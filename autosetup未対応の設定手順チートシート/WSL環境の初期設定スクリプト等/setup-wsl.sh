#!/usr/bin/env bash
set -euo pipefail

echo "==> WSL Ubuntu full environment setup started..."

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

#---- Zsh & Oh My Zsh & デフォルトシェル変更 ----#
echo "==> Install Zsh & Oh My Zsh"
if ! command -v zsh >/dev/null 2>&1; then
    sudo apt-get install -y zsh
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "--> Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "--> Oh My Zsh is already installed."
fi

ZSH_PATH=$(which zsh)
if ! grep -Fxq "$ZSH_PATH" /etc/shells; then
  echo "--> Adding $ZSH_PATH to /etc/shells..."
  echo "$ZSH_PATH" | sudo tee -a /etc/shells
fi

if [ "${SHELL##*/}" != "zsh" ]; then
  echo "--> Setting zsh as default shell for user $USER..."
  sudo usermod -s "$ZSH_PATH" "$USER"
  if [ $? -eq 0 ]; then
    echo "--> Default shell successfully changed to zsh."
  else
    echo "--> ERROR: Failed to change default shell." >&2
  fi
else
  echo "--> zsh is already the default shell."
fi

#---- nvm & Node.js(LTS) ----#
echo "==> Install nvm & Node.js"
if ! command -v nvm >/dev/null 2>&1; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

nvm install --lts
nvm alias default 'lts/*'
node -v
npm -v

#---- pyenv & Python ----#
echo "==> Install pyenv & Python"
PYTHON_VERSION="3.12.4"

if ! command -v pyenv >/dev/null 2>&1; then
  # bashで実行するため、パイプ先のシェルをbashに変更
  curl https://pyenv.run | bash
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
  pyenv install "$PYTHON_VERSION"
fi
pyenv global "$PYTHON_VERSION"
python --version

#---- uv（超高速パッケージマネージャ） ----#
echo "==> Install uv"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
uv --version

#---- 共通設定ファイル (.commonrc) のセットアップ ----#
echo "==> Setting up common config file (~/.commonrc) for both bash and zsh"
COMMONRC_FILE="$HOME/.commonrc"
touch "$COMMONRC_FILE"

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
if ! grep -q '.local/bin' "$COMMONRC_FILE"; then
  echo -e "\n# Add ~/.local/bin to PATH (for uv, etc.)" >> "$COMMONRC_FILE"
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
echo "✅ All environment setup is complete!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!! PLEASE CLOSE AND RE-OPEN YOUR WSL TERMINAL to start    !!!"
echo "!!! using zsh with the new development environment.        !!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"