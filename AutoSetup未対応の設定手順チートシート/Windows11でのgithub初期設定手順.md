# Windows11でのGit・GitHub初期設定手順（SSH接続版）

## 前提条件
- Windows 11がインストールされている
- Gitがインストール済み（未インストールの場合は[Git公式サイト](https://git-scm.com/)からダウンロード）
- GitHubアカウントを作成済み
- Git Bash または PowerShell を利用できる

## 1. Gitの基本設定

### ユーザー名とメールアドレスの設定
```bash
git config --global user.name "あなたの名前"
git config --global user.email "your-email@example.com"
```

### 設定の確認
```bash
git config --global --list
```

### デフォルトブランチ名の設定（推奨）
```bash
git config --global init.defaultBranch main
```

### Windows環境での改行コード設定
```bash
git config --global core.autocrlf true
```

## 2. SSH認証の設定

### 既存SSHキーの確認
```bash
ls -la ~/.ssh
```

`id_ed25519` と `id_ed25519.pub` が既にある場合は再作成不要です。ない場合は次へ進みます。

### SSHキーを作成（推奨: Ed25519）
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

キー保存先は通常そのまま（`~/.ssh/id_ed25519`）で問題ありません。  
パスフレーズは空でも動作しますが、設定を推奨します。

### ssh-agentを起動して秘密鍵を登録
```bash
# Git Bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

PowerShellで利用する場合:
```powershell
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519
```

### 公開鍵をGitHubに登録
```bash
# 公開鍵を表示
cat ~/.ssh/id_ed25519.pub

# クリップボードへコピー（Git Bash）
clip < ~/.ssh/id_ed25519.pub
```

1. GitHubにログインし、右上のプロフィール画像をクリック
2. **Settings** を選択
3. 左側メニューから **SSH and GPG keys** を選択
4. **New SSH key** をクリック
5. **Title** を入力（例: Windows11-PC）
6. **Key type** は `Authentication Key` を選択
7. **Key** に公開鍵を貼り付け
8. **Add SSH key** をクリック

### SSH接続の確認
```bash
ssh -T git@github.com
```

初回はホスト確認が表示されるため `yes` を入力します。  
`Hi <username>! You've successfully authenticated...` と表示されれば成功です。

## 3. 最初のリポジトリ操作

### 既存のリポジトリをSSHでクローン
```bash
git clone git@github.com:username/repository-name.git
```

### 新しいリポジトリの作成と初期化

#### GitHubでリポジトリを作成
1. GitHubにログインし、右上の **+** ボタンをクリック
2. **New repository** を選択
3. リポジトリ名を入力
4. **Create repository** をクリック

#### ローカルでの作業
```bash
# プロジェクトフォルダを作成
mkdir my-project
cd my-project

# Gitリポジトリとして初期化
git init

# READMEファイルを作成
echo "# My Project" > README.md

# ファイルをステージング
git add README.md

# 初回コミット
git commit -m "Initial commit"

# GitHubのリモートリポジトリと連携（SSH URL）
git remote add origin git@github.com:username/my-project.git

# メインブランチ名を設定
git branch -M main

# GitHubにプッシュ
git push -u origin main
```

### 既存ローカルリポジトリをHTTPSからSSHに切り替える
```bash
# 現在のURL確認
git remote -v

# SSH URLへ変更
git remote set-url origin git@github.com:username/repository-name.git
```

## 4. よく使用するGitコマンド

### 基本的なワークフロー
```bash
# 現在の状態を確認
git status

# すべての変更をステージング
git add .

# 特定のファイルのみステージング
git add filename.txt

# コミット
git commit -m "変更内容の説明"

# リモートリポジトリにプッシュ
git push

# リモートから最新を取得
git pull
```

### ブランチ操作
```bash
# 現在のブランチを確認
git branch

# 新しいブランチを作成して切り替え
git checkout -b feature-branch

# または（Git 2.23以降）
git switch -c feature-branch

# ブランチを切り替え
git checkout main
# または
git switch main

# ブランチをマージ
git merge feature-branch

# リモートブランチをプッシュ
git push -u origin feature-branch
```

### 履歴確認
```bash
# コミット履歴を表示
git log

# 簡潔な履歴表示
git log --oneline

# 変更差分を確認
git diff
```

## 5. トラブルシューティング

### よくある問題と解決方法

**`Permission denied (publickey)` が出る**
- GitHubに公開鍵（`.pub`）を登録済みか確認
- `ssh-add -l` で鍵がagentに読み込まれているか確認
- 読み込まれていない場合は `ssh-add ~/.ssh/id_ed25519` を実行

**`Host key verification failed` が出る**
- `~/.ssh/known_hosts` に古い `github.com` 情報がある可能性があります
- 以下で削除後、再接続して登録し直します

```bash
ssh-keygen -R github.com
ssh -T git@github.com
```

**HTTPS URLのままになっている**
```bash
git remote -v
git remote set-url origin git@github.com:username/repository-name.git
```

**接続詳細を確認したい**
```bash
ssh -vT git@github.com
```

## 6. セキュリティのベストプラクティス

### SSHキーの管理
- **パスフレーズを設定**: 秘密鍵が漏えいした場合のリスクを下げる
- **秘密鍵を共有しない**: 共有すべきなのは公開鍵（`.pub`）のみ
- **端末ごとに鍵を分離**: PCごとに別鍵を作成し、不要鍵はGitHubから削除
- **定期的な見直し**: 使っていない鍵はGitHub側で無効化・削除

### 認証情報の保護
- 秘密鍵をコードやリポジトリに含めない
- `.gitignore` で秘密情報ファイルを除外
- 共有PCでは作業後に鍵を削除またはセッションを終了

## 7. 推奨設定

### エディタの設定
```bash
# Visual Studio Codeを使用する場合
git config --global core.editor "code --wait"

# メモ帳を使用する場合
git config --global core.editor "notepad"
```

### マージツールの設定
```bash
# Visual Studio Codeをマージツールとして使用
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'
```

### プッシュ設定
```bash
# 現在のブランチのみをプッシュ（安全）
git config --global push.default current
```

## 8. 初心者向けワークフロー例

### 日常的な作業の流れ
```bash
# 1. 最新の状態に更新
git pull

# 2. ファイルを編集（エディタで作業）

# 3. 変更を確認
git status
git diff

# 4. 変更をステージング
git add .

# 5. コミット
git commit -m "機能Aを追加"

# 6. GitHubにプッシュ
git push
```

この手順でWindows11でのGit・GitHub初期設定（SSH接続）は完了です。  
Git操作で毎回トークンを入力する必要がなく、日常開発の運用がシンプルになります。
