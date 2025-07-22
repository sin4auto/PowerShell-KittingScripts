<#
.SYNOPSIS
    Windows PCの初期セットアップと開発環境構築を自動化します。

.DESCRIPTION
    このスクリプトは、設定ファイル「config.yaml」に記述された定義に基づき、
    PCのセットアップと環境構築を自動的に実行します。
    処理は、再起動を挟む2つのフェーズで構成されています。

    [フェーズ1：システム基本セットアップ]
    ・Wingetを使用したアプリケーションのインストール
    ・不要なプリインストールアプリのクリーンアップ
    ・既存アプリケーションの包括的なアップグレード
    ・エクスプローラーの表示設定など、Windowsシステムの最適化
    
    フェーズ1の完了後、再起動を経てフェーズ2が自動的に開始されるよう設定されます。

    [フェーズ2：開発者向け環境構築]
    ・PC再起動後に自動実行されます。
    ・npm, pipなどのパッケージマネージャーを通じて、開発用ライブラリをインストールします。

.PARAMETER SetupPhase
    実行するセットアップフェーズを指定します（例: '2'）。
    このパラメータは、フェーズ1からフェーズ2へ移行する際にスクリプトが内部的に使用します。
    通常、ユーザーが手動で指定する必要はありません。

.EXAMPLE
    # 1. PowerShellを「管理者として実行」で起動します。
    # 2. スクリプトが保存されているフォルダに移動します。
    # 3. 以下のコマンドを実行します。
    .\AutoSetup.ps1

.NOTES
    - 実行には管理者権限が必須です。
    - スクリプトと同じフォルダに「config.yaml」を配置する必要があります。
    - 安定したインターネット接続環境で実行してください。
    - このスクリプトはPowerShell 3.0以上を想定しています（$PSScriptRoot, $PSCommandPath変数を使用）。
    Copyright (c) 2025 sin4auto
#>

#=============================================================================
# ■ パラメータ定義
#=============================================================================
param(
    # スクリプトが現在どのフェーズを実行すべきかを判断するための内部パラメータ。
    [string]$SetupPhase
)

#=============================================================================
# ■ グローバル変数の初期化
#=============================================================================
# スクリプト実行中に発生したエラー項目を記録するためのリスト。
# スクリプトスコープ($script:)で定義し、どこからでもアクセス可能にする。
$script:FailedItems = [System.Collections.Generic.List[string]]::new()

#=============================================================================
# ■ 文字エンコーディングの設定
#=============================================================================
# wingetなどの外部コマンドが出力する日本語の文字化けを防ぐため、
# コンソールの出力エンコーディングを明示的にUTF-8に設定します。
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 外部コマンドへのリダイレクトやパイプライン処理時のエンコーディングもUTF-8に設定します。
$OutputEncoding = [System.Text.Encoding]::UTF8

#=============================================================================
# ■ ログ記録の開始
#=============================================================================
# スクリプトがあるフォルダにログファイルのパスを直接作成する。
$logFileName = "AutoSetup.log"
$logFilePath = Join-Path $PSScriptRoot $logFileName
# トランスクリプト（コンソール画面の記録）を開始。
# -Append スイッチにより、ファイルが存在すれば追記し、なければ新規作成する。
# これにより、フェーズ1とフェーズ2のログが同一ファイルに記録される。
Start-Transcript -Path $logFilePath -Append

#=============================================================================
# ■ 実行前準備 (設定ファイルの読み込みと環境チェック)
#=============================================================================
# --- YAML解析モジュールの準備 ---
try {
    # このスクリプトはYAML設定ファイルを扱うため、'powershell-yaml'モジュールが必須。
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Host "YAML設定ファイルを読み込むために 'powershell-yaml' モジュールが必要です。" -ForegroundColor Yellow
        Write-Host "モジュールのインストールを試みます...（初回のみ）" -ForegroundColor Yellow
        Install-Module -Name powershell-yaml -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Write-Host "'powershell-yaml' モジュールのインストールに成功しました。" -ForegroundColor Green
    }
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    Write-Error "YAMLモジュールのインストールまたはインポートに失敗しました。`nお手数ですが、PowerShellを管理者として実行し、次のコマンドを手動で実行してください: Install-Module -Name powershell-yaml"
    Read-Host "Enterキーを押すと終了します。"
    Stop-Transcript
    exit
}

