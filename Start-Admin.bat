@echo off

:: =====================================================================
:: �� �Ǘ��Ҍ����̃`�F�b�N
:: =====================================================================
:: net session �R�}���h�͊Ǘ��Ҍ������Ȃ��Ǝ��s(errorlevel��0�ȊO�ɂȂ�)
:: ����𗘗p���āA�X�N���v�g���Ǘ��҂Ƃ��Ď��s����Ă��邩���m�F���܂��B
:: >nul 2>nul �́A����/���s���b�Z�[�W����ʂɕ\�����Ȃ����߂̂��܂��Ȃ��ł��B

net session >nul 2>nul
if %errorlevel% NEQ 0 (
    echo.
    echo ======================================================================
    echo  �G���[�F���̃X�N���v�g�͊Ǘ��҂Ƃ��Ď��s����K�v������܂��B
    echo ======================================================================
    echo.
    echo  ���̃o�b�`�t�@�C�����E�N���b�N���A�u�Ǘ��҂Ƃ��Ď��s�v��I�����Ă��������B
    echo.
    pause
    goto End
)

:menu
cls
echo ================================================
echo  ���s������������I�����Ă�������
echo ================================================
echo.
echo  1. AutoWindowsUpdate �����s����
echo.
echo  2. AutoSetup �����s����
echo.
echo  3. ���������ɏI������
echo.
echo ================================================

set /p choice="�ԍ�����͂��Ă������� (1, 2, 3): "

if "%choice%"=="1" goto RunUpdate
if "%choice%"=="2" goto RunSetup
if "%choice%"=="3" goto End

echo.
echo �����ȑI���ł��B������x��蒼���Ă��������B
pause
goto menu

:RunUpdate
echo "AutoWindowsUpdate" �����s���܂�...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0AutoWindowsUpdate.ps1"
goto Finish

:RunSetup
echo "AutoSetup" �����s���܂�...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0AutoSetup.ps1"
goto Finish

:Finish
echo.
echo �������������܂����B
pause
goto End

:End
exit