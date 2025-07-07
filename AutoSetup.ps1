# =================================================================
# Windows PC 初期設定自動化スクリプト (2フェーズ実行 / 自動再起動対応)
# =================================================================
# ■ 概要
# このスクリプトは、Windows PCの初期設定（キッティング）を自動化します。
# 処理は2つのフェーズに分かれており、途中で自動的に再起動が行われます。
#
#   - フェーズ1:
#     主要アプリケーションのインストール、不要な標準アプリの削除、OSの基本設定変更を行います。
#     完了後、PCは自動で再起動します。
#
#   - フェーズ2:
#     再起動後、ユーザーのログオン時に自動で実行されます。
#     Node.js環境に必要な開発者向けツール（npmパッケージ）をインストールします。
#
# ■ 実行手順
# 1. このファイルをPCの任意の場所（例: C:\temp\setup.ps1）に保存します。
#    ※注意: ファイルの文字コードは「UTF-8 (BOM付き)」で保存してください。
#
# 2. PowerShellを「管理者として実行」します。
#
# 3. 開いたPowerShellの画面で、以下の2つのコマンドを順に実行します。
#
#    Set-ExecutionPolicy RemoteSigned -Scope Process -Force
#    & C:\temp\setup.ps1
#
# 4. スクリプトが実行され、フェーズ1が完了するとPCが自動で再起動します。
#    再起動後にログオンすると、自動的にフェーズ2が開始されます。
# =================================================================

# --- スクリプト引数の定義 ---
# スクリプトが現在どのフェーズで実行されているかを管理するための内部的な引数です。
# ユーザーが手動で指定する必要はありません。
param (
    [string]$Phase
)

# --- 0. 実行権限の確認 ---
# フェーズ1の実行時のみ、管理者権限を持っているかを確認します。
# システム設定の変更やアプリケーションのインストールには管理者権限が必須です。
# ※フェーズ2は再起動後に自動実行されるため、このチェックは不要です。
if ($Phase -ne '2') {
    Write-Host "スクリプトが管理者権限で実行されているか確認中..." -ForegroundColor Yellow
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "エラー: 管理者権限がありません。"
        Write-Warning "PowerShellアイコンを右クリックし、「管理者として実行」を選んでから再度実行してください。"
        Read-Host "Enterキーを押すとスクリプトを終了します。"
        exit
    }
}


# =================================================================
# 【フェーズ2】 再起動後の追加設定
# (Node.js 関連パッケージのインストール)
# =================================================================
# このブロックは、引数 -Phase が '2' の場合にのみ実行されます。
if ($Phase -eq '2') {
    # ログオン直後はシステムが安定していない可能性があるため、少し待機します。
    Start-Sleep -Seconds 5
    
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  キッティング フェーズ2を開始します" -ForegroundColor Cyan
    Write-Host "  (開発者向けツールのインストール)" -ForegroundColor Cyan
    Write-Host "==============================================="
    Write-Host ""
    
    # グローバルにインストールするnpmパッケージのリスト
    $npmPackagesToInstall = @(
        "typescript",   # JavaScriptに型システムを追加する言語とそのコンパイラ
        "ts-node",      # TypeScriptコードをコンパイルせずに直接実行するユーティリティ
        "nodemon",      # ソースコードの変更を検知して、自動的にアプリケーションを再起動するツール
        "eslint",       # コードの品質を保つための静的解析（リンティング）ツール
        "prettier",     # コードの書式を統一ルールに従って自動で整形するフォーマッター
        "pnpm"          # 高速かつディスク容量を効率的に使用するパッケージマネージャー
    )

    # 各パッケージについて、インストール済みかを確認し、未インストールの場合のみ処理を実行します。
    foreach ($pkg in $npmPackagesToInstall) {
        Write-Host "パッケージ [$pkg] の状態を確認しています..."
        # `npm list -g` でグローバルインストール済みかを確認します。
        npm list -g $pkg --depth=0 > $null
        if ($LASTEXITCODE -eq 0) {
            # 終了コードが0なら、既にインストール済みです。
            Write-Host "-> [$pkg] はインストール済みです。スキップします。" -ForegroundColor Cyan
        } else {
            # 終了コードが0以外なら、未インストールと判断してインストールを実行します。
            Write-Host "-> [$pkg] をグローバルにインストールします..."
            npm install -g $pkg
            if ($LASTEXITCODE -eq 0) {
                Write-Host "-> [$pkg] のインストールに成功しました。" -ForegroundColor Green
            } else {
                Write-Warning "-> [$pkg] のインストール中にエラーが発生しました。ログを確認してください。"
            }
        }
    }
    
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "  すべての初期設定が完了しました！" -ForegroundColor Green
    Write-Host "==============================================="
    Read-Host "Enterキーを押して、このウィンドウを閉じてください。"
    exit
}

# =================================================================
# 【フェーズ1】 初期インストーラーの実行
# =================================================================
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  キッティング フェーズ1を開始します" -ForegroundColor Cyan
Write-Host "==============================================="
Write-Host ""

# --- 1. Wingetによるアプリケーションのインストール ---
# Windows標準のパッケージ管理ツール「Winget」を使い、業務や開発で利用する基本的なアプリを導入します。
$appsToInstall = @(
    "Google.Chrome",                 # Webブラウザ
    "7zip.7zip",                     # 高機能なファイル圧縮・解凍ソフト
    "Microsoft.PowerToys",           # Windowsの操作性を向上させるMicrosoft公式ツール群
    "Microsoft.VisualStudioCode",    # 高機能なテキストエディタ
    "OpenJS.NodeJS.LTS",             # サーバーサイドJavaScript実行環境（npmを含む）
    "Git.Git",                       # バージョン管理システム
    "Zoom.Zoom"                      # Web会議クライアント
)

