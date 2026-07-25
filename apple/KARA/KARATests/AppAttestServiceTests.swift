import Foundation
import Testing
@testable import KARA

@Suite("App Attest service")
struct AppAttestServiceTests {
    @Test("Concurrent callers share one generated and registered key")
    func coalescesConcurrentRegistration() async throws {
        let provider = RecordingAppAttestProvider()
        let registrations = RegistrationRecorder()
        let defaults = try #require(UserDefaults(suiteName: "kara.tests.app-attest.\(UUID().uuidString)"))
        let service = AppAttestService(provider: provider, defaults: defaults)

        let keyIds = try await withThrowingTaskGroup(of: String.self, returning: [String].self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await service.ensureRegistered { keyId in
                        await registrations.record(keyId)
                    }
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        #expect(Set(keyIds) == ["key-1"])
        #expect(await provider.generatedKeyCount == 1)
        #expect(await registrations.keyIds == ["key-1"])
    }

    @Test("An unknown persisted key is replaced once")
    func recoversUnknownPersistedKey() async throws {
        let provider = RecordingAppAttestProvider()
        let registrations = RegistrationRecorder()
        let defaults = try #require(UserDefaults(suiteName: "kara.tests.app-attest.\(UUID().uuidString)"))
        defaults.set("lost-key", forKey: "kara.app-attest.key-id")
        defaults.set("lost-key", forKey: "kara.app-attest.registered-key-id")
        let service = AppAttestService(provider: provider, defaults: defaults)

        let replacement = try await service.recoverUnknownKey("lost-key") { keyId in
            await registrations.record(keyId)
        }

        #expect(replacement == "key-1")
        #expect(await provider.generatedKeyCount == 1)
        #expect(await registrations.keyIds == ["key-1"])
    }
}

private actor RecordingAppAttestProvider: AppAttestProviding {
    private(set) var generatedKeyCount = 0

    func isSupported() async -> Bool { true }

    func generateKey() async throws -> String {
        generatedKeyCount += 1
        return "key-\(generatedKeyCount)"
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data { Data("attestation".utf8) }
    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data { Data("assertion".utf8) }
}

private actor RegistrationRecorder {
    private(set) var keyIds: [String] = []

    func record(_ keyId: String) {
        keyIds.append(keyId)
    }
}
