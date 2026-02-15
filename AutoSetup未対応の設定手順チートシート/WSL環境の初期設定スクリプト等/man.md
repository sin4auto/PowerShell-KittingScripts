# WSL環境 再構築手順（アンインストール → 再インストール → 初期設定）

この手順は、Windows 上の WSL (Ubuntu) をいったん作り直し、最終的に本リポジトリの初期設定スクリプト `setup-wsl.sh` を実行するまでを対象にしています。

## 0. 前提

- 対象 OS: Windows 11（Windows 10 2004 / build 19041 以降でも可）
- 実行ターミナル:
  - Windows 側: `PowerShell (管理者)`
  - Linux 側: `Ubuntu` ターミナル

## 1. 事前バックアップ（任意だが推奨）

既存 Ubuntu のデータを残したい場合のみ実施します。

```powershell
wsl --shutdown
wsl -l -v
wsl --export Ubuntu C:\backup\ubuntu-backup.tar
```

`Ubuntu` 以外のディストリ名を使っている場合は、適宜読み替えてください。

## 2. アンインストール（通常リセット）

### 2-1. ディストリを削除（データ初期化）

```powershell
wsl --shutdown
wsl -l -v
wsl --unregister Ubuntu
```

これで Ubuntu の Linux 側データ（ホーム配下など）は削除されます。

### 2-2. （任意）完全リセットしたい場合のみ

WSL 機能自体も一度落としたい場合の手順です。通常は不要です。

```powershell
dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
shutdown /r /t 0
```

再起動後、再インストール手順へ進みます。

## 3. 再インストール

管理者 PowerShell で実行:

```powershell
wsl --install -d Ubuntu
```

必要に応じて再起動します（メッセージが出た場合は必須）。

確認コマンド:

```powershell
wsl -l -v
wsl --status
```

## 4. Ubuntu 初期設定（初回起動）

1. Ubuntu を起動  
   （初回は自動でセットアップ画面が出ます）
2. Linux ユーザー名を作成
3. パスワードを設定
4. パッケージ更新

```bash
sudo apt update
sudo apt upgrade -y
```

## 5. 本リポジトリの初期設定スクリプト実行

`setup-wsl.sh` は `/mnt/c` 配下での実行を禁止しているため、**必ず Linux ホーム配下**で実行します。

### 方法A: リポジトリを clone して実行

```bash
cd ~
git clone https://github.com/sin4auto/PowerShell-KittingScripts.git
cd ~/PowerShell-KittingScripts
bash "AutoSetup未対応の設定手順チートシート/WSL環境の初期設定スクリプト等/setup-wsl.sh"
```

### 方法B: curl で直接実行（`curl.txt` ベース）

```bash
cd ~
curl -fsSL "https://raw.githubusercontent.com/sin4auto/PowerShell-KittingScripts/main/AutoSetup未対応の設定手順チートシート/WSL環境の初期設定スクリプト等/setup-wsl.sh" | bash
```

スクリプト完了後、表示に従って WSL ターミナルを閉じて再度開きます。

## 6. （任意）追加セットアップ

必要なら以下を実行します。

### 方法A: clone 済みリポジトリから実行

```bash
cd ~/PowerShell-KittingScripts
bash "AutoSetup未対応の設定手順チートシート/WSL環境の初期設定スクリプト等/setup-Rust-Go-Haskell.sh"
bash "AutoSetup未対応の設定手順チートシート/WSL環境の初期設定スクリプト等/setup-codex.sh"
```

### 方法B: curl で直接実行（`curl.txt` ベース）

```bash
cd ~
curl -fsSL "https://raw.githubusercontent.com/sin4auto/PowerShell-KittingScripts/main/AutoSetup未対応の設定手順チートシート/WSL環境の初期設定スクリプト等/setup-Rust-Go-Haskell.sh" | bash
curl -fsSL "https://raw.githubusercontent.com/sin4auto/PowerShell-KittingScripts/main/AutoSetup未対応の設定手順チートシート/WSL環境の初期設定スクリプト等/setup-codex.sh" | bash
```

## 7. 動作確認

```powershell
wsl -l -v
```

```bash
uname -a
python --version
node -v
npm -v
uv --version
git --version
shellcheck --version
```

## 8. よく使う復旧コマンド

```powershell
wsl --shutdown
wsl --update
```

```bash
cd ~
pwd   # /home/<ユーザー名> になっていることを確認
```
