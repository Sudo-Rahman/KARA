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
        XCTAssertTrue(app.buttons["Facture Lingotin 50 g.pdf"].exists)
        XCTAssertTrue(app.buttons["Certificat d’authenticité.jpg"].exists)
        capture("vault-05-linked-documents", in: app)
    }

    @MainActor
    func testPrivacyAnalysisAndSaleRecordingEntryPoints() {
        let app = launchSeededVault()

        let privacy = app.buttons["vault.privacy-toggle"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        privacy.tap()

        let maskedValue = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Valeur masquée"))
            .firstMatch
        XCTAssertTrue(maskedValue.waitForExistence(timeout: 5))
        capture("vault-05-privacy", in: app)

        let analysisTab = app.tabBars.buttons["Analyse"]
        XCTAssertTrue(analysisTab.waitForExistence(timeout: 5))
        analysisTab.tap()

        let analysisScreen = element("analysis.dashboard", in: app)
        XCTAssertTrue(analysisScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(element("analysis.period", in: app).exists)
        XCTAssertTrue(element("analysis.evolution-card", in: app).exists)
        XCTAssertFalse(analysisScreen.buttons["vault.privacy-toggle"].exists)

        let maskedAnalysisValue = analysisScreen.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Valeur masquée"))
            .firstMatch
        XCTAssertTrue(maskedAnalysisValue.waitForExistence(timeout: 5))
        capture("vault-06-analysis", in: app)

        let performanceCard = element("analysis.evolution-card", in: app)
        XCTAssertTrue(performanceCard.isHittable)
        performanceCard.tap()

        let performanceScreen = element("analysis.performance", in: app)
        XCTAssertTrue(performanceScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(element("analysis.performance.overview", in: app).exists)
        XCTAssertTrue(element("analysis.performance.ranking", in: app).exists)
        capture("vault-07-performance", in: app)

        let saleTab = app.tabBars.buttons["Ventes"]
        XCTAssertTrue(saleTab.waitForExistence(timeout: 5))
        saleTab.tap()

        let saleScreen = element("sales.dashboard", in: app)
        XCTAssertTrue(saleScreen.waitForExistence(timeout: 5))
        XCTAssertFalse(saleScreen.buttons["vault.privacy-toggle"].exists)
        XCTAssertTrue(app.buttons["sales.record"].exists)
        XCTAssertTrue(app.buttons["sales.alert.create"].exists)

        app.buttons["sales.record"].tap()
        XCTAssertTrue(element("sale-flow", in: app).waitForExistence(timeout: 5))

        let assetPicker = element("sale-flow.asset-picker", in: app)
        XCTAssertTrue(assetPicker.isHittable)
        assetPicker.tap()

        let napoleon = element(
            "sale-flow.asset-picker.A1000000-0000-4000-8000-000000000002",
            in: app
        )
        XCTAssertTrue(napoleon.waitForExistence(timeout: 5))
        napoleon.tap()
        XCTAssertFalse(
            element(
                "sale-flow.asset-picker.A1000000-0000-4000-8000-000000000002",
                in: app
            ).exists
        )
        XCTAssertTrue(element("sale-flow.quantity", in: app).exists)
        XCTAssertTrue(element("sale-flow.gross", in: app).exists)
        capture("vault-08-sale-recording", in: app)
    }

    @MainActor
    func testAllocationCardOpensPortfolioBreakdown() {
        let app = launchSeededVault()

        app.tabBars.buttons["Analyse"].tap()
        XCTAssertTrue(
            element("analysis.dashboard", in: app).waitForExistence(timeout: 5)
        )

        let allocationCard = element("analysis.allocation-card", in: app)
        reveal(allocationCard, in: app, attempts: 8)
        XCTAssertTrue(allocationCard.isHittable)
        allocationCard.tap()

        XCTAssertTrue(
            element("analysis.allocation", in: app).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(element("analysis.allocation.picker", in: app).exists)
        XCTAssertTrue(element("analysis.allocation.chart-card", in: app).exists)
        XCTAssertTrue(element("analysis.allocation.reading", in: app).exists)

        let exposures = element("analysis.allocation.exposures", in: app)
        reveal(exposures, in: app, attempts: 8)
        XCTAssertTrue(exposures.exists)
        capture("vault-07-allocation", in: app)
    }

    @MainActor
    func testSaleFormDismissesKeyboardOnlyAfterOutsideTap() {
        let app = launchSeededVault()

        app.tabBars.buttons["Ventes"].tap()
        XCTAssertTrue(
            element("sales.dashboard", in: app).waitForExistence(timeout: 5)
        )
        app.buttons["sales.record"].tap()
        XCTAssertTrue(element("sale-flow", in: app).waitForExistence(timeout: 5))

        let grossAmount = element("sale-flow.gross", in: app)
        XCTAssertTrue(grossAmount.isHittable)
        grossAmount.tap()
        grossAmount.typeText("2500")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        app.swipeUp()
        XCTAssertTrue(app.keyboards.firstMatch.exists)

        app.staticTexts["Frais"].firstMatch.tap()
        XCTAssertTrue(waitForDisappearance(of: app.keyboards.firstMatch))
    }

    @MainActor
    func testRecordedFullSaleMovesTheAssetOutOfTheVault() {
        let app = launchSeededVault()
        let soldAssetID = "A1000000-0000-4000-8000-000000000004"

        app.tabBars.buttons["Ventes"].tap()
        XCTAssertTrue(
            element("sales.dashboard", in: app).waitForExistence(timeout: 5)
        )
        app.buttons["sales.record"].tap()
        XCTAssertTrue(element("sale-flow", in: app).waitForExistence(timeout: 5))

        let assetPicker = element("sale-flow.asset-picker", in: app)
        XCTAssertTrue(assetPicker.isHittable)
        assetPicker.tap()

        let asset = element(
            "sale-flow.asset-picker.\(soldAssetID)",
            in: app
        )
        XCTAssertTrue(asset.waitForExistence(timeout: 5))
        asset.tap()

        let grossAmount = element("sale-flow.gross", in: app)
        XCTAssertTrue(grossAmount.isHittable)
        grossAmount.tap()
        grossAmount.typeText("850")
        app.swipeUp()

        let submit = app.buttons["Continuer"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()

        let confirmation = app.alerts["Confirmer la vente"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Enregistrer la vente"].tap()

        XCTAssertTrue(
            element("sale-flow.success", in: app).waitForExistence(timeout: 5)
        )
        app.buttons["sale-flow.success.close"].tap()
        XCTAssertTrue(
            element("sales.dashboard", in: app).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Bracelet Or 18 carats"].exists)

        app.tabBars.buttons["Coffre"].tap()
        app.buttons["vault.inventory-card"].tap()
        XCTAssertTrue(
            element("inventory.screen", in: app).waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["inventory.asset.\(soldAssetID)"].exists)
    }

    @MainActor
    func testPastPriceGoalsCanBeDeletedInBulk() {
        let app = launchSeededVault()

        app.tabBars.buttons["Ventes"].tap()
        XCTAssertTrue(
            element("sales.dashboard", in: app).waitForExistence(timeout: 5)
        )

        app.buttons["Tout voir"].tap()
        XCTAssertTrue(
            element("alerts.list", in: app).waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["Vérifiés automatiquement"].exists)
        XCTAssertTrue(app.staticTexts["À examiner"].exists)
        XCTAssertTrue(app.staticTexts["Anciens objectifs"].exists)

        let deleteAll = element("alerts.past.delete-all", in: app)
        XCTAssertTrue(deleteAll.isHittable)
        deleteAll.tap()

        let confirmation = app.alerts[
            "Supprimer tous les anciens objectifs ?"
        ]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["Annuler"].tap()
        XCTAssertTrue(deleteAll.exists)

        deleteAll.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["Tout supprimer"].tap()

        let removalExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: deleteAll
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [removalExpectation], timeout: 5),
            .completed
        )
        XCTAssertTrue(app.staticTexts["À examiner"].exists)
        XCTAssertFalse(app.staticTexts["Anciens objectifs"].exists)
    }

    @MainActor
    func testPriceGoalUsesCompactAssetPicker() {
        let app = launchSeededVault()

        app.tabBars.buttons["Ventes"].tap()
        XCTAssertTrue(
            element("sales.dashboard", in: app).waitForExistence(timeout: 5)
        )
        app.buttons["sales.alert.create"].tap()

        XCTAssertTrue(
            element("alert-flow", in: app).waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["Comment cela fonctionne"].exists)
        XCTAssertFalse(
            app.staticTexts[
                "Actualisation dans l’app et en arrière-plan"
            ].exists
        )

        let assetPicker = element("alert-flow.asset-picker", in: app)
        XCTAssertTrue(assetPicker.isHittable)
        assetPicker.tap()

        let mapleLeaf = element(
            "alert-flow.asset-picker.A1000000-0000-4000-8000-000000000003",
            in: app
        )
        XCTAssertTrue(mapleLeaf.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Maple Leaf 1 oz"].exists)
        mapleLeaf.tap()

        XCTAssertTrue(app.staticTexts["Maple Leaf 1 oz"].exists)
        XCTAssertTrue(element("alert-flow.target", in: app).exists)
        capture("vault-07-price-goal-picker", in: app)
    }

    @MainActor
    func testHomeDashboardAndSettingsExposeTheirPrimaryContent() {
        let app = launchSeededVault()

        XCTAssertTrue(app.tabBars.buttons["Analyse"].exists)
        XCTAssertTrue(app.tabBars.buttons["Ventes"].exists)

        let metalPrices = element("vault.metal-prices", in: app)
        reveal(metalPrices, in: app, attempts: 16)
        XCTAssertTrue(metalPrices.exists)
        capture("vault-08-home-dashboard", in: app)

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
        capture("vault-09-settings-trash", in: app)
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
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
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

        app.tabBars.buttons["Réglages"].tap()
        XCTAssertTrue(element("settings.screen", in: app).waitForExistence(timeout: 5))

        let trash = element("settings.trash", in: app)
        reveal(trash, in: app, attempts: 8)
        XCTAssertTrue(trash.isHittable)
        trash.tap()

        XCTAssertTrue(element("settings.trash.screen", in: app).waitForExistence(timeout: 5))
        let trashedAsset = element("settings.trash.asset.\(featuredAssetID)", in: app)
        XCTAssertTrue(trashedAsset.waitForExistence(timeout: 5))

        let deleteAll = element("settings.trash.delete-all", in: app)
        XCTAssertTrue(deleteAll.isHittable)
        deleteAll.tap()

        let deleteAllAlert = app.alerts["Vider la corbeille ?"]
        XCTAssertTrue(deleteAllAlert.waitForExistence(timeout: 2))
        hittableElement(labeled: "Annuler", in: app).tap()
        XCTAssertTrue(trashedAsset.exists)

        trashedAsset.swipeLeft()
        let permanentDelete = element(
            "settings.trash.delete.\(featuredAssetID)",
            in: app
        )
        XCTAssertTrue(permanentDelete.waitForExistence(timeout: 2))
        permanentDelete.tap()

        XCTAssertFalse(app.alerts["Supprimer définitivement cet actif ?"].exists)
        let permanentRemovalExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: trashedAsset
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [permanentRemovalExpectation], timeout: 5),
            .completed
        )
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

    @MainActor
    private func waitForDisappearance(
        of element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
