import Foundation

enum TrafficPath: String, Codable {
    case vpn
    case direct
    case blocked
    case dns
    case leak

    var title: String {
        switch self {
        case .vpn: return "Через VPN"
        case .direct: return "Мимо VPN"
        case .blocked: return "Блок"
        case .dns: return "DNS"
        case .leak: return "Утечка?"
        }
    }

    var symbol: String {
        switch self {
        case .vpn: return "lock.shield.fill"
        case .direct: return "arrow.triangle.branch"
        case .blocked: return "hand.raised.fill"
        case .dns: return "text.magnifyingglass"
        case .leak: return "exclamationmark.triangle.fill"
        }
    }
}

enum LogLevel: String, Codable {
    case info
    case success
    case warn
    case danger
}

struct TrafficLogEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let host: String
    let detail: String
    let path: TrafficPath
    let bytes: Int64
    let level: LogLevel

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        host: String,
        detail: String,
        path: TrafficPath,
        bytes: Int64 = 0,
        level: LogLevel = .info
    ) {
        self.id = id
        self.date = date
        self.host = host
        self.detail = detail
        self.path = path
        self.bytes = bytes
        self.level = level
    }
}

struct TrafficSample: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let uploadBytesPerSec: Double
    let downloadBytesPerSec: Double

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        uploadBytesPerSec: Double,
        downloadBytesPerSec: Double
    ) {
        self.id = id
        self.date = date
        self.uploadBytesPerSec = uploadBytesPerSec
        self.downloadBytesPerSec = downloadBytesPerSec
    }
}

struct DestinationStat: Identifiable, Equatable {
    let id: UUID
    let host: String
    var bytes: Int64
    var path: TrafficPath

    init(id: UUID = UUID(), host: String, bytes: Int64, path: TrafficPath) {
        self.id = id
        self.host = host
        self.bytes = bytes
        self.path = path
    }
}

enum LeakKind: String, CaseIterable, Identifiable {
    case ip
    case dns
    case ipv6
    case webrtc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ip: return "IP"
        case .dns: return "DNS"
        case .ipv6: return "IPv6"
        case .webrtc: return "WebRTC"
        }
    }

    var symbol: String {
        switch self {
        case .ip: return "network"
        case .dns: return "text.magnifyingglass"
        case .ipv6: return "6.circle.fill"
        case .webrtc: return "video.fill"
        }
    }
}

enum LeakStatus: Equatable {
    case idle
    case checking
    case ok(String)
    case leak(String)
    case unknown(String)

    var isBad: Bool {
        if case .leak = self { return true }
        return false
    }
}

struct LeakCheck: Identifiable, Equatable {
    let kind: LeakKind
    var status: LeakStatus

    var id: String { kind.id }
}

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    static func rate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return String(format: "%.0f B/s", bytesPerSec)
        }
        if bytesPerSec < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        }
        return String(format: "%.2f MB/s", bytesPerSec / (1024 * 1024))
    }
}
