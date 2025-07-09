<#
.SYNOPSIS
    Windows PCの初期設定を自動化します。

.DESCRIPTION
    このスクリプトは、Wingetやnpmを利用してアプリケーションのインストールやシステム設定を自動で行います。
    処理は `config.json` ファイルに基づいて実行され、再起動を挟む2つのフェーズで構成されています。

    フェーズ1:
    - 管理者権限で実行する必要があります。
    - アプリケーションのインストール (Winget)
    - プリインストールアプリの削除
    - 既存アプリのアップグレード
    - Windowsシステム設定の変更
    - 再起動後にフェーズ2を自動実行するように設定し、システムを再起動します。

    フェーズ2:
    - 再起動後に自動で実行されます。
    - 開発者向けパッケージのインストール (npm)

.PARAMETER Phase
    実行するフェーズを指定します。
    通常、このパラメータは手動で指定する必要はありません。
    スクリプトが内部的にフェーズ2を呼び出す際に使用します。
    - (指定なし): フェーズ1を実行
    - '2': フェーズ2を実行

.EXAMPLE
    .\setup.ps1
    PowerShellを「管理者として実行」で開き、このスクリプトを実行します。フェーズ1が開始されます。

.NOTES
    実行には管理者権限が必須です。
    必須ファイル: config.json (スクリプトと同じディレクトリに配置)
    インストール時にはインターネット接続が必要です。
    本スクリプトはWindows標準のPowerShell 5.1での動作を想定しています。
    Copyright (c) 2025 sin4auto
#>

# =================================================================
# パラメータ定義
# =================================================================
# スクリプト実行時の引数を定義します。
param (
    # 実行する処理のフェーズを指定します ('2' を指定するとフェーズ2が実行されます)。
    [string]$Phase
)

# =================================================================
# 0. 初期設定と事前準備
# =================================================================
# スクリプトの実行に必要な準備処理を行います。
# - スクリプトの実行ディレクトリへ移動
# - 設定ファイル (config.json) の読み込み
# 失敗した場合はエラーメッセージを表示して終了します。
try {
    # スクリプトが置かれているディレクトリのパスを取得します。
    $PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    # カレントディレクトリをスクリプトの場所に設定します。
    Set-Location -Path $PSScriptRoot

    # 設定ファイルのパスを構築します。
    $configPath = Join-Path $PSScriptRoot "config.json"
    # 設定ファイルが存在しない場合はエラーを発生させます。
    if (-not (Test-Path $configPath)) {
        throw "設定ファイル 'config.json' が見つかりません。処理を中断します。"
    }
    # 設定ファイル (config.json) を読み込み、PowerShellオブジェクトに変換します。
    # -Encoding UTF8 を指定して、日本語などの文字化けを防ぎます。
    $config = Get-Content -Path $configPath -Encoding UTF8 -Raw | ConvertFrom-Json
} catch {
    # tryブロック内でエラーが発生した場合の処理です。
    Write-Error $_.Exception.Message
    Read-Host "Enterキーを押すと終了します。"
    exit
}

# -----------------------------------------------------------------
# 実行権限の確認
# -----------------------------------------------------------------
# フェーズ1の実行には管理者権限が必要です。
# フェーズ2は再起動後に自動実行されるため、このチェックはスキップします。
if ($Phase -ne '2') {
    # 現在のユーザーが管理者グループに所属しているかを確認します。
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "エラー: 管理者権限がありません。"
        Write-Warning "PowerShellアイコンを右クリックし、「管理者として実行」を選んでから再度実行してください。"
        Read-Host "Enterキーを押すとスクリプトを終了します。"
        exit
    }
}


