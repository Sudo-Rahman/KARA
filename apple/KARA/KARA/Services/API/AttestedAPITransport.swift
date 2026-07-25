import Foundation

nonisolated protocol APIDataTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

nonisolated final class URLSessionAPIDataTransport: APIDataTransport, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw AppAttestClientError.nonHTTPResponse
        }
        return (data, response)
    }
}

nonisolated final class AttestedAPITransport: APIDataTransport, @unchecked Sendable {
    private struct ChallengeResponse: Decodable {
        let id: String
        let challenge: String
        let expiresAt: String
    }

    private struct ErrorEnvelope: Decodable {
        struct APIError: Decodable { let code: String }
        let error: APIError
    }

    private struct ChallengeRequest: Encodable {
        let purpose: String
        let keyId: String
        let request: AppAttestRequestBinding?
    }

    private struct RegistrationRequest: Encodable {
        let challengeId: String
        let keyId: String
        let attestation: String
    }

    private let baseURL: URL
    private let session: URLSession
    private let appAttest: AppAttestService

    init(
        baseURL: URL,
        session: URLSession = .shared,
        appAttest: AppAttestService = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.appAttest = appAttest
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await send(request, recoveredUnknownKey: false)
    }

    private func send(
        _ request: URLRequest,
        recoveredUnknownKey: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        let registrar: @Sendable (String) async throws -> Void = { [self] keyId in
            try await register(keyId: keyId)
        }
        let keyId = try await appAttest.ensureRegistered(using: registrar)
        let binding = try requestBinding(for: request)

        let challenge: ChallengeResponse
        do {
            challenge = try await requestChallenge(
                ChallengeRequest(purpose: "assertion", keyId: keyId, request: binding)
            )
        } catch let error as AppAttestClientError {
            if case let .server(_, code) = error,
               code == "unknown_app_attest_key",
               !recoveredUnknownKey {
                _ = try await appAttest.recoverUnknownKey(keyId, using: registrar)
                return try await send(request, recoveredUnknownKey: true)
            }
            throw error
        }

        let payload = Data(binding.canonicalPayload(challenge: challenge.challenge).utf8)
        let assertion = try await appAttest.assertion(keyId: keyId, payload: payload)
        var authenticatedRequest = request
        authenticatedRequest.setValue(keyId, forHTTPHeaderField: "X-Kara-App-Attest-Key-Id")
        authenticatedRequest.setValue(challenge.id, forHTTPHeaderField: "X-Kara-App-Attest-Challenge-Id")
        authenticatedRequest.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-Kara-App-Attest-Assertion")

        let result = try await URLSessionAPIDataTransport(session: session).data(for: authenticatedRequest)
        if result.1.statusCode == 401,
           serverErrorCode(from: result.0) == "unknown_app_attest_key",
           !recoveredUnknownKey {
            _ = try await appAttest.recoverUnknownKey(keyId, using: registrar)
            return try await send(request, recoveredUnknownKey: true)
        }
        return result
    }

    private func register(keyId: String) async throws {
        let challenge = try await requestChallenge(
            ChallengeRequest(purpose: "registration", keyId: keyId, request: nil)
        )
        guard let challengeData = Data(base64URL: challenge.challenge) else {
            throw AppAttestClientError.invalidChallenge
        }
        let attestation = try await appAttest.attestation(keyId: keyId, challenge: challengeData)
        let body = RegistrationRequest(
            challengeId: challenge.id,
            keyId: keyId,
            attestation: attestation.base64EncodedString()
        )
        let acknowledgement = try await postJSON(
            path: "auth/app-attest/registrations",
            body: body,
            as: RegistrationAcknowledgement.self
        )
        guard acknowledgement.registered else { throw AppAttestClientError.invalidChallenge }
    }

    private func requestChallenge(_ body: ChallengeRequest) async throws -> ChallengeResponse {
        try await postJSON(path: "auth/app-attest/challenges", body: body, as: ChallengeResponse.self)
    }

    private func postJSON<Body: Encodable, Output: Decodable>(
        path: String,
        body: Body,
        as: Output.Type
    ) async throws -> Output {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSessionAPIDataTransport(session: session).data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw AppAttestClientError.server(
                status: response.statusCode,
                code: serverErrorCode(from: data)
            )
        }
        return try JSONDecoder().decode(Output.self, from: data)
    }

    private func requestBinding(for request: URLRequest) throws -> AppAttestRequestBinding {
        guard let url = request.url else { throw AppAttestClientError.invalidURL }
        if request.httpBodyStream != nil { throw AppAttestClientError.unsupportedBodyStream }
        return try AppAttestRequestBinding(
            method: request.httpMethod ?? "GET",
            url: url,
            body: request.httpBody
        )
    }

    private func serverErrorCode(from data: Data) -> String? {
        try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error.code
    }
}

private nonisolated struct RegistrationAcknowledgement: Decodable {
    let registered: Bool
}

private nonisolated extension Data {
    init?(base64URL value: String) {
        var normalized = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        normalized += String(repeating: "=", count: (4 - normalized.count % 4) % 4)
        self.init(base64Encoded: normalized)
    }
}
