# Run FlutterFire configure without adding flutterfire_cli to pubspec (conflicts with flutter_launcher_icons).
# Prereqs: dart pub global activate flutterfire_cli
# Use a Google account that has access to Firebase project "haver-bahatzer" (Editor/Owner).

$ErrorActionPreference = "Stop"
$PubBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
$Flutterfire = Join-Path $PubBin "flutterfire.bat"

if (-not (Test-Path $Flutterfire)) {
    Write-Host "Installing FlutterFire CLI globally..."
    dart pub global activate flutterfire_cli
}

# Ensure this session can find `flutterfire` (optional if User PATH already includes Pub\Cache\bin).
if ($env:Path -notlike "*$PubBin*") {
    $env:Path = "$PubBin;$env:Path"
    Write-Host "Prepended to session PATH: $PubBin"
}

Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "Running FlutterFire configure for haver-bahatzer (android, ios, web)..."
Write-Host "If you see 'project could not be found' or 403, run: firebase logout && firebase login"
Write-Host "and sign in with an account that has access to the Firebase project."
Write-Host ""

& $Flutterfire configure `
    --project=haver-bahatzer `
    --platforms=android,ios,web `
    --yes `
    --overwrite-firebase-options
