# PURPOSE: Run formatting and scenario/simulation checks with local tools.
# CHANGE THIS SCRIPT WHEN: Verified development checks or tool paths change.
# DO NOT PUT HERE: Dependency installation, personal-save edits or release approval.

param(
    [string]$LovePath = '',
    [string]$StyLuaPath = '',
    [string]$LuacheckPath = ''
)
$ErrorActionPreference = 'Stop'
$previewRoot = Split-Path $PSScriptRoot -Parent
if (-not $LovePath) { $LovePath = Join-Path $previewRoot '.local-tools/love-11.5-win64/lovec.exe' }
if (-not $StyLuaPath) { $StyLuaPath = Join-Path $previewRoot '.local-tools/stylua/stylua.exe' }
if (-not $LuacheckPath) { $LuacheckPath = Join-Path $previewRoot '.local-tools/luacheck/luacheck.exe' }
Push-Location $previewRoot
try {
    if (-not (Test-Path -LiteralPath $LovePath)) { throw 'Supply -LovePath for LOVE 11.5 lovec.exe.' }
    if (-not (Test-Path -LiteralPath $StyLuaPath)) { throw 'Supply -StyLuaPath for StyLua 2.5.2.' }
    & $StyLuaPath --check --config-path .stylua.toml main.lua conf.lua src tests
    if ($LASTEXITCODE -ne 0) { throw 'Formatting check failed.' }
    if (-not (Test-Path -LiteralPath $LuacheckPath)) { throw 'Supply -LuacheckPath for Luacheck 1.2.0.' }
    & $LuacheckPath main.lua conf.lua src tests --no-color --codes
    if ($LASTEXITCODE -ne 0) { throw 'Static lint failed.' }
    $coreFiles = @(
        Get-ChildItem src/blackjack, src/random, src/progress, src/training -Filter '*.lua' -File | Where-Object Name -ne 'practice.lua'
        Get-Item src/plain_copy.lua
        Get-Item src/check.lua
    )
    $forbidden = $coreFiles | Select-String -Pattern '\b(love|io|os|debug)\.|math\.random|\bffi\b|src\.(ui|platform|persistence|app)'
    if ($forbidden) { $forbidden | Write-Output; throw 'Portable-core dependency boundary failed.' }
    Write-Output 'Portable-core dependency boundary: PASS'
    & $LovePath . --self-test
    if ($LASTEXITCODE -ne 0) { throw 'Scenario/simulation checks failed.' }
} finally { Pop-Location }
