#!/usr/bin/env bash
# Build zlib, argp-standalone, libiberty (obstack), and elfutils libelf into a
# prefix tree for aarch64-linux-android (Bionic), for use with libbpf-sys when
# cross-compiling scx_lavd. Requires ANDROID_NDK_HOME and host build tools
# (curl, tar, make, autoreconf, patch, flex, bison, gawk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STAGEDIR="${SCX_ANDROID_STAGEDIR:-$ROOT/.android-aarch64-deps}"
PREFIX="${SCX_ANDROID_LIBELF_PREFIX:-$STAGEDIR/prefix}"
SRC="$STAGEDIR/src"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
	echo "error: set ANDROID_NDK_HOME" >&2
	exit 1
fi

API="${ANDROID_API_LEVEL:-34}"
case "$(uname -s)" in
Linux) NDK_HOST="${ANDROID_NDK_HOST_DIR:-linux-x86_64}" ;;
Darwin) NDK_HOST="${ANDROID_NDK_HOST_DIR:-darwin-x86_64}" ;;
*)
	echo "error: unsupported host OS: $(uname -s)" >&2
	exit 1
	;;
esac

NDK_BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST/bin"
export CC="$NDK_BIN/aarch64-linux-android${API}-clang"
export AR="$NDK_BIN/llvm-ar"
export RANLIB="$NDK_BIN/llvm-ranlib"

if [[ ! -x "$CC" ]]; then
	echo "error: missing Android compiler: $CC" >&2
	exit 1
fi

mkdir -p "$PREFIX/include" "$PREFIX/lib" "$SRC"
cp -f "$ROOT/scripts/android/include-stubs/libintl.h" "$PREFIX/include/libintl.h"

if [[ -f "$PREFIX/lib/libelf.a" && -z "${SCX_ANDROID_REBUILD_DEPS:-}" ]]; then
	echo "Dependencies already present at $PREFIX (set SCX_ANDROID_REBUILD_DEPS=1 to rebuild)." >&2
	exit 0
fi

echo "Building Android libelf prefix -> $PREFIX" >&2

ZVER=1.3.1
if [[ ! -f "$PREFIX/lib/libz.a" ]]; then
	curl -sL -o "$SRC/zlib.tgz" "https://github.com/madler/zlib/releases/download/v$ZVER/zlib-$ZVER.tar.gz"
	tar -C "$SRC" -xzf "$SRC/zlib.tgz"
	cd "$SRC/zlib-$ZVER"
	CC="$CC" AR="$AR" RANLIB="$RANLIB" ./configure --static --prefix="$PREFIX"
	make -j"$(nproc)"
	make install
	cd "$ROOT"
fi

if [[ ! -f "$PREFIX/lib/libargp.a" ]]; then
	curl -sL -o "$SRC/argp.tgz" "https://www.lysator.liu.se/~nisse/misc/argp-standalone-1.3.tar.gz"
	rm -rf "$SRC/argp-standalone-1.3"
	tar -C "$SRC" -xzf "$SRC/argp.tgz"
	cd "$SRC/argp-standalone-1.3"
	export CFLAGS="-std=gnu89 -O2"
	./configure --host=aarch64-linux-android --prefix="$PREFIX" --disable-shared
	make -j"$(nproc)"
	cp libargp.a "$PREFIX/lib/"
	cp argp.h "$PREFIX/include/"
	cd "$ROOT"
fi

if [[ ! -f "$PREFIX/lib/libiberty.a" ]]; then
	BUVER=2.42
	if [[ ! -d "$SRC/binutils-$BUVER" ]]; then
		curl -sL -o "$SRC/binutils.tar.xz" "https://ftp.gnu.org/gnu/binutils/binutils-$BUVER.tar.xz"
		tar -C "$SRC" -xf "$SRC/binutils.tar.xz"
	fi
	cd "$SRC/binutils-$BUVER/libiberty"
	export CFLAGS="-O2"
	./configure --host=aarch64-linux-android --prefix="$PREFIX"
	make -j"$(nproc)"
	cp libiberty.a "$PREFIX/lib/"
	cd "$ROOT"
	cp -f "$SRC/binutils-$BUVER/include/obstack.h" "$PREFIX/include/"
fi

EUVER=0.191
EUSRC="$SRC/elfutils-$EUVER"
if [[ ! -d "$EUSRC" ]]; then
	curl -sL -o "$SRC/elfutils.tar.bz2" "https://sourceware.org/elfutils/ftp/$EUVER/elfutils-$EUVER.tar.bz2"
	tar -C "$SRC" -xjf "$SRC/elfutils.tar.bz2"
fi
if ! grep -q scx_prog_inv "$EUSRC/lib/color.c"; then
	patch -d "$EUSRC" -p1 <"$ROOT/scripts/android/patches/elfutils-0.191-android-color.patch"
fi

cd "$EUSRC"
autoreconf -i -f >/dev/null
export CFLAGS="-O2 -I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
export LIBS="-liberty -largp -lz"
./configure --host=aarch64-linux-android --prefix="$PREFIX" \
	--disable-debuginfod --disable-libdebuginfod --disable-demangler \
	--without-zstd --disable-nls --disable-symbol-versioning
make -j"$(nproc)" BUILD_STATIC_ONLY=y -C lib
make -j"$(nproc)" BUILD_STATIC_ONLY=y -C libelf install
cd "$ROOT"

echo "Done. Use: export SCX_ANDROID_LIBELF_PREFIX=$PREFIX" >&2
