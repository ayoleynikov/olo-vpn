package app.olo.vpn.model

import java.util.UUID

enum class ProxyProto(val title: String) {
    shadowsocks("Shadowsocks"),
    vmess("VMess"),
    vless("VLESS"),
    trojan("Trojan"),
    hysteria2("Hysteria2"),
    tuic("TUIC"),
    socks("SOCKS5"),
    http("HTTP"),
    wireguard("WireGuard");

    companion object {
        fun from(raw: String) = entries.find { it.name.equals(raw, true) } ?: vless
    }
}

data class VpnServer(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var proto: ProxyProto,
    var host: String,
    var port: Int,
    var password: String = "",
    var uuid: String = "",
    var method: String = "",
    var sni: String = "",
    var transport: String = "tcp",
    var security: String = "",
    var flow: String = "",
    var fingerprint: String = "",
    var publicKey: String = "",
    var shortId: String = "",
    var wsPath: String = "/",
    var hy2Obfs: String = "",
    var hy2ObfsPassword: String = "",
    var rawLink: String = ""
) {
    val endpoint: String get() = "$host:$port"
    val displayName: String get() = name.ifBlank { endpoint }
}

enum class RouteMode { smart, global }
enum class LocalPolicy { bypass, throughVPN }
enum class LocalRegion { auto, ru, cn, other }

data class Protection(
    var killSwitch: Boolean = true,
    var dnsThroughVpn: Boolean = true,
    var blockIpv6: Boolean = true,
    var allowLan: Boolean = true
)
