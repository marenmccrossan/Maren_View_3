//
//  NotificationLogicTests.swift
//  Seizure Sense Tests
//
//  Created by Maren McCrossan on 4/16/26.
//

import XCTest
@testable import Seizure_Sense

final class NotificationLogicTests: XCTestCase {
    func testNotificationTriggers() {
        let detector = SeizureDetector()
        let expectation = expectation(description: "Closure called")
        
        detector.onSeizureDetected = {
            expectation.fulfill()
        }
        
        // Simulate high HR and Motion to trigger your logic
        detector.ingestHeartRate(150)
        detector.ingestMotionMagnitude(4.0)
        
        waitForExpectations(timeout: 2)
    }
}
