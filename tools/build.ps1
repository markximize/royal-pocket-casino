# PURPOSE: Package only the desktop preview's owned source and notices.
# CHANGE THIS SCRIPT WHEN: The reviewed desktop archive contents change.
# DO NOT PUT HERE: Runtime downloads, firmware changes or public publishing.

param([string]$OutputName = 'royal-pocket-casino-desktop-preview.love')
$ErrorActionPreference = 'Stop'
$previewRoot = Split-Path $PSScriptRoot -Parent
if ([IO.Path]::GetFileName($OutputName) -ne $OutputName -or -not $OutputName.EndsWith('.love')) {
    throw 'OutputName must be a simple .love filename.'
}
$artifactDirectory = Join-Path $previewRoot 'artifacts'
New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
$archivePath = Join-Path $artifactDirectory $OutputName
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($archivePath, [IO.FileMode]::Create)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    $sourceFiles = @(
        Get-Item -LiteralPath (Join-Path $previewRoot 'main.lua')
        Get-Item -LiteralPath (Join-Path $previewRoot 'conf.lua')
        Get-Item -LiteralPath (Join-Path $previewRoot 'THIRD_PARTY_NOTICES.md')
        foreach ($sourceDirectory in @('src', 'tests', 'notices', 'assets')) {
            Get-ChildItem -LiteralPath (Join-Path $previewRoot $sourceDirectory) -File -Recurse
        }
    )
    foreach ($sourceFile in ($sourceFiles | Sort-Object FullName)) {
        $relativePath = $sourceFile.FullName.Substring($previewRoot.Length + 1).Replace('\', '/')
        $entry = $archive.CreateEntry($relativePath, [IO.Compression.CompressionLevel]::Optimal)
        # Stable entry timestamps keep unchanged local builds reproducible.
        $entry.LastWriteTime = [DateTimeOffset]::new(2026, 10, 1, 0, 0, 0, [TimeSpan]::Zero)
        $entryStream = $entry.Open()
        try {
            $bytes = [IO.File]::ReadAllBytes($sourceFile.FullName)
            $entryStream.Write($bytes, 0, $bytes.Length)
        } finally { $entryStream.Dispose() }
    }
} finally {
    $archive.Dispose()
    $stream.Dispose()
}
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
[IO.File]::WriteAllText($archivePath + '.sha256', $hash + '  ' + $OutputName + "`n")
Write-Output ('Built ' + $archivePath)
Write-Output ('Bytes: ' + (Get-Item -LiteralPath $archivePath).Length)
Write-Output ('SHA256: ' + $hash)
