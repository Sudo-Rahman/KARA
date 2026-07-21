import Foundation
import SwiftData

enum KaraModelContainerFactory {
    static let cloudKitContainerIdentifier = "iCloud.kara"
    static let inMemoryLaunchArgument = "-KARAUseInMemoryStore"

    static var schema: Schema {
        Schema([
            Asset.self,
            AssetAttachment.self,
            SavedSeller.self,
            StorageLocation.self,
        ])
    }

    static func configuration(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ModelConfiguration {
        #if DEBUG
        let isRunningUnitTests = environment["XCTestConfigurationFilePath"] != nil
        if arguments.contains(inMemoryLaunchArgument) || isRunningUnitTests {
            return ModelConfiguration(
                "KARA-Tests",
                schema: schema,
                isStoredInMemoryOnly: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        }
        #endif

        return ModelConfiguration(
            "KARA",
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )
    }

    static func make(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ModelContainer {
        let schema = schema
        let container = try ModelContainer(
            for: schema,
            configurations: [
                configuration(arguments: arguments, environment: environment),
            ]
        )

        #if DEBUG
        try VisualQAVaultSeeder.seedIfRequested(
            in: container,
            arguments: arguments
        )
        #endif

        return container
    }
}
