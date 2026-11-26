# PowerShell-KittingScripts 開発ガイド

<!-- 以前あった Codex 用の AGENTS.md を元に、このリポジトリ向けに絞り込んだもの -->

思考は英語で行い、最終的な出力は必ず日本語で提供してください。

## このリポジトリについて
- Windows 11 PC のキッティング（初期セットアップ）を自動化する PowerShell スクリプト集
- 入口は `Start-Admin.bat`。`AutoWindowsUpdate.ps1` と `AutoSetup.ps1` を呼び出す
- `AutoSetup.ps1` は、同じフォルダにある `recipe.yaml` を読んで動く。この3つと `recipe.yaml` は、ルート直下から動かさない
- `AutoSetup未対応の設定手順チートシート/` には、手順書と WSL 用のシェルスクリプトがある

## 絶対にしないこと
- `AutoSetup.ps1`・`AutoWindowsUpdate.ps1`・`Start-Admin.bat` を実行しない。作業中の PC が再起動したり、アプリが入れ替わったりする
- 動作の確認は、実行ではなく構文チェックで行う（下の「確かめ方」）

## 文字コードと改行（守らないと文字化け・動作不良になる）
- `.ps1`：UTF-8（BOM 付き）、改行 CRLF。PowerShell 5.1 で日本語を正しく読むために BOM が必要
- `.bat`：Shift-JIS、改行 CRLF。UTF-8 にするとコマンドプロンプトで文字化けする。Edit/Write ツールでは編集できないので、文字コードを保つ方法で変更する
- `.sh`：UTF-8、改行 LF（WSL で実行するため）
- `recipe.yaml`：UTF-8、改行 CRLF
- `.html`：UTF-8、改行 LF（`Update-RecipeBuilder.ps1` が LF で書き出すため）
- 改行の扱いは `.gitattributes` で固定している。Git Bash の `sed -i` は CRLF を LF に変えてしまうので、使うなら `sed -b -i` にする。変更後は `git ls-files --eol` で確かめる

## 動作環境
- PowerShell 5.1 でも動くこと。PowerShell 7 にしかない書き方（`&&`、`??`、三項演算子など）は使わない
- 管理者権限で実行される前提

## 確かめ方
- 構文チェック（PowerShell 5.1 と 7 の両方で行う）:
  `$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'AutoSetup.ps1'), [ref]$null, [ref]$errors) | Out-Null; $errors.Count` を実行し、0 であることを確認する（`$errors = $null` で先に変数を作っておかないと失敗する）
- 可能なら PSScriptAnalyzer（PowerShell の書き方チェックツール）でも確認する

## ドキュメント
- README は日本語版と英語版の2部構成。片方を直したら、もう片方も同じ内容に直す
- ファイル構成や `recipe.yaml` の書き方を変えたら、README の該当箇所も直す

## 開発の基本方針
- このリポジトリは個人用ツールなので、必要以上に作り込まない
- 頼まれた範囲の外で問題を見つけたら、勝手に直さず報告し、直すかどうかを確認する
- エラーを握りつぶさず、根本原因を直す。失敗した処理は利用者に分かる形で残す

## セキュリティ
- API キーやパスワードはファイルに直接書かない（環境変数で渡す）
- `recipe.yaml` の `command` はそのまま実行される。外部から受け取った値を混ぜない

## Git 運用
- コンベンショナルコミット形式（feat:, fix:, docs:, refactor:, chore: など）で、英語のメッセージを書く
- 1コミットには1つの変更だけを入れる
- main ブランチへ直接コミットしてよい（作業用ブランチは作らない）
- `git push --force` はしない
