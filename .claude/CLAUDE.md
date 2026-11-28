# PowerShell-KittingScripts 開発ガイド

<!-- Codex 用の旧 AGENTS.md を、このリポジトリ向けに絞り込んだもの -->

最終的な出力は必ず日本語にする。

## 概要
- Windows 11 PC のキッティング（初期セットアップ）を自動化する PowerShell スクリプト集
- 入口は `Start-Admin.bat`。ここから `AutoWindowsUpdate.ps1` と `AutoSetup.ps1` を呼ぶ
- `AutoSetup.ps1` は同じフォルダの `recipe.yaml` を読む。この 4 つはルート直下から動かさない
- `AutoSetup未対応の設定手順チートシート/`：手順書と WSL 用のシェルスクリプト

## 絶対にしないこと
- `AutoSetup.ps1`・`AutoWindowsUpdate.ps1`・`Start-Admin.bat` を実行しない（作業中の PC が再起動したり、アプリが入れ替わったりする）。動作は構文チェックで確かめる

## 文字コードと改行
守らないと文字化け・動作不良になる。改行は `.gitattributes` で固定している。

| ファイル | 文字コード | 改行 | 理由・注意 |
|---|---|---|---|
| `.ps1` | UTF-8（BOM 付き） | CRLF | BOM がないと PowerShell 5.1 が日本語を正しく読めない |
| `.bat` | Shift-JIS | CRLF | UTF-8 だとコマンドプロンプトで文字化けする。Edit/Write ツールでは編集できないので、文字コードを保つ方法で変える |
| `.sh` | UTF-8 | LF | WSL で実行する |
| `recipe.yaml` | UTF-8 | CRLF | |
| `.html` | UTF-8 | CRLF | `Update-RecipeBuilder.ps1` も CRLF で書き出す |

- Git Bash の `sed -i` は CRLF を LF に変えるので、使うなら `sed -b -i` にする
- 変更後は `git ls-files --eol` で確かめる

## 書き方と確かめ方
- PowerShell 5.1 でも動くようにする。7 専用の書き方（`&&`、`??`、三項演算子など）は使わない
- 管理者権限で実行される前提
- 構文チェックは 5.1 と 7 の両方で行い、結果が 0 になることを確かめる（先に `$errors = $null` を書かないと失敗する）
  ```powershell
  $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'AutoSetup.ps1'), [ref]$null, [ref]$errors) | Out-Null; $errors.Count
  ```
- 可能なら PSScriptAnalyzer（PowerShell の書き方チェックツール）でも確かめる

## 方針
- 個人用ツールなので、必要以上に作り込まない
- 頼まれた範囲の外で問題を見つけたら、勝手に直さず報告し、直すかどうかを確認する
- エラーを握りつぶさず、根本原因を直す。失敗した処理は利用者に分かる形で残す
- README は日本語版と英語版の 2 部構成。片方を直したら、もう片方も同じ内容に直す
- ファイル構成や `recipe.yaml` の書き方を変えたら、README の該当箇所も直す

## セキュリティ
- API キーやパスワードはファイルに書かず、環境変数で渡す
- `recipe.yaml` の `command` はそのまま実行される。外部から受け取った値を混ぜない

## Git
- コンベンショナルコミット形式（feat:, fix:, docs:, refactor:, chore: など）で、英語で書く
- 1 コミットには 1 つの変更だけを入れる
- main ブランチへ直接コミットしてよい（作業用ブランチは作らない）
- `git push --force` はしない