Write-Host "--- 1. アプリケーションのインストールを開始します ---" -ForegroundColor Green
# 各アプリについて、インストール済みかを確認し、未インストールの場合のみ処理を実行します。
foreach ($app in $appsToInstall) {
    Write-Host "アプリ [$app] の状態を確認しています..."
    # `winget list` でインストール済みかを確認します。
    winget list --id $app -e --accept-source-agreements > $null
    if ($LASTEXITCODE -eq 0) {
        # 終了コードが0なら、既にインストール済みです。
        Write-Host "-> [$app] はインストール済みです。スキップします。" -ForegroundColor Cyan
    } else {
        # 終了コードが0以外なら、未インストールと判断してインストールを実行します。
        Write-Host "-> [$app] をインストールします..."
        winget install --id $app -e --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "-> [$app] のインストールに成功しました。" -ForegroundColor Green
        } else {
            Write-Warning "-> [$app] のインストール中にエラーが発生しました。処理を続行します。"
        }
    }
}
Write-Host "--- アプリケーションのインストールが完了しました ---" -ForegroundColor Green
Write-Host ""

# --- 2. 不要なプリインストールアプリの削除 ---
# 業務利用では使用頻度が低い標準搭載アプリを削除し、システムを整理します。
$bloatware = @(
    "*Microsoft.549981C3F5F10*",      # Cortana (デジタルアシスタント)
    "*Microsoft.BingNews*",           # Microsoft ニュース
    "*Microsoft.GetHelp*",            # ヘルプの表示
    "*Microsoft.Getstarted*",         # ヒント
    "*Microsoft.Office.OneNote*",     # OneNote (for Windows 10版)
    "*Microsoft.People*",             # People (連絡先)
    "*Microsoft.WindowsFeedbackHub*", # フィードバック Hub
    "*Microsoft.YourPhone*",          # スマートフォン連携
    "*Microsoft.ZuneMusic*",          # Groove ミュージック
    "*Microsoft.ZuneVideo*"           # 映画 & テレビ
)
Write-Host "--- 2. 不要なプリインストールアプリの削除を開始します ---" -ForegroundColor Green
foreach ($app in $bloatware) {
    Write-Host "[$app] を検索し、存在すれば削除します..."
    # Get-AppxPackageで全ユーザーからアプリを検索し、存在すればRemove-AppxPackageで削除します。
    # -ErrorAction SilentlyContinue は、アプリが存在しなくてもエラーを表示しないための設定です。
    Get-AppxPackage -AllUsers $app | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}
Write-Host "--- 不要なプリインストールアプリの削除が完了しました ---" -ForegroundColor Green
Write-Host ""

# --- 3. 既存アプリケーションのアップグレード ---
Write-Host "--- 3. インストール済みアプリをすべて最新版に更新します ---" -ForegroundColor Green
# `winget upgrade --all` コマンドで、Wingetが管理する全アプリを最新バージョンに更新します。
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
Write-Host "--- アプリの更新が完了しました ---" -ForegroundColor Green
Write-Host ""

# --- 4. Windowsのシステム設定変更 ---
# 開発効率や操作性を向上させるため、いくつかのWindows設定をレジストリ経由で変更します。
Write-Host "--- 4. Windowsの各種設定を変更します ---" -ForegroundColor Green

Write-Host "エクスプローラーの表示設定を変更中..."
# 隠しファイルやシステムファイルを常に表示する
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Force
# ファイルの拡張子（.txt, .exeなど）を常に表示する
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Force
# アドレスバーに常に完全なパス（例: C:\Users\…）を表示する
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPathAddress" -Value 1 -Force
# エクスプローラーを開いた際の初期表示を「クイックアクセス」から「PC」に変更する
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Force
# (Win11) 右クリックメニューを従来の形式に戻し、操作ステップを減らす
New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Set-ItemProperty -Name "(Default)" -Value "" -Force

Write-Host "高速スタートアップを無効化中..."
# シャットダウン時のシステムトラブルを予防する。PCを完全にシャットダウンさせる設定です。
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord -Force

Write-Host "--- Windowsの各種設定変更が完了しました ---" -ForegroundColor Green
Write-Host ""

# --- 5. フェーズ2の自動実行設定と再起動 ---
# Windowsの「RunOnce」機能を利用して、次回のログオン時に一度だけこのスクリプトを再度実行するよう設定します。
Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---" -ForegroundColor Green
# 「RunOnce」レジストリキーのパスを定義します。
$runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
# このスクリプト自身のフルパスを取得します。
$scriptPath = $MyInvocation.MyCommand.Path
# 再起動後に実行するコマンドを組み立てます。`-Phase 2` を付けてフェーズ2を実行するよう指示します。
$commandToRun = "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -Phase 2"
# `RunOnce`レジストリに、"KittingPhase2"という名前でコマンドを登録します。
Set-ItemProperty -Path $runOnceKey -Name "KittingPhase2" -Value $commandToRun -Force
Write-Host "再起動後の自動実行設定が完了しました。"
Write-Host ""

# --- 自動再起動の実行 ---
Write-Host "==============================================="
Write-Host "  フェーズ1のすべての処理が完了しました！" -ForegroundColor Green
Write-Host "==============================================="
Write-Host "設定を完全に適用するため、システムを再起動します。" -ForegroundColor Yellow
Write-Host "10秒後に自動で再起動が開始されます。中断したい場合はこのウィンドウを閉じてください。" -ForegroundColor Yellow
Start-Sleep -Seconds 10

# PCを強制的に再起動します。
Restart-Computer -Force