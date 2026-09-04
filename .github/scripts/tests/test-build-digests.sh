#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/archives/linux/whisper-v-test/lib/sub" "$TMP/out" "$TMP/win/whisper-v-test" "$TMP/mac/build-apple/whisper.xcframework/macos/whisper.framework/Versions/A"
printf linux > "$TMP/archives/linux/whisper-v-test/lib/sub/libwhisper.so.1"
ln -s sub/libwhisper.so.1 "$TMP/archives/linux/whisper-v-test/lib/libwhisper.so"
tar -czf "$TMP/archives/whisper-v-test-bin-ubuntu-cpu-x64.tar.gz" -C "$TMP/archives/linux" whisper-v-test
printf windows > "$TMP/win/whisper-v-test/WHISPER.DLL"
(cd "$TMP/win" && zip -qr "$TMP/archives/whisper-v-test-bin-windows-cpu-x64.zip" whisper-v-test)
printf darwin > "$TMP/mac/build-apple/whisper.xcframework/macos/whisper.framework/Versions/A/whisper"
(cd "$TMP/mac" && zip -qr "$TMP/archives/whisper-v-test-bin-darwin-metal-universal.zip" build-apple)

SOURCE_DATE_EPOCH=0 "$ROOT/.github/scripts/build-digests.py" v-test "$TMP/archives" "$TMP/out" >/dev/null
cp "$TMP/out/v-test.json" "$TMP/first.json"
SOURCE_DATE_EPOCH=0 "$ROOT/.github/scripts/build-digests.py" v-test "$TMP/archives" "$TMP/out" >/dev/null
cmp "$TMP/first.json" "$TMP/out/v-test.json"
jq -e '
  .version == 1 and .tag == "v-test" and .generated == "1970-01-01T00:00:00Z" and
  (.sources["ardanlabs/bucky-builder"].assets | length) == 3 and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-ubuntu-cpu-x64.tar.gz"].links["lib/libwhisper.so"] == "sub/libwhisper.so.1" and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-windows-cpu-x64.zip"].files["WHISPER.DLL"] and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-darwin-metal-universal.zip"].files["libwhisper.dylib"]
' "$TMP/out/v-test.json" >/dev/null
if command -v sha256sum >/dev/null; then
  (cd "$TMP/out" && sha256sum -c v-test.json.sha256)
else
  (cd "$TMP/out" && shasum -a 256 -c v-test.json.sha256)
fi
