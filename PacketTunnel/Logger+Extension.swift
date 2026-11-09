import Foundation
import os

extension Logger {
    init(category: String) {
        self.init(
            subsystem: Bundle.main.bundleIdentifier ?? "app.olo.vpn",
            category: category
        )
    }
}
