//
//  SeizureDetector.swift
//  Seizure Sense
//
//  Created by Maren McCrossan on 4/8/26.
//
import Foundation
import Combine

final class SeizureDetector: ObservableObject {
    // Inputs (latest values)
    @Published private(set) var seizureDetected: Bool = false

    enum DisplayState {
        case normalGreen
        case alarmingRedFlashing
        case steady
    }

    @Published var displayState: DisplayState = .normalGreen
    @Published var shouldFlash: Bool = false

    // Tuning (defaults aligned with ContentView)
    // Heart rate spike is measured against a short rolling baseline, not just the immediately previous value
    var hrSpikeRiseThreshold: Double = 10
    var hrBaselineWindow: TimeInterval = 8 // seconds of history to compute baseline

    // Absolute HR threshold trigger (immediate) reads from UserDefaults key "baselineHR"
    var hrAbsoluteThreshold: Double {
        let value = UserDefaults.standard.integer(forKey: "baselineHR")
        return value == 0 ? 100 : Double(value)
    }

    // Motion spike threshold (g magnitude or your chosen unit)
    var motionSpikeThreshold: Double = 0.8

    // Seizure detection requires HR and motion spikes to coincide within this window
    var coincidenceWindow: TimeInterval = 20

    // Stabilization monitoring (end the alert when HR variance calms down)
    var stabilizationVarianceThreshold: Double = 8
    var stabilizationSeconds: TimeInterval = 10

    // Internal state
    private var lastHRValue: Double? = nil
    private var lastHRSpike: Date?
    private var lastMotionSpike: Date?
    private var lastSeizureTrigger: Date?
    private var lastNotificationTime: Date?

    // HR history for baseline + stabilization
    private var points: [(date: Date, bpm: Double)] = []
    private var lastAppendDate: Date = .distantPast
    private let chartWindow: TimeInterval = 5 * 60
    private let minSamplesForStabilization = 5

    private var stabilizationTimer: Timer?
    private var suppressFlashingUntilNextTrigger: Bool = false
    private var cooldownUntil: Date? = nil

    // Callback for UI layer
    var onSeizureDetected: (() -> Void)?
    
    // MARK: - Initializer
    init(){
            if ProcessInfo.processInfo.arguments.contains("-simulateSeizure") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.triggerSeizure()
            }
        }
    }

    // MARK: - Public APIs to feed data
    func ingestHeartRate(_ bpm: Double) {
        let now = Date()
        guard bpm > 0 else { return }

        // Keep a rolling buffer for stabilization (not used for charting)
        if now.timeIntervalSince(lastAppendDate) >= 0.25 {
            points.append((date: now, bpm: bpm))
            lastAppendDate = now
            let cutoff = now.addingTimeInterval(-chartWindow)
            points = points.filter { $0.date >= cutoff }
        }

        // Baseline over recent window
        let baselineCutoff = now.addingTimeInterval(-hrBaselineWindow)
        let recentForBaseline = points.filter { $0.date >= baselineCutoff }
        let baselineMean: Double? = {
            guard !recentForBaseline.isEmpty else { return nil }
            let vals = recentForBaseline.map { $0.bpm }
            return vals.reduce(0, +) / Double(vals.count)
        }()

        // If heart rate is under rolling baseline, force steady green and no flashing
        if let baseline = baselineMean, bpm < baseline {
            if !seizureDetected {
                self.displayState = .normalGreen
                self.shouldFlash = false
            }
        }

        // Spike detection: compare to rolling baseline if available, otherwise to lastHRValue
        let reference = baselineMean ?? lastHRValue ?? bpm
        if bpm - reference >= hrSpikeRiseThreshold {
            lastHRSpike = now
            evaluateCombinedSpike()
        }

        lastHRValue = bpm

        if !seizureDetected {
            self.displayState = .normalGreen
            self.shouldFlash = false
        }
    }

    func ingestMotionMagnitude(_ magnitude: Double) {
        if magnitude >= motionSpikeThreshold {
            lastMotionSpike = Date()
            evaluateCombinedSpike()
        }
    }

    // MARK: - Detection
    private func evaluateCombinedSpike() {
        let now = Date()

        if let until = cooldownUntil, now < until { }

        // We consider a combined event if we have a recent motion spike and either:
        // 1) a detected HR spike timestamp, or
        // 2) current/last HR reading meets absolute threshold
        guard let motionTime = lastMotionSpike else { return }

        var candidateHRTime: Date?
        if let hrTime = lastHRSpike {
            candidateHRTime = hrTime
        } else if let lastHR = lastHRValue, lastHR >= hrAbsoluteThreshold {
            candidateHRTime = now
        }

        guard let hrTime = candidateHRTime else { return }

        let delta = abs(hrTime.timeIntervalSince(motionTime))
        guard delta <= coincidenceWindow else { return }

        // Prevent rapid retriggers within the coincidence window
        if let lastNotif = lastNotificationTime, now.timeIntervalSince(lastNotif) < 60 {
            return
        }

        triggerSeizure()
        lastSeizureTrigger = now
        lastNotificationTime = now
    }

    private func triggerSeizure() {
        //guard !seizureDetected else { return }
        DispatchQueue.main.async {
            if let until = self.cooldownUntil, Date() >= until {
                self.cooldownUntil = nil
            }
            self.seizureDetected = true
            self.displayState = .alarmingRedFlashing
            self.shouldFlash = true
            self.suppressFlashingUntilNextTrigger = false
            self.startStabilizationMonitor()
            self.onSeizureDetected?()
        }
    }

    private func startStabilizationMonitor() {
        DispatchQueue.main.async {
            self.stabilizationTimer?.invalidate()
            self.stabilizationTimer = Timer.scheduledTimer(withTimeInterval: 0.5,
                                                           repeats: true) { [weak self] _ in
                self?.evaluateStabilization()
            }
            RunLoop.main.add(self.stabilizationTimer!, forMode: .common)
        }
    }

    private func evaluateStabilization() {
        let now = Date()
        let recent = points.filter { now.timeIntervalSince($0.date) <= stabilizationSeconds }
        guard recent.count >= minSamplesForStabilization else { return }

        let values = recent.map { $0.bpm }
        let mean = values.reduce(0,+) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0,+) / Double(values.count)
        let stddev = sqrt(variance)

        if stddev <= stabilizationVarianceThreshold {
            stopAlert()
        }
    }

    func stopAlert() {
        DispatchQueue.main.async {
            self.stabilizationTimer?.invalidate()
            self.stabilizationTimer = nil
            self.seizureDetected = false
            self.shouldFlash = false
            self.displayState = .normalGreen
            self.suppressFlashingUntilNextTrigger = true
            self.cooldownUntil = Date().addingTimeInterval(60)
        }
    }
}


