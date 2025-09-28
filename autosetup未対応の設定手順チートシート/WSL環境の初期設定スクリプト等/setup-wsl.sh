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

#---- Zsh & Oh My Zsh ----#
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

#---- Zsh必須プラグイン (autosuggestions & syntax-highlighting) ----#
echo "==> Install essential Zsh plugins"
# zsh-autosuggestions (コマンド履歴から候補を薄く表示)
ZSH_AUTOSUGGESTIONS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
if [[ ! -d "$ZSH_AUTOSUGGESTIONS_DIR" ]]; then
  echo "--> Cloning zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR"
else
  echo "--> zsh-autosuggestions is already cloned."
fi

# zsh-syntax-highlighting (コマンドの構文をハイライト)
ZSH_SYNTAX_HIGHLIGHTING_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
if [[ ! -d "$ZSH_SYNTAX_HIGHLIGHTING_DIR" ]]; then
  echo "--> Cloning zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_HIGHLIGHTING_DIR"
else
  echo "--> zsh-syntax-highlighting is already cloned."
fi

# .zshrcのプラグイン設定を更新 (冪等性を担保)
if [[ -f "$HOME/.zshrc" ]]; then
  # zsh-autosuggestionsを有効化 (まだ設定されていない場合)
  if ! grep -q "zsh-autosuggestions" "$HOME/.zshrc"; then
    echo "--> Adding zsh-autosuggestions to .zshrc plugins"
    sed -i '/^plugins=(/ s/)$/ zsh-autosuggestions)/' "$HOME/.zshrc"
  else
    echo "--> zsh-autosuggestions already enabled in .zshrc."
  fi
  # zsh-syntax-highlightingを有効化 (まだ設定されていない場合)
  if ! grep -q "zsh-syntax-highlighting" "$HOME/.zshrc"; then
    echo "--> Adding zsh-syntax-highlighting to .zshrc plugins"
    sed -i '/^plugins=(/ s/)$/ zsh-syntax-highlighting)/' "$HOME/.zshrc"
  else
    echo "--> zsh-syntax-highlighting already enabled in .zshrc."
  fi
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