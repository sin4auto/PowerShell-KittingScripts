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
    Copyright (c) 2025 sin4auto
#>

#=============================================================================
# ■ 1. パラメータ定義
#=============================================================================
param(
    # スクリプトが現在どのフェーズを実行すべきかを判断するための内部パラメータ。
    [string]$SetupPhase
)

#=============================================================================
# ■ 2. グローバル変数の初期化
#=============================================================================
# スクリプト実行中に発生したエラー項目を記録するためのリスト。
# スクリプトスコープ($script:)で定義し、どこからでもアクセス可能にする。
$script:FailedItems = [System.Collections.Generic.List[string]]::new()

#=============================================================================
# ■ 2.5 ログ記録の開始
#=============================================================================
# スクリプトの実行パスを取得。
$scriptRootPathForLog = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
# ログファイル名を固定にする。
$logFileName = "AutoSetup.log"
$logFilePath = Join-Path $scriptRootPathForLog $logFileName
# トランスクリプト（コンソール画面の記録）を開始。
# -Append スイッチにより、ファイルが存在すれば追記し、なければ新規作成する。
# これにより、フェーズ1とフェーズ2のログが同一ファイルに記録される。
Start-Transcript -Path $logFilePath -Append
# この時点ではログファイルパスを表示するのみ。Clear-Hostで消されることを想定。

#=============================================================================
# ■ 3. 実行前準備 (設定ファイルの読み込みと環境チェック)
#=============================================================================
# --- 3.1. YAML解析モジュールの準備 ---
try {
    # このスクリプトはYAML設定ファイルを扱うため、'powershell-yaml'モジュールが必須。
    # まず、モジュールが利用可能かを確認する。
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Host "YAML設定ファイルを読み込むために 'powershell-yaml' モジュールが必要です。" -ForegroundColor Yellow
        Write-Host "モジュールのインストールを試みます...（初回のみ）" -ForegroundColor Yellow
        # ユーザーの環境を汚さないよう、現在のユーザーのスコープにインストールする。
        Install-Module -Name powershell-yaml -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Write-Host "'powershell-yaml' モジュールのインストールに成功しました。" -ForegroundColor Green
    }
    # モジュールを現在のPowerShellセッションにインポートする。
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    Write-Error "YAMLモジュールのインストールまたはインポートに失敗しました。`nお手数ですが、PowerShellを管理者として実行し、次のコマンドを手動で実行してください: Install-Module -Name powershell-yaml"
    Read-Host "Enterキーを押すと終了します。"
    Stop-Transcript
    exit
}

# --- 3.2. 設定ファイルの読み込み ---
try {
    # スクリプト自身のパスを基準に、カレントディレクトリを移動する。
    $scriptRootPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Set-Location -Path $scriptRootPath
    # 'config.yaml' または一般的な別名 'config.yml' を探索する。
    $configFileName = "config.yaml"
    $configFilePath = Join-Path $scriptRootPath $configFileName
    if (-not (Test-Path $configFilePath)) {
        $configFileName = "config.yml"
        $configFilePath = Join-Path $scriptRootPath $configFileName
        if (-not (Test-Path $configFilePath)) { throw "設定ファイル 'config.yaml' または 'config.yml' が見つかりません。" }
    }
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

# --- 3.3. 管理者権限の確認 ---
# フェーズ1はシステム変更を伴うため、管理者権限が不可欠。
if ($SetupPhase -ne '2') {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "エラー：このスクriptの実行には管理者権限が必要です。`nPowerShellのアイコンを右クリックし、「管理者として実行」を選択してから再度お試しください。"
        Read-Host "Enterキーを押すとスクリプトを終了します。"
        Stop-Transcript
        exit
    }
}

#=============================================================================
# ■ 4. メインロジック (フェーズ分岐)
#   $SetupPhaseパラメータの値に応じて、フェーズ1またはフェーズ2の処理を実行する。
#=============================================================================

