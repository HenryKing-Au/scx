# Building schedulers in the `scx` project

The `scx` repository is organized as a **Cargo workspace** containing multiple schedulers, shared libraries, and tools.
Schedulers are implemented as individual Rust crates under `scheds/rust/*`.

This document explains how to build the entire project as well as individual schedulers and tools.

---

## 1. Available build profiles

The project defines several Cargo build profiles in the top-level `Cargo.toml`:

- **release**
  Thin LTO enabled (default for production).

- **release-tiny**
  Stripped, thin LTO, optimized for small binary size.

- **release-fast**
  Optimized for compilation speed and native CPU optimizations, no LTO.

You can select a profile using the `--profile` option, for example:

```bash
cargo build --profile=release-tiny
```

---

## 2. Building the entire workspace

To build **all crates** (schedulers, libraries, and tools):

- Debug build (default):

  ```bash
  cargo build
  ```

- Optimized release build:

  ```bash
  cargo build --release
  ```

- Tiny profile:

  ```bash
  cargo build --profile=release-tiny
  ```

- Fast profile:

  ```bash
  cargo build --profile=release-fast
  ```

---

## 3. Building individual schedulers

Each scheduler is its own Cargo package. You can build a single one using:

```bash
cargo build --profile=<profile> -p <scheduler_name>
```

Example for **scx_flash** with **release-tiny**:

```bash
cargo build --profile=release-tiny -p scx_flash
```

---

### List of schedulers

| Scheduler name | Example build command |
|----------------|------------------------|
| `scx_bpfland`  | `cargo build --release -p scx_bpfland` |
| `scx_chaos`    | `cargo build --release -p scx_chaos` |
| `scx_cosmos`   | `cargo build --release -p scx_cosmos` |
| `scx_flash`    | `cargo build --release -p scx_flash` |
| `scx_lavd`     | `cargo build --release -p scx_lavd` |
| `scx_layered`  | `cargo build --release -p scx_layered` |
| `scx_mitosis`  | `cargo build --release -p scx_mitosis` |
| `scx_p2dq`     | `cargo build --release -p scx_p2dq` |
| `scx_rlfifo`   | `cargo build --release -p scx_rlfifo` |
| `scx_rustland` | `cargo build --release -p scx_rustland` |
| `scx_rusty`    | `cargo build --release -p scx_rusty` |
| `scx_tickless` | `cargo build --release -p scx_tickless` |
| `scx_wd40`     | `cargo build --release -p scx_wd40` |

---

## 4. Building tools

Besides schedulers, the workspace includes several tools:

- **scxtop** – Monitoring tool:

  ```bash
  cargo build --release -p scxtop
  ```

- **scxcash** – Caching utility:

  ```bash
  cargo build --release -p scxcash
  ```

- **vmlinux_docify** – Kernel documentation generator:

  ```bash
  cargo build --release -p vmlinux_docify
  ```

---

## 5. Installing from crates.io

