//
//  WarrantyVaultUITests.swift
//  WarrantyVaultUITests
//
//  Created by Ama Hitiarachchi  on 2026-10-12.
//

import XCTest

final class WarrantyVaultUITests: XCTestCase {

    /// Stops the test at the first failure.
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    /// Reserved for cleanup after each UI test.
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Confirms the four primary tabs are available after launch.
    @MainActor
    func testMainTabsExist() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetVault"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Vault"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Add"].exists)
        XCTAssertTrue(tabBar.buttons["Insights"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
    }

    /// Pages through the introduction once, then opens straight to the vault on the next launch.
    @MainActor
    func testOnboardingIsShownOnce() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetOnboarding", "-resetVault"]
        app.launch()

        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        let importPage = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Import a receipt'")
        ).firstMatch
        XCTAssertTrue(importPage.waitForExistence(timeout: 3))
        next.tap()
        let start = app.buttons["Get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()
        XCTAssertTrue(app.tabBars.buttons["Vault"].waitForExistence(timeout: 5))

        app.terminate()
        let relaunch = XCUIApplication()
        relaunch.launchArguments = ["-resetVault"]
        relaunch.launch()
        XCTAssertTrue(relaunch.tabBars.buttons["Vault"].waitForExistence(timeout: 5))
        XCTAssertFalse(relaunch.buttons["Next"].exists)
    }

    /// Types a warranty and finds it in the vault.
    @MainActor
    func testAddItemManually() throws {
        let app = launch()
        app.tabBars.buttons["Add"].tap()
        let manual = app.buttons["add.enterManually"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()

        let name = app.textFields["add.productName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Kettle")
        let amount = app.textFields["add.amount"]
        amount.tap()
        amount.typeText("49.50")
        if app.buttons["add.keyboardDone"].exists {
            app.buttons["add.keyboardDone"].tap()
        }
        app.buttons["add.save"].tap()

        XCTAssertTrue(app.staticTexts["Warranty saved."].waitForExistence(timeout: 5))
        app.tabBars.buttons["Vault"].tap()
        XCTAssertTrue(row("Kettle", in: app).waitForExistence(timeout: 5))
    }

    /// The expired chip hides an active warranty and shows the expired one.
    @MainActor
    func testFilterVault() throws {
        let app = launch(arguments: ["-skipOnboarding", "-seedVault"])
        XCTAssertTrue(row("Active Lamp", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("Expired Fan", in: app).exists)

        app.buttons["vault.filter.expired"].tap()
        XCTAssertTrue(row("Expired Fan", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Active Lamp", in: app).exists)

        app.buttons["vault.filter.active"].tap()
        XCTAssertTrue(row("Active Lamp", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Expired Fan", in: app).exists)
    }

    /// Deletes a seeded warranty from the vault.
    @MainActor
    func testDeleteItem() throws {
        let app = launch(arguments: ["-skipOnboarding", "-seedVault"])
        let lamp = row("Active Lamp", in: app)
        XCTAssertTrue(lamp.waitForExistence(timeout: 5))
        lamp.press(forDuration: 1.0)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertFalse(row("Active Lamp", in: app).waitForExistence(timeout: 3))
    }

    /// A vault row whose spoken label starts with the product name.
    @MainActor
    private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", name)
        ).firstMatch
    }

    /// Launches past the introduction with a clean or seeded vault.
    @MainActor
    private func launch(arguments: [String] = ["-skipOnboarding", "-resetVault"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Vault"].waitForExistence(timeout: 5))
        return app
    }

    /// Records how long the app takes to launch.
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding"]
            app.launch()
        }
    }
}
