# Windows PC キッティング自動化スクリプト

Windows PCのキッティング（初期セットアップ）から開発環境構築までの一連の作業を自動化するPowerShellスクリプト群です。

**`recipe.yaml`** に設定を定義し **`Start-Admin.bat`** を管理者権限で実行するだけで、手作業による時間のかかるセットアップ作業を大幅に削減し、誰でも一貫性のある環境を迅速に構築できます。

<p align="center">
<img src="./images/launcher-screenshot.png" alt="コマンドプロンプトのランチャー画面" width="70%">
</p>

## 主な機能

- **Windows Updateの完全自動化**: 更新プログラムがなくなるまで、確認・インストール・再起動を無人で繰り返します。
- **柔軟なアプリケーション管理**: `winget` を利用し、`recipe.yaml` に基づいてアプリの一括インストールや不要なプリインストールアプリの削除を行います。
- **開発環境の自動構築**: `recipe.yaml` で定義された `code` (VSCode拡張機能)、 `npm` (Node.js) 、 `pip` (Python) などのパッケージマネージャーを通じて、開発用ライブラリを一括でインストールします。
- **設定ファイルによる柔軟なシステム構築**: エクスプローラーの拡張子表示などのシステム設定を`recipe.yaml`に直接記述することで、スクリプトを編集することなく柔軟に設定を変更できます。
- **安定した2フェーズ実行**: アプリインストール（フェーズ1）と、PATH環境変数を参照する開発ツール（フェーズ2）の間に再起動を挟むことで、安定した動作を保証します。
- **対話的な操作メニュー**: `Start-Admin.bat` を実行するだけで、ユーザーはメニューから実行したい処理を簡単に選択できます。

## 推奨ワークフロー

1.  **OSのクリーンインストール**: Windows 11をクリーンインストールします。
2.  **リポジトリの配置**: このリポジトリをダウンロードし、フォルダをPCの任意の場所（例: `C:\Work`）に配置します。USBメモリ、外付けストレージ内で実行しても基本的に安全です。
3.  **設定ファイルの編集**: `recipe.yaml` をテキストエディタで開き、不要な項目を行頭に `#` を付けてコメントアウトし、自分の好みに合わせて編集します。
4.  **スクリプトの実行**:
    1.  `Start-Admin.bat` を**右クリック**し、「**管理者として実行**」を選択します。
    2.  メニューから `1. AutoWindowsUpdate` を選択し、OSを最新の状態にします。（**強く推奨**）
    3.  処理が完了したら、再度 `Start-Admin.bat` を管理者として実行します。
    4.  メニューから `2. AutoSetup` を選択し、アプリケーションのインストールと環境構築を開始します。
5.  **最終確認**:
    - すべての自動処理が完了したら、PCを一度手動で再起動します。
    - Windows Updateの画面やデバイスマネージャーを開き、更新漏れや不明なデバイスがないか最終確認を行います。

## スクリプト構成

| ファイル名 | 役割 |
|---|---|
| `Start-Admin.bat` | **起点となるファイル。** 管理者権限を確認し、対話形式で実行するスクリプトを選択させます。 |
| `AutoWindowsUpdate.ps1` | Windows Updateを全自動で実行します。更新がなくなるまで、更新の確認・インストール・再起動を繰り返します。 |
| `AutoSetup.ps1` | `recipe.yaml` に基づき、アプリのインストール、システム設定、開発環境の構築を2フェーズ（再起動を挟む）に分けて実行します。 |
| `recipe.yaml` | **カスタマイズの中心。** インストールするアプリ、システム設定、開発パッケージなどを、コメント付きで分かりやすく定義します。 |
| `template-recipes/` | `recipe.yaml` のテンプレート集。代表的な構成例をフォルダ単位で保持し、必要に応じてコピーして利用できます。 |
| `キッティング手順.txt` | 自動化スクリプトを使用する際の、手動作業を含めた全体的な作業フローのメモです。 |
| `AutoSetup未対応の設定手順チートシート/` | スクリプトによる自動化範囲外の、各種手動設定に関する手順書が格納されています。（例: Hyper-V、WSL2のセットアップなど） |

## カスタマイズ

セットアップ内容は `recipe.yaml` を編集することで自由にカスタマイズできます。不要な項目は行頭に `#` を付けてコメントアウトしてください。

## 実行場所ごとの注意点

### ローカル固定ディスク（例: `C:` / `D:`）
- 最も安全です。再起動後もパスが安定して参照できます。

