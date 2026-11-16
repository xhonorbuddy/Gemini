param([string]$GameRoot = 'C:\Program Files (x86)\World of Warcraft\_forever_')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo 'Gemini'
$addonRoot = Join-Path $GameRoot 'Interface\AddOns'
if (-not (Test-Path -LiteralPath $addonRoot -PathType Container)) { throw "Addon directory not found: $addonRoot" }
$target = Join-Path $addonRoot 'Gemini'
New-Item -ItemType Directory -Path $target -Force | Out-Null
Get-ChildItem -LiteralPath $source -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $target -Force }
foreach ($line in Get-Content -LiteralPath (Join-Path $target 'Gemini.toc')) {
    if ($line -match '\.lua$' -and -not (Test-Path -LiteralPath (Join-Path $target $line))) { throw "Missing TOC file: $line" }
}
Write-Output "Installed Gemini to $target"
Write-Output 'Run /reload, then /gemini in game.'
