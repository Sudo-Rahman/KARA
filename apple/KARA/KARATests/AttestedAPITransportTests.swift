import Foundation
import Testing
@testable import KARA

@Suite("Attested API transport", .serialized)
struct AttestedAPITransportTests {
    @Test("Registers once then signs the protected request")
    func registersAndSigns() async throws {
        let defaults = try #require(UserDefaults(suiteName: "kara.tests.transport.\(UUID().uuidString)"))
        let appAttest = AppAttestService(provider: TransportAppAttestProvider(), defaults: defaults)
        let session = URLSession.attestationStubbed()
        let transport = AttestedAPITransport(
            baseURL: URL(string: "https://example.test")!,
            session: session,
            appAttest: appAttest
        )

        let (data, response) = try await transport.data(
            for: URLRequest(url: URL(string: "https://example.test/v1/manifest.json")!)
        )

        #expect(response.statusCode == 200)
        #expect(String(decoding: data, as: UTF8.self) == "protected")
        #expect(await TransportURLProtocol.requests.count == 4)
        let protectedRequest = try #require(await TransportURLProtocol.requests.last)
        #expect(protectedRequest.value(forHTTPHeaderField: "X-Kara-App-Attest-Key-Id") == TransportAppAttestProvider.keyId)
        #expect(protectedRequest.value(forHTTPHeaderField: "X-Kara-App-Attest-Challenge-Id") == "00000000-0000-0000-0000-000000000003")
        #expect(protectedRequest.value(forHTTPHeaderField: "X-Kara-App-Attest-Assertion") == Data("assertion".utf8).base64EncodedString())
    }
}

private actor TransportAppAttestProvider: AppAttestProviding {
    static let keyId = Data(repeating: 7, count: 32).base64EncodedString()

    func isSupported() async -> Bool { true }
    func generateKey() async throws -> String { Self.keyId }
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data { Data("attestation".utf8) }
    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data { Data("assertion".utf8) }
}

private final class TransportURLProtocol: URLProtocol, @unchecked Sendable {
    private static let state = TransportRequestState()
    static var requests: [URLRequest] { get async { await state.requests } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task {
            let index = await Self.state.append(request)
            let output: (Int, Data)
            switch index {
            case 0:
                output = (201, Self.json([
                    "id": "00000000-0000-0000-0000-000000000001",
                    "challenge": Data("register".utf8).base64URLEncodedString,
                    "expiresAt": "2026-07-24T22:00:00Z",
                ]))
            case 1:
                output = (201, Self.json(["registered": true]))
            case 2:
                output = (201, Self.json([
                    "id": "00000000-0000-0000-0000-000000000003",
                    "challenge": Data("assert".utf8).base64URLEncodedString,
                    "expiresAt": "2026-07-24T22:00:00Z",
                ]))
            default:
                output = (200, Data("protected".utf8))
            }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: output.0, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: output.1)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private static func json(_ value: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: value)
    }
}

private actor TransportRequestState {
    private(set) var requests: [URLRequest] = []
    func append(_ request: URLRequest) -> Int {
        requests.append(request)
        return requests.count - 1
    }
}

private extension URLSession {
    static func attestationStubbed() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TransportURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private extension Data {
    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
