import XCTest

final class VaultExperienceUITests: XCTestCase {
    private let featuredAssetID = "A1000000-0000-4000-8000-000000000001"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testVaultInventoryDetailAndLinkedDocumentsJourney() {
        let app = launchSeededVault()

        XCTAssertTrue(element("vault.estimated-value", in: app).exists)
        capture("vault-01-dashboard", in: app)

        let inventoryCard = app.buttons["vault.inventory-card"]
        XCTAssertTrue(inventoryCard.waitForExistence(timeout: 5))
        inventoryCard.tap()

        XCTAssertTrue(element("inventory.screen", in: app).waitForExistence(timeout: 5))
        capture("vault-02-inventory", in: app)

        let featuredAsset = app.buttons["inventory.asset.\(featuredAssetID)"]
        reveal(featuredAsset, in: app, attempts: 10)
        XCTAssertTrue(featuredAsset.isHittable)
        featuredAsset.tap()

        XCTAssertTrue(element("asset-detail.screen", in: app).waitForExistence(timeout: 5))
        capture("vault-03-detail", in: app)

        let edit = app.buttons["asset-detail.edit"]
        XCTAssertTrue(edit.isHittable)
        edit.tap()

        let name = app.textFields["asset-editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Lingotin Or 50 g CPoR")
        capture("vault-04-editor", in: app)
        app.buttons["asset-editor.cancel"].tap()
        XCTAssertTrue(element("asset-detail.screen", in: app).waitForExistence(timeout: 5))

        let documents = app.buttons["asset-detail.documents"]
        reveal(documents, in: app, attempts: 14)
        XCTAssertTrue(documents.isHittable)
        documents.tap()

        XCTAssertTrue(element("documents.header", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Facture Lingotin 50 g.txt"].exists)
        XCTAssertTrue(app.buttons["Certificat d’authenticité.txt"].exists)
        capture("vault-05-linked-documents", in: app)
    }

    @MainActor
    func testPrivacyAndIntegerSaleSimulation() {
        let app = launchSeededVault()

        let privacy = app.buttons["vault.privacy-toggle"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        privacy.tap()

        let maskedValue = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Valeur masquée"))
            .firstMatch
        XCTAssertTrue(maskedValue.waitForExistence(timeout: 5))
        capture("vault-05-privacy", in: app)

        privacy.tap()

        let simulate = app.buttons["vault.simulate"]
        reveal(simulate, in: app, attempts: 12)
        XCTAssertTrue(simulate.isHittable)
        simulate.tap()

        XCTAssertTrue(element("sale-simulation.screen", in: app).waitForExistence(timeout: 5))

        let increase = app.buttons["Augmenter la quantité"].firstMatch
        reveal(increase, in: app, attempts: 8)
        XCTAssertTrue(increase.isHittable)
        increase.tap()
        capture("vault-06-sale-simulation", in: app)
    }

    @MainActor
    private func launchSeededVault() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KARAUseInMemoryStore",
            "-KARASeedVault",
            "-KARAShowOnboarding",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
        ]
        app.launch()

        let action = app.buttons["onboarding.primary.action"]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        action.tap()
        XCTAssertTrue(waitForLabel("Continuer", on: action))
        action.tap()
        XCTAssertTrue(waitForLabel("Ajouter mon premier objet", on: action))
        action.tap()

        XCTAssertTrue(element("vault.dashboard", in: app).waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    @MainActor
    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int
    ) {
        for _ in 0..<attempts where !element.isHittable {
            app.swipeUp()
        }
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
