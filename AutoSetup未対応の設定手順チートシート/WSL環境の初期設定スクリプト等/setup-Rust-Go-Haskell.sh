#!/usr/bin/env bash
# WSL Ubuntu に Rust（rustup）・Go・Haskell（GHCup）を入れる。
# 何度実行しても同じ状態になる（導入済みなら Rust は更新、Go は指定バージョンでなければ入れ直す）。
# 使い方: bash setup-Rust-Go-Haskell.sh   または   curl -fsSL <raw URL> | bash
set -euo pipefail

GO_VERSION="1.27.4"
GO_INSTALL_DIR="/usr/local"
GO_BIN="${GO_INSTALL_DIR}/go/bin"
CARGO_BIN="$HOME/.cargo/bin"
GHCUP_ENV="$HOME/.ghcup/env"
# 既存の ~/.bashrc から古いブロックを消すために使うので、文字列は変えないこと
BLOCK_START="### setup-Rust-Go-Haskell.sh managed block: rust/go/ghcup ###"
BLOCK_END="### end setup-Rust-Go-Haskell.sh managed block ###"

#---- 共通ヘルパー（curl | bash で単体実行するため、各スクリプトに同じものを持つ）----#
log()  { printf '==> %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

path_append() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$PATH:$1" ;;
  esac
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
install_rust() {
  # curl | bash は ~/.bashrc を読まないので、導入済みかを調べる前に PATH を通しておく
  path_prepend "$CARGO_BIN"
  if has rustup; then
    log "Rust is already installed. Updating..."
    rustup update
  else
    log "Install Rust"
    # --no-modify-path: PATH は下の managed block で管理するので、インストーラーには触らせない
    # -y: すべての質問に yes で答える
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path -y
  fi
  echo "Rust version:"
  cargo --version
}

install_go() {
  path_append "$GO_BIN"
  # 出力例: "go version go1.27.4 linux/amd64"。1.27.40 などを誤って一致させないよう、前後の区切りまで比べる
  if has go && [[ "$(go version)" == *" go${GO_VERSION} "* ]]; then
    log "Go ${GO_VERSION} is already installed."
  else
    log "Install Go ${GO_VERSION}"
    local tarball
    tarball="$(mktemp --suffix=.tar.gz)"
    if ! curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o "$tarball"; then
      rm -f "$tarball"
      die "Failed to download Go ${GO_VERSION}."
    fi
    sudo rm -rf "${GO_INSTALL_DIR}/go"
    sudo tar -C "$GO_INSTALL_DIR" -xzf "$tarball"
    rm -f "$tarball"
  fi
  echo "Go version:"
  go version
}

load_ghcup_env() {
  if [[ -f "$GHCUP_ENV" ]]; then
    # shellcheck disable=SC1090
    . "$GHCUP_ENV"
  fi
}

install_haskell() {
  load_ghcup_env
  if has ghcup; then
    log "Haskell (GHCup) is already installed."
  else
    log "Install Haskell (via GHCup)"
    # BOOTSTRAP_HASKELL_NONINTERACTIVE: 非対話モード
    # BOOTSTRAP_HASKELL_INSTALL_HLS: HLS（言語サーバー）も一緒に入れる
    # GHCUP_INSTALL_BASE_PREFIX: ~/.ghcup に入れる
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org \
      | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
        BOOTSTRAP_HASKELL_INSTALL_HLS=1 \
        GHCUP_INSTALL_BASE_PREFIX="$HOME" \
        sh
    load_ghcup_env
  fi
  echo "GHC version:"
  ghc --version
  echo "Cabal version:"
  cabal --version
}

setup_bashrc() {
  log "Setting up bash config (~/.bashrc)"
  # 新しい bash セッションで Rust / Go / GHCup が使えるようにする（GO_INSTALL_DIR だけは今の値で埋め込む）
  local body
  body="$(cat <<EOF
case ":\$PATH:" in
  *":\$HOME/.cargo/bin:"*) ;;
  *) export PATH="\$HOME/.cargo/bin:\$PATH" ;;
esac

case ":\$PATH:" in
  *":${GO_BIN}:"*) ;;
  *) export PATH="\$PATH:${GO_BIN}" ;;
esac

if [ -f "\$HOME/.ghcup/env" ]; then
  . "\$HOME/.ghcup/env"
fi
EOF
)"
  write_bashrc_block "$BLOCK_START" "$BLOCK_END" "$body"
}

# 処理はすべて main から呼ぶ。curl | bash の途中でダウンロードが切れても、中途半端に実行されないようにするため
main() {
  log "Programming Languages setup started"
  install_rust
  install_go
  install_haskell
  setup_bashrc
  log "Programming Languages setup finished."
}

main "$@"
