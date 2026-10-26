#!/usr/bin/env bash
set -euo pipefail

# Build the native ArkTS/ArkUI branch and place a release-ready HAP in build-out.
# hvigor rejects non-ASCII project paths, so build from an ASCII temp directory.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${CLI:-/home/liandd/Data/项目/command-line-tools}"
WORK="${WORK:-/tmp/tuichuang-native-build}"
VERSION="$(python3 - "$ROOT/AppScope/app.json5" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
m=re.search(r'"versionName"\s*:\s*"([^"]+)"',s)
print(m.group(1) if m else "0.0.0")
PY
)"

rm -rf "$WORK"
mkdir -p "$WORK"
cp -a "$ROOT/." "$WORK/"
cd "$WORK"

export HOME="${HOME:-/tmp/tuichuang-build-home}"
mkdir -p "$HOME"
export DEVECO_SDK_HOME="$CLI/sdk"
export PATH="$CLI/bin:$CLI/tool/node/bin:$CLI/sdk/default/openharmony/toolchains:$PATH"

hvigorw assembleHap \
  --mode module \
  -p module=entry@default \
  -p product=default \
  -p buildMode=debug \
  --no-daemon

mkdir -p "$ROOT/build-out/native-rewrite"
cp -f "entry/build/default/outputs/default/tuichuang-unsigned.hap" \
  "$ROOT/build-out/native-rewrite/tuichuang-native-${VERSION}-unsigned.hap"

echo "HAP: $ROOT/build-out/native-rewrite/tuichuang-native-${VERSION}-unsigned.hap"
