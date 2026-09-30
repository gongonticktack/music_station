$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$expectedPython = Join-Path $root '.tools\python-official\python.exe'
$venvPython = Join-Path $root '.venv\Scripts\python.exe'
$line = netstat -ano -p tcp | Select-String '^\s*TCP\s+127\.0\.0\.1:7860\s+\S+\s+LISTENING\s+(\d+)' | Select-Object -First 1
if (-not $line) {
    Write-Host 'Seed-VC は起動していません。'
    exit 0
}
$serverPid = [int]$line.Matches[0].Groups[1].Value
$serverProcess = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
if ($serverProcess -and $serverProcess.Path -eq $expectedPython) {
    & $venvPython -c "import os,psutil,sys; p=psutil.Process(int(sys.argv[1])); cmd=p.cmdline(); ok=os.path.normcase(p.cwd())==os.path.normcase(sys.argv[2]) and 'app.py' in cmd and '--enable-v1' in cmd; sys.exit(0 if ok else 1)" $serverPid (Join-Path $root 'seed-vc')
    if ($LASTEXITCODE -ne 0) { throw '7860 番ポートのプロセスは、この Seed-VC アプリではありません。停止しませんでした。' }
    Set-Content -LiteralPath (Join-Path $root '.tools\stop-requested') -Value '1' -NoNewline
    Stop-Process -Id $serverProcess.Id -Force
    Write-Host 'Seed-VC を停止しました。'
} else {
    throw '7860 番ポートは別のアプリが使用しています。停止しませんでした。'
}
