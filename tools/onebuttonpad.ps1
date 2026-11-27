# Builds and installs One Button Pad.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/onebuttonpad.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/onebuttonpad.ps1 -NoInstall
#
# The version comes from ## Version: in the .toc, so the archive is always
# dist/OneButtonPad-<version>.zip with OneButtonPad/ as its root and "/" in every
# entry - the same two details tools/package.ps1 exists for.
#
# The install half does what tools/install.ps1 does for MacroVaultPro: it refuses
# an archive older than the source tree, replaces the destination folder instead of
# merging into it, and then hashes every installed file against its archive entry
# and re-reads OPB.BUILD from disk. A local test build is only useful if what the
# client loads is provably this checkout.

param(
	[string]$AddOns = "D:\World of Warcraft\_forever_\Interface\AddOns",
	[switch]$NoInstall
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root  = Split-Path -Parent $PSScriptRoot
$addon = "OneButtonPad"
$src   = Join-Path $root $addon
$toc   = Join-Path $src "$addon.toc"
$dist  = Join-Path $root "dist"

if (-not (Test-Path $toc)) { throw "Missing $toc" }

$match = Select-String -Path $toc -Pattern '^##\s*Version:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $match) { throw "No '## Version:' line in $toc" }
$version = $match.Matches[0].Groups[1].Value

$corePath = Join-Path $src "Core.lua"
$stampHit = Select-String -Path $corePath -Pattern 'OPB\.BUILD\s*=\s*"([^"]*)"' | Select-Object -First 1
if (-not $stampHit) { throw "No OPB.BUILD line in $corePath" }
$stamp = $stampHit.Matches[0].Groups[1].Value

# ---- package -------------------------------------------------------------
$zip = Join-Path $dist "$addon-$version.zip"
New-Item -ItemType Directory -Path $dist -Force | Out-Null

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

# ---- verify the archive --------------------------------------------------
$check = [System.IO.Compression.ZipFile]::OpenRead($zip)
$names = @($check.Entries | ForEach-Object { $_.FullName })
$hashes = @{}
foreach ($entry in $check.Entries) {
	$stream = $entry.Open()
	$sha = [System.Security.Cryptography.SHA1]::Create()
	try { $hashes[$entry.FullName] = [System.BitConverter]::ToString($sha.ComputeHash($stream)).Replace("-", "").ToLower() }
	finally { $sha.Dispose(); $stream.Dispose() }
}
$check.Dispose()

$badRoot = @($names | Where-Object { -not $_.StartsWith("$addon/") })
$badSep  = @($names | Where-Object { $_.Contains([string][char]92) })
if ($badRoot.Count) { throw "Entries outside $addon/: $($badRoot -join ', ')" }
if ($badSep.Count)  { throw "Entries with backslashes: $($badSep -join ', ')" }
if ($names -notcontains "$addon/$addon.toc") { throw "Archive is missing $addon/$addon.toc" }

$srcFiles = @{}
Get-ChildItem $src -Recurse -File | ForEach-Object {
	$rel = $_.FullName.Substring($src.Length + 1).Replace([string][char]92, "/")
	$srcFiles["$addon/$rel"] = (Get-FileHash $_.FullName -Algorithm SHA1).Hash.ToLower()
}
$differs = @($srcFiles.Keys | Where-Object { $hashes[$_] -ne $srcFiles[$_] })
if ($differs.Count) { throw "Archive does not match the source tree: $($differs -join ', ')" }

$names | Sort-Object | ForEach-Object { "{0,-38}" -f $_ }
"zip:       {0}  {1:N0} files, {2:N0} bytes" -f $zip, $names.Count, (Get-Item $zip).Length
"build:     $addon $version  [$stamp]  interface 16001"

if ($NoInstall) { return }

# ---- install -------------------------------------------------------------
if (-not (Test-Path $AddOns)) { throw "No AddOns folder at $AddOns" }
$dest = Join-Path $AddOns $addon

if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $AddOns -Force

$problems = @()
foreach ($name in $hashes.Keys) {
	$path = Join-Path $dest $name.Substring($addon.Length + 1)
	if (-not (Test-Path $path)) { $problems += "missing after install: $name"; continue }
	if ((Get-FileHash $path -Algorithm SHA1).Hash.ToLower() -ne $hashes[$name]) {
		$problems += "hash differs after install: $name"
	}
}
Get-ChildItem $dest -Recurse -File | ForEach-Object {
	$rel = $_.FullName.Substring($dest.Length + 1).Replace([string][char]92, "/")
	if (-not $hashes.ContainsKey("$addon/$rel")) { $problems += "installed but not in the archive: $rel" }
}

$installedToc = Join-Path $dest "$addon.toc"
if (-not (Test-Path $installedToc)) { $problems += "installed folder has no $addon.toc" }

$installedStamp = ""
if (Test-Path (Join-Path $dest "Core.lua")) {
	$hit = Select-String -Path (Join-Path $dest "Core.lua") -Pattern 'OPB\.BUILD\s*=\s*"([^"]*)"' | Select-Object -First 1
	if ($hit) { $installedStamp = $hit.Matches[0].Groups[1].Value }
}
if ($installedStamp -ne $stamp) { $problems += "installed OPB.BUILD is '$installedStamp', expected '$stamp'" }

if ($problems.Count) { throw ("Install did not verify:`n  " + ($problems -join "`n  ")) }

"installed: {0}" -f $dest
"verified:  {0} files, every hash matches the archive, stamp {1}" -f $hashes.Count, $installedStamp

if (Get-Process -Name "Wow" -ErrorAction SilentlyContinue) {
	"note:      Wow.exe is running - /reload in game to load this build"
}
