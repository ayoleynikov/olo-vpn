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
        createdAt: Date = Date()
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
    }

    var endpointLabel: String {
        "\(host):\(port)"
    }

    var displayName: String {
        name.isEmpty ? endpointLabel : name
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

/// Как гонять трафик, когда VPN включён.
enum RouteMode: String, Codable, CaseIterable, Identifiable {
    /// Местные сайты региона — по правилу ниже; остальное через VPN.
    case smart
    /// Весь трафик через VPN, без исключений.
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

/// Куда слать сайты «своего» региона в умном режиме.
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

/// Какой регион считать «местным» для умного маршрута.
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
