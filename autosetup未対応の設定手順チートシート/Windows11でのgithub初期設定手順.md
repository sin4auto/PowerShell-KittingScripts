# Windows11でのGit・GitHub初期設定手順（HTTPS接続版）

## 前提条件
- Windows11がインストールされている
- Gitがインストール済み（未インストールの場合は[Git公式サイト](https://git-scm.com/)からダウンロード）
- GitHubアカウントを作成済み

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

## 2. HTTPS認証の設定

### Git Credential Managerの設定
```bash
git config --global credential.helper manager-core
```

この設定により、初回認証後は認証情報が安全に保存され、毎回入力する必要がなくなります。

### Personal Access Token（PAT）の作成

1. GitHubにログインし、右上のプロフィール画像をクリック
2. **Settings** を選択
3. 左側メニューから **Developer settings** を選択
4. **Personal access tokens** → **Tokens (classic)** を選択
5. **Generate new token** → **Generate new token (classic)** をクリック
6. 以下の項目を設定：
   - **Note**: トークンの用途を記入（例：Windows11 PC用）
   - **Expiration**: 有効期限を設定（30日、60日、90日、1年、または無期限）
   - **Select scopes**: 最低限 `repo` をチェック（プライベートリポジトリにアクセスする場合）
7. **Generate token** をクリック
8. 表示されたトークンをコピーして安全な場所に保存

**重要**: このトークンは再表示されないため、必ずコピーして保存してください。

## 3. 最初のリポジトリ操作

### 既存のリポジトリをクローン
```bash
git clone https://github.com/username/repository-name.git
```

初回クローン時に認証が求められた場合：
- **Username**: GitHubのユーザー名
- **Password**: 作成したPersonal Access Token（GitHubのパスワードではない）

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

# GitHubのリモートリポジトリと連携
git remote add origin https://github.com/username/my-project.git

# メインブランチ名を設定
git branch -M main

# GitHubにプッシュ（初回認証が求められます）
git push -u origin main
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

**認証エラー（remote: Support for password authentication was removed）**
- GitHubはパスワード認証を廃止しているため、Personal Access Tokenを使用する必要があります
- ユーザー名はGitHubユーザー名、パスワード欄にはPATを入力

**403 Forbiddenエラー**
- Personal Access Tokenの権限不足の可能性があります
- GitHubでトークンの権限（scopes）を確認し、必要に応じて `repo` 権限を追加

**Credential Managerに古い認証情報が残っている場合**
```bash
# Windows Credential Managerから古い認証情報を削除
git config --global --unset credential.helper
git config --global credential.helper manager-core
```

**リモートURLの確認・変更**
```bash
# 現在のリモートURL確認
git remote -v

# リモートURLを変更（必要に応じて）
git remote set-url origin https://github.com/username/repository-name.git
```

## 6. セキュリティのベストプラクティス

### Personal Access Tokenの管理
- **有効期限を設定**: 無期限は避け、定期的に更新する
- **最小権限の原則**: 必要最小限の権限のみ付与
- **安全な保存**: パスワードマネージャーなどで管理
- **定期的な見直し**: 不要になったトークンは削除

### 認証情報の保護
- Personal Access Tokenをコードにハードコーディングしない
- `.gitignore`ファイルで認証情報ファイルを除外
- 共有PCでは作業後にCredential Managerから認証情報をクリア

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

この手順でWindows11でのGit・GitHub初期設定（HTTPS接続）は完了です。HTTPS接続は設定が簡単で、企業環境でも広く使用されている安全な方法です。