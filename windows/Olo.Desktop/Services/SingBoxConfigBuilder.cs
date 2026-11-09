using System.Text.Json.Nodes;
using Olo.Desktop.Models;

namespace Olo.Desktop.Services;

public static class SingBoxConfigBuilder
{
    public static string Build(
        VpnServer server,
        RouteMode routeMode,
        LocalPolicy localPolicy,
        LocalRegion localRegion,
        Protection protection,
        bool useTun)
    {
        var outbound = new JsonObject
        {
            ["tag"] = "proxy",
            ["type"] = server.Proto.ToString()
        };

        switch (server.Proto)
        {
            case ProxyProto.shadowsocks:
                outbound["server"] = server.Host;
                outbound["server_port"] = server.Port;
                outbound["method"] = string.IsNullOrWhiteSpace(server.Method) ? "aes-256-gcm" : server.Method;
                outbound["password"] = server.Password;
                break;
            case ProxyProto.vless:
                outbound["server"] = server.Host;
                outbound["server_port"] = server.Port;
                outbound["uuid"] = server.Uuid;
                outbound["packet_encoding"] = "xudp";
                if (!string.IsNullOrWhiteSpace(server.Flow)) outbound["flow"] = server.Flow;
                if (!string.IsNullOrWhiteSpace(server.Transport) && server.Transport != "tcp")
                    outbound["transport"] = Transport(server);
                outbound["tls"] = Tls(server);
                break;
            case ProxyProto.trojan:
                outbound["server"] = server.Host;
                outbound["server_port"] = server.Port;
                outbound["password"] = server.Password;
                outbound["tls"] = Tls(server);
                break;
            case ProxyProto.hysteria2:
                outbound["server"] = server.Host;
                outbound["server_port"] = server.Port;
                outbound["password"] = string.IsNullOrWhiteSpace(server.Password) ? server.Uuid : server.Password;
                if (!string.IsNullOrWhiteSpace(server.Hy2Obfs))
                {
                    outbound["obfs"] = new JsonObject
                    {
                        ["type"] = server.Hy2Obfs,
                        ["password"] = server.Hy2ObfsPassword
                    };
                }
                outbound["tls"] = Tls(server);
                break;
            case ProxyProto.vmess:
                outbound["server"] = server.Host;
                outbound["server_port"] = server.Port;
                outbound["uuid"] = server.Uuid;
                outbound["security"] = string.IsNullOrWhiteSpace(server.Method) ? "auto" : server.Method;
                if (!string.IsNullOrWhiteSpace(server.Transport) && server.Transport != "tcp")
                    outbound["transport"] = Transport(server);
                outbound["tls"] = Tls(server);
                break;
            default:
                outbound["server"] = server.Host;
                outbound["server_port"] = server.Port;
                outbound["password"] = server.Password;
                break;
        }

        var rules = new JsonArray
        {
            new JsonObject { ["action"] = "sniff" },
            new JsonObject { ["protocol"] = new JsonArray("dns"), ["action"] = "hijack-dns" }
        };
        if (protection.AllowLan)
            rules.Add(new JsonObject { ["ip_is_private"] = true, ["outbound"] = "direct" });
        if (routeMode == RouteMode.smart && localPolicy == LocalPolicy.bypass)
        {
            foreach (var r in LocalRules(localRegion)) rules.Add(r);
        }

        JsonObject inbound;
        if (useTun)
        {
            var address = new JsonArray("172.19.0.1/30");
            if (!protection.BlockIpv6) address.Add("fdfe:dcba:9876::1/126");
            inbound = new JsonObject
            {
                ["type"] = "tun",
                ["tag"] = "tun-in",
                ["mtu"] = 9000,
                ["address"] = address,
                ["auto_route"] = true,
                ["strict_route"] = protection.KillSwitch,
                ["stack"] = "system"
            };
        }
        else
        {
            // System proxy / mixed inbound — works without admin / WinTun
            inbound = new JsonObject
            {
                ["type"] = "mixed",
                ["tag"] = "mixed-in",
                ["listen"] = "127.0.0.1",
                ["listen_port"] = 7890
            };
        }

        // Legacy DNS schema compatible with sing-box 1.11 release binaries.
        var dnsServers = new JsonArray();
        if (protection.DnsThroughVpn)
        {
            dnsServers.Add(new JsonObject
            {
                ["tag"] = "remote", ["address"] = "tls://1.1.1.1", ["detour"] = "proxy"
            });
            dnsServers.Add(new JsonObject
            {
                ["tag"] = "local", ["address"] = "8.8.8.8", ["detour"] = "direct"
            });
        }
        else
        {
            dnsServers.Add(new JsonObject { ["tag"] = "local", ["address"] = "8.8.8.8" });
        }

        var config = new JsonObject
        {
            ["log"] = new JsonObject { ["level"] = "info", ["timestamp"] = true },
            ["dns"] = new JsonObject
            {
                ["servers"] = dnsServers,
                ["strategy"] = protection.BlockIpv6 ? "ipv4_only" : "prefer_ipv4",
                ["final"] = protection.DnsThroughVpn ? "remote" : "local"
            },
            ["inbounds"] = new JsonArray(inbound),
            ["outbounds"] = new JsonArray(
                outbound,
                new JsonObject { ["type"] = "direct", ["tag"] = "direct" },
                new JsonObject { ["type"] = "block", ["tag"] = "block" }
            ),
            ["route"] = new JsonObject
            {
                ["rules"] = rules,
                ["final"] = "proxy",
                ["auto_detect_interface"] = true
            },
            ["experimental"] = new JsonObject
            {
                ["clash_api"] = new JsonObject
                {
                    ["external_controller"] = "127.0.0.1:9090",
                    ["secret"] = "olo-local"
                }
            }
        };

        return config.ToJsonString(new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
    }

    private static JsonObject Tls(VpnServer server)
    {
        var tls = new JsonObject
        {
            ["enabled"] = true,
            ["server_name"] = string.IsNullOrWhiteSpace(server.Sni) ? server.Host : server.Sni
        };
        if (!string.IsNullOrWhiteSpace(server.Fingerprint))
        {
            tls["utls"] = new JsonObject { ["enabled"] = true, ["fingerprint"] = server.Fingerprint };
        }
        if (string.Equals(server.Security, "reality", StringComparison.OrdinalIgnoreCase) ||
            !string.IsNullOrWhiteSpace(server.PublicKey))
        {
            var reality = new JsonObject { ["enabled"] = true, ["public_key"] = server.PublicKey };
            if (!string.IsNullOrWhiteSpace(server.ShortId))
                reality["short_id"] = server.ShortId;
            tls["reality"] = reality;
        }
        return tls;
    }

    private static JsonObject Transport(VpnServer server) =>
        server.Transport.ToLowerInvariant() switch
        {
            "ws" or "websocket" => new JsonObject { ["type"] = "ws", ["path"] = string.IsNullOrWhiteSpace(server.WsPath) ? "/" : server.WsPath },
            "grpc" => new JsonObject { ["type"] = "grpc", ["service_name"] = "GunService" },
            _ => new JsonObject { ["type"] = server.Transport }
        };

    private static IEnumerable<JsonObject> LocalRules(LocalRegion region)
    {
        if (region == LocalRegion.cn)
        {
            yield return new JsonObject
            {
                ["domain_suffix"] = new JsonArray(".cn", ".com.cn"),
                ["outbound"] = "direct"
            };
        }
        else
        {
            yield return new JsonObject
            {
                ["domain_suffix"] = new JsonArray(".ru", ".su"),
                ["outbound"] = "direct"
            };
        }
    }
}
