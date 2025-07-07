<#
.SYNOPSIS
    Windows Updateを全自動で実行し、システムを最新の状態にします。

.DESCRIPTION
    このスクリプトは、更新プログラムの確認、ダウンロード、インストール、そして必要に応じた再起動までの一連のプロセスを、「更新プログラムはありません」と表示されるまで自動で繰り返します。
    一度実行すれば、すべての更新が適用されるまで完全に無人で処理が継続されます。

    主な動作:
    - 必須モジュール「PSWindowsUpdate」を自動でインストール・セットアップします。
    - 再起動後も処理が自動で継続されるように、タスクスケジューラに一時的なタスクを登録します。
    - 実行されたすべての操作は、スクリプトと同じフォルダ内の「AutoUpdateLog.txt」に記録されます。

.EXAMPLE
    .\Update-Windows.ps1
    PowerShellを「管理者として実行」で開き、上記コマンドでスクリプトを実行します。
    以後の処理はすべて自動で行われます。

.NOTES
    - 実行には管理者権限が必須です。
    - 初回実行時やモジュールのインストール時にはインターネット接続が必要です。
#>

# =================================================================
# 設定項目
# =================================================================
# 再起動後にこのスクリプトを自動実行させるためにタスクスケジューラに登録するタスクの名前です。
# 通常は変更する必要はありません。
$TaskName = "Ultimate-AutoUpdateAfterReboot"

