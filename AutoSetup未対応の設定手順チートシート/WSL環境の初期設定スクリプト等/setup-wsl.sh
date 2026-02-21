#!/usr/bin/env bash
set -euo pipefail

NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh"
PYTHON_VERSION="3.12.4"
PYENV_INSTALL_URL="https://pyenv.run"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"
BLOCK_START="### setup-wsl.sh managed block: pyenv/nvm/uv ###"
BLOCK_END="### end setup-wsl.sh managed block ###"
APT_UPDATED=0

# 標準ログをプレフィックス付きで出力する
log() {
  echo "==> $*"
}

# 警告を標準エラー出力に出す
warn() {
  echo "WARN: $*" >&2
}

# エラーメッセージを出して即時終了する
die() {
  echo "ERROR: $*" >&2
  exit 1
}

# PATH に未登録のディレクトリだけを先頭追加する
path_prepend() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
}

# apt 更新を1回だけ実行し、非対話モードでパッケージを入れる
apt_install() {
  if [[ "$APT_UPDATED" -eq 0 ]]; then
    sudo apt-get update -y
    APT_UPDATED=1
  fi
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# リモート配布インストーラを統一インターフェースで実行する
run_remote_installer() {
  local name="$1"
  local url="$2"
  local runner="$3"

  log "Install ${name}"
  case "$runner" in
    bash) curl -fsSL "$url" | bash ;;
    sh) curl -fsSL "$url" | sh ;;
    *) die "Unsupported installer runner: ${runner}" ;;
  esac
}

