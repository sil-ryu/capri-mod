# Extracts the framework zips from the modding tools folder into the game folder.
param(
    [string]$GamePath = "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077",
    [string]$ToolsPath = (Join-Path $env:USERPROFILE "Documents\modding tools")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path (Join-Path $GamePath "bin\x64\Cyberpunk2077.exe"))) {
    throw "Cyberpunk2077.exe not found under '$GamePath'. Let the Steam download finish first."
}

# Install order matters only for readability; each zip mirrors the game folder layout.
$frameworks = [ordered]@{
    "RED4ext"             = @("RED4ext*.zip")
    "Cyber Engine Tweaks" = @("Cyber Engine Tweaks*.zip", "cet_*.zip", "CET*.zip")
    "redscript"           = @("redscript*.zip")
    "TweakXL"             = @("TweakXL*.zip")
    "ArchiveXL"           = @("ArchiveXL*.zip")
    "Codeware"            = @("Codeware*.zip")
}

foreach ($name in $frameworks.Keys) {
    $zip = $frameworks[$name] |
        ForEach-Object { Get-ChildItem -Path $ToolsPath -Filter $_ -File } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $zip) {
        Write-Warning "$name zip not found in '$ToolsPath' - skipped"
        continue
    }
    Expand-Archive -Path $zip.FullName -DestinationPath $GamePath -Force
    Write-Host "Installed $name ($($zip.Name))"
}
