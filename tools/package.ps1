# Builds the CurseForge upload for MacroVaultPro.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/package.ps1
#
# The version comes from ## Version: in the .toc, so the archive is always
# dist/MacroVaultPro-<version>.zip. Two details this script exists for:
#
#   * the archive root is the addon folder itself, because the client needs
#     Interface\AddOns\MacroVaultPro\MacroVaultPro.toc;
#   * entries use "/" separators, as the ZIP spec requires. .NET on Windows
#     writes "\" instead, and some unzippers keep that backslash as part of the
#     file name, which is how "the addon folder is missing" uploads happen.
#
# It also checks the finished archive: root folder, separators, the .toc, and
# that the icon the .toc points at is actually inside it.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root  = Split-Path -Parent $PSScriptRoot
$addon = "MacroVaultPro"
$src   = Join-Path $root $addon
$toc   = Join-Path $src "$addon.toc"
$dist  = Join-Path $root "dist"

if (-not (Test-Path $toc)) { throw "Missing $toc" }

$match = Select-String -Path $toc -Pattern '^##\s*Version:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $match) { throw "No '## Version:' line in $toc" }
$version = $match.Matches[0].Groups[1].Value

$zip = Join-Path $dist "$addon-$version.zip"
New-Item -ItemType Directory -Path $dist -Force | Out-Null
# Older archives stay: each one is named after its version, and the published one
# is the only thing upload-curseforge.ps1 -VerifyId can hash a live file against,
# so deleting it after the next build would throw away that proof.

$fs = [System.IO.File]::Create($zip)
$archive = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
Get-ChildItem $src -Recurse -File | Sort-Object FullName | ForEach-Object {
	$relative = $_.FullName.Substring($src.Length + 1).Replace([string][char]92, "/")
	$entry = $archive.CreateEntry("$addon/$relative", [System.IO.Compression.CompressionLevel]::Optimal)
	$stream = $entry.Open()
	$bytes = [System.IO.File]::ReadAllBytes($_.FullName)
	$stream.Write($bytes, 0, $bytes.Length)
	$stream.Dispose()
}
$archive.Dispose()
$fs.Dispose()

# ---- verify --------------------------------------------------------------
$check = [System.IO.Compression.ZipFile]::OpenRead($zip)
$names = @($check.Entries | ForEach-Object { $_.FullName })
$check.Dispose()

$badRoot   = @($names | Where-Object { -not $_.StartsWith("$addon/") })
$badSep    = @($names | Where-Object { $_.Contains([string][char]92) })
$hasToc    = $names -contains "$addon/$addon.toc"
if ($badRoot.Count) { throw "Entries outside $addon/: $($badRoot -join ', ')" }
if ($badSep.Count)  { throw "Entries with backslashes: $($badSep -join ', ')" }
if (-not $hasToc)   { throw "Archive is missing $addon/$addon.toc" }

# The .toc names the addon-list icon; a path that does not resolve ships a
# blank icon in the client.
# A .toc without the line is not "nothing to check": the archive would ship with
# no icon and the check would never say so.
$iconLine = Select-String -Path $toc -Pattern '^##\s*IconTexture:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $iconLine) { throw "No '## IconTexture:' line in $toc, so the archive's icon cannot be checked" }
$iconPath = $iconLine.Matches[0].Groups[1].Value
$relative = $iconPath -replace '^Interface[\\/]AddOns[\\/]', ''
$relative = $relative.Replace([string][char]92, "/")
if ($names -notcontains $relative) { throw "The .toc icon is not in the archive: $relative" }

# ---- report --------------------------------------------------------------
$names | ForEach-Object { "{0,-38}" -f $_ }
"zip: {0}  {1:N0} files, {2:N0} bytes" -f $zip, $names.Count, (Get-Item $zip).Length
