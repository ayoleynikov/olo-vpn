import Foundation
import Combine

@MainActor
final class ConfigStore: ObservableObject {
    @Published var servers: [VPNServer] = []
    @Published var selectedID: UUID?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var routeMode: RouteMode = .smart {
        didSet { persistRouting() }
    }
    @Published var localPolicy: LocalTrafficPolicy = .bypass {
        didSet { persistRouting() }
    }
    @Published var localRegion: LocalRegion = .auto {
        didSet { persistRouting() }
    }

    private let serversKey = "olo.servers"
    private let selectedKey = "olo.selected"
    private let routeModeKey = "olo.routeMode"
    private let localPolicyKey = "olo.localPolicy"
    private let localRegionKey = "olo.localRegion"

    init() {
        load()
    }

    var selectedServer: VPNServer? {
        servers.first { $0.id == selectedID } ?? servers.first
    }

    var routingSummary: String {
        switch routeMode {
        case .global:
            return "Весь трафик через VPN"
        case .smart:
            switch localPolicy {
            case .bypass:
                return "Местные (\(localRegion.title)) мимо VPN"
            case .throughVPN:
                return "Местные (\(localRegion.title)) через VPN"
            }
        }
    }

    func add(_ server: VPNServer) {
        servers.insert(server, at: 0)
        selectedID = server.id
        persist()
    }

    func update(_ server: VPNServer) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index] = server
        persist()
    }

    func delete(_ server: VPNServer) {
        servers.removeAll { $0.id == server.id }
        if selectedID == server.id {
            selectedID = servers.first?.id
        }
        persist()
    }

    func select(_ server: VPNServer) {
        selectedID = server.id
        persist()
    }

    func replaceServers(namedPrefix prefix: String, with newServers: [VPNServer]) {
        servers.removeAll { $0.name.hasPrefix(prefix) }
        for server in newServers.reversed() {
            servers.insert(server, at: 0)
        }
        if selectedID == nil || !servers.contains(where: { $0.id == selectedID }) {
            selectedID = servers.first?.id
        }
        persist()
    }

    /// Legacy UI simulation when tunnel manager is unavailable (simulator / no signing).
    func simulateToggleConnection() {
        switch connectionState {
        case .disconnected:
            guard selectedServer != nil else { return }
            connectionState = .connecting
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                connectionState = .connected
            }
        case .connected:
            connectionState = .disconnecting
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                connectionState = .disconnected
            }
        case .connecting, .disconnecting:
            break
        }
    }

    func applyTunnelStatus(_ state: ConnectionState) {
        connectionState = state
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: serversKey),
           let decoded = try? JSONDecoder().decode([VPNServer].self, from: data) {
            servers = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: selectedKey),
           let id = UUID(uuidString: idString) {
            selectedID = id
        } else {
            selectedID = servers.first?.id
        }

        if let raw = UserDefaults.standard.string(forKey: routeModeKey),
           let mode = RouteMode(rawValue: raw) {
            routeMode = mode
        }
        if let raw = UserDefaults.standard.string(forKey: localPolicyKey),
           let policy = LocalTrafficPolicy(rawValue: raw) {
            localPolicy = policy
        }
        if let raw = UserDefaults.standard.string(forKey: localRegionKey),
           let region = LocalRegion(rawValue: raw) {
            localRegion = region
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: serversKey)
        }
        UserDefaults.standard.set(selectedID?.uuidString, forKey: selectedKey)
        persistRouting()
    }

    private func persistRouting() {
        UserDefaults.standard.set(routeMode.rawValue, forKey: routeModeKey)
        UserDefaults.standard.set(localPolicy.rawValue, forKey: localPolicyKey)
        UserDefaults.standard.set(localRegion.rawValue, forKey: localRegionKey)
    }
}
