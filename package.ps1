# Builds dist\HammerSounds-<version>.zip (version read from HammerSounds.toc).
# The zip contains a single top-level HammerSounds folder, as CurseForge expects.
# Entries are written with forward slashes: Windows PowerShell 5.1's
# Compress-Archive writes backslashes, which some unzip tools mishandle.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = $PSScriptRoot
$addon = Join-Path $root "HammerSounds"
$toc = Get-Content (Join-Path $addon "HammerSounds.toc")
$version = ($toc | Where-Object { $_ -match '^## Version:\s*(.+)$' } | ForEach-Object { $Matches[1].Trim() }) | Select-Object -First 1
if (-not $version) { throw "No '## Version:' line in HammerSounds.toc" }

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$zipPath = Join-Path $dist "HammerSounds-$version.zip"
if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem $addon -Recurse -File | ForEach-Object {
        $rel = "HammerSounds/" + $_.FullName.Substring($addon.Length + 1).Replace('\', '/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
    }
} finally {
    $zip.Dispose()
}
"Built $zipPath ($([math]::Round((Get-Item $zipPath).Length / 1KB)) KB)"
