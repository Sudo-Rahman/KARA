import SwiftData
import Testing
@testable import KARA

@Suite("Persistence configuration")
struct PersistenceConfigurationTests {
    @Test("Production always uses the private KARA CloudKit database")
    func productionConfigurationUsesPrivateCloudKit() {
        let configuration = KaraModelContainerFactory.configuration(
            arguments: [],
            environment: [:]
        )

        #expect(!configuration.isStoredInMemoryOnly)
        #expect(configuration.cloudKitContainerIdentifier == "iCloud.kara")
    }

    #if DEBUG
    @Test("The explicit DEBUG launch argument isolates tests in memory")
    func debugConfigurationCanUseMemory() {
        let configuration = KaraModelContainerFactory.configuration(
            arguments: ["-KARAUseInMemoryStore"],
            environment: [:]
        )

        #expect(configuration.isStoredInMemoryOnly)
        #expect(configuration.cloudKitContainerIdentifier == nil)
    }

    @Test("A unit-test host never opens CloudKit")
    func unitTestHostUsesMemory() {
        let configuration = KaraModelContainerFactory.configuration(
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/KARA.xctestconfiguration"]
        )

        #expect(configuration.isStoredInMemoryOnly)
        #expect(configuration.cloudKitContainerIdentifier == nil)
    }
    #endif
}
