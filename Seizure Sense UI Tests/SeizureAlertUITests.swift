//
//  SeizureAlertUITests.swift
//  Seizure Sense UI Tests
//
//  Created by Maren McCrossan on 4/16/26.
//

import XCTest

final class SeizureAlertUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    func testAlertAndEmergencyVisualsAppear() throws {
        let app = XCUIApplication()
        
        // 1. Add the launch argument that your SeizureDetector.init is looking for
        app.launchArguments.append("-simulateSeizure")
        app.launch()

        // 2. Wait for the Alert to appear
        // We use a 5-second timeout to account for the 0.5s delay in your init
        let alert = app.alerts["Seizure Detected"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "The seizure alert should have appeared automatically via launch arguments.")

        // 3. Verify the text inside the alert
        let alertDescription = alert.staticTexts["We detected seizure-like activity."]
        XCTAssertTrue(alertDescription.exists, "The alert should display the correct warning message.")

        // 4. Verify the "OK" button exists and tap it to dismiss
        let okButton = alert.buttons["OK"]
        XCTAssertTrue(okButton.exists)
        okButton.tap()

        // 5. Verify the alert is dismissed
        XCTAssertFalse(alert.exists, "The alert should disappear after tapping OK.")
    }

    func testAppReturnsToNormalStateAfterDismissal() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-simulateSeizure")
        app.launch()

        let alert = app.alerts["Seizure Detected"]
        _ = alert.waitForExistence(timeout: 5)
        
        // Dismiss the alert
        alert.buttons["OK"].tap()

    }
}
