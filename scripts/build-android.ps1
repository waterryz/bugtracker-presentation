param([switch]$Release)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExecutable = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterExecutable)) {
    throw 'Flutter not found. Add the Flutter bin directory to PATH and retry.'
}

function Initialize-PluginJunctions {
    $manifestPath = Join-Path $projectDirectory '.flutter-plugins-dependencies'
    if (-not (Test-Path -LiteralPath $manifestPath)) { return }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $junctionDirectory = Join-Path $projectDirectory 'windows\flutter\ephemeral\.plugin_symlinks'
    New-Item -ItemType Directory -Force -Path $junctionDirectory | Out-Null
    foreach ($plugin in $manifest.plugins.windows) {
        if ($plugin.name -ne [IO.Path]::GetFileName($plugin.name)) { continue }
        $junctionPath = Join-Path $junctionDirectory $plugin.name
        if (-not (Test-Path -LiteralPath $junctionPath)) {
            # Directory junctions work without changing Windows Developer Mode.
            New-Item -ItemType Junction -Path $junctionPath -Target $plugin.path | Out-Null
        }
    }
}

Push-Location $projectDirectory
try {
    Initialize-PluginJunctions
    & $flutterExecutable --no-version-check pub get
    if ($LASTEXITCODE -ne 0) {
        Initialize-PluginJunctions
        & $flutterExecutable --no-version-check pub get
        if ($LASTEXITCODE -ne 0) { throw 'Could not resolve Flutter dependencies.' }
    }
    $mode = if ($Release) { '--release' } else { '--debug' }
    & $flutterExecutable --no-version-check build apk $mode --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed. See the build output above.' }
    $apk = if ($Release) { 'app-release.apk' } else { 'app-debug.apk' }
    Write-Output (Join-Path $projectDirectory "build\app\outputs\flutter-apk\$apk")
}
finally {
    Pop-Location
}
