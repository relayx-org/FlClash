$ErrorActionPreference = 'Stop'
if (-not $env:GITHUB_ENV -or -not $args.Count -or -not (Test-Path pubspec.yaml) -or -not (Test-Path core)) {
    throw 'Run from the application checkout inside GitHub Actions.'
}
$base = Join-Path $env:RUNNER_TOOL_CACHE 'iping'
$target = Join-Path $base "build\$($args[0])"
$paths = @('build', 'libclash', '.dart_tool\flutter_build', '.dart_tool\setup_build_cache', '.dart_tool\hooks_runner', 'services\helper\target', 'plugins\rust_api\rust\target')
foreach ($path in $paths) {
    $destination = Join-Path $target $path
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $current = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($current -and ($current.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        if ($current.Target -contains $destination) { continue }
        & cmd.exe /c rmdir "`"$path`""
        if ($LASTEXITCODE -ne 0) { throw "Cannot replace junction $path" }
    } elseif ($current) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
    $parent = Split-Path $path -Parent
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    New-Item -ItemType Junction -Path $path -Target $destination | Out-Null
}
foreach ($name in @('pub', 'gradle', 'npm')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $base $name) | Out-Null
}
@("PUB_CACHE=$base\pub", "GRADLE_USER_HOME=$base\gradle", "npm_config_cache=$base\npm") | Add-Content $env:GITHUB_ENV
Write-Output 'Reusing local build and package caches outside the checkout.'
