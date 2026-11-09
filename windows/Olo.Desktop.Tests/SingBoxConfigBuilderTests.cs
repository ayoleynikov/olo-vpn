using System.Text.Json.Nodes;
using Olo.Desktop.Models;
using Olo.Desktop.Services;
using Xunit;

namespace Olo.Desktop.Tests;

public class SingBoxConfigBuilderTests
{
    [Fact]
    public void BuildsVlessRealityAndWritesFixture()
    {
        var server = new VpnServer
        {
            Name = "R",
            Proto = ProxyProto.vless,
            Host = "example.com",
            Port = 443,
            Uuid = "11111111-2222-3333-4444-555555555555",
            Sni = "www.cloudflare.com",
            Security = "reality",
            // 32-byte reality public key (standard base64url, no padding)
            PublicKey = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
            ShortId = "abcd",
            Fingerprint = "chrome",
            Flow = "xtls-rprx-vision"
        };
        var json = SingBoxConfigBuilder.Build(
            server, RouteMode.smart, LocalPolicy.bypass, LocalRegion.ru, new Protection(), useTun: false);
        var root = JsonNode.Parse(json)!;
        Assert.Equal("mixed", root["inbounds"]![0]!["type"]!.GetValue<string>());
        Assert.Equal("vless", root["outbounds"]![0]!["type"]!.GetValue<string>());
        Assert.True(root["outbounds"]![0]!["tls"]!["reality"]!["enabled"]!.GetValue<bool>());
        Assert.Equal("tls://1.1.1.1", root["dns"]!["servers"]![0]!["address"]!.GetValue<string>());

        var dir = Path.Combine(AppContext.BaseDirectory, "fixtures");
        Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir, "windows-vless-reality.json"), json);

        // Optional: validate with local Vendor/bin/sing-box if present
        var repoSingBox = FindRepoSingBox();
        if (repoSingBox != null)
        {
            var psi = new System.Diagnostics.ProcessStartInfo
            {
                FileName = repoSingBox,
                Arguments = $"check -c \"{Path.Combine(dir, "windows-vless-reality.json")}\"",
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false
            };
            using var p = System.Diagnostics.Process.Start(psi)!;
            var err = p.StandardError.ReadToEnd();
            p.WaitForExit();
            Assert.True(p.ExitCode == 0, $"sing-box check failed: {err}");
        }
    }

    private static string? FindRepoSingBox()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            var candidate = Path.Combine(dir.FullName, "Vendor", "bin", "sing-box");
            if (File.Exists(candidate)) return candidate;
            dir = dir.Parent;
        }
        return null;
    }

    [Fact]
    public void BuildsProxyOnlyDirectSmokeConfig()
    {
        // Engine smoke: mixed inbound → direct (no remote node required)
        var server = new VpnServer
        {
            Name = "unused",
            Proto = ProxyProto.socks,
            Host = "127.0.0.1",
            Port = 1,
            Password = ""
        };
        var json = SingBoxConfigBuilder.Build(
            server, RouteMode.global, LocalPolicy.throughVPN, LocalRegion.auto, new Protection(), useTun: false);
        Assert.Contains("mixed-in", json);
        Assert.Contains("7890", json);
    }
}
