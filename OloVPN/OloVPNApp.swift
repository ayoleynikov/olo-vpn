import SwiftUI

@main
struct OloVPNApp: App {
    @StateObject private var store = ConfigStore()
    @StateObject private var monitor = TrafficMonitor()
    @StateObject private var tunnel = TunnelManager()
    @StateObject private var subscriptions = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(monitor)
                .environmentObject(tunnel)
                .environmentObject(subscriptions)
                .preferredColorScheme(.light)
                .onChange(of: store.connectionState) { _, _ in
                    monitor.bind(to: store)
                }
                .task {
                    await tunnel.reload()
                    await subscriptions.refreshDue(into: store)
                }
        }
        #if os(macOS)
        .defaultSize(width: 440, height: 780)
        .windowResizability(.contentSize)
        #endif
    }
}
