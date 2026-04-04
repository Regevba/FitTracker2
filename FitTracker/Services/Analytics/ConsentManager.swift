// Services/Analytics/ConsentManager.swift
// Manages GDPR analytics consent and ATT authorization.
// Consent state persisted in UserDefaults (synced via existing Supabase).
// All analytics calls are gated on consent status.

import Foundation
import SwiftUI
import AppTrackingTransparency

@MainActor
final class ConsentManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var gdprConsent: ConsentStatus = .pending
    @Published private(set) var attStatus: ATTrackingManager.AuthorizationStatus = .notDetermined

    enum ConsentStatus: String, Codable {
        case pending   // User hasn't been asked yet
        case granted   // User accepted
        case denied    // User declined
    }

    /// Whether analytics should be active (both GDPR consent AND not revoked)
    var isAnalyticsAllowed: Bool {
        gdprConsent == .granted
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let gdprConsent = "ft.analytics.gdprConsent"
        static let consentDate = "ft.analytics.consentDate"
        static let hasBeenAsked = "ft.analytics.hasBeenAsked"
    }

    // MARK: - Init

    init() {
        loadStoredConsent()
    }

    // MARK: - Consent Flow

    /// Whether the consent screen should be shown
    var needsConsentPrompt: Bool {
        !UserDefaults.standard.bool(forKey: Keys.hasBeenAsked)
    }

    /// User accepts analytics consent
    func grantConsent() {
        gdprConsent = .granted
        UserDefaults.standard.set(ConsentStatus.granted.rawValue, forKey: Keys.gdprConsent)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.consentDate)
        UserDefaults.standard.set(true, forKey: Keys.hasBeenAsked)
    }

    /// User declines analytics consent
    func denyConsent() {
        gdprConsent = .denied
        UserDefaults.standard.set(ConsentStatus.denied.rawValue, forKey: Keys.gdprConsent)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.consentDate)
        UserDefaults.standard.set(true, forKey: Keys.hasBeenAsked)
    }

    /// User revokes consent from Settings (can re-grant later)
    func revokeConsent() {
        gdprConsent = .denied
        UserDefaults.standard.set(ConsentStatus.denied.rawValue, forKey: Keys.gdprConsent)
        // Keep hasBeenAsked = true so we don't re-prompt automatically
    }

    /// User re-grants consent from Settings
    func regrantConsent() {
        grantConsent()
    }

    /// Reset consent state (for re-prompting, e.g., after consent text changes)
    func resetConsentPrompt() {
        UserDefaults.standard.set(false, forKey: Keys.hasBeenAsked)
        gdprConsent = .pending
    }

    // MARK: - ATT

    /// Request App Tracking Transparency authorization (only after GDPR consent)
    func requestATT() async {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        attStatus = status
    }

    /// Refresh ATT status from system
    func refreshATTStatus() {
        attStatus = ATTrackingManager.trackingAuthorizationStatus
    }

    // MARK: - Private

    private func loadStoredConsent() {
        if let stored = UserDefaults.standard.string(forKey: Keys.gdprConsent),
           let status = ConsentStatus(rawValue: stored) {
            gdprConsent = status
        }
        refreshATTStatus()
    }
}
