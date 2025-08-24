[日本語](#japanese) | [English](#english)

<a name="japanese"></a>

# Windows PC キッティング自動化スクリプト

Windows PCのキッティング（初期セットアップ）から開発環境構築までの一連の作業を自動化するPowerShellスクリプト群です。

**`recipe.yaml`** に設定を定義するだけで、手作業による時間のかかるセットアップ作業を大幅に削減し、誰でも一貫性のある環境を迅速に構築できます。

## 主な機能

- **Windows Updateの完全自動化**: 更新プログラムがなくなるまで、確認・インストール・再起動を無人で繰り返します。
- **柔軟なアプリケーション管理**: `winget` を利用し、`recipe.yaml` に基づいてアプリの一括インストールや不要なプリインストールアプリの削除を行います。
- **開発環境の自動構築**: `recipe.yaml` で定義された `npm` (Node.js) や `pip` (Python) などのパッケージマネージャーを通じて、開発用ライブラリを一括でインストールします。
- **システム設定のデータ駆動化**: エクスプローラーの拡張子表示などのシステム設定を`recipe.yaml`に直接記述することで、スクリプトを編集することなく柔軟に設定を変更できます。
- **安定した2フェーズ実行**: アプリインストール（フェーズ1）と、PATH環境変数を参照する開発ツール（フェーズ2）の間に再起動を挟むことで、安定した動作を保証します。
- **対話的な操作メニュー**: `Start-Admin.bat` を実行するだけで、ユーザーはメニューから実行したい処理を簡単に選択できます。

## Winget Configurationとの違い

Microsoftが提供する `winget configuration` は、宣言的な環境構築の標準機能として非常に強力です。しかし、このプロジェクトは特定のワークフローをより深く自動化するために、いくつかのユニークな機能を提供します。

1.  **Windows Updateの自動ループ**
    `winget configuration` は基本的に一度きりの実行ですが、このプロジェクトの `AutoWindowsUpdate.ps1` は、**更新がなくなるまで「更新チェック → インストール → 再起動」のサイクルを自律的に繰り返します。** これはタスクスケジューラを活用することで実現しており、一度実行すれば完全に最新の状態になるまで無人で処理を継続できる強力な機能です。

2.  **安定性を重視した厳密な2フェーズ実行**
    `winget configuration` でも再起動は扱えますが、このスクリプトは**PATH環境変数の問題を確実に回避するため、アーキテクチャとして「システム変更」と「開発ツール導入」の間に必ず再起動を挟む**厳格な2フェーズ構造を採用しています。これにより、フェーズ2で`npm`や`uv`などのコマンドが「見つからない」といったトラブルを根本的に防止します。

3.  **対話的な操作メニューによるユーザー体験**
    `winget configuration` はコマンドラインベースのツールですが、このプロジェクトは `Start-Admin.bat` を起点とするシンプルなメニューを提供します。これにより、PowerShellに不慣れなユーザーでも、「1. まずはアップデート」「2. 次にセットアップ」というように、**迷うことなく直感的に操作を進めることが可能**です。

4.  **拡張が容易なパッケージマネージャー定義**
    `npm`や`pip`といったパッケージのインストールロジックは、`recipe.yaml`で直接定義できます。ユーザーは`checkCommand`や`installCommand`を設定ファイルに記述するだけで、**スクリプトを編集することなく、`cargo` (Rust)や`gem` (Ruby)のような新しいパッケージマネージャーを自由に追加できます。** これにより、プロジェクトの要求に合わせてツールチェーンを柔軟に拡張できる高い保守性を実現しています。

## 推奨ワークフロー

1.  **OSのクリーンインストール**: Windows 11をクリーンインストールします。
2.  **リポジトリの配置**: このリポジトリのファイルをPCの任意の場所（例: `C:\Work`）に配置します。
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
| `Start-Admin.bat` | **起点となるファイル。** 管理者権限を確認し、対話形式で実行するスクリプトを選択させます。（メモ帳などで開くと文字化けすることがありますが、実行には影響ありません） |
| `AutoWindowsUpdate.ps1` | Windows Updateを全自動で実行します。更新がなくなるまで、更新の確認・インストール・再起動を繰り返します。 |
| `AutoSetup.ps1` | `recipe.yaml` に基づき、アプリのインストール、システム設定、開発環境の構築を2フェーズ（再起動を挟む）に分けて実行します。 |
| `recipe.yaml` | **カスタマイズの中心。** インストールするアプリ、システム設定、開発パッケージなどを、コメント付きで分かりやすく定義します。 |
| `.gitignore` | ログファイルなど、Gitの管理対象から除外するファイルを指定します。 |
| `キッティング手順.txt` | 自動化スクリプトを使用する際の、手動作業を含めた全体的な作業フローのメモです。 |
| `ツール未対応の設定手順覚書き/` | スクリプトによる自動化範囲外の、各種手動設定に関する手順書が格納されています。（例: Hyper-V、WSL2のセットアップなど） |

## カスタマイズ

セットアップ内容は `recipe.yaml` を編集することで自由にカスタマイズできます。不要な項目は行頭に `#` を付けてコメントアウトしてください。また[onOff: true/false]でオンオフの切り替えができます。

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
    - managerName: 'npm'
      checkCommand: 'npm list -g {package} --depth=0'
      installCommand: 'npm install -g {package}'
      packages:
        - name: typescript
        - name: eslint
    - managerName: 'pip'
      checkCommand: 'uv pip show {package}'
      installCommand: 'uv pip install {package} --system'
      packages:
        - name: jupyterlab
        - name: numpy
```

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。

---
Copyright (c) 2025 sin4auto

---

<a name="english"></a>

# English

## Overview

This is a collection of PowerShell scripts designed to automate the entire process of Windows PC kitting, from initial setup to configuring a development environment.

By simply defining your desired setup in the **`recipe.yaml`** file, you can dramatically reduce time-consuming manual work and enable anyone to build a consistent, ready-to-use environment quickly.

## Key Features

- **Fully Automated Windows Updates**: Unattended, it repeatedly checks for updates, installs them, and reboots until the system is completely up-to-date.
- **Flexible Application Management**: Uses `winget` to batch install applications and remove unwanted pre-installed apps based on `recipe.yaml`.
- **Automated Development Environment Setup**: Installs development libraries in bulk through package managers like `npm` (Node.js) and `pip` (Python), as defined in `recipe.yaml`.
- **Data-Driven System Configuration**: System settings, like showing file extensions in Explorer, can be written directly in `recipe.yaml`, allowing for flexible configuration changes without editing scripts.
- **Stable Two-Phase Execution**: Guarantees stable operation by enforcing a reboot between Phase 1 (application installation) and Phase 2 (development tools that rely on PATH variables).
- **Interactive Operation Menu**: By running `Start-Admin.bat`, users can easily select the process they want to execute from a simple menu.

## Comparison with Winget Configuration

While Microsoft's `winget configuration` is a powerful standard for declarative setup, this project offers several unique features to more deeply automate specific workflows.

1.  **Autonomous Windows Update Loop**
    `winget configuration` is typically a one-shot execution. In contrast, this project's `AutoWindowsUpdate.ps1` **autonomously repeats the "check -> install -> reboot" cycle until no more updates are found.** This is achieved using the Task Scheduler, providing a powerful feature that allows the process to run unattended until the PC is fully updated.

2.  **Strict Two-Phase Execution for Stability**
    While `winget configuration` can handle reboots, this script employs a **strict two-phase architecture that enforces a reboot between system changes and development tool installations to reliably avoid PATH environment variable issues.** This fundamentally prevents problems where commands like `npm` or `uv` are "not found" in Phase 2.

3.  **User-Friendly Interactive Menu**
    `winget configuration` is a command-line tool. This project provides a simple menu launched from `Start-Admin.bat`, allowing even users unfamiliar with PowerShell to **intuitively proceed with the steps without hesitation**, such as "1. Update first," then "2. Setup next."

4.  **Easily Extensible Package Manager Definitions**
    The installation logic for package managers like `npm` and `pip` is defined directly in `recipe.yaml`. Users can **add new package managers like `cargo` (Rust) or `gem` (Ruby) without editing the script, simply by writing the `checkCommand` and `installCommand` in the configuration file.** This provides high maintainability, allowing the toolchain to be flexibly extended to meet project requirements.

## Recommended Workflow

1.  **Perform a Clean OS Install**: Perform a clean installation of Windows 11.
2.  **Place the Repository**: Place the files from this repository anywhere on your PC (e.g., `C:\Work`).
3.  **Edit the Configuration File**: Open `recipe.yaml` in a text editor, comment out any unwanted items by adding a `#` at the beginning of the line, and customize it to your preferences.
4.  **Run the Scripts**:
    1.  **Right-click** on `Start-Admin.bat` and select "**Run as administrator**".
    2.  Choose `1. AutoWindowsUpdate` from the menu to bring the OS up to date. (**Strongly Recommended**)
    3.  Once completed, run `Start-Admin.bat` as an administrator again.
    4.  Choose `2. AutoSetup` to begin installing applications and configuring the environment.
5.  **Final Verification**:
    - After all automated processes are complete, manually restart the PC one last time.
    - Open the Windows Update screen and Device Manager to perform a final check for any missed updates or unknown devices.

## Script Structure

| File Name | Role |
|---|---|
| `Start-Admin.bat` | **The starting point.** Checks for administrator privileges and lets you select which script to run from an interactive menu. (May appear garbled if opened in Notepad, but this does not affect execution.) |
| `AutoWindowsUpdate.ps1` | Fully automates Windows Update, repeating the check-install-reboot cycle until no updates remain. |
| `AutoSetup.ps1` | Executes a two-phase setup (with a reboot in between) for apps, system settings, and dev environments based on `recipe.yaml`. |
| `recipe.yaml` | **The heart of customization.** Defines apps to install, system settings, and development packages in a clear, commented format. |
| `.gitignore` | Specifies files to be ignored by Git, such as log files. |
| `キッティング手順.txt` | A memo outlining the overall workflow, including manual steps, when using these automation scripts. |
| `ツール未対応の設定手順覚書き/` | Contains manuals for various manual configurations outside the scope of the scripts (e.g., Hyper-V, WSL2 setup). |

## Customization

The setup can be freely customized by editing `recipe.yaml`. To disable an item, comment out the line by adding a `#` at the beginning. You can also toggle features on or off using `onOff: true/false` where available.

### Phase 1 (`phase1`)

Defines the basic system setup that runs before the reboot.

- `windowsSettings`: Define system settings that involve registry changes, using `description` and `command` keys.
- `wingetInstall`: List the IDs of apps to install with `winget`. Optional installation arguments can be included.
- `appxRemove`: List the names of pre-installed Windows apps to remove (wildcards are supported).

### Phase 2 (`phase2`)

Defines the installation of developer-focused packages that runs after the reboot.

- `packageManagers`: Defines a list of package managers.
  - `managerName`: The name of the management tool to be displayed in logs (e.g., 'npm', 'pip').
  - `checkCommand`: The command to check if a package is already installed. The `{package}` placeholder is replaced with the package name.
  - `installCommand`: The command to install a package. The `{package}` placeholder is replaced.
  - `packages`: A list of packages to install with this manager.

**Configuration Example (`recipe.yaml`):**
```yaml
phase2:
  packageManagers:
    - managerName: 'npm'
      checkCommand: 'npm list -g {package} --depth=0'
      installCommand: 'npm install -g {package}'
      packages:
        - name: typescript
        - name: eslint
    - managerName: 'pip'
      checkCommand: 'uv pip show {package}'
      installCommand: 'uv pip install {package} --system'
      packages:
        - name: jupyterlab
        - name: numpy
```

## License

This project is licensed under the [MIT License](LICENSE).

---
Copyright (c) 2025 sin4auto