<#
.SYNOPSIS
    Windows PCの初期セットアップと開発環境構築を自動化します。
.DESCRIPTION
    このスクリプトは、「config.yaml」設定ファイルに基づき、PCのセットアップを自動実行します。
    処理はシステムの再起動を挟む2つのフェーズで構成されます。
    フェーズ1では、システム設定の変更、Wingetによるアプリのインストール、不要なプリインストールアプリの削除、そして全アプリの更新を行います。
    フェーズ1完了後、再起動を経てフェーズ2が自動開始されるよう設定されます。
    フェーズ2では、npmやpipなどのパッケージマネージャーを通じて開発用ライリをインストールします。
.PARAMETER SetupPhase
    実行するセットアップフェーズを内部的に指定します（例: '2'）。
    このパラメータはフェーズ1から2へ移行する際にスクリプトが内部で使用するため、ユーザーが手動で指定する必要はありません。
.EXAMPLE
    # 1. PowerShellを「管理者として実行」で起動します。
    # 2. スクリプトが保存されているフォルダに移動します。
    # 3. 以下のコマンドを実行します。
    .\AutoSetup.ps1
.NOTES
    - スクリプトの実行には管理者権限が必須です。
    - スクリプトと同じフォルダに「config.yaml」を配置する必要があります。
    - 安定したインターネット接続環境で実行してください。
    - このスクリプトはPowerShell 3.0以上を想定しています。
    Copyright (c) 2025 sin4auto
