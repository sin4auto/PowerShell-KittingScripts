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
    - 作成者: (もしあれば記入)
    - バージョン: 1.0
#>

# =================================================================
# 設定項目
# =================================================================
# 再起動後にこのスクリプトを自動実行させるためにタスクスケジューラに登録するタスクの名前です。
# 通常は変更する必要はありません。
$TaskName = "Ultimate-AutoUpdateAfterReboot"

# =================================================================
# 初期化処理
# =================================================================
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

# =================================================================
# メイン処理関数
# Windows Update の確認から再起動までの一連のサイクルを実行します。
# =================================================================
Function Start-WindowsUpdateProcess {
    try {
        # --- 1. 必須モジュールの準備 ---
        Write-Host "----------------------------------------------------"
        Write-Host "[1/6] 必須モジュール(PSWindowsUpdate)の準備" -ForegroundColor Cyan
        # Windows UpdateをPowerShellで操作するための「PSWindowsUpdate」モジュールがインストール済みか確認します。
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "-> モジュールが未導入のため、インストールを開始します..." -ForegroundColor Yellow
            # 信頼されたリポジトリからモジュールをインストールできるよう、関連コンポーネントを準備します。
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
            # PSWindowsUpdateモジュールをインストールします。-Forceで確認プロンプトをスキップします。
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -Scope AllUsers
            Write-Host "-> モジュールのインストールが完了しました。" -ForegroundColor Green
        } else {
            Write-Host "-> モジュールはインストール済みです。" -ForegroundColor Green
        }
        # モジュールを現在のセッションに読み込み、コマンドレットを使えるようにします。
        Import-Module PSWindowsUpdate -Force

        # --- 2. 更新プログラムの確認 ---
        Write-Host "----------------------------------------------------"
        Write-Host "`n[2/6] 更新プログラムを確認中..." -ForegroundColor Cyan
        # `-MicrosoftUpdate` を付けることで、WindowsだけでなくOffice等の他のMicrosoft製品の更新も対象にします。
        $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

        # --- 3. 更新がない場合の処理 ---
        # 利用可能な更新がなければ、$updatesは空($null)になります。
        if ($null -eq $updates) {
            Write-Host "`n>> システムは最新の状態です。更新プログラムはありません。" -ForegroundColor Green
            Write-Host ">> 後片付けを行い、処理を終了します..."
            # 再起動に備えて登録した自動実行タスクが残っている可能性があるので、念のため削除します。
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "-> 自動実行タスクをクリーンアップしました。"
            
            Write-Host "`n全ての処理が完了しました。10秒後にウィンドウを閉じます。"
            if ($global:Transcript) { Stop-Transcript }
            Start-Sleep -Seconds 10
            exit
        }

        # --- 4. 更新プログラムの一覧表示 ---
        Write-Host ("`n[3/6] {0}個の更新プログラムが見つかりました。" -f $updates.Count) -ForegroundColor Yellow
        $updates | Select-Object Title, KB, Size | Format-Table

        # --- 5. 再起動後の自動実行タスク登録 ---
        Write-Host "`n[4/6] 再起動後に処理を継続するためのタスクを登録します..." -ForegroundColor Cyan
        # タスクスケジューラに、PC起動時にこのスクリプトを再度実行するよう設定します。
        $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
        $trigger   = New-ScheduledTaskTrigger -AtStartup
        # SYSTEM権限で実行することで、ログオン不要かつ最高権限でタスクを実行できます。
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        
        # 既存のタスクがあれば上書き(-Force)して登録します。
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop
        Write-Host "-> タスク '$TaskName' を登録しました。" -ForegroundColor Green

        # --- 6. 更新のインストールと再起動 ---
        Write-Host "`n[5/6] 更新のダウンロードとインストールを開始します..." -ForegroundColor Cyan
        Write-Host "-> この処理は時間がかかります。完了すると自動で再起動されます。" -ForegroundColor Yellow
        # 再起動の瞬間にログが途切れないよう、ここで一度ログを停止・再開します。
        if ($global:Transcript) { Stop-Transcript; Start-Transcript -Path $LogFile -Append }
        
        # 見つかった更新をすべて承認(-AcceptAll)し、インストール後に再起動が必要な場合は自動で再起動(-AutoReboot)します。
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose

        # --- 7. 再起動が不要だった場合の処理 ---
        # -AutoRebootしても再起動が実行されなかった場合、まだ適用すべき更新が残っている可能性があります。
        Write-Host "`n[6/6] 再起動は不要でした。続けて残りの更新をチェックします。" -ForegroundColor Yellow
        # このサイクルでは再起動しなかったため、次回の起動に備えたタスクは不要です。削除します。
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        
        # 連続実行による負荷を避けるため5秒待機し、再度この関数の先頭から処理を繰り返します。
        Write-Host "-> 5秒後に更新チェックを再開します..."
        Start-Sleep -Seconds 5
        Start-WindowsUpdateProcess

    } catch {
        # --- エラーハンドリング ---
        # tryブロック内で発生したすべてのエラーをここで捕捉します。
        Write-Host "`nエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "処理を中断します。詳細はログファイルを確認してください: $LogFile" -ForegroundColor Red
        # 意図しない自動実行を防ぐため、登録済みのタスクを削除します。
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 20
        if ($global:Transcript) { Stop-Transcript }
    }
}

# =================================================================
# スクリプト実行開始点
# =================================================================
# --- 事前チェック1: 管理者権限 ---
# システム設定やモジュールインストールには管理者権限が必須です。
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "管理者権限がありません。PowerShellを「管理者として実行」で開き直してください。"
    if ($global:Transcript) { Stop-Transcript }
    Start-Sleep -Seconds 10
    exit
}

# --- 事前チェック2: 実行ポリシー ---
# スクリプト実行がセキュリティポリシーで禁止されている場合、一時的に許可するか確認します。
if ((Get-ExecutionPolicy) -ne "Unrestricted" -and (Get-ExecutionPolicy) -ne "RemoteSigned" -and (Get-ExecutionPolicy) -ne "Bypass") {
    Write-Warning "現在のPowerShell実行ポリシーでは、スクリプトを実行できません。"
    $choice = Read-Host "このセッションに限り、一時的に実行を許可しますか？ (Y/N)"
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        # `-Scope Process` を指定することで、このPowerShellウィンドウ内でのみポリシーが変更されます。
        Set-ExecutionPolicy RemoteSigned -Scope Process -Force
    } else {
        Write-Error "実行が許可されなかったため、スクリプトを終了します。"
        if ($global:Transcript) { Stop-Transcript }
        Start-Sleep -Seconds 10
        exit
    }
}

# --- メイン処理の呼び出し ---
# すべてのチェックを通過後、Windows Updateのメインプロセスを開始します。
Start-WindowsUpdateProcess

# --- 終了処理 ---
# スクリプトが正常・異常問わず終了する際に、ログ記録を確実に停止します。
if ($global:Transcript) {
    Stop-Transcript
}
