#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/android/app/libs"
mkdir -p "$DEST"
# Prefer official build pipeline; placeholder documents expected path.
# Example release mirrors (update URL when pinning a version):
# https://github.com/SagerNet/sing-box/releases — build lib_android locally:
#   cd Vendor/sing-box && make lib_install && make lib_android
echo "Build Libbox AAR from sing-box:"
echo "  git clone https://github.com/SagerNet/sing-box Vendor/sing-box"
echo "  cd Vendor/sing-box && make lib_install && go run ./cmd/internal/build_libbox -target android"
echo "  cp libbox.aar $DEST/"
echo "Then uncomment implementation(files(\"libs/libbox.aar\")) in android/app/build.gradle.kts"
