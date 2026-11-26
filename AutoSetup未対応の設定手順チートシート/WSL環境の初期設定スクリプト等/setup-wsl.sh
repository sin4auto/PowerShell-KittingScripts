#!/usr/bin/env bash
# WSL Ubuntu の開発環境（日本語ロケール・基本パッケージ・Node.js・Python・uv・Chrome）をまとめて整える。
# 何度実行しても同じ状態になる（導入済みのものは飛ばす）。
# 使い方: bash setup-wsl.sh   または   curl -fsSL <raw URL> | bash
set -euo pipefail

NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh"
PYTHON_VERSION="3.12.4"
PYENV_INSTALL_URL="https://pyenv.run"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"
CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
# 既存の ~/.bashrc から古いブロックを消すために使うので、文字列は変えないこと
BLOCK_START="### setup-wsl.sh managed block: pyenv/nvm/uv ###"
BLOCK_END="### end setup-wsl.sh managed block ###"

export NVM_DIR="$HOME/.nvm"
export PYENV_ROOT="$HOME/.pyenv"

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

apt_install() {
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
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
move_to_home() {
  # /mnt 配下（Windows 側のドライブ）は権限やパフォーマンス面で不利なので、どこから実行しても Linux ホームを起点にする
  cd "$HOME"
}

setup_locale_timezone() {
  log "Configure locale & timezone (Asia/Tokyo)"
  sudo apt-get update -y
  apt_install language-pack-ja tzdata
  sudo update-locale LANG=ja_JP.UTF-8

  if ! has timedatectl; then
    warn "timedatectl is not available. Skipping timezone setup."
  elif ! sudo timedatectl set-timezone Asia/Tokyo; then
    warn "timedatectl is unavailable in this WSL environment. Skipping timezone setup."
  fi
}

install_base_packages() {
  # Python（pyenv でのビルド）や Node に必要な開発系パッケージもまとめて入れる
  local packages=(
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
  log "Install base packages"
  apt_install "${packages[@]}"
}

setup_git() {
  # 古い環境では git init の既定ブランチが master のことがあるため main にそろえる
  log "Set git default branch to main"
  git config --global init.defaultBranch main
}

install_node() {
  log "Install nvm & Node.js"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    curl -fsSL "$NVM_INSTALL_URL" | bash
  fi
  # インストールが成功しても nvm.sh が生成されないケースがあるため、存在を確かめる
  [[ -s "$NVM_DIR/nvm.sh" ]] || die "nvm.sh was not found after installation."

  # nvm を読み込んだ同じシェルで、そのまま LTS の Node.js まで入れる
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default "lts/*"
  node -v
  npm -v
}

install_python() {
  log "Install pyenv & Python ${PYTHON_VERSION}"
  if [[ ! -x "$PYENV_ROOT/bin/pyenv" ]]; then
    curl -fsSL "$PYENV_INSTALL_URL" | bash
  fi
  [[ -x "$PYENV_ROOT/bin/pyenv" ]] || die "pyenv binary was not found after installation."

  # PATH を通してから初期化し、その場で Python を使える状態にする
  path_prepend "$PYENV_ROOT/bin"
  eval "$(pyenv init -)"
  if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
    pyenv install "$PYTHON_VERSION"
  fi
  pyenv global "$PYTHON_VERSION"
  python --version
}

install_uv() {
  log "Install uv"
  path_prepend "$HOME/.local/bin"
  if [[ ! -x "$HOME/.local/bin/uv" ]]; then
    curl -fsSL "$UV_INSTALL_URL" | sh
  fi
  # uv が無いと後続の Python ワークフローが成り立たないため、ここで止める
  has uv || die "uv command was not found after installation."
  uv --version
}

install_chrome() {
  log "Install Google Chrome"
  if ! has google-chrome; then
    # 未導入のときだけ公式の .deb を取得して apt で入れる。失敗しても一時ファイルは必ず消す
    local deb
    deb="$(mktemp --suffix=.deb)"
    if ! { curl -fL "$CHROME_DEB_URL" -o "$deb" && apt_install "$deb"; }; then
      rm -f "$deb"
      die "Failed to install Google Chrome."
    fi
    rm -f "$deb"
  fi
  google-chrome --version
}

setup_bashrc() {
  log "Setting up bash config (~/.bashrc)"
  # 新しい bash セッションで pyenv / nvm / uv が使えるようにする
  local body
  body="$(cat <<'EOF'
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
)"
  write_bashrc_block "$BLOCK_START" "$BLOCK_END" "$body"
}

# 処理はすべて main から呼ぶ。curl | bash の途中でダウンロードが切れても、中途半端に実行されないようにするため
main() {
  log "WSL Ubuntu full environment setup started..."
  move_to_home
  setup_locale_timezone
  install_base_packages
  setup_git
  install_node
  install_python
  install_uv
  install_chrome
  setup_bashrc

  echo ""
  echo "✅ All environment setup is complete!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!! PLEASE CLOSE AND RE-OPEN YOUR WSL TERMINAL to start    !!!"
  echo "!!! using bash with the new development environment.       !!!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
}

main "$@"
