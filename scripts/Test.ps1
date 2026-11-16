param([string]$LuaExecutable)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo
try {
    if ($LuaExecutable) {
        & $LuaExecutable tests/run.lua
        if ($LASTEXITCODE -ne 0) { throw 'Lua tests failed' }
        return
    }
    $msbuild = Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'
    if (-not (Test-Path -LiteralPath $msbuild)) { throw 'Pass -LuaExecutable pointing to a Lua 5.1 interpreter, or install VS 2026 Community v145.' }
    $env:PATH = "$env:SystemRoot\System32;$env:PATH"
    & $msbuild tests/runner.vcxproj /p:Configuration=Release /p:Platform=x64 /nologo /v:minimal
    if ($LASTEXITCODE -ne 0) { throw 'Test runner build failed; the sibling vega Lua library is required.' }
    & (Join-Path $repo 'tmp\tests\runner.exe') tests/run.lua
    if ($LASTEXITCODE -ne 0) { throw 'Lua tests failed' }
} finally { Pop-Location }
