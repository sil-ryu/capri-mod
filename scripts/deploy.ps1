# Copies the Capri mod into the game's CET mods folder.
param(
    [string]$GamePath = "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077"
)

$ErrorActionPreference = "Stop"

$cetRoot = Join-Path $GamePath "bin\x64\plugins\cyber_engine_tweaks"
if (-not (Test-Path $cetRoot)) {
    throw "Cyber Engine Tweaks is not installed in '$GamePath'. Run install-frameworks.ps1 first."
}

$source = Join-Path $PSScriptRoot "..\src\cet\capri"
$target = Join-Path $cetRoot "mods\capri"

New-Item -ItemType Directory -Force -Path $target | Out-Null
# settings.json is never in src, so the player's saved settings survive a redeploy.
Copy-Item -Path (Join-Path $source "*") -Destination $target -Recurse -Force
Write-Host "Deployed Capri to $target"
