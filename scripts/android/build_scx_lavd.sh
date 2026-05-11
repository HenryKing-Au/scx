#!/usr/bin/env bash
# Cross-build scx_lavd (and pass through other cargo args) for aarch64-linux-android.
# Requires ANDROID_NDK_HOME. For libbpf-sys you still need libelf + zlib for the
# target — set SCX_ANDROID_LIBELF_PREFIX (see CARGO_BUILD.md §8.1).
set -euo pipefail

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
	echo "error: set ANDROID_NDK_HOME to the NDK root (directory containing toolchains/llvm)." >&2
	exit 1
fi

API="${ANDROID_API_LEVEL:-34}"

case "$(uname -s)" in
Linux) NDK_HOST="${ANDROID_NDK_HOST_DIR:-linux-x86_64}" ;;
Darwin) NDK_HOST="${ANDROID_NDK_HOST_DIR:-darwin-x86_64}" ;;
*)
	echo "error: unsupported host OS for NDK prebuilt layout: $(uname -s)" >&2
	exit 1
	;;
esac

NDK_BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST/bin"
if [[ ! -x "$NDK_BIN/clang" ]]; then
	echo "error: expected clang at $NDK_BIN/clang" >&2
	exit 1
fi

export BPF_CLANG="${BPF_CLANG:-$NDK_BIN/clang}"
export CC_aarch64_linux_android="${CC_aarch64_linux_android:-$NDK_BIN/aarch64-linux-android${API}-clang}"
export AR_aarch64_linux_android="${AR_aarch64_linux_android:-$NDK_BIN/llvm-ar}"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="${CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER:-$CC_aarch64_linux_android}"

if [[ -n "${SCX_ANDROID_LIBELF_PREFIX:-}" ]]; then
	lib="${SCX_ANDROID_LIBELF_PREFIX}/lib"
	export LIBBPF_SYS_EXTRA_CFLAGS="-I${SCX_ANDROID_LIBELF_PREFIX}/include${LIBBPF_SYS_EXTRA_CFLAGS:+ ${LIBBPF_SYS_EXTRA_CFLAGS}}"
	export LIBBPF_SYS_LIBRARY_PATH_aarch64_linux_android="${LIBBPF_SYS_LIBRARY_PATH_aarch64_linux_android:-$lib}"
fi

echo "Using NDK clang: $CC_aarch64_linux_android (API $API)" >&2
if [[ -z "${SCX_ANDROID_LIBELF_PREFIX:-}" ]]; then
	echo "note: SCX_ANDROID_LIBELF_PREFIX is unset; libbpf-sys will need libelf headers/libs for aarch64-linux-android (see CARGO_BUILD.md §8.1)." >&2
fi

exec cargo "$@"
