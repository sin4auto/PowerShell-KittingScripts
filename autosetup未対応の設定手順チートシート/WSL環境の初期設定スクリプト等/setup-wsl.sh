#!/usr/bin/env zsh
# zshで実行するため、shebangをzshに変更
set -euo pipefail

echo "==> WSL development environment setup started (running with zsh)..."

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
  # nvmのバージョンは最新のものに更新される可能性があります
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
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

#---- pyenv & Python ----#
PYTHON_VERSION="3.12.4" # 必要に応じてバージョンを指定

if ! command -v pyenv >/dev/null 2>&1; then
  echo "==> Install pyenv"
  curl https://pyenv.run | zsh # zshで実行
fi

# 反映
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
  echo "==> Install Python $PYTHON_VERSION via pyenv"
  pyenv install "$PYTHON_VERSION"
fi
pyenv global "$PYTHON_VERSION"
python --version

#---- uv（超高速パッケージマネージャ） ----#
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Install uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
uv --version

#---- 共通設定ファイル (.commonrc) のセットアップ ----#
echo "==> Setting up common config file (~/.commonrc) for both bash and zsh"
COMMONRC_FILE="$HOME/.commonrc"
touch "$COMMONRC_FILE" # ファイルがなければ作成

# pyenv の設定を .commonrc に書き込む (なければ)
if ! grep -q 'PYENV_ROOT' "$COMMONRC_FILE"; then
  echo -e "\n# pyenv settings" >> "$COMMONRC_FILE"
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$COMMONRC_FILE"
  echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> "$COMMONRC_FILE"
  echo 'eval "$(pyenv init -)"' >> "$COMMONRC_FILE"
fi

# nvm の設定を .commonrc に書き込む (なければ)
if ! grep -q 'NVM_DIR' "$COMMONRC_FILE"; then
  echo -e "\n# nvm settings" >> "$COMMONRC_FILE"
  echo 'export NVM_DIR="$HOME/.nvm"' >> "$COMMONRC_FILE"
  echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> "$COMMONRC_FILE"
fi

# uv の PATH設定を .commonrc に書き込む (なければ)
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$COMMONRC_FILE"; then
  echo -e "\n# uv path" >> "$COMMONRC_FILE"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$COMMONRC_FILE"
fi

# .bashrc と .zshrc の両方から .commonrc を読み込む設定
for SHELL_RC_FILE in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$SHELL_RC_FILE" ] && ! grep -q ".commonrc" "$SHELL_RC_FILE"; then
    echo "--> Adding .commonrc source to $SHELL_RC_FILE"
    echo -e '\n# Load common settings\nif [ -f ~/.commonrc ]; then\n    . ~/.commonrc\nfi' >> "$SHELL_RC_FILE"
  fi
done

echo ""
echo "✅ All environment setup is complete."
echo "Please restart your terminal one last time, or run 'source ~/.zshrc' to apply all changes."