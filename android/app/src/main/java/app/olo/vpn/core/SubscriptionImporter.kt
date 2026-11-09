package app.olo.vpn.core

import android.util.Base64
import app.olo.vpn.model.VpnServer
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object SubscriptionImporter {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    fun isSubscriptionUrl(raw: String): Boolean {
        val t = raw.trim().lowercase()
        return t.startsWith("http://") || t.startsWith("https://")
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
            val lines = decoded.lines().map { it.trim() }.filter { it.isNotEmpty() && !it.startsWith("#") }
            val servers = mutableListOf<VpnServer>()
            for (line in lines) {
                runCatching { LinkParser.parse(line) }.getOrNull()?.let { server ->
                    if (!namePrefix.isNullOrBlank() && (server.name.isBlank() || server.name == server.proto.title)) {
                        server.name = "$namePrefix · ${server.endpoint}"
                    }
                    servers += server
                }
            }
            if (servers.isEmpty()) error("В подписке не нашлось понятных ссылок")
            return servers
        }
    }

    private fun decodeBody(text: String): String {
        if (text.contains("://") && (text.contains("ss://") || text.contains("vless://"))) return text
        decodeB64(text)?.let { return it }
        decodeB64(text.replace("\\s".toRegex(), ""))?.let { return it }
        return text
    }

    private fun decodeB64(raw: String): String? {
        return try {
            val padded = raw + "=".repeat((4 - raw.length % 4) % 4)
            val data = Base64.decode(padded, Base64.DEFAULT)
            val s = String(data)
            if (s.contains("://")) s else null
        } catch (_: Exception) {
            null
        }
    }
}
