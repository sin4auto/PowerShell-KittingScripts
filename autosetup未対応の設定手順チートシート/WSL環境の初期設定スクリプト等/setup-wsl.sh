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

#---- Zsh & Oh My Zsh ----#
echo "==> Install Zsh & Oh My Zsh"
if ! command -v zsh >/dev/null 2>&1; then
    sudo apt-get install -y zsh
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "--> Installing Oh My Zsh and setting zsh as default shell..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "--> Oh My Zsh is already installed."
fi

#---- 共通設定ファイル (.commonrc) のセットアップ ----#
echo "==> Setting up common config file (~/.commonrc)"
COMMONRC_FILE="$HOME/.commonrc"
touch "$COMMONRC_FILE" # ファイルがなければ作成

# pyenv の設定を .commonrc に書き込む (なければ)
if ! grep -q 'PYENV_ROOT' "$COMMONRC_FILE"; then
  echo -e "\n# pyenv settings" >> "$COMMONRC_FILE"
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$COMMONRC_FILE"
  echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> "$COMMONRC_FILE"
  echo 'eval "$(pyenv init -)"' >> "$COMMONRC_FILE"
fi

# uv の PATH設定を .commonrc に書き込む (なければ)
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$COMMONRC_FILE"; then
  echo -e "\n# uv path" >> "$COMMONRC_FILE"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$COMMONRC_FILE"
fi

# .bashrc に .commonrc の読み込み設定を追記 (なければ)
BASHRC_LOAD_CMD='\n# Load common settings\nif [ -f ~/.commonrc ]; then\n    . ~/.commonrc\nfi'
if ! grep -q ".commonrc" "$HOME/.bashrc"; then
  echo -e "$BASHRC_LOAD_CMD" >> "$HOME/.bashrc"
fi

# .zshrc に .commonrc の読み込み設定を追記 (なければ)
ZSHRC_LOAD_CMD='\n# Load common settings\nif [ -f ~/.commonrc ]; then\n    . ~/.commonrc\nfi'
if ! grep -q ".commonrc" "$HOME/.zshrc"; then
  echo -e "$ZSHRC_LOAD_CMD" >> "$HOME/.zshrc"
fi
#---- VSCode は Windows 側で導入。ここでは WSL 内連携のみ。 ----#

#---- 推奨アドオン：Jupyter/開発補助など（必要なら後で） ----#
# 例) uv で高速インストール:
# uv pip install --upgrade pip
# uv pip install jupyter numpy pandas matplotlib

echo "==> Base environment setup is complete."
echo "==> Next, run 'bash ./setup_codex.sh' to install Codex."