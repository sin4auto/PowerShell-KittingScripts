# =================================================================
# Windows PC 初期設定自動化スクリプト (設定ファイル対応版)
# =================================================================
# (省略...)

param (
    [string]$Phase
)

# --- 0. 実行前準備 ---
try {
    $PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Set-Location -Path $PSScriptRoot

    $configPath = Join-Path $PSScriptRoot "config.json"
    if (-not (Test-Path $configPath)) {
        throw "設定ファイル 'config.json' が見つかりません。処理を中断します。"
    }
    # 【修正箇所】-Encoding UTF8 を追加して文字化けを防止
    $config = Get-Content -Path $configPath -Encoding UTF8 -Raw | ConvertFrom-Json
} catch {
    Write-Error $_.Exception.Message
    Read-Host "Enterキーを押すと終了します。"
    exit
}

# --- 実行権限の確認 ---
if ($Phase -ne '2') {
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
if ($Phase -eq '2') {
    Start-Sleep -Seconds 5
    
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  キッティング フェーズ2を開始します" -ForegroundColor Cyan
    Write-Host "  (開発者向けツールのインストール)" -ForegroundColor Cyan
    Write-Host "==============================================="
    Write-Host ""
    
    foreach ($pkg in $config.npmInstall) {
        Write-Host "パッケージ [$($pkg.package)] ($($pkg.description)) の状態を確認しています..."
        npm list -g $pkg.package --depth=0 > $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "-> [$($pkg.package)] はインストール済みです。スキップします。" -ForegroundColor Cyan
        } else {
            Write-Host "-> [$($pkg.package)] をグローバルにインストールします..."
            npm install -g $pkg.package
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
Write-Host "--- 1. アプリケーションのインストールを開始します ---" -ForegroundColor Green
foreach ($app in $config.wingetInstall) {
    Write-Host "アプリ [$($app.id)] ($($app.name)) の状態を確認しています..."
    winget list --id $app.id -e --accept-source-agreements > $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "-> [$($app.id)] はインストール済みです。スキップします。" -ForegroundColor Cyan
    } else {
        Write-Host "-> [$($app.id)] をインストールします..."
        winget install --id $app.id -e --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "-> [$($app.id)] のインストールに成功しました。" -ForegroundColor Green
        } else {
            Write-Warning "-> [$($app.id)] のインストール中にエラーが発生しました。処理を続行します。"
        }
    }
}
Write-Host "--- アプリケーションのインストールが完了しました ---" -ForegroundColor Green
Write-Host ""

# --- 2. 不要なプリインストールアプリの削除 ---
Write-Host "--- 2. 不要なプリインストールアプリの削除を開始します ---" -ForegroundColor Green
foreach ($app in $config.appxRemove) {
    Write-Host "[$($app.name)] ($($app.description)) を検索し、存在すれば削除します..."
    Get-AppxPackage -AllUsers $app.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}
Write-Host "--- 不要なプリインストールアプリの削除が完了しました ---" -ForegroundColor Green
Write-Host ""

# --- 3. 既存アプリケーションのアップグレード ---
Write-Host "--- 3. インストール済みアプリをすべて最新版に更新します ---" -ForegroundColor Green
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
Write-Host "--- アプリの更新が完了しました ---" -ForegroundColor Green
Write-Host ""

# --- 4. Windowsのシステム設定変更 ---
Write-Host "--- 4. Windowsの各種設定を変更します ---" -ForegroundColor Green

Write-Host "エクスプローラーの表示設定を変更中..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPathAddress" -Value 1 -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Force
New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Set-ItemProperty -Name "(Default)" -Value "" -Force

Write-Host "高速スタートアップを無効化中..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord -Force

Write-Host "--- Windowsの各種設定変更が完了しました ---" -ForegroundColor Green
Write-Host ""

# --- 5. フェーズ2の自動実行設定と再起動 ---
Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---" -ForegroundColor Green
$runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
$scriptPath = $MyInvocation.MyCommand.Path
$commandToRun = "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -Phase 2"
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

Restart-Computer -Force