package app.olo.vpn

import app.olo.vpn.core.SingBoxConfigBuilder
import app.olo.vpn.model.LocalPolicy
import app.olo.vpn.model.LocalRegion
import app.olo.vpn.model.Protection
import app.olo.vpn.model.ProxyProto
import app.olo.vpn.model.RouteMode
import app.olo.vpn.model.VpnServer
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class SingBoxConfigBuilderTest {
    @Test
    fun buildsVlessRealityJson() {
        val server = VpnServer(
            name = "R",
            proto = ProxyProto.vless,
            host = "example.com",
            port = 443,
            uuid = "11111111-2222-3333-4444-555555555555",
            sni = "www.cloudflare.com",
            security = "reality",
            publicKey = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
            shortId = "abcd",
            fingerprint = "chrome",
            flow = "xtls-rprx-vision"
        )
        val json = SingBoxConfigBuilder.build(
            server, RouteMode.smart, LocalPolicy.bypass, LocalRegion.ru, Protection()
        )
        val root = JSONObject(json)
        assertTrue(root.has("inbounds"))
        assertTrue(root.has("outbounds"))
        val proxy = root.getJSONArray("outbounds").getJSONObject(0)
        assertEquals("vless", proxy.getString("type"))
        assertEquals("xtls-rprx-vision", proxy.getString("flow"))
        val tls = proxy.getJSONObject("tls")
        assertTrue(tls.getJSONObject("reality").getBoolean("enabled"))
        assertEquals(
            "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
            tls.getJSONObject("reality").getString("public_key")
        )
        assertEquals(
            "tls://1.1.1.1",
            root.getJSONObject("dns").getJSONArray("servers").getJSONObject(0).getString("address")
        )
        // Write fixture for sing-box check smoke
        val out = File("build/test-fixtures")
        out.mkdirs()
        File(out, "android-vless-reality.json").writeText(json)
    }

    @Test
    fun buildsHy2WithObfs() {
        val server = VpnServer(
            name = "H",
            proto = ProxyProto.hysteria2,
            host = "hy2.example",
            port = 443,
            password = "secret",
            sni = "hy2.example",
            hy2Obfs = "salamander",
            hy2ObfsPassword = "obfs"
        )
        val json = SingBoxConfigBuilder.build(
            server, RouteMode.global, LocalPolicy.throughVPN, LocalRegion.auto, Protection()
        )
        val proxy = JSONObject(json).getJSONArray("outbounds").getJSONObject(0)
        assertEquals("hysteria2", proxy.getString("type"))
        assertEquals("salamander", proxy.getJSONObject("obfs").getString("type"))
    }
}