### USBメモリ／外付けストレージ
- 基本的に安全ですが、再起動やログオン後も同じドライブレターでマウントされ続ける必要があります。
- 取り外しやレター変更が発生するとフェーズ2や再開処理が開始できません。失敗した場合はドライブを接続し直し、手動で再実行してください。

### Active Directory管理のファイルサーバー共有
- UNCパス上でも実行できますが、共有への書き込み権限と安定した接続が必須です。
- ログオン時に自動再接続されない環境ではタスクスケジューラがスクリプトを見つけられず失敗します。必要に応じてローカルにコピーしてから実行してください。

### NAS共有
- 基本的な制約はファイルサーバー共有と同じです。
- NASのスリープや再接続遅延によりタスクが失敗することがあります。長時間処理が続く場合はローカルディスクでの実行を検討してください。

### フェーズ1 (`phase1`)

再起動前に実行される基本的なシステムセットアップを定義します。

- `windowsSettings`: レジストリ変更を伴うシステム設定を、`description`と`command`キーで定義します。
- `wingetInstall`: `winget` でインストールするアプリのIDと、必要に応じてインストールオプションを記述します。
- `appxRemove`: 削除したいWindows標準アプリの名称（ワイルドカード使用可）を記述します。

### フェーズ2 (`phase2`)

再起動後に実行される開発者向けパッケージのインストールを定義します。

- `packageManagers`: 複数のパッケージマネージャーをリスト形式で定義します。
  - `managerName`: ログに表示される管理ツールの名前です（例: 'npm', 'pip'）。
  - `checkCommand`: パッケージがインストール済みか確認するためのコマンドです。`{package}` というプレースホルダーがパッケージ名に置換されます。
  - `installCommand`: パッケージをインストールするためのコマンドです。`{package}` が置換されます。
  - `packages`: このマネージャーでインストールするパッケージのリストです。

**設定例 (`recipe.yaml`):**
```yaml
phase2:
  packageManagers:
    - managerName: 'vscode'
      checkCommand: 'code --list-extensions | findstr /i /c:"{package}"'
      installCommand: 'code --install-extension {package}'
      packages:
        # [UI / 表示]
        - description: 'UIの日本語化'
          name: ms-ceintl.vscode-language-pack-ja
        - description: 'インデントを色付け'
          name: oderwat.indent-rainbow
        - description: '全角スペースをハイライト'
          name: mosapride.zenkaku
        - description: 'コメントを種類別に色分け'
          name: aaron-bond.better-comments
        - description: 'エラー/警告を行内表示'
          name: usernamehw.errorlens
        - description: 'EditorConfig（書式統一）'
          name: EditorConfig.EditorConfig
        # [ユーティリティ / Markdown]
        - description: '印刷（コード/Markdown をブラウザ経由で印刷・PDF化）'
          name: pdconsec.vscode-print
        - description: 'Markdown編集サポート'
          name: yzhang.markdown-all-in-one
        - description: 'TODOコメントの一覧表示'
          name: gruntfuggly.todo-tree
        - description: 'ファイルパス入力補完'
          name: christian-kohler.path-intellisense
        - description: 'dotenvファイル支援'
          name: mikestead.dotenv
```

## テンプレートレシピの活用

`template-recipes/` ディレクトリには、フェーズや目的別に分かれたサンプル `recipe.yaml` が格納されています。`step1_only_basic/` のようにフェーズ1のみを含む最小構成から、`step1_only_dev/` のような本格的な開発者向け環境、 `step2_VSCode/`や`step2_Rust/` のように開発言語・ツール別の拡張セットまで揃っています。環境構築のたたき台がほしい場合は、近い構成のテンプレートをリポジトリ直下にコピーし、自分の要件に合わせて調整してから `AutoSetup.ps1` を実行してください。

## Winget Configurationとの違い

Microsoftが提供する `winget configuration` は、宣言的な環境構築の標準機能として非常に強力です。しかし、このプロジェクトは特定のワークフローをより深く自動化するために、いくつかのユニークな機能を提供します。

1.  **Windows Updateの自動ループ**
    `winget configuration` は基本的に一度きりの実行ですが、このプロジェクトの `AutoWindowsUpdate.ps1` は、**更新がなくなるまで「更新チェック → インストール → 再起動」のサイクルを自律的に繰り返します。** これはタスクスケジューラを活用することで実現しており、一度実行すれば完全に最新の状態になるまで無人で処理を継続できる強力な機能です。

