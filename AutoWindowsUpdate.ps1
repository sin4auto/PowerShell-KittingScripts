# =================================================================
# 【スクリプト名】
#   Windows Update 全自動化スクリプト
#
# 【概要】
#   Windows Update を「最新の状態です」と表示されるまで、更新の
#   インストールと再起動を自動で繰り返します。一度実行すれば、
#   全ての更新が完了するまで完全に放置できます。
#
# 【主な機能】
#   - 必須モジュール(PSWindowsUpdate)の自動インストール
#   - 更新チェック → インストール → 再起動 のサイクルを自動反復
#   - 再起動後、スクリプトを自動継続するためのタスクを登録
#   - 全ての実行履歴をログファイルに記録
#
# 【使用方法】
#   1. このスクリプト(.ps1)をPCに保存します。
#   2. PowerShellを「管理者として実行」します。
#   3. PowerShellコンソールで、保存したスクリプトを実行します。
#
# 【注意事項】
#   - このスクリプトは必ず「管理者として実行」してください。
#   - モジュールの初回インストールにはインターネット接続が必要です。
# =================================================================

# -----------------------------------------------------------------
# ■ 設定値
# -----------------------------------------------------------------
# 再起動後にこのスクリプトを自動実行させるためのタスク名です。
# 他のタスクと名前が競合しない限り、変更の必要はありません。
$TaskName = "Ultimate-AutoUpdateAfterReboot"

# -----------------------------------------------------------------
# ■ 実行前準備
# -----------------------------------------------------------------
# スクリプト自身の場所を特定し、ログ記録を開始します。
try {
    # このスクリプトファイルがどこにあるか、そのフルパスを取得します。
    $ScriptPath = $MyInvocation.MyCommand.Path
    # スクリプトファイルが置かれているフォルダのパスを取得します。
    $ScriptDir = Split-Path $ScriptPath -Parent
    # ログファイル等が意図した場所に作成されるよう、作業場所をスクリプトのあるフォルダに移動します。
    Set-Location -Path $ScriptDir
} catch {
    # このエラーは、スクリプトをファイルとして保存せず、コードを直接コンソールに貼り付けた場合などに発生します。
    Write-Error "スクリプトを.ps1ファイルとして保存してから実行してください。"
    Start-Sleep -Seconds 10
    exit
}

# 全ての画面表示をログファイルに保存する設定です。
# 何が起きたかを後から確認するのに役立ちます。
$LogFile = Join-Path $ScriptDir "AutoUpdateLog.txt"
try {
    # 既存のログに追記する形で、記録を開始します。
    Start-Transcript -Path $LogFile -Append
} catch {
    Write-Warning "ログ記録の開始に失敗しました。エラー: $($_.Exception.Message)"
}


