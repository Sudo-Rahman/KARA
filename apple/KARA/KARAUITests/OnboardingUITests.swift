import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPrimaryButtonCompletesAllThreeActsInFrench() {
        let app = launch(language: "fr")
        let action = app.buttons["onboarding.primary.action"]

        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertEqual(action.label, "Commencer")
        action.tap()

        XCTAssertTrue(waitForLabel("Continuer", on: action))
        action.tap()

        XCTAssertTrue(waitForLabel("Ajouter mon premier objet", on: action))
        action.tap()

        XCTAssertTrue(
            app.buttons["handoff.replay"].waitForExistence(timeout: 10)
        )
    }

    @MainActor
    func testHorizontalSwipeKeepsActionInSync() {
        let app = launch(language: "fr")
        let pager = app.scrollViews["onboarding.pager"]
        let action = app.buttons["onboarding.primary.action"]

        XCTAssertTrue(pager.waitForExistence(timeout: 10))
        pager.swipeLeft()

        XCTAssertTrue(waitForLabel("Continuer", on: action))
        XCTAssertTrue(app.staticTexts["Chaque objet"].exists)
        XCTAssertTrue(app.staticTexts["trouve sa place."].exists)
    }

    @MainActor
    func testEnglishLocalizationAndCompletionPersistence() {
        let app = launch(language: "en")
        let action = app.buttons["onboarding.primary.action"]

        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Know what\nyou hold."].exists)
        XCTAssertTrue(app.staticTexts["See what it’s worth."].exists)
        action.tap()
        XCTAssertTrue(waitForLabel("Continue", on: action))
        action.tap()
        XCTAssertTrue(waitForLabel("Add my first item", on: action))
        action.tap()
        XCTAssertTrue(
            app.buttons["handoff.replay"].waitForExistence(timeout: 10)
        )

        app.terminate()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["handoff.replay"].waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.buttons["onboarding.primary.action"].exists)
    }

    @MainActor
    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KARAResetOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "fr" ? "fr_FR" : "en_US",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
