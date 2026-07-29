import Foundation
import Testing
import UIKit
@testable import KARA

@Suite("Privacy preferences")
@MainActor
struct PrivacyPreferencesTests {
    @Test
    func freshInstallShowsSensitiveValues() {
        let defaults = makeDefaults()
        let preferences = PrivacyPreferences(defaults: defaults)

        #expect(!preferences.hidesSensitiveValues)
    }

    @Test
    func togglePersistsHiddenValuesAcrossInstances() {
        let defaults = makeDefaults()
        let preferences = PrivacyPreferences(defaults: defaults)

        preferences.toggle()

        #expect(preferences.hidesSensitiveValues)
        #expect(PrivacyPreferences(defaults: defaults).hidesSensitiveValues)
    }

    @Test
    func sensitiveArtworkUsesPhotoWhileValuesAreVisible() {
        let source = AssetArtworkSource.resolve(
            photoData: validImageData(),
            privacyBehavior: .sensitive,
            hidesSensitiveValues: false
        )

        #expect(source.usesUserPhoto)
    }

    @Test
    func sensitiveArtworkUsesCategoryAssetWhileValuesAreHidden() {
        let source = AssetArtworkSource.resolve(
            photoData: validImageData(),
            privacyBehavior: .sensitive,
            hidesSensitiveValues: true
        )

        #expect(!source.usesUserPhoto)
    }

    @Test
    func alwaysVisibleArtworkKeepsPhotoWhileValuesAreHidden() {
        let source = AssetArtworkSource.resolve(
            photoData: validImageData(),
            privacyBehavior: .alwaysVisible,
            hidesSensitiveValues: true
        )

        #expect(source.usesUserPhoto)
    }

    @Test(arguments: [Data?.none, Data([0x00, 0x01, 0x02])])
    func artworkUsesCategoryAssetForMissingOrInvalidPhoto(_ photoData: Data?) {
        let source = AssetArtworkSource.resolve(
            photoData: photoData,
            privacyBehavior: .alwaysVisible,
            hidesSensitiveValues: false
        )

        #expect(!source.usesUserPhoto)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "kara.tests.privacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func validImageData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).pngData { context in
            UIColor.systemYellow.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}
