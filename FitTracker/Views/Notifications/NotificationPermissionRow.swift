// Views/Notifications/NotificationPermissionRow.swift
//
// Settings row that gives the user a permanent re-entry into the notification
// permission flow. Per ux-spec §2.3:
//   - State 1 — !authorized + never asked    → "Enable Notifications" → opens priming sheet
//   - State 2 — !authorized + previously asked → "Open iOS Settings"   → UIApplication.openSettingsURLString
//   - State 3 — authorized                    → "Notifications enabled ✓" → opens preferences sub-screen (P2 — currently no-op)
//
// Recognition over Recall (#5) — label changes by current state.
//
// Owned by: push-notifications-v2 (FIT-23). Wired into SettingsView v2 between
// the accountSecurity featured card and the LazyVGrid of secondary categories.

import SwiftUI

struct NotificationPermissionRow: View {

    @ObservedObject private var gateway = NotificationGateway.shared
    @AppStorage("ft.notification.permission_requested") private var permissionRequested = false
    @State private var showPrimingSheet = false

    let analytics: AnalyticsService?

    init(analytics: AnalyticsService? = nil) {
        self.analytics = analytics
    }

    var body: some View {
        Button(action: rowTapped) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: AppSize.iconBadge, height: AppSize.iconBadge)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(subtitle)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(
                AppColor.Surface.elevated,
                in: RoundedRectangle(cornerRadius: AppRadius.medium)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications — \(subtitle)")
        .accessibilityHint(accessibilityHint)
        .sheet(isPresented: $showPrimingSheet) {
            NotificationPermissionPrimingView(
                triggerContext: .settings,
                analytics: analytics
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            Task { await gateway.refreshAuthorizationStatus() }
        }
        .onChange(of: gateway.isAuthorized) { _, granted in
            // Mark "permission_requested" once the user has gone through the OS dialog
            // (whether granted or denied — both flip the cached state)
            if granted {
                permissionRequested = true
            }
        }
    }

    // MARK: - Tap action

    private func rowTapped() {
        if gateway.isAuthorized {
            // State 3 — preferences sub-screen deferred to P2; no-op for v2 ship
            return
        }
        if permissionRequested {
            // State 2 — iOS one-shot consumed; route to system Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            // State 1 — present priming flow
            showPrimingSheet = true
            // Pre-stamp the "requested" flag so re-entry routes to State 2 even on dismiss-without-grant
            permissionRequested = true
        }
    }

    // MARK: - State-derived display

    private var iconName: String {
        if gateway.isAuthorized {
            return "checkmark.circle.fill"
        } else if permissionRequested {
            return "bell.slash"
        } else {
            return "bell.badge.fill"
        }
    }

    private var iconTint: Color {
        if gateway.isAuthorized {
            return AppColor.Status.success
        } else if permissionRequested {
            return AppColor.Status.warning
        } else {
            return AppColor.Accent.primary
        }
    }

    private var subtitle: String {
        if gateway.isAuthorized {
            return "Notifications enabled"
        } else if permissionRequested {
            return "Open iOS Settings"
        } else {
            return "Enable Notifications"
        }
    }

    private var accessibilityHint: String {
        if gateway.isAuthorized {
            return "Notifications are currently enabled."
        } else if permissionRequested {
            return "Opens the system Settings to manage notifications."
        } else {
            return "Opens the notification permission priming sheet."
        }
    }
}
