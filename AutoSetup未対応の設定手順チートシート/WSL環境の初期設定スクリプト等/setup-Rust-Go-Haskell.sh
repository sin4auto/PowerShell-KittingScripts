#!/usr/bin/env bash
set -euo pipefail

GO_VERSION="1.22.5"
GO_INSTALL_DIR="/usr/local"
BLOCK_START="### setup-Rust-Go-Haskell.sh managed block: rust/go/ghcup ###"
BLOCK_END="### end setup-Rust-Go-Haskell.sh managed block ###"

log() {
  echo "==> $*"
}

path_prepend() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
}

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
    cat <<EOF
case ":\$PATH:" in
  *":\$HOME/.cargo/bin:"*) ;;
  *) export PATH="\$HOME/.cargo/bin:\$PATH" ;;
esac

case ":\$PATH:" in
  *":${GO_INSTALL_DIR}/go/bin:"*) ;;
  *) export PATH="\$PATH:${GO_INSTALL_DIR}/go/bin" ;;
esac

if [ -f "\$HOME/.ghcup/env" ]; then
  . "\$HOME/.ghcup/env"
fi
EOF
    echo "$BLOCK_END"
  } >> "$bashrc_file"
}

log "Programming Languages setup started"

#---- Rust ----#
if ! command -v cargo >/dev/null 2>&1; then
  log "Install Rust"
  # --no-modify-path: PATH の自動変更を無効化。後で .bashrc の managed block に追記するため
  # -y: 全ての質問にyesで答える
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path -y
else
  log "Rust is already installed. Updating..."
  "$HOME/.cargo/bin/rustup" update
fi

# シェルに反映
path_prepend "$HOME/.cargo/bin"
echo "Rust version:"
cargo --version

#---- Go ----#
if ! command -v go >/dev/null 2>&1 || ! go version | grep -q "$GO_VERSION"; then
  log "Install Go ${GO_VERSION}"
  wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
  sudo rm -rf "${GO_INSTALL_DIR}/go"
  sudo tar -C "${GO_INSTALL_DIR}" -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
else
  log "Go is already installed."
fi

# シェルに反映
case ":$PATH:" in
  *":${GO_INSTALL_DIR}/go/bin:"*) ;;
  *) export PATH="$PATH:${GO_INSTALL_DIR}/go/bin" ;;
esac
echo "Go version:"
go version

#---- Haskell (GHCup) ----#
if ! command -v ghcup >/dev/null 2>&1; then
  log "Install Haskell (via GHCup)"
  # GHCUP_INSTALL_BASE_PREFIX: ~/.ghcup にインストール
  # BOOTSTRAP_HASKELL_INSTALL_HLS: HLS(言語サーバー)も一緒にインストール
  # BOOTSTRAP_HASKELL_NONINTERACTIVE: 非対話モード
  export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
  export BOOTSTRAP_HASKELL_INSTALL_HLS=1
  curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | GHCUP_INSTALL_BASE_PREFIX="$HOME" sh
else
  log "Haskell (GHCup) is already installed."
fi

setup_bashrc_block

# 現在のシェルセッションに設定を反映させる
if [ -f "$HOME/.ghcup/env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.ghcup/env"
fi
echo "GHC version:"
ghc --version
echo "Cabal version:"
cabal --version

log "Programming Languages setup finished."
