$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $root
$toolsDir = Join-Path $root '.tools'
$uvExe = Join-Path $toolsDir 'uv.exe'
$venvPython = Join-Path $root '.venv\Scripts\python.exe'
$logDir = Join-Path $root '.logs'
$logFile = Join-Path $logDir 'seed-vc.log'
$stopMarker = Join-Path $toolsDir 'stop-requested'
$uvVersion = '0.12.21'
$uvHash = '5D223EFA0BF00208C3853246AF09420419DFBD352536AA6BB8163D6170E23890'
$pythonVersion = '3.10.11'
$pythonHash = 'D8DEDE5005564B408BA50317108B765ED9C3C510342A598F9FD42681CBE0648B'
$pythonDir = Join-Path $toolsDir 'python-official'
$officialPython = Join-Path $pythonDir 'python.exe'
$torchVersion = '2.7.1'
$torchvisionVersion = '0.22.1'
$torchaudioVersion = '2.7.1'
$cudaIndex = 'https://download.pytorch.org/whl/cu128'

New-Item -ItemType Directory -Force -Path $toolsDir, $logDir | Out-Null
if (Test-Path -LiteralPath $stopMarker) { Remove-Item -LiteralPath $stopMarker }
Start-Transcript -Path $logFile -Append | Out-Null
$env:UV_CACHE_DIR = Join-Path $toolsDir 'cache'
$env:HF_HOME = Join-Path $toolsDir 'huggingface'
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = '1'
$env:PYTHONPATH = Join-Path $root 'seed-vc'

if (-not (Test-Path -LiteralPath $uvExe)) {
    $zip = Join-Path $toolsDir 'uv.zip'
    $url = "https://github.com/astral-sh/uv/releases/download/$uvVersion/uv-x86_64-pc-windows-msvc.zip"
    Write-Host 'uv をダウンロードしています...'
    Invoke-WebRequest -Uri $url -OutFile $zip
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $uvHash) {
        Remove-Item -LiteralPath $zip
        throw 'uv のダウンロード結果が SHA-256 検証に一致しません。'
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $toolsDir -Force
    Remove-Item -LiteralPath $zip
}

if (-not (Test-Path -LiteralPath $officialPython)) {
    $installer = Join-Path $toolsDir "python-$pythonVersion-amd64.exe"
    Write-Host '署名付きの Python 3.10 をダウンロードしています...'
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe" -OutFile $installer
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $pythonHash -or
        (Get-AuthenticodeSignature -LiteralPath $installer).Status -ne 'Valid') {
        Remove-Item -LiteralPath $installer
        throw 'Python の SHA-256 または署名の検証に失敗しました。'
    }
    $installArgs = @('/quiet', 'InstallAllUsers=0', "TargetDir=$pythonDir", 'Include_pip=1', 'Include_launcher=0', 'AssociateFiles=0', 'PrependPath=0', 'Shortcuts=0', 'Include_test=0')
    $install = Start-Process -FilePath $installer -ArgumentList $installArgs -PassThru -Wait -WindowStyle Hidden
    if ($install.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $officialPython)) { throw "Python のインストールに失敗しました（終了コード $($install.ExitCode)）。" }
}

if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host 'Python の仮想環境を作成しています...'
    & $uvExe venv (Join-Path $root '.venv') --python $officialPython
    if ($LASTEXITCODE -ne 0) { throw 'Python の仮想環境を作成できませんでした。' }
}

$manifestHash = (Get-FileHash -LiteralPath (Join-Path $root 'requirements-web.txt') -Algorithm SHA256).Hash
$stampFile = Join-Path $toolsDir 'dependencies.stamp'
$stamp = "$manifestHash|$torchVersion|$torchvisionVersion|$torchaudioVersion|$cudaIndex"
if (-not (Test-Path -LiteralPath $stampFile) -or (Get-Content -LiteralPath $stampFile -Raw).Trim() -ne $stamp) {
    Write-Host 'CUDA 対応 PyTorch をインストールしています...'
    & $uvExe pip install --python $venvPython "torch==$torchVersion" "torchvision==$torchvisionVersion" "torchaudio==$torchaudioVersion" --index-url $cudaIndex
    if ($LASTEXITCODE -ne 0) { throw 'PyTorch のインストールに失敗しました。' }
    Write-Host 'Seed-VC の依存パッケージをインストールしています...'
    & $uvExe pip install --python $venvPython -r (Join-Path $root 'requirements-web.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Seed-VC の依存パッケージをインストールできませんでした。' }
    Set-Content -LiteralPath $stampFile -Value $stamp -NoNewline
}

