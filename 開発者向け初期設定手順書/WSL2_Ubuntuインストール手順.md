# Windows 11にWSL2をインストールする手順書

## 1. 前提条件の確認

WSL2をインストールするために、以下の要件を満たしていることを確認してください。

- Windows 10 バージョン 2004 以上（ビルド 19041 以上）
- Windows 11

## 2. WSLのインストール

### 基本インストール（Ubuntu）

1. **管理者権限でコマンドプロンプトまたはPowerShellを開く**
2. **WSLインストールコマンドを実行**
   ```bash
   wsl --install
   ```
   - このコマンドにより、既定のディストリビューション（Ubuntu）がインストールされます
3. **システムを再起動**
   - インストール完了後、メッセージに従ってシステムを再起動してください

## 3. Linuxユーザー情報の設定

### 初回セットアップ

1. **スタートメニューからUbuntuを起動**
   - インストール完了後、スタートメニューにUbuntuが追加されます

2. **初回インストール処理の完了を待つ**
   - 初回起動時は自動的にインストール処理が実行されます

3. **ユーザーアカウントとパスワードを作成**
   - ユーザー名を入力
   - パスワードを入力（2回）
   - このユーザーはLinux管理者として設定され、sudoコマンドが実行可能です

### デフォルトユーザーの変更（必要に応じて）

1. **新しいユーザーをディストリビューション上で作成**
   ```bash
   # デフォルト設定確認
   useradd -D
   
   # 新しいユーザーを追加
   sudo useradd -m <新しいユーザー名>
   exit
   ```

2. **Windows側でデフォルトユーザーを変更**
   ```bash
   Ubuntu config --default-user <新しいユーザー名>
   ```

## 4. 基本設定とベストプラクティス

### パッケージの更新

WSLではLinuxディストリビューションの更新は自動で行われないため、定期的に手動で更新を実行してください。

```bash
sudo apt update && sudo apt upgrade
```

### Windows Terminal（ターミナル）の利用

- 新しいディストリビューションをインストールするたびに、Windows Terminal内に新しいインスタンスが自動作成されます
- Windows Terminal（ターミナル）から各ディストリビューションにアクセス可能です

### ファイルストレージ

WSLプロジェクトをWindowsエクスプローラーで開く場合：

```bash
explorer.exe .
```

## 5. 開発環境の設定

### Visual Studio Codeの設定

1. **必要なライブラリをインストール**
   ```bash
   sudo apt-get update
   sudo apt-get install wget ca-certificates
   ```

2. **Windows側にVS Codeをインストール後、WSLから起動**
   ```bash
   mkdir ~/helloworld
   cd ~/helloworld
   code .
   ```
   - 初回実行時にVS Code Serverが自動インストールされます

### Gitの設定

1. **Gitをインストール**
   ```bash
   sudo apt install git
   ```

2. **Git Credential Managerの設定**（Windows側のGit for Windowsを利用）
   
   以下のコマンドを実行：
   
   ```bash
   # Git >= v2.39.0 の場合
   git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
   ```

## 6. 追加機能

### Linux GUIアプリケーションの実行

WSL2ではLinux GUIアプリケーションをWindowsアプリのように実行できます。

例：geditエディタのインストールと実行
```bash
sudo apt install gedit -y
```

インストール後、スタートメニューからgeditを選択するか、WSL上で`gedit`コマンドを実行すると、WindowsアプリケーションとしてGUIエディタが起動します。

### Docker環境の設定

Windows側にDocker Desktop for Windowsをインストールすることで、WSL2上でDockerコンテナを使用した開発が可能になります。

## 7. 基本的なWSLコマンド

### よく使用するコマンド

- **インストール済みディストリビューション一覧表示**
  ```bash
  wsl --list --verbose
  ```

- **特定のディストリビューションを開始**
  ```bash
  wsl -d <ディストリビューション名>
  ```

- **WSLシャットダウン**
  ```bash
  wsl --shutdown
  ```

## 注意事項

- WindowsとWSL間でのファイルシステムパフォーマンスを最適化するため、WSLプロジェクトはLinuxファイルシステム内で作業することを推奨
- 定期的なパッケージ更新を忘れずに実行
- 各ディストリビューションは独立したLinux環境として動作

## トラブルシューティング

問題が発生した場合は、Microsoft公式のWSLトラブルシューティングドキュメントを参照してください。

---

以上