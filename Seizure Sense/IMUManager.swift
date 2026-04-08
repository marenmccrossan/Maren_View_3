//
//  IMUManager.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//

import Foundation
import CoreMotion
import Combine

final class IMUManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    // Published accelerometer values: [x, y, z]
    @Published var accel: [Double] = [0, 0, 0]

    init() {
        queue.name = "IMUManager.MotionQueue"
        queue.qualityOfService = .userInteractive
    }

    func startAccelerometers() {
        guard motionManager.isAccelerometerAvailable else { return }
        // 50 Hz update (adjust as needed)
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0

        motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self else { return }
            if let a = data?.acceleration {
                let values = [a.x, a.y, a.z]
                DispatchQueue.main.async {
                    self.accel = values
                }
            }
        }
    }

    func stopAccelerometers() {
        motionManager.stopAccelerometerUpdates()
    }
}
