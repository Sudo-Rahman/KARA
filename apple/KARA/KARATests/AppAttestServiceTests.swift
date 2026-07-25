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

    @Test("Concurrent assertions are generated one at a time in arrival order")
    func serializesConcurrentAssertions() async throws {
        let provider = ControlledAssertionProvider()
        let defaults = try #require(UserDefaults(suiteName: "kara.tests.app-attest.\(UUID().uuidString)"))
        let service = AppAttestService(provider: provider, defaults: defaults)

        let first = Task {
            try await service.assertion(keyId: "key-1", payload: Data("first".utf8))
        }
        await provider.waitUntilInvocationCount(1)

        let second = Task {
            try await service.assertion(keyId: "key-1", payload: Data("second".utf8))
        }
        try await Task.sleep(for: .milliseconds(50))

        #expect(await provider.invocationCount == 1)

        await provider.completeNext(returning: Data("assertion-1".utf8))
        #expect(try await first.value == Data("assertion-1".utf8))
        await provider.waitUntilInvocationCount(2)
        await provider.completeNext(returning: Data("assertion-2".utf8))
        #expect(try await second.value == Data("assertion-2".utf8))
    }

    @Test("A failed assertion does not block the next assertion")
    func continuesAfterAssertionFailure() async throws {
        let provider = ControlledAssertionProvider()
        let defaults = try #require(UserDefaults(suiteName: "kara.tests.app-attest.\(UUID().uuidString)"))
        let service = AppAttestService(provider: provider, defaults: defaults)

        let failing = Task {
            try await service.assertion(keyId: "key-1", payload: Data("failing".utf8))
        }
        await provider.waitUntilInvocationCount(1)
        let succeeding = Task {
            try await service.assertion(keyId: "key-1", payload: Data("succeeding".utf8))
        }

        await provider.failNext(with: AssertionProviderError.expected)
        do {
            _ = try await failing.value
            Issue.record("Expected the first assertion to fail")
        } catch let error as AssertionProviderError {
            #expect(error == .expected)
        }

        await provider.waitUntilInvocationCount(2)
        await provider.completeNext(returning: Data("assertion-2".utf8))
        #expect(try await succeeding.value == Data("assertion-2".utf8))
    }

    @Test("Cancelling an assertion waiting for its turn skips the provider call")
    func skipsCancelledWaitingAssertion() async throws {
        let provider = ControlledAssertionProvider()
        let defaults = try #require(UserDefaults(suiteName: "kara.tests.app-attest.\(UUID().uuidString)"))
        let service = AppAttestService(provider: provider, defaults: defaults)

        let active = Task {
            try await service.assertion(keyId: "key-1", payload: Data("active".utf8))
        }
        await provider.waitUntilInvocationCount(1)
        let waiting = Task {
            try await service.assertion(keyId: "key-1", payload: Data("waiting".utf8))
        }
        try await Task.sleep(for: .milliseconds(50))

        waiting.cancel()
        await provider.completeNext(returning: Data("assertion-1".utf8))
        #expect(try await active.value == Data("assertion-1".utf8))

        do {
            _ = try await waiting.value
            Issue.record("Expected the waiting assertion to be cancelled")
        } catch is CancellationError {
            // Expected.
        }
        #expect(await provider.invocationCount == 1)
    }

    @Test("Cancelling an active assertion never overlaps the next assertion")
    func waitsForCancelledActiveAssertionToFinish() async throws {
        let provider = ControlledAssertionProvider()
        let defaults = try #require(UserDefaults(suiteName: "kara.tests.app-attest.\(UUID().uuidString)"))
        let service = AppAttestService(provider: provider, defaults: defaults)

        let active = Task {
            try await service.assertion(keyId: "key-1", payload: Data("active".utf8))
        }
        await provider.waitUntilInvocationCount(1)
        let waiting = Task {
            try await service.assertion(keyId: "key-1", payload: Data("waiting".utf8))
        }

        active.cancel()
        try await Task.sleep(for: .milliseconds(50))
        #expect(await provider.invocationCount == 1)

        await provider.completeNext(returning: Data("discarded".utf8))
        do {
            _ = try await active.value
            Issue.record("Expected the active assertion to be cancelled")
        } catch is CancellationError {
            // Expected.
        }

        await provider.waitUntilInvocationCount(2)
        await provider.completeNext(returning: Data("assertion-2".utf8))
        #expect(try await waiting.value == Data("assertion-2".utf8))
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

private actor ControlledAssertionProvider: AppAttestProviding {
    private var continuations: [CheckedContinuation<Data, any Error>] = []
    private(set) var invocationCount = 0

    func isSupported() async -> Bool { true }
    func generateKey() async throws -> String { "key-1" }
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        Data("attestation".utf8)
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        invocationCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitUntilInvocationCount(_ expectedCount: Int) async {
        while invocationCount < expectedCount {
            await Task.yield()
        }
    }

    func completeNext(returning data: Data) {
        continuations.removeFirst().resume(returning: data)
    }

    func failNext(with error: any Error) {
        continuations.removeFirst().resume(throwing: error)
    }
}

private enum AssertionProviderError: Error, Equatable {
    case expected
}
