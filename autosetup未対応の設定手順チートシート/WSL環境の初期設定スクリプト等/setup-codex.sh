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

#---- ~/.codex/config.tomlファイル生成 ----#
echo "==> Write MCP config to ~/.codex/config.toml"
mkdir -p ~/.codex
cat > ~/.codex/config.toml <<'TOML'
model = "gpt-5-codex"
network_access = true

[tools]
web_search = true

# === Context7（最新ドキュメント取得＝手戻り削減） === #
[mcp_servers.context7]
command = "npx"
args    = ["-y", "@upstash/context7-mcp@latest"]
transport = "stdio"

# === 拡張：E2E/品質/ウェブ取得 === #
[mcp_servers.playwright]
command = "npx"
args    = ["-y", "@playwright/mcp@latest"]
transport = "stdio"

# === コーディング能力強化（プロジェクト指向） ===
[mcp_servers.serena]
command = "uvx"
args    = ["--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server", "--context", "ide-assistant"]
transport = "stdio"
disabled = false
[mcp_servers.serena.env]
PYTHONUTF8 = "1"
PYTHONIOENCODING = "utf-8"
TOML

echo "==> Done. Please open VSCode with Remote-WSL and run 'codex' in the WSL terminal."
echo "If the 'codex' command is not found, try restarting your terminal or run 'source ~/.bashrc'."