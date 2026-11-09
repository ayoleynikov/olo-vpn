import Foundation

struct PublicIPInfo: Equatable {
    var ip: String
    var country: String
    var city: String
    var org: String
    var isVPNHint: Bool

    var summary: String {
        let place = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        return place.isEmpty ? ip : "\(ip) · \(place)"
    }
}

enum IPCheckService {
    static func fetch() async throws -> PublicIPInfo {
        // Public endpoints — no API key. Try a couple for resilience.
        if let info = try? await fetchIPAPI() { return info }
        return try await fetchIfConfig()
    }

    private static func fetchIPAPI() async throws -> PublicIPInfo {
        let url = URL(string: "https://ipapi.co/json/")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let ip = json["ip"] as? String ?? "—"
        let country = json["country_name"] as? String ?? json["country"] as? String ?? ""
        let city = json["city"] as? String ?? ""
        let org = json["org"] as? String ?? ""
        let hint = org.lowercased().contains("vpn")
            || org.lowercased().contains("hosting")
            || org.lowercased().contains("cloud")
        return PublicIPInfo(ip: ip, country: country, city: city, org: org, isVPNHint: hint)
    }

    private static func fetchIfConfig() async throws -> PublicIPInfo {
        let url = URL(string: "https://ifconfig.co/json")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return PublicIPInfo(
            ip: json["ip"] as? String ?? "—",
            country: json["country"] as? String ?? "",
            city: json["city"] as? String ?? "",
            org: json["asn_org"] as? String ?? "",
            isVPNHint: false
        )
    }
}