Write-Host 'FFmpeg を確認しています...'
$ffmpegExe = Join-Path $toolsDir 'ffmpeg.exe'
$ffprobeExe = Join-Path $toolsDir 'ffprobe.exe'
if (-not (Test-Path -LiteralPath $ffmpegExe) -or -not (Test-Path -LiteralPath $ffprobeExe)) {
    $ffmpegZip = Join-Path $toolsDir 'ffmpeg-8.1.2.zip'
    $ffmpegHash = 'DB580001CAA24AC104C8CB856CD113A87B0A443F7BDF47D8C12B1D740584A2EC'
    $ffmpegUrl = 'https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-8.1.2-essentials_build.zip'
    Write-Host 'FFmpeg と ffprobe をダウンロードしています...'
    Invoke-WebRequest -Uri $ffmpegUrl -OutFile $ffmpegZip
    if ((Get-FileHash -LiteralPath $ffmpegZip -Algorithm SHA256).Hash -ne $ffmpegHash) {
        Remove-Item -LiteralPath $ffmpegZip
        throw 'FFmpeg のダウンロード結果が SHA-256 検証に一致しません。'
    }
    $extractDir = Join-Path $toolsDir 'ffmpeg-unpacked'
    Expand-Archive -LiteralPath $ffmpegZip -DestinationPath $extractDir -Force
    $ffmpegSource = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter 'ffmpeg.exe' | Select-Object -First 1
    if (-not $ffmpegSource -or -not (Test-Path -LiteralPath (Join-Path $ffmpegSource.DirectoryName 'ffprobe.exe'))) {
        throw 'FFmpeg の圧縮ファイルに ffmpeg.exe と ffprobe.exe が見つかりません。'
    }
    Copy-Item -LiteralPath $ffmpegSource.FullName -Destination $ffmpegExe -Force
    Copy-Item -LiteralPath (Join-Path $ffmpegSource.DirectoryName 'ffprobe.exe') -Destination $ffprobeExe -Force
}
$env:PATH = "$toolsDir;$env:PATH"
& $ffmpegExe -version | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'FFmpeg を実行できません。' }
& $ffprobeExe -version | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'ffprobe を実行できません。' }
Write-Host 'FFmpeg と ffprobe の準備ができました。'

Write-Host 'Python パッケージと CUDA を確認しています...'
& $venvPython -c "import torch, torchaudio, gradio, librosa, transformers, seed_vc_wrapper; print('torch:', torch.__version__, 'CUDA:', torch.cuda.is_available()); assert torch.cuda.is_available(), 'CUDA GPU is unavailable'"
if ($LASTEXITCODE -ne 0) { throw '依存パッケージまたは GPU の確認に失敗しました。' }

$modelStampFile = Join-Path $toolsDir 'models-ready.stamp'
$wrapperHash = (Get-FileHash -LiteralPath (Join-Path $root 'seed-vc\seed_vc_wrapper.py') -Algorithm SHA256).Hash
$modelStamp = "$manifestHash|$wrapperHash"
if (-not (Test-Path -LiteralPath $modelStampFile) -or
    (Get-Content -LiteralPath $modelStampFile -Raw).Trim() -ne $modelStamp -or
    -not (Test-Path -LiteralPath (Join-Path $root 'seed-vc\checkpoints')) -or
    -not (Test-Path -LiteralPath $env:HF_HOME)) {
    Write-Host 'Seed-VC のモデルを準備しています。初回は数 GB のダウンロードが必要です...'
    Push-Location (Join-Path $root 'seed-vc')
    try {
        & $venvPython -u -c "from seed_vc_wrapper import SeedVCWrapper; model=SeedVCWrapper(); print('Seed-VC models ready:', model.device)"
        $modelExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($modelExitCode -ne 0) { throw 'Seed-VC のモデルを準備できませんでした。.logs\seed-vc.log を確認してください。' }
    Set-Content -LiteralPath $modelStampFile -Value $modelStamp -NoNewline
}
$env:HF_HUB_OFFLINE = '1'

$port = 7860
$listenerPattern = '^\s*TCP\s+127\.0\.0\.1:7860\s+\S+\s+LISTENING\s+(\d+)'
$existing = netstat -ano -p tcp | Select-String $listenerPattern | Select-Object -First 1
if ($existing) {
    $serverPid = [int]$existing.Matches[0].Groups[1].Value
    $serverProcess = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
    $expectedPython = Join-Path $toolsDir 'python-official\python.exe'
    if (-not $serverProcess -or $serverProcess.Path -ne $expectedPython) {
        throw "$port 番ポートは別のアプリが使用しています。そのアプリは停止していません。"
    }
    Write-Host '起動中の Seed-VC を停止して再起動します...'
    & (Join-Path $root 'stop-seed-vc.ps1')
    for ($i = 0; $i -lt 30; $i++) {
        $existing = netstat -ano -p tcp | Select-String $listenerPattern | Select-Object -First 1
        if (-not $existing) { break }
        Start-Sleep -Seconds 1
    }
    if ($existing) { throw "前の Seed-VC が $port 番ポートを解放しませんでした。" }
    for ($i = 0; $i -lt 10 -and (Test-Path -LiteralPath $stopMarker); $i++) {
        Start-Sleep -Seconds 1
    }
    if (Test-Path -LiteralPath $stopMarker) { Remove-Item -LiteralPath $stopMarker }
}

Write-Host "Seed-VC を起動します: http://127.0.0.1:$port/"
$env:GRADIO_SERVER_NAME = '127.0.0.1'
$env:GRADIO_SERVER_PORT = "$port"
Write-Host '使用中はこの画面を開いたままにしてください。停止するには Ctrl+C または Stop Seed-VC.cmd を実行します。'
Push-Location (Join-Path $root 'seed-vc')
try {
    & $venvPython -u app.py --enable-v1
    if (Test-Path -LiteralPath $stopMarker) {
        Remove-Item -LiteralPath $stopMarker
        Write-Host 'Seed-VC を停止しました。'
    } elseif ($LASTEXITCODE -ne 0) {
        throw "Seed-VC が終了コード $LASTEXITCODE で停止しました。.logs\seed-vc.log を確認してください。"
    }
} finally {
    Pop-Location
    Stop-Transcript | Out-Null
}
