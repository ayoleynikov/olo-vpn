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
            lower.startsWith("hysteria2://") || lower.startsWith("hy2://") || lower.startsWith("hysteria://") ->
                parseHy2(trimmed)
            lower.startsWith("tuic://") -> parseTuic(trimmed)
            lower.startsWith("socks://") || lower.startsWith("socks5://") -> parseSocks(trimmed)
            lower.startsWith("wireguard://") || lower.startsWith("wg://") -> parseWireGuard(trimmed)
            (lower.startsWith("http://") || lower.startsWith("https://")) &&
                trimmed.substringBefore('@').contains("://") && trimmed.contains('@') ->
                parseHttp(trimmed)
            else -> error("Этот формат пока не поддерживается")
        }
    }

    fun parseMany(raw: String): List<VpnServer> {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return emptyList()
        var chunks = trimmed.lines()
            .flatMap { it.split(',', ';') }
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") }
        if (chunks.size == 1) {
            val split = splitProxyLinks(chunks[0])
            if (split.size > 1) chunks = split
        }
        val seen = linkedSetOf<String>()
        val out = mutableListOf<VpnServer>()
        for (chunk in chunks) {
            val server = runCatching { parse(chunk) }.getOrNull() ?: continue
            val key = "${server.proto}|${server.host}|${server.port}|${server.uuid}|${server.password}"
            if (seen.add(key)) out += server
        }
        return out
    }

    private fun parseVless(link: String): VpnServer {
        val uri = Uri.parse(link)
        val host = uri.host ?: error("bad vless")
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "VLESS"),
            proto = ProxyProto.vless,
            host = host,
            port = if (uri.port != -1) uri.port else 443,
            uuid = uri.userInfo ?: error("bad uuid"),
            sni = uri.getQueryParameter("sni") ?: host,
            transport = uri.getQueryParameter("type") ?: "tcp",
            security = uri.getQueryParameter("security") ?: "",
            flow = uri.getQueryParameter("flow") ?: "",
            fingerprint = uri.getQueryParameter("fp") ?: "",
            publicKey = uri.getQueryParameter("pbk") ?: "",
            shortId = uri.getQueryParameter("sid") ?: "",
            wsPath = uri.getQueryParameter("path") ?: "/",
            wsHost = uri.getQueryParameter("host") ?: "",
            grpcServiceName = uri.getQueryParameter("serviceName") ?: "GunService",
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
            transport = uri.getQueryParameter("type") ?: "tcp",
            security = uri.getQueryParameter("security") ?: "",
            fingerprint = uri.getQueryParameter("fp") ?: "",
            publicKey = uri.getQueryParameter("pbk") ?: "",
            shortId = uri.getQueryParameter("sid") ?: "",
            wsPath = uri.getQueryParameter("path") ?: "/",
            wsHost = uri.getQueryParameter("host") ?: "",
            rawLink = link
        )
    }

    private fun parseHy2(link: String): VpnServer {
        val normalized = link
            .replace("hy2://", "hysteria2://", ignoreCase = true)
            .replace("hysteria://", "hysteria2://", ignoreCase = true)
        val uri = Uri.parse(normalized)
        val host = uri.host ?: error("bad hy2")
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "Hysteria2"),
            proto = ProxyProto.hysteria2,
            host = host,
            port = if (uri.port != -1) uri.port else 443,
            password = Uri.decode(uri.userInfo ?: uri.getQueryParameter("auth") ?: ""),
            sni = uri.getQueryParameter("sni") ?: host,
            hy2Obfs = uri.getQueryParameter("obfs") ?: "",
            hy2ObfsPassword = uri.getQueryParameter("obfs-password")
                ?: uri.getQueryParameter("obfs_password")
                ?: "",
            rawLink = link
        )
    }

    private fun parseTuic(link: String): VpnServer {
        val uri = Uri.parse(link)
        val host = uri.host ?: error("bad tuic")
        val userInfo = Uri.decode(uri.userInfo ?: "")
        val uuid: String
        val password: String
        if (userInfo.contains(":")) {
            uuid = userInfo.substringBefore(':')
            password = userInfo.substringAfter(':')
        } else {
            uuid = userInfo
            password = ""
        }
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "TUIC"),
            proto = ProxyProto.tuic,
            host = host,
            port = if (uri.port != -1) uri.port else 443,
            uuid = uuid,
            password = password,
            sni = uri.getQueryParameter("sni") ?: host,
            security = "tls",
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
            var method = ""
            var password = ""
            val user = userHost[0]
            if (user.contains(":")) {
                method = user.substringBefore(':')
                password = Uri.decode(user.substringAfter(':'))
            } else {
                val decoded = String(Base64.decode(padB64(user), Base64.DEFAULT))
                method = decoded.substringBefore(':')
                password = decoded.substringAfter(':', "")
            }
            val hostPart = userHost[1].substringBefore('/').substringBefore('?')
            val hp = hostPart.split(":", limit = 2)
            return VpnServer(
                name = name,
                proto = ProxyProto.shadowsocks,
                host = hp[0],
                port = hp.getOrNull(1)?.toIntOrNull() ?: 8388,
                method = method,
                password = password,
                rawLink = link
            )
        }
        val padded = padB64(body.substringBefore("/"))
        val decoded = String(Base64.decode(padded, Base64.DEFAULT))
        return parseSs("ss://$decoded#${Uri.encode(name)}")
    }

    private fun parseVmess(link: String): VpnServer {
        val body = padB64(link.removePrefix("vmess://"))
        val json = JSONObject(String(Base64.decode(body, Base64.DEFAULT)))
        val port = when (val p = json.get("port")) {
            is Int -> p
            else -> p.toString().toInt()
        }
        val tls = json.optString("tls")
        return VpnServer(
            name = json.optString("ps").ifBlank { "VMess" },
            proto = ProxyProto.vmess,
            host = json.getString("add"),
            port = port,
            uuid = json.optString("id"),
            method = json.optString("scy", "auto"),
            sni = json.optString("sni").ifBlank { json.getString("add") },
            transport = json.optString("net", "tcp"),
            security = if (tls.isNotBlank()) tls else "",
            fingerprint = json.optString("fp"),
            publicKey = json.optString("pbk"),
            shortId = json.optString("sid"),
            wsPath = json.optString("path", "/"),
            wsHost = json.optString("host"),
            rawLink = link
        )
    }

    private fun parseSocks(link: String): VpnServer {
        val uri = Uri.parse(link.replace("socks5://", "socks://", ignoreCase = true))
        val userInfo = uri.userInfo ?: ""
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "SOCKS5"),
            proto = ProxyProto.socks,
            host = uri.host ?: error("bad socks"),
            port = if (uri.port != -1) uri.port else 1080,
            uuid = userInfo.substringBefore(":"),
            password = if (userInfo.contains(":")) userInfo.substringAfter(":") else "",
            rawLink = link
        )
    }

    private fun parseHttp(link: String): VpnServer {
        val uri = Uri.parse(link)
        val userInfo = uri.userInfo ?: ""
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "HTTP"),
            proto = ProxyProto.http,
            host = uri.host ?: error("bad http"),
            port = if (uri.port != -1) uri.port else if (link.lowercase().startsWith("https://")) 443 else 80,
            uuid = Uri.decode(userInfo.substringBefore(":")),
            password = if (userInfo.contains(":")) Uri.decode(userInfo.substringAfter(":")) else "",
            rawLink = link
        )
    }

    private fun parseWireGuard(link: String): VpnServer {
        val normalized = link.replace("wg://", "wireguard://", ignoreCase = true)
        val uri = Uri.parse(normalized)
        return VpnServer(
            name = Uri.decode(uri.fragment ?: "WireGuard"),
            proto = ProxyProto.wireguard,
            host = uri.host ?: error("bad wg"),
            port = if (uri.port != -1) uri.port else 51820,
            password = Uri.decode(uri.userInfo ?: error("missing private key")),
            uuid = uri.getQueryParameter("publickey")
                ?: uri.getQueryParameter("publicKey")
                ?: uri.getQueryParameter("peer")
                ?: "",
            method = uri.getQueryParameter("address") ?: uri.getQueryParameter("ip") ?: "10.0.0.2/32",
            rawLink = link
        )
    }

    private fun splitProxyLinks(blob: String): List<String> {
        val schemes = listOf(
            "ss://", "vmess://", "vless://", "trojan://", "hysteria2://", "hy2://",
            "hysteria://", "tuic://", "socks://", "socks5://", "wireguard://", "wg://"
        )
        val lower = blob.lowercase()
        val indices = mutableListOf<Int>()
        for (scheme in schemes) {
            var idx = lower.indexOf(scheme)
            while (idx >= 0) {
                indices += idx
                idx = lower.indexOf(scheme, idx + scheme.length)
            }
        }
        val sorted = indices.distinct().sorted()
        if (sorted.size <= 1) return listOf(blob)
        return sorted.mapIndexed { i, start ->
            val end = sorted.getOrNull(i + 1) ?: blob.length
            blob.substring(start, end).trim()
        }.filter { it.isNotEmpty() }
    }

    private fun padB64(value: String): String {
        val cleaned = value.replace('-', '+').replace('_', '/')
        val rem = cleaned.length % 4
        return if (rem == 0) cleaned else cleaned + "=".repeat(4 - rem)
    }
}
