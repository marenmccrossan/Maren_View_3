//
//  WCSessionManager.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.

import Foundation
import WatchConnectivity
import Combine

class PhoneHeartRateObservable: ObservableObject {
    @Published var heartRate: Double = 0
}

class WCSessionManager: NSObject, WCSessionDelegate {
    static let shared = WCSessionManager()

    let heartRateObservable = HeartRateObservable()
    
    class AccelerometerObservable: ObservableObject {
        @Published var accel: [Double] = [0, 0, 0]
    }
    
    let accelerometerObservable = AccelerometerObservable()

    private override init() {
        super.init()
        activateSession()
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { print("WCSession activation failed:", error) }
        else { print("WCSession activated on iPhone:", activationState.rawValue) }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let bpm = message["heartRate"] as? Double {
            DispatchQueue.main.async { self.heartRateObservable.heartRate = bpm }
            print("Received HR on iPhone:", bpm)
        }
        if let accel = message["accel"] as? [Double], accel.count == 3 {
            DispatchQueue.main.async {
                self.accelerometerObservable.accel = accel
            }
            print("Received accel on iPhone:", accel)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let bpm = userInfo["heartRate"] as? Double {
            DispatchQueue.main.async {
                self.heartRateObservable.heartRate = bpm
            }
            print("Received HR on iPhone via userInfo:", bpm)
        }
        if let accel = userInfo["accel"] as? [Double], accel.count == 3 {
            DispatchQueue.main.async {
                self.accelerometerObservable.accel = accel
            }
            print("Received accel on iPhone via userInfo:", accel)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let bpm = applicationContext["heartRate"] as? Double {
            DispatchQueue.main.async {
                self.heartRateObservable.heartRate = bpm
            }
            print("Received HR on iPhone via appContext:", bpm)
        }
        if let accel = applicationContext["accel"] as? [Double], accel.count == 3 {
            DispatchQueue.main.async {
                self.accelerometerObservable.accel = accel
            }
            print("Received accel on iPhone via appContext:", accel)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}


