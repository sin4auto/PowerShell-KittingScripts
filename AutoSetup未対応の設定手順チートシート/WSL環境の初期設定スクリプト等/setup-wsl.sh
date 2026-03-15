#!/usr/bin/env bash
set -euo pipefail

NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh"
PYTHON_VERSION="3.12.4"
PYENV_INSTALL_URL="https://pyenv.run"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"
CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
BLOCK_START="### setup-wsl.sh managed block: pyenv/nvm/uv ###"
BLOCK_END="### end setup-wsl.sh managed block ###"

echo "==> WSL Ubuntu full environment setup started..."

# /mnt 配下では権限やパフォーマンス面で不利なので Linux ホームを起点にする
cd "$HOME"
if [[ "$(pwd)" == /mnt/* ]]; then
  echo "ERROR: You are under /mnt/. Please move to your Linux home (e.g., cd ~) and re-run." >&2
  exit 1
fi

# 日本語ロケールとタイムゾーンを先に整える
echo "==> Configure locale & timezone (Asia/Tokyo)"
sudo apt-get update -y
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y language-pack-ja tzdata
sudo update-locale LANG=ja_JP.UTF-8

if ! command -v timedatectl >/dev/null 2>&1; then
  echo "WARN: timedatectl is not available. Skipping timezone setup." >&2
elif ! sudo timedatectl set-timezone Asia/Tokyo; then
  echo "WARN: timedatectl is unavailable in this WSL environment. Skipping timezone setup." >&2
fi

# Python や Node のビルドに必要な開発系パッケージもまとめて入れる
packages=(
  ca-certificates  # HTTPS 通信の証明書検証に必要
  curl             # 各種インストーラー取得に使う
  wget             # ファイル単位のダウンロードに使う
  gnupg            # GPG 鍵や署名の検証に使う
  lsb-release      # Ubuntu のディストリ情報取得に使う
  unzip            # zip アーカイブ展開に使う
  tar              # tar アーカイブ展開に使う
  xz-utils         # xz 形式の圧縮展開に使う
  git              # Git リポジトリ操作に使う
  build-essential  # C/C++ ビルドツール一式
  pkg-config       # ネイティブ依存ライブラリ検出に使う
  ripgrep          # 高速な全文検索コマンド
  shellcheck       # Shell スクリプトの静的解析に使う
  libssl-dev       # OpenSSL 開発ヘッダ
  zlib1g-dev       # zlib 開発ヘッダ
  libbz2-dev       # bzip2 開発ヘッダ
  libreadline-dev  # readline 開発ヘッダ
  libsqlite3-dev   # SQLite3 開発ヘッダ
  libffi-dev       # FFI 開発ヘッダ
  liblzma-dev      # lzma/xz 開発ヘッダ
  libncursesw5-dev # ワイド文字対応 ncurses 開発ヘッダ
  tk-dev           # Tk 開発ヘッダ
  libgmp-dev       # 多倍長整数演算ライブラリの開発ヘッダ
)

# WSL Ubuntu 22.04 では Python 3.12 系を pyenv で入れる前提のため、ビルド依存もここでまとめて入れる
echo "==> Install base packages"
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"

# WSL の古い環境では git init の既定ブランチが master のことがあるため main にそろえる
echo "==> Set git default branch to main"
git config --global init.defaultBranch main

# nvm を読み込んだ同じシェルで、そのまま LTS Node.js まで導入する
export NVM_DIR="$HOME/.nvm"
# nvm のインストールスクリプトは成功しても nvm.sh が生成されないケースがあるため、インストール後の存在チェックを入れる
echo "==> Install nvm & Node.js"
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  curl -fsSL "$NVM_INSTALL_URL" | bash
fi
# nvm.sh が存在しない場合はインストールに失敗している可能性が高いため、即時終了する
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  echo "ERROR: nvm.sh was not found after installation." >&2
  exit 1
fi

# shellcheck disable=SC1090,SC1091
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default "lts/*"
node -v
npm -v

# pyenv は PATH を通してから初期化し、その場で Python を利用可能にする
export PYENV_ROOT="$HOME/.pyenv"

echo "==> Install pyenv & Python"
if [[ ! -x "$PYENV_ROOT/bin/pyenv" ]]; then
  curl -fsSL "$PYENV_INSTALL_URL" | bash
fi

if [[ ! -x "$PYENV_ROOT/bin/pyenv" ]]; then
  echo "ERROR: pyenv binary was not found after installation." >&2
  exit 1
fi

case ":$PATH:" in
  *":$PYENV_ROOT/bin:"*) ;;
  *) export PATH="$PYENV_ROOT/bin:$PATH" ;;
esac

eval "$(pyenv init -)"
if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
  pyenv install "$PYTHON_VERSION"
fi
pyenv global "$PYTHON_VERSION"
python --version

echo "==> Install uv"
if [[ ! -x "$HOME/.local/bin/uv" ]]; then
  curl -fsSL "$UV_INSTALL_URL" | sh
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# uv が見つからない場合は後続の Python ワークフローが成立しないため即時終了
if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: uv command was not found after installation." >&2
  exit 1
fi
uv --version

# Google Chrome は未導入時だけ公式 .deb を取得して apt で導入する
echo "==> Install Google Chrome"
if ! command -v google-chrome >/dev/null 2>&1; then
  chrome_deb_path="$(mktemp --suffix=.deb)"
  curl -fL "$CHROME_DEB_URL" -o "$chrome_deb_path"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$chrome_deb_path"
  rm -f "$chrome_deb_path"
fi
google-chrome --version

# .bashrc は managed block を毎回作り直して再実行しても内容が増殖しないようにする
bashrc_file="$HOME/.bashrc"
touch "$bashrc_file"

echo "==> Setting up bash config (~/.bashrc)"
tmp_file="$(mktemp)"
awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
  BEGIN { in_block = 0 }
  $0 == start { in_block = 1; next }
  $0 == end { in_block = 0; next }
  !in_block { lines[++count] = $0 }
  END {
    while (count > 0 && lines[count] ~ /^[[:space:]]*$/) {
      count--
    }
    for (i = 1; i <= count; i++) {
      print lines[i]
    }
  }
' "$bashrc_file" > "$tmp_file"

# 新しい bash セッションで pyenv / nvm / uv が有効になる設定を追記する
{
  echo ""
  echo "$BLOCK_START"
  cat <<'EOF'
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
EOF
  echo "$BLOCK_END"
} >> "$tmp_file"
mv "$tmp_file" "$bashrc_file"

echo ""
echo "✅ All environment setup is complete!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!! PLEASE CLOSE AND RE-OPEN YOUR WSL TERMINAL to start    !!!"
echo "!!! using bash with the new development environment.       !!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