# --- 設定ファイルの読み込み ---
try {
    # スクリプトと同じフォルダにある 'config.yaml' または 'config.yml' を探索する。
    $configFilePath = Join-Path $PSScriptRoot "config.yaml"
    if (-not (Test-Path $configFilePath)) {
        $configFilePath = Join-Path $PSScriptRoot "config.yml"
    }
    if (-not (Test-Path $configFilePath)) {
        throw "設定ファイル 'config.yaml' または 'config.yml' がスクリプトと同じフォルダに見つかりません。"
    }

    $configFileName = Split-Path -Leaf $configFilePath
    Write-Host "設定ファイル '$configFileName' を読み込んでいます..."
    # -Encoding UTF8で日本語コメントの文字化けを防ぎ、-Rawでファイル全体を一つの文字列として読み込む。
    $config = Get-Content -Path $configFilePath -Encoding UTF8 -Raw | ConvertFrom-Yaml
}
catch {
    Write-Error "設定ファイルの読み込み中にエラーが発生しました: $($_.Exception.Message)"
    # YAMLの書式エラーは利用者が特定しにくいため、具体的なヒントを表示する。
    if ($_.Exception.InnerException -is [YamlDotNet.Core.YamlException]) {
        Write-Error "YAMLファイルの書式に誤りがある可能性があります。インデント、ハイフン、コロンなどを確認してください。"
    }
    Read-Host "Enterキーを押すと終了します。"
    Stop-Transcript
    exit
}

# --- 管理者権限の確認 ---
# フェーズ1はシステム変更を伴うため、管理者権限が不可欠。
if ($SetupPhase -ne '2') {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "エラー：このスクリプトの実行には管理者権限が必要です。`nPowerShellのアイコンを右クリックし、「管理者として実行」を選択してから再度お試しください。"
        Read-Host "Enterキーを押すとスクリプトを終了します。"
        Stop-Transcript
        exit
    }
}

#=============================================================================
# ■ メインロジック (フェーズ分岐)
#=============================================================================

#----------------------------------------------------------------------
# ● フェーズ1 (初回実行): システムの基本セットアップ
#----------------------------------------------------------------------
if ($SetupPhase -ne '2') {
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ1 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    
    # --- アプリケーションのインストール (winget) ---
    if ($config.phase1.wingetInstall) {
        Write-Host "--- 1. アプリケーションのインストールを開始します ---`n" -ForegroundColor Green
        foreach ($app in $config.phase1.wingetInstall) {
            Write-Host "アプリ [$($app.id)] の状態を確認しています..."
            winget list --id $app.id -e --accept-source-agreements --disable-interactivity
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "-> [$($app.id)] はインストール済みです。`n" -ForegroundColor Cyan
            }
            else {
                Write-Host "-> [$($app.id)] をインストールします..."
                # 引数を配列で準備し、Splatting(@)で安全にコマンドを実行する
                $wingetArgs = @(
                    'install',
                    '--id', $app.id,
                    '-e',
                    '--accept-package-agreements',
                    '--accept-source-agreements',
                    '--disable-interactivity'
                )
                if ($null -ne $app.options) {
                    $wingetArgs += $app.options.Split(' ')
                    Write-Host "-> 個別オプション ($($app.options)) を適用します。" -ForegroundColor Yellow
                }
                
                winget @wingetArgs
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($app.id)] のインストールに成功しました。`n" -ForegroundColor Green
                }
                else {
                    Write-Warning "-> [$($app.id)] のインストール中にエラーが発生しました。`n"
                    $script:FailedItems.Add("Winget Install: $($app.id)")
                }
            }
        }
        Write-Host "--- アプリケーションのインストールが完了しました ---`n" -ForegroundColor Green
    }

    # --- 不要な標準アプリの削除 ---
    if ($config.phase1.appxRemove) {
        Write-Host "--- 2. 不要なプリインストールアプリの削除を開始します ---`n" -ForegroundColor Green
        foreach ($app in $config.phase1.appxRemove) {
            Write-Host "[$($app.name)] を検索し、存在すれば削除します..."
            Get-AppxPackage -AllUsers $app.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }
        Write-Host "`n--- 不要なプリインストールアプリの削除が完了しました ---`n" -ForegroundColor Green
    }

    # --- Windowsのシステム設定変更 ---
    if ($config.phase1.windowsTweaks) {
        Write-Host "--- 3. Windowsの各種設定を変更します ---`n" -ForegroundColor Green
        foreach ($tweak in $config.phase1.windowsTweaks) {
            Write-Host "-> $($tweak.description)..."
            try {
                $parentPath = Split-Path -Path $tweak.path
                if (-not (Test-Path $parentPath)) {
                    New-Item -Path $parentPath -Force | Out-Null
                }
                switch ($tweak.type) {
                    'Set-RegistryValue' {
                        Set-ItemProperty -Path $tweak.path -Name $tweak.name -Value $tweak.value -Type $tweak.valueType -Force -ErrorAction Stop
                    }
                    'Create-RegistryKeyWithDefault' {
                        New-Item -Path $tweak.path -Force -ErrorAction Stop | Set-ItemProperty -Name "(Default)" -Value $tweak.value -Force -ErrorAction Stop
                    }
                }
            }
            catch {
                $errorMessage = "設定変更失敗: $($tweak.description): $($_.Exception.Message)"
                Write-Warning "-> $($_.Exception.Message)"
                $script:FailedItems.Add($errorMessage)
            }
        }
        Write-Host "`n--- Windowsの各種設定変更が完了しました ---`n" -ForegroundColor Green
    }

    # --- インストール済みアプリ全体を更新 ---
    Write-Host "--- 4. インストール済みアプリ全体を更新します ---`n" -ForegroundColor Green
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "-> アプリ全体の更新プロセス中にエラーが報告されました。"
        $script:FailedItems.Add("Winget Upgrade: 全体更新")
    }
    Write-Host "--- インストール済みアプリ全体の更新が完了しました ---`n" -ForegroundColor Green

    # --- フェーズ2の自動実行設定と再起動 ---
    Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---`n" -ForegroundColor Green
    $runOnceRegistryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    # $PSCommandPath変数でスクリプトのフルパスを直接取得する
    $runOnceCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$PSCommandPath`" -SetupPhase 2"
    Set-ItemProperty -Path $runOnceRegistryKeyPath -Name "AutoSetupPhase2" -Value $runOnceCommand -Force
    Write-Host "再起動後の自動実行設定が完了しました。`n"

    # --- フェーズ1の完了報告と自動再起動 ---
    Write-Host "==============================================="
    if ($script:FailedItems.Count -gt 0) {
        Write-Warning "フェーズ1の一部の処理でエラーが発生しました。詳細は以下の通りです："
        foreach ($failedItem in $script:FailedItems) {
            Write-Warning "- $failedItem"
        }
        Write-Host "==============================================="
    }
    Write-Host "  フェーズ1のすべての処理が完了しました！" -ForegroundColor Green
    Write-Host "===============================================`n"
    Write-Host "設定を完全に適用するため、システムを再起動します。" -ForegroundColor Yellow
    Write-Host "10秒後に自動で再起動が開始されます。中断したい場合はこのウィンドウを閉じてください。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Stop-Transcript
    Restart-Computer -Force
}

