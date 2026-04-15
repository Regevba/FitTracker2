// FitTracker/Views/Profile/AccountDataCard.swift
import SwiftUI

struct AccountDataCard: View {
    let signInProvider: String?
    let biometricEnabled: Bool
    let syncStatus: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: "lock.shield.fill")
                    .font(AppText.titleMedium)
                    .foregroundStyle(AppColor.Accent.primary)
                    .frame(width: 36, height: 36)
                    .background(AppColor.Accent.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text("Account & Data")
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(summaryLine)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account and Data")
        .accessibilityValue(summaryLine)
        .accessibilityHint("Double tap to manage account, sync, and privacy")
    }

    private var summaryLine: String {
        let provider = signInProvider ?? "Not signed in"
        let lock = biometricEnabled ? "Face ID" : "No lock"
        return "\(provider) · \(lock) · \(syncStatus)"
    }
}
