<#
.SYNOPSIS
    recipe.yaml の書き方を、実行せずに確かめます。
.DESCRIPTION
    AutoSetup.ps1 は、知らないキーや書き間違えたキーを黙って無視します。
    例えば wingetInstall を wingetInstal と書くと、アプリが1つも入らないまま正常に終わってしまいます。
    PC で実行してから気づくのでは遅いため、ここで先に見つけます。
.PARAMETER Path
    確かめる recipe.yaml のパス。省略すると、ルートの recipe.yaml と template-recipes 内のすべてを確かめます。
.EXAMPLE
    .\.github\scripts\Test-Recipe.ps1
#>
param(
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'
Import-Module powershell-yaml

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $Path) {
    $Path = @(Join-Path $repoRoot 'recipe.yaml') +
        @(Get-ChildItem -Path (Join-Path $repoRoot 'template-recipes') -Recurse -Filter 'recipe.yaml' | ForEach-Object { $_.FullName })
}

# 各セクションの項目に書いてよいキーと、必ず書くキー。AutoSetup.ps1 が実際に読むキーに合わせている。
$itemRules = @{
    windowsSettings = @{ Allowed = @('description', 'command'); Required = @('command') }
    wingetInstall   = @{ Allowed = @('description', 'id', 'options'); Required = @('id') }
    appxRemove      = @{ Allowed = @('description', 'name'); Required = @('name') }
    packageManagers = @{ Allowed = @('managerName', 'checkCommand', 'installCommand', 'packages'); Required = @('managerName', 'checkCommand', 'installCommand') }
    packages        = @{ Allowed = @('description', 'name'); Required = @('name') }
}
$sectionKeys = @{
    root   = @('phase1', 'phase2')
    phase1 = @('windowsSettings', 'wingetInstall', 'appxRemove')
    phase2 = @('packageManagers')
}

$problems = [System.Collections.Generic.List[string]]::new()

function Add-Problem {
    param([string]$Message)
    $problems.Add("$($script:currentLabel): $Message")
}

function Test-KeyName {
    param($Map, [string[]]$Allowed, [string]$Location)
    foreach ($key in $Map.Keys) {
        # 大文字・小文字の違いも書き間違いとして扱う（キーは大文字・小文字を区別して書く決まりにそろえる）。
        if ($Allowed -cnotcontains $key) {
            Add-Problem "$Location に知らないキー '$key' があります。使えるキー: $($Allowed -join ', ')"
        }
    }
}

function Test-Section {
    param($Items, [string]$RuleName, [string]$Location)
    # 中身が空のセクションは、AutoSetup.ps1 が飛ばすだけなので問題にしない。
    if ($null -eq $Items) { return }
    if ($Items -isnot [System.Collections.IList]) {
        Add-Problem "$Location は、「- 」で始まる項目のリストにしてください。"
        return
    }
    $rule = $itemRules[$RuleName]
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $itemLocation = "$Location の $($i + 1) 番目"
        if ($item -isnot [System.Collections.IDictionary]) {
            Add-Problem "$itemLocation が「キー: 値」の形になっていません。"
            continue
        }
        foreach ($key in @('id', 'name', 'managerName', 'description')) {
            if ($item.Contains($key)) {
                $itemLocation += " ($key`: $($item[$key]))"
                break
            }
        }
        Test-KeyName -Map $item -Allowed $rule.Allowed -Location $itemLocation
        foreach ($key in $rule.Required) {
            if ([string]::IsNullOrWhiteSpace([string]$item[$key])) {
                Add-Problem "$itemLocation に '$key' がありません。"
            }
        }
        if ($RuleName -eq 'packageManagers') {
            Test-Section -Items $item['packages'] -RuleName 'packages' -Location "$itemLocation.packages"
        }
    }
}

function Test-Phase {
    param($Config, [string]$PhaseName)
    if (-not $Config.Contains($PhaseName) -or $null -eq $Config[$PhaseName]) { return }
    $phase = $Config[$PhaseName]
    if ($phase -isnot [System.Collections.IDictionary]) {
        Add-Problem "$PhaseName が「キー: 値」の形になっていません。"
        return
    }
    Test-KeyName -Map $phase -Allowed $sectionKeys[$PhaseName] -Location $PhaseName
    foreach ($sectionName in $sectionKeys[$PhaseName]) {
        if ($phase.Contains($sectionName)) {
            Test-Section -Items $phase[$sectionName] -RuleName $sectionName -Location "$PhaseName.$sectionName"
        }
    }
}

foreach ($file in $Path) {
    $fullPath = (Resolve-Path $file).Path
    $script:currentLabel = $fullPath
    if ($fullPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        # GitHub の注釈はリポジトリからの相対パスでないとファイルに結び付かない。
        $script:currentLabel = $fullPath.Substring($repoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
    }
    $problemCountBefore = $problems.Count
    try {
        # AutoSetup.ps1 は UTF-8 として読むため、別の文字コードで保存されていたら文字化けする前にここで止める。
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString([System.IO.File]::ReadAllBytes($file)).TrimStart([char]0xFEFF)
    }
    catch {
        Add-Problem "UTF-8 として読めません。UTF-8 で保存し直してください。"
        continue
    }
    try {
        $config = ConvertFrom-Yaml -Yaml $text
    }
    catch {
        Add-Problem "YAML として読めません（インデントや引用符を確認してください）: $($_.Exception.Message)"
        continue
    }
    if ($config -isnot [System.Collections.IDictionary]) {
        Add-Problem "中身が空か、「phase1:」「phase2:」で始まる形になっていません。"
        continue
    }
    Test-KeyName -Map $config -Allowed $sectionKeys.root -Location 'ファイルの一番上'
    Test-Phase -Config $config -PhaseName 'phase1'
    Test-Phase -Config $config -PhaseName 'phase2'
    if ($problems.Count -eq $problemCountBefore) {
        Write-Host "OK: $script:currentLabel"
    }
}

if ($problems.Count -eq 0) {
    exit 0
}
foreach ($problem in $problems) {
    if ($env:GITHUB_ACTIONS -eq 'true') {
        # GitHub の画面で、どのファイルの問題かが分かるように注釈の形で出す。
        $fileName, $message = $problem -split ': ', 2
        Write-Host "::error file=$fileName::$message"
    }
    else {
        Write-Host "NG: $problem" -ForegroundColor Red
    }
}
Write-Host "recipe.yaml の書き方に $($problems.Count) 件の問題があります。"
exit 1