#----------------------------------------------------------------------
# ● フェーズ2 (再起動後): 開発者向けパッケージのインストール
#----------------------------------------------------------------------
if ($SetupPhase -eq '2') {
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ2 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    Write-Host "10秒後に自動でパッケージのインストールが開始されます。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # --- パッケージインストールの実行ループ ---
    if ($config.phase2.packageManagers) {
        foreach ($manager in $config.phase2.packageManagers) {
            # コマンドの存在確認は Get-Command で行う
            if (-not (Get-Command $manager.commandName -ErrorAction SilentlyContinue)) {
                $errorMessage = "必須コマンド '$($manager.commandName)' が見つかりません。($($manager.managerName)の処理はスキップされます)"
                Write-Warning $errorMessage
                $script:FailedItems.Add($errorMessage)
                continue
            }

            Write-Host "`n--- $($manager.managerName) パッケージのインストールを開始します ---`n" -ForegroundColor Green
            
            if ($manager.packages) {
                foreach ($pkgName in $manager.packages) {
                    Write-Host "パッケージ [$($pkgName)] の状態を確認しています..."
                    
                    # ---- 確認コマンドの実行 (cmd.exe 経由) ----
                    $checkArgs = $manager.checkArgs | ForEach-Object { $_ -replace '\{package\}', $pkgName }
                    $fullCheckCommand = "$($manager.commandName) " + ($checkArgs -join " ")
                    $checkProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $fullCheckCommand" -Wait -NoNewWindow -PassThru
                    
                    if ($checkProcess.ExitCode -eq 0) {
                        Write-Host "-> [$($pkgName)] はインストール済みです。スキップします。`n" -ForegroundColor Cyan
                    } 
                    else {
                        Write-Host "-> [$($pkgName)] をインストールします..."
                        
                        # ---- インストールコマンドの実行 (cmd.exe 経由) ----
                        $installArgs = $manager.installArgs | ForEach-Object { $_ -replace '\{package\}', $pkgName }
                        $fullInstallCommand = "$($manager.commandName) " + ($installArgs -join " ")
                        $installProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $fullInstallCommand" -Wait -NoNewWindow -PassThru
                        
                        if ($installProcess.ExitCode -eq 0) {
                            Write-Host "-> [$($pkgName)] のインストールに成功しました。`n" -ForegroundColor Green
                        }
                        else {
                            Write-Warning "-> [$($pkgName)] のインストール中にエラーが発生しました。`n"
                            $script:FailedItems.Add("$($manager.managerName): $($pkgName)")
                        }
                    }
                }
            }
            Write-Host "--- $($manager.managerName) パッケージのインストールが完了しました ---" -ForegroundColor Green
        }
    }

    # --- フェーズ2の完了報告 ---
    Write-Host "`n==============================================="
    if ($script:FailedItems.Count -gt 0) {
        Write-Warning "一部の処理でエラーが発生しました。詳細は以下の通りです："
        foreach ($failedItem in $script:FailedItems) {
            Write-Warning "- $failedItem"
        }
        Write-Host "==============================================="
    }
    Write-Host "  すべてのセットアップ処理が完了しました！" -ForegroundColor Green
    Write-Host "==============================================="
    Read-Host "Enterキーを押して、このウィンドウを閉じてください。"
    Stop-Transcript
    exit
}