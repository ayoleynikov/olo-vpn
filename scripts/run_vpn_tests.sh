#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.dotnet:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

fail=0
trap 'echo "FAILED at line $LINENO"' ERR

echo "######## 1) Windows unit tests ########"
dotnet test "$ROOT/windows/Olo.sln" -c Release --nologo


echo "######## 2) Android unit tests ########"
(
  cd "$ROOT/android"
  if [[ ! -f local.properties ]]; then
    printf 'sdk.dir=%s\n' "$ANDROID_HOME" > local.properties
  fi
  ./gradlew :app:testDebugUnitTest
)

echo "######## 3) sing-box engine smoke ########"
"$ROOT/scripts/singbox_smoke.sh"

echo "######## 4) Apple build smoke (no NE e2e) ########"
if command -v xcodegen >/dev/null; then
  (cd "$ROOT" && xcodegen generate >/dev/null)
fi
xcodebuild -project "$ROOT/OloVPN.xcodeproj" -scheme OloVPN \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build >/tmp/olo-apple-build.log 2>&1 \
  && echo "PASS: Apple macOS build" \
  || { echo "FAIL: Apple build — see /tmp/olo-apple-build.log"; tail -40 /tmp/olo-apple-build.log; exit 1; }

echo
echo "ALL AUTOMATED CHECKS PASSED"
echo "NOTE: full VPN tunnel e2e (NE / Libbox TUN / WinTun + live node) still needs a real server + signing."
