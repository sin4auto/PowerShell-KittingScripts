#!/usr/bin/env bash
# WSL Ubuntu に Claude Code を公式のネイティブインストーラーで入れる（Node.js は不要）。
# 導入済みなら何もしない（インストール後はバックグラウンドで自動更新される）。
# 使い方: bash setup-claude_code.sh   または   curl -fsSL <raw URL> | bash
set -euo pipefail

CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
LOCAL_BIN="$HOME/.local/bin"
# 既存の ~/.bashrc から古いブロックを消すために使うので、文字列は変えないこと
BLOCK_START="### setup-claude_code.sh managed block: claude ###"
BLOCK_END="### end setup-claude_code.sh managed block ###"

#---- 共通ヘルパー（curl | bash で単体実行するため、各スクリプトに同じものを持つ）----#
log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

# ~/.bashrc の managed block を毎回作り直す（再実行しても内容や末尾の空行が増えない）
write_bashrc_block() {
  local start="$1" end="$2" body="$3"
  local bashrc="$HOME/.bashrc" tmp
  touch "$bashrc"
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; next }
    !skip       { lines[++n] = $0 }
    END {
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
      for (i = 1; i <= n; i++) print lines[i]
    }
  ' "$bashrc" > "$tmp"
  printf '\n%s\n%s\n%s\n' "$start" "$body" "$end" >> "$tmp"
  cat "$tmp" > "$bashrc"
  rm -f "$tmp"
}

#---- 各セットアップ ----#
install_claude_code() {
  # インストーラーは ~/.local/bin/claude を作る。curl | bash は ~/.bashrc を読まないので、調べる前に PATH を通す
  path_prepend "$LOCAL_BIN"
  if has claude; then
    log "Claude Code is already installed: $(claude --version)"
    echo "    (Native installs auto-update. To update manually, run 'claude update'.)"
    return
  fi
  log "Install Claude Code (native installer)"
  curl -fsSL "$CLAUDE_INSTALL_URL" | bash \
    || die "Failed to install Claude Code. You can retry later: curl -fsSL $CLAUDE_INSTALL_URL | bash"
}

setup_bashrc() {
  log "Setting up bash config (~/.bashrc)"
  local body
  body="$(cat <<'EOF'
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
EOF
)"
  write_bashrc_block "$BLOCK_START" "$BLOCK_END" "$body"
}

verify() {
  if has claude; then
    log "Installed: $(claude --version)"
  else
    warn "'claude' command not found. Restart your terminal or run 'source ~/.bashrc'."
  fi
}

# 処理はすべて main から呼ぶ。curl | bash の途中でダウンロードが切れても、中途半端に実行されないようにするため
main() {
  log "Claude Code setup started"
  install_claude_code
  setup_bashrc
  verify
  log "Done. Run 'claude' in the WSL terminal (not PowerShell/CMD) to sign in and start."
  echo "For a detailed check, run 'claude doctor'."
}

main "$@"
