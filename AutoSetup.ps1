<#
.SYNOPSIS
    Windows PCのセットアップ作業を自動化するためのスクリプトです。

.DESCRIPTION
    このスクリプトは、新しいPCの初期設定や環境構築を自動で行います。
    設定ファイル「config.json」の内容に基づき、以下の処理を実行します。

    このスクリプトは2つのフェーズ（段階）に分かれて動作します。
    [フェーズ1]
    - Wingetを利用したアプリケーションの一括インストール
    - Windows標準搭載アプリ（UWPアプリ）の削除
    - インストール済みアプリの全体的なアップグレード
    - エクスプローラーの表示設定など、Windowsのシステム設定変更
    - 完了後、フェーズ2を自動実行するよう設定し、PCを再起動します。

    [フェーズ2]
    - PC再起動後に自動で実行されます。
    - Node.jsのパッケージ（npm）をグローバルにインストールします。（開発者向け）

.PARAMETER Phase
    実行するフェーズを '2' のように指定します。
    通常、このパラメータは手動で指定する必要はありません。
    フェーズ1の最後に、PC再起動後にフェーズ2を呼び出すために内部的に使用されます。

.EXAMPLE
    .\AutoSetup.ps1
    PowerShellを「管理者として実行」で起動し、このコマンドを実行します。
    これにより、フェーズ1の処理が開始されます。

.NOTES
    [注意点]
    - 実行には必ず管理者権限が必要です。
    - スクリプトと同じ場所に「config.json」ファイルが必要です。
    - 処理中はインターネット接続が必須です。
    - このスクリプトは、Windowsに標準でインストールされているPowerShell 5.1での動作を想定しています。
    - Copyright (c) 2025 sin4auto
#>

#=============================================================================
# ■ パラメータ定義
#=============================================================================
# スクリプト実行時に外部から受け取る引数（パラメータ）を定義します。
param(
    # 実行する処理の段階（フェーズ）を指定します。
    # '2' を指定すると、再起動後の処理であるフェーズ2が実行されます。
    [string]$Phase
)

#=============================================================================
# ■ 0. スクリプトの初期化と設定ファイルの読み込み
#=============================================================================
# スクリプトを実行するための下準備を行います。
# 万が一、設定ファイルが見つからないなどの問題があれば、処理を中断します。
try {
    # スクリプトファイル自身の場所を取得し、そこを基準に動作させます。
    # これにより、どこからスクリプトを実行しても、設定ファイルを正しく見つけられます。
    $PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Set-Location -Path $PSScriptRoot

    # 必須ファイルである「config.json」のパスを生成します。
    $configPath = Join-Path $PSScriptRoot "config.json"

    # 「config.json」が存在するかどうかを確認します。
    if (-not (Test-Path $configPath)) {
        # ファイルが見つからない場合は、エラーメッセージを表示して処理を停止します。
        throw "設定ファイル 'config.json' が見つかりません。スクリプトと同じフォルダに配置してください。"
    }

    # 「config.json」の内容を読み込み、PowerShellで扱えるオブジェクト形式に変換します。
    # 日本語のコメントなどが含まれていても文字化けしないよう、UTF-8形式で読み込みます。
    $config = Get-Content -Path $configPath -Encoding UTF8 -Raw | ConvertFrom-Json
}
catch {
    # 上記の `try` ブロック内でエラーが発生した場合、その内容を表示してスクリプトを安全に終了させます。
    Write-Error $_.Exception.Message
    Read-Host "Enterキーを押すと終了します。"
    exit
}

#----------------------------------------------------------------------
# ● 管理者権限の確認
#----------------------------------------------------------------------
# フェーズ1はシステムの変更を伴うため、管理者権限が必須です。
# （フェーズ2は再起動後に自動実行されるため、このチェックは不要です）
if ($Phase -ne '2') {
    # 現在のスクリプトが管理者として実行されているかを確認します。
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        # 管理者でない場合、警告メッセージを表示してスクリプトを終了します。
        Write-Warning "エラー：このスクリプトの実行には管理者権限が必要です。"
        Write-Warning "PowerShellのアイコンを右クリックし、「管理者として実行」を選択してから再度お試しください。"
        Read-Host "Enterキーを押すとスクリプトを終了します。"
        exit
    }
}


