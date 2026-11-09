import Foundation
import Libbox
import Network
import NetworkExtension
import os

final class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    private static let logger = Logger(category: "ExtensionPlatformInterface")

    private let tunnel: ExtensionProvider
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var nwMonitor: Network.NWPathMonitor?

    init(_ tunnel: ExtensionProvider) {
        self.tunnel = tunnel
    }

    // MARK: - TUN

    func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try runBlocking { [self] in
            try await openTun0(options, ret0_)
        }
    }

    private func openTun0(_ options: (any LibboxTunOptionsProtocol)?, _ tunFdPointer: UnsafeMutablePointer<Int32>?) async throws {
        guard let options else {
            throw NSError(domain: "OloTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing TUN options"])
        }
        guard let tunFdPointer else {
            throw NSError(domain: "OloTunnel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing TUN fd pointer"])
        }

        let prefs = tunnel.overridePreferences ?? .init()
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())
            var dnsServers: [String] = []
            let dnsIterator = try options.getDNSServerAddress()
            while dnsIterator.hasNext() {
                dnsServers.append(dnsIterator.next())
            }
            if dnsServers.isEmpty {
                dnsServers = ["1.1.1.1"]
            }
            let dnsSettings = NEDNSSettings(servers: dnsServers)
            settings.dnsSettings = dnsSettings

            var ipv4Addresses: [String] = []
            var ipv4Masks: [String] = []
            let ipv4AddressIterator = options.getInet4Address()!
            while ipv4AddressIterator.hasNext() {
                let prefix = ipv4AddressIterator.next()!
                ipv4Addresses.append(prefix.address())
                ipv4Masks.append(prefix.mask())
            }

            let ipv4Settings = NEIPv4Settings(addresses: ipv4Addresses, subnetMasks: ipv4Masks)
            var ipv4Routes: [NEIPv4Route] = []
            var ipv4ExcludedRoutes: [NEIPv4Route] = []

            let ipv4RouteIterator = options.getInet4RouteAddress()!
            if ipv4RouteIterator.hasNext() {
                while ipv4RouteIterator.hasNext() {
                    let prefix = ipv4RouteIterator.next()!
                    ipv4Routes.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
                }
            } else if prefs.autoRouteUseSubRangesByDefault {
                ipv4Routes.append(NEIPv4Route(destinationAddress: "1.0.0.0", subnetMask: "255.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "2.0.0.0", subnetMask: "254.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "4.0.0.0", subnetMask: "252.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "8.0.0.0", subnetMask: "248.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "16.0.0.0", subnetMask: "240.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "32.0.0.0", subnetMask: "224.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "64.0.0.0", subnetMask: "192.0.0.0"))
                ipv4Routes.append(NEIPv4Route(destinationAddress: "128.0.0.0", subnetMask: "128.0.0.0"))
            } else {
                ipv4Routes.append(.default())
            }

            let ipv4ExcludeIterator = options.getInet4RouteExcludeAddress()!
            while ipv4ExcludeIterator.hasNext() {
                let prefix = ipv4ExcludeIterator.next()!
                ipv4ExcludedRoutes.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
            }

            ipv4Settings.includedRoutes = ipv4Routes
            ipv4Settings.excludedRoutes = ipv4ExcludedRoutes
            settings.ipv4Settings = ipv4Settings
        }

        if options.isHTTPProxyEnabled() {
            let proxySettings = NEProxySettings()
            let proxyServer = NEProxyServer(address: options.getHTTPProxyServer(), port: Int(options.getHTTPProxyServerPort()))
            proxySettings.httpServer = proxyServer
            proxySettings.httpsServer = proxyServer
            proxySettings.httpEnabled = prefs.systemProxyEnabled
            proxySettings.httpsEnabled = prefs.systemProxyEnabled
            settings.proxySettings = proxySettings
        }

        networkSettings = settings
        try await tunnel.setTunnelNetworkSettings(settings)

        if let tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            tunFdPointer.pointee = tunFd
            return
        }
        let tunnelFd = LibboxGetTunnelFileDescriptor()
        guard tunnelFd != -1 else {
            throw NSError(domain: "OloTunnel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing tunnel file descriptor"])
        }
        tunFdPointer.pointee = tunnelFd
    }

    // MARK: - LibboxPlatformInterface

    func autoDetectControl(_ fd: Int32) throws {}
    func usePlatformAutoDetectControl() -> Bool { false }
    func usePlatformBridge() -> Bool { false }
    func usePlatformShell() -> Bool { false }
    func useProcFS() -> Bool { false }
    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { tunnel.overridePreferences?.includeAllNetworks ?? false }
    func clearDNSCache() {}
    func registerMyInterface(_ name: String?) {}
    func tailscaleHostname() -> String { "olo" }

    func cancelNotification(_ identifier: String?, typeID: Int32) throws {}
    func checkPlatformShell() throws {}

    func createBridge(_ options: LibboxBridgeOptions?) throws -> any LibboxBridgeSessionProtocol {
        throw unsupported("bridge")
    }

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        throw unsupported("connection owner")
    }

    func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        let monitor = NWPathMonitor()
        let sem = DispatchSemaphore(value: 0)
        var path: Network.NWPath?
        monitor.pathUpdateHandler = { p in
            path = p
            sem.signal()
        }
        monitor.start(queue: DispatchQueue.global())
        _ = sem.wait(timeout: .now() + 1)
        monitor.cancel()
        let interfaces = (path?.availableInterfaces ?? []).map { iface -> LibboxNetworkInterface in
            let result = LibboxNetworkInterface()
            result.name = iface.name
            result.index = Int32(iface.index)
            switch iface.type {
            case .wifi: result.type = LibboxInterfaceTypeWIFI
            case .cellular: result.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: result.type = LibboxInterfaceTypeEthernet
            default: result.type = LibboxInterfaceTypeOther
            }
            return result
        }
        return NetworkInterfaceArray(interfaces)
    }

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }

    func lookupSFTPServer(_ error: NSErrorPointer) -> String {
        error?.pointee = unsupported("sftp")
        return ""
    }

    func lookupUser(_ username: String?) throws -> LibboxPlatformUser {
        throw unsupported("user")
    }

    func openShellSession(
        _ user: LibboxPlatformUser?,
        command: String?,
        environ: (any LibboxStringIteratorProtocol)?,
        term: String?,
        rows: Int32,
        cols: Int32
    ) throws -> any LibboxShellSessionProtocol {
        throw unsupported("shell")
    }

    func readSystemSSHHostKey(_ error: NSErrorPointer) -> String {
        error?.pointee = unsupported("ssh host key")
        return ""
    }

    func readWIFIState() -> LibboxWIFIState? { nil }

    func send(_ notification: LibboxNotification?) throws {}

    func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
        nwMonitor?.cancel()
        let monitor = NWPathMonitor()
        nwMonitor = monitor
        monitor.pathUpdateHandler = { path in
            guard let listener else { return }
            let name = path.availableInterfaces.first?.name
            listener.updateDefaultInterface(
                name,
                interfaceIndex: Int32(path.availableInterfaces.first?.index ?? 0),
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained
            )
        }
        monitor.start(queue: .global())
    }

    func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    func startNeighborMonitor(_ listener: (any LibboxNeighborUpdateListenerProtocol)?) throws {}
    func closeNeighborMonitor(_ listener: (any LibboxNeighborUpdateListenerProtocol)?) throws {}

    // MARK: - Command server handler

    func connectSSHAgent(_ ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw unsupported("ssh agent")
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        status.available = true
        status.enabled = tunnel.overridePreferences?.systemProxyEnabled ?? true
        return status
    }

    func serviceReload() throws {
        try runBlocking { [self] in
            try await tunnel.reloadService()
        }
    }

    func serviceStop() throws {
        tunnel.stopService()
    }

    func setSystemProxyEnabled(_ isEnabled: Bool) throws {
        tunnel.overridePreferences?.systemProxyEnabled = isEnabled
        if let networkSettings {
            try runBlocking { [self] in
                try await tunnel.setTunnelNetworkSettings(networkSettings)
            }
        }
    }

    func triggerNativeCrash() throws {
        fatalError("native crash requested")
    }

    func writeDebugMessage(_ message: String?) {
        Self.logger.debug("\(message ?? "", privacy: .public)")
    }

    func reset() {
        networkSettings = nil
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    private func unsupported(_ name: String) -> NSError {
        NSError(domain: "OloTunnel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported: \(name)"])
    }
}

private final class NetworkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    private var nextValue: LibboxNetworkInterface?

    init(_ values: [LibboxNetworkInterface]) {
        iterator = values.makeIterator()
        nextValue = iterator.next()
    }

    func hasNext() -> Bool { nextValue != nil }

    func next() -> LibboxNetworkInterface? {
        defer { nextValue = iterator.next() }
        return nextValue
    }
}
