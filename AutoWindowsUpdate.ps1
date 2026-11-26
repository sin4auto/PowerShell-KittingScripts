<#
.SYNOPSIS
    Windows Updateの完全自動化スクリプト。

.DESCRIPTION
    更新プログラムの確認、ダウンロード、インストール、自動再起動までを、更新がなくなるまで繰り返します。
    PSWindowsUpdateモジュールの自動セットアップ、再起動後の処理継続のためのタスク登録、ログ記録機能を含みます。

.PARAMETER Round
    何周目の更新処理かを表します。再起動後の自動実行でスクリプト自身が渡すため、手動で指定する必要はありません。

.EXAMPLE
    .\AutoWindowsUpdate.ps1
    管理者権限のPowerShellでスクリプトを実行します。

.NOTES
    - 要管理者権限。
    - 初回実行にはインターネット接続が必須。
    - PowerShell 5.1 と 7 の両方で動く。Start-Admin.bat は、7 があれば 7 で起動する。
    - 5.1 で始めても、再起動のときに 7 が入っていれば、再起動のあとは 7 で続ける。
    - 完了後、手動での最終確認を推奨します: [設定] > [Windows Update] > [更新プログラムのチェック]
    Copyright (c) 2025 sin4auto
#>

param(
    # 再起動をまたいで周回数を引き継ぐため、タスク登録時に次の周回数を渡す。
    [int]$Round = 1
)

# =================================================================
# 定数定義
# =================================================================
# 再起動後の自動実行で利用するタスクスケジューラのタスク名を定義する。
$TaskName = "AutoWindowsUpdateTask"
# 失敗し続ける更新があると「インストール → 再起動」が永遠に続くため、周回数に上限を設ける。
# 新しいPCでも通常は数周で終わるので、余裕を持たせた値にしている。
$MaxRounds = 10
# 呼び出し元（Start-Admin.bat など）が失敗に気づけるよう、異常終了したら 1 に変えて最後に返す。
$exitCode = 0
# 下の catch と finally は、途中で中断しても動くため、どこで中断しても参照できるよう先に用意しておく。
$LogFile = $null
# PowerShellには「記録中かどうか」を知る標準の変数がないため、開始できたかを自分で覚えておく。
$transcriptStarted = $false

