package app.olo.vpn

import app.olo.vpn.core.LinkParser
import app.olo.vpn.core.SubscriptionImporter
import app.olo.vpn.model.ProxyProto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class LinkParserTest {
    @Test
    fun parseVlessReality() {
        val link =
            "vless://11111111-2222-3333-4444-555555555555@example.com:443" +
                "?encryption=none&flow=xtls-rprx-vision&security=reality" +
                "&sni=www.cloudflare.com&fp=chrome&pbk=PUBLICKEY&sid=abcd1234&type=tcp#RealityNode"
        val s = LinkParser.parse(link)
        assertEquals(ProxyProto.vless, s.proto)
        assertEquals("example.com", s.host)
        assertEquals(443, s.port)
        assertEquals("11111111-2222-3333-4444-555555555555", s.uuid)
        assertEquals("reality", s.security)
        assertEquals("PUBLICKEY", s.publicKey)
        assertEquals("abcd1234", s.shortId)
        assertEquals("chrome", s.fingerprint)
        assertEquals("xtls-rprx-vision", s.flow)
        assertEquals("RealityNode", s.name)
    }

    @Test
    fun parseTrojan() {
        val s = LinkParser.parse("trojan://secret@host.example:8443?sni=host.example#T1")
        assertEquals(ProxyProto.trojan, s.proto)
        assertEquals("secret", s.password)
        assertEquals(8443, s.port)
    }

    @Test
    fun parseHy2() {
        val s = LinkParser.parse("hy2://pass@hy2.example:443?sni=hy2.example&obfs=salamander&obfs-password=obfs#H")
        assertEquals(ProxyProto.hysteria2, s.proto)
        assertEquals("pass", s.password)
        assertEquals("salamander", s.hy2Obfs)
        assertEquals("obfs", s.hy2ObfsPassword)
    }

    @Test
    fun parseSsUserInfo() {
        val s = LinkParser.parse("ss://aes-256-gcm:password@ss.example:8388#SS")
        assertEquals(ProxyProto.shadowsocks, s.proto)
        assertEquals("aes-256-gcm", s.method)
        assertEquals("password", s.password)
        assertEquals("ss.example", s.host)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectEmpty() {
        LinkParser.parse("   ")
    }

    @Test
    fun rejectUnknown() {
        try {
            LinkParser.parse("ftp://nope")
            assertTrue("expected error", false)
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("не поддерживается") || e.message!!.isNotEmpty())
        } catch (e: IllegalArgumentException) {
            // ok
        }
    }

    @Test
    fun parseTuicHttpWgAndMany() {
        val tuic = LinkParser.parse("tuic://11111111-2222-3333-4444-555555555555:pass@tuic.example:443?sni=tuic.example#T")
        assertEquals(ProxyProto.tuic, tuic.proto)
        val http = LinkParser.parse("http://u:p@proxy.example:8080#H")
        assertEquals(ProxyProto.http, http.proto)
        val wg = LinkParser.parse("wg://PRIVATEKEY@wg.example:51820?publickey=PUB#W")
        assertEquals(ProxyProto.wireguard, wg.proto)
        val many = LinkParser.parseMany(
            "trojan://secret@host.example:8443?sni=host.example#T1\nhy2://pass@hy2.example:443?sni=hy2.example#H"
        )
        assertEquals(2, many.size)
        assertTrue(!SubscriptionImporter.isSubscriptionUrl("http://u:p@proxy.example:8080"))
        assertTrue(SubscriptionImporter.isSubscriptionUrl("https://example.com/sub#MySub"))
    }
}
