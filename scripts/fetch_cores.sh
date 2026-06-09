#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${ROOT_DIR}/secure_vpn_client/assets/binaries"

# Override with env vars, e.g. XRAY_VERSION=26.3.27 SINGBOX_VERSION=1.13.13
XRAY_VERSION="${XRAY_VERSION:-}"
SINGBOX_VERSION="${SINGBOX_VERSION:-}"

mkdir -p "${DEST}"/{android/arm64-v8a,android/armeabi-v7a,ios,windows/x64,linux/x64,macos}

fetch_latest_tag() {
  local repo="$1"
  local tag
  tag="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))")"
  echo "${tag}"
}

resolve_asset_url() {
  local repo="$1"
  local version="$2"
  local pattern="$3"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/v${version}" \
    | python3 -c "
import json, re, sys
release = json.load(sys.stdin)
pattern = re.compile(sys.argv[1])
for asset in release.get('assets', []):
    name = asset['name']
    if pattern.search(name) and not name.endswith('.dgst'):
        print(asset['browser_download_url'])
        break
" "${pattern}"
}

download_and_extract() {
  local url="$1"
  local output_dir="$2"
  local binary_name="$3"
  local optional="${4:-false}"
  local tmp
  tmp="$(mktemp -d)"

  if [[ -z "${url}" ]]; then
    if [[ "${optional}" == "true" ]]; then
      echo "  skip (asset not found, optional): ${binary_name}"
      return 0
    fi
    echo "Asset URL not found for ${binary_name}"
    exit 1
  fi

  echo "  -> ${url}"
  if ! curl -fsSL "${url}" -o "${tmp}/archive"; then
    if [[ "${optional}" == "true" ]]; then
      echo "  skip (download failed, optional): ${binary_name}"
      rm -rf "${tmp}"
      return 0
    fi
    echo "Download failed: ${url}"
    exit 1
  fi

  mkdir -p "${tmp}/extracted"
  case "${url}" in
    *.tar.gz)
      tar -xzf "${tmp}/archive" -C "${tmp}/extracted"
      ;;
    *.zip)
      unzip -qo "${tmp}/archive" -d "${tmp}/extracted"
      ;;
    *)
      echo "Unsupported archive type: ${url}"
      exit 1
      ;;
  esac

  local found
  found="$(find "${tmp}/extracted" -type f -name "${binary_name}" | head -n 1)"
  if [[ -z "${found}" ]]; then
    if [[ "${optional}" == "true" ]]; then
      echo "  skip (binary not in archive, optional): ${binary_name}"
      rm -rf "${tmp}"
      return 0
    fi
    echo "Binary ${binary_name} not found in ${url}"
    exit 1
  fi

  cp "${found}" "${output_dir}/${binary_name}"
  chmod +x "${output_dir}/${binary_name}" || true
  rm -rf "${tmp}"
}

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -f "${src}" ]]; then
    mkdir -p "$(dirname "${dst}")"
    cp "${src}" "${dst}"
    chmod +x "${dst}" || true
  fi
}

if [[ -z "${XRAY_VERSION}" ]]; then
  XRAY_VERSION="$(fetch_latest_tag "XTLS/Xray-core")"
fi
if [[ -z "${SINGBOX_VERSION}" ]]; then
  SINGBOX_VERSION="$(fetch_latest_tag "SagerNet/sing-box")"
fi

echo "Fetching Xray-core v${XRAY_VERSION}..."
download_and_extract \
  "$(resolve_asset_url "XTLS/Xray-core" "${XRAY_VERSION}" '^Xray-linux-64\.zip$')" \
  "${DEST}/linux/x64" "xray"
download_and_extract \
  "$(resolve_asset_url "XTLS/Xray-core" "${XRAY_VERSION}" '^Xray-windows-64\.zip$')" \
  "${DEST}/windows/x64" "xray.exe"
download_and_extract \
  "$(resolve_asset_url "XTLS/Xray-core" "${XRAY_VERSION}" '^Xray-macos-64\.zip$')" \
  "${DEST}/macos" "xray"
