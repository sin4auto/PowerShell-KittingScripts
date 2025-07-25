<#
.SYNOPSIS
    Windows PCの初期セットアップと開発環境構築を自動化します。
.DESCRIPTION
    このスクリプトは、「config.yaml」設定ファイルに基づき、PCのセットアップを自動実行します。
    処理はシステムの再起動を挟む2つのフェーズで構成されます。
    フェーズ1では、システム設定の変更、Wingetによるアプリのインストール、不要なプリインストールアプリの削除、そして全アプリの更新を行います。
    フェーズ1完了後、再起動を経てフェーズ2が自動開始されるよう設定されます。
    フェーズ2では、npmやpipなどのパッケージマネージャーを通じて開発用ライブラリをインストールします。
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
    # スクリプトが現在どの実行段階にあるかを判断するためのパラメータ。
    [string]$SetupPhase
)
#=============================================================================
# ■ グローバル変数の初期化
#=============================================================================
# スクリプト全体で共有する、失敗した処理の情報を記録するためのリスト。
$script:FailedItems = [System.Collections.Generic.List[string]]::new()
#=============================================================================
# ■ 文字エンコーディングの設定
#=============================================================================
# 外部コマンドの日本語出力が文字化けするのを防ぐため、コンソールの出力をUTF-8に設定します。
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# PowerShell内部の出力エンコーディングもUTF-8に統一します。
$OutputEncoding = [System.Text.Encoding]::UTF8
#=============================================================================
# ■ ログ記録の開始
#=============================================================================
# スクリプトの実行内容をすべてログファイルに記録するため、トランスクリプトを開始します。
$logFileName = "AutoSetup.log"
$logFilePath = Join-Path $PSScriptRoot $logFileName
# -Appendオプションにより、既存のログファイルに追記し、フェーズ1と2のログを1つのファイルにまとめます。
Start-Transcript -Path $logFilePath -Append
#=============================================================================
# ■ 実行前準備 (設定ファイルの読み込みと環境チェック)
#=============================================================================
# --- YAML解析モジュールの準備 ---
try {
    # 設定ファイルの解析に必要な 'powershell-yaml' モジュールがインストールされているか確認します。
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Host "YAMLモジュールが見つかりません。インストールを試みます..." -ForegroundColor Yellow
        # モジュールがなければ、PowerShell Galleryから自動でインストールします。
        Install-Module -Name powershell-yaml -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Write-Host "YAMLモジュールのインストールが完了しました。" -ForegroundColor Green
    }
    # モジュールを現在のセッションにインポートします。
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    # モジュールの準備に失敗した場合、スクリプトを続行できないため終了します。
    Write-Error "YAMLモジュールの準備に失敗しました。管理者権限で `Install-Module -Name powershell-yaml` を手動で実行してください。"
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit
}
# --- 設定ファイルの読み込み ---
try {
    # スクリプトと同じディレクトリにある設定ファイルを探します。
    $configFilePath = Join-Path $PSScriptRoot "config.yaml"
    if (-not (Test-Path $configFilePath)) {
        $configFilePath = Join-Path $PSScriptRoot "config.yml"
    }
    if (-not (Test-Path $configFilePath)) {
        throw "設定ファイル 'config.yaml' または 'config.yml' が見つかりません。"
    }
    $configFileName = Split-Path -Leaf $configFilePath
    Write-Host "設定ファイル '$configFileName' を読み込んでいます..."
    # ファイルをUTF-8として読み込み、YAML形式からPowerShellオブジェクトに変換します。
    $config = Get-Content -Path $configFilePath -Encoding UTF8 -Raw | ConvertFrom-Yaml
}
catch {
    # 設定ファイルの読み込みや解析に失敗した場合、スクリプトを終了します。
    Write-Error "設定ファイルの読み込みでエラーが発生しました: $($_.Exception.Message)"
    if ($_.Exception.InnerException -is [YamlDotNet.Core.YamlException]) {
        Write-Error "YAMLの書式が正しくない可能性があります。インデント等を確認してください。"
    }
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit
}
# --- 管理者権限の確認 ---
# フェーズ1の処理はシステム設定の変更を含むため、管理者権限が必須です。
if ($SetupPhase -ne '2') {
    # 現在の実行ユーザーが管理者ロールを持っているか確認します。
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
if ($SetupPhase -ne '2') {
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ1 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    # --- Windowsのシステム設定変更 ---
    if ($config.phase1.windowsTweaks) {
        Write-Host "--- 1. Windowsの各種設定を変更します ---`n" -ForegroundColor Green
        # 設定ファイルに定義された各設定をループで処理します。
        foreach ($tweak in $config.phase1.windowsTweaks) {
            Write-Host "-> $($tweak.description)..."
            # commandキーに値が設定されているか確認します。
            if (-not ([string]::IsNullOrEmpty($tweak.command))) {
                # コマンド文字列を実行します。
                Invoke-Expression -Command $tweak.command
                # 直前のコマンドが失敗したか($?が$falseか)を判定します。
                if (-not $?) {
                    # 失敗した場合、エラーリストに情報を追加します。
                    $errorMessage = "設定変更失敗: $($tweak.description)"
                    Write-Warning "-> コマンドの実行に失敗しました。"
                    $script:FailedItems.Add($errorMessage)
                }
            }
            else {
                # commandキー自体が未定義の場合もエラーとして記録します。
                $errorMessage = "設定変更失敗: $($tweak.description) - commandプロパティが定義されていません。"
                Write-Warning "-> commandプロパティが定義されていません。"
                $script:FailedItems.Add($errorMessage)
            }
        }
        Write-Host "`n--- Windowsの各種設定変更が完了しました ---`n" -ForegroundColor Green
    }
    # --- アプリケーションのインストール (winget) ---
    if ($config.phase1.wingetInstall) {
        Write-Host "--- 2. アプリケーションのインストールを開始します ---`n" -ForegroundColor Green
        # 設定された各アプリケーションをループで処理します。
        foreach ($app in $config.phase1.wingetInstall) {
            Write-Host "アプリ [$($app.id)] の状態を確認しています..."
            # winget listでアプリがインストール済みか確認します。
            winget list --id $app.id -e --accept-source-agreements --disable-interactivity
            # 直前のwingetコマンドが成功したか($?が$trueか)で判定します。
            if ($?) {
                Write-Host "-> [$($app.id)] はインストール済みです。`n" -ForegroundColor Cyan
            }
            else {
                Write-Host "-> [$($app.id)] をインストールします..."
                # インストール用の引数を配列で組み立てます。
                $wingetArgs = @(
                    'install',
                    '--id', $app.id,
                    '-e',
                    '--accept-package-agreements',
                    '--accept-source-agreements',
                    '--disable-interactivity'
                )
                # 個別のオプションが指定されていれば、引数に追加します。
                if (-not ([string]::IsNullOrEmpty($app.options))) {
                    $wingetArgs += $app.options.Split(' ')
                    Write-Host "-> 個別オプション ($($app.options)) を適用します。" -ForegroundColor Yellow
                }
                # splatting(@)を使って安全に引数を渡し、winget installを実行します。
                winget @wingetArgs
                # インストールコマンドが成功したか判定します。
                if ($?) {
                    Write-Host "-> [$($app.id)] のインストールに成功しました。`n" -ForegroundColor Green
                }
                else {
                    # 失敗した場合、エラーリストに情報を追加します。
                    Write-Warning "-> [$($app.id)] のインストール中にエラーが発生しました。`n"
                    $script:FailedItems.Add("Winget Install: $($app.id)")
                }
            }
        }
        Write-Host "--- アプリケーションのインストールが完了しました ---`n" -ForegroundColor Green
    }
    # --- 不要な標準アプリの削除 ---
    if ($config.phase1.appxRemove) {
        Write-Host "--- 3. 不要なプリインストールアプリの削除を開始します ---`n" -ForegroundColor Green
        # 設定された各アプリをループで処理します。
        foreach ($app in $config.phase1.appxRemove) {
            Write-Host "[$($app.name)] を検索し、存在すれば削除します..."
            # ワイルドカードを含む名前でパッケージを探し、見つかったものをすべて削除します。
            Get-AppxPackage -AllUsers $app.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }
        Write-Host "`n--- 不要なプリインストールアプリの削除が完了しました ---`n" -ForegroundColor Green
    }
    # --- インストール済みアプリ全体を更新 ---
    Write-Host "--- 4. インストール済みアプリ全体を更新します ---`n" -ForegroundColor Green
    # wingetで管理されているすべてのアプリを更新します。
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
    # 更新コマンドが失敗したか判定します。
    if (-not $?) {
        Write-Warning "-> アプリ全体の更新プロセス中にエラーが報告されました。"
        $script:FailedItems.Add("Winget Upgrade: 全体更新")
    }
    Write-Host "--- インストール済みアプリ全体の更新が完了しました ---`n" -ForegroundColor Green
    # --- フェーズ2の自動実行設定と再起動 ---
    Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---`n" -ForegroundColor Green
    # Windowsの「RunOnce」レジストリキーに、フェーズ2を実行するコマンドを登録します。
    # このキーに登録されたコマンドは、次回のユーザーログオン時に一度だけ実行されます。
    $runOnceRegistryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $runOnceCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$PSCommandPath`" -SetupPhase 2"
    Set-ItemProperty -Path $runOnceRegistryKeyPath -Name "AutoSetupPhase2" -Value $runOnceCommand -Force
    Write-Host "再起動後の自動実行設定が完了しました。`n"
    # --- フェーズ1の完了報告と自動再起動 ---
    Write-Host "==============================================="
    # 失敗した項目があれば、リストアップして報告します。
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
        # 設定された各パッケージマネージャーをループで処理します (npm, pipなど)。
        foreach ($manager in $config.phase2.packageManagers) {
            Write-Host "`n--- $($manager.managerName) パッケージのインストールを開始します ---`n" -ForegroundColor Green
            # ガード節を使い、パッケージリストが未定義ならスキップします。
            if (-not $manager.packages) {
                Write-Host "-> $($manager.managerName) でインストールするパッケージが定義されていないため、スキップします。`n" -ForegroundColor Yellow
                continue
            }
            # 各マネージャーでインストールするパッケージをループで処理します。
            foreach ($pkgName in $manager.packages) {
                Write-Host "パッケージ [$($pkgName)] の状態を確認しています..."
                # {package} という文字列を、実際のパッケージ名に置換します。
                $checkCommand = $manager.checkCommand -replace '\{package\}', $pkgName
                # 確認コマンドを実行します。
                Invoke-Expression -Command $checkCommand
                # [修正点] 外部コマンドの終了コードで判定します。
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($pkgName)] はインストール済みです。スキップします。`n" -ForegroundColor Cyan
                } 
                else {
                    Write-Host "-> [$($pkgName)] をインストールします..."
                    # インストールコマンドの{package}を置換します。
                    $installCommand = $manager.installCommand -replace '\{package\}', $pkgName
                    # インストールコマンドを実行します。
                    Invoke-Expression -Command $installCommand
                     # [修正点] 外部コマンドの終了コードで判定します。
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "-> [$($pkgName)] のインストールに成功しました。`n" -ForegroundColor Green
                    }
                    else {
                        # 失敗した場合、エラーリストに情報を追加します。
                        $errorMessage = "パッケージ処理失敗: $($manager.managerName) - $pkgName"
                        Write-Warning "-> インストールコマンドの実行に失敗しました。"
                        $script:FailedItems.Add($errorMessage)
                    }
                }
            }
            Write-Host "--- $($manager.managerName) パッケージのインストールが完了しました ---" -ForegroundColor Green
        }
    }
    # --- フェーズ2の完了報告 ---
    Write-Host "`n==============================================="
    # 失敗した項目があれば、リストアップして報告します。
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