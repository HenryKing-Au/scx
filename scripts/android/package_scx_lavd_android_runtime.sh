#!/usr/bin/env bash
# Copy scx_lavd and the libelf shared libraries from the Android dependency prefix
# into a staging directory so you can adb push a self-contained folder (fixes
# "library libelf.so.1 not found" on device when the binary is dynamically linked).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEFAULT_PREFIX="$ROOT/.android-aarch64-deps/prefix"
PREFIX="${SCX_ANDROID_LIBELF_PREFIX:-$DEFAULT_PREFIX}"
STAGE="${SCX_ANDROID_RUNTIME_STAGE:-$ROOT/.android-aarch64-deps/stage}"

PROFILE="${SCX_ANDROID_CARGO_PROFILE:-release}"
BIN="$ROOT/target/aarch64-linux-android/$PROFILE/scx_lavd"

if [[ ! -f "$BIN" ]]; then
	echo "error: expected binary at $BIN (build with ./scripts/android/build_scx_lavd.sh build --$PROFILE -p scx_lavd --target aarch64-linux-android)." >&2
	exit 1
fi
if [[ ! -d "$PREFIX/lib" ]]; then
	echo "error: missing $PREFIX/lib (set SCX_ANDROID_LIBELF_PREFIX or run bootstrap_android_lavd_deps.sh)." >&2
	exit 1
fi

mkdir -p "$STAGE"
cp -f "$BIN" "$STAGE/scx_lavd"
chmod 755 "$STAGE/scx_lavd"

# Real file + SONAME symlinks (bootstrap installs libelf-*.so, libelf.so.1, libelf.so).
shopt -s nullglob
for f in "$PREFIX/lib"/libelf*.so*; do
	cp -a "$f" "$STAGE/"
done
shopt -u nullglob

echo "Staged under $STAGE :" >&2
ls -la "$STAGE" >&2
echo >&2
echo "Example: adb push $STAGE/. /data/local/tmp/lavd/ && adb shell 'cd /data/local/tmp/lavd && export LD_LIBRARY_PATH=/data/local/tmp/lavd && ./scx_lavd ...'" >&2
