import Foundation

enum LinkParseError: LocalizedError {
    case empty
    case unsupported
    case malformed

    var errorDescription: String? {
        switch self {
        case .empty: return "Вставьте ссылку на сервер"
        case .unsupported: return "Этот формат пока не поддерживается"
        case .malformed: return "Ссылка повреждена или неполная"
        }
    }
}

enum LinkParser {
    static func parse(_ raw: String) throws -> VPNServer {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LinkParseError.empty }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("ss://") {
            return try parseShadowsocks(trimmed)
        }
        if lower.hasPrefix("trojan://") {
            return try parseTrojan(trimmed)
        }
        if lower.hasPrefix("vless://") {
            return try parseVLESS(trimmed)
        }
        if lower.hasPrefix("vmess://") {
            return try parseVMess(trimmed)
        }
        if lower.hasPrefix("hysteria2://") || lower.hasPrefix("hy2://") {
            return try parseHysteria2(trimmed)
        }
        if lower.hasPrefix("socks://") || lower.hasPrefix("socks5://") {
            return try parseSocks(trimmed)
        }
        throw LinkParseError.unsupported
    }

    // ss://METHOD:PASSWORD@HOST:PORT#NAME  or  ss://BASE64#NAME
    private static func parseShadowsocks(_ link: String) throws -> VPNServer {
        let withoutScheme = String(link.dropFirst("ss://".count))
        let parts = withoutScheme.split(separator: "#", maxSplits: 1).map(String.init)
        let body = parts[0]
        let name = parts.count > 1 ? decodeName(parts[1]) : "Shadowsocks"

        if body.contains("@") {
            // method:password@host:port
            let userHost = body.split(separator: "@", maxSplits: 1).map(String.init)
            guard userHost.count == 2 else { throw LinkParseError.malformed }
            let methodPass = userHost[0].split(separator: ":", maxSplits: 1).map(String.init)
            let hostPort = splitHostPort(userHost[1])
            guard methodPass.count == 2, let port = hostPort.port else { throw LinkParseError.malformed }
            return VPNServer(
                name: name,
                proto: .shadowsocks,
                host: hostPort.host,
                port: port,
                password: methodPass[1].removingPercentEncoding ?? methodPass[1],
                method: methodPass[0],
                rawLink: link
            )
        }

        // Base64 body
        let padded = padBase64(body.components(separatedBy: "/").first ?? body)
        guard let data = Data(base64Encoded: padded),
              let decoded = String(data: data, encoding: .utf8),
              decoded.contains("@") else {
            throw LinkParseError.malformed
        }
        return try parseShadowsocks("ss://\(decoded)#\(name)")
    }

    private static func parseTrojan(_ link: String) throws -> VPNServer {
        guard let url = URL(string: link),
              let host = url.host,
              let port = url.port ?? Optional(443),
              let password = url.user?.removingPercentEncoding else {
            throw LinkParseError.malformed
        }
        let name = decodeName(url.fragment ?? "Trojan")
        let sni = query(url, "sni") ?? host
        return VPNServer(
            name: name,
            proto: .trojan,
            host: host,
            port: port,
            password: password,
            sni: sni,
            rawLink: link
        )
    }

    private static func parseVLESS(_ link: String) throws -> VPNServer {
        // Prefer URLComponents — fragments with emoji/%-encoding break URL(string:) sometimes.
        guard let components = URLComponents(string: link) ?? URLComponents(string: link.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? link),
              let host = components.host,
              let uuid = components.user else {
            throw LinkParseError.malformed
        }
        let port = components.port ?? 443
        let name = decodeName(components.fragment ?? "VLESS")
        let q: (String) -> String? = { key in
            components.queryItems?.first(where: { $0.name == key })?.value
        }
        return VPNServer(
            name: name,
            proto: .vless,
            host: host,
            port: port,
            uuid: uuid,
            sni: q("sni") ?? host,
            transport: q("type") ?? "tcp",
            rawLink: link,
            security: q("security") ?? "",
            flow: q("flow") ?? "",
            fingerprint: q("fp") ?? "",
            publicKey: q("pbk") ?? "",
            shortID: q("sid") ?? "",
            spiderX: q("spx") ?? "",
            wsPath: q("path") ?? "/",
            wsHost: q("host") ?? "",
            grpcServiceName: q("serviceName") ?? "GunService"
        )
    }

    private static func parseVMess(_ link: String) throws -> VPNServer {
        let body = String(link.dropFirst("vmess://".count))
        let padded = padBase64(body)
        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let host = json["add"] as? String,
              let portValue = json["port"] else {
            throw LinkParseError.malformed
        }
        let port: Int
        if let p = portValue as? Int {
            port = p
        } else if let s = portValue as? String, let p = Int(s) {
            port = p
        } else {
            throw LinkParseError.malformed
        }
        let name = (json["ps"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "VMess"
        return VPNServer(
            name: name,
            proto: .vmess,
            host: host,
            port: port,
            uuid: json["id"] as? String ?? "",
            method: json["scy"] as? String ?? "auto",
            sni: json["sni"] as? String ?? host,
            transport: json["net"] as? String ?? "tcp",
            rawLink: link
        )
    }

    private static func parseHysteria2(_ link: String) throws -> VPNServer {
        let normalized = link
            .replacingOccurrences(of: "hy2://", with: "hysteria2://")
        guard let url = URL(string: normalized),
              let host = url.host,
              let port = url.port ?? Optional(443) else {
            throw LinkParseError.malformed
        }
        let password = url.user?.removingPercentEncoding ?? ""
        let name = decodeName(url.fragment ?? "Hysteria2")
        return VPNServer(
            name: name,
            proto: .hysteria2,
            host: host,
            port: port,
            password: password,
            sni: query(url, "sni") ?? host,
            rawLink: link,
            hy2Obfs: query(url, "obfs") ?? "",
            hy2ObfsPassword: query(url, "obfs-password") ?? query(url, "obfs_password") ?? ""
        )
    }

    private static func parseSocks(_ link: String) throws -> VPNServer {
        let normalized = link.replacingOccurrences(of: "socks5://", with: "socks://")
        guard let url = URL(string: normalized),
              let host = url.host,
              let port = url.port ?? Optional(1080) else {
            throw LinkParseError.malformed
        }
        let name = decodeName(url.fragment ?? "SOCKS5")
        return VPNServer(
            name: name,
            proto: .socks,
            host: host,
            port: port,
            password: url.password ?? "",
            uuid: url.user ?? "",
            rawLink: link
        )
    }

    private static func query(_ url: URL, _ key: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == key }?
            .value
    }

    private static func decodeName(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    private static func padBase64(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = cleaned.count % 4
        if remainder == 0 { return cleaned }
        return cleaned + String(repeating: "=", count: 4 - remainder)
    }

    private static func splitHostPort(_ value: String) -> (host: String, port: Int?) {
        if value.hasPrefix("["), let end = value.firstIndex(of: "]") {
            let host = String(value[value.index(after: value.startIndex)..<end])
            let rest = value[value.index(after: end)...]
            if rest.hasPrefix(":"), let port = Int(rest.dropFirst()) {
                return (host, port)
            }
            return (host, nil)
        }
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2, let port = Int(parts[1]) {
            return (parts[0], port)
        }
        return (value, nil)
    }
}
