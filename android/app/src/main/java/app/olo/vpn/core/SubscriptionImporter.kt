package app.olo.vpn.core

import android.util.Base64
import app.olo.vpn.model.ProxyProto
import app.olo.vpn.model.VpnServer
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

object SubscriptionImporter {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    fun isSubscriptionUrl(raw: String): Boolean {
        val t = raw.trim()
        val lower = t.lowercase()
        if (!(lower.startsWith("http://") || lower.startsWith("https://"))) return false
        val at = t.indexOf('@')
        if (at > 0 && t.substring(0, at).contains("://")) return false
        return true
    }

    fun remark(raw: String): String? {
        val i = raw.indexOf('#')
        if (i < 0) return null
        return android.net.Uri.decode(raw.substring(i + 1))
    }

    fun fetchServers(rawUrl: String, namePrefix: String? = null): List<VpnServer> {
        val withoutFragment = rawUrl.trim().substringBefore('#')
        val req = Request.Builder()
            .url(withoutFragment)
            .header("User-Agent", "Shadowrocket/2101 CFNetwork Darwin")
            .build()
        client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) error("HTTP ${resp.code}")
            val text = resp.body?.string()?.trim().orEmpty()
            if (text.isEmpty()) error("Подписка пустая")
            val decoded = decodeBody(text)
            val servers = mutableListOf<VpnServer>()
            parseJsonProfile(decoded)?.let { servers += it }
            if (servers.isEmpty()) {
                servers += LinkParser.parseMany(decoded)
            }
            if (!namePrefix.isNullOrBlank()) {
                servers.forEach { server ->
                    if (server.name.isBlank() || server.name == server.proto.title) {
                        server.name = "$namePrefix · ${server.endpoint}"
                    }
                }
            }
            if (servers.isEmpty()) error("В подписке не нашлось понятных ссылок")
            return servers
        }
    }

    private fun parseJsonProfile(text: String): List<VpnServer>? {
        val stripped = text.trim()
        if (!(stripped.startsWith("{") || stripped.startsWith("["))) return null
        return try {
            val nodes = mutableListOf<JSONObject>()
            if (stripped.startsWith("[")) {
                val arr = JSONArray(stripped)
                for (i in 0 until arr.length()) nodes += arr.getJSONObject(i)
            } else {
                val root = JSONObject(stripped)
                when {
                    root.has("proxies") -> {
                        val arr = root.getJSONArray("proxies")
                        for (i in 0 until arr.length()) nodes += arr.getJSONObject(i)
                    }
                    root.has("outbounds") -> {
                        val arr = root.getJSONArray("outbounds")
                        val skip = setOf("direct", "block", "dns", "selector", "urltest", "relay")
                        for (i in 0 until arr.length()) {
                            val o = arr.getJSONObject(i)
                            val type = o.optString("type").lowercase()
                            if (type !in skip) nodes += o
                        }
                    }
                }
            }
            val out = nodes.mapNotNull { mapNode(it) }
            out.ifEmpty { null }
        } catch (_: Exception) {
            null
        }
    }

    private fun mapNode(node: JSONObject): VpnServer? {
        val type = node.optString("type").lowercase()
        val name = node.optString("name").ifBlank { node.optString("tag").ifBlank { type } }
        val host = node.optString("server")
        val port = when {
            node.has("server_port") -> node.optInt("server_port")
            else -> node.optInt("port")
        }
        if (host.isBlank() || port <= 0) return null
        return when (type) {
            "ss", "shadowsocks" -> VpnServer(
                name = name, proto = ProxyProto.shadowsocks, host = host, port = port,
                password = node.optString("password"),
                method = node.optString("cipher").ifBlank { node.optString("method", "aes-256-gcm") }
            )
            "vmess" -> VpnServer(
                name = name, proto = ProxyProto.vmess, host = host, port = port,
                uuid = node.optString("uuid"), method = node.optString("cipher", "auto"),
                sni = node.optString("servername").ifBlank { host }
            )
            "vless" -> VpnServer(
                name = name, proto = ProxyProto.vless, host = host, port = port,
                uuid = node.optString("uuid"), sni = host
            )
            "trojan" -> VpnServer(
                name = name, proto = ProxyProto.trojan, host = host, port = port,
                password = node.optString("password"), sni = node.optString("sni").ifBlank { host }
            )
            "hysteria2", "hy2" -> VpnServer(
                name = name, proto = ProxyProto.hysteria2, host = host, port = port,
                password = node.optString("password").ifBlank { node.optString("auth") },
                sni = node.optString("sni").ifBlank { host }
            )
            "tuic" -> VpnServer(
                name = name, proto = ProxyProto.tuic, host = host, port = port,
                uuid = node.optString("uuid"), password = node.optString("password"),
                sni = node.optString("sni").ifBlank { host }
            )
            "socks", "socks5" -> VpnServer(
                name = name, proto = ProxyProto.socks, host = host, port = port,
                uuid = node.optString("username"), password = node.optString("password")
            )
            "http" -> VpnServer(
                name = name, proto = ProxyProto.http, host = host, port = port,
                uuid = node.optString("username"), password = node.optString("password")
            )
            "wireguard" -> VpnServer(
                name = name, proto = ProxyProto.wireguard, host = host, port = port,
                password = node.optString("private-key").ifBlank { node.optString("private_key") },
                uuid = node.optString("public-key").ifBlank { node.optString("peer_public_key") }
            )
            else -> null
        }
    }

    private fun decodeBody(text: String): String {
        val lower = text.lowercase()
        if (text.trimStart().startsWith("{") || text.trimStart().startsWith("[")) return text
        if (text.contains("://") && (
                lower.contains("ss://") || lower.contains("vless://") || lower.contains("vmess://") ||
                    lower.contains("trojan://") || lower.contains("hy2://") || lower.contains("tuic://")
                )
        ) return text
        decodeB64(text)?.let { return it }
        decodeB64(text.replace("\\s".toRegex(), ""))?.let { return it }
        return text
    }

    private fun decodeB64(raw: String): String? {
        return try {
            val padded = raw + "=".repeat((4 - raw.length % 4) % 4)
            val data = Base64.decode(padded, Base64.DEFAULT)
            val s = String(data)
            if (s.contains("://") || s.trimStart().startsWith("{")) s else null
        } catch (_: Exception) {
            null
        }
    }
}
