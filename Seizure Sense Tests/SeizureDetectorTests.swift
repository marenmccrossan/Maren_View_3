import XCTest
@testable import Seizure_Sense

@MainActor
final class SeizureDetectorTests: XCTestCase {

    var detector: SeizureDetector!

    override func setUp() {
        super.setUp()
        detector = SeizureDetector()
        
        // 1. Set the Motion Threshold to 1.0 (Violent Shaking baseline)
        detector.motionSpikeThreshold = 1.0
        
        // 2. Set the Adaptive (Spike) Threshold to 10 bpm
        detector.hrSpikeRiseThreshold = 10
        
        detector.hrBaselineWindow = 5
        detector.coincidenceWindow = 10
    }

    override func tearDown() {
        detector = nil
        // Clear UserDefaults to ensure a clean slate for the next test
        UserDefaults.standard.removeObject(forKey: "baselineHR")
        super.tearDown()
    }

    // MARK: - Test 1: Absolute Threshold (HR 110 + Violent Shaking)
    func testTriggersOnAbsoluteThresholdWithViolentShaking() {
        let callbackExpectation = expectation(description: "Triggered on Absolute HR 110")
        
        detector.onSeizureDetected = {
            callbackExpectation.fulfill()
        }

        // Set the user's absolute baseline threshold in UserDefaults to 110
        UserDefaults.standard.set(110, forKey: "baselineHR")

        // Action: Heart rate hits exactly 110, and motion hits 1.5g (Violent)
        detector.ingestHeartRate(110)
        detector.ingestMotionMagnitude(1.5)

        wait(for: [callbackExpectation], timeout: 1.0)
        XCTAssertTrue(detector.seizureDetected)
    }

    // MARK: - Test 2: Adaptive Threshold (Spike + Violent Shaking)
    func testTriggersOnAdaptiveSpikeWithViolentShaking() {
        let callbackExpectation = expectation(description: "Triggered on Adaptive HR Spike")
        
        detector.onSeizureDetected = {
            callbackExpectation.fulfill()
        }

        // 1. Establish a steady resting baseline of 70 bpm
        for _ in 0..<10 {
            detector.ingestHeartRate(70)
        }

        // 2. Sudden Spike: 70 -> 85 (A 15bpm rise, which exceeds our 10bpm threshold)
        detector.ingestHeartRate(85)
        
        // 3. Concurrent Violent Shaking
        detector.ingestMotionMagnitude(1.2)

        wait(for: [callbackExpectation], timeout: 1.0)
        XCTAssertTrue(detector.seizureDetected)
    }

    // MARK: - Test 3: Safety Check (No False Alarm on Gravity)
    func testDoesNotTriggerOnNormalMovementWithoutHRSpike() {
        let inverted = expectation(description: "Should NOT trigger")
        inverted.isInverted = true

        detector.onSeizureDetected = {
            inverted.fulfill()
        }

        // Steady HR
        detector.ingestHeartRate(75)
        
        // Moderate motion (0.8g) - below our 1.0g threshold
        detector.ingestMotionMagnitude(0.8)

        wait(for: [inverted], timeout: 0.5)
        XCTAssertFalse(detector.seizureDetected)
    }
}