2.  **安定性を重視した厳密な2フェーズ実行**
    `winget configuration` でも再起動は扱えますが、このスクリプトは**PATH環境変数の問題を確実に回避するため、アーキテクチャとして「システム変更」と「開発ツール導入」の間に必ず再起動を挟む**厳格な2フェーズ構造を採用しています。これにより、フェーズ2で`npm`や`uv`などのコマンドが「見つからない」といったトラブルを根本的に防止します。

3.  **対話的な操作メニューによるユーザー体験**
    `winget configuration` はコマンドラインベースのツールですが、このプロジェクトは `Start-Admin.bat` を起点とするシンプルなメニューを提供します。これにより、PowerShellに不慣れなユーザーでも、「1. まずはアップデート」「2. 次にセットアップ」というように、**迷うことなく直感的に操作を進めることが可能**です。

4.  **拡張が容易なパッケージマネージャー定義**
    `npm`や`pip`といったパッケージのインストールロジックは、`recipe.yaml`で直接定義できます。ユーザーは`checkCommand`や`installCommand`を設定ファイルに記述するだけで、**スクリプトを編集することなく、`cargo` (Rust)のような新しいパッケージマネージャーを自由に追加できます。** これにより、プロジェクトの要求に合わせてツールチェーンを柔軟に拡張できる高い保守性を実現しています。

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。

---
# Windows PC Kitting Automation Scripts (English)

This repository provides a collection of PowerShell scripts that automate the entire workflow from Windows PC kitting (initial provisioning) to development environment setup.

Define your settings in **`recipe.yaml`** and simply run **`Start-Admin.bat`** with administrative privileges to dramatically cut down on time-consuming manual setup while letting anyone build a consistent environment quickly.

<p align="center">
<img src="./images/launcher-screenshot.png" alt="Launcher menu in Command Prompt" width="70%">
</p>

## Key Features

- **Fully automated Windows Update**: Checks, installs, and reboots unattended until no updates remain.
- **Flexible application management**: Leverages `winget` to batch-install apps and remove unwanted preinstalled software based on `recipe.yaml`.
- **Automated development environment provisioning**: Installs development libraries at once via package managers defined in `recipe.yaml`, such as `code` (VS Code extensions), `npm` (Node.js), and `pip` (Python).
- **Configuration-driven system setup**: Describe system tweaks directly in `recipe.yaml`—for example, file extension visibility—so you can adjust behavior without editing scripts.
- **Reliable two-phase execution**: Inserts a reboot between the app installation phase and the development tool phase to ensure stable behavior.
- **Interactive menu-driven experience**: Running `Start-Admin.bat` lets users choose tasks from a simple menu with minimal PowerShell knowledge.

## Recommended Workflow

1.  **Perform a clean OS installation**: Install Windows 11 fresh.
2.  **Place the repository**: Download this repository and put the folder anywhere on the PC (e.g., `C:\Work`). It also runs safely from a USB drive or other external storage.
3.  **Edit the configuration file**: Open `recipe.yaml` in a text editor. Comment out unnecessary entries with `#` and tailor it to your preferences.
4.  **Run the scripts**:
    1.  Right-click `Start-Admin.bat` and choose **Run as administrator**.
    2.  From the menu, select `1. AutoWindowsUpdate` to bring the OS fully up to date (**strongly recommended**).
    3.  After it finishes, run `Start-Admin.bat` as administrator again.
    4.  Select `2. AutoSetup` from the menu to begin app installation and environment provisioning.
5.  **Final checks**:
    - After all automated tasks finish, restart the PC manually once.
    - Open Windows Update and Device Manager to confirm there are no missing updates or unknown devices.

## Script Structure

| File Name | Role |
|---|---|
| `Start-Admin.bat` | **Entry point.** Confirms administrative privileges and lets you pick scripts interactively. |
| `AutoWindowsUpdate.ps1` | Runs Windows Update end-to-end. Repeats checking, installing, and rebooting until nothing remains. |
| `AutoSetup.ps1` | Executes app installation, system tweaks, and development environment setup in two phases (with a reboot in between) based on `recipe.yaml`. |
| `recipe.yaml` | **Customization hub.** Defines apps to install, system settings, development packages, and more with explanatory comments. |
| `template-recipes/` | Template collection for `recipe.yaml`. Stores representative examples arranged by folder so you can copy and adapt them. |
| `キッティング手順.txt` | Notes covering the full operational flow, including manual steps when using the automation scripts. |
| `AutoSetup未対応の設定手順チートシート/` | Guides for manual tasks outside the automation scope (e.g., Hyper-V, WSL2 setup). |

## Customization

You can freely customize the setup by editing `recipe.yaml`. Comment out any unnecessary entries with `#`.

## Location-Specific Considerations

