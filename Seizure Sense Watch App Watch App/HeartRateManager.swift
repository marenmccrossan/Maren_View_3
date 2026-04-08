//
//  HeartRateManager.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//

import Foundation
import HealthKit
import Combine
import WatchConnectivity

@MainActor
class HeartRateManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var heartRate: Double = 0

    private let healthStore = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

    private var observerQuery: HKObserverQuery?
    private let anchorKey = "HRAnchorKey"

    override init() {
        super.init()
        activateSession()
        requestAuthorization()
    }

    // MARK: - WatchConnectivity
    private func activateSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { print("WCSession activation failed:", error) }
        else { print("WCSession activated on Watch:", activationState.rawValue) }
    }

    // MARK: - HealthKit Authorization
    private func requestAuthorization() {
        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: [heartRateType])
                startQuery()
                enableBackgroundDeliveryAndObserver()
            } catch {
                print("HealthKit authorization failed:", error)
            }
        }
    }

    // MARK: - Heart Rate Query
    private func startQuery() {
        query = HKAnchoredObjectQuery(type: heartRateType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            let samplesCopy = samples
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.handle(samples: samplesCopy)
            }
        }

        query?.updateHandler = { [weak self] _, samples, _, _, _ in
            let samplesCopy = samples
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.handle(samples: samplesCopy)
            }
        }

        if let query = query {
            healthStore.execute(query)
        }
    }

    private func handle(samples: [HKSample]?) {
        guard let sample = samples?.last as? HKQuantitySample else { return }
        let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        heartRate = bpm
        sendToPhoneBackground(bpm: bpm)
        print("Watch HR:", bpm)
    }

    private func sendToPhone(bpm: Double) {
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(["heartRate": bpm], replyHandler: nil)
        }
    }

    private func loadAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: anchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor?) {
        guard let anchor else { return }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: anchorKey)
        }
    }

    private func enableBackgroundDeliveryAndObserver() {
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                print("BG delivery error:", error)
            } else {
                print("BG delivery enabled:", success)
            }
        }

        let observer = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completion, error in
            guard let strongSelf = self else { completion(); return }
            Task { @MainActor in
                strongSelf.fetchNewHeartRateSamples {
                    completion()
                }
            }
        }
        observerQuery = observer
        healthStore.execute(observer)

        // Do an initial fetch on launch so we have a value even before the first observer wakeup
        fetchNewHeartRateSamples(completion: {})
    }

    private func fetchNewHeartRateSamples(completion: @escaping () -> Void) {
        let currentAnchor = loadAnchor()
        let anchored = HKAnchoredObjectQuery(type: heartRateType, predicate: nil, anchor: currentAnchor, limit: HKObjectQueryNoLimit) { [weak self] _, samples, deletedObjects, newAnchor, error in
            defer { completion() }
            guard let strongSelf = self else { return }
            if let error = error {
                print("Anchored fetch error:", error)
                return
            }
            if let newAnchor = newAnchor {
                Task { @MainActor in
                    strongSelf.saveAnchor(newAnchor)
                }
            }
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            if let last = samples.last {
                let bpm = last.quantity.doubleValue(for: bpmUnit)
                Task { @MainActor in
                    strongSelf.heartRate = bpm
                    strongSelf.sendToPhoneBackground(bpm: bpm)
                    print("Watch HR (BG):", bpm)
                }
            }
        }
        healthStore.execute(anchored)
    }

    private func sendToPhoneBackground(bpm: Double) {
        let session = WCSession.default
        session.transferUserInfo(["heartRate": bpm])
        if session.isReachable {
            session.sendMessage(["heartRate": bpm], replyHandler: nil)
        }
    }

    deinit {
        if let q = query { healthStore.stop(q) }
        if let o = observerQuery { healthStore.stop(o) }
    }
}


