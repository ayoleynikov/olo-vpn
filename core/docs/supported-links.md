# Universal share links (all platforms)

Olo imports the same URI families on **iPhone, Mac, Android, Windows**.

## Single-node URIs

| Scheme | Notes |
|--------|--------|
| `ss://` | SIP002 / legacy base64 |
| `vmess://` | Base64 JSON (v2rayN) |
| `vless://` | Query: `type`, `security`, `sni`, `fp`, `pbk`, `sid`, `flow`, `path`, `host`, `serviceName` |
| `trojan://` | Query: `sni`, `type`, `path`, `host`, `security`, `fp`, `pbk`, `sid` |
| `hysteria2://` / `hy2://` | Query: `sni`, `obfs`, `obfs-password` |
| `tuic://` | `uuid:password@host:port` |
| `socks://` / `socks5://` | Optional user:pass |
| `http://` / `https://` **with** `user@host` | HTTP proxy node (not a subscription) |
| `wireguard://` / `wg://` | `privateKey@endpoint:port?publickey=&address=` |

## Bulk paste

Paste several links (newlines or inline). Clients call `parseMany` / `parseAll` and import every recognized URI.

## Subscriptions

Plain `https://…` **without** userinfo is treated as a subscription URL:

- newline / base64 list of the URIs above
- Clash Meta JSON (`{"proxies":[…]}`)
- sing-box JSON (`{"outbounds":[…]}`) where outbound types map to nodes
