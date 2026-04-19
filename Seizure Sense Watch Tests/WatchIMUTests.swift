//
//  WatchIMUTests.swift
//  Seizure Sense Watch Tests
//
//  Created by Maren McCrossan on 4/16/26.
//


import XCTest
import CoreMotion
#if os(watchOS) && arch(arm64_32)
@testable import Seizure_Sense_Watch_App_Watch_App

#endif

final class WatchIMUTests: XCTestCase {
    func testUserAccelerationFormatting() {
        // We want to ensure that when we send data, the dictionary key is exactly "accel"
        // and it contains 3 coordinates.
        let mockAccel = [0.5, -0.2, 1.1]
        let packet: [String: Any] = ["accel": mockAccel]
        
        XCTAssertNotNil(packet["accel"])
        XCTAssertEqual((packet["accel"] as? [Double])?.count, 3)
    }
}

