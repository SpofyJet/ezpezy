#!/bin/bash
# ============================================
#  Selfsteal Installer — точка входа
#  Вся логика в setup-fakesite.sh (одна копия вместо двух разошедшихся).
#  Прежний install.sh вешал Caddy на TCP 443 (конфликт с Xray REALITY) и с HTTP/3 —
#  на UDP 443 (конфликт с Hysteria2). Теперь: fakesite только на 127.0.0.1 / unix-сокете.
#
#  bash <(curl -Ls https://raw.githubusercontent.com/SpofyJet/ezpezy/main/install.sh)
# ============================================
set -e
REPO_RAW="${SELFSTEAL_REPO_RAW:-https://raw.githubusercontent.com/SpofyJet/ezpezy/main}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

if [[ -n "$HERE" && -f "$HERE/setup-fakesite.sh" ]]; then
    exec bash "$HERE/setup-fakesite.sh" "${@:-install}"
fi
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
curl -fsSL "$REPO_RAW/setup-fakesite.sh" -o "$tmp" || { echo "Не удалось скачать setup-fakesite.sh" >&2; exit 1; }
bash -n "$tmp" || { echo "Скачанный setup-fakesite.sh повреждён" >&2; exit 1; }
bash "$tmp" "${@:-install}"
