<#
.SYNOPSIS
    Windows PCの初期セットアップと開発環境構築を自動化します。

.DESCRIPTION
    このスクリプトは、「config.json」ファイルに基づいてPCセットアップを自動化します。
    処理は2つのフェーズに分かれており、間にPC再起動を挟むことで、
    PATH環境変数の問題を回避し、安定したセットアップを実現します。

    [フェーズ1：システムセットアップ]
    ・Wingetによるアプリケーションの一括インストール
    ・不要な標準プリインストールアプリの削除
    ・インストール済みアプリ全体のアップグレード
    ・Windowsのシステム設定（エクスプローラー等）の最適化
    ・完了後、フェーズ2を自動実行するよう予約し、PCを再起動します。

    [フェーズ2：開発者向けパッケージ導入]
    ・PC再起動後に自動で実行されます。
    ・config.json に基づき、各種パッケージマネージャーのライブラリをインストールします。

.PARAMETER Phase
    実行するフェーズを指定します（例: '2'）。
    このパラメータは通常、スクリプトが内部的に使用するためのもので、
    ユーザーが手動で指定する必要はありません。

.EXAMPLE
    # PowerShellを「管理者として実行」で起動し、以下のコマンドを実行します。
    .\AutoSetup.ps1

.NOTES
    - 実行には管理者権限が必須です。
    - スクリプトと同じフォルダに「config.json」を配置してください。
    - 処理には安定したインターネット接続が必要です。
    - Copyright (c) 2025 sin4auto
#>

#=============================================================================
# ■ パラメータ定義
#=============================================================================
param(
    [string]$Phase
)

#=============================================================================
# ■ スクリプト全体で使用する変数の初期化
#=============================================================================
# 処理中に発生したエラーを記録するためのリストを初期化します。
$script:failedItems = [System.Collections.Generic.List[string]]::new()

#=============================================================================
# ■ 0. スクリプトの初期化と設定ファイルの読み込み
#=============================================================================
try {
    $PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Set-Location -Path $PSScriptRoot
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (-not (Test-Path $configPath)) {
        throw "設定ファイル 'config.json' が見つかりません。スクリプトと同じフォルダに配置してください。"
    }
    $config = Get-Content -Path $configPath -Encoding UTF8 -Raw | ConvertFrom-Json
}
catch {
    Write-Error $_.Exception.Message
    Read-Host "Enterキーを押すと終了します。"
    exit
}

#----------------------------------------------------------------------
# ● 管理者権限の確認
#----------------------------------------------------------------------
if ($Phase -ne '2') {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "エラー：このスクリプトの実行には管理者権限が必要です。"
        Write-Warning "PowerShellのアイコンを右クリックし、「管理者として実行」を選択してから再度お試しください。"
        Read-Host "Enterキーを押すとスクリプトを終了します。"
        exit
    }
}

#=============================================================================
# ■ フェーズ2：再起動後の処理 (開発者向けパッケージのインストール)
#=============================================================================
if ($Phase -eq '2') {
    Start-Sleep -Seconds 1

    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ2 を開始します" -ForegroundColor Cyan
    Write-Host "  (開発者向けツールのインストール)" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    # PC起動直後はシステムが不安定な場合があるため、少し待機してから処理を開始します。
    Write-Host "10秒後に自動でパッケージのインストールが開始されます。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    #----------------------------------------------------------------------
    # ● パッケージマネージャーの定義
    #   新しいパッケージマネージャーを追加したい場合は、このリストに新しい設定ブロックを
    #   追加するだけで対応できます。スクリプトの他の部分を修正する必要はありません。
    #----------------------------------------------------------------------
    $packageManagerDefinitions = @(
        @{
            Name           = "npm"
            ConfigJsonKey  = "npmInstall"
            RequiredCmd    = "npm"
            CheckCommand   = { param($pkgName) npm list -g $pkgName --depth=0 > $null }
            InstallCommand = { param($pkgName) npm install -g $pkgName }
        },
        @{
            Name           = "pip"
            ConfigJsonKey  = "pipInstall"
            RequiredCmd    = "uv"
            CheckCommand   = { param($pkgName) uv pip show $pkgName > $null 2>$null }
            InstallCommand = { param($pkgName) uv pip install $pkgName --system }
        }
        # 例：将来的にCargoを追加する場合、ここに新しいブロックを追記する
        # ,@{
        #     Name           = "cargo"
        #     ConfigJsonKey  = "cargoInstall"
        #     RequiredCmd    = "cargo"
        #     CheckCommand   = { param($pkgName) cargo install --list | Select-String -SimpleMatch $pkgName > $null }
        #     InstallCommand = { param($pkgName) cargo install $pkgName }
        # }
    )

    #----------------------------------------------------------------------
    # ● パッケージインストールの実行ループ
    #----------------------------------------------------------------------
    # 定義された各パッケージマネージャーについてループ処理します。
    foreach ($manager in $packageManagerDefinitions) {
        # config.jsonに対応するセクション（例: "npmInstall"）が存在するか確認します。
        if ($config.PSObject.Properties.Name -contains $manager.ConfigJsonKey) {
            
            # 必要なコマンド（例: "npm"）が利用可能かを確認します。
            if (-not (Get-Command $manager.RequiredCmd -ErrorAction SilentlyContinue)) {
                $errorMessage = "必須コマンド '$($manager.RequiredCmd)' が見つかりません。($($manager.Name)の処理はスキップされます)"
                Write-Warning $errorMessage
                $script:failedItems.Add($errorMessage)
                continue # 次のパッケージマネージャーへ
            }

            Write-Host "--- $($manager.Name) パッケージのインストールを開始します ---" -ForegroundColor Green
            
            # config.jsonからパッケージのリストを取得します。
            $packagesToInstall = $config.($manager.ConfigJsonKey)

            foreach ($pkg in $packagesToInstall) {
                Write-Host "パッケージ [$($pkg.package)] ($($pkg.description)) の状態を確認しています..."
                
                # インストール済みかチェック
                & $manager.CheckCommand $pkg.package
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($pkg.package)] はインストール済みです。スキップします。" -ForegroundColor Cyan
                } else {
                    Write-Host "-> [$($pkg.package)] をインストールします..."
                    & $manager.InstallCommand $pkg.package
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "-> [$($pkg.package)] のインストールに成功しました。" -ForegroundColor Green
                    } else {
                        $errorMessage = "$($manager.Name): $($pkg.package)"
                        Write-Warning "-> [$($pkg.package)] のインストール中にエラーが発生しました。"
                        $script:failedItems.Add($errorMessage)
                    }
                }
            }
            Write-Host "--- $($manager.Name) パッケージのインストールが完了しました ---" -ForegroundColor Green
            Write-Host ""
        }
    }

    # --- 最終結果の表示 ---
    Write-Host "==============================================="
    if ($script:failedItems.Count -gt 0) {
        Write-Warning "一部の処理でエラーが発生しました。詳細は以下の通りです："
        foreach ($item in $script:failedItems) {
            Write-Warning "- $item"
        }
        Write-Host "==============================================="
    }
    Write-Host "  すべてのセットアップ処理が完了しました！" -ForegroundColor Green
    Write-Host "==============================================="
    Read-Host "Enterキーを押して、このウィンドウを閉じてください。"
    exit
}

