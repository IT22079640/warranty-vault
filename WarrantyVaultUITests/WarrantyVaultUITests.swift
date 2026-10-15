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
        app.launchArguments.append("-skipOnboarding")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Vault"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Add"].exists)
        XCTAssertTrue(tabBar.buttons["Insights"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
    }

    /// Records how long the app takes to launch.
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
