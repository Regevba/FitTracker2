import SwiftUI

/// Centralized haptic feedback — use instead of inline UIImpactFeedbackGenerator calls.
enum HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        #if os(iOS)
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
        #endif
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(type)
        #endif
    }

    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
