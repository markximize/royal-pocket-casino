# PURPOSE: Build two small source-only diagnostic archives using built-in .NET.
# CHANGE THIS FILE WHEN: Package names or included diagnostic files change.
# DO NOT PUT HERE: Runtime downloads, production builds or signing secrets.
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$experimentDirectory = $PSScriptRoot
$artifactDirectory = Join-Path $experimentDirectory 'artifacts'
$appDirectory = Join-Path $experimentDirectory 'app'
$repositoryDirectory = [System.IO.Path]::GetFullPath((Join-Path $experimentDirectory '..\..'))
New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null

function Add-ArchiveFile {
    param($Archive, [string]$Source, [string]$Name)
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $Archive, $Source, $Name, [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
}

# ## LOVE ARCHIVE (main.lua IS AT THE ROOT)
$loveArchivePath = Join-Path $artifactDirectory 'royal-pocket-compatibility.love'
$loveStream = [System.IO.File]::Open($loveArchivePath, [System.IO.FileMode]::Create)
$loveArchive = [System.IO.Compression.ZipArchive]::new($loveStream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($luaFile in (Get-ChildItem -LiteralPath $appDirectory -File -Filter '*.lua' | Sort-Object Name)) {
        Add-ArchiveFile $loveArchive $luaFile.FullName $luaFile.Name
    }
} finally {
    $loveArchive.Dispose()
    $loveStream.Dispose()
}

# ## HANDHELD TRANSFER ARCHIVE (NO RUNTIME OR EXISTING SAVES)
$handheldArchivePath = Join-Path $artifactDirectory 'royal-pocket-compatibility-rg35xx-h.zip'
$handheldStream = [System.IO.File]::Open($handheldArchivePath, [System.IO.FileMode]::Create)
$handheldArchive = [System.IO.Compression.ZipArchive]::new($handheldStream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Add-ArchiveFile $handheldArchive $loveArchivePath 'royalpocketcompatibility/compatibility.love'
    Add-ArchiveFile $handheldArchive (Join-Path $experimentDirectory 'launcher\Royal Pocket Casino Compatibility.sh') 'Royal Pocket Casino Compatibility.sh'
    Add-ArchiveFile $handheldArchive (Join-Path $experimentDirectory 'README.md') 'royalpocketcompatibility/README.md'
    Add-ArchiveFile $handheldArchive (Join-Path $experimentDirectory 'DEVICE_TEST.md') 'royalpocketcompatibility/DEVICE_TEST.md'
    Add-ArchiveFile $handheldArchive (Join-Path $experimentDirectory 'VERIFICATION.md') 'royalpocketcompatibility/VERIFICATION.md'
    Add-ArchiveFile $handheldArchive (Join-Path $repositoryDirectory 'THIRD_PARTY_NOTICES.md') 'royalpocketcompatibility/THIRD_PARTY_NOTICES.md'
    foreach ($notice in (Get-ChildItem -LiteralPath (Join-Path $experimentDirectory 'notices') -File | Sort-Object Name)) {
        Add-ArchiveFile $handheldArchive $notice.FullName ('royalpocketcompatibility/notices/' + $notice.Name)
    }
} finally {
    $handheldArchive.Dispose()
    $handheldStream.Dispose()
}

foreach ($archivePath in @($loveArchivePath, $handheldArchivePath)) {
    $archiveFile = Get-Item -LiteralPath $archivePath
    $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    Write-Output ('{0}: {1} bytes; SHA256 {2}' -f $archiveFile.Name, $archiveFile.Length, $archiveHash)
}
