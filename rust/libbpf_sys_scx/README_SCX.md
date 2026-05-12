# libbpf-sys (scx fork)

Vendored from **crates.io `libbpf-sys` 1.7.0+v1.7.0**, with a small **`build.rs`**
change used by the whole workspace via **`[patch.crates-io]`** in the repo root
`Cargo.toml`:

1. Emit **`LIBBPF_SYS_LIBRARY_PATH`** / per-target **`LIBBPF_SYS_LIBRARY_PATH_*`**
   **before** **`cargo:rustc-link-lib=static=elf`** so rustc can find **`libelf.a`**
   when cross-compiling.
2. When **`static-libelf`** is enabled on a typical **glibc Linux** host triple
   (not Android), also link **`libzstd`** — distro **`libelf.a`** often references
   ZSTD symbols. Android **`libelf.a`** from **`bootstrap_android_lavd_deps.sh`**
   does not need this.

Upstream: https://github.com/libbpf/libbpf-sys