#=============================================================================
# ■ フェーズ2：再起動後の処理 (npm パッケージのインストール)
#=============================================================================
# スクリプト実行時に -Phase '2' が指定されていた場合、このブロックのみが実行されます。
if ($Phase -eq '2') {
    # PC起動直後はシステムが不安定な場合があるため、少し待機してから処理を開始します。
    Start-Sleep -Seconds 5

    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  セットアップ フェーズ2 を開始します" -ForegroundColor Cyan
    Write-Host "  (開発者向けツールのインストール)" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # config.jsonの 'npmInstall' リストに記載されたパッケージを一つずつ処理します。
    foreach ($pkg in $config.npmInstall) {
        Write-Host "パッケージ [$($pkg.package)] ($($pkg.description)) の状態を確認しています..."
        
        # npmコマンドを使い、パッケージがすでにグローバルインストールされているかを確認します。
        # 画面に出力はせず、コマンドの成功/失敗を示す終了コード($LASTEXITCODE)だけを利用します。
        npm list -g $pkg.package --depth=0 > $null
        
        # 終了コードが 0 の場合は「インストール済み」を意味します。
        if ($LASTEXITCODE -eq 0) {
            Write-Host "-> [$($pkg.package)] はインストール済みです。スキップします。" -ForegroundColor Cyan
        } else {
            # インストールされていない場合、npm installコマンドを実行します。
            Write-Host "-> [$($pkg.package)] をグローバルにインストールします..."
            npm install -g $pkg.package
            
            # インストール結果を判定し、メッセージを表示します。
            if ($LASTEXITCODE -eq 0) {
                Write-Host "-> [$($pkg.package)] のインストールに成功しました。" -ForegroundColor Green
            } else {
                Write-Warning "-> [$($pkg.package)] のインストール中にエラーが発生しました。ログを確認してください。"
            }
        }
    }
    
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "  すべてのセットアップ処理が完了しました！" -ForegroundColor Green
    Write-Host "==============================================="
    
    # ユーザーが結果を確認できるよう、キー入力があるまでウィンドウを閉じずに待機します。
    Read-Host "Enterキーを押して、このウィンドウを閉じてください。"
    
    # フェーズ2の全処理が完了したため、スクリプトを終了します。
    exit
}

#=============================================================================
# ■ フェーズ1：PC初期設定のメイン処理
#=============================================================================
# 実行前に画面をクリアして見やすくします。
Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  セットアップ フェーズ1 を開始します" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

#----------------------------------------------------------------------
# ● 1. アプリケーションのインストール (winget)
#----------------------------------------------------------------------
Write-Host "--- 1. アプリケーションのインストールを開始します ---" -ForegroundColor Green

# config.jsonの 'wingetInstall' リストに記載されたアプリを一つずつ処理します。
foreach ($app in $config.wingetInstall) {
    Write-Host "アプリ [$($app.id)] ($($app.name)) の状態を確認しています..."

    # winget listコマンドを使い、アプリがすでにインストールされているかを確認します。
    # "-e" はIDが完全一致するものだけを対象にするためのオプションです。
    # 画面への出力は不要なため、"> $null" で抑制します。
    winget list --id $app.id -e --accept-source-agreements > $null

    # 直前のコマンドの終了コードが 0 なら「インストール済み」です。
    if ($LASTEXITCODE -eq 0) {
        Write-Host "-> [$($app.id)] はインストール済みです。スキップします。" -ForegroundColor Cyan
    }
    else {
        Write-Host "-> [$($app.id)] をインストールします..."

        # ここから、実行するwinget installコマンドを動的に組み立てます。
        # まず、基本となる標準的なインストールコマンドを生成します。
        $command = "winget install --id $($app.id) -e --accept-package-agreements --accept-source-agreements"

        # 次に、config.jsonでこのアプリに個別の "options" が指定されているか確認します。
        if ($app.PSObject.Properties.Name -contains 'options' -and -not [string]::IsNullOrWhiteSpace($app.options)) {
            # "options" があれば、その内容をコマンドの末尾に追加します。
            # これにより、アプリごとに特有のインストール設定（例: VSCodeのPATH追加など）が可能になります。
            $command += " $($app.options)"
            Write-Host "-> 個別オプション ($($app.options)) を適用してインストールします。" -ForegroundColor Yellow
        }

        # 最終的に組み立てられたコマンド文字列を実行します。
        Invoke-Expression -Command $command

        # インストール結果を判定し、メッセージを表示します。
        if ($LASTEXITCODE -eq 0) {
            Write-Host "-> [$($app.id)] のインストールに成功しました。" -ForegroundColor Green
        }
        else {
            # 失敗した場合でも、他のアプリのインストールを続けるため、処理は中断しません。
            Write-Warning "-> [$($app.id)] のインストール中にエラーが発生しました。処理を続行します。"
        }
    }
}
Write-Host "--- アプリケーションのインストールが完了しました ---" -ForegroundColor Green
Write-Host ""

