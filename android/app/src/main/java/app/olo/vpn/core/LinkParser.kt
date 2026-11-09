package app.olo.vpn.core

import android.net.Uri
import android.util.Base64
import app.olo.vpn.model.ProxyProto
import app.olo.vpn.model.VpnServer
import org.json.JSONObject

object LinkParser {
    fun parse(raw: String): VpnServer {
        val trimmed = raw.trim()
        require(trimmed.isNotEmpty()) { "Пустая ссылка" }
        val lower = trimmed.lowercase()
        return when {
            lower.startsWith("ss://") -> parseSs(trimmed)
            lower.startsWith("trojan://") -> parseTrojan(trimmed)
            lower.startsWith("vless://") -> parseVless(trimmed)
            lower.startsWith("vmess://") -> parseVmess(trimmed)
            lower.startsWith("hysteria2://") || lower.startsWith("hy2://") -> parseHy2(trimmed)
            lower.startsWith("socks://") || lower.startsWith("socks5://") -> parseSocks(trimmed)
            else -> error("Этот формат пока не поддерживается")
        }
    }

    private fun parseVless(link: String): VpnServer {
        val uri = Uri.parse(link)
        val host = uri.host ?: error("bad vless")
        val port = if (uri.port != -1) uri.port else 443
        val uuid = uri.userInfo ?: error("bad uuid")
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "VLESS"),
            proto = ProxyProto.vless,
            host = host,
            port = port,
            uuid = uuid,
            sni = uri.getQueryParameter("sni") ?: host,
            transport = uri.getQueryParameter("type") ?: "tcp",
            security = uri.getQueryParameter("security") ?: "",
            flow = uri.getQueryParameter("flow") ?: "",
            fingerprint = uri.getQueryParameter("fp") ?: "",
            publicKey = uri.getQueryParameter("pbk") ?: "",
            shortId = uri.getQueryParameter("sid") ?: "",
            wsPath = uri.getQueryParameter("path") ?: "/",
            rawLink = link
        )
    }

    private fun parseTrojan(link: String): VpnServer {
        val uri = Uri.parse(link)
        val host = uri.host ?: error("bad trojan")
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "Trojan"),
            proto = ProxyProto.trojan,
            host = host,
            port = if (uri.port != -1) uri.port else 443,
            password = Uri.decode(uri.userInfo ?: ""),
            sni = uri.getQueryParameter("sni") ?: host,
            rawLink = link
        )
    }

    private fun parseHy2(link: String): VpnServer {
        val normalized = link.replace("hy2://", "hysteria2://")
        val uri = Uri.parse(normalized)
        val host = uri.host ?: error("bad hy2")
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "Hysteria2"),
            proto = ProxyProto.hysteria2,
            host = host,
            port = if (uri.port != -1) uri.port else 443,
            password = Uri.decode(uri.userInfo ?: ""),
            sni = uri.getQueryParameter("sni") ?: host,
            hy2Obfs = uri.getQueryParameter("obfs") ?: "",
            hy2ObfsPassword = uri.getQueryParameter("obfs-password")
                ?: uri.getQueryParameter("obfs_password")
                ?: "",
            rawLink = link
        )
    }

    private fun parseSs(link: String): VpnServer {
        val without = link.removePrefix("ss://")
        val parts = without.split("#", limit = 2)
        val body = parts[0]
        val name = if (parts.size > 1) Uri.decode(parts[1]) else "Shadowsocks"
        if (body.contains("@")) {
            val userHost = body.split("@", limit = 2)
            val methodPass = userHost[0].split(":", limit = 2)
            val hp = userHost[1].split(":", limit = 2)
            return VpnServer(
                name = name,
                proto = ProxyProto.shadowsocks,
                host = hp[0],
                port = hp.getOrNull(1)?.toIntOrNull() ?: 8388,
                method = methodPass[0],
                password = Uri.decode(methodPass.getOrNull(1) ?: ""),
                rawLink = link
            )
        }
        val padded = padB64(body.substringBefore("/"))
        val decoded = String(Base64.decode(padded, Base64.DEFAULT))
        return parseSs("ss://$decoded#$name")
    }

    private fun parseVmess(link: String): VpnServer {
        val body = padB64(link.removePrefix("vmess://"))
        val json = JSONObject(String(Base64.decode(body, Base64.DEFAULT)))
        val port = when (val p = json.get("port")) {
            is Int -> p
            else -> p.toString().toInt()
        }
        return VpnServer(
            name = json.optString("ps").ifBlank { "VMess" },
            proto = ProxyProto.vmess,
            host = json.getString("add"),
            port = port,
            uuid = json.optString("id"),
            method = json.optString("scy", "auto"),
            sni = json.optString("sni").ifBlank { json.getString("add") },
            transport = json.optString("net", "tcp"),
            rawLink = link
        )
    }

    private fun parseSocks(link: String): VpnServer {
        val uri = Uri.parse(link.replace("socks5://", "socks://"))
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "SOCKS5"),
            proto = ProxyProto.socks,
            host = uri.host ?: error("bad socks"),
            port = if (uri.port != -1) uri.port else 1080,
            uuid = uri.userInfo?.substringBefore(":") ?: "",
            password = uri.userInfo?.substringAfter(":", "") ?: "",
            rawLink = link
        )
    }

    private fun padB64(value: String): String {
        val cleaned = value.replace('-', '+').replace('_', '/')
        val rem = cleaned.length % 4
        return if (rem == 0) cleaned else cleaned + "=".repeat(4 - rem)
    }
}