#=============================================================================
# ■ フェーズ1：PC初期設定のメイン処理
#=============================================================================
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  セットアップ フェーズ1 を開始します" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

#----------------------------------------------------------------------
# ● 1. アプリケーションのインストール (winget)
#----------------------------------------------------------------------
Write-Host "--- 1. アプリケーションのインストールを開始します ---" -ForegroundColor Green
foreach ($app in $config.wingetInstall) {
    Write-Host "アプリ [$($app.id)] ($($app.name)) の状態を確認しています..."
    winget list --id $app.id -e --accept-source-agreements > $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "-> [$($app.id)] はインストール済みです。スキップします。" -ForegroundColor Cyan
    }
    else {
        Write-Host "-> [$($app.id)] をインストールします..."
        $command = "winget install --id $($app.id) -e --accept-package-agreements --accept-source-agreements"
        if ($app.PSObject.Properties.Name -contains 'options' -and -not [string]::IsNullOrWhiteSpace($app.options)) {
            $command += " $($app.options)"
            Write-Host "-> 個別オプション ($($app.options)) を適用してインストールします。" -ForegroundColor Yellow
        }
        Invoke-Expression -Command $command
        if ($LASTEXITCODE -eq 0) {
            Write-Host "-> [$($app.id)] のインストールに成功しました。" -ForegroundColor Green
        }
        else {
            $errorMessage = "Winget: $($app.id)"
            Write-Warning "-> [$($app.id)] のインストール中にエラーが発生しました。処理を続行します。"
            $script:failedItems.Add($errorMessage)
        }
    }
}
Write-Host "--- アプリケーションのインストールが完了しました ---" -ForegroundColor Green
Write-Host ""

#----------------------------------------------------------------------
# ● 2. 不要な標準アプリの削除
#----------------------------------------------------------------------
Write-Host "--- 2. 不要なプリインストールアプリの削除を開始します ---" -ForegroundColor Green
foreach ($app in $config.appxRemove) {
    Write-Host "[$($app.name)] ($($app.description)) を検索し、存在すれば削除します..."
    Get-AppxPackage -AllUsers $app.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}
Write-Host "--- 不要なプリインストールアプリの削除が完了しました ---" -ForegroundColor Green
Write-Host ""

#----------------------------------------------------------------------
# ● 3. 既存アプリのアップグレード
#----------------------------------------------------------------------
Write-Host "--- 3. インストール済みアプリをすべて最新版に更新します ---" -ForegroundColor Green
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
Write-Host "--- アプリの更新が完了しました ---" -ForegroundColor Green
Write-Host ""

#----------------------------------------------------------------------
# ● 4. Windowsのシステム設定変更
#----------------------------------------------------------------------
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

#----------------------------------------------------------------------
# ● 5. フェーズ2の自動実行設定と再起動
#----------------------------------------------------------------------
Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---" -ForegroundColor Green
$runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
$scriptPath = $MyInvocation.MyCommand.Path
$commandToRun = "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -Phase 2"
Set-ItemProperty -Path $runOnceKey -Name "AutoSetupPhase2" -Value $commandToRun -Force
Write-Host "再起動後の自動実行設定が完了しました。"
Write-Host ""

#----------------------------------------------------------------------
# ● 自動再起動の実行
#----------------------------------------------------------------------
Write-Host "==============================================="
if ($script:failedItems.Count -gt 0) {
    Write-Warning "フェーズ1の一部の処理でエラーが発生しました。詳細は以下の通りです："
    foreach ($item in $script:failedItems) {
        Write-Warning "- $item"
    }
    Write-Host "==============================================="
}
Write-Host "  フェーズ1のすべての処理が完了しました！" -ForegroundColor Green
Write-Host "==============================================="
Write-Host "設定を完全に適用するため、システムを再起動します。" -ForegroundColor Yellow
Write-Host "10秒後に自動で再起動が開始されます。中断したい場合はこのウィンドウを閉じてください。" -ForegroundColor Yellow
Start-Sleep -Seconds 10
Restart-Computer -Force