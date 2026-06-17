// Services/Notifications/NotificationPermissionPrimingView.swift
//
// 3-step permission priming surface (per ux-foundations.md §5.2). Step 1 of the
// flow shown to the user before the OS dialog fires. Revived at push-notifications-v2
// (PR feature/push-notifications-v2) — formerly HISTORICAL after v1 partial-ship UI-016.
//
// Entry points:
//   - First-workout-completed (primary, post SessionCompletionSheet dismiss)
//   - Settings → Notifications row (secondary)
//
// Wires NotificationGateway.requestAuthorization() — does NOT call
// UNUserNotificationCenter directly (the gateway owns the system call so cap audit
// + auth state tracking stays consistent across all consumers).

import SwiftUI
import UserNotifications

struct NotificationPermissionPrimingView: View {

    // MARK: - Trigger context (drives analytics + post-denial copy)

    enum TriggerContext: String {
        case postWorkout = "post_workout"
        case settings    = "settings"
    }

    // MARK: - Internal state machine

    private enum PrimingState {
        case initial    // pre-OS-dialog
        case granted    // user tapped Allow → auto-dismiss
        case denied     // user tapped Don't Allow → show denial hint, swap CTA to "Open Settings"
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var gateway = NotificationGateway.shared
    @State private var primingState: PrimingState = .initial

    let triggerContext: TriggerContext
    let analytics: AnalyticsService?

    init(triggerContext: TriggerContext, analytics: AnalyticsService? = nil) {
        self.triggerContext = triggerContext
        self.analytics = analytics
    }

    var body: some View {
        ZStack {
            AppGradient.screenBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.large) {
                Spacer()

                // Hero icon (decorative — accessibility hidden)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColor.Accent.primary)
                    .accessibilityHidden(true)

                // Title (Jakob's Law — same hierarchy as existing priming surfaces)
                Text("Stay on track with smart reminders")
                    .font(AppText.titleStrong)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.center)

                // Body (benefit framing per ux-foundations §5.2 pre-primer rules)
                Text("FitMe can remind you about training, recovery, and readiness — only when it matters.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.large)

                // Category list (Progressive Disclosure + Recognition over Recall)
                CategoryListView()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Notification categories: training reminders, readiness alerts, recovery nudges")

                Spacer()

                // Denial hint (only when previously denied within the same sheet lifecycle)
                if primingState == .denied {
                    DenialHintRow()
                }

                // Primary CTA — copy switches based on state
                Button {
                    Task { await requestPermission() }
                } label: {
                    Text(primingState == .denied ? "Open Settings" : "Enable Notifications")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppSize.ctaHeight)
                        .background(
                            AppColor.Accent.primary,
                            in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        )
                }
                .accessibilityLabel(primingState == .denied
                    ? "Open notification settings"
                    : "Enable notifications")
                .accessibilityHint("Opens the system permission dialog")

                // Secondary dismiss — preserves OS one-shot privilege (no dialog fired)
                Button("Not now") {
                    analytics?.logNotificationPrimingSkipped(triggerContext: triggerContext.rawValue)
                    dismiss()
                }
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
                .accessibilityLabel("Skip enabling notifications")
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.large)
        }
        .onAppear {
            analytics?.logNotificationPrimingShown(triggerContext: triggerContext.rawValue)
            // Edge case: if the user already granted via iOS Settings before reaching us,
            // short-circuit to .granted so we don't fire a redundant OS dialog.
            Task {
                await gateway.refreshAuthorizationStatus()
                if gateway.isAuthorized {
                    primingState = .granted
                    dismiss()
                }
            }
        }
    }

    // MARK: - Permission request

    private func requestPermission() async {
        // From the .denied state, the CTA opens iOS Settings instead of re-firing the OS dialog
        // (which is impossible — Apple's API is one-shot per app install).
        if primingState == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return
        }

        analytics?.logNotificationPermissionRequested()
        await gateway.requestAuthorization()
        await MainActor.run {
            if gateway.isAuthorized {
                analytics?.logNotificationPermissionResult(granted: true)
                primingState = .granted
                dismiss()
            } else {
                analytics?.logNotificationPermissionResult(granted: false)
                primingState = .denied
            }
        }
    }
}

// MARK: - Sub-components

/// 3-bullet category list — surfaces what kinds of notifications the user will receive
/// before they grant permission. Per ux-spec §2.1 hi-fi schematic.
private struct CategoryListView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            CategoryRow(text: "Training reminders — when you've scheduled a session")
            CategoryRow(text: "Readiness alerts — when your recovery is low before a workout")
            CategoryRow(text: "Recovery nudges — when your body needs rest")
        }
        .padding(.horizontal, AppSpacing.large)
    }

    private struct CategoryRow: View {
        let text: String
        var body: some View {
            HStack(alignment: .top, spacing: AppSpacing.xSmall) {
                Text("•")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
                Text(text)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
    }
}

/// Inline hint row shown when the user previously denied within the same priming session.
/// Distinct from the post-app-foreground SettingsDeepLinkBanner (which is a one-time
/// surface presented at top of Home).
private struct DenialHintRow: View {
    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColor.Status.warning)
            Text("Notifications are off. Enable in Settings to get reminders.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .padding(AppSpacing.small)
        .background(
            AppColor.Surface.secondary,
            in: RoundedRectangle(cornerRadius: AppRadius.medium)
        )
    }
}
