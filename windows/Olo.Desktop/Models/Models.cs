namespace Olo.Desktop.Models;

public enum ProxyProto
{
    shadowsocks, vmess, vless, trojan, hysteria2, tuic, socks, http, wireguard
}

public sealed class VpnServer
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = "";
    public ProxyProto Proto { get; set; } = ProxyProto.vless;
    public string Host { get; set; } = "";
    public int Port { get; set; } = 443;
    public string Password { get; set; } = "";
    public string Uuid { get; set; } = "";
    public string Method { get; set; } = "";
    public string Sni { get; set; } = "";
    public string Transport { get; set; } = "tcp";
    public string Security { get; set; } = "";
    public string Flow { get; set; } = "";
    public string Fingerprint { get; set; } = "";
    public string PublicKey { get; set; } = "";
    public string ShortId { get; set; } = "";
    public string WsPath { get; set; } = "/";
    public string Hy2Obfs { get; set; } = "";
    public string Hy2ObfsPassword { get; set; } = "";
    public string RawLink { get; set; } = "";

    public string Endpoint => $"{Host}:{Port}";
    public string DisplayName => string.IsNullOrWhiteSpace(Name) ? Endpoint : Name;
}

public enum RouteMode { smart, global }
public enum LocalPolicy { bypass, throughVPN }
public enum LocalRegion { auto, ru, cn, other }

public sealed class Protection
{
    public bool KillSwitch { get; set; } = true;
    public bool DnsThroughVpn { get; set; } = true;
    public bool BlockIpv6 { get; set; } = true;
    public bool AllowLan { get; set; } = true;
}
