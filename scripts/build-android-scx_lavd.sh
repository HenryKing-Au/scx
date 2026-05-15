#!/usr/bin/env bash
# Build scx_lavd for Android arm64 with statically linked dependencies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Host clang for BPF; NDK prepends its toolchain to PATH below.
if command -v clang >/dev/null 2>&1; then
  export BPF_CLANG="$(command -v clang)"
elif command -v clang-19 >/dev/null 2>&1; then
  export BPF_CLANG="$(command -v clang-19)"
else
  echo "host clang not found (install clang for BPF build)" >&2
  exit 1
fi

: "${ANDROID_NDK_HOME:=${HOME}/android-ndk-r27c}"
: "${ANDROID_API_LEVEL:=34}"

NDK_TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"
export PATH="${NDK_TOOLCHAIN}/bin:${PATH}"

export CC="${NDK_TOOLCHAIN}/bin/aarch64-linux-android${ANDROID_API_LEVEL}-clang"
export CXX="${NDK_TOOLCHAIN}/bin/aarch64-linux-android${ANDROID_API_LEVEL}-clang++"
export AR="${NDK_TOOLCHAIN}/bin/llvm-ar"
export RANLIB="${NDK_TOOLCHAIN}/bin/llvm-ranlib"

export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="${CC}"
export CC_aarch64_linux_android="${CC}"
export CXX_aarch64_linux_android="${CXX}"
export AR_aarch64_linux_android="${AR}"
export RANLIB_aarch64_linux_android="${RANLIB}"

rustup target add aarch64-linux-android >/dev/null 2>&1 || true

# libbpf-sys builds vendored elfutils with {arch}-{vendor}-{os}-{env}, which is
# invalid on Android (empty env => aarch64-unknown-android-). Use NDK triplet.
clean_elfutils_artifacts() {
  local eu
  eu="$(find "${CARGO_HOME:-${HOME}/.cargo}/registry/src" -path '*/libbpf-sys-1.7.0*/elfutils' 2>/dev/null | head -1)"
  [[ -z "${eu}" ]] && return 0
  find "${eu}" \( -name '*.o' -o -name '*.a' -o -name '*.so' -o -name '*.lo' \) -delete 2>/dev/null || true
  rm -f "${eu}/config.status" "${eu}/config.h" "${eu}/lib/Makefile" "${eu}/libelf/Makefile" 2>/dev/null || true
}

build_android_compat_libs() {
  local dir="${ROOT}/.android-deps/compat"
  local src="${ROOT}/scripts/android-compat"
  mkdir -p "${dir}/include"
  cp "${src}/argp.h" "${dir}/include/argp.h"
  if [[ ! -f "${dir}/include/libintl.h" ]]; then
    cat > "${dir}/include/libintl.h" <<'EOF'
#ifndef LIBINTL_H
#define LIBINTL_H
#define gettext(Msgid) (Msgid)
#define dgettext(Domainname, Msgid) (Msgid)
#define ngettext(Msgid, MsgidPlural, N) ((N) == 1 ? (Msgid) : (MsgidPlural))
#endif
EOF
  fi
  cp "${src}/compat.c" "${dir}/compat.c"
  "${CC}" -I"${dir}/include" -c "${dir}/compat.c" -o "${dir}/compat.o"
  "${AR}" rcs "${dir}/libandroid_compat.a" "${dir}/compat.o"
  ln -sf libandroid_compat.a "${dir}/libargp.a"
  export ANDROID_ARGP_LIB_DIR="${dir}"
}

patch_libbpf_sys_android() {
  local f
  f="$(find "${CARGO_HOME:-${HOME}/.cargo}/registry/src" -path '*/libbpf-sys-1.7.0*/build.rs' 2>/dev/null | head -1)"
  [[ -z "${f}" ]] && { echo "libbpf-sys build.rs not found" >&2; return 1; }
  python3 "${ROOT}/scripts/patches/apply-libbpf-sys-android.py" "${f}"
}

build_android_compat_libs
patch_libbpf_sys_android
clean_elfutils_artifacts

# Statically link libbpf/libelf/zlib (vendored). Also request fully static Bionic link.
export RUSTFLAGS="${RUSTFLAGS:-} -C link-arg=-static -C link-arg=-static-libgcc"

cargo build --release -p scx_lavd --target aarch64-linux-android "$@"

OUT="${ROOT}/target/aarch64-linux-android/release/scx_lavd"
echo ""
echo "Build succeeded: ${OUT}"
file "${OUT}"
echo "Dynamic dependencies (if any):"
readelf -d "${OUT}" 2>/dev/null | grep NEEDED || echo "  (none — fully static)"
echo ""
echo "Third-party libs (libbpf, libelf, zlib) are linked statically via libbpf-rs vendored feature."
