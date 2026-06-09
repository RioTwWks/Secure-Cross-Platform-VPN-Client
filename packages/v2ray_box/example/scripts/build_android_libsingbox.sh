#!/usr/bin/env bash
set -euo pipefail

SINGBOX_REPO_URL="https://github.com/SagerNet/sing-box.git"
# Prefer latest stable release tag by default.
SINGBOX_REF="latest"
PROJECT_ROOT="$(pwd)"
SINGBOX_DIR=""
KEEP_SOURCE=false
TMP_DIR=""
WORK_DIR=""
ANDROID_ABIS="arm64-v8a,x86_64"
ANDROID_API=23
SINGBOX_TAGS="with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_tailscale,with_ccm,with_ocm,badlinkname,tfogo_checklinkname0"

usage() {
  cat <<'EOF'
Usage: build_android_libsingbox.sh [options]

Build Android libsingbox.so from SagerNet/sing-box source and place it in:
  android/app/src/main/jniLibs/<abi>/libsingbox.so

Options:
  --project-root <path>      Flutter app root (default: current directory)
  --singbox-dir <path>       Use an existing local sing-box directory
  --singbox-ref <ref|main|latest> sing-box git ref to use when auto-cloning (default: latest release tag)
  --singbox-repo <url>       sing-box git repo URL (default: https://github.com/SagerNet/sing-box.git)
  --android-abis <csv>       Build ABIs (default: arm64-v8a,x86_64)
  --android-api <level>      Android API level used by cross-compiler (default: 23)
  --tags <csv>               Build tags for sing-box (default: official release tags)
  --keep-source              Keep temporary cloned source (if auto-cloned)
  -h, --help                 Show this help

Examples:
  sh scripts/build_android_libsingbox.sh
  sh scripts/build_android_libsingbox.sh --project-root /path/to/flutter_app
  sh scripts/build_android_libsingbox.sh --singbox-dir /path/to/sing-box
  sh scripts/build_android_libsingbox.sh --android-abis arm64-v8a
EOF
}

log() { printf '[libsingbox-android] %s\n' "$*" >&2; }
err() { printf '[libsingbox-android] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || err "Missing required command: $cmd"
}

validate_abis() {
  local csv="$1"
  [[ -n "$csv" ]] || err "--android-abis cannot be empty"
  for abi in ${csv//,/ }; do
    case "$abi" in
      arm64-v8a|armeabi-v7a|x86|x86_64) ;;
      *)
        err "Invalid ABI in --android-abis: $abi (allowed: arm64-v8a,armeabi-v7a,x86,x86_64)"
        ;;
    esac
  done
}

resolve_latest_release_tag() {
  local tag
  tag="$(curl -fsSL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r '.tag_name // empty')" || true
  if [[ -n "$tag" && "$tag" != "null" ]]; then
    printf '%s\n' "$tag"
    return
  fi
  # Safe fallback if GitHub API is rate-limited.
  printf 'v1.12.22\n'
}

resolve_latest_ref() {
  # Keep "latest" pinned to stable releases for predictable runtime behavior.
  resolve_latest_release_tag
}

prepare_source_dir() {
  if [[ -n "$SINGBOX_DIR" ]]; then
    [[ -d "$SINGBOX_DIR" ]] || err "sing-box directory not found: $SINGBOX_DIR"
    [[ -f "$SINGBOX_DIR/go.mod" ]] || err "Invalid sing-box directory (missing go.mod): $SINGBOX_DIR"
    [[ -d "$SINGBOX_DIR/cmd/sing-box" ]] || err "Invalid sing-box directory (missing cmd/sing-box): $SINGBOX_DIR"
    printf '%s\n' "$SINGBOX_DIR"
    return
  fi

  TMP_DIR="$(mktemp -d)"
  local source_dir="$TMP_DIR/sing-box"
  local ref_to_use="$SINGBOX_REF"
  if [[ "$ref_to_use" == "latest" ]]; then
    ref_to_use="$(resolve_latest_ref)"
  fi
  log "Cloning sing-box ($ref_to_use) from $SINGBOX_REPO_URL ..."
  if ! git clone --depth 1 --branch "$ref_to_use" "$SINGBOX_REPO_URL" "$source_dir" >/dev/null 2>&1; then
    log "Branch/tag clone failed for ref '$ref_to_use'; trying default clone + checkout..."
    git clone --depth 1 "$SINGBOX_REPO_URL" "$source_dir" >/dev/null
    (
      cd "$source_dir"
      git fetch --depth 1 origin "$ref_to_use" >/dev/null 2>&1 || true
      git checkout "$ref_to_use" >/dev/null
    )
  fi
  printf '%s\n' "$source_dir"
}

