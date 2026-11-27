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
    - PowerShell 5.1 と 7 の両方で動く。Start-Admin.bat は、7 があれば 7 で起動する。
    - 5.1 で始めても、再起動のときに 7 が入っていれば、再起動のあとは 7 で続ける。
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
# 再起動で画面の表示が消えてもフェーズ1の失敗を見逃さないよう、フェーズ2の結果まとめに引き継ぐためのファイル。
$phase1FailuresPath = Join-Path $PSScriptRoot "AutoSetup-phase1-failures.log"
#=============================================================================
# ■ 関数定義
#=============================================================================
# recipe.yaml のコマンドを実行し、失敗した理由を返す（成功したときは $null）。
# 外部コマンドは終了コードで、cmdlet は終了コードを残さないため例外で判定する。
# どちらか一方だけで判定すると、cmdlet の成功を失敗と取り違えたり、例外でスクリプト全体が止まったりする。
function Invoke-RecipeCommand {
    param([string]$Command)
    # コマンドが見つからないときは終了コードが更新されず、前の処理の「0」が残って成功と誤判定するため、「未判定」に戻す。
    $global:LASTEXITCODE = $null
    # この関数の中だけで有効。エラーを例外に変えて、下の catch で受け取る。
    $ErrorActionPreference = 'Stop'
    try {
        # 今動いている PowerShell が 7 以上なら
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # エラー出力（stderr）は、そのままだとログに残らないため、普通の出力にまとめて記録する。
            # 5.1 でまとめると、stderr の1行目で失敗扱いになるため、7 だけで行う（5.1 は下の else）。
            # Invoke-Expression だと stderr が消えて cargo の進み具合などが出ないため、スクリプトブロックにして「.」で動かす。
            . ([scriptblock]::Create($Command)) 2>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.ToString() } else { $_ }
            } | Out-Host
        }
        else {
            Invoke-Expression -Command $Command | Out-Host
        }
    }
    catch {
        return "コマンドの実行に失敗しました: $($_.Exception.Message)"
    }
    if (($null -ne $LASTEXITCODE) -and ($LASTEXITCODE -ne 0)) {
        return "コマンドの実行に失敗しました。終了コード: $LASTEXITCODE"
    }
    return $null
}
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
# 実行される全コマンドとその出力を記録するログファイル。スクリプトと同じフォルダーに置く。
$logFilePath = Join-Path $PSScriptRoot "AutoSetup.log"
# PowerShell 7 は BOM なしの UTF-8 でログを作り、5.1 は BOM のないログに追記すると日本語を「?」に置き換えてしまう。
# 7 で書いたログに 5.1 で続きを書いても読めるよう、5.1 のときだけ、追記の前にログの先頭へ BOM を付ける。
# 7 は BOM のあるログに追記するたびに BOM を書き足すため、7 のときは付けない。
if (($PSVersionTable.PSVersion.Major -lt 6) -and (Test-Path -LiteralPath $logFilePath)) {
    $logBytes = [System.IO.File]::ReadAllBytes($logFilePath)
    $hasBom = ($logBytes.Length -ge 3) -and ($logBytes[0] -eq 0xEF) -and ($logBytes[1] -eq 0xBB) -and ($logBytes[2] -eq 0xBF)
    if (-not $hasBom) {
        [System.IO.File]::WriteAllBytes($logFilePath, [byte[]]([byte[]](0xEF, 0xBB, 0xBF) + $logBytes))
    }
}
# フェーズ1とフェーズ2の記録を1つのファイルにまとめるため、追記する。
Start-Transcript -LiteralPath $logFilePath -Append
#=============================================================================
# ■ 実行前準備 (環境チェックと設定ファイルの読み込み)
#=============================================================================
# --- 管理者権限の確認 ---
# 権限がないまま進むと、モジュールの導入まで済ませてから途中で失敗するため、最初に確かめる。
# フェーズ2もタスクから最高の権限で起動されるので、同じ確認で通る。手動で権限なしのまま実行したときに気づけるよう、両フェーズで確かめる。
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "エラー: 管理者権限が必要です。PowerShellを右クリックして「管理者として実行」してください。"
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit 1
}
# --- YAML解析モジュールの準備 ---
try {
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Host "YAMLモジュールが見つかりません。インストールを試みます..." -ForegroundColor Yellow
        # PC 全体（AllUsers）に入れる。今のユーザーに入れると 5.1 と 7 で置き場所が分かれ、フェーズ2の 7 から見えずに入れ直しになるため。
        Install-Module -Name powershell-yaml -Scope AllUsers -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Write-Host "YAMLモジュールのインストールが完了しました。" -ForegroundColor Green
    }
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    # 原因が分かるよう、元のエラーの内容も表示する。導入先は上と同じ「PC 全体」にそろえて案内する。
    Write-Error "YAMLモジュールの準備に失敗しました: $($_.Exception.Message)"
    Write-Error "インターネット接続を確認し、管理者のPowerShellで「Install-Module -Name powershell-yaml -Scope AllUsers」を手動で実行してください。"
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit 1
}
# --- 設定ファイルの読み込み ---
try {
    $configFilePath = Join-Path $PSScriptRoot "recipe.yaml"
    if (-not (Test-Path -LiteralPath $configFilePath)) {
        throw "設定ファイル 'recipe.yaml' が見つかりません。"
    }
    Write-Host "設定ファイル 'recipe.yaml' を読み込んでいます..."
    $config = Get-Content -LiteralPath $configFilePath -Encoding UTF8 -Raw | ConvertFrom-Yaml
}
catch {
    Write-Error "設定ファイルの読み込みでエラーが発生しました: $($_.Exception.Message)"
    if ($_.Exception.InnerException -is [YamlDotNet.Core.YamlException]) {
        Write-Error "YAMLの書式が正しくない可能性があります。インデント等を確認してください。"
    }
    Read-Host "Enterキーを押して終了します。"
    Stop-Transcript
    exit 1
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
    # 前回の実行で残った失敗一覧を、今回の結果と混ぜないよう削除する。
    if (Test-Path -LiteralPath $phase1FailuresPath) {
        Remove-Item -LiteralPath $phase1FailuresPath
    }
    # --- Windowsのシステム設定変更 ---
    if ($config.phase1.windowsSettings) {
        Write-Host "--- 1. Windowsの各種設定を変更します ---`n" -ForegroundColor Green
        foreach ($setting in $config.phase1.windowsSettings) {
            Write-Host "-> $($setting.description)..."
            if (-not ([string]::IsNullOrEmpty($setting.command))) {
                $failureReason = Invoke-RecipeCommand -Command $setting.command
                if ($failureReason) {
                    Write-Warning "-> $failureReason"
                    $script:failedItems.Add("設定変更失敗: $($setting.description)")
                }
            }
            else {
                $errorMessage = "設定変更失敗: $($setting.description) - commandプロパティが定義されていません。"
                Write-Warning "-> commandプロパティが定義されていません。"
                $script:failedItems.Add($errorMessage)
            }
        }
        Write-Host "`n--- Windowsの各種設定変更が完了しました ---`n" -ForegroundColor Green
    }
    # winget が「インストールは成功、完了には再起動が必要」のときに返す終了コード（0x8A150109）。
    # Visual Studio Build Tools のように、インストーラーが 3010 を返すとこのコードになる。
    $wingetRebootRequiredToFinish = -1978334967
    # --- アプリケーションのインストール (winget) ---
    if ($config.phase1.wingetInstall) {
        Write-Host "--- 2. アプリケーションのインストールを開始します ---`n" -ForegroundColor Green
        # wingetのソースリポジトリをリセットし、潜在的な問題を解消する。
        # winget 自体が見つからない場合に前の終了コードを成功と取り違えないよう、「未判定」に戻す。
        $global:LASTEXITCODE = $null
        winget source reset --force
        if ($LASTEXITCODE -ne 0) {
            # ソースが壊れたままだと後のインストールがまとめて失敗するため、その原因として分かるように残す。
            Write-Warning "-> wingetのソースのリセットに失敗しました。終了コード: $LASTEXITCODE"
            $script:failedItems.Add("Winget Source Reset")
        }
        foreach ($wingetApp in $config.phase1.wingetInstall) {
            Write-Host "アプリ [$($wingetApp.id)] の状態を確認しています..."
            # 前のアプリの結果「0」が残っていると、未インストールでも導入済みと誤判定するため、「未判定」に戻す。
            $global:LASTEXITCODE = $null
            # ソースを winget に固定する。msstore が証明書エラー(0x8a15005e)などで使えないと、
            # ソース未指定の winget はインストール先を決められず、全アプリの導入が失敗するため。
            winget list --id $wingetApp.id -e --source winget --accept-source-agreements --disable-interactivity
            if ($LASTEXITCODE -ne 0) {
                Write-Host "-> [$($wingetApp.id)] をインストールします..."
                $wingetArgs = @(
                    'install', '--id', $wingetApp.id, '-e', '--source', 'winget',
                    '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
                )
                if (-not ([string]::IsNullOrEmpty($wingetApp.options))) {
                    # 空白で単純に区切ると --override "..." の中身までばらばらになるため、
                    # 二重引用符で囲まれた部分は1つの引数として扱う（引用符は外して渡す）。
                    $wingetArgs += @([regex]::Matches($wingetApp.options, '"[^"]*"|\S+') | ForEach-Object { $_.Value.Trim('"') })
                    Write-Host "-> 個別オプション ($($wingetApp.options)) を適用します。" -ForegroundColor Yellow
                }
                winget @wingetArgs
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "-> [$($wingetApp.id)] のインストールに成功しました。`n" -ForegroundColor Green
                }
                elseif ($LASTEXITCODE -eq $wingetRebootRequiredToFinish) {
                    # フェーズ1の最後に必ず再起動するため、再起動で仕上がるインストールは成功として扱う。
                    Write-Host "-> [$($wingetApp.id)] のインストールに成功しました（再起動で完了します）。`n" -ForegroundColor Green
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
    if ($config.phase1.appxRemove) {
        Write-Host "--- 3. プリインストールアプリの削除を開始します ---`n" -ForegroundColor Green
        foreach ($appxPackage in $config.phase1.appxRemove) {
            Write-Host "-> [$($appxPackage.name)] を削除します..."
            $foundPackages = @(Get-AppxPackage -AllUsers -Name $appxPackage.name)
            if ($foundPackages.Count -eq 0) {
                # Windowsのバージョンによっては最初から入っていないアプリもあるため、失敗ではなくスキップとして扱う。
                Write-Host "-> [$($appxPackage.name)] は見つかりませんでした。スキップします。`n" -ForegroundColor Cyan
                continue
            }
            # 1つの失敗で残りのパッケージの削除が止まらないよう、パッケージごとに処理する。
            foreach ($foundPackage in $foundPackages) {
                try {
                    Remove-AppxPackage -Package $foundPackage.PackageFullName -AllUsers -ErrorAction Stop
                    Write-Host "-> [$($foundPackage.Name)] を削除しました。" -ForegroundColor Green
                }
                catch {
                    Write-Warning "-> [$($foundPackage.Name)] の削除に失敗しました: $($_.Exception.Message)"
                    $script:failedItems.Add("Appx Remove: $($foundPackage.Name)")
                }
            }
            Write-Host ""
        }
        Write-Host "`n--- プリインストールアプリの削除が完了しました ---`n" -ForegroundColor Green
    }
    # --- インストール済みアプリ全体を更新 ---
    Write-Host "--- 4. インストール済みアプリ全体を更新します ---`n" -ForegroundColor Green
    # winget 自体が見つからない場合に前の終了コードを成功と取り違えないよう、「未判定」に戻す。
    $global:LASTEXITCODE = $null
    # msstore ソースは証明書エラーや利用規約の表示で止まることがあるため、install・list と同じく winget ソースに限る。
    winget upgrade --all --source winget --silent --accept-package-agreements --accept-source-agreements
    # 再起動で仕上がる更新は、このあとの再起動で完了するため失敗にしない。
    if (($LASTEXITCODE -ne 0) -and ($LASTEXITCODE -ne $wingetRebootRequiredToFinish)) {
        Write-Warning "-> アプリ全体の更新プロセス中にエラーが報告されました。終了コード: $LASTEXITCODE"
        $script:failedItems.Add("Winget Upgrade: 全体更新")
    }
    Write-Host "--- インストール済みアプリ全体の更新が完了しました ---`n" -ForegroundColor Green
    # --- フェーズ2の自動実行設定と再起動 ---
    Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---`n" -ForegroundColor Green
    $taskRegistered = $false
    try {
        # 5.1 は非推奨のため、フェーズ1で PowerShell 7 が入っていれば、フェーズ2は 7 で動かす。
        # 7 を入れた直後は、今動いている PowerShell の PATH に反映されていないため、標準のインストール先も調べる。
        $powerShellExe = Join-Path $PSHOME 'powershell.exe'
        if ($PSVersionTable.PSEdition -eq 'Core') {
            $powerShellExe = Join-Path $PSHOME 'pwsh.exe'
        } else {
            $pwshCandidates = @(Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe') + @(Get-Command pwsh.exe -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
            $pwshPath = $pwshCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
            if ($pwshPath) { $powerShellExe = $pwshPath }
        }
        Write-Host "-> フェーズ2は次の PowerShell で動かします: $powerShellExe" -ForegroundColor DarkGray
        $taskAction = New-ScheduledTaskAction -Execute $powerShellExe -Argument "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -setupPhase 2"
        $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
        $currentUserId = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId $currentUserId -LogonType Interactive -RunLevel Highest
        Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Force -ErrorAction Stop
        Write-Host "-> タスクスケジューラに '$TaskName' を登録しました。" -ForegroundColor Green
        $taskRegistered = $true
    }
    catch {
        Write-Error "致命的エラー: 再起動後の自動実行設定に失敗しました。フェーズ2は開始されません。"
        Write-Error $_.Exception.Message
        $script:failedItems.Add("致命的エラー: タスクスケジューラ登録失敗")
    }
    # --- フェーズ1の完了報告と自動再起動 ---
    Write-Host "==============================================="
    if ($script:failedItems.Count -gt 0) {
        Write-Warning "フェーズ1の一部の処理でエラーが発生しました。詳細は以下の通りです："
        foreach ($failedItem in $script:failedItems) {
            Write-Warning "- $failedItem"
        }
        Write-Host "==============================================="
        try {
            Set-Content -LiteralPath $phase1FailuresPath -Value $script:failedItems -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Warning "フェーズ1の失敗一覧を保存できませんでした。フェーズ2の結果まとめには表示されません: $($_.Exception.Message)"
        }
        # 失敗があるのに「すべて完了」と緑で出すと、上の一覧を見落とすため、言い方と色を変える。
        Write-Host "  フェーズ1の処理が終わりました（失敗した項目は上の一覧を確認してください）" -ForegroundColor Yellow
    }
    else {
        Write-Host "  フェーズ1のすべての処理が完了しました！" -ForegroundColor Green
    }
    Write-Host "===============================================`n"
    if (-not $taskRegistered) {
        # 自動実行がないまま再起動すると、フェーズ2が始まらないことに利用者が気づけないため、ここで止めて手順を示す。
        Write-Warning "フェーズ2の自動実行を設定できなかったため、自動再起動は行いません。"
        Write-Warning "手動でPCを再起動したあと、管理者のPowerShellで次のコマンドを実行してフェーズ2を開始してください:"
        Write-Warning "  & `"$PSCommandPath`" -setupPhase 2"
        Read-Host "Enterキーを押して終了します。"
        Stop-Transcript
        exit 1
    }
    Write-Host "設定を完全に適用するため、システムを再起動します。" -ForegroundColor Yellow
    # ユーザーがメッセージを読むための待機時間を設ける。
    Write-Host "10秒後に自動で再起動が開始されます。中断したい場合はこのウィンドウを閉じてください。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Stop-Transcript
    Restart-Computer -Force
}
#----------------------------------------------------------------------
# ● フェーズ2 (再起動後): 開発者向けパッケージのインストール
#----------------------------------------------------------------------
# パラメータ$setupPhaseが'2'に等しい、つまり再起動後に実行された場合にこのブロックを実行する。
else {
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ2 を開始します" -ForegroundColor Cyan
    Write-Host "===============================================`n" -ForegroundColor Cyan
    # --- 自動実行タスクのクリーンアップ ---
    # フェーズ2が開始されたため、このタスクは不要。次の実行に備えて削除する。
    Write-Host "-> 自動実行タスクをクリーンアップします..." -ForegroundColor DarkGray
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    # フェーズ1の失敗を、最後の結果まとめに一緒に表示する。
    if (Test-Path -LiteralPath $phase1FailuresPath) {
        foreach ($phase1Failure in (Get-Content -LiteralPath $phase1FailuresPath -Encoding UTF8)) {
            $script:failedItems.Add("フェーズ1 - $phase1Failure")
        }
    }
    # ネットワーク接続の確立などを待つため、少し待機する。
    Write-Host "10秒後に自動でパッケージのインストールが開始されます。" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    # --- パッケージインストールの実行ループ ---
    if ($config.phase2.packageManagers) {
        foreach ($manager in $config.phase2.packageManagers) {
            Write-Host "`n--- $($manager.managerName) パッケージのインストールを開始します ---`n" -ForegroundColor Green
            if (-not $manager.packages) {
                Write-Host "-> $($manager.managerName) でインストールするパッケージが定義されていないため、スキップします。`n" -ForegroundColor Yellow
                continue
            }
            foreach ($package in $manager.packages) {
                $packageName = $package.name
                Write-Host "パッケージ [$($packageName)] の状態を確認しています..."
                $checkCommand = $manager.checkCommand -replace '\{package\}', $packageName
                # 確認コマンドの失敗は「未インストール」という意味なので、警告にはせずインストールへ進む。
                if (Invoke-RecipeCommand -Command $checkCommand) {
                    Write-Host "-> [$($packageName)] をインストールします..."
                    $installCommand = $manager.installCommand -replace '\{package\}', $packageName
                    $failureReason = Invoke-RecipeCommand -Command $installCommand
                    if (-not $failureReason) {
                        Write-Host "-> [$($packageName)] のインストールに成功しました。`n" -ForegroundColor Green
                    }
                    else {
                        Write-Warning "-> $failureReason"
                        $script:failedItems.Add("パッケージ処理失敗: $($manager.managerName) - $packageName")
                    }
                }
                else {
                    Write-Host "-> [$($packageName)] はインストール済みです。スキップします。`n" -ForegroundColor Cyan
                }
            }
            Write-Host "--- $($manager.managerName) パッケージのインストールが完了しました ---" -ForegroundColor Green
        }
    }
    # --- フェーズ2の完了報告 ---
    Write-Host "`n==============================================="
    if ($script:failedItems.Count -gt 0) {
        Write-Warning "一部の処理でエラーが発生しました。詳細は以下の通りです："
        foreach ($failedItem in $script:failedItems) {
            Write-Warning "- $failedItem"
        }
        Write-Host "==============================================="
        # 失敗があるのに「すべて完了」と緑で出すと、上の一覧を見落とすため、言い方と色を変える。
        Write-Host "  すべてのセットアップ処理が終わりました（失敗した項目は上の一覧を確認してください）" -ForegroundColor Yellow
    }
    else {
        Write-Host "  すべてのセットアップ処理が完了しました！" -ForegroundColor Green
    }
    Write-Host "==============================================="
    # 結果まとめに表示し終えたので削除する。途中で止まった場合は、次にフェーズ2を手動実行したときに再表示される。
    if (Test-Path -LiteralPath $phase1FailuresPath) {
        Remove-Item -LiteralPath $phase1FailuresPath
    }
    # 実行結果をユーザーが確認できるよう、キー入力があるまでウィンドウを閉じずに待機する。
    Read-Host "Enterキーを押して、このウィンドウを閉じてください。"
    Stop-Transcript
    # 呼び出し元（タスクスケジューラの実行結果など）からも失敗が分かるよう、失敗があれば 1 を返す。
    if ($script:failedItems.Count -gt 0) {
        exit 1
    }
    exit 0
}