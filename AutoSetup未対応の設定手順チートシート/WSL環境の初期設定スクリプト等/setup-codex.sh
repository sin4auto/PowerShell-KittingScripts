#!/usr/bin/env bash
set -euo pipefail

echo "==> Codex setup started"

#---- nvm環境を読み込む ----#
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1090
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

#---- Codex CLI ----#
echo "==> Install Codex CLI (global)"
npm install -g @openai/codex || {
  echo "WARN: Failed to install @openai/codex via npm. You can retry later: npm install -g @openai/codex" >&2
}

echo "==> Done. Please open VSCode with Remote-WSL and run 'codex' in the WSL terminal."
echo "If the 'codex' command is not found, try restarting your terminal or run 'source ~/.bashrc'."