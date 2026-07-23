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
        XCTAssertFalse(app.buttons["vault.privacy-toggle"].exists)
        capture("vault-02-inventory", in: app)

        let featuredAsset = app.buttons["inventory.asset.\(featuredAssetID)"]
        reveal(featuredAsset, in: app, attempts: 10)
        XCTAssertTrue(featuredAsset.isHittable)
        featuredAsset.tap()

        XCTAssertTrue(element("asset-detail.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["vault.privacy-toggle"].exists)
        capture("vault-03-detail", in: app)

        let more = app.buttons["asset-detail.more"]
        XCTAssertTrue(more.isHittable)
        more.tap()

        let edit = app.buttons["asset-detail.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 2))
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
        XCTAssertFalse(app.buttons["vault.privacy-toggle"].exists)
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

        let simulate = app.buttons["vault.simulate"]
        reveal(simulate, in: app, attempts: 12)
        XCTAssertTrue(simulate.isHittable)
        simulate.tap()

        let saleScreen = element("sale-simulation.screen", in: app)
        XCTAssertTrue(saleScreen.waitForExistence(timeout: 5))
        XCTAssertFalse(saleScreen.buttons["vault.privacy-toggle"].exists)

        let maskedSaleValue = saleScreen.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Valeur masquée"))
            .firstMatch
        XCTAssertTrue(maskedSaleValue.waitForExistence(timeout: 5))

        let increase = app.buttons["Augmenter la quantité"].firstMatch
        reveal(increase, in: app, attempts: 8)
        XCTAssertTrue(increase.isHittable)
        increase.tap()
        capture("vault-06-sale-simulation", in: app)
    }

    @MainActor
    func testDeletionConfirmationAndThirtyDayTrashWording() {
        let app = launchSeededVault()
        app.buttons["vault.inventory-card"].tap()
        XCTAssertTrue(element("inventory.screen", in: app).waitForExistence(timeout: 5))

        let featuredAsset = app.buttons["inventory.asset.\(featuredAssetID)"]
        reveal(featuredAsset, in: app, attempts: 10)
        XCTAssertTrue(featuredAsset.isHittable)
        featuredAsset.swipeLeft()

        let swipeDelete = app.buttons["Supprimer"].firstMatch
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 2))
        swipeDelete.tap()

        let confirmationMessage = app.staticTexts[
            "Cet actif sera placé dans la corbeille, puis supprimé automatiquement après 30 jours."
        ]
        XCTAssertTrue(confirmationMessage.waitForExistence(timeout: 2))
        hittableElement(labeled: "Annuler", in: app).tap()
        XCTAssertTrue(featuredAsset.exists)

        featuredAsset.tap()
        XCTAssertTrue(element("asset-detail.screen", in: app).waitForExistence(timeout: 5))
        app.buttons["asset-detail.more"].tap()

        let detailDelete = app.buttons["asset-detail.delete"]
        XCTAssertTrue(detailDelete.waitForExistence(timeout: 2))
        detailDelete.tap()
        XCTAssertTrue(confirmationMessage.waitForExistence(timeout: 2))
        hittableElement(labeled: "Supprimer", in: app).tap()

        XCTAssertTrue(element("inventory.screen", in: app).waitForExistence(timeout: 5))
        let removalExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: featuredAsset
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [removalExpectation], timeout: 5),
            .completed
        )
        capture("vault-08-after-delete", in: app)
    }

    @MainActor
    private func launchSeededVault() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KARAUseInMemoryStore",
            "-KARASeedVault",
            "-KARAShowOnboarding",
            "-kara.privacy.hidesSensitiveValues", "NO",
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
    private func hittableElement(
        labeled label: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        let matches = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
        return matches.allElementsBoundByIndex.first(where: \.isHittable)
            ?? matches.firstMatch
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
