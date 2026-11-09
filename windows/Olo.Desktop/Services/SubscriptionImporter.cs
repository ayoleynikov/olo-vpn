using System.Text;
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
        var t = raw.Trim().ToLowerInvariant();
        return t.StartsWith("http://") || t.StartsWith("https://");
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
        var servers = new List<VpnServer>();
        foreach (var line in decoded.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (line.StartsWith('#')) continue;
            try
            {
                var server = LinkParser.Parse(line);
                if (!string.IsNullOrWhiteSpace(namePrefix) &&
                    (string.IsNullOrWhiteSpace(server.Name) || server.Name == server.Proto.ToString()))
                {
                    server.Name = $"{namePrefix} · {server.Endpoint}";
                }
                servers.Add(server);
            }
            catch
            {
                // skip unknown lines
            }
        }
        if (servers.Count == 0) throw new InvalidOperationException("В подписке не нашлось понятных ссылок");
        return servers;
    }

    private static string DecodeBody(string text)
    {
        if (text.Contains("://") && (text.Contains("ss://") || text.Contains("vless://"))) return text;
        return TryDecodeB64(text) ?? TryDecodeB64(string.Concat(text.Where(c => !char.IsWhiteSpace(c)))) ?? text;
    }

    private static string? TryDecodeB64(string raw)
    {
        try
        {
            var rem = raw.Length % 4;
            var padded = rem == 0 ? raw : raw + new string('=', 4 - rem);
            var s = Encoding.UTF8.GetString(Convert.FromBase64String(padded));
            return s.Contains("://") ? s : null;
        }
        catch
        {
            return null;
        }
    }
}
