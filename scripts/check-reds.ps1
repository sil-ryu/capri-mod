# Compiles the Capri redscript against the game's own scripts (plus Codeware and TweakXL) in a
# scratch folder, without touching the game install. Exits non-zero on compile errors.
param(
    [string]$GamePath = "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077"
)

$ErrorActionPreference = "Stop"

$scc = Join-Path $GamePath "engine\tools\scc.exe"
if (-not (Test-Path $scc)) {
    throw "redscript is not installed in '$GamePath'. Run install-frameworks.ps1 first."
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) "capri-reds-check"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
$scripts = Join-Path $work "scripts"
$cache = Join-Path $work "cache"
New-Item -ItemType Directory -Force -Path (Join-Path $scripts "capri"), (Join-Path $scripts "deps"), $cache | Out-Null

Copy-Item -Path (Join-Path $PSScriptRoot "..\src\reds\capri\*") -Destination (Join-Path $scripts "capri")
foreach ($plugin in "Codeware", "TweakXL") {
    Copy-Item -Path (Join-Path $GamePath "red4ext\plugins\$plugin\Scripts\*.reds") -Destination (Join-Path $scripts "deps")
}
# Other script mods installed in the game (e.g. Cyberware-EX), so conflicts with them show up too.
Get-ChildItem -Path (Join-Path $GamePath "r6\scripts") -Directory | Where-Object Name -ne "capri" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $scripts "mods\$($_.Name)") -Recurse
}
Copy-Item -Path (Join-Path $GamePath "r6\cache\final.redscripts") -Destination $cache

$output = & $scc -compile $scripts -customCacheDir $cache 2>&1 | Out-String
Write-Host $output
if ($output -match "compilation has failed|\[ERROR") {
    exit 1
}
Write-Host "Capri redscript compiles cleanly."
