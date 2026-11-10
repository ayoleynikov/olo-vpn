import Foundation

enum SubscriptionImportError: LocalizedError {
    case badURL
    case empty
    case noServers

    var errorDescription: String? {
        switch self {
        case .badURL: return "Проверьте URL подписки"
        case .empty: return "Подписка пустая"
        case .noServers: return "В подписке не нашлось понятных ссылок (ss/vless/trojan…)"
        }
    }
}

enum SubscriptionImporter {
    static func isSubscriptionURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return false }
        // `http://user:pass@host:port` is an HTTP proxy node, not a subscription list.
        if let at = trimmed.firstIndex(of: "@"), trimmed[..<at].contains("://") {
            return false
        }
        return true
    }

    static func fetchServers(from rawURL: String, namePrefix: String? = nil) async throws -> [VPNServer] {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutFragment: String
        if let hash = trimmed.firstIndex(of: "#") {
            withoutFragment = String(trimmed[..<hash])
        } else {
            withoutFragment = trimmed
        }

        guard let url = URL(string: withoutFragment) else {
            throw SubscriptionImportError.badURL
        }

        var request = URLRequest(url: url)
        // Many panels expect a client UA
        request.setValue("Shadowrocket/2101 CFNetwork Darwin", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .ascii)
            ?? ""

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SubscriptionImportError.empty
        }

        let decoded = decodeSubscriptionBody(text)
        let prefix = namePrefix?.trimmingCharacters(in: .whitespacesAndNewlines)

        var servers: [VPNServer] = []

        // Clash / sing-box JSON profiles
        if let fromJSON = parseJSONProfile(decoded) {
            servers.append(contentsOf: fromJSON)
        }

        // URI list (Shadowrocket-style)
        if servers.isEmpty {
            servers = LinkParser.parseMany(decoded)
        } else {
            // Also merge any inline URIs present alongside JSON
            for extra in LinkParser.parseMany(decoded) {
                if !servers.contains(where: {
                    $0.host == extra.host && $0.port == extra.port && $0.proto == extra.proto
                }) {
                    servers.append(extra)
                }
            }
        }

        if let prefix, !prefix.isEmpty {
            for i in servers.indices {
                if servers[i].name.isEmpty || servers[i].name == servers[i].proto.title || servers[i].name.count > 80 {
                    servers[i].name = "\(prefix) · \(servers[i].endpointLabel)"
                }
            }
        }

        if servers.isEmpty {
            throw SubscriptionImportError.noServers
        }
        return servers
    }

    /// Clash Meta `{"proxies":[…]}` or sing-box `{"outbounds":[…]}`.
    private static func parseJSONProfile(_ text: String) -> [VPNServer]? {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.hasPrefix("{") || stripped.hasPrefix("[") else { return nil }
        guard let data = stripped.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        var nodes: [[String: Any]] = []
        if let dict = root as? [String: Any] {
            if let proxies = dict["proxies"] as? [[String: Any]] {
                nodes = proxies
            } else if let outbounds = dict["outbounds"] as? [[String: Any]] {
                nodes = outbounds.filter { item in
                    let type = (item["type"] as? String)?.lowercased() ?? ""
                    return !["direct", "block", "dns", "selector", "urltest", "relay"].contains(type)
                }
            }
        } else if let array = root as? [[String: Any]] {
            nodes = array
        }
        guard !nodes.isEmpty else { return nil }

        var servers: [VPNServer] = []
        for node in nodes {
            if let server = mapClashOrSingNode(node) {
                servers.append(server)
            }
        }
        return servers.isEmpty ? nil : servers
    }

    private static func mapClashOrSingNode(_ node: [String: Any]) -> VPNServer? {
        let type = ((node["type"] as? String) ?? "").lowercased()
        let name = (node["name"] as? String) ?? (node["tag"] as? String) ?? type.uppercased()
        let host = (node["server"] as? String) ?? ""
        let port: Int = {
            if let p = node["server_port"] as? Int { return p }
            if let p = node["port"] as? Int { return p }
            if let s = node["port"] as? String, let p = Int(s) { return p }
            return 0
        }()
        guard !host.isEmpty, port > 0 else { return nil }

        switch type {
        case "ss", "shadowsocks":
            return VPNServer(
                name: name, proto: .shadowsocks, host: host, port: port,
                password: node["password"] as? String ?? "",
                method: (node["cipher"] as? String) ?? (node["method"] as? String) ?? "aes-256-gcm"
            )
        case "vmess":
            return VPNServer(
                name: name, proto: .vmess, host: host, port: port,
                uuid: (node["uuid"] as? String) ?? "",
                method: (node["cipher"] as? String) ?? (node["security"] as? String) ?? "auto",
                sni: (node["servername"] as? String) ?? (node["sni"] as? String) ?? host,
                transport: (node["network"] as? String) ?? (node["transport"] as? [String: Any]).flatMap { $0["type"] as? String } ?? "tcp"
            )
        case "vless":
            return VPNServer(
                name: name, proto: .vless, host: host, port: port,
                uuid: (node["uuid"] as? String) ?? "",
                sni: (node["servername"] as? String) ?? (node["tls"] as? [String: Any]).flatMap { $0["server_name"] as? String } ?? host,
                transport: (node["network"] as? String) ?? "tcp",
                security: ((node["reality-opts"] as? [String: Any]) != nil) ? "reality" : ((node["tls"] as? Bool) == true || node["tls"] is [String: Any] ? "tls" : ""),
                flow: node["flow"] as? String ?? "",
                publicKey: (node["reality-opts"] as? [String: Any])?["public-key"] as? String
                    ?? (node["tls"] as? [String: Any]).flatMap { ($0["reality"] as? [String: Any])?["public_key"] as? String } ?? "",
                shortID: (node["reality-opts"] as? [String: Any])?["short-id"] as? String
                    ?? (node["tls"] as? [String: Any]).flatMap { ($0["reality"] as? [String: Any])?["short_id"] as? String } ?? ""
            )
        case "trojan":
            return VPNServer(
                name: name, proto: .trojan, host: host, port: port,
                password: node["password"] as? String ?? "",
                sni: (node["sni"] as? String) ?? host
            )
        case "hysteria2", "hy2":
            return VPNServer(
                name: name, proto: .hysteria2, host: host, port: port,
                password: (node["password"] as? String) ?? (node["auth"] as? String) ?? "",
                sni: (node["sni"] as? String) ?? host
            )
        case "tuic":
            return VPNServer(
                name: name, proto: .tuic, host: host, port: port,
                password: node["password"] as? String ?? "",
                uuid: (node["uuid"] as? String) ?? "",
                sni: (node["sni"] as? String) ?? host
            )
        case "socks", "socks5":
            return VPNServer(
                name: name, proto: .socks, host: host, port: port,
                password: node["password"] as? String ?? "",
                uuid: (node["username"] as? String) ?? ""
            )
        case "http":
            return VPNServer(
                name: name, proto: .http, host: host, port: port,
                password: node["password"] as? String ?? "",
                uuid: (node["username"] as? String) ?? ""
            )
        case "wireguard":
            return VPNServer(
                name: name, proto: .wireguard, host: host, port: port,
                password: (node["private-key"] as? String) ?? (node["private_key"] as? String) ?? "",
                uuid: (node["public-key"] as? String) ?? (node["peer_public_key"] as? String) ?? ""
            )
        default:
            return nil
        }
    }

    static func remark(from rawURL: String) -> String? {
        guard let hash = rawURL.firstIndex(of: "#") else { return nil }
        let fragment = String(rawURL[rawURL.index(after: hash)...])
        return fragment.removingPercentEncoding ?? fragment
    }

    /// Shadowrocket-style bodies are often one long base64 line without padding.
    private static func decodeSubscriptionBody(_ text: String) -> String {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = stripped.lowercased()
        if stripped.contains("://"),
           lower.contains("ss://")
            || lower.contains("vless://")
            || lower.contains("vmess://")
            || lower.contains("trojan://")
            || lower.contains("hy2://")
            || lower.contains("hysteria")
            || lower.contains("tuic://")
            || lower.contains("socks")
            || lower.contains("wireguard://") {
            return stripped
        }
        if stripped.hasPrefix("{") || stripped.hasPrefix("[") {
            return stripped
        }

        if let decoded = decodeBase64ProxyList(stripped) {
            return decoded
        }

        let compact = stripped.replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
        if compact != stripped, let decoded = decodeBase64ProxyList(compact) {
            return decoded
        }

        return stripped
    }

    private static func decodeBase64ProxyList(_ raw: String) -> String? {
        let padded = padBase64(raw)
        let options: Data.Base64DecodingOptions = [.ignoreUnknownCharacters]
        guard let data = Data(base64Encoded: padded, options: options)
                ?? Data(base64Encoded: padBase64(raw
                    .replacingOccurrences(of: "-", with: "+")
                    .replacingOccurrences(of: "_", with: "/")), options: options),
              let asString = String(data: data, encoding: .utf8),
              asString.contains("://") else {
            return nil
        }
        return asString
    }

    private static func padBase64(_ value: String) -> String {
        let remainder = value.count % 4
        if remainder == 0 { return value }
        return value + String(repeating: "=", count: 4 - remainder)
    }

    private static func splitProxyLinks(_ blob: String) -> [String] {
        let pattern = #"(?=ss://|vmess://|vless://|trojan://|hysteria2://|hy2://|tuic://|socks://|socks5://)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return [blob]
        }
        let ns = blob as NSString
        let matches = regex.matches(in: blob, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [blob] }
        var result: [String] = []
        for (index, match) in matches.enumerated() {
            let start = match.range.location
            let end = index + 1 < matches.count ? matches[index + 1].range.location : ns.length
            let part = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty {
                result.append(part)
            }
        }
        return result
    }
}
