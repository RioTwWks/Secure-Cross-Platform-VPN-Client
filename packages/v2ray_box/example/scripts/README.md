# Scripts Guide

This directory contains Android core build scripts for this package:

- `build_android_libxray.sh` -> builds `libxray.aar` from [XTLS/libXray](https://github.com/XTLS/libXray)
- `build_android_libsingbox.sh` -> builds `libsingbox.so` from [SagerNet/sing-box](https://github.com/SagerNet/sing-box)

## 1) build_android_libxray.sh (Android Only)

Build output:

- `android/app/libs/libxray.aar`

Usage:

```bash
sh scripts/build_android_libxray.sh
```

Common examples:

```bash
# Current Flutter project
sh scripts/build_android_libxray.sh

# Another Flutter project
sh scripts/build_android_libxray.sh \
  --project-root /path/to/your_app

# Use local libXray source
sh scripts/build_android_libxray.sh \
  --libxray-dir /path/to/libXray
```

Required tools:

- `git`
- `go`
- `python3`
- `curl`
- `jq`
- `unzip`
- `zip`

## 2) build_android_libsingbox.sh (Android Only)

Build output:

- `android/app/src/main/jniLibs/<abi>/libsingbox.so`

Notes:

- Default ABIs: `arm64-v8a,x86_64`
- 16 KB page-size check is enforced with `llvm-readobj` from Android NDK

Usage:

```bash
sh scripts/build_android_libsingbox.sh
```

Common examples:

```bash
# Current Flutter project
sh scripts/build_android_libsingbox.sh

# Another Flutter project
sh scripts/build_android_libsingbox.sh \
  --project-root /path/to/your_app

# Use local sing-box source
sh scripts/build_android_libsingbox.sh \
  --singbox-dir /path/to/sing-box

# Build only arm64
sh scripts/build_android_libsingbox.sh \
  --android-abis arm64-v8a
```

Required tools:

- `git`
- `go`
- `curl`
- `jq`
- Android NDK (with `clang` and `llvm-readobj`)
