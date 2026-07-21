import XCTest

final class AssetCreationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFrenchManualFlowSavesAndImmediatelyAppearsAtHome() {
        let app = launchAtHome(language: "fr")

        XCTAssertTrue(app.buttons["vault.privacy-toggle"].exists)
        XCTAssertEqual(app.buttons["home.add"].label, "Ajouter un actif")

        completeManualAssetFlow(
            in: app,
            language: "fr",
            expectedAssetName: "Lingotin d’or 1 g",
            selectedCurrencyCode: "CHF"
        )

        assertSavedPurchaseSuggestions(in: app, language: "fr")
    }

    @MainActor
    func testEnglishManualFlowIsLocalizedAndPersists() {
        let app = launchAtHome(language: "en")

        XCTAssertEqual(app.buttons["home.add"].label, "Add an asset")

        completeManualAssetFlow(
            in: app,
            language: "en",
            expectedAssetName: "Gold bar 1 g",
            selectedCurrencyCode: "GBP"
        )
    }

    @MainActor
    func testPlusCanOpenTheFlowRepeatedly() {
        let app = launchAtHome(language: "fr")

        app.buttons["home.add"].tap()
        assertStep(1, screenIdentifier: "asset-flow.object.skip", language: "fr", in: app)
        XCTAssertFalse(app.buttons["home.add"].exists)

        app.buttons["asset-flow.object.skip"].tap()
        assertStep(2, screenIdentifier: "invoice.skip", language: "fr", in: app)
        XCTAssertTrue(app.buttons["asset-flow.cancel"].exists)

        let back = app.buttons["asset-flow.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertEqual(back.label, "Retour")
        back.tap()
        assertStep(1, screenIdentifier: "asset-flow.object.skip", language: "fr", in: app)

        app.buttons["asset-flow.cancel"].tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))

        app.buttons["home.add"].tap()
        assertStep(1, screenIdentifier: "asset-flow.object.skip", language: "fr", in: app)
    }

    @MainActor
    func testKeyboardDismissesFromPageTapButNotScroll() {
        let app = launchAtHome(language: "fr")

        app.buttons["home.add"].tap()
        app.buttons["asset-flow.object.skip"].tap()
        app.buttons["invoice.skip"].tap()

        let category = app.buttons["classification.category.goldBar"]
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.tap()
        app.buttons["classification.continue"].tap()

        assertKeyboardDismissal(in: app)
    }

    @MainActor
    private func completeManualAssetFlow(
        in app: XCUIApplication,
        language: String,
        expectedAssetName: String,
        selectedCurrencyCode: String
    ) {
        app.buttons["home.add"].tap()
        assertStep(1, screenIdentifier: "asset-flow.object.skip", language: language, in: app)
        capture("\(language)-01-photo", in: app)
        XCTAssertFalse(app.buttons["home.add"].exists)

        app.buttons["asset-flow.object.skip"].tap()
        assertStep(2, screenIdentifier: "invoice.skip", language: language, in: app)
        capture("\(language)-02-invoice", in: app)
        app.buttons["invoice.skip"].tap()

        assertStep(
            3,
            screenIdentifier: "classification.category.goldBar",
            language: language,
            in: app
        )

        let classificationContinue = app.buttons["classification.continue"]
        XCTAssertTrue(classificationContinue.exists)
        XCTAssertFalse(classificationContinue.isEnabled)

        app.buttons["classification.category.goldBar"].tap()

        let gold = app.buttons["classification.metal.gold"]
        reveal(gold, in: app)
        XCTAssertTrue(gold.isHittable)
        gold.tap()

        let presetChoice = app.buttons["classification.preset.gold-bar-1g"]
        reveal(presetChoice, in: app)
        XCTAssertTrue(presetChoice.isHittable)
        presetChoice.tap()

        XCTAssertTrue(classificationContinue.isEnabled)
        capture("\(language)-03-classification", in: app)
        classificationContinue.tap()

        assertStep(4, screenIdentifier: "details.name", language: language, in: app)
        capture("\(language)-04-characteristics", in: app)
        let characteristicsContinue = app.buttons["characteristics.continue"]
        XCTAssertTrue(characteristicsContinue.waitForExistence(timeout: 5))
        XCTAssertTrue(characteristicsContinue.isHittable)
        characteristicsContinue.tap()

        assertStep(5, screenIdentifier: "details.currency", language: language, in: app)
        selectCurrency(selectedCurrencyCode, in: app)
        capture("\(language)-05-purchase", in: app)
        enterReusablePurchaseValues(in: app)

        let purchaseContinue = app.buttons["purchase.continue"]
        XCTAssertTrue(purchaseContinue.waitForExistence(timeout: 5))
        XCTAssertTrue(purchaseContinue.isHittable)
        purchaseContinue.tap()

        assertStep(6, screenIdentifier: "summary.asset", language: language, in: app)
        let summaryAsset = element(identifier: "summary.asset", in: app)
        XCTAssertTrue(summaryAsset.label.contains(expectedAssetName))
        capture("\(language)-06-summary", in: app)

        let save = app.buttons["summary.save"]
        reveal(save, in: app)
        XCTAssertTrue(save.isHittable)
        save.tap()

        XCTAssertTrue(element(identifier: "home.assets", in: app).waitForExistence(timeout: 5))

        let savedAsset = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.asset."))
            .firstMatch
        XCTAssertTrue(savedAsset.waitForExistence(timeout: 5))
        XCTAssertTrue(savedAsset.label.contains(expectedAssetName))
        XCTAssertTrue(app.buttons["home.add"].exists)
        capture("\(language)-07-saved-home", in: app)
    }

    @MainActor
    private func enterReusablePurchaseValues(in app: XCUIApplication) {
        let seller = app.textFields["details.seller"]
        reveal(seller, in: app)
        seller.tap()
        seller.typeText("Maison Aurore")

        let storage = app.textFields["details.storage-location"]
        reveal(storage, in: app)
        storage.tap()
        storage.typeText("Coffre privé")

        element(identifier: "asset-step.heading", in: app).tap()
        XCTAssertTrue(waitForDisappearance(of: app.keyboards.firstMatch))
    }

    @MainActor
    private func assertSavedPurchaseSuggestions(
        in app: XCUIApplication,
        language: String
    ) {
        app.buttons["home.add"].tap()
        app.buttons["asset-flow.object.skip"].tap()
        app.buttons["invoice.skip"].tap()

        let customCategory = app.buttons["classification.category.custom"]
        XCTAssertTrue(customCategory.waitForExistence(timeout: 5))
        customCategory.tap()
        app.buttons["classification.continue"].tap()

        let name = app.textFields["details.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(language == "fr" ? "Test des suggestions" : "Suggestion test")
        element(identifier: "asset-step.heading", in: app).tap()
        app.buttons["characteristics.continue"].tap()

        let seller = app.textFields["details.seller"]
        reveal(seller, in: app)
        seller.tap()
        XCTAssertTrue(
            element(identifier: "details.seller.suggestions", in: app)
                .waitForExistence(timeout: 5)
        )
        seller.typeText("auro")
        let sellerSuggestion = app.buttons["Maison Aurore"]
        XCTAssertTrue(sellerSuggestion.waitForExistence(timeout: 5))
        sellerSuggestion.tap()
        XCTAssertEqual(String(describing: seller.value), "Maison Aurore")
        XCTAssertTrue(waitForDisappearance(of: app.keyboards.firstMatch))

        let storage = app.textFields["details.storage-location"]
        reveal(storage, in: app)
        storage.tap()
        let storageSuggestion = app.buttons["Coffre privé"]
        XCTAssertTrue(storageSuggestion.waitForExistence(timeout: 5))
        storageSuggestion.tap()
        XCTAssertEqual(String(describing: storage.value), "Coffre privé")

        app.buttons["asset-flow.cancel"].tap()
        let discard = app.buttons[language == "fr" ? "Abandonner" : "Discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertStep(
        _ number: Int,
        screenIdentifier: String,
        language: String,
        in app: XCUIApplication
    ) {
        XCTAssertTrue(element(identifier: screenIdentifier, in: app).waitForExistence(timeout: 5))

        let progress = element(identifier: "asset-flow.progress", in: app)
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let expectedLabel = language == "fr"
            ? "Étape \(number) sur 6"
            : "Step \(number) of 6"
        XCTAssertEqual(progress.label, expectedLabel)
    }

    @MainActor
    private func selectCurrency(_ code: String, in app: XCUIApplication) {
        let picker = app.buttons["details.currency"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()

        for supportedCode in ["EUR", "USD", "CHF", "GBP"] {
            XCTAssertTrue(currencyOption(supportedCode, in: app).waitForExistence(timeout: 5))
        }
        XCTAssertFalse(currencyOption("JPY", in: app).exists)

        let option = currencyOption(code, in: app)
        XCTAssertTrue(option.isHittable)
        option.tap()

        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let selectedValue = "\(picker.label) \(String(describing: picker.value))"
        XCTAssertTrue(selectedValue.contains(code))
    }

    @MainActor
    private func assertKeyboardDismissal(in app: XCUIApplication) {
        let weight = app.textFields["details.weight"]
        reveal(weight, in: app)
        XCTAssertTrue(weight.isHittable)

        weight.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        let heading = element(identifier: "asset-step.heading", in: app)
        XCTAssertTrue(heading.isHittable)
        heading.tap()
        XCTAssertTrue(waitForDisappearance(of: app.keyboards.firstMatch))

        weight.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.keyboards.firstMatch.exists)
    }

    @MainActor
    private func currencyOption(_ code: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "label == %@ OR label ENDSWITH %@", code, " \(code)"))
            .firstMatch
    }

    @MainActor
    private func element(identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    @MainActor
    private func launchAtHome(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KARAUseInMemoryStore",
            "-KARAShowOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "fr" ? "fr_FR" : "en_US",
        ]
        app.launch()

        let action = app.buttons["onboarding.primary.action"]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        action.tap()
        XCTAssertTrue(
            waitForLabel(language == "fr" ? "Continuer" : "Continue", on: action)
        )
        action.tap()
        XCTAssertTrue(
            waitForLabel(
                language == "fr" ? "Ajouter mon premier objet" : "Add my first item",
                on: action
            )
        )
        action.tap()

        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        return app
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

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !element.isHittable {
            app.swipeUp()
        }
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        // NavigationStack exposes the destination before its native transition has
        // fully settled. Keep visual QA captures out of that transition frame.
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
