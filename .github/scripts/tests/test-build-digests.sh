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

# CUDA majors and architectures must remain distinct manifest entries even
# though their installed backend has the same filename.
for arch in x64 arm64; do
  mkdir -p "$TMP/cuda-13-$arch/whisper-v-test"
  printf 'cuda13-%s' "$arch" > "$TMP/cuda-13-$arch/whisper-v-test/libggml-cuda.so"
  tar -czf "$TMP/archives/whisper-v-test-bin-ubuntu-cuda-13-$arch.tar.gz" -C "$TMP/cuda-13-$arch" whisper-v-test
done
mkdir -p "$TMP/cuda-12/whisper-v-test"
printf cuda12 > "$TMP/cuda-12/whisper-v-test/libggml-cuda.so"
tar -czf "$TMP/archives/whisper-v-test-bin-ubuntu-cuda-x64.tar.gz" -C "$TMP/cuda-12" whisper-v-test

SOURCE_DATE_EPOCH=0 "$ROOT/.github/scripts/build-digests.py" v-test "$TMP/archives" "$TMP/out" >/dev/null
cp "$TMP/out/v-test.json" "$TMP/first.json"
SOURCE_DATE_EPOCH=0 "$ROOT/.github/scripts/build-digests.py" v-test "$TMP/archives" "$TMP/out" >/dev/null
cmp "$TMP/first.json" "$TMP/out/v-test.json"
jq -e '
  .version == 1 and .tag == "v-test" and .generated == "1970-01-01T00:00:00Z" and
  (.sources["ardanlabs/bucky-builder"].assets | length) == 6 and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-ubuntu-cpu-x64.tar.gz"].links["lib/libwhisper.so"] == "sub/libwhisper.so.1" and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-windows-cpu-x64.zip"].files["WHISPER.DLL"] and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-darwin-metal-universal.zip"].files["libwhisper.dylib"] and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-ubuntu-cuda-13-x64.tar.gz"].files["libggml-cuda.so"] == "017dfd3d28c4d77c4ab7510ca4261c00279a459feea051f0a0a1e27ec4199e96" and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-ubuntu-cuda-13-arm64.tar.gz"].files["libggml-cuda.so"] == "0242709a8a28d8bc4c9060d52d6153917ef436ab2d1f1fbb3d7266e1d7120f0b" and
  .sources["ardanlabs/bucky-builder"].assets["whisper-v-test-bin-ubuntu-cuda-x64.tar.gz"].files["libggml-cuda.so"] == "70211a8b2877d455e90117f66f17baac4632607b94419bc55d5f39817c9fce9e"
' "$TMP/out/v-test.json" >/dev/null
if command -v sha256sum >/dev/null; then
  (cd "$TMP/out" && sha256sum -c v-test.json.sha256)
else
  (cd "$TMP/out" && shasum -a 256 -c v-test.json.sha256)
fi