### Local fixed drives (e.g., `C:` / `D:`)
- Safest option. Paths remain stable after reboots.

### USB drives / external storage
- Generally safe, but the volume must stay mounted under the same drive letter after reboots or logons.
- If the drive is removed or the letter changes, phase 2 or resume processing cannot start. Reattach the drive and rerun manually if a failure occurs.

### Active Directory-managed file shares
- Works over UNC paths, but requires write permissions and a stable connection.
- In environments where the share does not reconnect automatically on logon, Task Scheduler cannot find the scripts. Copy them locally first if needed.

### NAS shares
- Follow constraints similar to file shares.
- NAS sleep or reconnection delays may cause tasks to fail. When running long processes, consider executing from a local disk.

### Phase 1 (`phase1`)

Defines the fundamental system setup that runs before the reboot.

- `windowsSettings`: Describe system tweaks (including registry edits) with `description` and `command`.
- `wingetInstall`: List `winget` app IDs and optional install arguments.
- `appxRemove`: List the built-in Windows app names (supports wildcards) you want to remove.

### Phase 2 (`phase2`)

Defines developer-oriented package installation executed after the reboot.

- `packageManagers`: List multiple package managers as objects.
  - `managerName`: Label shown in logs (e.g., 'npm', 'pip').
  - `checkCommand`: Command used to verify whether a package is installed. `{package}` is substituted with the package name.
  - `installCommand`: Command used to install a package. `{package}` is replaced accordingly.
  - `packages`: Array of packages to install with that manager.

**Example configuration (`recipe.yaml`):**
```yaml
phase2:
  packageManagers:
    - managerName: 'vscode'
      checkCommand: 'code --list-extensions | findstr /i /c:"{package}"'
      installCommand: 'code --install-extension {package}'
      packages:
        # [UI / Display]
        - description: 'Japanese UI localization'
          name: ms-ceintl.vscode-language-pack-ja
        - description: 'Colorize indentation'
          name: oderwat.indent-rainbow
        - description: 'Highlight full-width spaces'
          name: mosapride.zenkaku
        - description: 'Colorize comments by type'
          name: aaron-bond.better-comments
        - description: 'Inline error / warning display'
          name: usernamehw.errorlens
        - description: 'EditorConfig (format consistency)'
          name: EditorConfig.EditorConfig
        # [Utilities / Markdown]
        - description: 'Print via browser to paper / PDF'
          name: pdconsec.vscode-print
        - description: 'Markdown authoring support'
          name: yzhang.markdown-all-in-one
        - description: 'TODO comment overview'
          name: gruntfuggly.todo-tree
        - description: 'File path completion'
          name: christian-kohler.path-intellisense
        - description: 'dotenv support'
          name: mikestead.dotenv
```

## Using Template Recipes

The `template-recipes/` directory contains sample `recipe.yaml` files grouped by phase and purpose. They range from minimal configurations such as `step1_only_basic/`, to developer-focused setups like `step1_only_dev/`, and language/tool-specific add-ons like `step2_VSCode/` or `step2_Rust/`. Copy the template closest to your desired environment to the repository root, adjust it to your needs, and then run `AutoSetup.ps1`.

## How This Differs from Winget Configuration

Microsoft's `winget configuration` is a powerful declarative option, but this project offers several unique capabilities to automate a specific workflow more deeply.

1.  **Automated Windows Update Loop**
    While `winget configuration` typically runs once, `AutoWindowsUpdate.ps1` **autonomously loops through "check for updates → install → reboot" until no updates remain.** It leverages Task Scheduler so that once invoked, it continues unattended until the system is fully patched.

2.  **Strict Two-Phase Execution for Stability**
    `winget configuration` can handle reboots, but this project **guarantees avoidance of PATH-related issues by architecting a strict two-phase flow with an enforced reboot between "system changes" and "developer tool installation".** That prevents scenarios where commands such as `npm` or `uv` are unavailable in phase 2.

3.  **Interactive Menu-Driven User Experience**
    `winget configuration` is command-line only, whereas this project provides a simple menu starting from `Start-Admin.bat`. Even users unfamiliar with PowerShell can intuitively follow "1. Update first" → "2. Then run setup".

4.  **Easily Extensible Package Manager Definitions**
    Installation logic for package managers like `npm` or `pip` is defined directly in `recipe.yaml`. Users just specify `checkCommand` and `installCommand` in the configuration to **add new managers such as `cargo` (Rust) without touching the scripts.** This delivers high maintainability by letting you extend the toolchain to match project needs.

## License

This project is released under the [MIT License](LICENSE).