#----------------------------------------------------------------------
# ● フェーズ1 (初回実行): システムの基本セットアップ
#   -SetupPhaseパラメータが指定されていない場合、こちらが実行される。
#----------------------------------------------------------------------
if ($SetupPhase -ne '2') {
    Clear-Host
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ1 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    # --- ログファイルパスの再表示 ---
    Write-Host ""
    Write-Host "このセッションのログは以下のファイルに出力されます:" -ForegroundColor Gray
    Write-Host $logFilePath -ForegroundColor Gray
    # --- 4.1.1. アプリケーションのインストール (winget) ---
    if ($config.phase1.wingetInstall) {
        Write-Host ""
        Write-Host "--- 1. アプリケーションのインストールを開始します ---" -ForegroundColor Green  
        # 設定ファイルに記載されたアプリを一つずつ処理する
        foreach ($app in $config.phase1.wingetInstall) {
            Write-Host "アプリ [$($app.id)] の状態を確認しています..."
            winget list --id $app.id -e --accept-source-agreements > $null
            # 既にインストール済みかチェック
            if ($LASTEXITCODE -eq 0) {
                Write-Host "-> [$($app.id)] はインストール済みです。" -ForegroundColor Cyan
            }
            # 未インストールの場合、インストール処理を実行
            else {
                Write-Host "-> [$($app.id)] をインストールします..."
                $wingetCommand = "winget install --id $($app.id) -e --accept-package-agreements --accept-source-agreements"
                
                # インストールオプションが指定されていればコマンドに追加
                if ($app.PSObject.Properties.Name -contains 'options' -and $app.options) {
                    $wingetCommand += " $($app.options)"
                    Write-Host "-> 個別オプション ($($app.options)) を適用します。" -ForegroundColor Yellow
                }
                # wingetコマンドを実行
                Invoke-Expression -Command $wingetCommand
                # インストールの成否を判定
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($app.id)] のインストールに成功しました。" -ForegroundColor Green
                }
                else {
                    Write-Warning "-> [$($app.id)] のインストール中にエラーが発生しました。"
                    $script:FailedItems.Add("Winget: $($app.id)")
                }
            }
        }
        Write-Host "--- アプリケーションのインストールが完了しました ---" -ForegroundColor Green
    }

    # --- 4.1.2. 不要な標準アプリの削除 ---
    if ($config.phase1.appxRemove) {
        Write-Host ""
        Write-Host "--- 2. 不要なプリインストールアプリの削除を開始します ---" -ForegroundColor Green
        # 設定ファイルに記載されたアプリを一つずつ削除
        foreach ($app in $config.phase1.appxRemove) {
            Write-Host "[$($app.name)] を検索し、存在すれば削除します..."
            Get-AppxPackage -AllUsers $app.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }
        Write-Host "--- 不要なプリインストールアプリの削除が完了しました ---" -ForegroundColor Green
    }

    # --- 4.1.3. 既存アプリのアップグレード ---
    if ($config.phase1.otherTasks.upgradeAllApps) {
        Write-Host ""
        Write-Host "--- 3. インストール済みアプリをすべて最新版に更新します ---" -ForegroundColor Green
        winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
        Write-Host "--- アプリの更新が完了しました ---" -ForegroundColor Green
    }

    # --- 4.1.4. Windowsのシステム設定変更 ---
    if ($config.phase1.windowsTweaks) {
        Write-Host ""
        Write-Host "--- 4. Windowsの各種設定を変更します ---" -ForegroundColor Green
        # 設定ファイルに記載されたWindows設定変更を一つずつ実行
        foreach ($tweak in $config.phase1.windowsTweaks) {
            Write-Host "-> $($tweak.description)..."
            try {
                $parentPath = Split-Path -Path $tweak.path
                # レジストリキーの親パスが存在しない場合は作成する
                if (-not (Test-Path $parentPath)) {
                    New-Item -Path $parentPath -Force | Out-Null
                }
                # config.yamlで定義された 'type' に基づき、実行するコマンドを切り替える。
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
        Write-Host "--- Windowsの各種設定変更が完了しました ---" -ForegroundColor Green
    }

    # --- 4.1.5. フェーズ2の自動実行設定と再起動 ---
    Write-Host ""
    Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---" -ForegroundColor Green
    $runOnceRegistryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $currentScriptPath = $MyInvocation.MyCommand.Path
    $runOnceCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$currentScriptPath`" -SetupPhase 2"
    Set-ItemProperty -Path $runOnceRegistryKeyPath -Name "AutoSetupPhase2" -Value $runOnceCommand -Force
    Write-Host "再起動後の自動実行設定が完了しました。"

    # --- 4.1.6. フェーズ1の完了報告と自動再起動 ---
    Write-Host ""
    Write-Host "==============================================="
    # 失敗した項目があればリスト表示する
    if ($script:FailedItems.Count -gt 0) {
        Write-Warning "フェーズ1の一部の処理でエラーが発生しました。詳細は以下の通りです："
        # 失敗した項目を一つずつ表示
        foreach ($failedItem in $script:FailedItems) {
            Write-Warning "- $failedItem"
        }
        Write-Host "==============================================="
    }
    Write-Host "  フェーズ1のすべての処理が完了しました！" -ForegroundColor Green
    Write-Host "==============================================="
    Write-Host ""
    Write-Host "設定を完全に適用するため、システムを再起動します。" -ForegroundColor Yellow
    Write-Host "10秒後に自動で再起動が開始されます。中断したい場合はこのウィンドウを閉じてください。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Stop-Transcript
    Restart-Computer -Force
}

#----------------------------------------------------------------------
# ● フェーズ2 (再起動後): 開発者向けパッケージのインストール
#   -SetupPhaseパラメータが '2' の場合、こちらが実行される。
#----------------------------------------------------------------------
if ($SetupPhase -eq '2') {
    # 起動直後のシステム安定化のため、少し待機する。
    Start-Sleep -Seconds 1
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ2 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "10秒後に自動でパッケージのインストールが開始されます。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # --- 4.2.1. パッケージインストールの実行ループ ---
    # config.yaml の `phase2` セクションに `packageInstall` が定義されているか確認
    if ($config.phase2.packageInstall) {
        # `packageInstall` のキー (npm, pip など) を一つずつ処理
        foreach ($managerName in $config.phase2.packageInstall.Keys) {
            # 対応するパッケージマネージャーの定義を `packageManagers` から探す
            $managerDef = $config.packageManagers | Where-Object { $_.managerName -eq $managerName }

            if (-not $managerDef) {
                Write-Warning "設定ファイル(config.yaml)の 'packageManagers' に '$($managerName)' の定義が見つかりません。スキップします。"
                continue
            }
            
            # 実行に必要なコマンドが存在するか確認
            if (-not (Get-Command $managerDef.executable -ErrorAction SilentlyContinue)) {
                $errorMessage = "必須コマンド '$($managerDef.executable)' が見つかりません。($($managerName)の処理はスキップされます)"
                Write-Warning $errorMessage
                $script:FailedItems.Add($errorMessage)
                continue
            }

            Write-Host ""
            Write-Host "--- $($managerName) パッケージのインストールを開始します ---" -ForegroundColor Green
            
            # インストール対象のパッケージリストを取得
            $packagesToInstall = $config.phase2.packageInstall.$managerName

            # 設定ファイルに記載されたパッケージを一つずつ処理
            foreach ($package in $packagesToInstall) {
                $pkgName = $package.package
                Write-Host "パッケージ [$($pkgName)] の状態を確認しています..."
                
                # Checkコマンドのテンプレートにパッケージ名を埋め込む
                $checkCmd = $managerDef.checkCommand -replace '\{package\}', $pkgName
                
                # Checkコマンドを実行して、インストール済みか判定
                $isInstalled = try { Invoke-Expression $checkCmd > $null 2>$null; $LASTEXITCODE -eq 0 } catch { $false }
                
                # 既にインストール済みかチェック
                if ($isInstalled) {
                    Write-Host "-> [$($pkgName)] はインストール済みです。スキップします。" -ForegroundColor Cyan
                } 
                # 未インストールの場合、インストール処理を実行
                else {
                    Write-Host "-> [$($pkgName)] をインストールします..."
                    
                    # Installコマンドのテンプレートにパッケージ名を埋め込む
                    $installCmd = $managerDef.installCommand -replace '\{package\}', $pkgName
                    Invoke-Expression $installCmd
                    
                    # インストールの成否を判定
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "-> [$($pkgName)] のインストールに成功しました。" -ForegroundColor Green
                    }
                    else {
                        Write-Warning "-> [$($pkgName)] のインストール中にエラーが発生しました。"
                        $script:FailedItems.Add("$($managerName): $($pkgName)")
                    }
                }
            }
            Write-Host "--- $($managerName) パッケージのインストールが完了しました ---" -ForegroundColor Green
        }
    }

    # --- 4.2.2. フェーズ2の完了報告 ---
    Write-Host ""
    Write-Host "==============================================="
    # 失敗した項目があればリスト表示する
    if ($script:FailedItems.Count -gt 0) {
        Write-Warning "一部の処理でエラーが発生しました。詳細は以下の通りです："
        # 失敗した項目を一つずつ表示
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