<#
.SYNOPSIS
    リポジトリのファイルが、決められた文字コードと改行で保存されているかを確かめます。
.DESCRIPTION
    文字コードや改行がずれると、PowerShell 5.1 で日本語が読めなくなる、コマンドプロンプトで文字化けする、
    WSL でシェルスクリプトが動かなくなる、といった問題が起きます。どれも実行するまで気づけないため、ここで先に見つけます。
    決まりは .claude/CLAUDE.md の「文字コードと改行」と同じです。Git で管理しているファイルだけを確かめます。
.EXAMPLE
    .\.github\scripts\Test-Encoding.ps1
#>
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

# 拡張子ごとの決まり。
# Encoding … Utf8Bom: BOM 付き UTF-8 / Utf8NoBom: BOM なし UTF-8 / Utf8: BOM はどちらでもよい UTF-8 / ShiftJis: Shift-JIS
$rules = @{
    # PowerShell 5.1 は BOM がないと日本語を正しく読めない。
    '.ps1'  = @{ Encoding = 'Utf8Bom'; Eol = 'CRLF' }
    # UTF-8 にすると、コマンドプロンプトで日本語が文字化けする。
    '.bat'  = @{ Encoding = 'ShiftJis'; Eol = 'CRLF' }
    # WSL で実行する。BOM があると 1 行目の「#!」が認識されず、CR があるとコマンド名の末尾に CR が付いて動かない。
    '.sh'   = @{ Encoding = 'Utf8NoBom'; Eol = 'LF' }
    '.yaml' = @{ Encoding = 'Utf8'; Eol = 'CRLF' }
    '.html' = @{ Encoding = 'Utf8'; Eol = 'CRLF' }
}

# PowerShell 7 は、Shift-JIS などの古い文字コードを使う前に登録が要る。
if ($PSVersionTable.PSEdition -eq 'Core') {
    [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
}
# 読めない文字があったら、別の文字に置き換えずに例外にする設定で用意する。
$strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
$strictShiftJis = [System.Text.Encoding]::GetEncoding(932, [System.Text.EncoderFallback]::ExceptionFallback, [System.Text.DecoderFallback]::ExceptionFallback)
# 1 バイトを 1 文字に対応させる文字コード。改行を数えるだけなので、どの文字コードのファイルにも使える。
$latin1 = [System.Text.Encoding]::GetEncoding(28591)

function Test-StrictDecode {
    param([System.Text.Encoding]$Encoding, [byte[]]$Bytes)
    try {
        [void]$Encoding.GetString($Bytes)
        return $true
    }
    catch {
        return $false
    }
}

# 日本語のファイル名が「\343\201...」の形にならないよう、UTF-8 のまま受け取る。
$previousOutputEncoding = [System.Console]::OutputEncoding
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try {
    $trackedFiles = @(git -C $repoRoot -c core.quotepath=false ls-files)
}
finally {
    [System.Console]::OutputEncoding = $previousOutputEncoding
}
if ($LASTEXITCODE -ne 0) {
    throw "Git で管理しているファイルの一覧を取得できませんでした。終了コード: $LASTEXITCODE"
}

$problems = [System.Collections.Generic.List[string]]::new()
$checkedCount = 0
foreach ($relativePath in $trackedFiles) {
    $rule = $rules[[System.IO.Path]::GetExtension($relativePath).ToLowerInvariant()]
    if (-not $rule) { continue }
    $checkedCount++
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $repoRoot $relativePath))
    $hasBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
    $hasNonAscii = $false
    foreach ($byte in $bytes) {
        if ($byte -gt 0x7F) { $hasNonAscii = $true; break }
    }

    switch ($rule.Encoding) {
        'Utf8Bom' {
            if (-not $hasBom) { $problems.Add("${relativePath}: BOM 付きの UTF-8 で保存してください（BOM がありません）。") }
            elseif (-not (Test-StrictDecode $strictUtf8 $bytes)) { $problems.Add("${relativePath}: UTF-8 として読めない文字があります。") }
        }
        'Utf8NoBom' {
            if ($hasBom) { $problems.Add("${relativePath}: BOM なしの UTF-8 で保存してください（BOM があります）。") }
            elseif (-not (Test-StrictDecode $strictUtf8 $bytes)) { $problems.Add("${relativePath}: UTF-8 として読めない文字があります。") }
        }
        'Utf8' {
            if (-not (Test-StrictDecode $strictUtf8 $bytes)) { $problems.Add("${relativePath}: UTF-8 として読めない文字があります。") }
        }
        'ShiftJis' {
            # 日本語を含まないファイルは、どの文字コードでも同じ中身になるので確かめない。
            # UTF-8 の日本語は Shift-JIS としても読めてしまうことがあるため、先に「UTF-8 として読めないこと」を確かめる。
            if ($hasBom -or ($hasNonAscii -and (Test-StrictDecode $strictUtf8 $bytes))) {
                $problems.Add("${relativePath}: UTF-8 で保存されています。Shift-JIS で保存し直してください。")
            }
            elseif ($hasNonAscii -and -not (Test-StrictDecode $strictShiftJis $bytes)) {
                $problems.Add("${relativePath}: Shift-JIS として読めない文字があります。")
            }
        }
    }

    $text = $latin1.GetString($bytes)
    $crlfCount = [regex]::Matches($text, "`r`n").Count
    $bareLfCount = [regex]::Matches($text, "(?<!`r)`n").Count
    $bareCrCount = [regex]::Matches($text, "`r(?!`n)").Count
    if ($rule.Eol -eq 'CRLF' -and ($bareLfCount -gt 0 -or $bareCrCount -gt 0)) {
        $problems.Add("${relativePath}: 改行は CRLF にしてください（LF だけの改行が $bareLfCount か所、CR だけの改行が $bareCrCount か所あります）。")
    }
    if ($rule.Eol -eq 'LF' -and ($crlfCount -gt 0 -or $bareCrCount -gt 0)) {
        $problems.Add("${relativePath}: 改行は LF にしてください（CRLF の改行が $crlfCount か所、CR だけの改行が $bareCrCount か所あります）。")
    }
}

if ($problems.Count -eq 0) {
    Write-Host "OK: $checkedCount 件のファイルが、決められた文字コードと改行で保存されています。"
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
Write-Host "文字コードと改行に $($problems.Count) 件の問題があります。"
exit 1
