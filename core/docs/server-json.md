# Olo server JSON (shared storage format)

Cross-platform clients store servers as `olo-servers.json` (array).

```json
{
  "id": "uuid",
  "name": "Display name",
  "proto": "vless|vmess|trojan|shadowsocks|hysteria2|tuic|socks|http|wireguard",
  "host": "example.com",
  "port": 443,
  "password": "",
  "uuid": "",
  "method": "",
  "sni": "",
  "transport": "tcp",
  "security": "reality|tls|",
  "flow": "xtls-rprx-vision",
  "fingerprint": "chrome",
  "publicKey": "",
  "shortId": "",
  "wsPath": "/",
  "wsHost": "",
  "grpcServiceName": "GunService",
  "hy2Obfs": "",
  "hy2ObfsPassword": "",
  "rawLink": ""
}
```

Secrets: Apple uses Keychain; Android EncryptedSharedPreferences / Keystore; Windows DPAPI when available. Disk copy may redact password/uuid.

See also [`supported-links.md`](supported-links.md) for URI schemes shared by iPhone, Mac, Android, and Windows.
