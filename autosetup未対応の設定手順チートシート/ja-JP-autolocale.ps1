#Requires -RunAsAdministrator
<# 日本語化ワンショット（Install-Language を優先、失敗時 DISM にフォールバック） #>
[CmdletBinding()]
param([switch]$IncludeSpeech,[switch]$IncludeHandwriting,[switch]$IncludeOCR,[switch]$IncludeTTS,
      [switch]$KeepEnUSKeyboard,[switch]$UseDism,[string]$Source,[switch]$NoReboot)
$ErrorActionPreference='Stop'
function Test-IsWin11{try{$v=(Get-CimInstance Win32_OperatingSystem).Version;return [version]$v -ge [version]"10.0.22000"}catch{return $false}}
if(-not(Test-IsWin11)){Write-Warning "Windows 11 以外の OS です。"}
$features=@('Language.Basic~~~ja-JP~0.0.1.0')
if($IncludeHandwriting){$features+='Language.Handwriting~~~ja-JP~0.0.1.0'}
if($IncludeOCR){$features+='Language.OCR~~~ja-JP~0.0.1.0'}
if($IncludeSpeech){$features+='Language.Speech~~~ja-JP~0.0.1.0'}
if($IncludeTTS){$features+='Language.TextToSpeech~~~ja-JP~0.0.1.0'}
function Install-WithInstallLanguage{Install-Language ja-JP -CopyToSettings}
function Install-WithDism{foreach($cap in $features){$args=@('/Online','/Add-Capability',"/CapabilityName:$cap");if($Source){$args+=('/LimitAccess',"/Source:$Source")};$p=Start-Process dism.exe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden;if($p.ExitCode -ne 0){throw "DISM 失敗: $cap ($($p.ExitCode))"}}}
try{if($UseDism){Install-WithDism}else{try{Install-WithInstallLanguage}catch{Write-Warning "Install-Language 失敗 → DISM へ";Install-WithDism}}}
catch{Write-Error "言語コンポーネント導入に失敗。ネット接続 / -Source を確認してください。";throw}
Set-WinUILanguageOverride -Language ja-JP; Set-Culture ja-JP
$ll=New-WinUserLanguageList -Language 'ja-JP'; if($KeepEnUSKeyboard){$ll.Add('en-US')}
Set-WinUserLanguageList -LanguageList $ll -Force
Set-WinSystemLocale -SystemLocale ja-JP
try{Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true}catch{}
try{Set-TimeZone -Id "Tokyo Standard Time"}catch{& tzutil.exe /s "Tokyo Standard Time"}
if(-not $NoReboot){Start-Sleep 5; Restart-Computer}