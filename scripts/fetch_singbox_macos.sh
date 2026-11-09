#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Vendor/bin"
VERSION="${SINGBOX_VERSION:-1.11.15}"
ARCH="$(uname -m)"
case "$ARCH" in
  arm64|aarch64) SB_ARCH=arm64 ;;
  x86_64) SB_ARCH=amd64 ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac
NAME="sing-box-${VERSION}-darwin-${SB_ARCH}"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/${NAME}.tar.gz"
mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading $URL"
curl -fL --retry 3 -o "$TMP/sb.tgz" "$URL"
tar -xzf "$TMP/sb.tgz" -C "$TMP"
BIN="$(find "$TMP" -type f -name sing-box | head -n1)"
cp "$BIN" "$DEST/sing-box"
chmod +x "$DEST/sing-box"
"$DEST/sing-box" version
echo "Installed -> $DEST/sing-box"
