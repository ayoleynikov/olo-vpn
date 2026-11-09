import Foundation

enum ProxyProtocol: String, Codable, CaseIterable, Identifiable {
    case shadowsocks
    case vmess
    case vless
    case trojan
    case hysteria2
    case tuic
    case socks
    case http
    case wireguard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shadowsocks: return "Shadowsocks"
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .trojan: return "Trojan"
        case .hysteria2: return "Hysteria2"
        case .tuic: return "TUIC"
        case .socks: return "SOCKS5"
        case .http: return "HTTP"
        case .wireguard: return "WireGuard"
        }
    }

    var symbol: String {
        switch self {
        case .shadowsocks: return "shield.lefthalf.filled"
        case .vmess, .vless: return "bolt.horizontal.circle.fill"
        case .trojan: return "lock.shield.fill"
        case .hysteria2: return "hare.fill"
        case .tuic: return "airplane"
        case .socks, .http: return "globe"
        case .wireguard: return "network"
        }
    }
}

struct VPNServer: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var proto: ProxyProtocol
    var host: String
    var port: Int
    var password: String
    var uuid: String
    var method: String
    var sni: String
    var transport: String
    var remark: String
    var rawLink: String
    var createdAt: Date

    // TLS / Reality / transport extras
    var security: String
    var flow: String
    var fingerprint: String
    var publicKey: String
    var shortID: String
    var spiderX: String
    var wsPath: String
    var wsHost: String
    var grpcServiceName: String
    var hy2Obfs: String
    var hy2ObfsPassword: String

    init(
        id: UUID = UUID(),
        name: String,
        proto: ProxyProtocol,
        host: String,
        port: Int,
        password: String = "",
        uuid: String = "",
        method: String = "",
        sni: String = "",
        transport: String = "tcp",
        remark: String = "",
        rawLink: String = "",
        createdAt: Date = Date(),
        security: String = "",
        flow: String = "",
        fingerprint: String = "",
        publicKey: String = "",
        shortID: String = "",
        spiderX: String = "",
        wsPath: String = "/",
        wsHost: String = "",
        grpcServiceName: String = "GunService",
        hy2Obfs: String = "",
        hy2ObfsPassword: String = ""
    ) {
        self.id = id
        self.name = name
        self.proto = proto
        self.host = host
        self.port = port
        self.password = password
        self.uuid = uuid
        self.method = method
        self.sni = sni
        self.transport = transport
        self.remark = remark
        self.rawLink = rawLink
        self.createdAt = createdAt
        self.security = security
        self.flow = flow
        self.fingerprint = fingerprint
        self.publicKey = publicKey
        self.shortID = shortID
        self.spiderX = spiderX
        self.wsPath = wsPath
        self.wsHost = wsHost
        self.grpcServiceName = grpcServiceName
        self.hy2Obfs = hy2Obfs
        self.hy2ObfsPassword = hy2ObfsPassword
    }

    var endpointLabel: String {
        "\(host):\(port)"
    }

    var displayName: String {
        name.isEmpty ? endpointLabel : name
    }

    /// Copy without secrets for UserDefaults persistence.
    func redactedForDisk() -> VPNServer {
        var copy = self
        copy.password = ""
        copy.uuid = ""
        return copy
    }

    func withSecrets(password: String, uuid: String) -> VPNServer {
        var copy = self
        if copy.password.isEmpty { copy.password = password }
        if copy.uuid.isEmpty { copy.uuid = uuid }
        return copy
    }
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting

    var title: String {
        switch self {
        case .disconnected: return "Не подключено"
        case .connecting: return "Подключение…"
        case .connected: return "Защищено"
        case .disconnecting: return "Отключение…"
        }
    }
}

enum RouteMode: String, Codable, CaseIterable, Identifiable {
    case smart
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "Умный"
        case .global: return "Всё через VPN"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: return "Местные сайты отдельно"
        case .global: return "Без исключений"
        }
    }

    var symbol: String {
        switch self {
        case .smart: return "brain.head.profile"
        case .global: return "globe.badge.chevron.backward"
        }
    }
}

enum LocalTrafficPolicy: String, Codable, CaseIterable, Identifiable {
    case bypass
    case throughVPN

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bypass: return "Мимо VPN"
        case .throughVPN: return "Через VPN"
        }
    }

    var subtitle: String {
        switch self {
        case .bypass: return "Быстрее для банков, доставки, госсайтов"
        case .throughVPN: return "Местные тоже идут через сервер"
        }
    }

    var symbol: String {
        switch self {
        case .bypass: return "arrow.triangle.branch"
        case .throughVPN: return "lock.shield.fill"
        }
    }
}

enum LocalRegion: String, Codable, CaseIterable, Identifiable {
    case auto
    case ru
    case cn
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Авто"
        case .ru: return "Россия"
        case .cn: return "Китай"
        case .other: return "Другой"
        }
    }
}
