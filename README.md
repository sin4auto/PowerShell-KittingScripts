# Windows自動化スクリプト集 (Windows Automation Scripts)

このリポジトリは、Windows PCのセットアップやメンテナンス作業を自動化するためのPowerShellスクリプトを管理します。

## 概要

PCの初期設定や、定期的なWindows Updateを簡単かつ確実に実行することを目指しています。
大きな特徴として、**インストールするアプリケーションなどを `config.json` ファイルで自由にカスタマイズできる**ため、個人の用途や組織のポリシーに合わせて柔軟に運用できます。

---

## 使い方

1.  このリポジトリ全体をダウンロードまたはクローンします。
    -   画面右上の緑色の **`< > Code`** ボタンをクリックし、**`Download ZIP`** を選択するのが最も簡単です。
    -   ダウンロードしたZIPファイルを解凍し、任意の場所（例: `C:\temp\Win-Auto-Scripts`）に配置します。

2.  フォルダの中にある `Start-Admin.bat` ファイルを **右クリックし、「管理者として実行」** してください。

3.  ユーザーアカウント制御(UAC)のプロンプトが表示されたら「はい」を選択します。

4.  PowerShellベースのランチャーが起動し、メニューが表示されます。実行したい処理の番号を入力してEnterキーを押してください。

---

## 🔧 カスタマイズ方法

このツールの中心となるのが `config.json` ファイルです。このファイルを編集することで、スクリプトのコードを一切触ることなく、インストール・アンインストールするアプリケーションを自由に管理できます。

`config.json` をテキストエディタで開き、あなたの環境に合わせて内容を編集してください。

-   **業務アプリを追加/変更したい場合**:
    `wingetInstall` のリストに、インストールしたいアプリのIDと名前を追加・編集します。アプリのIDは、コマンドプロンプトやPowerShellで `winget search <アプリ名>` コマンドを実行すると検索できます。

-   **標準アプリを削除したくない場合**:
    `appxRemove` のリストから、PCに残しておきたいアプリの行を丸ごと削除します。

-   **開発者向けツールが不要な場合**:
    `npmInstall` のリストから、不要なパッケージの行を削除します。

---

## 提供するスクリプト

### 1. 全自動Windows Update (`AutoWindowsUpdate.ps1`)

Windows Updateを「最新の状態」になるまで、更新のインストールと再起動を全自動で繰り返します。

#### 主な機能
-   **完全自動化**: 一度実行すれば、すべての更新が完了するまで完全に放置できます。
-   **必須モジュールの自動インストール**: `PSWindowsUpdate`モジュールがない場合、自動でインストールします。
-   **ログ記録**: すべての実行履歴を `AutoUpdateLog.txt` に保存します。

#### ⚠️ 最終確認のお願い
スクリプト完了後も、一部の機能更新プログラム等が残る場合があります。**最後に必ず、Windowsの「設定」→「Windows Update」画面から手動で「更新プログラムのチェック」を実行し、**完全に最新の状態になっていることを確認してください。

---

### 2. PC初期設定（キッティング）自動化 (`AutoSetup.ps1`)

`config.json` の設定に基づき、新しいPCのセットアップ作業を自動化します。

#### フェーズ1: 基本セットアップ
-   **アプリケーションのインストール**: `config.json` の `wingetInstall` リストに基づき、Wingetを利用して各種アプリケーションを導入します。
-   **プリインストールアプリの削除**: `config.json` の `appxRemove` リストに基づき、不要な標準アプリを削除します。
-   **システム設定の最適化**: エクスプローラーの表示設定改善や、高速スタートアップの無効化など、一般的な最適化を行います。

#### フェーズ2: 開発環境のセットアップ (再起動後に自動実行)
-   **Node.js開発ツールのインストール**: `config.json` の `npmInstall` リストに基づき、`npm` を利用して各種ツールをグローバルにインストールします。
-   **ログ記録**: すべての実行履歴を `KittingLog.txt` に保存します。

---

## ⚠️ 重要：免責事項 (Disclaimer)

**警告: このスクリプトはシステムに重大な変更を加える可能性があります。**

本ソフトウェアは、作者が最大限の注意を払って作成していますが、その動作、安全性、正確性について一切の保証はありません。本ソフトウェアは「現状のまま（AS IS）」提供されます。

本ソフトウェアの使用によって生じたいかなる種類の損害（データの損失、システムの不具合、業務の中断などを含むがこれらに限定されない）についても、作者は一切の責任を負いません。

**すべての操作は、完全に自己責任で行ってください。** 使用前に必ず内容を理解し、必要であればバックアップを取得することを強く推奨します。

## ライセンス (License)

このプロジェクトは [MITライセンス](LICENSE) の下で公開されています。
