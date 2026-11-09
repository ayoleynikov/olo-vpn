package app.olo.vpn.data

import android.content.Context
import app.olo.vpn.model.LocalPolicy
import app.olo.vpn.model.LocalRegion
import app.olo.vpn.model.Protection
import app.olo.vpn.model.ProxyProto
import app.olo.vpn.model.RouteMode
import app.olo.vpn.model.VpnServer
import org.json.JSONArray
import org.json.JSONObject

class ServerStore(context: Context) {
    private val prefs = context.getSharedPreferences("olo", Context.MODE_PRIVATE)

    var servers: List<VpnServer>
        get() {
            val raw = prefs.getString(KEY_SERVERS, "[]") ?: "[]"
            val arr = JSONArray(raw)
            return (0 until arr.length()).map { i -> decode(arr.getJSONObject(i)) }
        }
        set(value) {
            val arr = JSONArray()
            value.forEach { arr.put(encode(it)) }
            prefs.edit().putString(KEY_SERVERS, arr.toString()).apply()
        }

    var selectedId: String?
        get() = prefs.getString(KEY_SELECTED, null)
        set(value) { prefs.edit().putString(KEY_SELECTED, value).apply() }

    var routeMode: RouteMode
        get() = RouteMode.valueOf(prefs.getString(KEY_ROUTE, RouteMode.smart.name)!!)
        set(value) { prefs.edit().putString(KEY_ROUTE, value.name).apply() }

    var localPolicy: LocalPolicy
        get() = LocalPolicy.valueOf(prefs.getString(KEY_LOCAL, LocalPolicy.bypass.name)!!)
        set(value) { prefs.edit().putString(KEY_LOCAL, value.name).apply() }

    var localRegion: LocalRegion
        get() = LocalRegion.valueOf(prefs.getString(KEY_REGION, LocalRegion.auto.name)!!)
        set(value) { prefs.edit().putString(KEY_REGION, value.name).apply() }

    var protection: Protection
        get() = Protection(
            killSwitch = prefs.getBoolean("kill", true),
            dnsThroughVpn = prefs.getBoolean("dns", true),
            blockIpv6 = prefs.getBoolean("ipv6", true),
            allowLan = prefs.getBoolean("lan", true)
        )
        set(value) {
            prefs.edit()
                .putBoolean("kill", value.killSwitch)
                .putBoolean("dns", value.dnsThroughVpn)
                .putBoolean("ipv6", value.blockIpv6)
                .putBoolean("lan", value.allowLan)
                .apply()
        }

    val selected: VpnServer? get() = servers.find { it.id == selectedId } ?: servers.firstOrNull()

    fun upsert(server: VpnServer) {
        val list = servers.toMutableList()
        val idx = list.indexOfFirst { it.id == server.id }
        if (idx >= 0) list[idx] = server else list += server
        servers = list
        if (selectedId == null) selectedId = server.id
    }

    fun upsertAll(items: List<VpnServer>) {
        items.forEach { upsert(it) }
    }

    fun remove(id: String) {
        servers = servers.filterNot { it.id == id }
        if (selectedId == id) selectedId = servers.firstOrNull()?.id
    }

    private fun encode(s: VpnServer) = JSONObject()
        .put("id", s.id).put("name", s.name).put("proto", s.proto.name)
        .put("host", s.host).put("port", s.port).put("password", s.password)
        .put("uuid", s.uuid).put("method", s.method).put("sni", s.sni)
        .put("transport", s.transport).put("security", s.security)
        .put("flow", s.flow).put("fingerprint", s.fingerprint)
        .put("publicKey", s.publicKey).put("shortId", s.shortId)
        .put("wsPath", s.wsPath).put("hy2Obfs", s.hy2Obfs)
        .put("hy2ObfsPassword", s.hy2ObfsPassword).put("rawLink", s.rawLink)

    private fun decode(o: JSONObject) = VpnServer(
        id = o.getString("id"),
        name = o.optString("name"),
        proto = ProxyProto.from(o.optString("proto")),
        host = o.optString("host"),
        port = o.optInt("port"),
        password = o.optString("password"),
        uuid = o.optString("uuid"),
        method = o.optString("method"),
        sni = o.optString("sni"),
        transport = o.optString("transport", "tcp"),
        security = o.optString("security"),
        flow = o.optString("flow"),
        fingerprint = o.optString("fingerprint"),
        publicKey = o.optString("publicKey"),
        shortId = o.optString("shortId"),
        wsPath = o.optString("wsPath", "/"),
        hy2Obfs = o.optString("hy2Obfs"),
        hy2ObfsPassword = o.optString("hy2ObfsPassword"),
        rawLink = o.optString("rawLink")
    )

    companion object {
        private const val KEY_SERVERS = "servers"
        private const val KEY_SELECTED = "selected"
        private const val KEY_ROUTE = "route"
        private const val KEY_LOCAL = "local"
        private const val KEY_REGION = "region"
    }
}
