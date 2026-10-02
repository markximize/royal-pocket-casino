# PURPOSE: Assemble one source-only RG35XX H candidate with its launcher and instructions.
# CHANGE THIS FILE WHEN: Reviewed handheld contents or candidate name change.
# DO NOT PUT HERE: Runtime installation, firmware changes or public publishing.

param()
$ErrorActionPreference = 'Stop'
$repositoryDirectory = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'build.ps1') -OutputName 'royal-pocket-casino-v0.1-polish-test.love'
$archiveDirectory = Join-Path $repositoryDirectory 'artifacts'
$archivePath = Join-Path $archiveDirectory 'royal-pocket-casino-v0.1-polish-rg35xx-h-test.zip'
$stream = [IO.File]::Open($archivePath, [IO.FileMode]::Create)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    $files = @(
        @{ Source = 'packaging/rg35xx-h/Royal Pocket Casino.sh'; Target = 'ROMS/Ports/Royal Pocket Casino.sh' }
        @{ Source = 'artifacts/royal-pocket-casino-v0.1-polish-test.love'; Target = 'ports/royalpocketcasino/game.love' }
        @{ Source = 'docs/HANDHELD_TEST.md'; Target = 'ports/royalpocketcasino/INSTALL_AND_TEST.md' }
        @{ Source = 'docs/TRAINING_RULES.md'; Target = 'ports/royalpocketcasino/TRAINING_RULES.md' }
        @{ Source = 'docs/LEARNING_GUIDE.md'; Target = 'ports/royalpocketcasino/LEARNING_GUIDE.md' }
        @{ Source = 'docs/SESSION_COACH.md'; Target = 'ports/royalpocketcasino/SESSION_COACH.md' }
        @{ Source = 'docs/AUDIO_AND_BRANDING.md'; Target = 'ports/royalpocketcasino/AUDIO_AND_BRANDING.md' }
        @{ Source = 'THIRD_PARTY_NOTICES.md'; Target = 'ports/royalpocketcasino/THIRD_PARTY_NOTICES.md' }
    )
    foreach ($notice in Get-ChildItem -LiteralPath (Join-Path $repositoryDirectory 'notices') -File) {
        $files += @{ Source = 'notices/' + $notice.Name; Target = 'ports/royalpocketcasino/notices/' + $notice.Name }
    }
    foreach ($file in $files | Sort-Object Target) {
        $entry = $archive.CreateEntry($file.Target, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [DateTimeOffset]::new(2026, 10, 2, 0, 0, 0, [TimeSpan]::Zero)
        if ($file.Target.EndsWith('.sh')) {
            # Unix regular-file mode 0755; Wi-Fi upload permissions still need device verification.
            $entry.ExternalAttributes = -2115174400
        }
        $entryStream = $entry.Open()
        try {
            $bytes = [IO.File]::ReadAllBytes((Join-Path $repositoryDirectory $file.Source))
            $entryStream.Write($bytes, 0, $bytes.Length)
        } finally { $entryStream.Dispose() }
    }
} finally { $archive.Dispose(); $stream.Dispose() }
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
[IO.File]::WriteAllText($archivePath + '.sha256', $hash + '  ' + [IO.Path]::GetFileName($archivePath) + "`n")
Write-Output ('Handheld test candidate: ' + $archivePath)
Write-Output ('Bytes: ' + (Get-Item -LiteralPath $archivePath).Length)
Write-Output ('SHA256: ' + $hash)
