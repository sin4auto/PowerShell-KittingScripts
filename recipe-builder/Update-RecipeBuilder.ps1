<#
.SYNOPSIS
    recipe-builder/recipe-builder.html に、recipe.yaml とテンプレートの中身を埋め込み直します。
.DESCRIPTION
    レシピ作成アプリは、ネットにつながらない PC でもダブルクリックで使えるよう、1つの HTML ファイルにしています。
    ブラウザーは file:// で開いたページからほかのファイルを読めないため、テンプレートを HTML の中に埋め込んでいます。
    recipe.yaml や template-recipes の中身を変えたら、このスクリプトを実行してください。
.EXAMPLE
    .\recipe-builder\Update-RecipeBuilder.ps1
#>
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$htmlPath = Join-Path $PSScriptRoot 'recipe-builder.html'
$beginMarker = '<!-- BEGIN TEMPLATES'
$endMarker = '<!-- END TEMPLATES -->'

# ルートの recipe.yaml を先頭にし、アプリを開いたときの初期状態にする。
$sources = @([pscustomobject]@{ Name = 'recipe.yaml（ルートの既定）'; Path = 'recipe.yaml' })
$sources += @(Get-ChildItem -Path (Join-Path $repoRoot 'template-recipes') -Directory | Sort-Object Name | Where-Object {
        Test-Path (Join-Path $_.FullName 'recipe.yaml')
    } | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Path = "template-recipes/$($_.Name)/recipe.yaml" }
    })

$utf8 = [System.Text.UTF8Encoding]::new($false)
$blocks = foreach ($source in $sources) {
    $text = [System.IO.File]::ReadAllText((Join-Path $repoRoot $source.Path), $utf8).TrimStart([char]0xFEFF) -replace "`r`n", "`n"
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
[System.IO.File]::WriteAllText($htmlPath, $newHtml, $utf8)
Write-Host "recipe-builder.html にテンプレートを $($sources.Count) 件埋め込みました。"
