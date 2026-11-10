using System.Text;
using System.Text.Json;
using Olo.Desktop.Models;

namespace Olo.Desktop.Services;

public static class SubscriptionImporter
{
    private static readonly HttpClient Client = new() { Timeout = TimeSpan.FromSeconds(30) };

    static SubscriptionImporter()
    {
        Client.DefaultRequestHeaders.UserAgent.ParseAdd("Shadowrocket/2101 CFNetwork Darwin");
    }

    public static bool IsSubscriptionUrl(string raw)
    {
        var t = raw.Trim();
        var lower = t.ToLowerInvariant();
        if (!(lower.StartsWith("http://") || lower.StartsWith("https://"))) return false;
        var at = t.IndexOf('@');
        if (at > 0 && t[..at].Contains("://")) return false;
        return true;
    }

    public static string? Remark(string raw)
    {
        var i = raw.IndexOf('#');
        return i < 0 ? null : Uri.UnescapeDataString(raw[(i + 1)..]);
    }

    public static async Task<List<VpnServer>> FetchServersAsync(string rawUrl, string? namePrefix = null, CancellationToken ct = default)
    {
        var withoutFragment = rawUrl.Trim().Split('#')[0];
        using var resp = await Client.GetAsync(withoutFragment, ct);
        resp.EnsureSuccessStatusCode();
        var text = (await resp.Content.ReadAsStringAsync(ct)).Trim();
        if (string.IsNullOrEmpty(text)) throw new InvalidOperationException("Подписка пустая");
        var decoded = DecodeBody(text);
        var servers = ParseJsonProfile(decoded) ?? new List<VpnServer>();
        if (servers.Count == 0) servers = LinkParser.ParseMany(decoded);
        if (!string.IsNullOrWhiteSpace(namePrefix))
        {
            foreach (var server in servers)
            {
                if (string.IsNullOrWhiteSpace(server.Name) || server.Name == server.Proto.ToString())
                    server.Name = $"{namePrefix} · {server.Endpoint}";
            }
        }
        if (servers.Count == 0) throw new InvalidOperationException("В подписке не нашлось понятных ссылок");
        return servers;
    }

    private static List<VpnServer>? ParseJsonProfile(string text)
    {
        var stripped = text.Trim();
        if (!(stripped.StartsWith('{') || stripped.StartsWith('['))) return null;
        try
        {
            using var doc = JsonDocument.Parse(stripped);
            var nodes = new List<JsonElement>();
            if (doc.RootElement.ValueKind == JsonValueKind.Array)
            {
                nodes.AddRange(doc.RootElement.EnumerateArray());
            }
            else if (doc.RootElement.TryGetProperty("proxies", out var proxies))
            {
                nodes.AddRange(proxies.EnumerateArray());
            }
            else if (doc.RootElement.TryGetProperty("outbounds", out var outbounds))
            {
                var skip = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                    { "direct", "block", "dns", "selector", "urltest", "relay" };
                foreach (var o in outbounds.EnumerateArray())
                {
                    var type = o.TryGetProperty("type", out var t) ? t.GetString() ?? "" : "";
                    if (!skip.Contains(type)) nodes.Add(o);
                }
            }
            var list = nodes.Select(MapNode).Where(s => s != null).Cast<VpnServer>().ToList();
            return list.Count == 0 ? null : list;
        }
        catch
        {
            return null;
        }
    }

    private static VpnServer? MapNode(JsonElement node)
    {
        var type = node.TryGetProperty("type", out var t) ? (t.GetString() ?? "").ToLowerInvariant() : "";
        var name = node.TryGetProperty("name", out var n) ? n.GetString()
            : node.TryGetProperty("tag", out var tag) ? tag.GetString() : type;
        var host = node.TryGetProperty("server", out var s) ? s.GetString() ?? "" : "";
        var port = 0;
        if (node.TryGetProperty("server_port", out var sp) && sp.ValueKind == JsonValueKind.Number) port = sp.GetInt32();
        else if (node.TryGetProperty("port", out var p))
            port = p.ValueKind == JsonValueKind.Number ? p.GetInt32() : int.Parse(p.GetString() ?? "0");
        if (string.IsNullOrEmpty(host) || port <= 0) return null;

        string Str(string key) => node.TryGetProperty(key, out var v) ? v.GetString() ?? "" : "";

        return type switch
        {
            "ss" or "shadowsocks" => new VpnServer
            {
                Name = name ?? "SS", Proto = ProxyProto.shadowsocks, Host = host, Port = port,
                Password = Str("password"), Method = string.IsNullOrEmpty(Str("cipher")) ? Str("method") : Str("cipher")
            },
            "vmess" => new VpnServer
            {
                Name = name ?? "VMess", Proto = ProxyProto.vmess, Host = host, Port = port,
                Uuid = Str("uuid"), Method = string.IsNullOrEmpty(Str("cipher")) ? "auto" : Str("cipher")
            },
            "vless" => new VpnServer
            {
                Name = name ?? "VLESS", Proto = ProxyProto.vless, Host = host, Port = port, Uuid = Str("uuid"), Sni = host
            },
            "trojan" => new VpnServer
            {
                Name = name ?? "Trojan", Proto = ProxyProto.trojan, Host = host, Port = port,
                Password = Str("password"), Sni = string.IsNullOrEmpty(Str("sni")) ? host : Str("sni")
            },
            "hysteria2" or "hy2" => new VpnServer
            {
                Name = name ?? "HY2", Proto = ProxyProto.hysteria2, Host = host, Port = port,
                Password = string.IsNullOrEmpty(Str("password")) ? Str("auth") : Str("password"),
                Sni = string.IsNullOrEmpty(Str("sni")) ? host : Str("sni")
            },
            "tuic" => new VpnServer
            {
                Name = name ?? "TUIC", Proto = ProxyProto.tuic, Host = host, Port = port,
                Uuid = Str("uuid"), Password = Str("password")
            },
            "socks" or "socks5" => new VpnServer
            {
                Name = name ?? "SOCKS", Proto = ProxyProto.socks, Host = host, Port = port,
                Uuid = Str("username"), Password = Str("password")
            },
            "http" => new VpnServer
            {
                Name = name ?? "HTTP", Proto = ProxyProto.http, Host = host, Port = port,
                Uuid = Str("username"), Password = Str("password")
            },
            "wireguard" => new VpnServer
            {
                Name = name ?? "WG", Proto = ProxyProto.wireguard, Host = host, Port = port,
                Password = string.IsNullOrEmpty(Str("private-key")) ? Str("private_key") : Str("private-key"),
                Uuid = string.IsNullOrEmpty(Str("public-key")) ? Str("peer_public_key") : Str("public-key")
            },
            _ => null
        };
    }

    private static string DecodeBody(string text)
    {
        var lower = text.ToLowerInvariant();
        if (text.TrimStart().StartsWith('{') || text.TrimStart().StartsWith('[')) return text;
        if (text.Contains("://") && (lower.Contains("ss://") || lower.Contains("vless://") || lower.Contains("vmess://")))
            return text;
        return TryDecodeB64(text) ?? TryDecodeB64(string.Concat(text.Where(c => !char.IsWhiteSpace(c)))) ?? text;
    }

    private static string? TryDecodeB64(string raw)
    {
        try
        {
            var rem = raw.Length % 4;
            var padded = rem == 0 ? raw : raw + new string('=', 4 - rem);
            var s = Encoding.UTF8.GetString(Convert.FromBase64String(padded));
            return s.Contains("://") || s.TrimStart().StartsWith('{') ? s : null;
        }
        catch { return null; }
    }
}
