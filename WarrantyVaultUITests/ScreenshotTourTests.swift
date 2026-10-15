//
//  ScreenshotTourTests.swift
//  WarrantyVaultUITests
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Photographs every screen for the report. Run with parallel testing turned off.
//

import XCTest

/// One pass through the app in a single appearance, orientation, and text size.
final class ScreenshotTourTests: XCTestCase {

    /// Stops the tour at the first missing screen.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Leaves the simulator upright for the next test class.
    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// Light appearance, portrait.
    @MainActor
    func testLightPortrait() throws {
        try runTour(appearance: "Light", orientation: .portrait, accessibilitySize: false, suffix: "light_portrait")
    }

    /// Dark appearance, portrait.
    @MainActor
    func testDarkPortrait() throws {
        try runTour(appearance: "Dark", orientation: .portrait, accessibilitySize: false, suffix: "dark_portrait")
    }

    /// Light appearance, landscape.
    @MainActor
    func testLightLandscape() throws {
        try runTour(appearance: "Light", orientation: .landscapeLeft, accessibilitySize: false, suffix: "light_landscape")
    }

    /// Dark appearance, landscape.
    @MainActor
    func testDarkLandscape() throws {
        try runTour(appearance: "Dark", orientation: .landscapeLeft, accessibilitySize: false, suffix: "dark_landscape")
    }

    /// Light appearance, portrait, largest accessibility text size.
    @MainActor
    func testLightPortraitAccessibility() throws {
        try runTour(
            appearance: "Light",
            orientation: .portrait,
            accessibilitySize: true,
            suffix: "light_portrait_accessibility"
        )
    }

    /// Visits every screen and stores one attachment per stop.
    @MainActor
    private func runTour(
        appearance: String,
        orientation: UIDeviceOrientation,
        accessibilitySize: Bool,
        suffix: String
    ) throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = orientation

        launch(
            app,
            arguments: ["-resetOnboarding", "-resetVault"],
            appearance: appearance,
            accessibilitySize: accessibilitySize
        )
        settle(orientation)
        captureOnboarding(app, suffix: suffix)
        app.terminate()

        launch(
            app,
            arguments: ["-skipOnboarding", "-resetVault"],
            appearance: appearance,
            accessibilitySize: accessibilitySize
        )
        settle(orientation)
        waitForTab("Vault", in: app)
        shot(app, "04_vault_empty_\(suffix)", after: "screen.vault.empty")
        app.tabBars.buttons["Insights"].tap()
        shot(app, "23_insights_empty_\(suffix)", after: "screen.insights.empty")
        app.terminate()

        launch(
            app,
            arguments: ["-skipOnboarding", "-seedVault"],
            appearance: appearance,
            accessibilitySize: accessibilitySize
        )
        settle(orientation)
        try captureSeededVault(app, appearance: appearance, suffix: suffix)
        app.terminate()

        launch(
            app,
            arguments: ["-skipOnboarding", "-resetVault"],
            appearance: appearance,
            accessibilitySize: accessibilitySize
        )
        settle(orientation)
        try captureReceiptFlow(app, suffix: suffix)
        app.terminate()

