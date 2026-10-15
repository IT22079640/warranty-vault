//
//  WarrantyVaultUITestsLaunchTests.swift
//  WarrantyVaultUITests
//
//  Created by Ama Hitiarachchi  on 2026-10-12.
//
//  Screenshot captured the first time the app launches in a UI test.
//

import XCTest

/// Records a launch screenshot. It does not drive the warranty flows.
final class WarrantyVaultUITestsLaunchTests: XCTestCase {

    /// Runs once for each appearance the test plan enables.
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    /// Stops the test at the first failure.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app and keeps a screenshot of the first screen.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
