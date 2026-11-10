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
    /// Parse one URI / share link.
    static func parse(_ raw: String) throws -> VPNServer {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LinkParseError.empty }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("ss://") { return try parseShadowsocks(trimmed) }
        if lower.hasPrefix("trojan://") { return try parseTrojan(trimmed) }
        if lower.hasPrefix("vless://") { return try parseVLESS(trimmed) }
        if lower.hasPrefix("vmess://") { return try parseVMess(trimmed) }
        if lower.hasPrefix("hysteria2://") || lower.hasPrefix("hy2://") || lower.hasPrefix("hysteria://") {
            return try parseHysteria2(trimmed)
        }
        if lower.hasPrefix("tuic://") { return try parseTUIC(trimmed) }
        if lower.hasPrefix("socks://") || lower.hasPrefix("socks5://") { return try parseSocks(trimmed) }
        if lower.hasPrefix("wireguard://") || lower.hasPrefix("wg://") { return try parseWireGuard(trimmed) }
        // HTTP(S) proxy node: must include userinfo so plain subscription URLs stay elsewhere.
        if (lower.hasPrefix("http://") || lower.hasPrefix("https://")),
           let at = trimmed.firstIndex(of: "@"),
           trimmed[..<at].contains("://") {
            return try parseHTTPProxy(trimmed)
        }
        throw LinkParseError.unsupported
    }

    /// Bulk paste: newlines, commas, or inline scheme boundaries.
    static func parseMany(_ raw: String) -> [VPNServer] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var chunks = trimmed
            .components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: CharacterSet(charactersIn: ",;")) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        if chunks.count == 1, let only = chunks.first {
            let split = splitProxyLinks(only)
            if split.count > 1 { chunks = split }
        }

        var out: [VPNServer] = []
        var seen = Set<String>()
        for chunk in chunks {
            guard let server = try? parse(chunk) else { continue }
            let key = "\(server.proto.rawValue)|\(server.host)|\(server.port)|\(server.uuid)|\(server.password)"
            if seen.insert(key).inserted {
                out.append(server)
            }
        }
        return out
    }

    // MARK: - Schemes

    private static func parseShadowsocks(_ link: String) throws -> VPNServer {
        let withoutScheme = String(link.dropFirst("ss://".count))
        let parts = withoutScheme.split(separator: "#", maxSplits: 1).map(String.init)
        var body = parts[0]
        let name = parts.count > 1 ? decodeName(parts[1]) : "Shadowsocks"

        // SIP002: base64(method:password)@host:port/?plugin=...
        if body.contains("@") {
            let userHost = body.split(separator: "@", maxSplits: 1).map(String.init)
            guard userHost.count == 2 else { throw LinkParseError.malformed }
            var method = ""
            var password = ""
            let user = userHost[0]
            if user.contains(":") {
                let mp = user.split(separator: ":", maxSplits: 1).map(String.init)
                method = mp[0]
                password = mp[1].removingPercentEncoding ?? mp[1]
            } else if let decoded = decodeBase64String(user), decoded.contains(":") {
                let mp = decoded.split(separator: ":", maxSplits: 1).map(String.init)
                method = mp[0]
                password = mp.count > 1 ? mp[1] : ""
            } else {
                throw LinkParseError.malformed
            }
            let hostPart = userHost[1].components(separatedBy: "/").first ?? userHost[1]
            let hostPort = splitHostPort(hostPart.components(separatedBy: "?").first ?? hostPart)
            guard let port = hostPort.port else { throw LinkParseError.malformed }
            return VPNServer(
                name: name,
                proto: .shadowsocks,
                host: hostPort.host,
                port: port,
                password: password,
                method: method,
                rawLink: link
            )
        }

        let padded = padBase64(body.components(separatedBy: "/").first ?? body)
        guard let data = Data(base64Encoded: padded),
              let decoded = String(data: data, encoding: .utf8),
              decoded.contains("@") else {
            throw LinkParseError.malformed
        }
        return try parseShadowsocks("ss://\(decoded)#\(name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? name)")
    }

    private static func parseTrojan(_ link: String) throws -> VPNServer {
        guard let components = URLComponents(string: link) ?? URLComponents(string: percentEncodeIfNeeded(link)),
              let host = components.host,
              let password = components.user?.removingPercentEncoding else {
            throw LinkParseError.malformed
        }
        let port = components.port ?? 443
        let q = queryMap(components)
        return VPNServer(
            name: decodeName(components.fragment ?? "Trojan"),
            proto: .trojan,
            host: host,
            port: port,
            password: password,
            sni: q["sni"] ?? host,
            transport: q["type"] ?? "tcp",
            rawLink: link,
            security: q["security"] ?? "",
            fingerprint: q["fp"] ?? "",
            publicKey: q["pbk"] ?? "",
            shortID: q["sid"] ?? "",
            wsPath: q["path"] ?? "/",
            wsHost: q["host"] ?? "",
            grpcServiceName: q["serviceName"] ?? "GunService"
        )
    }

    private static func parseVLESS(_ link: String) throws -> VPNServer {
        guard let components = URLComponents(string: link) ?? URLComponents(string: percentEncodeIfNeeded(link)),
              let host = components.host,
              let uuid = components.user else {
            throw LinkParseError.malformed
        }
        let q = queryMap(components)
        return VPNServer(
            name: decodeName(components.fragment ?? "VLESS"),
            proto: .vless,
            host: host,
            port: components.port ?? 443,
            uuid: uuid,
            sni: q["sni"] ?? host,
            transport: q["type"] ?? "tcp",
            rawLink: link,
            security: q["security"] ?? "",
            flow: q["flow"] ?? "",
            fingerprint: q["fp"] ?? "",
            publicKey: q["pbk"] ?? "",
            shortID: q["sid"] ?? "",
            spiderX: q["spx"] ?? "",
            wsPath: q["path"] ?? "/",
            wsHost: q["host"] ?? "",
            grpcServiceName: q["serviceName"] ?? "GunService"
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
        if let p = portValue as? Int { port = p }
        else if let s = portValue as? String, let p = Int(s) { port = p }
        else { throw LinkParseError.malformed }

        let tlsFlag = (json["tls"] as? String)?.lowercased() ?? ""
        let security = tlsFlag == "tls" || tlsFlag == "reality" ? tlsFlag : (json["security"] as? String ?? "")
        return VPNServer(
            name: (json["ps"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "VMess",
            proto: .vmess,
            host: host,
            port: port,
            uuid: json["id"] as? String ?? "",
            method: json["scy"] as? String ?? "auto",
            sni: (json["sni"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? host,
            transport: json["net"] as? String ?? "tcp",
            rawLink: link,
            security: security,
            fingerprint: json["fp"] as? String ?? "",
            publicKey: json["pbk"] as? String ?? "",
            shortID: json["sid"] as? String ?? "",
            wsPath: json["path"] as? String ?? "/",
            wsHost: json["host"] as? String ?? "",
            grpcServiceName: json["path"] as? String ?? "GunService"
        )
    }

    private static func parseHysteria2(_ link: String) throws -> VPNServer {
        let normalized = link
            .replacingOccurrences(of: "hy2://", with: "hysteria2://", options: .caseInsensitive)
            .replacingOccurrences(of: "hysteria://", with: "hysteria2://", options: .caseInsensitive)
        guard let components = URLComponents(string: normalized) ?? URLComponents(string: percentEncodeIfNeeded(normalized)),
              let host = components.host else {
            throw LinkParseError.malformed
        }
        let q = queryMap(components)
        let password = components.user?.removingPercentEncoding
            ?? q["auth"]
            ?? q["password"]
            ?? ""
        return VPNServer(
            name: decodeName(components.fragment ?? "Hysteria2"),
            proto: .hysteria2,
            host: host,
            port: components.port ?? 443,
            password: password,
            sni: q["sni"] ?? host,
            rawLink: link,
            hy2Obfs: q["obfs"] ?? "",
            hy2ObfsPassword: q["obfs-password"] ?? q["obfs_password"] ?? ""
        )
    }

    private static func parseTUIC(_ link: String) throws -> VPNServer {
        guard let components = URLComponents(string: link) ?? URLComponents(string: percentEncodeIfNeeded(link)),
              let host = components.host else {
            throw LinkParseError.malformed
        }
        let userInfo = components.user?.removingPercentEncoding ?? ""
        let passwordFromURL = components.password?.removingPercentEncoding ?? ""
        var uuid = userInfo
        var password = passwordFromURL
        if password.isEmpty, userInfo.contains(":") {
            let parts = userInfo.split(separator: ":", maxSplits: 1).map(String.init)
            uuid = parts[0]
            password = parts.count > 1 ? parts[1] : ""
        }
        let q = queryMap(components)
        return VPNServer(
            name: decodeName(components.fragment ?? "TUIC"),
            proto: .tuic,
            host: host,
            port: components.port ?? 443,
            password: password,
            uuid: uuid,
            sni: q["sni"] ?? host,
            rawLink: link,
            security: "tls",
            fingerprint: q["fp"] ?? ""
        )
    }

    private static func parseSocks(_ link: String) throws -> VPNServer {
        let normalized = link.replacingOccurrences(of: "socks5://", with: "socks://", options: .caseInsensitive)
        guard let components = URLComponents(string: normalized) ?? URLComponents(string: percentEncodeIfNeeded(normalized)),
              let host = components.host else {
            throw LinkParseError.malformed
        }
        return VPNServer(
            name: decodeName(components.fragment ?? "SOCKS5"),
            proto: .socks,
            host: host,
            port: components.port ?? 1080,
            password: components.password ?? "",
            uuid: components.user ?? "",
            rawLink: link
        )
    }

    private static func parseHTTPProxy(_ link: String) throws -> VPNServer {
        guard let components = URLComponents(string: link) ?? URLComponents(string: percentEncodeIfNeeded(link)),
              let host = components.host else {
            throw LinkParseError.malformed
        }
        return VPNServer(
            name: decodeName(components.fragment ?? "HTTP"),
            proto: .http,
            host: host,
            port: components.port ?? (link.lowercased().hasPrefix("https://") ? 443 : 80),
            password: components.password?.removingPercentEncoding ?? "",
            uuid: components.user?.removingPercentEncoding ?? "",
            rawLink: link
        )
    }

    private static func parseWireGuard(_ link: String) throws -> VPNServer {
        let normalized = link.replacingOccurrences(of: "wg://", with: "wireguard://", options: .caseInsensitive)
        guard let components = URLComponents(string: normalized) ?? URLComponents(string: percentEncodeIfNeeded(normalized)),
              let host = components.host,
              let privateKey = components.user?.removingPercentEncoding else {
            throw LinkParseError.malformed
        }
        let q = queryMap(components)
        return VPNServer(
            name: decodeName(components.fragment ?? "WireGuard"),
            proto: .wireguard,
            host: host,
            port: components.port ?? 51820,
            password: privateKey,
            uuid: q["publickey"] ?? q["publicKey"] ?? q["peer"] ?? "",
            method: q["address"] ?? q["ip"] ?? "10.0.0.2/32",
            rawLink: link
        )
    }

    // MARK: - Helpers

    private static func queryMap(_ components: URLComponents) -> [String: String] {
        var map: [String: String] = [:]
        for item in components.queryItems ?? [] {
            map[item.name] = item.value ?? ""
        }
        return map
    }

    private static func decodeName(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    private static func percentEncodeIfNeeded(_ link: String) -> String {
        link.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? link
    }

    private static func padBase64(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = cleaned.count % 4
        if remainder == 0 { return cleaned }
        return cleaned + String(repeating: "=", count: 4 - remainder)
    }

    private static func decodeBase64String(_ value: String) -> String? {
        guard let data = Data(base64Encoded: padBase64(value)) else { return nil }
        return String(data: data, encoding: .utf8)
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

    private static func splitProxyLinks(_ blob: String) -> [String] {
        let schemes = ["ss://", "vmess://", "vless://", "trojan://", "hysteria2://", "hy2://", "hysteria://", "tuic://", "socks://", "socks5://", "wireguard://", "wg://"]
        var indices: [String.Index] = []
        let lower = blob.lowercased()
        for scheme in schemes {
            var search = lower.startIndex
            while let r = lower.range(of: scheme, range: search..<lower.endIndex) {
                indices.append(r.lowerBound)
                search = r.upperBound
            }
        }
        let sorted = indices.sorted()
        guard sorted.count > 1 else { return [blob] }
        var parts: [String] = []
        for i in 0..<sorted.count {
            let start = sorted[i]
            let end = i + 1 < sorted.count ? sorted[i + 1] : blob.endIndex
            parts.append(String(blob[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return parts.filter { !$0.isEmpty }
    }
}
