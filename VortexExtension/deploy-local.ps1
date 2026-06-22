# Copy the extension bundle into the local Vortex plugins folder for testing.
# Restart Vortex afterwards for it to pick up changes.
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'extension'
$dest = Join-Path $env:APPDATA 'Vortex\plugins\game-scum-ue4ss'

if (-not (Test-Path $src)) { throw "extension folder not found at $src" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
Write-Host "Deployed extension to $dest"
Write-Host "Restart Vortex to load it."