# =================================================================
# メイン処理ブロック
# =================================================================
# スクリプト全体をtryブロックで囲み、予期せぬエラーを包括的に捕捉する。
# 中断するときは exit ではなく throw を使い、終了コード・タスク削除・ログ停止を下の catch と finally にまとめる。
try {
    # --- フェーズ0: 初期化処理 ---
    # スクリプトが.ps1ファイルとして保存・実行されているかを確認する。
    # PowerShell 5.1 ではファイル以外から実行すると $PSScriptRoot が空文字になるため、$null だけでなく空文字も調べる。
    if ([string]::IsNullOrEmpty($PSScriptRoot)) {
        # ファイルではない場合、パスが取得できず後続処理が失敗するため、エラーを発生させる。
        throw "スクリプトを.ps1ファイルとして保存して実行してください。"
    }
    # スクリプトの安定した動作のため、カレントディレクトリをスクリプト自身の場所に設定する。
    Set-Location -Path $PSScriptRoot
    # 実行ログを記録するファイルパスを定義する。
    $LogFile = Join-Path $PSScriptRoot "AutoWindowsUpdate.log"
    # ログ記録（トランスクリプト）を開始する。-Appendで既存ファイルに追記する。
    try {
        Start-Transcript -Path $LogFile -Append -ErrorAction Stop
        $transcriptStarted = $true
    } catch {
        # ログ記録が開始できない場合でも、処理は続行する。
        Write-Warning "トランスクリプトの開始に失敗。ログは記録されません。Error: $($_.Exception.Message)"
    }
    # --- フェーズ1: 実行前チェック ---
    # スクリプトの実行に必要な管理者権限があるかを確認する。
    # 下のタスク削除にも管理者権限が要るため、それより先に確かめる。
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # 管理者権限がない場合は、処理を中断する。
        throw "管理者権限がありません。管理者としてPowerShellを再実行してください。"
    }
    # 過去の実行で残存している可能性のある自動実行タスクを、安全のために削除する。
    Write-Host "-> 既存の自動実行タスクをクリーンアップします..." -ForegroundColor DarkGray
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    # --- 依存モジュールのセットアップ ---
    # 1回のスクリプト実行の中では一度読み込めば足りるため、周回のループに入る前に1回だけ行う。
    Write-Host "----------------------------------------------------"
    Write-Host "[準備] 依存モジュール(PSWindowsUpdate)のセットアップ" -ForegroundColor Cyan
    # 'PSWindowsUpdate'モジュールがインストール済みかを確認する。
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Write-Host "-> 依存モジュールはインストール済み。" -ForegroundColor Green
    } else {
        # 未インストールの場合、依存関係にあるNuGetプロバイダーを準備する。
        Write-Host "-> 依存モジュールをインストールします..." -ForegroundColor Yellow
        # 失敗したまま進むと「インストール完了」と誤って表示されるため、失敗したらここで中断する。
        try {
            # PowerShell 7 には NuGet プロバイダーが最初から入っているため、足りないときだけ入れる。
            $nugetProvider = Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue | Where-Object { $_.Version -ge [version]'2.8.5.201' }
            if (-not $nugetProvider) {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
            }
            # 'PSWindowsUpdate'モジュールを全ユーザー向けにインストールする。
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -Scope AllUsers -ErrorAction Stop
        } catch {
            throw "依存モジュール(PSWindowsUpdate)のインストールに失敗しました。インターネット接続を確認してください: $($_.Exception.Message)"
        }
        Write-Host "-> インストール完了。" -ForegroundColor Green
    }
    # モジュールを現在のセッションにインポートして利用可能な状態にする。
    Import-Module PSWindowsUpdate -Force -ErrorAction Stop

    # --- フェーズ2: Windows Update メインループ ---
    # 前の周で失敗した更新。一時的な失敗は次の周で直ることがあるため、1回目の失敗では止めずに覚えておく。
    $previousFailedTitles = @()
    # 更新がなくなるまで一連の処理を繰り返すための無限ループ。
    while ($true) {
        if ($Round -gt $MaxRounds) {
            # 上限到達は「同じ更新が失敗し続けている」可能性が高いので、異常終了として利用者に確認を求める。
            throw "更新処理が上限の $MaxRounds 周に達したため中断しました。失敗し続けている更新がないか、[設定] > [Windows Update] の更新履歴を確認してください。"
        }
        Write-Host "===================================================="
        Write-Host "周回 $Round / $MaxRounds" -ForegroundColor Cyan

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
            # 5.1 は非推奨のため、PowerShell 7 が入っていれば、再起動のあとは 7 で動かす。
            # 7 を入れた直後は、今動いている PowerShell の PATH に反映されていないため、標準のインストール先も調べる。
            $powerShellExe = Join-Path $PSHOME 'powershell.exe'
            if ($PSVersionTable.PSEdition -eq 'Core') {
                $powerShellExe = Join-Path $PSHOME 'pwsh.exe'
            } else {
                $pwshCandidates = @(Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe') + @(Get-Command pwsh.exe -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
                $pwshPath = $pwshCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
                if ($pwshPath) { $powerShellExe = $pwshPath }
            }
            Write-Host "-> 再起動のあとは次の PowerShell で動かします: $powerShellExe" -ForegroundColor DarkGray
            $taskAction = New-ScheduledTaskAction -Execute $powerShellExe -Argument "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -Round $($Round + 1)"
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
        if ($transcriptStarted) { Stop-Transcript; Start-Transcript -Path $LogFile -Append }
        # 見つかった全ての更新プログラムを承諾し、インストールを実行する。-AutoRebootにより、必要に応じて自動で再起動される。
        # 失敗を確かめるため結果を受け取る。Tee-Object で、進み具合を画面とログにも残す。
        # 結果をそのまま表示すると、更新1件・段階ごとに数十項目が並び、ログが数千行になるため、1件1行にまとめる。
        # 再起動の直前まで記録が残るよう、まとめて受け取ってから表示するのではなく、届いた順に表示する。
        $installResults = $null
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose | Tee-Object -Variable installResults | ForEach-Object {
            Write-Host ("-> {0,-10} {1,-10} {2}" -f $_.Result, $_.KB, $_.Title)
        }
        # 再起動コマンドが実行された後のための短い待機時間。
        Write-Host "-> 20秒間待機します..."
        Start-Sleep -Seconds 20

        # ここに来るのは再起動しなかった場合だけなので、この周の失敗をここで確かめる。
        # 確かめないと、失敗し続ける更新に10周の上限まで気づけない。
        $failedTitles = @($installResults | Where-Object { $_.Result -eq 'Failed' } | ForEach-Object { $_.Title } | Select-Object -Unique)
        $repeatedFailedTitles = @($failedTitles | Where-Object { $previousFailedTitles -contains $_ })
        if ($repeatedFailedTitles.Count -gt 0) {
            throw "次の更新が2周続けてインストールに失敗しました: $($repeatedFailedTitles -join ' / ')。[設定] > [Windows Update] > [更新の履歴] でエラーコードを確認してください。"
        }
        if ($failedTitles.Count -gt 0) {
            Write-Warning "次の更新のインストールに失敗しました。次の周でもう一度だけ試します: $($failedTitles -join ' / ')"
        }
        $previousFailedTitles = $failedTitles

        # --- [5/5] 再起動が不要だった場合の処理 ---
        # このステップに到達した場合、-AutoRebootが再起動をトリガーしなかったことを意味する。
        Write-Host "`n[5/5] 再起動は要求されませんでした。連続して更新チェックを続行します。" -ForegroundColor Yellow
        # 再起動しなかったので、次のループのために登録した自動実行タスクは不要なため削除する。
        Write-Host "-> 自動実行タスクをクリーンアップします..." -ForegroundColor DarkGray
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        # 次のスキャンに移る前に短い待機時間を設ける。
        Write-Host "-> 5秒後に次のスキャンを開始します..."
        Start-Sleep -Seconds 5
        $Round++
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
    $exitCode = 1
    Write-Host "`nFATAL: エラーが発生しました。 $($_.Exception.Message)" -ForegroundColor Red
    if ($transcriptStarted) {
        Write-Host "処理を中断します。詳細はログファイルを参照してください: $LogFile" -ForegroundColor Red
    } else {
        # ログを記録する前に中断した場合は、存在しないログを案内しないようにする。
        Write-Host "処理を中断します。" -ForegroundColor Red
    }
    # 処理が異常終了したため、意図しない再実行を防ぐために自動実行タスクをクリーンアップする。
    Write-Host "-> 自動実行タスクをクリーンアップします..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    # ユーザーがエラーメッセージを確認するための待機時間を設ける。
    Start-Sleep -Seconds 20

} finally {
    # --- フェーズ5: 最終処理 ---
    # 処理が正常に終了しても、エラーで中断しても、必ずこのブロックが最後に実行される。
    # ログ記録（トランスクリプト）が実行中の場合、確実に停止させてファイルを閉じる。
    if ($transcriptStarted) {
        Stop-Transcript
    }
}
exit $exitCode