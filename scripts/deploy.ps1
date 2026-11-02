# Copies the Capri mod into the game: the CET test bench, the cyberdeck's redscript and its TweakXL records.
param(
    [string]$GamePath = "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077"
)

$ErrorActionPreference = "Stop"

$cetRoot = Join-Path $GamePath "bin\x64\plugins\cyber_engine_tweaks"
if (-not (Test-Path $cetRoot)) {
    throw "Cyber Engine Tweaks is not installed in '$GamePath'. Run install-frameworks.ps1 first."
}

$src = Join-Path $PSScriptRoot "..\src"

$cetTarget = Join-Path $cetRoot "mods\capri"
New-Item -ItemType Directory -Force -Path $cetTarget | Out-Null
# settings.json is never in src, so the player's saved settings survive a redeploy.
Copy-Item -Path (Join-Path $src "cet\capri\*") -Destination $cetTarget -Recurse -Force
Write-Host "Deployed CET mod to $cetTarget"

# The deck folders are replaced wholesale so files removed from src don't linger in the game.
$deckParts = @(
    @{ Source = "reds\capri"; Target = "r6\scripts\capri" },
    @{ Source = "tweaks\capri"; Target = "r6\tweaks\capri" }
)
foreach ($part in $deckParts) {
    $target = Join-Path $GamePath $part.Target
    if (Test-Path $target) { Remove-Item -Recurse -Force $target }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Copy-Item -Path (Join-Path $src "$($part.Source)\*") -Destination $target -Recurse -Force
    Write-Host "Deployed $($part.Source) to $target"
}