#>
#=============================================================================
# ■ パラメータ定義
#=============================================================================
param(
    # スクリプトの実行フェーズ（1または2）を格納するパラメータ。
    [string]$setupPhase
)
#=============================================================================
# ■ グローバル変数の初期化
#=============================================================================
# 失敗した処理名を記録するスクリプトワイドなリスト。
$script:failedItems = [System.Collections.Generic.List[string]]::new()
#=============================================================================
# ■ 文字エンコーディングの設定
#=============================================================================
# 外部コマンドの文字化けを防ぐためコンソール出力をUTF-8に設定。
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# PowerShell自体の出力エンコーディングもUTF-8に統一。
$OutputEncoding = [System.Text.Encoding]::UTF8
#=============================================================================
# ■ ログ記録の開始
#=============================================================================
# スクリプトの全実行内容をログファイルに記録開始。
$logFileName = "AutoSetup.log"
$logFilePath = Join-Path $PSScriptRoot $logFileName
# 既存ログに追記し、フェーズ1と2のログを1ファイルに統合。
Start-Transcript -Path $logFilePath -Append
#=============================================================================
# ■ 実行前準備 (設定ファイルの読み込みと環境チェック)
#=============================================================================
# --- YAML解析モジュールの準備 ---
try {
    # YAML解析用モジュール（powershell-yaml）の存在を確認。
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Host "YAMLモジュールが見つかりません。インストールを試みます..." -ForegroundColor Yellow
        # モジュールがなければPowerShell Galleryから自動インストール。
        Install-Module -Name powershell-yaml -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Write-Host "YAMLモジュールのインストールが完了しました。" -ForegroundColor Green
    }
    # モジュールを現在のセッションにインポート。
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    # モジュール準備失敗時はエラーを表示して終了。
    Write-Error "YAMLモジュールの準備に失敗しました。管理者権限で `Install-Module -Name powershell-yaml` を手動で実行してください。"
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit
}
# --- 設定ファイルの読み込み ---
try {
    # スクリプトと同じディレクトリにあるconfig.yamlを検索。
    $configFilePath = Join-Path $PSScriptRoot "config.yaml"
    if (-not (Test-Path $configFilePath)) {
        $configFilePath = Join-Path $PSScriptRoot "config.yml"
    }
    if (-not (Test-Path $configFilePath)) {
        throw "設定ファイル 'config.yaml' または 'config.yml' が見つかりません。"
    }
    $configFileName = Split-Path -Leaf $configFilePath
    Write-Host "設定ファイル '$configFileName' を読み込んでいます..."
    # YAMLファイルをUTF-8で読み込みPowerShellオブジェクトに変換。
    $config = Get-Content -Path $configFilePath -Encoding UTF8 -Raw | ConvertFrom-Yaml
}
catch {
    # 設定ファイルの読み込みや解析失敗時はエラーを表示して終了。
    Write-Error "設定ファイルの読み込みでエラーが発生しました: $($_.Exception.Message)"
    if ($_.Exception.InnerException -is [YamlDotNet.Core.YamlException]) {
        # YAMLの書式不正の可能性をユーザーに通知。
        Write-Error "YAMLの書式が正しくない可能性があります。インデント等を確認してください。"
    }
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit
}
# --- 管理者権限の確認 ---
# フェーズ1は管理者権限が必須なため初回実行時にチェック。
if ($setupPhase -ne '2') {
    # 現在のユーザーが管理者ロールを持つか確認。
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "エラー: 管理者権限が必要です。PowerShellを右クリックして「管理者として実行」してください。"
        Read-Host "Enterキーを押して終了します。"
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
if ($setupPhase -ne '2') {
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ1 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    # --- Windowsのシステム設定変更 ---
    if ($config.phase1.windowsSettings) {
        Write-Host "--- 1. Windowsの各種設定を変更します ---`n" -ForegroundColor Green
        # 設定ファイルで定義された各設定を順次実行。
        foreach ($setting in $config.phase1.windowsSettings) {
            Write-Host "-> $($setting.description)..."
            # コマンドが定義されているかを確認。
            if (-not ([string]::IsNullOrEmpty($setting.command))) {
                # 設定ファイルから読み込んだコマンドを実行。
                Invoke-Expression -Command $setting.command
                # 外部コマンドの終了コードで成功か失敗かを判定。
                if ($LASTEXITCODE -ne 0) {
                    # 失敗時はエラー内容をリストに追加。
                    $errorMessage = "設定変更失敗: $($setting.description)"
                    Write-Warning "-> コマンドの実行に失敗しました。終了コード: $LASTEXITCODE"
                    $script:failedItems.Add($errorMessage)
                }
            }
            else {
                # コマンド未定義の場合もエラーとしてリストに追加。
                $errorMessage = "設定変更失敗: $($setting.description) - commandプロパティが定義されていません。"
                Write-Warning "-> commandプロパティが定義されていません。"
                $script:failedItems.Add($errorMessage)
            }
        }
        Write-Host "`n--- Windowsの各種設定変更が完了しました ---`n" -ForegroundColor Green
    }
    # --- アプリケーションのインストール (winget) ---
    if ($config.phase1.wingetInstall) {
        Write-Host "--- 2. アプリケーションのインストールを開始します ---`n" -ForegroundColor Green
        winget source reset --force
        # 設定ファイルで定義された各アプリを順次インストール。
        foreach ($wingetApp in $config.phase1.wingetInstall) {
            Write-Host "アプリ [$($wingetApp.id)] の状態を確認しています..."
            # winget listコマンドでアプリがインストール済みか確認。
            winget list --id $wingetApp.id -e --accept-source-agreements --disable-interactivity
            # 終了コード0ならインストール済みと判断。
            if ($LASTEXITCODE -eq 0) {
                Write-Host "-> [$($wingetApp.id)] はインストール済みです。`n" -ForegroundColor Cyan
            }
            else {
                Write-Host "-> [$($wingetApp.id)] をインストールします..."
                # winget installコマンドの引数を配列として準備。
                $wingetArgs = @(
                    'install',
                    '--id', $wingetApp.id,
                    '-e',
                    '--accept-package-agreements',
                    '--accept-source-agreements',
                    '--disable-interactivity'
                )
                # 個別オプションがあれば引数配列に追加。
                if (-not ([string]::IsNullOrEmpty($wingetApp.options))) {
                    $wingetArgs += $wingetApp.options.Split(' ')
                    Write-Host "-> 個別オプション ($($wingetApp.options)) を適用します。" -ForegroundColor Yellow
                }
                # Splattingを使って安全に引数を渡しインストール実行。
                winget @wingetArgs
                # 終了コード0ならインストール成功と判断。
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($wingetApp.id)] のインストールに成功しました。`n" -ForegroundColor Green
                }
                else {
                    # 失敗時はエラー内容をリストに追加。
                    Write-Warning "-> [$($wingetApp.id)] のインストール中にエラーが発生しました。終了コード: $LASTEXITCODE`n"
                    $script:failedItems.Add("Winget Install: $($wingetApp.id)")
                }
            }
        }
        Write-Host "--- アプリケーションのインストールが完了しました ---`n" -ForegroundColor Green
    }
    # --- 不要な標準アプリの削除 ---
    if ($config.phase1.appxRemove) {
        Write-Host "--- 3. 不要なプリインストールアプリの削除を開始します ---`n" -ForegroundColor Green
        # 設定ファイルで定義された各アプリを順次処理。
        foreach ($appxPackage in $config.phase1.appxRemove) {
            Write-Host "[$($appxPackage.name)] を検索し、存在すれば削除します..."
            # ワイルドカード名でパッケージを検索して一括削除。
            # このコマンドレットは$LASTEXITCODEを更新しないためエラーは無視。
            Get-AppxPackage -AllUsers $appxPackage.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }
        Write-Host "`n--- 不要なプリインストールアプリの削除が完了しました ---`n" -ForegroundColor Green
    }
    # --- インストール済みアプリ全体を更新 ---
    Write-Host "--- 4. インストール済みアプリ全体を更新します ---`n" -ForegroundColor Green
    # wingetで管理される全アプリを最新版に更新。
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
    # 終了コードが0以外なら更新プロセスで問題発生と判断。
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "-> アプリ全体の更新プロセス中にエラーが報告されました。終了コード: $LASTEXITCODE"
        $script:failedItems.Add("Winget Upgrade: 全体更新")
    }
    Write-Host "--- インストール済みアプリ全体の更新が完了しました ---`n" -ForegroundColor Green
    # --- フェーズ2の自動実行設定と再起動 ---
    Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---`n" -ForegroundColor Green
    try {
        # レジストリのRunOnceキーにフェーズ2実行コマンドを登録。
        $runOnceRegistryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        # 次回ログオン時にこのスクリプトを引数付きで再度実行するコマンド。
        $runOnceCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$PSCommandPath`" -setupPhase 2"
        Set-ItemProperty -Path $runOnceRegistryKeyPath -Name "AutoSetupPhase2" -Value $runOnceCommand -Force -ErrorAction Stop
        Write-Host "再起動後の自動実行設定が完了しました。`n"
    }
    catch {
        Write-Error "致命的エラー: 再起動後の自動実行設定に失敗しました。フェーズ2は開始されません。"
        Write-Error $_.Exception.Message
        $script:failedItems.Add("致命的エラー: RunOnceレジストリ設定失敗")
    }
    # --- フェーズ1の完了報告と自動再起動 ---
    Write-Host "==============================================="
    # 失敗項目があれば一覧表示。
    if ($script:failedItems.Count -gt 0) {
        Write-Warning "フェーズ1の一部の処理でエラーが発生しました。詳細は以下の通りです："
        foreach ($failedItem in $script:failedItems) {
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
if ($setupPhase -eq '2') {
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ2 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    Write-Host "10秒後に自動でパッケージのインストールが開始されます。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    # --- パッケージインストールの実行ループ ---
    if ($config.phase2.packageManagers) {
        # 設定された各パッケージマネージャーを順次処理。
        foreach ($manager in $config.phase2.packageManagers) {
            Write-Host "`n--- $($manager.managerName) パッケージのインストールを開始します ---`n" -ForegroundColor Green
            # パッケージリストが未定義ならスキップ。
            if (-not $manager.packages) {
                Write-Host "-> $($manager.managerName) でインストールするパッケージが定義されていないため、スキップします。`n" -ForegroundColor Yellow
                continue
            }
            # 各マネージャーでインストールするパッケージを順次処理。
            foreach ($packageName in $manager.packages) {
                Write-Host "パッケージ [$($packageName)] の状態を確認しています..."
                # コマンドテンプレートの{package}を実際のパッケージ名に置換。
                $checkCommand = $manager.checkCommand -replace '\{package\}', $packageName
                # 確認コマンドを実行。
                Invoke-Expression -Command $checkCommand
                # 終了コードで成功か失敗かを判定。
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($packageName)] はインストール済みです。スキップします。`n" -ForegroundColor Cyan
                } 
                else {
                    Write-Host "-> [$($packageName)] をインストールします..."
                    # インストールコマンドの{package}も同様に置換。
                    $installCommand = $manager.installCommand -replace '\{package\}', $packageName
                    # インストールコマンドを実行。
                    Invoke-Expression -Command $installCommand
                    # 終了コードで成功か失敗かを判定。
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "-> [$($packageName)] のインストールに成功しました。`n" -ForegroundColor Green
                    }
                    else {
                        # 失敗時はエラー内容をリストに追加。
                        $errorMessage = "パッケージ処理失敗: $($manager.managerName) - $packageName"
                        Write-Warning "-> インストールコマンドの実行に失敗しました。終了コード: $LASTEXITCODE"
                        $script:failedItems.Add($errorMessage)
                    }
                }
            }
            Write-Host "--- $($manager.managerName) パッケージのインストールが完了しました ---" -ForegroundColor Green
        }
    }
    # --- フェーズ2の完了報告 ---
    Write-Host "`n==============================================="
    # 失敗項目があれば一覧表示。
    if ($script:failedItems.Count -gt 0) {
        Write-Warning "一部の処理でエラーが発生しました。詳細は以下の通りです："
        foreach ($failedItem in $script:failedItems) {
            Write-Warning "- $failedItem"
        }
        Write-Host "==============================================="
    }
    Write-Host "  すべてのセットアップ処理が完了しました！" -ForegroundColor Green
    Write-Host "==============================================="
    # ユーザーが結果を確認できるようキー入力を待機。
    Read-Host "Enterキーを押して、このウィンドウを閉じてください。"
    Stop-Transcript
    exit
}