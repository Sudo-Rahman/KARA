import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPrimaryButtonCompletesAllFiveActsInFrench() {
        let app = launch(language: "fr")
        let action = app.buttons["onboarding.primary.action"]

        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertEqual(action.label, "Découvrir KARA")
        action.tap()

        XCTAssertTrue(waitForLabel("Continuer", on: action))
        action.tap()

        XCTAssertTrue(waitForLabel("Continuer", on: action))
        action.tap()

        XCTAssertTrue(waitForLabel("Continuer", on: action))
        action.tap()

        XCTAssertTrue(waitForLabel("Ouvrir mon coffre", on: action))
        action.tap()

        XCTAssertTrue(
            app.buttons["home.add"].waitForExistence(timeout: 10)
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
        XCTAssertTrue(app.staticTexts["Chaque objet,"].exists)
        XCTAssertTrue(app.staticTexts["parfaitement documenté."].exists)
    }

    @MainActor
    func testEnglishLocalizationAndCompletionPersistence() {
        let app = launch(language: "en")
        let action = app.buttons["onboarding.primary.action"]

        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your collection."].exists)
        XCTAssertTrue(app.staticTexts["Down to every detail."].exists)
        action.tap()
        XCTAssertTrue(waitForLabel("Continue", on: action))
        action.tap()
        XCTAssertTrue(waitForLabel("Continue", on: action))
        action.tap()
        XCTAssertTrue(waitForLabel("Continue", on: action))
        action.tap()
        XCTAssertTrue(waitForLabel("Open my vault", on: action))
        action.tap()
        XCTAssertTrue(
            app.buttons["home.add"].waitForExistence(timeout: 10)
        )

        app.terminate()
        app.launchArguments = [
            "-KARAUseInMemoryStore",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        XCTAssertTrue(
            app.buttons["home.add"].waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.buttons["onboarding.primary.action"].exists)
    }

    @MainActor
    func testVisibleSkipOpensTheDashboard() {
        let app = launch(language: "fr")
        let skip = app.buttons["onboarding.skip"]

        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()

        XCTAssertTrue(
            app.buttons["home.add"].waitForExistence(timeout: 10)
        )
    }

    @MainActor
    func testPermissionPageExposesAllThreeSetupItems() {
        let app = launch(language: "fr")
        let pager = app.scrollViews["onboarding.pager"]

        XCTAssertTrue(pager.waitForExistence(timeout: 10))
        pager.swipeLeft()
        pager.swipeLeft()
        pager.swipeLeft()

        let camera = app.descendants(matching: .any)[
            "onboarding.permissions.camera"
        ]
        let notifications = app.descendants(matching: .any)[
            "onboarding.permissions.notifications"
        ]
        let appLock = app.descendants(matching: .any)[
            "onboarding.permissions.appLock"
        ]

        XCTAssertTrue(
            camera.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(notifications.exists)
        XCTAssertTrue(appLock.exists)
    }

    @MainActor
    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KARAUseInMemoryStore",
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
