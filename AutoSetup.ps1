<#
.SYNOPSIS
    Windows PCの初期セットアップと開発環境構築を自動化します。
.DESCRIPTION
    このスクリプトは、「recipe.yaml」設定ファイルに基づき、PCのセットアップを自動実行します。
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
    - スクリプトと同じフォルダに「recipe.yaml」を配置。
    - 要管理者権限。
    - 初回実行にはインターネット接続が必須。
    - PowerShell 5.1での動作を想定。
    Copyright (c) 2025 sin4auto
#>
#=============================================================================
# ■ パラメータ定義
#=============================================================================
param(
    # 再起動後にフェーズ2を実行するため、スクリプトが内部的に使用する引数。
    # '2'が指定された場合、フェーズ2の処理ブロックが実行される。
    [string]$setupPhase
)
#=============================================================================
# ■ グローバル変数の初期化
#=============================================================================
# スクリプト実行中に発生したエラーの情報を格納するためのリストを準備する。
# 'script:'スコープを使い、スクリプト内のどこからでもアクセス可能にする。
$script:failedItems = [System.Collections.Generic.List[string]]::new()
# 再起動後の自動実行で利用するタスクスケジューラのタスク名を定義する。
$TaskName = "AutoSetupPhase2Task"
#=============================================================================
# ■ 文字エンコーディングの設定
#=============================================================================
# wingetなどの外部コマンドが出力する日本語が文字化けするのを防ぐため、
# コンソールの出力エンコーディングをUTF-8に設定する。
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# PowerShell内部の出力エンコーディングもUTF-8に統一し、一貫性を保つ。
$OutputEncoding = [System.Text.Encoding]::UTF8
#=============================================================================
# ■ ログ記録の開始
#=============================================================================
# 実行される全コマンドとその出力を記録するログファイル名を定義する。
$logFileName = "AutoSetup.log"
# ログファイルをスクリプトと同じディレクトリに保存するためのフルパスを生成する。
$logFilePath = Join-Path $PSScriptRoot $logFileName
# ログ記録（トランスクリプト）を開始する。-Appendオプションにより、既存のログファイルに追記する形で
# フェーズ1とフェーズ2の実行記録を一つのファイルにまとめる。
Start-Transcript -Path $logFilePath -Append
#=============================================================================
# ■ 実行前準備 (設定ファイルの読み込みと環境チェック)
#=============================================================================
# --- YAML解析モジュールの準備 ---
try {
    # 設定ファイル(YAML形式)を読み込むために必要な'powershell-yaml'モジュールが
    # PCにインストールされているかを確認する。
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Host "YAMLモジュールが見つかりません。インストールを試みます..." -ForegroundColor Yellow
        # モジュールが存在しない場合、PowerShell公式リポジトリから自動的にインストールする。
        # -Scope CurrentUserで現在のユーザーのみにインストールし、管理者権限のエラーを避ける。
        Install-Module -Name powershell-yaml -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Write-Host "YAMLモジュールのインストールが完了しました。" -ForegroundColor Green
    }
    # 準備したモジュールを現在のPowerShellセッションで利用可能にする。
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    # モジュールのインストールまたはインポートに失敗した場合、エラーメッセージを表示してスクリプトを停止する。
    Write-Error "YAMLモジュールの準備に失敗しました。管理者権限で `Install-Module -Name powershell-yaml` を手動で実行してください。"
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit
}
# --- 設定ファイルの読み込み ---
try {
    # スクリプトと同じディレクトリに'recipe.yaml'が存在するか確認する。
    $configFilePath = Join-Path $PSScriptRoot "recipe.yaml"
    # 'recipe.yaml'が見つからない場合、代替として'recipe.yml'を探す。
    if (-not (Test-Path $configFilePath)) {
        $configFilePath = Join-Path $PSScriptRoot "recipe.yml"
    }
    # どちらのファイルも見つからない場合は、エラーを発生させる。
    if (-not (Test-Path $configFilePath)) {
        throw "設定ファイル 'recipe.yaml' または 'recipe.yml' が見つかりません。"
    }
    # 読み込むファイル名を取得して表示する。
    $configFileName = Split-Path -Leaf $configFilePath
    Write-Host "設定ファイル '$configFileName' を読み込んでいます..."
    # 設定ファイルの内容をUTF-8として読み込み、YAMLパーサーでPowerShellオブジェクトに変換する。
    $config = Get-Content -Path $configFilePath -Encoding UTF8 -Raw | ConvertFrom-Yaml
}
catch {
    # ファイルの読み込みやYAMLの解析中にエラーが発生した場合、その内容を表示して終了する。
    Write-Error "設定ファイルの読み込みでエラーが発生しました: $($_.Exception.Message)"
    # エラーがYAMLの構文エラーである場合、ユーザーに書式の確認を促すメッセージを追加で表示する。
    if ($_.Exception.InnerException -is [YamlDotNet.Core.YamlException]) {
        Write-Error "YAMLの書式が正しくない可能性があります。インデント等を確認してください。"
    }
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit
}
# --- 管理者権限の確認 ---
# フェーズ2の実行時($setupPhaseが'2')は、この権限チェックをスキップする。
if ($setupPhase -ne '2') {
    # スクリプトが管理者権限で実行されているかを確認する。
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # 管理者権限がない場合、警告メッセージを表示してスクリプトを終了する。
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
# パラメータ$setupPhaseが'2'でない、つまり初回実行の場合にこのブロックを実行する。
if ($setupPhase -ne '2') {
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ1 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    # --- 既存タスクのクリーンアップ ---
    # 過去の実行で残存している可能性のある自動実行タスクを、安全のために削除する。
    Write-Host "-> 既存の自動実行タスクをクリーンアップします..." -ForegroundColor DarkGray
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    # --- Windowsのシステム設定変更 ---
    # recipe.yamlに'phase1.windowsSettings'セクションが存在する場合にのみ実行する。
    if ($config.phase1.windowsSettings) {
        Write-Host "--- 1. Windowsの各種設定を変更します ---`n" -ForegroundColor Green
        # 設定ファイルに記述された各設定項目を一つずつループ処理する。
        foreach ($setting in $config.phase1.windowsSettings) {
            Write-Host "-> $($setting.description)..."
            # 実行すべきコマンドが定義されていることを確認する。
            if (-not ([string]::IsNullOrEmpty($setting.command))) {
                # 設定ファイルから読み取ったコマンド文字列を実行する。
                Invoke-Expression -Command $setting.command
                # 直前に実行した外部コマンドが正常に終了したかを確認する（終了コード0が成功）。
                if ($LASTEXITCODE -ne 0) {
                    # 失敗した場合、どの処理で失敗したかを示すエラーメッセージを作成する。
                    $errorMessage = "設定変更失敗: $($setting.description)"
                    Write-Warning "-> コマンドの実行に失敗しました。終了コード: $LASTEXITCODE"
                    # 失敗リストにエラーメッセージを追加する。
                    $script:failedItems.Add($errorMessage)
                }
            }
            else {
                # 実行コマンドが定義されていなかった場合もエラーとして扱う。
                $errorMessage = "設定変更失敗: $($setting.description) - commandプロパティが定義されていません。"
                Write-Warning "-> commandプロパティが定義されていません。"
                $script:failedItems.Add($errorMessage)
            }
        }
        Write-Host "`n--- Windowsの各種設定変更が完了しました ---`n" -ForegroundColor Green
    }
    # --- アプリケーションのインストール (winget) ---
    # recipe.yamlに'phase1.wingetInstall'セクションが存在する場合にのみ実行する。
    if ($config.phase1.wingetInstall) {
        Write-Host "--- 2. アプリケーションのインストールを開始します ---`n" -ForegroundColor Green
        # wingetのソースリポジトリをリセットし、潜在的な問題を解消する。
        winget source reset --force
        # 設定ファイルに記述された各アプリケーションを一つずつループ処理する。
        foreach ($wingetApp in $config.phase1.wingetInstall) {
            Write-Host "アプリ [$($wingetApp.id)] の状態を確認しています..."
            # 'winget list'を使い、対象のアプリが既にインストール済みかを確認する。
            winget list --id $wingetApp.id -e --accept-source-agreements --disable-interactivity
            # インストール済みでなければインストールを実行する
            if ($LASTEXITCODE -ne 0) {
                Write-Host "-> [$($wingetApp.id)] をインストールします..."
                $wingetArgs = @(
                    'install', '--id', $wingetApp.id, '-e',
                    '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
                )
                if (-not ([string]::IsNullOrEmpty($wingetApp.options))) {
                    $wingetArgs += $wingetApp.options.Split(' ')
                    Write-Host "-> 個別オプション ($($wingetApp.options)) を適用します。" -ForegroundColor Yellow
                }
                winget @wingetArgs
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($wingetApp.id)] のインストールに成功しました。`n" -ForegroundColor Green
                }
                else {
                    Write-Warning "-> [$($wingetApp.id)] のインストール中にエラーが発生しました。終了コード: $LASTEXITCODE`n"
                    $script:failedItems.Add("Winget Install: $($wingetApp.id)")
                }
            }
            else {
                Write-Host "-> [$($wingetApp.id)] はインストール済みです。スキップします。`n" -ForegroundColor Cyan
            }
        }
        Write-Host "--- アプリケーションのインストールが完了しました ---`n" -ForegroundColor Green
    }
    # --- 不要な標準アプリの削除 ---
    # recipe.yamlに'phase1.appxRemove'セクションが存在する場合にのみ実行する。
    if ($config.phase1.appxRemove) {
        Write-Host "--- 3. プリインストールアプリの削除を開始します ---`n" -ForegroundColor Green
        # 設定ファイルに記述された各UWPアプリを一つずつループ処理する。
        foreach ($appxPackage in $config.phase1.appxRemove) {
            Write-Host "-> [$($appxPackage.name)] を削除します..."
            # ワイルドカードを含むパッケージ名で対象アプリを検索し、PC上の全ユーザーから削除する。
            Get-AppxPackage -AllUsers $appxPackage.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Write-Host "-> [$($appxPackage.name)] の削除処理を実行しました。`n"
        }
        Write-Host "`n--- プリインストールアプリの削除が完了しました ---`n" -ForegroundColor Green
    }
    # --- インストール済みアプリ全体を更新 ---
    Write-Host "--- 4. インストール済みアプリ全体を更新します ---`n" -ForegroundColor Green
    # wingetで管理されている全てのパッケージを最新バージョンに一括で更新する。
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
    # 更新プロセスで何らかの問題が発生したかを確認する。
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "-> アプリ全体の更新プロセス中にエラーが報告されました。終了コード: $LASTEXITCODE"
        $script:failedItems.Add("Winget Upgrade: 全体更新")
    }
    Write-Host "--- インストール済みアプリ全体の更新が完了しました ---`n" -ForegroundColor Green
    # --- フェーズ2の自動実行設定と再起動 ---
    Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---`n" -ForegroundColor Green
    try {
        # タスクとして実行するアクション（このスクリプト自身を引数付きで呼び出す）を定義する。
        $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -setupPhase 2"
        # タスクを実行するトリガー（ユーザーのログオン時）を定義する。
        $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
        # スクリプトを実行している現在のユーザーのIDを確実に取得する。
        $currentUserId = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name
        # タスクの実行者情報と権限レベル（最高の権限）を定義する。
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId $currentUserId -LogonType Interactive -RunLevel Highest
        # 上記で定義したアクション、トリガー、プリンシパルを組み合わせてタスクをOSに登録する。
        Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Force -ErrorAction Stop
        Write-Host "-> タスクスケジューラに '$TaskName' を登録しました。" -ForegroundColor Green
    }
    catch {
        # タスクの登録に失敗した場合、致命的なエラーとして報告する。
        Write-Error "致命的エラー: 再起動後の自動実行設定に失敗しました。フェーズ2は開始されません。"
        Write-Error $_.Exception.Message
        $script:failedItems.Add("致命的エラー: タスクスケジューラ登録失敗")
    }
    # --- フェーズ1の完了報告と自動再起動 ---
    Write-Host "==============================================="
    # もし失敗リストに項目があれば、その内容を一覧表示する。
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
    # ユーザーがメッセージを読むための待機時間を設ける。
    Write-Host "10秒後に自動で再起動が開始されます。中断したい場合はこのウィンドウを閉じてください。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    # ログ記録を正常に終了させる。
    Stop-Transcript
    # システムを強制的に再起動する。
    Restart-Computer -Force
}
#----------------------------------------------------------------------
# ● フェーズ2 (再起動後): 開発者向けパッケージのインストール
#----------------------------------------------------------------------
# パラメータ$setupPhaseが'2'に等しい、つまり再起動後に実行された場合にこのブロックを実行する。
if ($setupPhase -eq '2') {
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ2 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    # --- 自動実行タスクのクリーンアップ ---
    # フェーズ2が開始されたため、このタスクは不要。次の実行に備えて削除する。
    Write-Host "-> 自動実行タスクをクリーンアップします..." -ForegroundColor DarkGray
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    # ネットワーク接続の確立などを待つため、少し待機する。
    Write-Host "10秒後に自動でパッケージのインストールが開始されます。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    # --- パッケージインストールの実行ループ ---
    # recipe.yamlに'phase2.packageManagers'セクションが存在する場合にのみ実行する。
    if ($config.phase2.packageManagers) {
        # 設定ファイルに記述された各パッケージマネージャー（npm, pipなど）をループ処理する。
        foreach ($manager in $config.phase2.packageManagers) {
            Write-Host "`n--- $($manager.managerName) パッケージのインストールを開始します ---`n" -ForegroundColor Green
            # インストールすべきパッケージのリストが存在しない場合は、このマネージャーの処理をスキップする。
            if (-not $manager.packages) {
                Write-Host "-> $($manager.managerName) でインストールするパッケージが定義されていないため、スキップします。`n" -ForegroundColor Yellow
                continue
            }
            # 各パッケージマネージャーのインストール対象パッケージを一つずつループ処理する。
            foreach ($package in $manager.packages) {
                $packageName = $package.name
                Write-Host "パッケージ [$($packageName)] の状態を確認しています..."
                # 設定ファイルの'checkCommand'テンプレート内の'{package}'を実際のパッケージ名で置き換える。
                $checkCommand = $manager.checkCommand -replace '\{package\}', $packageName
                # 生成した確認コマンドを実行する。
                Invoke-Expression -Command $checkCommand
                # 確認コマンドの終了コードが0の場合、パッケージはインストール済みと判断する。
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($packageName)] はインストール済みです。スキップします。`n" -ForegroundColor Cyan
                }
                else {
                    Write-Host "-> [$($packageName)] をインストールします..."
                    # 設定ファイルの'installCommand'テンプレート内の'{package}'を実際のパッケージ名で置き換える。
                    $installCommand = $manager.installCommand -replace '\{package\}', $packageName
                    # 生成したインストールコマンドを実行する。
                    Invoke-Expression -Command $installCommand
                    # インストールが成功したか（終了コード0）を確認する。
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "-> [$($packageName)] のインストールに成功しました。`n" -ForegroundColor Green
                    }
                    else {
                        # インストールに失敗した場合、どの処理で失敗したかを記録する。
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
    # もし失敗リストに項目があれば、その内容を一覧表示する。
    if ($script:failedItems.Count -gt 0) {
        Write-Warning "一部の処理でエラーが発生しました。詳細は以下の通りです："
        foreach ($failedItem in $script:failedItems) {
            Write-Warning "- $failedItem"
        }
        Write-Host "==============================================="
    }
    Write-Host "  すべてのセットアップ処理が完了しました！" -ForegroundColor Green
    Write-Host "==============================================="
    # 実行結果をユーザーが確認できるよう、キー入力があるまでウィンドウを閉じずに待機する。
    Read-Host "Enterキーを押して、このウィンドウを閉じてください。"
    # ログ記録を正常に終了させる。
    Stop-Transcript
    # スクリプトを正常に終了する。
    exit
}