#!/usr/bin/env bash

# WSL(Ubuntu) の初期設定を最小手順で実行するエントリスクリプトです。

# 1) 開発基盤
chmod +x setup-wsl-ubuntu-codex.sh
bash setup-wsl-ubuntu-codex.sh

# 2) 言語環境（Rust / Go / Haskell）
chmod +x setup-wsl-Rust-Go-Haskell.sh
bash setup-wsl-Rust-Go-Haskell.sh
