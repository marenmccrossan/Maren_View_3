//
//  MotionReader 2.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//
import Foundation
import CoreMotion
import Combine

/// A simple motion reader that exposes accelerometer data
/// as a published [Double] of x, y, z values.
final class MotionReader: ObservableObject {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    @Published var accel: [Double] = [0, 0, 0]

    deinit {
        stopAccelerometers()
    }

    /// Starts accelerometer updates at a reasonable update interval.
    func startAccelerometers() {
        guard motionManager.isAccelerometerAvailable else { return }
        // Configure update interval (e.g., 50 Hz)
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            // Publish on main thread for UI updates
            DispatchQueue.main.async {
                self.accel = [x, y, z]
            }
        }
    }

    /// Stops accelerometer updates.
    func stopAccelerometers() {
        motionManager.stopAccelerometerUpdates()
    }
}