# =================================================================
# ■ メイン処理関数
# Windows Updateの確認から再起動までの一連の処理を実行します。
# =================================================================
Function Start-WindowsUpdateProcess {
    try {
        # --- ステップ1: 必須モジュールの確認とセットアップ ---
        Write-Host "----------------------------------------------------" -ForegroundColor Green
        Write-Host "[1/6] 必須モジュール(PSWindowsUpdate)のセットアップを開始します..." -ForegroundColor Cyan

        # `PSWindowsUpdate`モジュールがPCにインストールされているか確認します。
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "-> モジュールが未導入のため、インストールします..." -ForegroundColor Yellow
            
            # 古い環境でエラーが出ないよう、PowerShellのモジュール管理機能を最新化します。
            if ((Get-Module -ListAvailable -Name PowerShellGet).Version -lt [System.Version]'2.0.0') {
                Write-Host "--> 依存関係(PowerShellGet)を更新中..."
                Install-Module PowerShellGet -Force -SkipPublisherCheck
            }
            # モジュールをインストールするための基盤(NuGet)を準備します。
            if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                Write-Host "--> 依存関係(NuGet)をインストール中..."
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            }
            
            # PSWindowsUpdateモジュールを、このPCの全ユーザーが使えるようにインストールします。
            Write-Host "--> PSWindowsUpdateモジュールをインストール中..."
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -Scope AllUsers
            Write-Host "-> モジュールのインストールが完了しました。" -ForegroundColor Green
        } else {
            Write-Host "-> モジュールは既にインストールされています。" -ForegroundColor Green
        }
        
        # モジュールを使えるように、現在のPowerShellセッションに読み込みます。
        Import-Module PSWindowsUpdate -Force

        # --- ステップ2: 更新プログラムの有無を確認 ---
        Write-Host "----------------------------------------------------" -ForegroundColor Green
        Write-Host "`n[2/6] Windows Updateサーバーに更新を確認します..." -ForegroundColor Cyan
        
        # 利用可能な更新プログラムの一覧を取得します。
        # `-MicrosoftUpdate`オプションにより、Officeなど他のMicrosoft製品も対象になります。
        $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

        # --- ステップ3: 更新がない場合の終了処理 ---
        # 更新プログラムの一覧が空だった場合、PCは最新の状態です。
        if ($null -eq $updates) {
            Write-Host "`n>> システムは最新です。更新プログラムはありません。" -ForegroundColor Green
            Write-Host ">> 後片付けをして終了します..." -ForegroundColor Yellow
            
            # 再起動用に登録したタスクが残っている場合があるので、ここで削除します。
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "-> 自動実行タスクを削除しました。" -ForegroundColor Green
            
            Write-Host "`n全ての処理が完了しました。10秒後にスクリプトを終了します。"
            
            # ログの記録を停止します。
            if ($global:Transcript) { Stop-Transcript }
            Start-Sleep -Seconds 10
            exit
        }

        # --- ステップ4: 更新プログラムの一覧表示 ---
        Write-Host ("`n[3/6] {0}個の更新プログラムが見つかりました。" -f $updates.Count) -ForegroundColor Yellow
        # 見つかった更新プログラムの詳細を表形式で表示します。
        $updates | Select-Object Title, KB, Size | Format-Table

        # --- ステップ5: 再起動後の自動実行タスクを登録 ---
        Write-Host "`n[4/6] 再起動後に処理を継続するためのタスクを登録します..." -ForegroundColor Cyan
        
        # 実行するコマンド（このスクリプト自身）を定義します。
        $psPath    = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
        $action    = New-ScheduledTaskAction -Execute $psPath -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -WorkingDirectory $ScriptDir
        # 実行するタイミング（PC起動時）を定義します。起動直後の負荷を避けるため、1分間の遅延を設けます。
        $trigger   = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Minutes 1)
        # 実行する権限（システムアカウント、最高権限）を定義します。
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        # 実行時の詳細な条件（バッテリー駆動時でも実行する、など）を定義します。
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

        # 上記で定義した設定を使い、タスクスケジューラにタスクを登録（または上書き）します。
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop
        Write-Host "-> タスク '$TaskName' を登録しました。" -ForegroundColor Green

        # --- ステップ6: 更新のインストールと再起動 ---
        Write-Host "`n[5/6] 更新プログラムのダウンロードとインストールを開始します..." -ForegroundColor Cyan
        Write-Host "この処理は時間がかかる場合があります。自動で再起動するまでお待ちください。" -ForegroundColor Yellow
        
        # 再起動直前のログが消えないように、ここで一度ログを止め、再度開始します。
        if ($global:Transcript) { Stop-Transcript }
        Start-Transcript -Path $LogFile -Append
        
        # 見つかった全ての更新を承認し(-AcceptAll)、必要なら自動で再起動(-AutoReboot)します。
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose

        # --- ステップ7: 再起動が不要だった場合のループ処理 ---
        # インストールが完了しても再起動が不要だった場合、まだ更新が残っている可能性があります。
        Write-Host "`n[6/6] 再起動は不要でした。続けて残りの更新をチェックします。" -ForegroundColor Yellow
        # 今回のサイクルでは再起動しなかったので、先ほど登録したタスクは不要です。削除します。
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        
        # 5秒待ってから、もう一度この関数の最初から処理を繰り返します。
        Write-Host "-> 5秒後に更新チェックを再開します..."
        Start-Sleep -Seconds 5
        Start-WindowsUpdateProcess

    } catch {
        # --- エラー処理 ---
        # 上記の `try` ブロック内で何かエラーが発生した場合、この部分が実行されます。
        Write-Host "`nエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "処理を中断します。ネットワーク接続などを確認してください。" -ForegroundColor Red
        Write-Host "詳細はログファイルを参照してください: $LogFile" -ForegroundColor Red
        # 念のため、登録済みのタスクを削除して、クリーンな状態に戻します。
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 20
        # ログの記録を停止します。
        if ($global:Transcript) { Stop-Transcript }
    }
}

# =================================================================
# ■ スクリプト実行の開始点
# =================================================================

# --- チェック1: 管理者権限の有無 ---
# システム設定を変更するため、管理者として実行されているかを確認します。
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "管理者権限がありません。このスクリプトは管理者として実行する必要があります。"
    Write-Warning "PowerShellを「管理者として実行」で開き直してください。"
    # ログの記録を停止します。
    if ($global:Transcript) { Stop-Transcript }
    Start-Sleep -Seconds 10
    exit
}

# --- チェック2: 実行ポリシーの確認 ---
# PowerShellのセキュリティ設定が厳しく、スクリプトを実行できない場合があります。
# その場合は、このプロセスに限り一時的に実行を許可するかどうかをユーザーに確認します。
if ((Get-ExecutionPolicy) -ne "Unrestricted" -and (Get-ExecutionPolicy) -ne "RemoteSigned" -and (Get-ExecutionPolicy) -ne "Bypass") {
    Write-Warning "現在のPowerShell実行ポリシーでは、スクリプトを実行できません。"
    $choice = Read-Host "このウィンドウ内でのみ、一時的に実行を許可しますか？ (Y/N)"
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        # 現在のPowerShellプロセス内でのみ、実行ポリシーを変更します。
        Set-ExecutionPolicy RemoteSigned -Scope Process -Force
    } else {
        Write-Error "実行が許可されなかったため、スクリプトを終了します。"
        # ログの記録を停止します。
        if ($global:Transcript) { Stop-Transcript }
        Start-Sleep -Seconds 10
        exit
    }
}

# --- メイン処理の実行 ---
# 全ての準備が整ったので、Windows Updateのメイン処理関数を呼び出します。
Start-WindowsUpdateProcess

# --- 終了処理 ---
# スクリプトが最後まで到達した場合、ログの記録を確実に停止します。
if ($global:Transcript) {
    Stop-Transcript
}