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

#---- bash設定ファイル (.bashrc) のセットアップ ----#
echo "==> Setting up bash config (~/.bashrc)"
BASHRC_FILE="$HOME/.bashrc"
touch "$BASHRC_FILE"

# 既存 managed block を削除してから再生成することで、内容変更時も自動更新する
sed -i '/^### setup-wsl.sh managed block: pyenv\/nvm\/uv ###$/,/^### end setup-wsl.sh managed block ###$/d' "$BASHRC_FILE"

cat >> "$BASHRC_FILE" <<'EOF'

### setup-wsl.sh managed block: pyenv/nvm/uv ###
export PYENV_ROOT="$HOME/.pyenv"
case ":$PATH:" in
  *":$PYENV_ROOT/bin:"*) ;;
  *) export PATH="$PYENV_ROOT/bin:$PATH" ;;
esac
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - bash)"
fi

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
### end setup-wsl.sh managed block ###
EOF

echo ""
echo "✅ All environment setup is complete!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!! PLEASE CLOSE AND RE-OPEN YOUR WSL TERMINAL to start    !!!"
echo "!!! using bash with the new development environment.       !!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
