<#
.SYNOPSIS
    APP_RecipeBuilder/recipe-builder.html に、recipe.yaml とテンプレートの中身を埋め込み直します。
.DESCRIPTION
    レシピ作成アプリは、ネットにつながらない PC でもダブルクリックで使えるよう、1つの HTML ファイルにしています。
    ブラウザーは file:// で開いたページからほかのファイルを読めないため、テンプレートを HTML の中に埋め込んでいます。
    recipe.yaml や template-recipes の中身を変えたら、このスクリプトを実行してください。
.EXAMPLE
    .\APP_RecipeBuilder\Update-RecipeBuilder.ps1
#>
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$htmlPath = Join-Path $PSScriptRoot 'recipe-builder.html'
$beginMarker = '<!-- BEGIN TEMPLATES'
$endMarker = '<!-- END TEMPLATES -->'

$utf8 = [System.Text.UTF8Encoding]::new($false)
function Read-RecipeText {
    param([string]$RelativePath)
    [System.IO.File]::ReadAllText((Join-Path $repoRoot $RelativePath), $utf8).TrimStart([char]0xFEFF) -replace "`r`n", "`n"
}

$sources = @(Get-ChildItem -Path (Join-Path $repoRoot 'template-recipes') -Directory | Sort-Object Name | Where-Object {
        Test-Path (Join-Path $_.FullName 'recipe.yaml')
    } | ForEach-Object {
        $path = "template-recipes/$($_.Name)/recipe.yaml"
        [pscustomobject]@{ Name = $_.Name; Path = $path; Text = (Read-RecipeText $path) }
    })
# ルートの recipe.yaml は、どれかのテンプレートと同じ中身なら埋め込まない。
# 同じ中身が選択肢に2つ並ぶと、どちらを選べばよいか迷わせるため。中身が違うときだけ先頭に足す。
$rootText = Read-RecipeText 'recipe.yaml'
if (-not ($sources | Where-Object { $_.Text -ceq $rootText })) {
    $sources = @([pscustomobject]@{ Name = 'recipe.yaml（ルートの既定）'; Path = 'recipe.yaml'; Text = $rootText }) + $sources
}

$blocks = foreach ($source in $sources) {
    $text = $source.Text
    # script 要素の中でも「</script」と「<!--」だけは HTML として解釈され、埋め込みが途中で切れてしまうため止める。
    if ($text -match '(?i)</script|<!--') {
        throw "$($source.Path) に '</script' または '<!--' が含まれているため、埋め込めません。"
    }
    "<script type=`"text/plain`" class=`"recipe-template`" data-name=`"$($source.Name)`" data-path=`"$($source.Path)`">`n$($text.TrimEnd("`n"))`n</script>"
}

$html = [System.IO.File]::ReadAllText($htmlPath, $utf8) -replace "`r`n", "`n"
$begin = $html.IndexOf($beginMarker)
$end = $html.IndexOf($endMarker)
if ($begin -lt 0 -or $end -lt $begin) {
    throw "recipe-builder.html に埋め込み位置の目印（$beginMarker と $endMarker）が見つかりません。"
}
$afterBeginLine = $html.IndexOf("`n", $begin) + 1
$newHtml = $html.Substring(0, $afterBeginLine) + ($blocks -join "`n") + "`n" + $html.Substring($end)
# 組み立ては LF で行い、書き出すときに、ほかの Windows 用ファイルと同じ CRLF にそろえる。
[System.IO.File]::WriteAllText($htmlPath, ($newHtml -replace "`n", "`r`n"), $utf8)
Write-Host "recipe-builder.html にテンプレートを $($sources.Count) 件埋め込みました。"
