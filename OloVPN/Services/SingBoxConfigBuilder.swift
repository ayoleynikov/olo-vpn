import Foundation

struct ProtectionSettings: Codable, Equatable {
    var killSwitch: Bool = true
    var dnsThroughVPN: Bool = true
    var blockIPv6: Bool = true
    var allowLAN: Bool = true

    static let `default` = ProtectionSettings()
}

enum SingBoxConfigBuilder {
    static func build(
        server: VPNServer,
        routeMode: RouteMode,
        localPolicy: LocalTrafficPolicy,
        localRegion: LocalRegion,
        protection: ProtectionSettings
    ) throws -> String {
        var outbound: [String: Any] = [
            "tag": "proxy",
            "type": outboundType(server.proto)
        ]

        switch server.proto {
        case .shadowsocks:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["method"] = server.method.isEmpty ? "aes-256-gcm" : server.method
            outbound["password"] = server.password
        case .trojan:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["password"] = server.password
            outbound["tls"] = tlsObject(server)
        case .vless:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["uuid"] = server.uuid
            outbound["packet_encoding"] = "xudp"
            if !server.transport.isEmpty && server.transport != "tcp" {
                outbound["transport"] = transportObject(server)
            }
            outbound["tls"] = tlsObject(server)
        case .vmess:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["uuid"] = server.uuid
            outbound["security"] = server.method.isEmpty ? "auto" : server.method
            if !server.transport.isEmpty && server.transport != "tcp" {
                outbound["transport"] = transportObject(server)
            }
            outbound["tls"] = tlsObject(server)
        case .hysteria2:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["password"] = server.password
            outbound["tls"] = tlsObject(server)
        case .tuic:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["uuid"] = server.uuid
            outbound["password"] = server.password
            outbound["congestion_control"] = "bbr"
            outbound["tls"] = tlsObject(server)
        case .socks:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            if !server.uuid.isEmpty {
                outbound["username"] = server.uuid
            }
            if !server.password.isEmpty {
                outbound["password"] = server.password
            }
        case .http:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            if !server.uuid.isEmpty {
                outbound["username"] = server.uuid
            }
            if !server.password.isEmpty {
                outbound["password"] = server.password
            }
        case .wireguard:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["private_key"] = server.password
            outbound["peer_public_key"] = server.uuid
            outbound["local_address"] = ["10.0.0.2/32"]
        }

        var routeRules: [[String: Any]] = [
            [
                "action": "sniff"
            ],
            [
                "protocol": ["dns"],
                "action": "hijack-dns"
            ]
        ]

        if protection.allowLAN {
            routeRules.append([
                "ip_is_private": true,
                "outbound": "direct"
            ])
        }

        let localDirect = routeMode == .smart && localPolicy == .bypass
        if localDirect {
            routeRules.append(contentsOf: localRules(for: localRegion))
        }

        routeRules.append([
            "action": "route",
            "outbound": routeMode == .global || localPolicy == .throughVPN || !localDirect ? "proxy" : "proxy"
        ])

        // Final default
        let finalOutbound = "proxy"

        var dnsServers: [[String: Any]] = []
        if protection.dnsThroughVPN {
            dnsServers.append([
                "tag": "remote",
                "type": "tls",
                "server": "1.1.1.1",
                "detour": "proxy"
            ])
            dnsServers.append([
                "tag": "local",
                "type": "udp",
                "server": "8.8.8.8",
                "detour": "direct"
            ])
        } else {
            dnsServers.append([
                "tag": "local",
                "type": "udp",
                "server": "8.8.8.8"
            ])
        }

        var inet4Address = ["172.19.0.1/30"]
        var inet6Address: [String] = []
        if !protection.blockIPv6 {
            inet6Address = ["fdfe:dcba:9876::1/126"]
        }

        var tun: [String: Any] = [
            "type": "tun",
            "tag": "tun-in",
            "mtu": 9000,
            "address": inet4Address + inet6Address,
            "auto_route": true,
            "strict_route": protection.killSwitch,
            "stack": "system"
        ]
        if protection.blockIPv6 {
            // Keep IPv6 off the tunnel path; OS still may need exclude.
            tun["address"] = inet4Address
        }

        let config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true
            ],
            "dns": [
                "servers": dnsServers,
                "strategy": protection.blockIPv6 ? "ipv4_only" : "prefer_ipv4",
                "final": protection.dnsThroughVPN ? "remote" : "local"
            ],
            "inbounds": [tun],
            "outbounds": [
                outbound,
                ["type": "direct", "tag": "direct"],
                ["type": "block", "tag": "block"]
            ],
            "route": [
                "rules": routeRules,
                "final": finalOutbound,
                "auto_detect_interface": true
            ],
            "experimental": [
                "clash_api": [
                    "external_controller": "127.0.0.1:9090",
                    "secret": AppConstants.clashSecret
                ],
                "cache_file": [
                    "enabled": true
                ]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Olo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось собрать JSON"])
        }
        return json
    }

    private static func outboundType(_ proto: ProxyProtocol) -> String {
        switch proto {
        case .shadowsocks: return "shadowsocks"
        case .vmess: return "vmess"
        case .vless: return "vless"
        case .trojan: return "trojan"
        case .hysteria2: return "hysteria2"
        case .tuic: return "tuic"
        case .socks: return "socks"
        case .http: return "http"
        case .wireguard: return "wireguard"
        }
    }

    private static func tlsObject(_ server: VPNServer) -> [String: Any] {
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": server.sni.isEmpty ? server.host : server.sni
        ]
        return tls
    }

    private static func transportObject(_ server: VPNServer) -> [String: Any] {
        switch server.transport.lowercased() {
        case "ws", "websocket":
            return ["type": "ws", "path": "/"]
        case "grpc":
            return ["type": "grpc", "service_name": "GunService"]
        default:
            return ["type": server.transport]
        }
    }

    private static func localRules(for region: LocalRegion) -> [[String: Any]] {
        switch region {
        case .ru, .auto:
            return [
                ["domain_suffix": [".ru", ".su", ".xn--p1ai"], "outbound": "direct"],
                ["domain_keyword": ["yandex", "vk.", "mail.ru", "sber", "gosuslugi", "cbr.ru"], "outbound": "direct"]
            ]
        case .cn:
            return [
                ["domain_suffix": [".cn", ".com.cn"], "outbound": "direct"],
                ["domain_keyword": ["baidu", "qq.com", "weixin", "alipay", "taobao"], "outbound": "direct"]
            ]
        case .other:
            return [
                ["ip_is_private": true, "outbound": "direct"]
            ]
        }
    }
}
