//
//  AppCoordinator.swift
//  Seizure Sense
//
//  Created by Maren McCrossan on 4/8/26.
//

// AppCoordinator.swift

// Central coordinator that wires SeizureDetector -> Alerts using ContactsStore and presents MessagingView
/// Note: Future work will contain a functional Messaging capbility where users will be able to add thier trusted contacts and the app will send alerts when a seizure is detected. Messaging will utilize the AppCoordinator and ContactsStore file to effectively send messages. It will also utilize a 3rd party API messaging capability to effectively send those messages. For the app's current state, will we be omitting Messaging Vew from the Settings section.

import Foundation
import SwiftUI
import UserNotifications
import Combine

/// A simple app-wide coordinator responsible for:
/// - owning shared stores/services
/// - wiring `SeizureDetector.onSeizureDetected`
/// - sending alerts to trusted contacts
/// - exposing the root SwiftUI view with proper environment objects
@MainActor
final class AppCoordinator: ObservableObject {
    // Shared services
    let contactsStore: ContactsStore
    let seizureDetector: SeizureDetector
    let appSettings = AppSettings()

    // Optional: surface app-level routing or state later
    @Published var isAlertActive: Bool = false

    init(
        contactsStore: ContactsStore,
        seizureDetector: SeizureDetector
    ) {
        self.contactsStore = contactsStore
        self.seizureDetector = seizureDetector

        // Wire the detector callback
        self.seizureDetector.onSeizureDetected = { [weak self] in
            Task { @MainActor in
                await self?.handleSeizureDetection()
            }
        }

        // Prepare local notifications permission (for demo alerting)
        requestNotificationAuthorizationIfNeeded()
    }

    /// Convenience initializer that creates default dependencies on the main actor to avoid
    /// calling actor-isolated initializers from a nonisolated context.
    convenience init() {
        self.init(
            contactsStore: ContactsStore(),
            seizureDetector: SeizureDetector()
        )
    }

    // MARK: Root View
    /// Root content view for the app. Injects environment objects so other views can access them.
    var rootView: some View {
        ContentView(detector: seizureDetector)
            .environmentObject(appSettings)
            .environmentObject(contactsStore)
    }

    // MARK: - Alert handling
    private func handleSeizureDetection() async {
        isAlertActive = true

        // 1) Notify the user locally (lock screen/banner)
        await scheduleLocalAlert()

        // 2) Send messages to trusted contacts (stub). Replace with your SMS/Server/CallKit integration.
        sendAlertsToTrustedContacts()
    }

    private func sendAlertsToTrustedContacts() {
        let numbers = contactsStore.phoneNumbers
        guard !numbers.isEmpty else { return }

        // Stub: Replace this with your real sending mechanism (e.g., SMS via your backend, Messages intents, or CallKit)
        // For now, we just log the action. In DEBUG, this will show in the console.
        #if DEBUG
        print("[Coordinator] Sending ALERT to: \(numbers.joined(separator: ", "))")
        #endif
    }

    // MARK: - Local notifications (demo)
    private func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            #if DEBUG
            if let error = error { print("Notification auth error: \(error)") }
            print("Notification permission granted: \(granted)")
            #endif
        }
    }

    private func scheduleLocalAlert() async {
        let content = UNMutableNotificationContent()
        content.title = "Potential Seizure Detected"
        content.body = "We are notifying your trusted contacts."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            #if DEBUG
            print("Failed to schedule local notification: \(error)")
            #endif
        }
    }
}



#if DEBUG
import Observation

#Preview("Coordinator Root") {
    AppCoordinator().rootView
}
#endif



