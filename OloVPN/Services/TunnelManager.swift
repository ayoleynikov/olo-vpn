import Foundation
import NetworkExtension
import Combine

@MainActor
final class TunnelManager: ObservableObject {
    enum TunnelError: LocalizedError {
        case noServer
        case notConfigured
        case startFailed(String)
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noServer: return "Сначала выберите сервер"
            case .notConfigured: return "VPN‑профиль ещё не создан"
            case .startFailed(let s): return s
            case .permissionDenied: return "Нужно разрешить VPN в системных настройках"
            }
        }
    }

    @Published private(set) var status: NEVPNStatus = .invalid
    @Published var lastError: String?
    @Published var protection: ProtectionSettings = .default {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(protection), forKey: "olo.protection") }
    }

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    init() {
        if let data = UserDefaults.standard.data(forKey: "olo.protection"),
           let decoded = try? JSONDecoder().decode(ProtectionSettings.self, from: data) {
            protection = decoded
        }
        Task { await reload() }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func reload() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == AppConstants.tunnelBundleID
            }) ?? managers.first {
                manager = existing
            } else {
                let created = NETunnelProviderManager()
                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = AppConstants.tunnelBundleID
                proto.serverAddress = "Olo"
                created.protocolConfiguration = proto
                created.localizedDescription = AppConstants.tunnelProviderDescription
                created.isEnabled = true
                manager = created
            }
            bindStatus()
            status = manager?.connection.status ?? .invalid
        } catch {
            lastError = error.localizedDescription
        }
    }

    func connect(store: ConfigStore) async throws {
        guard let server = store.selectedServer else { throw TunnelError.noServer }
        let json = try SingBoxConfigBuilder.build(
            server: server,
            routeMode: store.routeMode,
            localPolicy: store.localPolicy,
            localRegion: store.localRegion,
            protection: protection
        )

        if manager == nil {
            await reload()
        }
        guard let manager else { throw TunnelError.notConfigured }

        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppConstants.tunnelBundleID
        proto.serverAddress = server.endpointLabel
        proto.providerConfiguration = [
            "configContent": json
        ]
        #if os(macOS)
        // On macOS, disconnectOnSleep false is friendlier for desktops.
        proto.disconnectOnSleep = false
        #endif
        manager.protocolConfiguration = proto
        manager.isEnabled = true
        manager.localizedDescription = "Olo · \(server.displayName)"

        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
        } catch {
            throw TunnelError.startFailed(error.localizedDescription)
        }

        let options: [String: NSObject] = [
            "configContent": json as NSString,
            "includeAllNetworks": NSNumber(value: protection.killSwitch),
            "systemProxyEnabled": NSNumber(value: true),
            "excludeDefaultRoute": NSNumber(value: false)
        ]

        do {
            try manager.connection.startVPNTunnel(options: options)
            status = manager.connection.status
            lastError = nil
        } catch {
            let ns = error as NSError
            if ns.domain == NEVPNErrorDomain && ns.code == NEVPNError.configurationDisabled.rawValue {
                throw TunnelError.permissionDenied
            }
            throw TunnelError.startFailed(error.localizedDescription)
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    private func bindStatus() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        guard let connection = manager?.connection else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.status = connection.status
            }
        }
        status = connection.status
    }
}

extension NEVPNStatus {
    var oloConnectionState: ConnectionState {
        switch self {
        case .connected: return .connected
        case .connecting, .reasserting: return .connecting
        case .disconnecting: return .disconnecting
        case .disconnected, .invalid: return .disconnected
        @unknown default: return .disconnected
        }
    }
}
