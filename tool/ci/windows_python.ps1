$ErrorActionPreference = 'Stop'
$version = '3.12.10'
$expected = '4acbed6dd1c744b0376e3b1cf57ce906f9dc9e95e68824584c8099a63025a3c3'
$pythonRoot = Join-Path $env:RUNNER_TOOL_CACHE "iping\python-$version"
$complete = Join-Path $pythonRoot '.complete'
if (-not (Test-Path $complete)) {
    $archive = Join-Path $env:RUNNER_TEMP "python-$version-embed-amd64.zip"
    $staging = Join-Path $env:RUNNER_TEMP ("iping-python-" + [Guid]::NewGuid())
    Invoke-WebRequest -UseBasicParsing "https://www.python.org/ftp/python/$version/python-$version-embed-amd64.zip" -OutFile $archive
    if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
        throw 'Python download checksum mismatch'
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $staging
    $python = Join-Path $staging 'python.exe'
    if ((Get-AuthenticodeSignature $python).Status -ne 'Valid') {
        throw 'Python executable signature invalid'
    }
    & $python -I -c "import hashlib, json, pathlib, subprocess; assert hasattr(hashlib, 'file_digest')"
    if ($LASTEXITCODE -ne 0) { throw 'Portable Python self-check failed' }
    New-Item -ItemType Directory -Force (Split-Path $pythonRoot) | Out-Null
    if (Test-Path $pythonRoot) { Remove-Item $pythonRoot -Recurse -Force }
    Move-Item $staging $pythonRoot
    New-Item -ItemType File $complete | Out-Null
    Remove-Item $archive
}
[IO.File]::AppendAllText($env:GITHUB_PATH, "$pythonRoot`n", (New-Object System.Text.UTF8Encoding $false))
& (Join-Path $pythonRoot 'python.exe') --version
if ($LASTEXITCODE -ne 0) { throw 'Python is not runnable' }
