using Olo.Desktop.Models;
using Olo.Desktop.Services;
using Xunit;

namespace Olo.Desktop.Tests;

public class LinkParserTests
{
    [Fact]
    public void ParseVlessReality()
    {
        var link =
            "vless://11111111-2222-3333-4444-555555555555@example.com:443" +
            "?encryption=none&flow=xtls-rprx-vision&security=reality" +
            "&sni=www.cloudflare.com&fp=chrome&pbk=PUBLICKEY&sid=abcd1234&type=tcp#RealityNode";
        var s = LinkParser.Parse(link);
        Assert.Equal(ProxyProto.vless, s.Proto);
        Assert.Equal("example.com", s.Host);
        Assert.Equal(443, s.Port);
        Assert.Equal("PUBLICKEY", s.PublicKey);
        Assert.Equal("abcd1234", s.ShortId);
        Assert.Equal("chrome", s.Fingerprint);
        Assert.Equal("xtls-rprx-vision", s.Flow);
        Assert.Equal("RealityNode", s.Name);
    }

    [Fact]
    public void ParseHy2()
    {
        var s = LinkParser.Parse("hy2://pass@hy2.example:443?sni=hy2.example&obfs=salamander&obfs-password=obfs#H");
        Assert.Equal(ProxyProto.hysteria2, s.Proto);
        Assert.Equal("salamander", s.Hy2Obfs);
        Assert.Equal("obfs", s.Hy2ObfsPassword);
    }

    [Fact]
    public void ParseTrojan()
    {
        var s = LinkParser.Parse("trojan://secret@host.example:8443?sni=host.example#T1");
        Assert.Equal(ProxyProto.trojan, s.Proto);
        Assert.Equal("secret", s.Password);
    }

    [Fact]
    public void RejectEmpty()
    {
        Assert.Throws<InvalidOperationException>(() => LinkParser.Parse("  "));
    }

    [Fact]
    public void ParseTuicSocksHttpWgAndMany()
    {
        var tuic = LinkParser.Parse("tuic://11111111-2222-3333-4444-555555555555:pass@tuic.example:443?sni=tuic.example#T");
        Assert.Equal(ProxyProto.tuic, tuic.Proto);
        Assert.Equal("pass", tuic.Password);

        var socks = LinkParser.Parse("socks5://user:secret@socks.example:1080#S");
        Assert.Equal(ProxyProto.socks, socks.Proto);
        Assert.Equal("user", socks.Uuid);

        var http = LinkParser.Parse("http://u:p@proxy.example:8080#H");
        Assert.Equal(ProxyProto.http, http.Proto);

        var wg = LinkParser.Parse("wg://PRIVATEKEY@wg.example:51820?publickey=PUB&address=10.0.0.2/32#W");
        Assert.Equal(ProxyProto.wireguard, wg.Proto);
        Assert.Equal("PRIVATEKEY", wg.Password);

        var many = LinkParser.ParseMany(
            "trojan://secret@host.example:8443?sni=host.example#T1\n" +
            "hy2://pass@hy2.example:443?sni=hy2.example#H");
        Assert.Equal(2, many.Count);
    }

    [Fact]
    public void HttpProxyIsNotConfusedWithBareHost()
    {
        Assert.False(SubscriptionImporter.IsSubscriptionUrl("http://u:p@proxy.example:8080"));
        Assert.True(SubscriptionImporter.IsSubscriptionUrl("https://example.com/sub#MySub"));
    }
}
