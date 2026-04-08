//
//  HeartRateManager.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//



import Foundation
import Combine
import WatchConnectivity
import HealthKit

@MainActor
class HeartRateManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var heartRate: Double = 0

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?

    override init() {
        super.init()
        activateSession()
        requestHealthKitAuthorization()
    }

    // MARK: - WCSession
    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        } else {
            print("WCSession activated: \(activationState.rawValue)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let bpm = message["heartRate"] as? Double {
            heartRate = bpm
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let bpm = applicationContext["heartRate"] as? Double {
            heartRate = bpm
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let bpm = userInfo["heartRate"] as? Double {
            Task { @MainActor in
                self.heartRate = bpm
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}

    // MARK: - HealthKit Authorization
    func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("Health data unavailable or heart rate type missing.")
            return
        }

        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: [heartRateType])
                let status = healthStore.authorizationStatus(for: heartRateType)
                if status == .sharingAuthorized {
                    print("HealthKit authorized")
                    startHeartRateMonitoring()
                } else {
                    print("Heart rate permission not granted.")
                }
            } catch {
                print("HealthKit authorization failed: \(error)")
            }
        }
    }

    // MARK: - HealthKit Query
    func startHeartRateMonitoring() {
        guard heartRateQuery == nil else { return }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)

        // Initial fetch closure
        let query = HKAnchoredObjectQuery(type: heartRateType,
                                          predicate: predicate,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit) { _, samples, _, _, error in
            if let error = error {
                print("Initial heart rate fetch error: \(error.localizedDescription)")
                return
            }
            // ✅ Swift 6-safe MainActor call
            Task { @MainActor in
                self.processHeartRateSamples(samples)
            }
        }

        // Update handler
        query.updateHandler = { _, samples, _, _, _ in
            Task { @MainActor in
                self.processHeartRateSamples(samples)
            }
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample], !heartRateSamples.isEmpty else { return }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        for sample in heartRateSamples {
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            // Already on MainActor via Task, safe to update @Published
            heartRate = bpm
            sendHeartRateToWatch(bpm: bpm)
        }
    }

    // MARK: - Send HR to Watch (optional)
    private func sendHeartRateToWatch(bpm: Double) {
        let session = WCSession.default
        guard session.isReachable else { return }
        session.sendMessage(["heartRate": bpm], replyHandler: nil) { error in
            print("Error sending HR to watch: \(error.localizedDescription)")
        }
    }
}

