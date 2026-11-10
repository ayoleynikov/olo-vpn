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
        if (lower.StartsWith("hysteria2://") || lower.StartsWith("hy2://") || lower.StartsWith("hysteria://"))
            return ParseHy2(trimmed);
        if (lower.StartsWith("tuic://")) return ParseTuic(trimmed);
        if (lower.StartsWith("ss://")) return ParseSs(trimmed);
        if (lower.StartsWith("vmess://")) return ParseVmess(trimmed);
        if (lower.StartsWith("socks://") || lower.StartsWith("socks5://")) return ParseSocks(trimmed);
        if (lower.StartsWith("wireguard://") || lower.StartsWith("wg://")) return ParseWireGuard(trimmed);
        if ((lower.StartsWith("http://") || lower.StartsWith("https://")) &&
            trimmed.Contains('@') &&
            trimmed[..trimmed.IndexOf('@')].Contains("://"))
            return ParseHttp(trimmed);
        throw new InvalidOperationException("Этот формат пока не поддерживается");
    }

    public static List<VpnServer> ParseMany(string raw)
    {
        var trimmed = raw.Trim();
        if (string.IsNullOrEmpty(trimmed)) return new();
        var chunks = trimmed.Split(new[] { '\n', '\r', ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(l => !l.StartsWith('#'))
            .ToList();
        if (chunks.Count == 1)
        {
            var split = SplitProxyLinks(chunks[0]);
            if (split.Count > 1) chunks = split;
        }
        var seen = new HashSet<string>();
        var outList = new List<VpnServer>();
        foreach (var chunk in chunks)
        {
            try
            {
                var s = Parse(chunk);
                var key = $"{s.Proto}|{s.Host}|{s.Port}|{s.Uuid}|{s.Password}";
                if (seen.Add(key)) outList.Add(s);
            }
            catch { /* skip */ }
        }
        return outList;
    }

    private static Dictionary<string, string> Query(Uri uri)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var q = uri.Query.TrimStart('?');
        if (string.IsNullOrEmpty(q)) return map;
        foreach (var part in q.Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var kv = part.Split('=', 2);
            map[Uri.UnescapeDataString(kv[0])] = kv.Length > 1 ? Uri.UnescapeDataString(kv[1]) : "";
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
            WsHost = q.GetValueOrDefault("host", ""),
            GrpcServiceName = q.GetValueOrDefault("serviceName", "GunService"),
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
            Transport = q.GetValueOrDefault("type", "tcp"),
            Security = q.GetValueOrDefault("security", ""),
            Fingerprint = q.GetValueOrDefault("fp", ""),
            PublicKey = q.GetValueOrDefault("pbk", ""),
            ShortId = q.GetValueOrDefault("sid", ""),
            WsPath = q.GetValueOrDefault("path", "/"),
            WsHost = q.GetValueOrDefault("host", ""),
            RawLink = link
        };
    }

    private static VpnServer ParseHy2(string link)
    {
        var normalized = link
            .Replace("hy2://", "hysteria2://", StringComparison.OrdinalIgnoreCase)
            .Replace("hysteria://", "hysteria2://", StringComparison.OrdinalIgnoreCase);
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

    private static VpnServer ParseTuic(string link)
    {
        var uri = new Uri(link);
        var q = Query(uri);
        var user = Uri.UnescapeDataString(uri.UserInfo);
        var uuid = user;
        var password = "";
        if (user.Contains(':'))
        {
            var parts = user.Split(':', 2);
            uuid = parts[0];
            password = parts[1];
        }
        return new VpnServer
        {
            Name = Uri.UnescapeDataString(string.IsNullOrEmpty(uri.Fragment) ? "TUIC" : uri.Fragment.TrimStart('#')),
            Proto = ProxyProto.tuic,
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : 443,
            Uuid = uuid,
            Password = password,
            Sni = q.GetValueOrDefault("sni", uri.Host),
            Security = "tls",
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
            string method, password;
            if (userHost[0].Contains(':'))
            {
                var methodPass = userHost[0].Split(':', 2);
                method = methodPass[0];
                password = methodPass.Length > 1 ? Uri.UnescapeDataString(methodPass[1]) : "";
            }
            else
            {
                var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(PadB64(userHost[0])));
                var methodPass = decoded.Split(':', 2);
                method = methodPass[0];
                password = methodPass.Length > 1 ? methodPass[1] : "";
            }
            var hp = userHost[1].Split('?', 2)[0].Split('/', 2)[0].Split(':', 2);
            return new VpnServer
            {
                Name = name,
                Proto = ProxyProto.shadowsocks,
                Host = hp[0],
                Port = hp.Length > 1 && int.TryParse(hp[1], out var p) ? p : 8388,
                Method = method,
                Password = password,
                RawLink = link
            };
        }
        var decodedBody = Encoding.UTF8.GetString(Convert.FromBase64String(PadB64(body.Split('/')[0])));
        return ParseSs($"ss://{decodedBody}#{Uri.EscapeDataString(name)}");
    }

    private static VpnServer ParseVmess(string link)
    {
        var json = Encoding.UTF8.GetString(Convert.FromBase64String(PadB64(link["vmess://".Length..])));
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        var tls = root.TryGetProperty("tls", out var tlsEl) ? tlsEl.GetString() ?? "" : "";
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
            Security = tls,
            WsPath = root.TryGetProperty("path", out var path) ? path.GetString() ?? "/" : "/",
            WsHost = root.TryGetProperty("host", out var host) ? host.GetString() ?? "" : "",
            RawLink = link
        };
    }

    private static VpnServer ParseSocks(string link)
    {
        var uri = new Uri(link.Replace("socks5://", "socks://", StringComparison.OrdinalIgnoreCase));
        var user = uri.UserInfo.Split(':', 2);
        return new VpnServer
        {
            Name = string.IsNullOrEmpty(uri.Fragment) ? "SOCKS5" : Uri.UnescapeDataString(uri.Fragment.TrimStart('#')),
            Proto = ProxyProto.socks,
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : 1080,
            Uuid = user.Length > 0 ? user[0] : "",
            Password = user.Length > 1 ? user[1] : "",
            RawLink = link
        };
    }

    private static VpnServer ParseHttp(string link)
    {
        var uri = new Uri(link);
        var user = uri.UserInfo.Split(':', 2);
        return new VpnServer
        {
            Name = string.IsNullOrEmpty(uri.Fragment) ? "HTTP" : Uri.UnescapeDataString(uri.Fragment.TrimStart('#')),
            Proto = ProxyProto.http,
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : (link.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ? 443 : 80),
            Uuid = user.Length > 0 ? Uri.UnescapeDataString(user[0]) : "",
            Password = user.Length > 1 ? Uri.UnescapeDataString(user[1]) : "",
            RawLink = link
        };
    }

    private static VpnServer ParseWireGuard(string link)
    {
        var normalized = link.Replace("wg://", "wireguard://", StringComparison.OrdinalIgnoreCase);
        var uri = new Uri(normalized);
        var q = Query(uri);
        return new VpnServer
        {
            Name = string.IsNullOrEmpty(uri.Fragment) ? "WireGuard" : Uri.UnescapeDataString(uri.Fragment.TrimStart('#')),
            Proto = ProxyProto.wireguard,
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : 51820,
            Password = Uri.UnescapeDataString(uri.UserInfo),
            Uuid = q.GetValueOrDefault("publickey", q.GetValueOrDefault("publicKey", q.GetValueOrDefault("peer", ""))),
            Method = q.GetValueOrDefault("address", q.GetValueOrDefault("ip", "10.0.0.2/32")),
            RawLink = link
        };
    }

    private static List<string> SplitProxyLinks(string blob)
    {
        var schemes = new[]
        {
            "ss://", "vmess://", "vless://", "trojan://", "hysteria2://", "hy2://",
            "hysteria://", "tuic://", "socks://", "socks5://", "wireguard://", "wg://"
        };
        var lower = blob.ToLowerInvariant();
        var indices = new List<int>();
        foreach (var scheme in schemes)
        {
            var idx = 0;
            while ((idx = lower.IndexOf(scheme, idx, StringComparison.Ordinal)) >= 0)
            {
                indices.Add(idx);
                idx += scheme.Length;
            }
        }
        var sorted = indices.Distinct().OrderBy(i => i).ToList();
        if (sorted.Count <= 1) return new List<string> { blob };
        var parts = new List<string>();
        for (var i = 0; i < sorted.Count; i++)
        {
            var start = sorted[i];
            var end = i + 1 < sorted.Count ? sorted[i + 1] : blob.Length;
            parts.Add(blob[start..end].Trim());
        }
        return parts.Where(p => p.Length > 0).ToList();
    }

    private static string PadB64(string value)
    {
        var cleaned = value.Replace('-', '+').Replace('_', '/');
        var rem = cleaned.Length % 4;
        return rem == 0 ? cleaned : cleaned + new string('=', 4 - rem);
    }
}
