#!/usr/bin/env bash
set -euo pipefail

LIBXRAY_REPO_URL="https://github.com/XTLS/libXray.git"
# Prefer the libXray default development branch so xray-core updates in libXray
# commits (for example v26.2.6) are picked up immediately.
LIBXRAY_REF="main"
PROJECT_ROOT="$(pwd)"
LIBXRAY_DIR=""
KEEP_SOURCE=false
TMP_DIR=""
WORK_DIR=""
ANDROID_ABIS="arm64-v8a,x86_64"

usage() {
  cat <<'EOF'
Usage: build_android_libxray.sh [options]

Build Android libxray.aar from XTLS/libXray and place it in:
  android/app/libs/libxray.aar

Options:
  --project-root <path>      Flutter app root (default: current directory)
  --libxray-dir <path>       Use an existing local libXray directory
  --libxray-ref <ref|main|latest> libXray git ref to use when auto-cloning (default: main)
  --libxray-repo <url>       libXray git repo URL (default: https://github.com/XTLS/libXray.git)
  --android-abis <csv>       Keep ABIs in final AAR (default: arm64-v8a,x86_64)
  --keep-source              Keep temporary cloned source (if auto-cloned)
  -h, --help                 Show this help

Examples:
  sh scripts/build_android_libxray.sh
  sh scripts/build_android_libxray.sh --project-root /path/to/flutter_app
  sh scripts/build_android_libxray.sh --libxray-dir /path/to/libXray
  sh scripts/build_android_libxray.sh --libxray-ref v1.8.24
  sh scripts/build_android_libxray.sh --android-abis arm64-v8a
EOF
}

log() { printf '[libxray-android] %s\n' "$*" >&2; }
err() { printf '[libxray-android] ERROR: %s\n' "$*" >&2; exit 1; }

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

resolve_latest_ref() {
  # "latest" here means latest development head (default branch), not latest release.
  local branch
  branch="$(curl -fsSL "https://api.github.com/repos/XTLS/libXray" | jq -r '.default_branch // empty')" || true
  if [[ -n "$branch" && "$branch" != "null" ]]; then
    printf '%s\n' "$branch"
    return
  fi

  printf 'main\n'
}

prepare_source_dir() {
  if [[ -n "$LIBXRAY_DIR" ]]; then
    [[ -d "$LIBXRAY_DIR" ]] || err "libXray directory not found: $LIBXRAY_DIR"
    [[ -f "$LIBXRAY_DIR/build/main.py" ]] || err "Invalid libXray directory (missing build/main.py): $LIBXRAY_DIR"
    printf '%s\n' "$LIBXRAY_DIR"
    return
  fi

  TMP_DIR="$(mktemp -d)"
  local source_dir="$TMP_DIR/libXray"
  local ref_to_use="$LIBXRAY_REF"
  if [[ "$ref_to_use" == "latest" ]]; then
    ref_to_use="$(resolve_latest_ref)"
  fi
  log "Cloning libXray ($ref_to_use) from $LIBXRAY_REPO_URL ..."
  if ! git clone --depth 1 --branch "$ref_to_use" "$LIBXRAY_REPO_URL" "$source_dir" >/dev/null 2>&1; then
    log "Branch/tag clone failed for ref '$ref_to_use'; trying default clone + checkout..."
    git clone --depth 1 "$LIBXRAY_REPO_URL" "$source_dir" >/dev/null
    (
      cd "$source_dir"
      git fetch --depth 1 origin "$ref_to_use" >/dev/null 2>&1 || true
      git checkout "$ref_to_use" >/dev/null
    )
  fi
  printf '%s\n' "$source_dir"
}

ensure_android_compat_patch() {
  local source_dir="$1"
  local patch_file="$source_dir/android_compat_wrapper.go"
  cat >"$patch_file" <<'EOF'
package libXray

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/xtls/libxray/nodep"
	corenet "github.com/xtls/xray-core/common/net"
	"github.com/xtls/xray-core/common/platform"
	"github.com/xtls/xray-core/core"
)

// SetTunFd updates xray.tun.fd inside Go runtime env map.
// This is required for gomobile callers that cannot reliably mutate Go env via Java setenv.
func SetTunFd(fd int) {
	if fd < 0 {
		fd = 0
	}
	value := strconv.Itoa(fd)
	_ = os.Setenv(platform.TunFdKey, value)
	_ = os.Setenv(platform.NormalizeEnvName(platform.TunFdKey), value)
}

// MeasureOutboundDelay uses core.Dial (v2rayNG style real ping) instead of local SOCKS ping.
// Returns base64 encoded CallResponse just like other libXray wrapper APIs.
func MeasureOutboundDelay(configJSON string, url string, timeoutSec int64) string {
	var response nodep.CallResponse[int64]

	if strings.TrimSpace(configJSON) == "" {
		return response.EncodeToBase64(nodep.PingDelayError, fmt.Errorf("empty config JSON"))
	}

	if strings.TrimSpace(url) == "" {
		url = "https://www.gstatic.com/generate_204"
	}

	if timeoutSec <= 0 {
		timeoutSec = 7
	}
	if timeoutSec > 60 {
		timeoutSec = 60
	}

	inst, err := core.StartInstance("json", []byte(configJSON))
	if err != nil {
		return response.EncodeToBase64(nodep.PingDelayError, err)
	}
	defer inst.Close()

	delay, err := measureDelayByCoreDial(inst, url, time.Duration(timeoutSec)*time.Second)
	return response.EncodeToBase64(delay, err)
}

func measureDelayByCoreDial(inst *core.Instance, url string, timeout time.Duration) (int64, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	tr := &http.Transport{
		TLSHandshakeTimeout: timeout / 2,
		DisableKeepAlives:   false,
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			dest, err := corenet.ParseDestination(fmt.Sprintf("%s:%s", network, addr))
			if err != nil {
				return nil, err
			}
			return core.Dial(ctx, inst, dest)
		},
	}

	client := &http.Client{
		Transport: tr,
		Timeout:   timeout,
	}

	var minDuration int64 = -1
	success := false
	var lastErr error
	const attempts = 2

	for i := 0; i < attempts; i++ {
		if err := ctx.Err(); err != nil {
			if success {
				return minDuration, nil
			}
			return nodep.PingDelayTimeout, err
		}

		req, reqErr := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if reqErr != nil {
			lastErr = reqErr
			continue
		}

		start := time.Now()
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			continue
		}

		if resp != nil && resp.Body != nil {
			_, _ = io.Copy(io.Discard, resp.Body)
			_ = resp.Body.Close()
		}

		if resp == nil || (resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent) {
			if resp != nil {
				lastErr = fmt.Errorf("invalid status: %s", resp.Status)
			} else {
				lastErr = fmt.Errorf("empty response")
			}
			continue
		}

		duration := time.Since(start).Milliseconds()
		if !success || duration < minDuration {
			minDuration = duration
		}
		success = true
	}

	if success {
		return minDuration, nil
	}
	if lastErr != nil {
		if errors.Is(lastErr, context.DeadlineExceeded) || errors.Is(lastErr, context.Canceled) {
			return nodep.PingDelayTimeout, lastErr
		}
		return nodep.PingDelayError, lastErr
	}
	return nodep.PingDelayError, fmt.Errorf("delay test failed")
}
EOF
  log "Injected Android compatibility APIs into libXray source: ${patch_file}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      [[ $# -ge 2 ]] || err "Missing value for --project-root"
      PROJECT_ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    --libxray-dir)
      [[ $# -ge 2 ]] || err "Missing value for --libxray-dir"
      LIBXRAY_DIR="$(cd "$2" && pwd)"
      shift 2
      ;;
    --libxray-ref)
      [[ $# -ge 2 ]] || err "Missing value for --libxray-ref"
      LIBXRAY_REF="$2"
      shift 2
      ;;
    --libxray-repo)
      [[ $# -ge 2 ]] || err "Missing value for --libxray-repo"
      LIBXRAY_REPO_URL="$2"
      shift 2
      ;;
    --android-abis)
      [[ $# -ge 2 ]] || err "Missing value for --android-abis"
      ANDROID_ABIS="${2// /}"
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
require_cmd python3
require_cmd curl
require_cmd jq
require_cmd unzip
require_cmd zip

[[ -f "$PROJECT_ROOT/pubspec.yaml" ]] || err "pubspec.yaml not found at project root: $PROJECT_ROOT"
validate_abis "$ANDROID_ABIS"

SOURCE_DIR="$(prepare_source_dir)"
ensure_android_compat_patch "$SOURCE_DIR"
OUT_DIR="$PROJECT_ROOT/android/app/libs"
OUT_FILE="$OUT_DIR/libxray.aar"
WORK_DIR="$(mktemp -d)"

mkdir -p "$OUT_DIR"

export PATH="$(go env GOPATH)/bin:$PATH"

log "Building Android AAR from: $SOURCE_DIR"
(
  cd "$SOURCE_DIR"
  python3 build/main.py android
)

[[ -f "$SOURCE_DIR/libXray.aar" ]] || err "Build succeeded but libXray.aar was not found in $SOURCE_DIR"

# Filter ABIs in output AAR to avoid shipping non-16KB-safe 32-bit libs by default.
cp -f "$SOURCE_DIR/libXray.aar" "$WORK_DIR/libXray.aar"
unzip -o -q "$WORK_DIR/libXray.aar" -d "$WORK_DIR/aar"

if [[ -d "$WORK_DIR/aar/jni" ]]; then
  for dir in "$WORK_DIR/aar/jni"/*; do
    [[ -d "$dir" ]] || continue
    abi="$(basename "$dir")"
    if [[ ",$ANDROID_ABIS," != *",$abi,"* ]]; then
      rm -rf "$dir"
    fi
  done
fi

for abi in ${ANDROID_ABIS//,/ }; do
  [[ -f "$WORK_DIR/aar/jni/$abi/libgojni.so" ]] || err "Expected ABI output missing in built AAR: $abi"
done

# 16KB page-size safety check (PT_LOAD alignment must be >= 16384 for kept ABIs).
READOBJ=""
for ndk in \
  "$HOME/Library/Android/sdk/ndk/29.0.14206865" \
  "$HOME/Library/Android/sdk/ndk/28.2.13676358" \
  "$HOME/Library/Android/sdk/ndk/28.0.12433566" \
  "$HOME/Library/Android/sdk/ndk/27.0.12077973" \
  "$HOME/Library/Android/sdk/ndk/26.1.10909125"; do
  cand="$ndk/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readobj"
  if [[ -x "$cand" ]]; then
    READOBJ="$cand"
    break
  fi
done

if [[ -n "$READOBJ" ]]; then
  for abi in ${ANDROID_ABIS//,/ }; do
    so="$WORK_DIR/aar/jni/$abi/libgojni.so"
    min_align="$("$READOBJ" --program-headers "$so" | awk '
      /Type: PT_LOAD/ {inload=1; next}
      inload && /Alignment:/ {print $2; inload=0}
    ' | sort -n | head -n1)"
    [[ -n "$min_align" ]] || err "16KB check failed: cannot parse PT_LOAD alignment for ABI $abi"
    log "ABI $abi min PT_LOAD alignment: $min_align"
    if [[ "$min_align" -lt 16384 ]]; then
      err "16KB check failed for ABI $abi (alignment=$min_align). Use only 64-bit ABIs or update toolchain."
    fi
  done
else
  log "llvm-readobj not found; skipped 16KB alignment check."
fi

(
  cd "$WORK_DIR/aar"
  zip -qr "$WORK_DIR/libxray.aar" .
)

rm -f "$OUT_FILE"
cp -f "$WORK_DIR/libxray.aar" "$OUT_FILE"

log "Saved: ${OUT_FILE#$PROJECT_ROOT/}"
log "Done."
