import CryptoKit
import DeviceCheck
import Foundation

nonisolated enum AppAttestClientError: Error, Equatable, Sendable {
    case unsupported
    case invalidURL
    case invalidChallenge
    case nonHTTPResponse
    case unsupportedBodyStream
    case server(status: Int, code: String?)
}

nonisolated protocol AppAttestProviding: Sendable {
    func isSupported() async -> Bool
    func generateKey() async throws -> String
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data
}

nonisolated final class SystemAppAttestProvider: AppAttestProviding, @unchecked Sendable {
    private let service = DCAppAttestService.shared

    func isSupported() async -> Bool { service.isSupported }

    func generateKey() async throws -> String {
        try await service.generateKey()
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await service.attestKey(keyId, clientDataHash: clientDataHash)
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
    }
}

actor AppAttestService {
    static let shared = AppAttestService()

    private enum StorageKey {
        static let keyId = "kara.app-attest.key-id"
        static let registeredKeyId = "kara.app-attest.registered-key-id"
    }

    private let provider: any AppAttestProviding
    private let defaults: UserDefaults
    private var keyGenerationTask: Task<String, any Error>?
    private var registrationTask: Task<String, any Error>?
    private var assertionTail: Task<Void, Never>?

    init(
        provider: any AppAttestProviding = SystemAppAttestProvider(),
        defaults: UserDefaults = .standard
    ) {
        self.provider = provider
        self.defaults = defaults
    }

    func keyIdentifier() async throws -> String {
        if let keyId = defaults.string(forKey: StorageKey.keyId) { return keyId }
        if let keyGenerationTask {
            let keyId = try await keyGenerationTask.value
            defaults.set(keyId, forKey: StorageKey.keyId)
            return keyId
        }

        let provider = provider
        let task = Task<String, any Error> {
            guard await provider.isSupported() else {
                throw AppAttestClientError.unsupported
            }
            return try await provider.generateKey()
        }
        keyGenerationTask = task
        do {
            let keyId = try await task.value
            defaults.set(keyId, forKey: StorageKey.keyId)
            keyGenerationTask = nil
            return keyId
        } catch {
            keyGenerationTask = nil
            throw error
        }
    }

    func ensureRegistered(
        using registrar: @escaping @Sendable (String) async throws -> Void
    ) async throws -> String {
        let keyId = try await keyIdentifier()
        if defaults.string(forKey: StorageKey.registeredKeyId) == keyId { return keyId }
        if let registrationTask { return try await registrationTask.value }

        let task = Task {
            try await registrar(keyId)
            return keyId
        }
        registrationTask = task
        do {
            let registeredKeyId = try await task.value
            if defaults.string(forKey: StorageKey.keyId) == registeredKeyId {
                defaults.set(registeredKeyId, forKey: StorageKey.registeredKeyId)
            }
            registrationTask = nil
            return registeredKeyId
        } catch {
            registrationTask = nil
            throw error
        }
    }

    func recoverUnknownKey(
        _ rejectedKeyId: String,
        using registrar: @escaping @Sendable (String) async throws -> Void
    ) async throws -> String {
        if defaults.string(forKey: StorageKey.keyId) == rejectedKeyId {
            defaults.removeObject(forKey: StorageKey.keyId)
            defaults.removeObject(forKey: StorageKey.registeredKeyId)
            keyGenerationTask?.cancel()
            registrationTask?.cancel()
            keyGenerationTask = nil
            registrationTask = nil
        }
        return try await ensureRegistered(using: registrar)
    }

    func attestation(keyId: String, challenge: Data) async throws -> Data {
        do {
            return try await provider.attestKey(keyId, clientDataHash: Self.sha256(challenge))
        } catch {
            let nsError = error as NSError
            let isTemporaryAppleFailure = nsError.domain == DCError.errorDomain &&
                nsError.code == DCError.Code.serverUnavailable.rawValue
            if !isTemporaryAppleFailure,
               defaults.string(forKey: StorageKey.keyId) == keyId {
                defaults.removeObject(forKey: StorageKey.keyId)
                defaults.removeObject(forKey: StorageKey.registeredKeyId)
            }
            throw error
        }
    }

    func assertion(keyId: String, payload: Data) async throws -> Data {
        let predecessor = assertionTail
        let provider = provider
        let clientDataHash = Self.sha256(payload)
        let operation = Task<Data, any Error> {
            if let predecessor {
                await predecessor.value
            }
            try Task.checkCancellation()
            let assertion = try await provider.generateAssertion(
                keyId,
                clientDataHash: clientDataHash
            )
            try Task.checkCancellation()
            return assertion
        }
        assertionTail = Task {
            _ = await operation.result
        }

        return try await withTaskCancellationHandler {
            try await operation.value
        } onCancel: {
            operation.cancel()
        }
    }

    private static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}
