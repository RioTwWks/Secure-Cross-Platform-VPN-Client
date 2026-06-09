#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORK_DIR="${ROOT_DIR}/packages/v2ray_box"

if [[ ! -d "${FORK_DIR}/.git" ]]; then
  echo "Fork not found at ${FORK_DIR}"
  exit 1
fi

cd "${FORK_DIR}"

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/pesaregorg/v2ray_box.git
fi

git fetch upstream
CURRENT_BRANCH="$(git branch --show-current)"
git rebase "upstream/${CURRENT_BRANCH}"

cd "${ROOT_DIR}/secure_vpn_client"
flutter pub get
flutter test

echo "Rebase complete. Tag with: secure-vpn-<version>+<patch>"
