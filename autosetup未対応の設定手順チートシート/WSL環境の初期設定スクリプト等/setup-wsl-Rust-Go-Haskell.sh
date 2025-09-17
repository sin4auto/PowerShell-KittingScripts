#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rust / Go / Haskell セットアップ（WSL/Ubuntu 向け）
#
# 環境変数（任意）
#   GO_VERSION       : 例 "1.22.5" を指定すると公式 tarball から導入
#   GO_USE_TARBALL   : "true" を指定すると tarball 方式を強制（GO_VERSION 必須）
#   GHC_VERSION      : 例 "9.8.2" 指定時はその GHC を導入（未指定時は recommended）
#
# 実行後の反映:
#   - 新しいシェルを開くか、`source ~/.bashrc` を実行してください。
# ============================================================

export DEBIAN_FRONTEND=noninteractive

# ---- ログ関数 ------------------------------------------------
log_info()    { echo -e "\033[1;34m[INFO]\033[0m $*"; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
log_success() { echo -e "\033[1;32m[DONE]\033[0m $*"; }

# ---- 前提チェック --------------------------------------------
cd ~
if [[ "$(pwd)" == /mnt/* ]]; then
  log_error "現在 /mnt 配下にいます。WSL の Linux ホームで実行してください（例: cd ~）。"
  exit 1
fi

if grep -qi microsoft /proc/version 2>/dev/null; then
  log_info "WSL 環境を検知しました。"
fi

if command -v lsb_release >/dev/null 2>&1; then
  distro="$(lsb_release -is || true)"
  case "${distro,,}" in
    ubuntu) : ;;
    *) log_warn "Ubuntu 以外のディストリビューションです: ${distro:-unknown}" ;;
  esac
fi

# ---- Rust ----------------------------------------------------
install_rust() {
  if command -v rustc >/dev/null 2>&1; then
    log_info "Rust は既にインストール済み: $(rustc --version 2>/dev/null || echo unknown)"
  fi

  if ! command -v rustup >/dev/null 2>&1; then
    log_info "rustup をインストール（profile=minimal）"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal || {
      log_error "rustup のインストールに失敗しました。"; return 1; }
  else
    rustup self update || true
  fi

  # PATH 反映
  if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
  fi
  export PATH="$HOME/.cargo/bin:$PATH"

  # デフォルト stable に更新（既存がある場合もアップデート）
  rustup update stable || true
  rustup default stable || true

  # 必須コンポーネント
  for comp in rustfmt clippy rust-src rust-analyzer; do
    rustup component add "$comp" || true
  done

  cargo install cargo-llvm-cov

  command -v cargo >/dev/null 2>&1 && cargo --version || true
  command -v rustc  >/dev/null 2>&1 && rustc  --version || true
  log_success "Rust セットアップ完了"
}

# ---- Go ------------------------------------------------------
install_go_with_apt() {
  log_info "apt から golang-go をインストール"
  sudo apt-get install -y golang-go
  go version || true
}

install_go_with_tarball() {
  if [[ -z "${GO_VERSION:-}" ]]; then
    log_error "GO_USE_TARBALL=true が指定されていますが GO_VERSION が未指定です（例: GO_VERSION=1.22.5）。"
    return 1
  fi
  local arch; arch="$(dpkg --print-architecture)"   # amd64/arm64 を想定
  local url="https://go.dev/dl/go${GO_VERSION}.linux-${arch}.tar.gz"
  log_info "公式 tarball から Go ${GO_VERSION} を導入: ${url}"
  local tmpdir; tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    wget -q "$url" -O go.tgz || { log_error "Go のダウンロードに失敗しました"; return 1; }
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go.tgz
  )
  # PATH/GOPATH
  if ! grep -q '/usr/local/go/bin' ~/.bashrc; then
    echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.bashrc
  fi
  if ! grep -q 'export GOPATH=' ~/.bashrc; then
    echo 'export GOPATH="$HOME/go"' >> ~/.bashrc
    echo 'export PATH="$GOPATH/bin:$PATH"' >> ~/.bashrc
  fi
  export PATH="/usr/local/go/bin:$PATH"
  export GOPATH="$HOME/go"; mkdir -p "$GOPATH/bin"
  go version || true
}

install_go() {
  if command -v go >/dev/null 2>&1; then
    log_info "Go は既にインストール済み: $(go version 2>/dev/null || echo unknown)"
    return 0
  fi
  if [[ "${GO_USE_TARBALL:-}" == "true" || -n "${GO_VERSION:-}" ]]; then
    install_go_with_tarball || { log_warn "tarball 方式に失敗。apt 方式を試します。"; install_go_with_apt || return 1; }
  else
    install_go_with_apt || return 1
  fi
  log_success "Go セットアップ完了"
}

# ---- Haskell（ghcup） ----------------------------------------
install_haskell() {
  if ! command -v ghcup >/dev/null 2>&1; then
    log_info "ghcup をインストール（非対話）"
    BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_INSTALL_HLS=yes \
    BOOTSTRAP_HASKELL_GHC_VERSION="${GHC_VERSION:-recommended}" \
    BOOTSTRAP_HASKELL_CABAL_VERSION=recommended \
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh || {
      log_error "ghcup のインストールに失敗しました。"; return 1; }
  else
    ghcup upgrade || true
  fi

  # PATH 反映
  if ! grep -q '\.ghcup/env' ~/.bashrc; then
    echo '[[ -f "$HOME/.ghcup/env" ]] && source "$HOME/.ghcup/env"' >> ~/.bashrc
  fi
  [[ -f "$HOME/.ghcup/env" ]] && source "$HOME/.ghcup/env"

  # 推奨版（または指定版）を明示セット
  ghcup install ghc  "${GHC_VERSION:-recommended}" --set || true
  ghcup install cabal recommended || true
  ghcup install hls  recommended --set || true

  command -v ghc   >/dev/null 2>&1 && ghc   --version || true
  command -v cabal >/dev/null 2>&1 && cabal --version || true
  command -v hls   >/dev/null 2>&1 && hls   --version || true
  log_success "Haskell セットアップ完了"
}

# ---- 実行 ----------------------------------------------------
log_info "Rust セットアップ"
install_rust

log_info "Go セットアップ"
install_go

log_info "Haskell セットアップ"
install_haskell

echo
log_success "すべて完了。新しいシェルを開くか 'source ~/.bashrc' を実行してください。"
echo "---- Versions (if available) ----"
(command -v rustc >/dev/null 2>&1 && rustc --version) || true
(command -v cargo >/dev/null 2>&1 && cargo --version) || true
(command -v go    >/dev/null 2>&1 && go version) || true
(command -v ghc   >/dev/null 2>&1 && ghc --version) || true
(command -v cabal >/dev/null 2>&1 && cabal --version) || true
(command -v hls   >/dev/null 2>&1 && hls --version) || true
