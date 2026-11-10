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
            if needsTransport(server) {
                outbound["transport"] = transportObject(server)
            }
        case .vless:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["uuid"] = server.uuid
            outbound["packet_encoding"] = "xudp"
            if !server.flow.isEmpty {
                outbound["flow"] = server.flow
            }
            if needsTransport(server) {
                outbound["transport"] = transportObject(server)
            }
            outbound["tls"] = tlsObject(server)
        case .vmess:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["uuid"] = server.uuid
            outbound["security"] = server.method.isEmpty ? "auto" : server.method
            if needsTransport(server) {
                outbound["transport"] = transportObject(server)
            }
            if !server.security.isEmpty || !server.sni.isEmpty {
                outbound["tls"] = tlsObject(server)
            }
        case .hysteria2:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["password"] = server.password.isEmpty ? server.uuid : server.password
            if !server.hy2Obfs.isEmpty {
                outbound["obfs"] = [
                    "type": server.hy2Obfs,
                    "password": server.hy2ObfsPassword
                ]
            }
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
            if !server.uuid.isEmpty { outbound["username"] = server.uuid }
            if !server.password.isEmpty { outbound["password"] = server.password }
        case .http:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            if !server.uuid.isEmpty { outbound["username"] = server.uuid }
            if !server.password.isEmpty { outbound["password"] = server.password }
        case .wireguard:
            outbound["server"] = server.host
            outbound["server_port"] = server.port
            outbound["private_key"] = server.password
            outbound["peer_public_key"] = server.uuid
            outbound["local_address"] = [server.method.isEmpty ? "10.0.0.2/32" : server.method]
        }

        var routeRules: [[String: Any]] = [
            ["action": "sniff"],
            ["protocol": ["dns"], "action": "hijack-dns"]
        ]

        if protection.allowLAN {
            routeRules.append(["ip_is_private": true, "outbound": "direct"])
        }

        let localDirect = routeMode == .smart && localPolicy == .bypass
        if localDirect {
            routeRules.append(contentsOf: localRules(for: localRegion))
        }

        let inet4Address = ["172.19.0.1/30"]
        let inet6Address = protection.blockIPv6 ? [] : ["fdfe:dcba:9876::1/126"]

        let tun: [String: Any] = [
            "type": "tun",
            "tag": "tun-in",
            "mtu": 9000,
            "address": inet4Address + inet6Address,
            "auto_route": true,
            "strict_route": protection.killSwitch,
            "stack": "system"
        ]

        // Legacy DNS schema (sing-box 1.11 binary): address URL, not typed servers.
        var dnsServers: [[String: Any]] = []
        if protection.dnsThroughVPN {
            dnsServers = [
                ["tag": "remote", "address": "tls://1.1.1.1", "detour": "proxy"],
                ["tag": "local", "address": "8.8.8.8", "detour": "direct"]
            ]
        } else {
            dnsServers = [["tag": "local", "address": "8.8.8.8"]]
        }

        let config: [String: Any] = [
            "log": ["level": "info", "timestamp": true],
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
                "final": "proxy",
                "auto_detect_interface": true
            ],
            "experimental": [
                "clash_api": [
                    "external_controller": "127.0.0.1:9090",
                    "secret": AppConstants.clashSecret
                ],
                "cache_file": ["enabled": true]
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

    private static func needsTransport(_ server: VPNServer) -> Bool {
        let t = server.transport.lowercased()
        return !t.isEmpty && t != "tcp"
    }

    private static func tlsObject(_ server: VPNServer) -> [String: Any] {
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": server.sni.isEmpty ? server.host : server.sni
        ]
        if !server.fingerprint.isEmpty {
            tls["utls"] = ["enabled": true, "fingerprint": server.fingerprint]
        }
        let security = server.security.lowercased()
        if security == "reality" || !server.publicKey.isEmpty {
            var reality: [String: Any] = [
                "enabled": true,
                "public_key": server.publicKey
            ]
            if !server.shortID.isEmpty {
                reality["short_id"] = server.shortID
            }
            tls["reality"] = reality
        }
        return tls
    }

    private static func transportObject(_ server: VPNServer) -> [String: Any] {
        switch server.transport.lowercased() {
        case "ws", "websocket":
            var ws: [String: Any] = ["type": "ws", "path": server.wsPath.isEmpty ? "/" : server.wsPath]
            if !server.wsHost.isEmpty {
                ws["headers"] = ["Host": server.wsHost]
            }
            return ws
        case "grpc":
            return [
                "type": "grpc",
                "service_name": server.grpcServiceName.isEmpty ? "GunService" : server.grpcServiceName
            ]
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
            return [["ip_is_private": true, "outbound": "direct"]]
        }
    }
}
