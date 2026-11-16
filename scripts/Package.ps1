$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$toc = Get-Content -LiteralPath (Join-Path $repo 'Gemini\Gemini.toc')
$version = (($toc | Where-Object { $_ -match '^## Version: ' }) -replace '^## Version: ', '').Trim()
if (-not ($version -match '^\d+\.\d+\.\d+$')) { throw 'Invalid addon version' }
foreach ($line in $toc) {
    if ($line -match '\.lua$' -and -not (Test-Path -LiteralPath (Join-Path $repo "Gemini\$line"))) { throw "Missing TOC file: $line" }
}
$dist = Join-Path $repo 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$zip = Join-Path $dist "Gemini-$version.zip"
Compress-Archive -LiteralPath (Join-Path $repo 'Gemini') -DestinationPath $zip -Force
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS.txt'), "$hash  Gemini-$version.zip`n")
Write-Output $zip
Write-Output "SHA256 $hash"
