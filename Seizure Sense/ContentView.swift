//
//  ContentView.swift
//
//  Created by Maren McCrossan on 2/25/26.
//
//

import SwiftUI
import Charts
import UserNotifications
import AudioToolbox

struct ContentView: View {
    
    // MARK: - Observables (from Watch)
    @ObservedObject private var heartRateObservable = WCSessionManager.shared.heartRateObservable
    @ObservedObject private var watchAccelObservable = WCSessionManager.shared.accelerometerObservable
    
    @EnvironmentObject var settings: AppSettings
    @State private var showSettings = false
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject private var detector = SeizureDetector()
    
    // MARK: - Detection State
    @State private var seizureDetected = false
    @State private var isFlashing = false
    @State private var flashOpacity: Double = 1.0
    @State private var lastHRSpike: Date?
    @State private var lastMotionSpike: Date?
    @State private var stabilizationTimer: Timer?
    @State private var showSeizureAlert = false
    
    // MARK: - Detection Tuning
    private let hrSpikeRiseThreshold: Double = 20
    private let coincidenceWindow: TimeInterval = 3
    private let stabilizationVarianceThreshold: Double = 8
    private let stabilizationSeconds: TimeInterval = 10
    
    // MARK: - Chart
    private struct HeartRatePoint: Identifiable {
        let id = UUID()
        let date: Date
        let bpm: Double
    }
    
    @State private var points: [HeartRatePoint] = []
    @State private var lastAppendDate: Date = .distantPast
    private let window: TimeInterval = 5 * 60
    
    private var adaptiveLightBlue: Color {
        let base = Color(red: 0.85, green: 0.92, blue: 1.0)
        return colorScheme == .dark ? base.opacity(0.25) : base
    }

