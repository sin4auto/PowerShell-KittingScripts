@echo off

:: =====================================================================
:: ■ 管理者権限のチェック
:: =====================================================================
:: net session コマンドは管理者権限がないと失敗(errorlevelが0以外になる)
:: これを利用して、スクリプトが管理者として実行されているかを確認します。
:: >nul 2>nul は、成功/失敗メッセージを画面に表示しないためのおまじないです。

net session >nul 2>nul
if %errorlevel% NEQ 0 (
    echo.
    echo ======================================================================
    echo  エラー：このスクリプトは管理者として実行する必要があります。
    echo ======================================================================
    echo.
    echo  このバッチファイルを右クリックし、「管理者として実行」を選択してください。
    echo.
    pause
    goto End
)

:menu
cls
echo ================================================
echo  実行したい処理を選択してください
echo ================================================
echo.
echo  1. AutoWindowsUpdate を実行する
echo.
echo  2. AutoSetup を実行する
echo.
echo  3. 何もせずに終了する
echo.
echo ================================================

set /p choice="番号を入力してください (1, 2, 3): "

if "%choice%"=="1" goto RunUpdate
if "%choice%"=="2" goto RunSetup
if "%choice%"=="3" goto End

echo.
echo 無効な選択です。もう一度やり直してください。
pause
goto menu

:RunUpdate
echo "AutoWindowsUpdate" を実行します...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0AutoWindowsUpdate.ps1"
goto Finish

:RunSetup
echo "AutoSetup" を実行します...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0AutoSetup.ps1"
goto Finish

:Finish
echo.
echo 処理が完了しました。
pause
goto End

:End
exit