download_and_extract \
  "$(resolve_asset_url "XTLS/Xray-core" "${XRAY_VERSION}" '^Xray-android-arm64-v8a\.zip$')" \
  "${DEST}/android/arm64-v8a" "xray"
# 32-bit Android package is not published for all Xray releases.
download_and_extract \
  "$(resolve_asset_url "XTLS/Xray-core" "${XRAY_VERSION}" '^Xray-android-arm32-v7a\.zip$')" \
  "${DEST}/android/armeabi-v7a" "xray" "true"

echo "Fetching sing-box v${SINGBOX_VERSION}..."
download_and_extract \
  "$(resolve_asset_url "SagerNet/sing-box" "${SINGBOX_VERSION}" "^sing-box-${SINGBOX_VERSION}-linux-amd64\\.tar\\.gz\$")" \
  "${DEST}/linux/x64" "sing-box"
download_and_extract \
  "$(resolve_asset_url "SagerNet/sing-box" "${SINGBOX_VERSION}" "^sing-box-${SINGBOX_VERSION}-windows-amd64\\.zip\$")" \
  "${DEST}/windows/x64" "sing-box.exe"
download_and_extract \
  "$(resolve_asset_url "SagerNet/sing-box" "${SINGBOX_VERSION}" "^sing-box-${SINGBOX_VERSION}-darwin-amd64\\.tar\\.gz\$")" \
  "${DEST}/macos" "sing-box"
download_and_extract \
  "$(resolve_asset_url "SagerNet/sing-box" "${SINGBOX_VERSION}" "^sing-box-${SINGBOX_VERSION}-android-arm64\\.tar\\.gz\$")" \
  "${DEST}/android/arm64-v8a" "sing-box"
download_and_extract \
  "$(resolve_asset_url "SagerNet/sing-box" "${SINGBOX_VERSION}" "^sing-box-${SINGBOX_VERSION}-android-arm\\.tar\\.gz\$")" \
  "${DEST}/android/armeabi-v7a" "sing-box" "true"

LINUX_RES="${ROOT_DIR}/secure_vpn_client/linux/runner/resources"
WINDOWS_RES="${ROOT_DIR}/secure_vpn_client/windows/runner/resources"
MACOS_RES="${ROOT_DIR}/secure_vpn_client/macos/Runner/Resources"

copy_if_exists "${DEST}/linux/x64/xray" "${LINUX_RES}/xray"
copy_if_exists "${DEST}/linux/x64/sing-box" "${LINUX_RES}/sing-box"
copy_if_exists "${DEST}/windows/x64/xray.exe" "${WINDOWS_RES}/xray.exe"
copy_if_exists "${DEST}/windows/x64/sing-box.exe" "${WINDOWS_RES}/sing-box.exe"
copy_if_exists "${DEST}/macos/xray" "${MACOS_RES}/xray"
copy_if_exists "${DEST}/macos/sing-box" "${MACOS_RES}/sing-box"

GEO_BASE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download"
GEO_DEST="${DEST}/geo"
mkdir -p "${GEO_DEST}"

echo "Fetching Xray geo assets..."
curl -fsSL "${GEO_BASE_URL}/geoip.dat" -o "${GEO_DEST}/geoip.dat"
curl -fsSL "${GEO_BASE_URL}/geosite.dat" -o "${GEO_DEST}/geosite.dat"

copy_if_exists "${GEO_DEST}/geoip.dat" "${LINUX_RES}/geoip.dat"
copy_if_exists "${GEO_DEST}/geosite.dat" "${LINUX_RES}/geosite.dat"
copy_if_exists "${GEO_DEST}/geoip.dat" "${WINDOWS_RES}/geoip.dat"
copy_if_exists "${GEO_DEST}/geosite.dat" "${WINDOWS_RES}/geosite.dat"
copy_if_exists "${GEO_DEST}/geoip.dat" "${MACOS_RES}/geoip.dat"
copy_if_exists "${GEO_DEST}/geosite.dat" "${MACOS_RES}/geosite.dat"

echo "Core binaries downloaded to ${DEST}"
echo "Versions: Xray v${XRAY_VERSION}, sing-box v${SINGBOX_VERSION}"
