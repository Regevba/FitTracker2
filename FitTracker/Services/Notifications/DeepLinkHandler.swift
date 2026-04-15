import SwiftUI

struct DeepLinkHandler {
    // Parse deep link URL and return the target tab
    static func targetTab(from url: URL) -> AppTab? {
        switch url.host {
        case "training": return .training
        case "nutrition": return .nutrition
        case "stats": return .stats
        case "home": return .main
        default: return nil
        }
    }
}