        launch(
            app,
            arguments: ["-skipOnboarding", "-resetVault"],
            appearance: appearance,
            accessibilitySize: accessibilitySize
        )
        settle(orientation)
        captureManualValidation(app, suffix: suffix)
    }

    /// Pages 1, 2, and 3 of the introduction.
    @MainActor
    private func captureOnboarding(_ app: XCUIApplication, suffix: String) {
        XCTAssertTrue(page("Every warranty in one place", in: app).waitForExistence(timeout: 8))
        shot(app, "01_onboarding_page1_\(suffix)")
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        if !isOnScreen(next, in: app) {
            app.swipeUp()
        }
        next.tap()
        XCTAssertTrue(page("Import a receipt", in: app).waitForExistence(timeout: 4))
        shot(app, "02_onboarding_page2_\(suffix)")
        next.tap()
        XCTAssertTrue(page("A reminder before it ends", in: app).waitForExistence(timeout: 4))
        shot(app, "03_onboarding_page3_\(suffix)")
    }

    /// An introduction page. Its title and message are one accessibility element.
    @MainActor
    private func page(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", title)
        ).firstMatch
    }

    /// List, search, filters, swipe, menu, detail, zoom, edit, grid, insights, and settings.
    @MainActor
    private func captureSeededVault(_ app: XCUIApplication, appearance: String, suffix: String) throws {
        waitForTab("Vault", in: app)
        let lamp = row("Active Lamp", in: app)
        XCTAssertTrue(lamp.waitForExistence(timeout: 8))
        shot(app, "05_vault_list_\(suffix)")

        search(app, for: "Lamp")
        XCTAssertTrue(row("Active Lamp", in: app).waitForExistence(timeout: 4))
        shot(app, "07_vault_search_\(suffix)")
        clearSearch(app)

        tap("vault.filter.all", in: app)
        shot(app, "08_vault_filter_all_\(suffix)", after: "vault.filter.all")
        tap("vault.filter.active", in: app)
        shot(app, "09_vault_filter_active_\(suffix)")
        tap("vault.filter.expiringSoon", in: app)
        shot(app, "10_vault_filter_expiring_\(suffix)")
        tap("vault.filter.expired", in: app)
        shot(app, "11_vault_filter_expired_\(suffix)")
        tap("vault.filter.all", in: app)

        let seededLamp = row("Active Lamp", in: app)
        XCTAssertTrue(seededLamp.waitForExistence(timeout: 4))
        let topRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "vault.open.")
        ).element(boundBy: 0)
        XCTAssertTrue(topRow.waitForExistence(timeout: 4))
        topRow.swipeLeft()
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 3))
        shot(app, "12_vault_swipe_\(suffix)")
        topRow.swipeRight()

        seededLamp.press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["vault.menu.view"].waitForExistence(timeout: 3))
        shot(app, "13_vault_context_menu_\(suffix)")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()

        seededLamp.tap()
        let receipt = element("detail.receiptImage", in: app)
        XCTAssertTrue(receipt.waitForExistence(timeout: 8))
        reveal(receipt, in: app)
        shot(app, "14_item_detail_\(suffix)")
        receipt.doubleTap()
        Thread.sleep(forTimeInterval: 0.6)
        shot(app, "15_item_detail_zoomed_\(suffix)")

        tap("detail.edit", in: app)
        XCTAssertTrue(app.textFields["add.productName"].waitForExistence(timeout: 8))
        shot(app, "16_edit_form_\(suffix)")
        pop(app)
        pop(app)

        let layout = element("vault.layoutToggle", in: app)
        let layoutByLabel = app.buttons["Show as grid"]
        let layoutControl = layout.waitForExistence(timeout: 2) ? layout : layoutByLabel
        if !layoutControl.waitForExistence(timeout: 4) {
            let labels = app.navigationBars.buttons.allElementsBoundByIndex.map {
                "\($0.identifier)|\($0.label)"
            }
            XCTFail("Layout toggle was not on the vault. Nav buttons: \(labels.joined(separator: ", "))")
            return
        }
        layoutControl.tap()
        Thread.sleep(forTimeInterval: 0.4)
        shot(app, "06_vault_grid_\(suffix)", after: "vault.grid")

        app.tabBars.buttons["Insights"].tap()
        shot(app, "22_insights_\(suffix)", after: "screen.insights")

        app.tabBars.buttons["Settings"].tap()
        shot(app, "24_settings_\(suffix)", after: "screen.settings")
        overrideAppearance(awayFrom: appearance, in: app)
        Thread.sleep(forTimeInterval: 0.8)
        shot(app, "25_settings_appearance_\(suffix)")
        reveal(element("settings.clearAll", in: app), in: app)
        tap("settings.clearAll", in: app)
        XCTAssertTrue(element("settings.confirmClear", in: app).waitForExistence(timeout: 4))
        shot(app, "26_settings_clear_confirmation_\(suffix)")
        tap("settings.cancelClear", in: app)
    }

    /// Add tab, scanning state, amber review fields, and the recognized-text section.
    @MainActor
    private func captureReceiptFlow(_ app: XCUIApplication, suffix: String) throws {
        waitForTab("Vault", in: app)
        app.tabBars.buttons["Add"].tap()
        XCTAssertTrue(element("add.importReceipt", in: app).waitForExistence(timeout: 6))
        shot(app, "17_add_tab_\(suffix)")
        tap("add.importReceipt", in: app)
        XCTAssertTrue(element("add.scanStatus", in: app).waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.4)
        shot(app, "18_add_scanning_\(suffix)")
        XCTAssertTrue(app.textFields["add.productName"].waitForExistence(timeout: 25))
        let review = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier ENDSWITH '.review'")
        ).firstMatch
        XCTAssertTrue(review.waitForExistence(timeout: 6), "The sample receipt did not leave an uncertain field.")
        reveal(review, in: app)
        shot(app, "19_add_review_form_\(suffix)")
        reveal(element("add.recognizedText", in: app), in: app)
        tap("add.recognizedText", in: app)
        Thread.sleep(forTimeInterval: 0.4)
        shot(app, "20_add_recognized_text_\(suffix)")
    }

    /// Blank manual form after Save, with the validation messages showing.
    @MainActor
    private func captureManualValidation(_ app: XCUIApplication, suffix: String) {
        waitForTab("Vault", in: app)
        app.tabBars.buttons["Add"].tap()
        tap("add.enterManually", in: app)
        XCTAssertTrue(app.textFields["add.productName"].waitForExistence(timeout: 6))
        reveal(element("add.save", in: app), in: app)
        tap("add.save", in: app)
        XCTAssertTrue(element("add.productName.error", in: app).waitForExistence(timeout: 4))
        shot(app, "21_add_validation_errors_\(suffix)")
    }

    /// Starts the app with the sample receipt, appearance, and optional accessibility text size.
    @MainActor
    private func launch(
        _ app: XCUIApplication,
        arguments: [String],
        appearance: String,
        accessibilitySize: Bool
    ) {
        var launchArguments = arguments + ["-useSampleReceipt", "-AppleInterfaceStyle", appearance]
        if accessibilitySize {
            launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launchArguments = launchArguments
        app.launch()
    }

    /// Waits out the rotation animation.
    @MainActor
    private func settle(_ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        Thread.sleep(forTimeInterval: 1)
    }

    /// Waits until a tab is on screen.
    @MainActor
    private func waitForTab(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons[name].waitForExistence(timeout: 8))
    }

    /// Element with a stable identifier.
    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Scrolls until `element` can be tapped. Swipes down when the control is above the screen.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let bounds = app.frame.insetBy(dx: 1, dy: 8)
        var attempts = 0
        while attempts < 8 {
            guard element.exists else {
                app.swipeUp()
                attempts += 1
                continue
            }
            let frame = element.frame
            guard frame.width > 1, frame.height > 1, !frame.isNull, !frame.isInfinite else {
                Thread.sleep(forTimeInterval: 0.3)
                attempts += 1
                continue
            }
            let center = CGPoint(x: frame.midX, y: frame.midY)
            if bounds.contains(center) {
                return
            }
            if center.y > bounds.maxY {
                app.swipeUp()
            } else if center.y < bounds.minY {
                app.swipeDown()
            } else {
                return
            }
            attempts += 1
        }
    }

    /// Taps an identified control, scrolling it on screen first.
    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication) {
        let control = element(identifier, in: app)
        XCTAssertTrue(control.waitForExistence(timeout: 4), "Missing \(identifier)")
        if identifier.hasPrefix("vault.filter") {
            scrollFilters(untilVisible: control, in: app)
        } else {
            reveal(control, in: app)
        }
        control.tap()
        Thread.sleep(forTimeInterval: 0.4)
    }

    /// Slides the filter chips until `control` is fully inside the screen.
    @MainActor
    private func scrollFilters(untilVisible control: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while attempts < 8 && !isOnScreen(control, in: app) {
            dragFilterRow(control, in: app)
            attempts += 1
        }
    }

    /// Drags across the chip row. The scroll view's own frame sits above the chips, so the drag uses the chip's vertical center.
    @MainActor
    private func dragFilterRow(_ control: XCUIElement, in app: XCUIApplication) {
        let height = max(app.frame.height, 1)
        let rowY = control.exists ? control.frame.midY / height : 0.3
        let y = min(max(rowY, 0.05), 0.95)
        let towardStart = control.exists && control.frame.midX < 0
        let startX = towardStart ? 0.15 : 0.9
        let endX = towardStart ? 0.9 : 0.1
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: y))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: y))
        start.press(forDuration: 0.01, thenDragTo: end, withVelocity: XCUIGestureVelocity(2000), thenHoldForDuration: 0.15)
    }

    /// True when the element's center can be tapped. Avoids `isHittable`, which fails the test for an off-screen frame.
    @MainActor
    private func isOnScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else {
            return false
        }
        let frame = element.frame
        guard frame.width > 1, frame.height > 1, !frame.isNull, !frame.isInfinite else {
            return false
        }
        return app.frame.insetBy(dx: 1, dy: 1).contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    /// Types into the vault search field and hides the keyboard.
    @MainActor
    private func search(_ app: XCUIApplication, for text: String) {
        var field = app.searchFields["Search warranties"]
        if !field.waitForExistence(timeout: 2) {
            field = app.searchFields.firstMatch
        }
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText(text)
        Thread.sleep(forTimeInterval: 0.4)
    }

    /// Removes the current search text.
    @MainActor
    private func clearSearch(_ app: XCUIApplication) {
        let clear = app.searchFields.buttons["Clear text"]
        if clear.waitForExistence(timeout: 2), isOnScreen(clear, in: app) {
            clear.tap()
        } else if app.buttons["Clear text"].exists, isOnScreen(app.buttons["Clear text"], in: app) {
            app.buttons["Clear text"].tap()
        }
        let cancel = app.navigationBars.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 2), isOnScreen(cancel, in: app) {
            cancel.tap()
        }
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// A vault row whose spoken label starts with the product name.
    @MainActor
    private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", name)
        ).firstMatch
    }

    /// Pops the current screen, skipping the detail toolbar's share and edit buttons.
    @MainActor
    private func pop(_ app: XCUIApplication) {
        let bar = app.navigationBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 4))
        let back = bar.buttons.allElementsBoundByIndex.first { button in
            button.identifier != "detail.share" && button.identifier != "detail.edit"
        }
        XCTAssertNotNil(back)
        back?.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Selects the opposite of the launch appearance so the override is visible.
    @MainActor
    private func overrideAppearance(awayFrom appearance: String, in app: XCUIApplication) {
        chooseAppearance(appearance == "Dark" ? "Light" : "Dark", in: app)
    }

    /// Sets the appearance picker to System, Light, or Dark.
    @MainActor
    private func chooseAppearance(_ target: String, in app: XCUIApplication) {
        let expanded = app.buttons["settings.appearance.\(target.lowercased())"]
        if expanded.waitForExistence(timeout: 1) {
            reveal(expanded, in: app)
            expanded.tap()
            return
        }
        let picker = element("settings.appearance", in: app)
        reveal(picker, in: app)
        picker.tap()
        let choice = app.buttons[target]
        XCTAssertTrue(choice.waitForExistence(timeout: 4))
        choice.tap()
    }

    /// Saves a full-screen image. Waits for `identifier` first when one is given.
    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String, after identifier: String? = nil) {
        if let identifier {
            let marker = element(identifier, in: app)
            XCTAssertTrue(marker.waitForExistence(timeout: 8), "Missing \(identifier) for \(name)")
        }
        Thread.sleep(forTimeInterval: 0.35)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
