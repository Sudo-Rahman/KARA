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
        XCTAssertFalse(app.buttons["home.settings"].exists)
        XCTAssertFalse(app.buttons["vault.simulate"].exists)
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
        XCTAssertTrue(element("asset-detail.hero", in: app).exists)
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
        XCTAssertFalse(app.staticTexts["Affinez chaque détail"].exists)
        XCTAssertTrue(app.staticTexts["Investissement"].exists)
        XCTAssertTrue(app.staticTexts["Long terme"].exists)

        name.tap()
        XCTAssertFalse(app.buttons["Terminé"].exists)
        XCTAssertTrue(app.buttons["asset-editor.save"].exists)
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

        let saleTab = app.tabBars.buttons["Vente"]
        XCTAssertTrue(saleTab.waitForExistence(timeout: 5))
        saleTab.tap()

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
    func testHomeDashboardAndSettingsExposeTheirPrimaryContent() {
        let app = launchSeededVault()

        XCTAssertFalse(app.tabBars.buttons["Analyse"].exists)

        let history = element("vault.history", in: app)
        reveal(history, in: app, attempts: 10)
        XCTAssertTrue(history.exists)

        let metalPrices = element("vault.metal-prices", in: app)
        reveal(metalPrices, in: app, attempts: 16)
        XCTAssertTrue(metalPrices.exists)
        capture("vault-07-home-dashboard", in: app)

        let settingsTab = app.tabBars.buttons["Réglages"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        XCTAssertTrue(element("settings.screen", in: app).waitForExistence(timeout: 5))

        let aiToggle = app.switches["settings.ai.toggle"]
        let privacyToggle = app.switches["settings.privacy.toggle"]
        let appLockToggle = app.switches["settings.app-lock.toggle"]
        let report = element("settings.vault.report", in: app)
        XCTAssertTrue(aiToggle.exists)
        XCTAssertTrue(privacyToggle.exists)
        XCTAssertTrue(appLockToggle.exists)
        XCTAssertFalse(element("settings.app-lock.delay", in: app).exists)
        XCTAssertTrue(report.exists)
        XCTAssertTrue(report.isEnabled)

        let trash = element("settings.trash", in: app)
        reveal(trash, in: app, attempts: 8)
        XCTAssertTrue(trash.exists)
        XCTAssertTrue(trash.isHittable)
        trash.tap()
        XCTAssertTrue(element("settings.trash.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["La corbeille est vide"].exists)
        capture("vault-08-settings-trash", in: app)
    }

    @MainActor
    func testVaultReportPreviewOpensBeforeShareSheet() {
        let app = launchSeededVault()
        app.tabBars.buttons["Réglages"].tap()

        let report = element("settings.vault.report", in: app)
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        XCTAssertTrue(report.isEnabled)
        report.tap()

        XCTAssertTrue(
            element("settings.vault.report.preview", in: app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.tabBars.firstMatch.exists)

        let share = app.buttons["settings.vault.report.preview.share"]
        // Quick Look exposes its document through a system-owned process, so the
        // share action is the stable readiness signal for the rendered preview.
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        XCTAssertTrue(share.isHittable)
        share.tap()

        XCTAssertTrue(
            element("settings.vault.report.share-sheet", in: app)
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testVaultReportIsDisabledForAnEmptyVault() {
        let app = launchEmptyVault()
        app.tabBars.buttons["Réglages"].tap()

        let report = element("settings.vault.report", in: app)
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        XCTAssertFalse(report.isEnabled)
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
        capture("vault-09-after-delete", in: app)
    }

    @MainActor
    private func launchSeededVault() -> XCUIApplication {
        launchVault(seed: true)
    }

    @MainActor
    private func launchEmptyVault() -> XCUIApplication {
        launchVault(seed: false)
    }

    @MainActor
    private func launchVault(seed: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var launchArguments = [
            "-KARAUseInMemoryStore",
            "-kara.onboarding.hasCompleted", "YES",
            "-kara.privacy.hidesSensitiveValues", "NO",
            "-kara.app-lock.is-enabled", "NO",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
        ]
        if seed {
            launchArguments.append("-KARASeedVault")
        }
        app.launchArguments = launchArguments
        app.launch()

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
