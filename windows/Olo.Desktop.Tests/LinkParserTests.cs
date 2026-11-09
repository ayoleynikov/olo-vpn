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
}
