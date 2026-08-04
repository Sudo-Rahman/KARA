import Foundation

nonisolated struct KaraWidgetSnapshotStore: Sendable {
    static let defaultAppGroupIdentifier = "group.karaprivate.kara"
    static let relativePath = "Widget/v1/snapshot.json"

    let baseURL: URL

    var fileURL: URL {
        baseURL
            .appending(path: "Widget", directoryHint: .isDirectory)
            .appending(path: "v1", directoryHint: .isDirectory)
            .appending(path: "snapshot.json", directoryHint: .notDirectory)
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    init(
        appGroupIdentifier: String = KaraWidgetSnapshotStore.defaultAppGroupIdentifier
    ) throws {
        guard let baseURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw KaraWidgetSnapshotStoreError.appGroupContainerUnavailable(
                appGroupIdentifier
            )
        }
        self.init(baseURL: baseURL)
    }

    func read() throws -> KaraWidgetSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode(KaraWidgetSnapshot.self, from: data).validated()
    }

    func write(_ snapshot: KaraWidgetSnapshot) throws {
        let snapshot = try snapshot.validated()
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
        applyFileProtectionBestEffort()
    }

    func remove() throws {
        guard FileManager.default.fileExists(
            atPath: fileURL.path(percentEncoded: false)
        ) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func applyFileProtectionBestEffort() {
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path(percentEncoded: false)
        )
#endif
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return decoder
    }
}

nonisolated enum KaraWidgetSnapshotStoreError: Error, Equatable, Sendable {
    case appGroupContainerUnavailable(String)
}