# =================================================================
# フェーズ2: 再起動後の追加設定
# (Node.js 関連パッケージのインストール)
# =================================================================
# -Phase パラメータが '2' の場合のみ、このブロックが実行されます。
if ($Phase -eq '2') {
    # OS起動直後の実行負荷を考慮し、5秒待機します。
    Start-Sleep -Seconds 5
    
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  キッティング フェーズ2を開始します" -ForegroundColor Cyan
    Write-Host "  (開発者向けツールのインストール)" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # config.json の 'npmInstall' リストをループ処理します。
    foreach ($pkg in $config.npmInstall) {
        Write-Host "パッケージ [$($pkg.package)] ($($pkg.description)) の状態を確認しています..."
        # `npm list -g` コマンドで、パッケージがグローバルにインストール済みか確認します。
        # `--depth=0` は、依存関係を無視してトップレベルのパッケージのみをチェックするためのオプションです。
        # `> $null` で標準出力を抑制し、終了コード($LASTEXITCODE)のみで成否を判定します。
        npm list -g $pkg.package --depth=0 > $null
        # $LASTEXITCODE が 0 ならインストール済みです。
        if ($LASTEXITCODE -eq 0) {
            Write-Host "-> [$($pkg.package)] はインストール済みです。スキップします。" -ForegroundColor Cyan
        } else {
            Write-Host "-> [$($pkg.package)] をグローバルにインストールします..."
            # `npm install -g` コマンドでパッケージをグローバルにインストールします。
            npm install -g $pkg.package
            # インストールの成否を判定します。
            if ($LASTEXITCODE -eq 0) {
                Write-Host "-> [$($pkg.package)] のインストールに成功しました。" -ForegroundColor Green
            } else {
                Write-Warning "-> [$($pkg.package)] のインストール中にエラーが発生しました。ログを確認してください。"
            }
        }
    }
    
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "  すべての初期設定が完了しました！" -ForegroundColor Green
    Write-Host "==============================================="
    # ユーザーがウィンドウを閉じるまで待機します。
    Read-Host "Enterキーを押して、このウィンドウを閉じてください。"
    # フェーズ2が完了したらスクリプトを終了します。
    exit
}

# =================================================================
# フェーズ1: 初期インストールとシステム設定
# =================================================================
# 画面をクリアして、フェーズ1の開始を通知します。
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  キッティング フェーズ1を開始します" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------
# 1. Wingetによるアプリケーションのインストール
# -----------------------------------------------------------------
Write-Host "--- 1. アプリケーションのインストールを開始します ---" -ForegroundColor Green
# config.json の 'wingetInstall' リストをループ処理します。
foreach ($app in $config.wingetInstall) {
    Write-Host "アプリ [$($app.id)] ($($app.name)) の状態を確認しています..."
    # `winget list` コマンドで、指定したIDのアプリがインストール済みか確認します。
    # `-e` (--exact) は、IDが完全に一致するもののみを対象とします。
    winget list --id $app.id -e --accept-source-agreements > $null
    # $LASTEXITCODE が 0 ならインストール済みです。
    if ($LASTEXITCODE -eq 0) {
        Write-Host "-> [$($app.id)] はインストール済みです。スキップします。" -ForegroundColor Cyan
    } else {
        Write-Host "-> [$($app.id)] をインストールします..."
        # `winget install` コマンドでアプリをインストールします。
        # `--accept-package-agreements` と `--accept-source-agreements` は、ライセンス同意のプロンプトを自動で承諾するオプションです。
        winget install --id $app.id -e --accept-package-agreements --accept-source-agreements
        # インストールの成否を判定します。
        if ($LASTEXITCODE -eq 0) {
            Write-Host "-> [$($app.id)] のインストールに成功しました。" -ForegroundColor Green
        } else {
            # インストールに失敗しても、後続の処理を続けるため、警告のみ表示します。
            Write-Warning "-> [$($app.id)] のインストール中にエラーが発生しました。処理を続行します。"
        }
    }
}
Write-Host "--- アプリケーションのインストールが完了しました ---" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------
# 2. 不要なプリインストールアプリの削除
# -----------------------------------------------------------------
Write-Host "--- 2. 不要なプリインストールアプリの削除を開始します ---" -ForegroundColor Green
# config.json の 'appxRemove' リストをループ処理します。
foreach ($app in $config.appxRemove) {
    Write-Host "[$($app.name)] ($($app.description)) を検索し、存在すれば削除します..."
    # `Get-AppxPackage` で指定した名前のパッケージを検索し、`Remove-AppxPackage` で削除します。
    # `-AllUsers` は、すべてのユーザープロファイルから削除するオプションです。
    # `-ErrorAction SilentlyContinue` は、アプリが見つからない場合などにエラーを表示せず処理を続行します。
    Get-AppxPackage -AllUsers $app.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}
