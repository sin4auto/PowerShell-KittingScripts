<#
.SYNOPSIS
    Windows Updateの完全自動化スクリプト。

.DESCRIPTION
    更新プログラムの確認、ダウンロード、インストール、自動再起動までを、更新がなくなるまで繰り返します。
    PSWindowsUpdateモジュールの自動セットアップ、再起動後の処理継続のためのタスク登録、ログ記録機能を含みます。

.EXAMPLE
    .\AutoWindowsUpdate_v3.ps1
    管理者権限のPowerShellでスクリプトを実行します。

.NOTES
    - 要管理者権限。
    - 初回実行にはインターネット接続が必須。
    - PowerShell 5.1での動作を想定。
    - 完了後、手動での最終確認を推奨します: [設定] > [Windows Update] > [更新プログラムのチェック]
    Copyright (c) 2025 sin4auto
#>

# =================================================================
# 定数定義
# =================================================================
# 再起動後の自動実行で利用するタスクスケジューラのタスク名を定義する。
$TaskName = "AutoWindowsUpdateTask"

# =================================================================
# メイン処理ブロック
# =================================================================
# スクリプト全体をtryブロックで囲み、予期せぬエラーを包括的に捕捉する。
try {
    # --- フェーズ0: 初期化処理 ---
    # スクリプトの実行基盤を準備する。
    try {
        # スクリプトが.ps1ファイルとして保存・実行されているかを確認する。
        if ($null -eq $PSScriptRoot) {
            # ファイルではない場合、パスが取得できず後続処理が失敗するため、エラーを発生させる。
            throw "スクリプトを.ps1ファイルとして保存して実行してください。"
        }
        # スクリプトの安定した動作のため、カレントディレクトリをスクリプト自身の場所に設定する。
        Set-Location -Path $PSScriptRoot
    } catch {
        # 上記の初期化処理に失敗した場合、エラーを表示してスクリプトを終了する。
        Write-Error $_.Exception.Message
        Start-Sleep -Seconds 10
        exit
    }
    # 実行ログを記録するファイルパスを定義する。
    $LogFile = Join-Path $PSScriptRoot "AutoWindowsUpdate.log"
    # ログ記録（トランスクリプト）を開始する。-Appendで既存ファイルに追記する。
    try {
        Start-Transcript -Path $LogFile -Append
    } catch {
        # ログ記録が開始できない場合でも、処理は続行する。
        Write-Warning "トランスクリプトの開始に失敗。ログは記録されません。Error: $($_.Exception.Message)"
    }
    # 過去の実行で残存している可能性のある自動実行タスクを、安全のために削除する。
    Write-Host "-> 既存の自動実行タスクをクリーンアップします..." -ForegroundColor DarkGray
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    # --- フェーズ1: 実行前チェック ---
    # スクリプトの実行に必要な管理者権限があるかを確認する。
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # 管理者権限がない場合は、警告を表示して処理を中断する。
        Write-Warning "管理者権限がありません。管理者としてPowerShellを再実行してください。"
        Start-Sleep -Seconds 10
        exit
    }

    # --- フェーズ2: Windows Update メインループ ---
    # 更新がなくなるまで一連の処理を繰り返すための無限ループ。
    while ($true) {
        # --- [0/5] 依存モジュールのセットアップ ---
        Write-Host "----------------------------------------------------"
        Write-Host "[0/5] 依存モジュール(PSWindowsUpdate)のセットアップ" -ForegroundColor Cyan
        # 'PSWindowsUpdate'モジュールがインストール済みかを確認する。
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Write-Host "-> 依存モジュールはインストール済み。" -ForegroundColor Green
        } else {
            # 未インストールの場合、依存関係にあるNuGetプロバイダーを準備する。
            Write-Host "-> 依存モジュールをインストールします..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
            # 'PSWindowsUpdate'モジュールを全ユーザー向けにインストールする。
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -Scope AllUsers
            Write-Host "-> インストール完了。" -ForegroundColor Green
        }
        # モジュールを現在のセッションにインポートして利用可能な状態にする。
        Import-Module PSWindowsUpdate -Force

        # --- [1/5] 更新プログラムのスキャン ---
        Write-Host "----------------------------------------------------"
        Write-Host "`n[1/5] 更新プログラムをスキャン中..." -ForegroundColor Cyan
        # Microsoft Updateサーバーに接続し、利用可能な更新プログラムを取得する。
        $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

        # --- 更新が存在しない場合の処理 ---
        # 利用可能な更新プログラムが一つもなかった場合の処理。
        if (-not $updates) {
            Write-Host "`n>> 更新プログラムは検出されませんでした。システムは最新です。" -ForegroundColor Green
            Write-Host ">> 全プロセス正常完了。処理を終了します..."
            # ループを脱出し、スクリプトを正常終了させる。
            break
        }

        # --- [2/5] 検出された更新プログラムのリスト表示 ---
        # 見つかった更新の数を表示し、その一覧を表形式で出力する。
        Write-Host ("`n[2/5] {0}個の更新を検出。" -f $updates.Count) -ForegroundColor Yellow
        $updates | Select-Object Title, KB, Size | Format-Table

        # --- [3/5] 再起動後の自動実行設定 ---
        Write-Host "`n[3/5] 再起動後にスクリプトを管理者権限で自動実行するよう設定..." -ForegroundColor Cyan
        # タスクスケジューラの登録処理でエラーが発生した場合に備える。
        try {
            # タスクとして実行するアクション（このスクリプト自身）を定義する。
            $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
            # タスクを実行するトリガー（ユーザーのログオン時）を定義する。
            $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
            # スクリプトを実行している現在のユーザーのIDを確実に取得する。
            $currentUserId = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name
            # タスクの実行者情報と権限レベル（最高の権限）を定義する。
            $taskPrincipal = New-ScheduledTaskPrincipal -UserId $currentUserId -LogonType Interactive -RunLevel Highest
            # 上記で定義したアクション、トリガー、プリンシパルを組み合わせてタスクをOSに登録する。
            Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Force -ErrorAction Stop
            Write-Host "-> タスクスケジューラに '$TaskName' を登録しました。" -ForegroundColor Green
        } catch {
            # タスクの登録に失敗した場合、自動継続は不可能なため、致命的エラーとして処理を中断する。
            throw "タスクスケジューラの登録に失敗しました: $($_.Exception.Message)"
        }

        # --- [4/5] 更新のインストールと条件付き再起動 ---
        Write-Host "`n[4/5] 更新のダウンロードとインストールを開始..." -ForegroundColor Cyan
        Write-Host "-> この処理は長時間かかる場合があります。必要に応じて自動的に再起動します。" -ForegroundColor Yellow
        # OSが再起動する直前のログが失われるのを防ぐため、一度ログを停止し、即座に追記モードで再開する。
        if ($global:Transcript) { Stop-Transcript; Start-Transcript -Path $LogFile -Append }
        # 見つかった全ての更新プログラムを承諾し、インストールを実行する。-AutoRebootにより、必要に応じて自動で再起動される。
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose
        # 再起動コマンドが実行された後のための短い待機時間。
        Write-Host "-> 10秒間待機します..."
        Start-Sleep -Seconds 10

        # --- [5/5] 再起動が不要だった場合の処理 ---
        # このステップに到達した場合、-AutoRebootが再起動をトリガーしなかったことを意味する。
        Write-Host "`n[5/5] 再起動は要求されませんでした。連続して更新チェックを続行します。" -ForegroundColor Yellow
        # 再起動しなかったので、次のループのために登録した自動実行タスクは不要なため削除する。
        Write-Host "-> 自動実行タスクをクリーンアップします..." -ForegroundColor DarkGray
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        # 次のスキャンに移る前に短い待機時間を設ける。
        Write-Host "-> 5秒後に次のスキャンを開始します..."
        Start-Sleep -Seconds 5
        # continueキーワードでwhileループの先頭に戻り、再度更新スキャンから処理を始める。
        continue
    }

    # --- フェーズ3: 正常終了時のクリーンアップ ---
    # whileループが正常にbreakされた（更新がなくなった）場合に実行される。
    Write-Host "`n全ての処理が完了しました。"
    # 念のため、残存している可能性のある自動実行タスクを削除する。
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

} catch {
    # --- フェーズ4: 例外処理 ---
    # スクリプト全体のtryブロック内で発生した、捕捉可能な全てのエラーをここで処理する。
    Write-Host "`nFATAL: エラーが発生しました。 $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "処理を中断します。詳細はログファイルを参照してください: $LogFile" -ForegroundColor Red
    # 処理が異常終了したため、意図しない再実行を防ぐために自動実行タスクをクリーンアップする。
    Write-Host "-> 自動実行タスクをクリーンアップします..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    # ユーザーがエラーメッセージを確認するための待機時間を設ける。
    Start-Sleep -Seconds 20

} finally {
    # --- フェーズ5: 最終処理 ---
    # 処理が正常に終了しても、エラーで中断しても、必ずこのブロックが最後に実行される。
    # ログ記録（トランスクリプト）が実行中の場合、確実に停止させてファイルを閉じる。
    if ($global:Transcript) {
        Stop-Transcript
    }
}