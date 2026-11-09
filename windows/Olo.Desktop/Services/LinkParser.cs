using System.Text;
using System.Text.Json;
using Olo.Desktop.Models;

namespace Olo.Desktop.Services;

public static class LinkParser
{
    public static VpnServer Parse(string raw)
    {
        var trimmed = raw.Trim();
        if (string.IsNullOrEmpty(trimmed)) throw new InvalidOperationException("Пустая ссылка");
        var lower = trimmed.ToLowerInvariant();
        if (lower.StartsWith("vless://")) return ParseVless(trimmed);
        if (lower.StartsWith("trojan://")) return ParseTrojan(trimmed);
        if (lower.StartsWith("hysteria2://") || lower.StartsWith("hy2://")) return ParseHy2(trimmed);
        if (lower.StartsWith("ss://")) return ParseSs(trimmed);
        if (lower.StartsWith("vmess://")) return ParseVmess(trimmed);
        if (lower.StartsWith("socks://") || lower.StartsWith("socks5://")) return ParseSocks(trimmed);
        throw new InvalidOperationException("Этот формат пока не поддерживается");
    }

    private static Dictionary<string, string> Query(Uri uri)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var q = uri.Query.TrimStart('?');
        if (string.IsNullOrEmpty(q)) return map;
        foreach (var part in q.Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var kv = part.Split('=', 2);
            var key = Uri.UnescapeDataString(kv[0]);
            var val = kv.Length > 1 ? Uri.UnescapeDataString(kv[1]) : "";
            map[key] = val;
        }
        return map;
    }

    private static VpnServer ParseVless(string link)
    {
        var uri = new Uri(link);
        var q = Query(uri);
        return new VpnServer
        {
            Name = Uri.UnescapeDataString(uri.Fragment.TrimStart('#')),
            Proto = ProxyProto.vless,
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : 443,
            Uuid = uri.UserInfo,
            Sni = q.GetValueOrDefault("sni", uri.Host),
            Transport = q.GetValueOrDefault("type", "tcp"),
            Security = q.GetValueOrDefault("security", ""),
            Flow = q.GetValueOrDefault("flow", ""),
            Fingerprint = q.GetValueOrDefault("fp", ""),
            PublicKey = q.GetValueOrDefault("pbk", ""),
            ShortId = q.GetValueOrDefault("sid", ""),
            WsPath = q.GetValueOrDefault("path", "/"),
            RawLink = link
        };
    }

    private static VpnServer ParseTrojan(string link)
    {
        var uri = new Uri(link);
        var q = Query(uri);
        return new VpnServer
        {
            Name = Uri.UnescapeDataString(string.IsNullOrEmpty(uri.Fragment) ? "Trojan" : uri.Fragment.TrimStart('#')),
            Proto = ProxyProto.trojan,
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : 443,
            Password = Uri.UnescapeDataString(uri.UserInfo),
            Sni = q.GetValueOrDefault("sni", uri.Host),
            RawLink = link
        };
    }

    private static VpnServer ParseHy2(string link)
    {
        var normalized = link.Replace("hy2://", "hysteria2://", StringComparison.OrdinalIgnoreCase);
        var uri = new Uri(normalized);
        var q = Query(uri);
        return new VpnServer
        {
            Name = Uri.UnescapeDataString(string.IsNullOrEmpty(uri.Fragment) ? "Hysteria2" : uri.Fragment.TrimStart('#')),
            Proto = ProxyProto.hysteria2,
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : 443,
            Password = Uri.UnescapeDataString(uri.UserInfo),
            Sni = q.GetValueOrDefault("sni", uri.Host),
            Hy2Obfs = q.GetValueOrDefault("obfs", ""),
            Hy2ObfsPassword = q.GetValueOrDefault("obfs-password", q.GetValueOrDefault("obfs_password", "")),
            RawLink = link
        };
    }

    private static VpnServer ParseSs(string link)
    {
        var without = link["ss://".Length..];
        var parts = without.Split('#', 2);
        var body = parts[0];
        var name = parts.Length > 1 ? Uri.UnescapeDataString(parts[1]) : "Shadowsocks";
        if (body.Contains('@'))
        {
            var userHost = body.Split('@', 2);
            var methodPass = userHost[0].Split(':', 2);
            var hp = userHost[1].Split(':', 2);
            return new VpnServer
            {
                Name = name,
                Proto = ProxyProto.shadowsocks,
                Host = hp[0],
                Port = hp.Length > 1 && int.TryParse(hp[1], out var p) ? p : 8388,
                Method = methodPass[0],
                Password = methodPass.Length > 1 ? Uri.UnescapeDataString(methodPass[1]) : "",
                RawLink = link
            };
        }
        var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(PadB64(body.Split('/')[0])));
        return ParseSs($"ss://{decoded}#{Uri.EscapeDataString(name)}");
    }

    private static VpnServer ParseVmess(string link)
    {
        var json = Encoding.UTF8.GetString(Convert.FromBase64String(PadB64(link["vmess://".Length..])));
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        return new VpnServer
        {
            Name = root.TryGetProperty("ps", out var ps) ? ps.GetString() ?? "VMess" : "VMess",
            Proto = ProxyProto.vmess,
            Host = root.GetProperty("add").GetString() ?? "",
            Port = root.GetProperty("port").ValueKind == JsonValueKind.Number
                ? root.GetProperty("port").GetInt32()
                : int.Parse(root.GetProperty("port").GetString() ?? "443"),
            Uuid = root.TryGetProperty("id", out var id) ? id.GetString() ?? "" : "",
            Method = root.TryGetProperty("scy", out var scy) ? scy.GetString() ?? "auto" : "auto",
            Sni = root.TryGetProperty("sni", out var sni) ? sni.GetString() ?? "" : "",
            Transport = root.TryGetProperty("net", out var net) ? net.GetString() ?? "tcp" : "tcp",
            RawLink = link
        };
    }

    private static VpnServer ParseSocks(string link)
    {
        var uri = new Uri(link.Replace("socks5://", "socks://", StringComparison.OrdinalIgnoreCase));
        var user = uri.UserInfo.Split(':', 2);
        return new VpnServer
        {
            Name = "SOCKS5",
            Proto = ProxyProto.socks,
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : 1080,
            Uuid = user.Length > 0 ? user[0] : "",
            Password = user.Length > 1 ? user[1] : "",
            RawLink = link
        };
    }

    private static string PadB64(string value)
    {
        var cleaned = value.Replace('-', '+').Replace('_', '/');
        var rem = cleaned.Length % 4;
        return rem == 0 ? cleaned : cleaned + new string('=', 4 - rem);
    }
}
