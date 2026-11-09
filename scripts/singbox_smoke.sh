#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/Vendor/bin/sing-box"
WORKDIR="$ROOT/Vendor/bin/smoke"
mkdir -p "$WORKDIR"

if [[ ! -x "$BIN" ]]; then
  "$ROOT/scripts/fetch_singbox_macos.sh"
fi

# 1) Validate a Reality-shaped outbound config (schema only; node need not exist)
cat > "$WORKDIR/reality-check.json" <<'EOF'
{
  "log": { "level": "warn" },
  "inbounds": [
    { "type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 17890 }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "example.com",
      "server_port": 443,
      "uuid": "11111111-2222-3333-4444-555555555555",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "www.cloudflare.com",
        "utls": { "enabled": true, "fingerprint": "chrome" },
        "reality": { "enabled": true, "public_key": "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8", "short_id": "abcd" }
      }
    },
    { "type": "direct", "tag": "direct" }
  ],
  "route": { "final": "proxy" }
}
EOF

echo "== sing-box check (Reality JSON) =="
"$BIN" check -c "$WORKDIR/reality-check.json"

# Client-generated fixtures (from unit tests), if present
WIN_FIX="$(find "$ROOT/windows" -path '*/fixtures/windows-vless-reality.json' 2>/dev/null | head -n1 || true)"
AND_FIX="$ROOT/android/app/build/test-fixtures/android-vless-reality.json"
if [[ -n "${WIN_FIX:-}" && -f "$WIN_FIX" ]]; then
  echo "== sing-box check (Windows builder fixture) =="
  "$BIN" check -c "$WIN_FIX"
fi
if [[ -f "$AND_FIX" ]]; then
  echo "== sing-box check (Android builder fixture) =="
  # Android uses TUN inbound; schema check still validates DNS/outbound
  "$BIN" check -c "$AND_FIX"
fi

# 2) Live proxy smoke: mixed → direct (proves engine + local proxy path)
cat > "$WORKDIR/direct-proxy.json" <<'EOF'
{
  "log": { "level": "warn" },
  "inbounds": [
    { "type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 17891 }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }
  ],
  "route": { "final": "direct" }
}
EOF

echo "== sing-box check (direct proxy) =="
"$BIN" check -c "$WORKDIR/direct-proxy.json"

echo "== start sing-box mixed→direct on 127.0.0.1:17891 =="
"$BIN" run -c "$WORKDIR/direct-proxy.json" >"$WORKDIR/singbox.log" 2>&1 &
PID=$!
cleanup() { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; }
trap cleanup EXIT

ok=0
for _ in $(seq 1 40); do
  if curl -fsS -x http://127.0.0.1:17891 --max-time 3 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -q '^ip='; then
    ok=1
    break
  fi
  sleep 0.25
done

if [[ "$ok" -ne 1 ]]; then
  echo "FAIL: proxy smoke did not return ip=" >&2
  cat "$WORKDIR/singbox.log" >&2 || true
  exit 1
fi

TRACE="$(curl -fsS -x http://127.0.0.1:17891 --max-time 8 https://1.1.1.1/cdn-cgi/trace)"
IP="$(printf '%s\n' "$TRACE" | awk -F= '/^ip=/{print $2}')"
echo "PASS: traffic via sing-box mixed proxy works (ip=$IP)"
echo "$TRACE" | head -5
