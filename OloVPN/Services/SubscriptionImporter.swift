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

        // Links may be separated by newlines OR appear inline after decode
        var chunks = decoded
            .components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: "\r") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        // Fallback: split on scheme boundaries if still one blob
        if chunks.count == 1, let only = chunks.first, only.contains("://") {
            let split = splitProxyLinks(only)
            if split.count > 1 {
                chunks = split
            }
        }

        var servers: [VPNServer] = []
        for line in chunks {
            if var server = try? LinkParser.parse(line) {
                if let prefix, !prefix.isEmpty,
                   server.name.isEmpty || server.name == server.proto.title || server.name.count > 80 {
                    server.name = "\(prefix) · \(server.endpointLabel)"
                }
                servers.append(server)
            }
        }

        if servers.isEmpty {
            throw SubscriptionImportError.noServers
        }
        return servers
    }

    static func remark(from rawURL: String) -> String? {
        guard let hash = rawURL.firstIndex(of: "#") else { return nil }
        let fragment = String(rawURL[rawURL.index(after: hash)...])
        return fragment.removingPercentEncoding ?? fragment
    }

    /// Shadowrocket-style bodies are often one long base64 line without padding.
    private static func decodeSubscriptionBody(_ text: String) -> String {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.contains("://"),
           stripped.lowercased().contains("ss://")
            || stripped.lowercased().contains("vless://")
            || stripped.lowercased().contains("vmess://")
            || stripped.lowercased().contains("trojan://") {
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
