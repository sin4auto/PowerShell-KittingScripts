#!/usr/bin/env bash
set -euo pipefail

echo "==> WSL Ubuntu setup started"

#---- ホーム直下で作業（/mnt/c 回避） ----#
cd ~
if [[ "$(pwd)" == /mnt/* ]]; then
  echo "ERROR: You are under /mnt/. Please move to your Linux home (e.g., cd ~) and re-run." >&2
  exit 1
fi

#---- ロケール & タイムゾーン ----#
echo "==> Configure locale & timezone (Asia/Tokyo)"
sudo apt-get update -y
sudo apt-get install -y language-pack-ja tzdata
sudo update-locale LANG=ja_JP.UTF-8
sudo timedatectl set-timezone Asia/Tokyo || true

#---- 基本ツール ----#
echo "==> Install base packages"
sudo apt-get install -y build-essential git curl wget unzip ca-certificates gnupg lsb-release pkg-config \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev liblzma-dev tk-dev \
  libncursesw5-dev xz-utils ripgrep tar libgmp-dev

#---- gitのデフォルトブランチをmainにする ----#
git config --global init.defaultBranch main

#---- nvm & Node.js(LTS) ----#
if ! command -v nvm >/dev/null 2>&1; then
  echo "==> Install nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# シェルに反映
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1090
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

echo "==> Install Node.js (LTS) via nvm"
nvm install --lts
nvm alias default 'lts/*'
node -v
npm -v

#---- pyenv & Python 3.12.11 ----#
if ! command -v pyenv >/dev/null 2>&1; then
  echo "==> Install pyenv"
  curl https://pyenv.run | bash
  {
    echo 'export PYENV_ROOT="$HOME/.pyenv"'
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
    echo 'eval "$(pyenv init -)"'
  } >> ~/.bashrc
fi

# 反映
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

if ! pyenv versions --bare | grep -qx "3.12.11"; then
  echo "==> Install Python 3.12.11 via pyenv"
  pyenv install 3.12.11
fi
pyenv global 3.12.11
python --version

#---- uv（超高速パッケージマネージャ） ----#
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Install uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # uv は通常 ~/.local/bin 等に入る。PATH 追記（重複回避）
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  fi
  export PATH="$HOME/.local/bin:$PATH"
fi
uv --version

#---- VSCode は Windows 側で導入。ここでは WSL 内連携のみ。 ----#

#---- Codex CLI ----#
echo "==> Install Codex CLI (global)"
npm install -g @openai/codex || {
  echo "WARN: Failed to install @openai/codex via npm. You can retry later: npm install -g @openai/codex" >&2
}

#---- ~/.codex/config.tomlファイル生成 ----#
echo "==> Write MCP config to ~/.codex/config.toml"
mkdir -p ~/.codex
cat > ~/.codex/config.toml <<'TOML'
network_access = true
model = "gpt-5-codex"
model_reasoning_effort = "high"

[profiles.default]
approval_policy = "on-request"
sandbox_mode = "workspace-write"
model = "gpt-5-codex"
model_reasoning_effort = "high"

[profiles.readonly]
approval_policy = "never"
sandbox_mode    = "read-only"
model = "gpt-5-codex"
model_reasoning_effort = "high"

[tools]
web_search = true

# === 思考の外化（トークン節約/品質安定） ===
[mcp_servers.sequential-thinking]
command = "npx"
args    = ["-y", "@modelcontextprotocol/server-sequential-thinking"]
transport = "stdio"

# === コーディング能力強化（プロジェクト指向） ===
[mcp_servers.serena]
command = "uvx"
args    = [
  "--from", "git+https://github.com/oraios/serena",
  "serena", "start-mcp-server", "--context", "ide-assistant"
]
transport = "stdio"
disabled = false

[mcp_servers.serena.env]
PYTHONUTF8 = "1"
PYTHONIOENCODING = "utf-8"

# === 長期メモリ ===
[mcp_servers.memory]
command = "npx"
args    = ["-y", "@modelcontextprotocol/server-memory@latest"]
transport = "stdio"

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

[projects."/home/hsin4/myproject/typelang-hm-rs"]
trust_level = "trusted"

TOML

#---- 推奨アドオン：Jupyter/開発補助など（必要なら後で） ----#
# 例) uv で高速インストール:
# uv pip install --upgrade pip
# uv pip install jupyter numpy pandas matplotlib

echo "==> Done. Please open VSCode with Remote-WSL and run 'codex' in the WSL terminal."
