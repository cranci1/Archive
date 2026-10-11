//
//  BlockerModel.swift
//  Limitless
//
//  Created by Francesco on 14/06/26.
//

import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class BlockerModel: ObservableObject {
    static let shared = BlockerModel()
    
    @Published var isAuthorized = false
    @Published var selection = FamilyActivitySelection() {
        didSet {
            saveSelection()
            if isBlockingEnabled { applyBlocking() }
        }
    }
    
    @Published var isBlockingEnabled = false {
        didSet {
            saveBlockingEnabledState()
            if isBlockingEnabled {
                applyBlocking()
            } else {
                stopBlocking()
            }
        }
    }
    
    private let store = ManagedSettingsStore(named: .doomBlocker)
    private let center = AuthorizationCenter.shared
    
    init() {
        loadSavedSelection()
        loadBlockingEnabledState()
        
        if isBlockingEnabled && isAuthorized {
            applyBlocking()
        }
    }
    
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            isAuthorized = true
            if isBlockingEnabled { applyBlocking() }
        } catch {
            print("Authorization failed: \(error)")
            isAuthorized = false
        }
    }
    
    private func applyBlocking() {
        guard isAuthorized else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
    
    func stopBlocking() {
        store.shield.applications = nil
        store.shield.webDomains = nil
    }
    
    private func loadSavedSelection() {
        guard let userDefaults = UserDefaults(suiteName: "group.me.cranci.Limitless.doom"),
              let data = userDefaults.data(forKey: "savedSelection"),
              let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        selection = saved
    }
    
    private func saveSelection() {
        guard let encoded = try? JSONEncoder().encode(selection),
              let userDefaults = UserDefaults(suiteName: "group.me.cranci.Limitless.doom") else { return }
        userDefaults.set(encoded, forKey: "savedSelection")
    }
    
    private func loadBlockingEnabledState() {
        let defaults = UserDefaults.standard
        isBlockingEnabled = defaults.bool(forKey: "isBlockingEnabled")
    }
    
    private func saveBlockingEnabledState() {
        UserDefaults.standard.set(isBlockingEnabled, forKey: "isBlockingEnabled")
    }
}

extension ManagedSettingsStore.Name {
    static let doomBlocker = Self("DoomBlocker")
}
