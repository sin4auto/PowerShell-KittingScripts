#!/usr/bin/env bash
set -euo pipefail

CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
LOCAL_BIN="$HOME/.local/bin"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

echo "==> Claude Code setup started"

#---- Claude Code（ネイティブインストーラー）----#
# Node.js は不要。インストール後はバックグラウンドで自動更新される
if command -v claude >/dev/null 2>&1; then
  echo "==> Claude Code is already installed: $(claude --version)"
  echo "    (Native installs auto-update. To update manually, run 'claude update'.)"
else
  echo "==> Install Claude Code (native installer)"
  curl -fsSL "$CLAUDE_INSTALL_URL" | bash || {
    echo "WARN: Failed to install Claude Code. You can retry later: curl -fsSL $CLAUDE_INSTALL_URL | bash" >&2
    exit 1
  }
fi

#---- PATH（~/.local/bin）----#
# インストーラーは ~/.local/bin/claude を作る。PATH に無ければ ~/.bashrc に1回だけ追記する
if ! grep -qsF "$PATH_LINE" "$HOME/.bashrc"; then
  echo "==> Add ~/.local/bin to PATH in ~/.bashrc"
  printf '\n%s\n' "$PATH_LINE" >> "$HOME/.bashrc"
fi
export PATH="$LOCAL_BIN:$PATH"

#---- 確認 ----#
if command -v claude >/dev/null 2>&1; then
  echo "==> Installed: $(claude --version)"
else
  echo "WARN: 'claude' command not found. Restart your terminal or run 'source ~/.bashrc'." >&2
fi

echo "==> Done. Run 'claude' in the WSL terminal (not PowerShell/CMD) to sign in and start."
echo "For a detailed check, run 'claude doctor'."
