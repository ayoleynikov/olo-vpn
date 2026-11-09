package app.olo.vpn.core

import app.olo.vpn.model.LocalPolicy
import app.olo.vpn.model.LocalRegion
import app.olo.vpn.model.Protection
import app.olo.vpn.model.ProxyProto
import app.olo.vpn.model.RouteMode
import app.olo.vpn.model.VpnServer
import org.json.JSONArray
import org.json.JSONObject

object SingBoxConfigBuilder {
    fun build(
        server: VpnServer,
        routeMode: RouteMode,
        localPolicy: LocalPolicy,
        localRegion: LocalRegion,
        protection: Protection
    ): String {
        val outbound = JSONObject().put("tag", "proxy").put("type", server.proto.name.let {
            if (it == "shadowsocks") "shadowsocks" else it
        })
        when (server.proto) {
            ProxyProto.shadowsocks -> outbound
                .put("server", server.host).put("server_port", server.port)
                .put("method", server.method.ifBlank { "aes-256-gcm" })
                .put("password", server.password)
            ProxyProto.vless -> {
                outbound.put("server", server.host).put("server_port", server.port)
                    .put("uuid", server.uuid).put("packet_encoding", "xudp")
                if (server.flow.isNotBlank()) outbound.put("flow", server.flow)
                if (server.transport.isNotBlank() && server.transport != "tcp") {
                    outbound.put("transport", transport(server))
                }
                outbound.put("tls", tls(server))
            }
            ProxyProto.trojan -> outbound.put("server", server.host).put("server_port", server.port)
                .put("password", server.password).put("tls", tls(server))
            ProxyProto.hysteria2 -> {
                outbound.put("server", server.host).put("server_port", server.port)
                    .put("password", server.password.ifBlank { server.uuid })
                if (server.hy2Obfs.isNotBlank()) {
                    outbound.put(
                        "obfs",
                        JSONObject().put("type", server.hy2Obfs).put("password", server.hy2ObfsPassword)
                    )
                }
                outbound.put("tls", tls(server))
            }
            ProxyProto.vmess -> {
                outbound.put("server", server.host).put("server_port", server.port)
                    .put("uuid", server.uuid).put("security", server.method.ifBlank { "auto" })
                if (server.transport.isNotBlank() && server.transport != "tcp") {
                    outbound.put("transport", transport(server))
                }
                outbound.put("tls", tls(server))
            }
            else -> outbound.put("server", server.host).put("server_port", server.port)
                .put("password", server.password)
        }

        val rules = JSONArray()
            .put(JSONObject().put("action", "sniff"))
            .put(JSONObject().put("protocol", JSONArray().put("dns")).put("action", "hijack-dns"))
        if (protection.allowLan) {
            rules.put(JSONObject().put("ip_is_private", true).put("outbound", "direct"))
        }
        if (routeMode == RouteMode.smart && localPolicy == LocalPolicy.bypass) {
            localRules(localRegion).forEach { rules.put(it) }
        }

        // Legacy DNS schema compatible with sing-box 1.11 release binaries.
        val dnsServers = JSONArray()
        if (protection.dnsThroughVpn) {
            dnsServers.put(
                JSONObject().put("tag", "remote").put("address", "tls://1.1.1.1").put("detour", "proxy")
            )
            dnsServers.put(
                JSONObject().put("tag", "local").put("address", "8.8.8.8").put("detour", "direct")
            )
        } else {
            dnsServers.put(JSONObject().put("tag", "local").put("address", "8.8.8.8"))
        }

        val address = JSONArray().put("172.19.0.1/30")
        if (!protection.blockIpv6) address.put("fdfe:dcba:9876::1/126")

        val tun = JSONObject()
            .put("type", "tun").put("tag", "tun-in").put("mtu", 9000)
            .put("address", address).put("auto_route", true)
            .put("strict_route", protection.killSwitch).put("stack", "system")

        val config = JSONObject()
            .put("log", JSONObject().put("level", "info").put("timestamp", true))
            .put(
                "dns",
                JSONObject().put("servers", dnsServers)
                    .put("strategy", if (protection.blockIpv6) "ipv4_only" else "prefer_ipv4")
                    .put("final", if (protection.dnsThroughVpn) "remote" else "local")
            )
            .put("inbounds", JSONArray().put(tun))
            .put(
                "outbounds",
                JSONArray().put(outbound)
                    .put(JSONObject().put("type", "direct").put("tag", "direct"))
                    .put(JSONObject().put("type", "block").put("tag", "block"))
            )
            .put(
                "route",
                JSONObject().put("rules", rules).put("final", "proxy").put("auto_detect_interface", true)
            )
            .put(
                "experimental",
                JSONObject().put(
                    "clash_api",
                    JSONObject().put("external_controller", "127.0.0.1:9090").put("secret", "olo-local")
                )
            )
        return config.toString(2)
    }

    private fun tls(server: VpnServer): JSONObject {
        val tls = JSONObject().put("enabled", true)
            .put("server_name", server.sni.ifBlank { server.host })
        if (server.fingerprint.isNotBlank()) {
            tls.put("utls", JSONObject().put("enabled", true).put("fingerprint", server.fingerprint))
        }
        if (server.security.equals("reality", true) || server.publicKey.isNotBlank()) {
            val reality = JSONObject().put("enabled", true).put("public_key", server.publicKey)
            if (server.shortId.isNotBlank()) reality.put("short_id", server.shortId)
            tls.put("reality", reality)
        }
        return tls
    }

    private fun transport(server: VpnServer): JSONObject = when (server.transport.lowercase()) {
        "ws", "websocket" -> JSONObject().put("type", "ws").put("path", server.wsPath.ifBlank { "/" })
        "grpc" -> JSONObject().put("type", "grpc").put("service_name", "GunService")
        else -> JSONObject().put("type", server.transport)
    }

    private fun localRules(region: LocalRegion): List<JSONObject> = when (region) {
        LocalRegion.cn -> listOf(
            JSONObject().put("domain_suffix", JSONArray().put(".cn").put(".com.cn")).put("outbound", "direct")
        )
        else -> listOf(
            JSONObject().put("domain_suffix", JSONArray().put(".ru").put(".su")).put("outbound", "direct")
        )
    }
}
