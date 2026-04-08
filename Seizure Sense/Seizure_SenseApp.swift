//
//  Seizure_SenseApp.swift
//  Seizure Sense
//
//  Created by Maren McCrossan on 4/8/26.
//

import SwiftUI
import UserNotifications

@main
struct Seizure_SenseApp: App {


    @StateObject private var coordinator = AppCoordinator()

    init() {
        // Initialize WCSessionManager singleton immediately
        _ = WCSessionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
        }
    }
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notifications authorized")
            } else if let error = error {
                print("Notification permission error:", error)
            }
        }
    }
}
