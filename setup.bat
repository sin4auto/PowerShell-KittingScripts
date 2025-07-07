@echo off
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