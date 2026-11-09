#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/windows/Olo.Desktop/bin-dist}"
APP_DATA_HINT='$env:APPDATA/Olo/bin'
VERSION="${SINGBOX_VERSION:-1.11.0}"
mkdir -p "$DEST"

ARCH="${SINGBOX_ARCH:-amd64}"
NAME="sing-box-${VERSION}-windows-${ARCH}"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/${NAME}.zip"
ZIP="$DEST/${NAME}.zip"

echo "Downloading $URL"
curl -fL --retry 3 -o "$ZIP" "$URL"
unzip -o "$ZIP" -d "$DEST"
BIN="$(find "$DEST" -name 'sing-box.exe' | head -n1)"
if [[ -z "$BIN" ]]; then
  echo "sing-box.exe not found in archive" >&2
  exit 1
fi
mkdir -p "$ROOT/windows/Olo.Desktop/bin"
cp "$BIN" "$ROOT/windows/Olo.Desktop/bin/sing-box.exe"
echo "Installed -> windows/Olo.Desktop/bin/sing-box.exe"
echo "At runtime the app also looks in %AppData%/Olo/bin/ ($APP_DATA_HINT)"
echo "Copy there on the Windows machine if needed:"
echo "  copy windows\\Olo.Desktop\\bin\\sing-box.exe %AppData%\\Olo\\bin\\"
