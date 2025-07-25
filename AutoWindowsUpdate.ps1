<#
.SYNOPSIS
    Windows Updateの完全自動化スクリプト。

.DESCRIPTION
    更新プログラムの確認、ダウンロード、インストール、自動再起動までを、更新がなくなるまで繰り返します。
    PSWindowsUpdateモジュールの自動セットアップ、再起動後の処理継続のためのタスク登録、ログ記録機能を含みます。

.EXAMPLE
    .\AutoWindowsUpdate.ps1
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
# RunOnceレジストリキーに登録する名前
$RunOnceKeyName = "AutoWindowsUpdate"

# =================================================================
# メイン処理ブロック
# =================================================================
try {
    # --- 0. 初期化フェーズ ---
    # スクリプトパスの解決とログ記録の開始
    try {
        # スクリプトがファイルとして保存されていない場合($PSScriptRootが$null)はエラー
        if ($null -eq $PSScriptRoot) {
            throw "スクリプトを.ps1ファイルとして保存して実行してください。"
        }
        # カレントディレクトリをスクリプトの場所($PSScriptRoot)に設定
        Set-Location -Path $PSScriptRoot
    } catch {
        Write-Error $_.Exception.Message
        Start-Sleep -Seconds 10
        exit
    }

    # ログファイルの設定とトランスクリプトの開始
    $LogFile = Join-Path $PSScriptRoot "AutoWindowsUpdate.log"
    try {
        Start-Transcript -Path $LogFile -Append
    } catch {
        Write-Warning "トランスクリプトの開始に失敗。ログは記録されません。Error: $($_.Exception.Message)"
    }

    # --- 1. 実行前チェック ---
    # 管理者権限の検証
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "管理者権限がありません。管理者としてPowerShellを再実行してください。"
        Start-Sleep -Seconds 10
        exit
    }

    # --- 2. Windows Update メインループ ---
    while ($true) {
        # --- [0/5] 依存モジュール(PSWindowsUpdate)のセットアップ ---
        Write-Host "----------------------------------------------------"
        Write-Host "[0/5] 依存モジュール(PSWindowsUpdate)のセットアップ" -ForegroundColor Cyan
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Write-Host "-> 依存モジュールはインストール済み。" -ForegroundColor Green
        } else {
            Write-Host "-> 依存モジュールをインストールします..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -Scope AllUsers
            Write-Host "-> インストール完了。" -ForegroundColor Green
        }
        Import-Module PSWindowsUpdate -Force

        # --- [1/5] 更新プログラムのスキャン ---
        Write-Host "----------------------------------------------------"
        Write-Host "`n[1/5] 更新プログラムをスキャン中..." -ForegroundColor Cyan
        $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

        # --- 更新が存在しない場合の処理 ---
        if (-not $updates) {
            Write-Host "`n>> 更新プログラムは検出されませんでした。システムは最新です。" -ForegroundColor Green
            Write-Host ">> 全プロセス正常完了。処理を終了します..."
            break # ループを終了
        }

        # --- [2/5] 検出された更新プログラムのリスト表示 ---
        Write-Host ("`n[2/5] {0}個の更新を検出。" -f $updates.Count) -ForegroundColor Yellow
        $updates | Select-Object Title, KB, Size | Format-Table

        # --- [3/5] 再起動後にスクリプトを自動実行するよう設定 ---
        Write-Host "`n[3/5] 再起動後にスクリプトを自動実行するよう設定..." -ForegroundColor Cyan
        $runOnceRegistryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        # $PSCommandPath変数でスクリプトのフルパスを直接取得する
        $runOnceCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Set-ItemProperty -Path $runOnceRegistryKeyPath -Name $RunOnceKeyName -Value $runOnceCommand -Force
        Write-Host "-> レジストリに '$RunOnceKeyName' を登録しました。" -ForegroundColor Green

        # --- [4/5] 更新のインストールと条件付き再起動 ---
        Write-Host "`n[4/5] 更新のダウンロードとインストールを開始..." -ForegroundColor Cyan
        Write-Host "-> この処理は長時間かかる場合があります。必要に応じて自動的に再起動します。" -ForegroundColor Yellow
        
        # 再起動直前のログ欠損を防ぐため、トランスクリプトを再開
        if ($global:Transcript) { Stop-Transcript; Start-Transcript -Path $LogFile -Append }
        
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose

        # --- [5/5] 再起動が不要だった場合の処理 ---
        # このステップに到達した場合、AutoRebootはトリガーされなかったことを意味する
        Write-Host "`n[5/5] 再起動は要求されませんでした。連続して更新チェックを続行します。" -ForegroundColor Yellow
        
        # 次のサイクルに備えたRunOnceキーは不要なため削除
        Remove-ItemProperty -Path $runOnceRegistryKeyPath -Name $RunOnceKeyName -ErrorAction SilentlyContinue
        
        Write-Host "-> 5秒後に次のスキャンを開始します..."
        Start-Sleep -Seconds 5
        continue
    }

    # --- 3. 正常終了時のクリーンアップ ---
    # RunOnceキーは自動で消えるため、ここではクリーンアップ不要
    Write-Host "`n全ての処理が完了しました。"

} catch {
    # --- 4. 例外処理 ---
    # スクリプト全体で発生したエラーを捕捉
    Write-Host "`nFATAL: エラーが発生しました。 $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "処理を中断します。詳細はログファイルを参照してください: $LogFile" -ForegroundColor Red
    
    # フェイルセーフとしてRunOnceキーを削除
    $runOnceRegistryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    Remove-ItemProperty -Path $runOnceRegistryKeyPath -Name $RunOnceKeyName -ErrorAction SilentlyContinue
    Write-Host "-> 自動実行レジストリキーをクリーンアップしました。"
    Start-Sleep -Seconds 20

} finally {
    # --- 5. 最終処理 ---
    # 成功・失敗にかかわらず、必ず実行
    if ($global:Transcript) {
        Stop-Transcript
    }
}