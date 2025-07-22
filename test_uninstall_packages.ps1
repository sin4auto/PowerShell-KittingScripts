# --- YAMLモジュールのインポート ---
try {
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    Write-Error "YAMLモジュールが見つかりません。テストの前に Install-Module powershell-yaml を実行してください。"
    return
}

# --- 設定ファイルの読み込み ---
$configFilePath = Join-Path $PSScriptRoot "config.yaml"
if (-not (Test-Path $configFilePath)) {
    $configFilePath = Join-Path $PSScriptRoot "config.yml"
}
$config = Get-Content -Path $configFilePath -Encoding UTF8 -Raw | ConvertFrom-Yaml

# --- パッケージのアンインストール処理 ---
Write-Host "config.yamlに基づき、パッケージのアンインストールを開始します..." -ForegroundColor Yellow

foreach ($manager in $config.phase2.packageManagers) {
    $managerName = $manager.managerName
    $commandName = $manager.commandName
    
    Write-Host "`n--- $($managerName) パッケージをアンインストールしています ---" -ForegroundColor Cyan
    
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        Write-Warning "コマンド '$commandName' が見つからないため、スキップします。"
        continue
    }

    foreach ($pkgName in $manager.packages) {
        Write-Host "アンインストール中: $pkgName"
        
        # マネージャーごとにアンインストールコマンドを定義
        $uninstallCommand = ""
        if ($commandName -eq 'npm') {
            $uninstallCommand = "npm uninstall -g $pkgName"
        }
        elseif ($commandName -eq 'uv') {
            $uninstallCommand = "echo y | uv pip uninstall $pkgName --system"
        }
        
        if ($uninstallCommand) {
            # cmd.exe経由で実行
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallCommand" -Wait -NoNewWindow -PassThru | Out-Null
                Write-Host "-> '$pkgName' のアンインストールコマンドを実行しました。" -ForegroundColor Green
            }
            catch {
                Write-Warning "-> '$pkgName' のアンインストール中にエラーが発生しました。"
            }
        }
    }
}

Write-Host "`nすべてのパッケージのアンインストール処理が完了しました。" -ForegroundColor Yellow