//
//  IMUManager.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//


import Foundation
import CoreMotion
import SwiftUI
import Combine
import WatchConnectivity

@MainActor
class IMUManager: NSObject, ObservableObject, WCSessionDelegate {
    let motion = CMMotionManager()
    @Published var accel: [Double] = [0.0, 0.0, 0.0]
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func startAccelerometers() {
        guard motion.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }

        print("Accelerometer is available!")
        motion.accelerometerUpdateInterval = 1.0 / 60.0 // 60 Hz

        motion.startAccelerometerUpdates(to: OperationQueue.current ?? .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            self.accel = [data.acceleration.x, data.acceleration.y, data.acceleration.z]
            
            let session = WCSession.default
            if session.isReachable {
                session.sendMessage(["accel": self.accel], replyHandler: nil, errorHandler: nil)
            }
        }
    }

    func stopAccelerometers() {
        motion.stopAccelerometerUpdates()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
}

