# Windows 11で始めるWSL2導入ガイド

このガイドは、Windows 11にWSL2 (Windows Subsystem for Linux 2) をインストールし、開発環境を構築するための手順をまとめたものです。

> **関連する手順書**
> - **初めて WSL2 を入れる場合**：このガイドを上から順に進めてください。
> - **開発ツールをまとめて自動で入れたい場合 / WSL を作り直す場合**：[WSL環境 再構築手順（man.md）](WSL環境の初期設定スクリプト等/man.md) を参照してください。`setup-wsl.sh` などのスクリプトで、Git・Node.js・Python・uv などを一括で導入できます。
> - **GitHub への接続設定**：[Windows11でのgithub初期設定手順](Windows11でのgithub初期設定手順.md) を参照してください。

---

## Part 1：インストールと初期設定（必須）

まずはWSL2を動作させるための基本的な設定を行います。

### Step 1：前提条件の確認

- **OS**: Windows 11 または Windows 10 (バージョン 2004 / ビルド 19041 以降)  
- **仮想化**: PCのBIOS/UEFI設定で「仮想化支援機能（Intel VT-x や AMD-Vなど）」が有効になっている必要があります。  
  - 最近のPCでは通常、デフォルトで有効になっています。

### Step 2：WSL2のインストール

現在のWindowsでは、コマンド一つで必要なコンポーネントの導入からLinuxのインストールまでが完了します。

1. スタートボタンを右クリックし、**「ターミナル（管理者）」**または**「Windows PowerShell（管理者）」**を選択します。
2. 開いたウィンドウで、以下のコマンドを実行します。

   ```powershell
   wsl --install
   ```

   > **【解説】** このコマンドは以下の処理を自動で行います。  
   > - WSL2に必要なWindowsの機能（仮想マシンプラットフォームなど）を有効化します。  
   > - 最新のLinuxカーネルをダウンロードし、インストールします。  
   > - 標準のLinuxとして **Ubuntu** をダウンロードし、インストールします。  

3. 処理が完了したら、メッセージに従ってPCを**再起動**してください。

### Step 3：Linux (Ubuntu) の初期設定

再起動後、自動的にUbuntuのセットアップ画面が表示されます。

1. Linux環境で使用する**ユーザー名**を入力し、Enterキーを押します。  
2. 次に、そのユーザーの**パスワード**を入力し、Enterキーを押します。（確認のため、もう一度入力します）  
   - **注意**：パスワード入力時、セキュリティのため画面には何も表示されませんが、正しく入力されています。  

プロンプト（`ユーザー名@PC名:~$`のような表示）が出れば、インストールと初期設定は完了です。このユーザーは管理者権限（`sudo`コマンド）を持っています。

### Step 4：パッケージリストの更新

インストールしたLinuxを最新の状態に保つため、以下のコマンドを実行しましょう。これは新しい環境を構築した際の「お約束」です。

```bash
sudo apt update && sudo apt upgrade
```

---

## Part 2：開発環境の構築（推奨）

WSL2をより快適に使うためのツールを導入します。

### 1. Visual Studio Code (VS Code) との連携

Windows側にインストールしたVS Codeを使って、WSL内のファイルを直接編集・デバッグするのが最も効率的です。

- Windows側にVS Codeがインストールされていない場合は、公式サイトからダウンロードしてインストールします。
- WSLのターミナル（Ubuntu）で、プロジェクト用のディレクトリを作成し、移動します。

```bash
mkdir ~/myproject
cd ~/myproject
```

- 以下のコマンドを実行して、VS Codeを起動します。

```bash
code .
```

> **解説**  
> 初回実行時、WSL内にVS Codeのバックエンド機能（VS Code Server）が自動でインストールされます。これにより、WindowsのVS CodeからLinux内のファイルへシームレスにアクセスできるようになります。

---

### 2. Gitの導入と資格情報管理

