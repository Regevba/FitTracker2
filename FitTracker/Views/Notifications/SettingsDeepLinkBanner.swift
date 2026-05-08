// Views/Notifications/SettingsDeepLinkBanner.swift
//
// One-time recovery banner shown at the top of Home AFTER the user denied the
// OS notification dialog. Per ux-spec §1.3 + §2.2:
//   - Visible when !NotificationGateway.isAuthorized && !UserDefaults.notificationBannerDismissed
//   - Tap "Open Settings" → opens iOS Settings via UIApplication.openSettingsURLString
//   - Tap dismiss "X" → sets UserDefaults flag; banner disappears permanently
//
// Slide-in transition is gated on accessibilityReduceMotion (Reduce Motion compliance).
//
// Owned by: push-notifications-v2 (FIT-23). Call site: top of Home (HomeView).

import SwiftUI

struct SettingsDeepLinkBanner: View {

    @AppStorage("ft.notification.banner.dismissed") private var dismissed = false
    @ObservedObject private var gateway = NotificationGateway.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let analytics: AnalyticsService?

    init(analytics: AnalyticsService? = nil) {
        self.analytics = analytics
    }

    var body: some View {
        if !dismissed && !gateway.isAuthorized {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.Status.warning)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications are off")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.primary)
                    Text("Enable in Settings to get reminders.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }

                Spacer()

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppText.caption)
                .foregroundStyle(AppColor.Accent.primary)
                .accessibilityLabel("Open notification settings")

                Button {
                    dismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.Text.tertiary)
                        .frame(width: 32, height: 32) // 32pt visual + default touch slop = 44pt+ effective
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss notification banner")
            }
            .padding(AppSpacing.small)
            .background(
                AppColor.Surface.secondary,
                in: RoundedRectangle(cornerRadius: AppRadius.medium)
            )
            .padding(.horizontal, AppSpacing.medium)
            .transition(reduceMotion
                ? .opacity
                : .move(edge: .top).combined(with: .opacity))
            .onAppear {
                analytics?.logNotificationSettingsDeeplinkShown()
            }
        }
    }
}