# =================================================================
# スクリプト全体のエラーハンドリングと最終処理
# =================================================================
try {
    # --- 1. 初期化処理 ---
    # スクリプトの実行に必要なパスの特定と、操作ログの記録を開始します。
    try {
        # スクリプト自身のフルパスと、それが置かれているディレクトリのパスを取得します。
        $ScriptPath = $MyInvocation.MyCommand.Path
        $ScriptDir  = Split-Path $ScriptPath -Parent
        # ログファイルなどを正しく配置するため、カレントディレクトリをスクリプトのある場所に変更します。
        Set-Location -Path $ScriptDir
    } catch {
        # .ps1ファイルとして保存せずに実行した場合など、パス取得に失敗した際のエラー処理です。
        Write-Error "スクリプトを.ps1ファイルとして保存してから実行してください。"
        Start-Sleep -Seconds 10
        exit
    }

    # スクリプトの全出力をログファイルに記録する設定です。
    $LogFile = Join-Path $ScriptDir "AutoUpdateLog.txt"
    try {
        # 既存のログファイルに追記する形で記録を開始します。
        Start-Transcript -Path $LogFile -Append
    } catch {
        Write-Warning "ログ記録の開始に失敗しました。処理は続行しますが、ログは残りません。エラー: $($_.Exception.Message)"
    }

    # --- 2. 事前チェック ---
    # 管理者権限の有無を確認します。
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "管理者権限がありません。PowerShellを「管理者として実行」で開き直してください。"
        Start-Sleep -Seconds 10
        exit
    }

    # スクリプト実行がセキュリティポリシーで禁止されている場合、一時的に許可するか確認します。
    $currentExecutionPolicy = Get-ExecutionPolicy
    if ($currentExecutionPolicy -notin @('Unrestricted', 'RemoteSigned', 'Bypass')) {
        Write-Warning "現在のPowerShell実行ポリシー($currentExecutionPolicy)では、スクリプトを実行できません。"
        $choice = Read-Host "このセッションに限り、一時的に実行を許可しますか？ (Y/N)"
        if ($choice -eq 'y') {
            # `-Scope Process` を指定することで、このPowerShellウィンドウ内でのみポリシーが変更されます。
            Set-ExecutionPolicy RemoteSigned -Scope Process -Force
        } else {
            Write-Error "実行が許可されなかったため、スクリプトを終了します。"
            Start-Sleep -Seconds 10
            exit
        }
    }

    # --- 3. Windows Update メインループ ---
    # 「更新がなくなるまで繰り返す」という処理を、再帰呼び出しではなく while ループで実現します。
    # これにより、コードの可読性が向上し、意図しないスタックオーバーフローのリスクを回避できます。
    while ($true) {
        # --- [1/6] 必須モジュールの準備 ---
        Write-Host "----------------------------------------------------"
        Write-Host "[1/6] 必須モジュール(PSWindowsUpdate)の準備" -ForegroundColor Cyan
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "-> モジュールが未導入のため、インストールを開始します..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -Scope AllUsers
            Write-Host "-> モジュールのインストールが完了しました。" -ForegroundColor Green
        } else {
            Write-Host "-> モジュールはインストール済みです。" -ForegroundColor Green
        }
        Import-Module PSWindowsUpdate -Force

        # --- [2/6] 更新プログラムの確認 ---
        Write-Host "----------------------------------------------------"
        Write-Host "`n[2/6] 更新プログラムを確認中..." -ForegroundColor Cyan
        $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

        # --- 更新がない場合の処理 ---
        if (-not $updates) {
            Write-Host "`n>> システムは最新の状態です。更新プログラムはありません。" -ForegroundColor Green
            Write-Host ">> 全ての処理が完了しました。後片付けを行います..."
            break # 更新がなければループを抜ける
        }

        # --- [3/6] 更新プログラムの一覧表示 ---
        Write-Host ("`n[3/6] {0}個の更新プログラムが見つかりました。" -f $updates.Count) -ForegroundColor Yellow
        $updates | Select-Object Title, KB, Size | Format-Table

        # --- [4/6] 再起動後の自動実行タスク登録 ---
        Write-Host "`n[4/6] 再起動後に処理を継続するためのタスクを登録します..." -ForegroundColor Cyan
        
        # タスクスケジューラの各設定を定義します。
        $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
        $taskTrigger = New-ScheduledTaskTrigger -AtStartup
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        
        # パラメータをSplattingでまとめて渡し、コマンドの可読性を高めます。
        $registerTaskParams = @{
            TaskName  = $TaskName
            Action    = $taskAction
            Trigger   = $taskTrigger
            Principal = $taskPrincipal
            Settings  = $taskSettings
            Force     = $true
            ErrorAction = 'Stop'
        }
        Register-ScheduledTask @registerTaskParams
        Write-Host "-> タスク '$TaskName' を登録しました。" -ForegroundColor Green

        # --- [5/6] 更新のインストールと再起動 ---
        Write-Host "`n[5/6] 更新のダウンロードとインストールを開始します..." -ForegroundColor Cyan
        Write-Host "-> この処理は時間がかかります。完了すると自動で再起動される場合があります。" -ForegroundColor Yellow
        
        # 再起動の瞬間にログが途切れないよう、ここで一度ログを停止・再開します。
        if (Get-Transcript) { Stop-Transcript; Start-Transcript -Path $LogFile -Append }
        
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose

        # --- [6/6] 再起動が不要だった場合の処理 ---
        # Install-WindowsUpdate が完了してもスクリプトが続行した場合、再起動は発生していません。
        Write-Host "`n[6/6] 再起動は不要でした。続けて残りの更新をチェックします。" -ForegroundColor Yellow
        
        # このサイクルでは再起動しなかったため、次回の起動に備えたタスクは不要です。削除します。
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        
        Write-Host "-> 5秒後に更新チェックを再開します..."
        Start-Sleep -Seconds 5
        # continue でループの先頭に戻ります。
        continue
    }

    # --- 4. 正常終了処理 ---
    # ループを抜けた後（すべての更新が完了した後）の最終クリーンアップです。
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "-> 自動実行タスクをクリーンアップしました。"
            
    Write-Host "`n全ての処理が完了しました。10秒後にウィンドウを閉じます。"
    Start-Sleep -Seconds 10

} catch {
    # --- 5. エラー処理 ---
    # tryブロック内で発生したすべての$ErrorActionPreference='Stop'エラーをここで捕捉します。
    Write-Host "`nエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "処理を中断します。詳細はログファイルを確認してください: $LogFile" -ForegroundColor Red
    
    # 意図しない自動実行を防ぐため、登録済みのタスクを削除します。
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "-> 念のため、自動実行タスクをクリーンアップしました。"
    
    Start-Sleep -Seconds 20
    # スクリプトが異常終了したことを示すために、0以外の終了コードで終了します。
    exit 1
} finally {
    # --- 6. 最終処理 ---
    # スクリプトが正常終了しても、エラーで中断しても、必ず最後に実行されます。
    # ログ記録がアクティブな場合は、確実に停止してファイルに書き込みます。
    if (Get-Transcript) {
        Stop-Transcript
    }
}