#----------------------------------------------------------------------
# ● 2. 不要な標準アプリの削除
#----------------------------------------------------------------------
Write-Host "--- 2. 不要なプリインストールアプリの削除を開始します ---" -ForegroundColor Green

# config.jsonの 'appxRemove' リストに記載されたアプリを一つずつ処理します。
foreach ($app in $config.appxRemove) {
    Write-Host "[$($app.name)] ($($app.description)) を検索し、存在すれば削除します..."
    # Get-AppxPackageで対象アプリを検索し、Remove-AppxPackageで削除します。
    # -AllUsers: PCの全ユーザーから削除します。
    # -ErrorAction SilentlyContinue: アプリが見つからなくてもエラーを表示せず、次の処理へ進みます。
    Get-AppxPackage -AllUsers $app.name | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}
Write-Host "--- 不要なプリインストールアプリの削除が完了しました ---" -ForegroundColor Green
Write-Host ""

#----------------------------------------------------------------------
# ● 3. 既存アプリのアップグレード
#----------------------------------------------------------------------
Write-Host "--- 3. インストール済みアプリをすべて最新版に更新します ---" -ForegroundColor Green
# winget upgradeコマンドで、PCにインストールされているすべてのアプリを最新バージョンに更新します。
# --all: すべてのアプリを対象にします。
# --silent: 確認画面などを表示しないサイレントモードで実行します。
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
Write-Host "--- アプリの更新が完了しました ---" -ForegroundColor Green
Write-Host ""

#----------------------------------------------------------------------
# ● 4. Windowsのシステム設定変更
#----------------------------------------------------------------------
Write-Host "--- 4. Windowsの各種設定を変更します ---" -ForegroundColor Green
# レジストリを直接編集して、使い勝手を向上させるための設定変更を行います。

Write-Host "エクスプローラーの表示設定を変更中..."
# 隠しファイルやシステムファイルを常に表示する
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Force
# すべてのファイルの拡張子（.txt, .exeなど）を表示する
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Force
# エクスプローラーのアドレスバーに常にフルパスを表示する
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPathAddress" -Value 1 -Force
# エクスプローラーを起動したときに「クイックアクセス」ではなく「PC」を開く
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Force
# Windows 11の右クリックメニューを、以前の形式（クラシックコンテキストメニュー）に戻す
New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Set-ItemProperty -Name "(Default)" -Value "" -Force

Write-Host "高速スタートアップを無効化中..."
# シャットダウンや再起動の安定性を向上させるため、高速スタートアップ機能を無効にします。
# この設定はシステム全体（HKEY_LOCAL_MACHINE）に影響するため、管理者権限が必須です。
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord -Force

Write-Host "--- Windowsの各種設定変更が完了しました ---" -ForegroundColor Green
Write-Host ""

#----------------------------------------------------------------------
# ● 5. フェーズ2の自動実行設定と再起動
#----------------------------------------------------------------------
Write-Host "--- 5. 再起動後にフェーズ2を自動実行するよう設定します ---" -ForegroundColor Green

# Windowsの「RunOnce」機能を利用し、次回PCにサインインした時に一度だけコマンドを自動実行させます。
# これにより、再起動後に手動で操作しなくても、フェーズ2の処理を継続できます。
$runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

# このスクリプト自身のフルパスを取得します。
$scriptPath = $MyInvocation.MyCommand.Path

# 再起動後に実行するコマンドを組み立てます。「-Phase 2」を引数に指定するのがポイントです。
$commandToRun = "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -Phase 2"

# RunOnceレジストリキーに、実行したいコマンドを登録します。
Set-ItemProperty -Path $runOnceKey -Name "AutoSetupPhase2" -Value $commandToRun -Force
Write-Host "再起動後の自動実行設定が完了しました。"
Write-Host ""

#----------------------------------------------------------------------
# ● 自動再起動の実行
#----------------------------------------------------------------------
Write-Host "==============================================="
Write-Host "  フェーズ1のすべての処理が完了しました！" -ForegroundColor Green
Write-Host "==============================================="
Write-Host "設定を完全に適用するため、システムを再起動します。" -ForegroundColor Yellow

# ユーザーが処理をキャンセルする時間的猶予を与えるため、10秒間待機します。
Write-Host "10秒後に自動で再起動が開始されます。中断したい場合はこのウィンドウを閉じてください。" -ForegroundColor Yellow
Start-Sleep -Seconds 10

# PCを強制的に再起動し、フェーズ1を完了します。
Restart-Computer -Force