    var body: some View {
        NavigationStack {
            ZStack {
                
                adaptiveLightBlue
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    
                    // MARK: - HR Display
                    Text("\(heartRateObservable.heartRate, specifier: "%.0f") BPM")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(10)
                        .background(
                            Group {
                                if detector.displayState == .alarmingRedFlashing {
                                    Color.red.opacity(detector.shouldFlash ? flashOpacity : 1.0)
                                } else {
                                    Color.green
                                }
                            }
                        )
                        .cornerRadius(12)
                    
                    Text("Heart Rate")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    // MARK: - Chart
                    Chart(points) { p in
                        LineMark(
                            x: .value("Time", p.date),
                            y: .value("BPM", p.bpm)
                        )
                        .interpolationMethod(.monotone)
                        
                        PointMark(
                            x: .value("Time", p.date),
                            y: .value("BPM", p.bpm)
                        )
                        .symbolSize(20)
                    }
                    .chartYScale(domain: 40...200)
                    .frame(height: 220)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground)
                            .opacity(colorScheme == .dark ? 0.35 : 0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.separator, lineWidth: 1)
                    )
                    
                    Text("Last 5 minutes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Divider().padding(.vertical, 8)
                    
                    // MARK: - Accelerometer
                    Text("Motion Monitor")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text(String(format: "x: %.3f  y: %.3f  z: %.3f",
                                accelValue(0),
                                accelValue(1),
                                accelValue(2)))
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground)
                                .opacity(colorScheme == .dark ? 0.35 : 0.9))
                        )
                    
                }
                .padding()
                .onChange(of: heartRateObservable.heartRate) { oldValue, newValue in
                    handleHeartRateUpdate(old: oldValue, new: newValue)
                    detector.ingestHeartRate(newValue)
                }
                .onChange(of: watchAccelObservable.accel) { _, newValue in
                    handleMotionUpdate(newValue)
                    let mag = sqrt(newValue.map { $0 * $0 }.reduce(0,+))
                    detector.ingestMotionMagnitude(mag)
                }
                .onChange(of: detector.shouldFlash) { _, newValue in
                    if !newValue {
                        // Cancel flashing by restoring opacity
                        withAnimation(.easeInOut(duration: 0.1)) {
                            flashOpacity = 1.0
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .alert("Seizure Detected",
               isPresented: $showSeizureAlert,
               actions: {
                   Button("OK", role: .cancel) {
                       // Stop detector alert state; detector drives UI back to steady green
                       detector.stopAlert()
                       // Reset local flashing opacity immediately so any ongoing animation settles
                       flashOpacity = 1.0
                       seizureDetected = false
                       isFlashing = false
                   }
               },
               message: {
                   Text("We detected seizure-like motion.")
               })
        .onAppear {
            requestNotificationAuthorization()
            detector.onSeizureDetected = {
                // Present in-app alert
                showSeizureAlert = true
                // Play a sound for the in-app popup as well
                playAlertTone()
                // Schedule local notification
                scheduleSeizureNotification()
                // Drive a simple flashing opacity only while detector says to flash
                flashOpacity = 1.0
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    flashOpacity = 0.4
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

// MARK: - Detection Logic Extension
extension ContentView {
    
    // Plays a short system alert tone for in-app alerts
    private func playAlertTone() {
        // 1005 is a common system alert sound; adjust if desired
        AudioServicesPlaySystemSound(SystemSoundID(1005))
    }
    
    private func handleHeartRateUpdate(old: Double, new: Double) {
        let now = Date()
        guard new > 0 else { return }
        
        // Append to chart
        if now.timeIntervalSince(lastAppendDate) >= 0.25 {
            points.append(.init(date: now, bpm: new))
            lastAppendDate = now
            let cutoff = now.addingTimeInterval(-window)
            points = points.filter { $0.date >= cutoff }
        }
        
        // HR Spike detection
        if new - old >= hrSpikeRiseThreshold {
            lastHRSpike = now
            // evaluateCombinedSpike()
        }
    }
    
    private func handleMotionUpdate(_ accel: [Double]) {
        let magnitude = sqrt(accel.map { $0 * $0 }.reduce(0,+))
        
        if magnitude > 2.5 { // motion spike threshold
            lastMotionSpike = Date()
            // evaluateCombinedSpike()
        }
    }
    
    /*
    private func evaluateCombinedSpike() {
        guard let hrTime = lastHRSpike,
              let motionTime = lastMotionSpike else { return }
        
        let delta = abs(hrTime.timeIntervalSince(motionTime))
        
        if delta <= coincidenceWindow {
            triggerSeizure()
        }
    }
    */
    
    private func triggerSeizure() {
        /*
        guard !seizureDetected else { return }
        seizureDetected = true
        startFlashing()
        startStabilizationMonitor()

        // In-app popup
        showSeizureAlert = true

        // Schedule a local notification (foreground/background)
        scheduleSeizureNotification()
        */
    }
    
    /*
    private func startFlashing() {
        isFlashing = true
        flashOpacity = 1.0
        
        withAnimation(.easeInOut(duration: 0.5)
            .repeatForever(autoreverses: true)) {
            flashOpacity = 0.4
        }
    }
    */
    
    /*
    private func startStabilizationMonitor() {
        stabilizationTimer?.invalidate()
        
        stabilizationTimer = Timer.scheduledTimer(withTimeInterval: 0.5,
                                                  repeats: true) { _ in
            evaluateStabilization()
        }
    }
    */
    
    /*
    private func evaluateStabilization() {
        let now = Date()
        let recent = points.filter {
            now.timeIntervalSince($0.date) <= stabilizationSeconds
        }
        
        guard recent.count >= 5 else { return }
        
        let values = recent.map { $0.bpm }
        let mean = values.reduce(0,+) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }
            .reduce(0,+) / Double(values.count)
        let stddev = sqrt(variance)
        
        if stddev <= stabilizationVarianceThreshold {
            stopAlert()
        }
    }
    */
    
    /*
    private func stopAlert() {
        stabilizationTimer?.invalidate()
        stabilizationTimer = nil
        seizureDetected = false
        isFlashing = false
        flashOpacity = 1.0
        lastHRSpike = nil
        lastMotionSpike = nil
    }
    */
    
    private func accelValue(_ index: Int) -> Double {
        watchAccelObservable.accel.indices.contains(index)
        ? watchAccelObservable.accel[index]
        : 0
    }
    
    private func heartRateColor(for heartRate: Double) -> Color {
        switch heartRate {
        case 0..<60: return .blue
        case 60..<90: return .green
        default: return .red
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    private func scheduleSeizureNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Seizure Detected"
        content.body = "We detected seizure-like activity."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}

