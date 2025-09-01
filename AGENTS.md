# Repository Guidelines

## プロジェクト構成 & モジュール

- ルートスクリプト: `AutoSetup.ps1`（二段階セットアップ）, `AutoWindowsUpdate.ps1`（Windows Update ループ）, `Start-Admin.bat`（管理者メニュー起動）。
- 設定: `recipe.yaml` がインストールと設定を駆動。ログ: `AutoSetup.log`, `AutoWindowsUpdate.log`（各スクリプトと同階層）。
- ドキュメント: `README.md`、`ツール未対応の設定手順覚書き/`、`.github/ISSUE_TEMPLATE/`。

## ビルド・テスト・開発コマンド

- メニュー実行（推奨）: `Start-Admin.bat` を右クリック → 「管理者として実行」。
- 更新のみ: `powershell -ExecutionPolicy Bypass -File .\AutoWindowsUpdate.ps1`
- フルセットアップ: `powershell -ExecutionPolicy Bypass -File .\AutoSetup.ps1`
- 実行前に `recipe.yaml` を編集。作業ディレクトリはリポジトリ直下（`$PSScriptRoot` が正しく解決されるように）。

## コーディング規約・命名

- 対象: PowerShell 5.1、インデント4スペース、UTF‑8出力。`try/catch`、`$PSScriptRoot`、`$LASTEXITCODE` の確認を徹底。
- 関数は Verb‑Noun、変数は `camelCase`/`PascalCase`（例: `$TaskName`, `$LogFile`）。
- YAMLキーの既存スキーマ: `windowsSettings`, `wingetInstall`, `appxRemove`, `packageManagers`, `managerName`, `checkCommand`, `installCommand`, `packages`, `name`, `onOff`, `options`, `id`。
- 静的解析（任意）: `Install-Module PSScriptAnalyzer; Invoke-ScriptAnalyzer -Path . -Recurse`。

## テスト指針

- VM/検証端末で実行。先にアップデート、その後セットアップ。ログで警告と非ゼロ終了コードを確認。
- YAMLスキーマ拡張時は README の「Script Structure」と最小例を更新。
- 予定タスクが残らないことを確認: `AutoSetupPhase2Task`, `AutoWindowsUpdateTask`。

## コミット・PR ガイドライン

- コミットは短く命令形。日本語/英語可。例: "AutoWindowsUpdate: 再起動後の再開を修正"。
- PRには目的・要約、関連Issue、確認手順、関連ログ（個人情報は除去）、挙動変更時は `recipe.yaml` の例/差分を含める。
- 変更は最小でデータ駆動（ハードコードより `recipe.yaml`）。挙動やスキーマ変更時はドキュメントも更新。

## セキュリティ/設定ヒント

- 常に管理者で実行。モジュール/`winget` 取得にネットワークが必要。
- リポジトリ外への書き込みは最小化。外部コマンドは `recipe.yaml` の明示設定に限定。

