#!/usr/bin/env python3
"""Apply Android cross-build fixes to vendored libbpf-sys build.rs."""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <libbpf-sys/build.rs>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")
    if "ANDROID_ELFUTILS_PATCH_V2" in text:
        return 0

    old = '            format!("{arch}-{vendor}-{os}-{env}")'
    new = """            if os == "android" {
                format!("{arch}-linux-android")
            } else if env.is_empty() {
                format!("{arch}-{vendor}-{os}")
            } else {
                format!("{arch}-{vendor}-{os}-{env}")
            }"""
    if old not in text:
        print("host triplet pattern missing", file=sys.stderr)
        return 1
    text = text.replace(old, new)

    old_ld = '    let out_lib = format!("-L{}", out_dir.display());'
    new_ld = """    let out_lib = {
        let mut ld = format!("-L{}", out_dir.display());
        if env::var("CARGO_CFG_TARGET_OS").unwrap() == "android" {
            if let Ok(path) = env::var("ANDROID_ARGP_LIB_DIR") {
                ld.push_str(&format!(" -L{path} -largp"));
            }
        }
        ld
    };"""
    if old_ld not in text:
        print("LDFLAGS pattern missing", file=sys.stderr)
        return 1
    text = text.replace(old_ld, new_ld)

    old_cfg = '        .arg("--without-zstd")\n        .arg("--prefix")'
    new_cfg = """        .arg("--without-zstd")
        .args(if env::var("CARGO_CFG_TARGET_OS").unwrap() == "android" {
            vec!["--disable-nls"]
        } else {
            vec![]
        })
        .arg("--prefix")"""
    if old_cfg not in text:
        print("configure args pattern missing", file=sys.stderr)
        return 1
    text = text.replace(old_cfg, new_cfg)

    needle = '    cflags.push_str(&format!(" -I{}/zlib/", src_dir.display()));\n'
    insert = needle + """    if env::var("CARGO_CFG_TARGET_OS").unwrap() == "android" {
        if let Ok(path) = env::var("ANDROID_ARGP_LIB_DIR") {
            cflags.push_str(&format!(" -I{path}/include"));
        }
        cflags.push_str(" -Wno-error -Wno-unused-parameter -Wno-unused-variable");
    }
"""
    if needle not in text:
        print("cflags zlib pattern missing", file=sys.stderr)
        return 1
    text = text.replace(needle, insert)

    path.write_text("// ANDROID_ELFUTILS_PATCH_V2\n" + text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
