import SwiftUI
import UserNotifications

struct NotificationPermissionPrimingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var permissionGranted = false
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            AppGradient.screenBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.large) {
                Spacer()

                // Illustration
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColor.Accent.primary)
                    .accessibilityHidden(true)

                // Title
                Text("Stay on track with smart reminders")
                    .font(AppText.titleStrong)
                    .foregroundStyle(AppColor.Text.primary)
                    .multilineTextAlignment(.center)

                // Body
                Text("FitMe can remind you about training, nutrition, and recovery — only when it matters.")
                    .font(AppText.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.large)

                Spacer()

                // Denied banner (if applicable)
                if permissionDenied {
                    HStack(spacing: AppSpacing.xSmall) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColor.Status.warning)
                        Text("Notifications are off. Enable in Settings to get reminders.")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .padding(AppSpacing.small)
                    .background(AppColor.Surface.secondary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                }

                // CTA
                Button {
                    Task { await requestPermission() }
                } label: {
                    Text(permissionDenied ? "Open Settings" : "Enable Notifications")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.ctaHeight)
                        .background(AppColor.Accent.primary, in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                }
                .accessibilityLabel(permissionDenied ? "Open notification settings" : "Enable notifications")

                // Secondary dismiss
                Button("Not now") {
                    dismiss()
                }
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
                .accessibilityLabel("Skip enabling notifications")
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.large)
        }
    }

    private func requestPermission() async {
        if permissionDenied {
            // Open iOS Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return
        }

        // I1 fix: use NotificationService.shared instead of calling UNUserNotificationCenter directly
        let service = NotificationService.shared
        await service.requestAuthorization()
        await MainActor.run {
            if service.isAuthorized {
                permissionGranted = true
                dismiss()
            } else {
                permissionDenied = true
            }
        }
    }
}