detect_ndk_bin_dir() {
  local host_os
  host_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  local -a host_tags=()
  case "$host_os" in
    darwin)
      host_tags=("darwin-arm64" "darwin-x86_64")
      ;;
    linux)
      host_tags=("linux-x86_64")
      ;;
    *)
      err "Unsupported host OS for Android NDK detection: $host_os"
      ;;
  esac

  local -a candidates=()
  [[ -n "${ANDROID_NDK_HOME:-}" ]] && candidates+=("$ANDROID_NDK_HOME")
  [[ -n "${ANDROID_NDK_ROOT:-}" ]] && candidates+=("$ANDROID_NDK_ROOT")
  [[ -n "${NDK:-}" ]] && candidates+=("$NDK")
  [[ -n "${ANDROID_SDK_ROOT:-}" ]] && [[ -d "${ANDROID_SDK_ROOT}/ndk" ]] && candidates+=("${ANDROID_SDK_ROOT}/ndk"/*)
  [[ -n "${ANDROID_HOME:-}" ]] && [[ -d "${ANDROID_HOME}/ndk" ]] && candidates+=("${ANDROID_HOME}/ndk"/*)
  [[ -d "$HOME/Library/Android/sdk/ndk" ]] && candidates+=("$HOME/Library/Android/sdk/ndk"/*)
  [[ -d "$HOME/Android/Sdk/ndk" ]] && candidates+=("$HOME/Android/Sdk/ndk"/*)

  local c
  for c in "${candidates[@]}"; do
    [[ -d "$c" ]] || continue
    local tag
    for tag in "${host_tags[@]}"; do
      local bin_dir="$c/toolchains/llvm/prebuilt/$tag/bin"
      if [[ -x "$bin_dir/clang" ]]; then
        printf '%s\n' "$bin_dir"
        return
      fi
    done
  done

  err "Android NDK not found. Set ANDROID_NDK_HOME or install NDK in Android SDK."
}

map_abi_to_toolchain() {
  local abi="$1"
  local var_arch="$2"
  local var_cc_prefix="$3"
  local var_goarm="$4"
  case "$abi" in
    arm64-v8a)
      printf -v "$var_arch" "arm64"
      printf -v "$var_cc_prefix" "aarch64-linux-android"
      printf -v "$var_goarm" ""
      ;;
    armeabi-v7a)
      printf -v "$var_arch" "arm"
      printf -v "$var_cc_prefix" "armv7a-linux-androideabi"
      printf -v "$var_goarm" "7"
      ;;
    x86)
      printf -v "$var_arch" "386"
      printf -v "$var_cc_prefix" "i686-linux-android"
      printf -v "$var_goarm" ""
      ;;
    x86_64)
      printf -v "$var_arch" "amd64"
      printf -v "$var_cc_prefix" "x86_64-linux-android"
      printf -v "$var_goarm" ""
      ;;
    *)
      err "Unsupported ABI mapping: $abi"
      ;;
  esac
}

build_binary_for_abi() {
  local source_dir="$1"
  local ndk_bin_dir="$2"
  local abi="$3"
  local version="$4"

  local goarch cc_prefix goarm
  map_abi_to_toolchain "$abi" goarch cc_prefix goarm

  local cc="$ndk_bin_dir/${cc_prefix}${ANDROID_API}-clang"
  local cxx="$ndk_bin_dir/${cc_prefix}${ANDROID_API}-clang++"
  [[ -x "$cc" ]] || err "NDK compiler not found for ABI $abi: $cc"
  [[ -x "$cxx" ]] || err "NDK C++ compiler not found for ABI $abi: $cxx"

  local out_so="$WORK_DIR/jni/$abi/libsingbox.so"
  mkdir -p "$(dirname "$out_so")"

  local ldflags="-X github.com/sagernet/sing-box/constant.Version=${version} -X internal/godebug.defaultGODEBUG=multipathtcp=0 -s -w -buildid= -checklinkname=0 -linkmode external -extldflags=-Wl,-z,max-page-size=16384"

  log "Building ABI $abi ..."
  (
    cd "$source_dir"
    if [[ -n "$goarm" ]]; then
      env CGO_ENABLED=1 GOOS=android GOARCH="$goarch" GOARM="$goarm" CC="$cc" CXX="$cxx" \
        go build -v -trimpath -buildvcs=false -tags "$SINGBOX_TAGS" -ldflags "$ldflags" -o "$out_so" ./cmd/sing-box
    else
      env CGO_ENABLED=1 GOOS=android GOARCH="$goarch" CC="$cc" CXX="$cxx" \
        go build -v -trimpath -buildvcs=false -tags "$SINGBOX_TAGS" -ldflags "$ldflags" -o "$out_so" ./cmd/sing-box
    fi
  )

  [[ -f "$out_so" ]] || err "Build did not produce output for ABI $abi"
  chmod +x "$out_so" || true
}

resolve_singbox_version_marker() {
  local source_dir="$1"
  local version=""

  version="$(cd "$source_dir" && (git describe --tags --always 2>/dev/null || git rev-parse --short HEAD))"

  if [[ "$version" =~ (v?[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)*) ]]; then
    version="${BASH_REMATCH[1]}"
  elif [[ "$version" =~ ^[0-9a-f]{7,40}$ ]]; then
    version="$(resolve_latest_release_tag)"
  elif [[ "$SINGBOX_REF" != "main" && "$SINGBOX_REF" != "latest" ]]; then
    version="$SINGBOX_REF"
  else
    version="$(resolve_latest_release_tag)"
  fi

  version="${version#refs/tags/}"
  version="${version#tag/}"
  version="${version%%-*g[0-9a-fA-F]*}"

  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    version="v$version"
  fi
  if [[ ! "$version" =~ ^v ]]; then
    version="v${version}"
  fi
  printf '%s\n' "$version"
}

check_16kb_alignment() {
  local ndk_bin_dir="$1"
  local readobj="$ndk_bin_dir/llvm-readobj"
  if [[ ! -x "$readobj" ]]; then
    log "llvm-readobj not found in NDK; skipped 16KB alignment check."
    return
  fi

  local abi
  for abi in ${ANDROID_ABIS//,/ }; do
    local so="$WORK_DIR/jni/$abi/libsingbox.so"
    [[ -f "$so" ]] || err "Missing built output for ABI $abi before 16KB check"
    local min_align
    min_align="$("$readobj" --program-headers "$so" | awk '
      /Type: PT_LOAD/ {inload=1; next}
      inload && /Alignment:/ {print $2; inload=0}
    ' | sort -n | head -n1)"
    [[ -n "$min_align" ]] || err "16KB check failed: cannot parse PT_LOAD alignment for ABI $abi"
    log "ABI $abi min PT_LOAD alignment: $min_align"
    if [[ "$min_align" -lt 16384 ]]; then
      err "16KB check failed for ABI $abi (alignment=$min_align)."
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      [[ $# -ge 2 ]] || err "Missing value for --project-root"
      PROJECT_ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    --singbox-dir)
      [[ $# -ge 2 ]] || err "Missing value for --singbox-dir"
      SINGBOX_DIR="$(cd "$2" && pwd)"
      shift 2
      ;;
    --singbox-ref)
      [[ $# -ge 2 ]] || err "Missing value for --singbox-ref"
      SINGBOX_REF="$2"
      shift 2
      ;;
    --singbox-repo)
      [[ $# -ge 2 ]] || err "Missing value for --singbox-repo"
      SINGBOX_REPO_URL="$2"
      shift 2
      ;;
    --android-abis)
      [[ $# -ge 2 ]] || err "Missing value for --android-abis"
      ANDROID_ABIS="${2// /}"
      shift 2
      ;;
    --android-api)
      [[ $# -ge 2 ]] || err "Missing value for --android-api"
      ANDROID_API="$2"
      shift 2
      ;;
    --tags)
      [[ $# -ge 2 ]] || err "Missing value for --tags"
      SINGBOX_TAGS="${2// /}"
      shift 2
      ;;
    --keep-source)
      KEEP_SOURCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      ;;
  esac
done

trap 'if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" && "$KEEP_SOURCE" != "true" ]]; then rm -rf "$TMP_DIR"; fi; if [[ -n "${WORK_DIR:-}" && -d "${WORK_DIR:-}" ]]; then rm -rf "$WORK_DIR"; fi' EXIT

require_cmd git
require_cmd go
require_cmd curl
require_cmd jq
require_cmd awk
require_cmd sort

[[ -f "$PROJECT_ROOT/pubspec.yaml" ]] || err "pubspec.yaml not found at project root: $PROJECT_ROOT"
validate_abis "$ANDROID_ABIS"
[[ "$ANDROID_API" =~ ^[0-9]+$ ]] || err "--android-api must be a number"

SOURCE_DIR="$(prepare_source_dir)"
WORK_DIR="$(mktemp -d)"
OUT_DIR="$PROJECT_ROOT/android/app/src/main/jniLibs"
mkdir -p "$OUT_DIR"

NDK_BIN_DIR="$(detect_ndk_bin_dir)"

SINGBOX_VERSION="$(resolve_singbox_version_marker "$SOURCE_DIR")"
log "Using sing-box version marker: $SINGBOX_VERSION"

log "Downloading Go module dependencies (once)..."
(
  cd "$SOURCE_DIR"
  go mod download
)

for abi in ${ANDROID_ABIS//,/ }; do
  build_binary_for_abi "$SOURCE_DIR" "$NDK_BIN_DIR" "$abi" "$SINGBOX_VERSION"
done

check_16kb_alignment "$NDK_BIN_DIR"

for abi in ${ANDROID_ABIS//,/ }; do
  dst_dir="$OUT_DIR/$abi"
  mkdir -p "$dst_dir"
  rm -f "$dst_dir/libsingbox.so"
  cp -f "$WORK_DIR/jni/$abi/libsingbox.so" "$dst_dir/libsingbox.so"
  chmod +x "$dst_dir/libsingbox.so" || true
  log "Saved: ${OUT_DIR#$PROJECT_ROOT/}/$abi/libsingbox.so"
done

# Remove stale AAR if present (this script now outputs .so only).
rm -f "$PROJECT_ROOT/android/app/libs/libsingbox.aar"

log "Done."
