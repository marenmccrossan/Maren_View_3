//
//  ContactsStore.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//
import Foundation
import Observation
import SwiftUI
import Combine

public struct Contact: Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public var firstName: String
    public var phoneNumber: String
    public var lastMessage: String?

    public init(id: UUID = UUID(), firstName: String, phoneNumber: String, lastMessage: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.phoneNumber = phoneNumber
        self.lastMessage = lastMessage
    }
}

final class ContactsStore: ObservableObject {
    private let storageKey = "trustedContacts.v1"

    @Published var contacts: [Contact] = [] {
        didSet { persist() }
    }

    init() {
        load()
    }

    // MARK: - Public API
    func addContact(firstName: String, phone: String) {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneTrimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !phoneTrimmed.isEmpty else { return }
        contacts.append(Contact(firstName: name, phoneNumber: phoneTrimmed))
    }

    func delete(at offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
    }

    var phoneNumbers: [String] {
        contacts.compactMap { normalizeE164($0.phoneNumber) }
    }

    // MARK: - Persistence
    private func persist() {
        do {
            let data = try JSONEncoder().encode(contacts)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("ContactsStore persist error: \(error)")
            #endif
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([Contact].self, from: data)
            self.contacts = decoded
        } catch {
            #if DEBUG
            print("ContactsStore load error: \(error)")
            #endif
            self.contacts = []
        }
    }

    // Minimal normalization – customize as needed for your regions
    private func normalizeE164(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}