# /mnt 配下を避け、Linux ホーム配下で作業することを保証する
ensure_home_workspace() {
  cd "$HOME"
  if [[ "$(pwd)" == /mnt/* ]]; then
    die "You are under /mnt/. Please move to your Linux home (e.g., cd ~) and re-run."
  fi
}

# ロケールとタイムゾーンを設定する（非対応環境は警告して継続）
configure_locale_and_timezone() {
  log "Configure locale & timezone (Asia/Tokyo)"
  apt_install language-pack-ja tzdata
  sudo update-locale LANG=ja_JP.UTF-8

  if ! command -v timedatectl >/dev/null 2>&1; then
    warn "timedatectl is not available. Skipping timezone setup."
    return
  fi

  if ! sudo timedatectl set-timezone Asia/Tokyo; then
    warn "timedatectl is unavailable in this WSL environment. Skipping timezone setup."
  fi
}

# 開発環境の土台となる基本パッケージを導入する
install_base_packages() {
  local packages=(
    # 必須ツール（セットアップと運用に直接必要）
    ca-certificates  # TLS 検証用のルート証明書ストア
    curl             # HTTP(S) 通信クライアント（パイプ実行向け）
    wget             # HTTP(S) ダウンローダ（ファイル取得向け）
    gnupg            # GPG 署名検証・鍵管理ツール群
    lsb-release      # ディストリ情報（リリース判定）取得コマンド
    unzip            # ZIP アーカイブ展開ツール
    tar              # tar アーカイブ作成/展開ユーティリティ
    xz-utils         # xz 形式の圧縮/展開ユーティリティ
    git              # 分散バージョン管理クライアント
    build-essential  # GCC/G++・make などのビルドツールチェーン
    pkg-config       # ネイティブ依存ライブラリのビルドフラグ解決
    ripgrep          # Rust 製の高速 grep 互換検索ツール
    shellcheck       # Shell スクリプト静的解析（lint）ツール

    # 開発向け依存ライブラリ（各言語ランタイムのビルドで利用）
    libssl-dev       # OpenSSL 開発ヘッダ/静的リンク用ファイル
    zlib1g-dev       # zlib 開発ヘッダ（圧縮機能依存）
    libbz2-dev       # bzip2 開発ヘッダ（圧縮機能依存）
    libreadline-dev  # readline 開発ヘッダ（対話 CLI 入力）
    libsqlite3-dev   # SQLite3 開発ヘッダ/ライブラリ
    libffi-dev       # FFI 開発ヘッダ（C ABI ブリッジ）
    liblzma-dev      # xz/lzma 開発ヘッダ（圧縮機能依存）
    libncursesw5-dev # wide-char ncurses 開発ヘッダ（TUI）
    tk-dev           # Tk GUI 開発ヘッダ（例: tkinter）
    libgmp-dev       # GNU MP 多倍長演算ライブラリ開発ヘッダ
  )

  log "Install base packages"
  apt_install "${packages[@]}"
}

# git 初期ブランチ名を main に固定する
configure_git_defaults() {
  log "Set git default branch to main"
  git config --global init.defaultBranch main
}

# nvm と Node.js LTS を導入し、デフォルトを LTS 系へ設定する
setup_nvm() {
  local nvm_dir="$HOME/.nvm"
  export NVM_DIR="$nvm_dir"

  log "Install nvm & Node.js"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    run_remote_installer "nvm" "$NVM_INSTALL_URL" "bash"
  fi

  [[ -s "$NVM_DIR/nvm.sh" ]] || die "nvm.sh was not found after installation."
  # shellcheck disable=SC1090,SC1091
  . "$NVM_DIR/nvm.sh"

  nvm install --lts
  nvm alias default "lts/*"
  node -v
  npm -v
}

# pyenv で指定 Python を導入し、グローバル版として設定する
setup_pyenv() {
  export PYENV_ROOT="$HOME/.pyenv"

  log "Install pyenv & Python"
  if [[ ! -x "$PYENV_ROOT/bin/pyenv" ]]; then
    run_remote_installer "pyenv" "$PYENV_INSTALL_URL" "bash"
  fi

  [[ -x "$PYENV_ROOT/bin/pyenv" ]] || die "pyenv binary was not found after installation."
  path_prepend "$PYENV_ROOT/bin"
  eval "$(pyenv init -)"

  if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
    pyenv install "$PYTHON_VERSION"
  fi
  pyenv global "$PYTHON_VERSION"
  python --version
}

# uv を導入し、実行可能 PATH を整える
setup_uv() {
  local uv_bin="$HOME/.local/bin/uv"

  log "Install uv"
  if [[ ! -x "$uv_bin" ]]; then
    run_remote_installer "uv" "$UV_INSTALL_URL" "sh"
  fi

  path_prepend "$HOME/.local/bin"
  command -v uv >/dev/null 2>&1 || die "uv command was not found after installation."
  uv --version
}

# .bashrc の managed block を毎回再生成して内容を同期する
setup_bashrc_block() {
  local bashrc_file="$HOME/.bashrc"
  local tmp_file

  log "Setting up bash config (~/.bashrc)"
  touch "$bashrc_file"

  # 既存 managed block を除去
  tmp_file="$(mktemp)"
  awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
    BEGIN { in_block = 0 }
    $0 == start { in_block = 1; next }
    $0 == end { in_block = 0; next }
    !in_block { print }
  ' "$bashrc_file" > "$tmp_file"
  cat "$tmp_file" > "$bashrc_file"
  rm -f "$tmp_file"

  # 末尾空行を正規化して、再実行時の空行累積を防ぐ
  tmp_file="$(mktemp)"
  awk '
    { lines[NR] = $0 }
    END {
      last = NR
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) {
        last--
      }
      for (i = 1; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$bashrc_file" > "$tmp_file"
  cat "$tmp_file" > "$bashrc_file"
  rm -f "$tmp_file"

  # managed block を最新内容で追記
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
  } >> "$bashrc_file"
}

# 全セットアップ処理を順序制御して実行するエントリーポイント
main() {
  log "WSL Ubuntu full environment setup started..."
  ensure_home_workspace
  configure_locale_and_timezone
  install_base_packages
  configure_git_defaults
  setup_nvm
  setup_pyenv
  setup_uv
  setup_bashrc_block

  echo ""
  echo "✅ All environment setup is complete!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!! PLEASE CLOSE AND RE-OPEN YOUR WSL TERMINAL to start    !!!"
  echo "!!! using bash with the new development environment.       !!!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
}

main "$@"
