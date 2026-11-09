#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-v1.14.3-r2}"
URL="https://github.com/DE0CH/libbox-apple/releases/download/${VERSION}/Libbox.xcframework.zip"
DEST="$ROOT/Vendor"
mkdir -p "$DEST"
cd "$DEST"
echo "Downloading Libbox ${VERSION}…"
curl -L --retry 5 -o Libbox.xcframework.zip "$URL"
rm -rf Libbox.xcframework
unzip -qo Libbox.xcframework.zip

# Flatten iOS slices (gomobile Versions/A → shallow)
python3 - <<'PY'
import shutil
from pathlib import Path
root = Path("Libbox.xcframework")
for fw in root.glob("ios-*/Libbox.framework"):
    versions = fw / "Versions" / "A"
    if not versions.exists():
        continue
    tmp = fw.parent / (fw.name + ".shallow")
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir()
    for item in versions.iterdir():
        if item.name == "Resources":
            for r in item.iterdir():
                target = tmp / r.name
                if r.is_file():
                    shutil.copy2(r, target)
                else:
                    shutil.copytree(r, target)
        else:
            dest = tmp / item.name
            if item.is_dir():
                shutil.copytree(item, dest)
            else:
                shutil.copy2(item, dest)
    shutil.rmtree(fw)
    tmp.rename(fw)
    print("flattened", fw)
PY

echo "OK → $DEST/Libbox.xcframework"
ls Libbox.xcframework