WSL内にGitをインストールし、Windows側の認証情報を利用してGitHubなどへのアクセスを簡略化します。

#### Gitのインストール

```bash
sudo apt install git
```

> `setup-wsl.sh` を実行した場合は、Git はすでに入っています（既定ブランチ名 `main` の設定も済んでいます）。

#### GitHub への接続方法

GitHub への接続方法は、次の 2 通りがあります。**基本は A（SSH）** です。Windows 側と同じ方法でそろえられるためです。

**A. SSH の鍵を使う（推奨）**

[Windows11でのgithub初期設定手順](Windows11でのgithub初期設定手順.md) の「1. Gitの基本設定」と「2. SSH認証の設定」を、**WSL のターミナルで**同じように行います（Git Bash 用のコマンドがそのまま使えます）。

- 鍵は WSL 側の `~/.ssh` に作られます。Windows 側の鍵とは別のものなので、GitHub にも**別の鍵として**登録します
- `clip` の代わりに `cat ~/.ssh/id_ed25519.pub` で表示した内容をコピーして登録します

**B. Windows の認証情報を使う（HTTPS）**

WindowsにGit for Windowsがインストールされている場合、その認証情報管理システム（Credential Manager）をWSLから利用できます。これにより、HTTPS の URL で GitHub などへアクセスする際のパスワード入力を省略できます。

```bash
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
```

---

## Part 3：応用的な使い方

WSL2の便利な機能や、さらに進んだ設定を紹介します。

### 1. WindowsとLinux間のファイルアクセス

- **WindowsからLinuxへ**  
  エクスプローラーのアドレスバーに `\\wsl.localhost` と入力すると、インストールされているLinux（例：Ubuntu）のフォルダが表示され、直接ファイル操作ができます。

- **LinuxからWindowsへ**  
  Linux側からは `/mnt/` ディレクトリ配下にWindowsのドライブがマウントされています。
  - Cドライブ: `/mnt/c/`  
  - Dドライブ: `/mnt/d/`  

- **ホームディレクトリに戻る**  
  Linuxのターミナル上で以下を実行すると、常にUbuntuのホームディレクトリ（`/home/ユーザー名`）に移動できます。  

  ```bash
  cd ~
  ```

> **重要**  
> パフォーマンスのため、開発プロジェクトのファイルは必ずLinux側（例：`/home/ユーザー名/myproject`）に配置してください。

---

### 2. Linux GUIアプリケーションの実行

WSL2では、特別な設定なしにLinuxのGUIアプリを起動できます。

例として、シンプルなGUIテキストエディタ `gedit` をインストールします。

```bash
sudo apt update
sudo apt install gedit -y
```

ターミナルで以下を入力すると、Windowsアプリのようにgeditのウィンドウが起動します。

```bash
gedit
```

---

### 3. Docker Desktopとの連携

WindowsにDocker Desktopをインストールし、設定画面で **「Use the WSL 2 based engine」** を有効にすると、WSLのターミナルから直接 `docker` コマンドが利用可能になり、コンテナ開発ができます。

---

## Part 4：便利なWSLコマンドリファレンス

PowerShellやコマンドプロンプトから使用できる、よく使う管理コマンドです。

### インストール済みのLinux一覧と状態を確認

```powershell
wsl --list --verbose
# 短縮形: wsl -l -v
```

### WSL全体を安全にシャットダウン

```powershell
wsl --shutdown
```

### 特定のLinuxを起動

```powershell
wsl -d <ディストリビューション名>
# 例: wsl -d Ubuntu
```

### （参考）Linux環境の削除（初期化）

> ⚠️ この操作は元に戻せません。

```powershell
wsl --unregister <ディストリビューション名>
```

---

## トラブルシューティング

問題が発生した場合は、Microsoft公式のトラブルシューティングガイドが最も信頼できます。  

👉 [WSL のトラブルシューティング | Microsoft Learn](https://learn.microsoft.com/ja-jp/windows/wsl/troubleshooting)
