# PURPOSE: Download pinned official Windows development tools into an ignored folder.
# CHANGE THIS SCRIPT WHEN: Reviewed tool versions and verified hashes change.
# DO NOT PUT HERE: System installs, public publishing or device firmware changes.

$ErrorActionPreference = 'Stop'
$previewRoot = Split-Path $PSScriptRoot -Parent
$toolsDirectory = Join-Path $previewRoot '.local-tools'
New-Item -ItemType Directory -Path $toolsDirectory -Force | Out-Null
$downloads = @(
    @{ File = 'love-11.5-win64.zip'; Directory = '.';
       Url = 'https://github.com/love2d/love/releases/download/11.5/love-11.5-win64.zip';
       Hash = 'BA6E56BE2685E53C817749C4A5007F51137136FE5A3AB64920508BABC2E74369' },
    @{ File = 'stylua-windows-x86_64.zip'; Directory = 'stylua';
       Url = 'https://github.com/JohnnyMorganz/StyLua/releases/download/v2.5.2/stylua-windows-x86_64.zip';
       Hash = 'E77D0EA1226B8B389B43F702240091249A96EEA25857281F90EA24D0EB9EB969' },
    @{ File = 'luacheck/luacheck.exe'; Directory = $null;
       Url = 'https://github.com/lunarmodules/luacheck/releases/download/v1.2.0/luacheck.exe';
       Hash = '0F1C69C4D09F1EBB4D8DF14C215E4553E2E639BD4CB7BF3C639B0DAA6198317B' }
)
foreach ($download in $downloads) {
    $destination = Join-Path $toolsDirectory $download.File
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    if (-not (Test-Path -LiteralPath $destination)) {
        Invoke-WebRequest -Uri $download.Url -OutFile $destination
    }
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $download.Hash) {
        throw ('Tool checksum mismatch: ' + $download.File)
    }
    if ($download.Directory) {
        Expand-Archive -LiteralPath $destination -DestinationPath (Join-Path $toolsDirectory $download.Directory) -Force
    }
}
Write-Output 'Pinned local development tools are ready.'
