//
//  Notifications.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//

//
import UserNotifications

func sendSeizureNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Seizure Detected"
    content.body = "A seizure is occurring!"
    content.sound = .defaultCritical

    let request = UNNotificationRequest(
            identifier: UUID().uuidString, // unique ID so multiple notifications work
            content: content,
            trigger: nil // deliver immediately
    )

    UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification:", error)
            } else {
                print("Seizure notification sent!")
            }
    }
}

