#!/usr/bin/env bash
# WSL Ubuntu に Codex CLI（npm のグローバルパッケージ）を入れる。再実行すると最新版に更新される。
# 前提: setup-wsl.sh で nvm と Node.js を入れてあること。
# 使い方: bash setup-codex.sh   または   curl -fsSL <raw URL> | bash
set -euo pipefail

export NVM_DIR="$HOME/.nvm"

#---- 共通ヘルパー（curl | bash で単体実行するため、各スクリプトに同じものを持つ）----#
log()  { printf '==> %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

#---- 各セットアップ ----#
load_nvm() {
  # curl | bash は ~/.bashrc を読まないので、nvm を自分で読み込んで npm を使えるようにする
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
  fi
  has npm || die "npm was not found. Run setup-wsl.sh first to install nvm and Node.js."
}

install_codex() {
  log "Install Codex CLI (global)"
  npm install -g @openai/codex \
    || die "Failed to install @openai/codex via npm. You can retry later: npm install -g @openai/codex"
}

# 処理はすべて main から呼ぶ。curl | bash の途中でダウンロードが切れても、中途半端に実行されないようにするため
main() {
  log "Codex setup started"
  load_nvm
  install_codex
  log "Done. Please open VSCode with Remote-WSL and run 'codex' in the WSL terminal."
  echo "If the 'codex' command is not found, try restarting your terminal or run 'source ~/.bashrc'."
}

main "$@"
