#!/usr/bin/env bash
set -euo pipefail

echo "==> Programming Languages setup started"

COMMONRC_FILE="$HOME/.commonrc"
touch "$COMMONRC_FILE" # ファイルがなければ作成

#---- Rust ----#
if ! command -v cargo >/dev/null 2>&1; then
  echo "==> Install Rust"
  # --no-modify-path: PATHの自動変更を無効化。後で手動で .commonrc に追記するため
  # -y: 全ての質問にyesで答える
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path -y
  
  # RustのPATH設定を .commonrc に書き込む (なければ)
  if ! grep -q "$HOME/.cargo/bin" "$COMMONRC_FILE"; then
    echo -e '\n# Rust (cargo) path' >> "$COMMONRC_FILE"
    echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\"" >> "$COMMONRC_FILE"
  fi
else
  echo "==> Rust is already installed. Updating..."
  "$HOME/.cargo/bin/rustup" update
fi

# シェルに反映
export PATH="$HOME/.cargo/bin:$PATH"
echo "Rust version:"
cargo --version

#---- Go ----#
GO_VERSION="1.22.5"
GO_INSTALL_DIR="/usr/local"
if ! command -v go >/dev/null 2>&1 || ! go version | grep -q "$GO_VERSION"; then
  echo "==> Install Go ${GO_VERSION}"
  wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
  sudo rm -rf "${GO_INSTALL_DIR}/go"
  sudo tar -C "${GO_INSTALL_DIR}" -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
  
  # GoのPATH設定を .commonrc に書き込む (なければ)
  if ! grep -q "${GO_INSTALL_DIR}/go/bin" "$COMMONRC_FILE"; then
    echo -e '\n# Go path' >> "$COMMONRC_FILE"
    echo "export PATH=\"\$PATH:${GO_INSTALL_DIR}/go/bin\"" >> "$COMMONRC_FILE"
  fi
else
  echo "==> Go is already installed."
fi

# シェルに反映
export PATH="$PATH:${GO_INSTALL_DIR}/go/bin"
echo "Go version:"
go version

#---- Haskell (GHCup) ----#
if ! command -v ghcup >/dev/null 2>&1; then
  echo "==> Install Haskell (via GHCup)"
  # GHCUP_INSTALL_BASE_PREFIX: ~/.ghcup にインストール
  # BOOTSTRAP_HASKELL_INSTALL_HLS: HLS(言語サーバー)も一緒にインストール
  # BOOTSTRAP_HASKELL_NONINTERACTIVE: 非対話モード
  export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
  export BOOTSTRAP_HASKELL_INSTALL_HLS=1
  curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | GHCUP_INSTALL_BASE_PREFIX="$HOME" sh

  # GHCupのインストール後、手動でPATH設定を .commonrc に追記する (なければ)
  GHCUP_PATH_SNIPPET="[ -f \"\$HOME/.ghcup/env\" ] && source \"\$HOME/.ghcup/env\""
  if ! grep -qF "$GHCUP_PATH_SNIPPET" "$COMMONRC_FILE"; then
    echo "--> Adding GHCup env to .commonrc"
    echo -e '\n# Haskell (GHCup)' >> "$COMMONRC_FILE"
    echo "$GHCUP_PATH_SNIPPET" >> "$COMMONRC_FILE"
  fi
else
  echo "==> Haskell (GHCup) is already installed."
fi

# 現在のシェルセッションに設定を反映させる
if [ -f "$HOME/.ghcup/env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.ghcup/env"
fi
echo "GHC version:"
ghc --version
echo "Cabal version:"
cabal --version

echo "==> Programming Languages setup finished."