Some schedulers and tools may also be available directly from [crates.io](https://crates.io). This allows you to install them without cloning the repository.

### Examples

| Crate name   | Install command            |
|--------------|----------------------------|
| `scxtop`     | `cargo install scxtop`     |
| `scx_flash`  | `cargo install scx_flash`  |

This will place the binary in `~/.cargo/bin`, which you should add to your `PATH` if it is not already included.

> **Note**: Availability on crates.io depends on which components the maintainers publish there. Not all schedulers may be published.

### Installing system-wide

To make a scheduler or tool available system-wide, you can either:

1. Copy the installed binary from `~/.cargo/bin` into a system directory, e.g.:

   ```bash
   sudo cp ~/.cargo/bin/scxtop /usr/local/bin/
   ```

2. Or add `~/.cargo/bin` to your system `PATH`, for example by adding this line to `~/.bashrc` or `~/.zshrc`:

   ```bash
   export PATH="$HOME/.cargo/bin:$PATH"
   ```

---

## 6. Running tests

To verify the correctness of the build, you can run tests:

- For the entire workspace:

  ```bash
  cargo test
  ```

- For a specific scheduler:

  ```bash
  cargo test -p scx_flash
  ```

---

## 7. Dependency management

The workspace uses a shared `Cargo.lock` file.

- To prefetch dependencies for offline builds:

  ```bash
  cargo fetch --locked
  ```

- To update dependencies:

  ```bash
  cargo update
  ```

---

## 8. Cross-compilation

You can build for different targets, for example **musl**:

```bash
cargo build --release --target x86_64-unknown-linux-musl
```

Make sure the target is installed first:

```bash
rustup target add x86_64-unknown-linux-musl
```

### 8.1 Android NDK (`aarch64-linux-android`)

Build user-space schedulers (Rust + libbpf + BPF object produced at compile time) for **64-bit Android (arm64-v8a)** using the Rust triple **`aarch64-linux-android`** (Bionic).

**Runtime note:** Schedulers need a kernel with **sched_ext** enabled and compatible with the BPF in this tree. Stock phone/tablet images often do not ship sched_ext; this section only covers **cross-compiling** the binaries.

#### Prerequisites

1. **Android NDK** (r26 or newer recommended). Set `ANDROID_NDK_HOME` to the NDK root (the directory that contains `toolchains/llvm`).
2. **API level** (e.g. 24, 31, 34). NDK compiler wrappers look like `aarch64-linux-android<api>-clang` under `toolchains/llvm/prebuilt/<host>/bin/`.
3. Install the Rust target:

   ```bash
   rustup target add aarch64-linux-android
   ```

#### Why `BPF_CLANG` and `CC_*` matter

- **`build.rs`** in scheduler crates uses [`scx_cargo`](rust/scx_cargo), which runs `clang --version --target=$TARGET`. When `$TARGET` is `aarch64-linux-android`, a host `clang` that does not support that triple will fail immediately.
- Point **`BPF_CLANG`** at the NDK **LLVM `clang`** (same sysroot as your API level) so that probe succeeds.
- **`libbpf-sys`** compiles C libbpf during the build; set **`CC_aarch64_linux_android`** and **`AR_aarch64_linux_android`** to the NDK Clang / `llvm-ar` wrappers so that static lib links for Android.

Example (Linux host, API 34 — adjust paths and API to match your machine):

```bash
export ANDROID_NDK_HOME=/path/to/ndk
NDK_BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
export BPF_CLANG="$NDK_BIN/clang"
export CC_aarch64_linux_android="$NDK_BIN/aarch64-linux-android34-clang"
export AR_aarch64_linux_android="$NDK_BIN/llvm-ar"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$NDK_BIN/aarch64-linux-android34-clang"
```

Ensure the **linker** Cargo uses is also from the NDK (see [`.cargo/config.toml`](.cargo/config.toml) commented template), set **`CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER`** as above, or use **`cargo-ndk`**, which wires linker and compiler env for you:

```bash
cargo install cargo-ndk
cargo ndk -t arm64-v8a -p 34 -- build --release -p scx_lavd
```

(`cargo-ndk` sets API level and target; you may still need `BPF_CLANG` as above if the build script’s `clang --target=aarch64-linux-android` must resolve against the NDK.)

#### Suggested first build (single crate)

Start with one scheduler to reduce dependency surface before building the whole workspace:

```bash
./scripts/android/build_scx_lavd.sh --release -p scx_lavd --target aarch64-linux-android
```

#### libbpf / libelf (required for `libbpf-sys`)

With default `libbpf-rs` / `libbpf-sys` settings, the build **compiles** vendored libbpf C sources using `CC_aarch64_linux_android`. That requires **libelf** and **zlib** headers and **target** static (or shared) libraries. The Android NDK sysroot **does not** ship libelf.

- **Do not** enable `libbpf-rs` feature **`vendored`** for Android: vendored **elfutils** expects GNU **argp** and fails under Bionic (e.g. `configure: error: failed to find argp_parse`).
- Point the build at a **prefix** where you have cross-built or copied **libelf** + **zlib** for `aarch64-linux-android` (typical sources: **AOSP** `external/elfutils` / prebuilts, or a cross environment such as **dockcross**). Then set, for example:

  ```bash
  export SCX_ANDROID_LIBELF_PREFIX=/path/to/prefix   # contains include/ and lib/
  ./scripts/android/build_scx_lavd.sh --release -p scx_lavd --target aarch64-linux-android
  ```

  The helper script maps that to `LIBBPF_SYS_EXTRA_CFLAGS` and `LIBBPF_SYS_LIBRARY_PATH_aarch64_linux_android` (see [`libbpf-sys` README](https://crates.io/crates/libbpf-sys) for other `LIBBPF_SYS_*` knobs).

If linking fails with missing **zlib** only, add `-lz` via your prefix’s `libz` or adjust `LIBBPF_SYS_*` per the error output.

#### Alternative: Termux / glibc on device

If the environment is **glibc + Linux ABI** (e.g. some Termux setups), the triple is often **`aarch64-unknown-linux-gnu`** with a Linux cross toolchain (`aarch64-linux-gnu-gcc`), not the NDK. BPF is still built as `-target bpf` on the host; you do not need `clang` to understand the `linux-android` triple for that path.

---

## 9. Debugging

- Enable backtraces:

  ```bash
  sudo env RUST_BACKTRACE=1 ./target/debug/scx_flash
  ```

- Enable debug logging:

  ```bash
  sudo env RUST_LOG=debug ./target/debug/scx_flash
  ```

---

## 10. Cleaning up

To remove build artifacts and start fresh:

```bash
cargo clean
```

---

## 11. Summary

- **Build everything**: `cargo build --release`
- **Build one scheduler**: `cargo build --profile=<profile> -p <name>`
- **Install from crates.io**: `cargo install <crate_name>`
- **Make available system-wide**: copy binary to `/usr/local/bin` or add `~/.cargo/bin` to `PATH`
- **Run tests**: `cargo test`
- **Cross-compile**: `cargo build --target=<target>` (see §8.1 for **Android NDK / `aarch64-linux-android`**)
- **Profiles available**: `release`, `release-tiny`, `release-fast`

This approach allows you to build and test either the whole project at once or focus on a single scheduler or tool.