Write-Host "--- 不要なプリインストールアプリの削除が完了しました ---" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------
# 3. 既存アプリケーションのアップグレード
# -----------------------------------------------------------------
Write-Host "--- 3. インストール済みアプリをすべて最新版に更新します ---" -ForegroundColor Green
# Winget を使い、インストール済みのすべてのアプリケーションをアップグレードします。
# `--all` はすべてのアプリを対象とし、`--silent` はUIを表示せずにバックグラウンドで実行します。
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
Write-Host "--- アプリの更新が完了しました ---" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------
# 4. Windowsのシステム設定変更
# -----------------------------------------------------------------
# レジストリを直接編集して、Windowsの各種設定をカスタマイズします。
Write-Host "--- 4. Windowsの各種設定を変更します ---" -ForegroundColor Green

Write-Host "エクスプローラーの表示設定を変更中..."
# 隠しファイルを表示する (Hidden = 1)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Force
# ファイルの拡張子を表示する (HideFileExt = 0)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Force
# エクスプローラーのアドレスバーにフルパスを表示する (FullPathAddress = 1)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPathAddress" -Value 1 -Force
# エクスプローラーの起動時に「PC」を表示する (LaunchTo = 1)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Force
# Windows 11 のコンテキストメニューをクラシック表示（Windows 10形式）に戻す
New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Set-ItemProperty -Name "(Default)" -Value "" -Force

Write-Host "高速スタートアップを無効化中..."
# HKLM (HKEY_LOCAL_MACHINE) 配下の設定のため、管理者権限が必須です。
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord -Force

Write-Host "--- Windowsの各種設定変更が完了しました ---" -ForegroundColor Green
Write-Host ""

# -----------------------------------------------------------------
# 5. フェーズ2の自動実行設定と再起動
# -----------------------------------------------------------------
Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---" -ForegroundColor Green
# WindowsのRunOnce機能を利用して、次回のログオン時に一度だけコマンドを実行させます。
$runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
# このスクリプト自身のパスを取得します。
$scriptPath = $MyInvocation.MyCommand.Path
# 再起動後に実行するコマンドを組み立てます。`-Phase 2` をつけてフェーズ2を呼び出します。
$commandToRun = "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -Phase 2"
# RunOnceレジストリキーにコマンドを登録します。
Set-ItemProperty -Path $runOnceKey -Name "KittingPhase2" -Value $commandToRun -Force
Write-Host "再起動後の自動実行設定が完了しました。"
Write-Host ""

# -----------------------------------------------------------------
# 自動再起動の実行
# -----------------------------------------------------------------
Write-Host "==============================================="
Write-Host "  フェーズ1のすべての処理が完了しました！" -ForegroundColor Green
Write-Host "==============================================="
Write-Host "設定を完全に適用するため、システムを再起動します。" -ForegroundColor Yellow
Write-Host "10秒後に自動で再起動が開始されます。中断したい場合はこのウィンドウを閉じてください。" -ForegroundColor Yellow
# ユーザーがキャンセルする時間を与えるため、10秒待機します。
Start-Sleep -Seconds 10

# システムを強制的に再起動します。
Restart-Computer -Force
