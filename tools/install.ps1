# Installs the built archive into the client's AddOns folder, and refuses to
# install anything that is not the build in this checkout.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/install.ps1 -AddOns "D:\World of Warcraft\_forever_\Interface\AddOns"
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/install.ps1 -Zip dist/MacroVaultPro-1.0.0.zip -NoBackup
#
# A stale folder in Interface\AddOns is invisible from the repository: the code
# is right, the archive is right, and the client loads a copy somebody extracted
# days ago. So this script proves what it installed, in this order:
#
#   * the archive matches the source tree byte for byte, which catches a zip
#     left over from an earlier edit and says to run tools/package.ps1;
#   * the archive has the addon folder as its root, exactly one .toc, and a
#     build stamp that matches MV.BUILD in the checkout;
#   * the destination folder is deleted before extracting, so a renamed or
#     removed file cannot survive as a stray;
#   * every installed file is hashed again and compared to the archive entry it
#     came from, and the .toc and stamp are re-read from what landed on disk.
#
# The previous install is copied to ..\_addon-archive\backups first, outside
# AddOns, where the client never looks.

param(
	[string]$AddOns = "D:\World of Warcraft\_forever_\Interface\AddOns",
	[string]$Zip,
	[switch]$NoBackup
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root    = Split-Path -Parent $PSScriptRoot
$addon   = "MacroVaultPro"
$src     = Join-Path $root $addon
$tocPath = Join-Path $src "$addon.toc"

if (-not (Test-Path $tocPath)) { throw "Missing $tocPath" }
if (-not (Test-Path $AddOns))  { throw "No AddOns folder at $AddOns" }

$match = Select-String -Path $tocPath -Pattern '^##\s*Version:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $match) { throw "No '## Version:' line in $tocPath" }
$version = $match.Matches[0].Groups[1].Value

if (-not $Zip) { $Zip = Join-Path $root "dist\$addon-$version.zip" }
if (-not (Test-Path $Zip)) { throw "No archive at $Zip - run tools/package.ps1 first" }
$Zip = (Resolve-Path $Zip).Path

# What this checkout says the build is. Everything below is compared to this,
# so "install the right build" means "install what the source currently holds".
$srcCore  = Join-Path $src "Core.lua"
$stampHit = Select-String -Path $srcCore -Pattern 'MV\.BUILD\s*=\s*"([^"]*)"' | Select-Object -First 1
if (-not $stampHit) { throw "No MV.BUILD line in $srcCore" }
$srcStamp = $stampHit.Matches[0].Groups[1].Value

$ifaceHit = Select-String -Path $tocPath -Pattern '^##\s*Interface:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $ifaceHit) { throw "No '## Interface:' line in $tocPath" }
$srcInterface = $ifaceHit.Matches[0].Groups[1].Value

# ---- read the archive ----------------------------------------------------
$archive = [System.IO.Compression.ZipFile]::OpenRead($Zip)
$entries = @{}
$zipToc  = $null
$zipCore = $null
try {
	foreach ($entry in $archive.Entries) {
		if ($entry.FullName.EndsWith("/")) { continue }
		$stream = $entry.Open()
		$sha    = [System.Security.Cryptography.SHA1]::Create()
		try { $hash = [System.BitConverter]::ToString($sha.ComputeHash($stream)).Replace("-", "").ToLower() }
		finally { $sha.Dispose(); $stream.Dispose() }
		$entries[$entry.FullName] = $hash

		if ($entry.FullName -eq "$addon/$addon.toc") {
			$reader = New-Object System.IO.StreamReader($entry.Open())
			try { $zipToc = $reader.ReadToEnd() } finally { $reader.Dispose() }
		}
		if ($entry.FullName -eq "$addon/Core.lua") {
			$reader = New-Object System.IO.StreamReader($entry.Open())
			try { $zipCore = $reader.ReadToEnd() } finally { $reader.Dispose() }
		}
	}
}
finally { $archive.Dispose() }

$badRoot = @($entries.Keys | Where-Object { -not $_.StartsWith("$addon/") })
if ($badRoot.Count) { throw "Archive entries outside $addon/: $($badRoot -join ', ')" }
if (-not $entries.ContainsKey("$addon/$addon.toc")) { throw "Archive is missing $addon/$addon.toc" }

# A second .toc is how a renamed addon ships both names and loads the old one.
$tocs = @($entries.Keys | Where-Object { $_ -match "^$addon/[^/]+\.toc$" })
if ($tocs.Count -ne 1) { throw "Archive has $($tocs.Count) .toc files: $($tocs -join ', ')" }

$zipStamp = if ($zipCore -and ($zipCore -match 'MV\.BUILD\s*=\s*"([^"]*)"')) { $Matches[1] } else { "" }
if ($zipStamp -ne $srcStamp) {
	throw "Archive build stamp '$zipStamp' is not the checkout's '$srcStamp' - run tools/package.ps1"
}
$zipIface = if ($zipToc -and ($zipToc -match '(?m)^##\s*Interface:\s*(.+?)\s*$')) { $Matches[1] } else { "" }
if ($zipIface -ne $srcInterface) {
	throw "Archive .toc interface '$zipIface' is not the checkout's '$srcInterface' - run tools/package.ps1"
}
if ($zipToc -notmatch '(?m)^##\s*Title:\s*MacroVaultPro\s*$') {
	throw "Archive .toc title is not MacroVaultPro - that is the pre-rename build"
}

# ---- archive must equal the source tree ---------------------------------
$srcFiles = @{}
Get-ChildItem $src -Recurse -File | ForEach-Object {
	$rel = $_.FullName.Substring($src.Length + 1).Replace([string][char]92, "/")
	$srcFiles["$addon/$rel"] = (Get-FileHash $_.FullName -Algorithm SHA1).Hash.ToLower()
}

$missing = @($srcFiles.Keys | Where-Object { -not $entries.ContainsKey($_) })
if ($missing.Count) {
	throw "Archive is older than the source tree, missing: $($missing -join ', ') - run tools/package.ps1"
}
$orphans = @($entries.Keys | Where-Object { -not $srcFiles.ContainsKey($_) })
if ($orphans.Count) {
	throw "Archive has files the source tree does not, stale build: $($orphans -join ', ') - run tools/package.ps1"
}
$differs = @($srcFiles.Keys | Where-Object { $srcFiles[$_] -ne $entries[$_] })
if ($differs.Count) {
	throw "Archive content differs from the source tree: $($differs -join ', ') - run tools/package.ps1"
}

# ---- back up and install -------------------------------------------------
$dest        = Join-Path $AddOns $addon
$installRoot = Split-Path -Parent (Split-Path -Parent $AddOns)
$archiveDir  = Join-Path $installRoot "_addon-archive"

# Reinstalling the same build is routine, so only keep a copy when the
# installed folder actually differs from what is about to replace it.
if ((Test-Path $dest) -and -not $NoBackup) {
	$already = @(Get-ChildItem $dest -Recurse -File).Count -eq $entries.Count
	if ($already) {
		foreach ($name in $entries.Keys) {
			$path = Join-Path $dest $name.Substring($addon.Length + 1)
			if (-not (Test-Path $path) -or ((Get-FileHash $path -Algorithm SHA1).Hash.ToLower() -ne $entries[$name])) {
				$already = $false
				break
			}
		}
	}

	if ($already) {
		"backup:    skipped, the installed folder is already this build"
	} else {
		$backup = Join-Path (Join-Path $archiveDir "backups") ("$addon-" + (Get-Date -Format "yyyy-MM-dd-HHmmss"))
		New-Item -ItemType Directory -Path $backup -Force | Out-Null
		Copy-Item (Join-Path $dest "*") $backup -Recurse -Force
		"backup:    $backup"
	}
}

# Replace, never merge: a stale file left behind loads as though it were part
# of this build.
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive -Path $Zip -DestinationPath $AddOns -Force

# ---- prove what landed on disk -------------------------------------------
$problems = @()
foreach ($name in $entries.Keys) {
	$path = Join-Path $dest $name.Substring($addon.Length + 1)
	if (-not (Test-Path $path)) { $problems += "missing after install: $name"; continue }
	$onDisk = (Get-FileHash $path -Algorithm SHA1).Hash.ToLower()
	if ($onDisk -ne $entries[$name]) { $problems += "hash differs after install: $name" }
}

Get-ChildItem $dest -Recurse -File | ForEach-Object {
	$rel = $_.FullName.Substring($dest.Length + 1).Replace([string][char]92, "/")
	if (-not $entries.ContainsKey("$addon/$rel")) { $problems += "installed but not in the archive: $rel" }
}

$installedTocs = @(Get-ChildItem $dest -Filter "*.toc" -File)
if ($installedTocs.Count -ne 1) { $problems += "installed folder has $($installedTocs.Count) .toc files" }
elseif ($installedTocs[0].Name -ne "$addon.toc") { $problems += "installed .toc is $($installedTocs[0].Name)" }

$installedCore  = Join-Path $dest "Core.lua"
$installedStamp = ""
if (Test-Path $installedCore) {
	$hit = Select-String -Path $installedCore -Pattern 'MV\.BUILD\s*=\s*"([^"]*)"' | Select-Object -First 1
	if ($hit) { $installedStamp = $hit.Matches[0].Groups[1].Value }
}
if ($installedStamp -ne $srcStamp) { $problems += "installed MV.BUILD is '$installedStamp', expected '$srcStamp'" }

if ($problems.Count) {
	throw ("Install did not verify:`n  " + ($problems -join "`n  "))
}

# ---- report --------------------------------------------------------------
$entries.Keys | Sort-Object | ForEach-Object { "{0,-42} {1}" -f $_, $entries[$_] }
"installed: {0}" -f $dest
"archive:   {0}  ({1:N0} bytes)" -f $Zip, (Get-Item $Zip).Length
"build:     MacroVaultPro {0}  [{1}]  interface {2}" -f $version, $installedStamp, $srcInterface
"verified:  {0} files, every hash matches the archive" -f $entries.Count

if (Get-Process -Name "Wow" -ErrorAction SilentlyContinue) {
	"note:      Wow.exe is running - /reload in game (or restart the client) to load this build"
}

# CurseForge keeps its own record of what it installed. If the record names
# this folder, the next scan can overwrite what was just installed.
$cf = Join-Path $env:APPDATA "CurseForge\agent\GameInstances\AddonGameInstance.json"
if (Test-Path $cf) {
	$pattern = '"foldername":"' + $addon + '"'
	if (Select-String -Path $cf -Pattern $pattern -SimpleMatch -Quiet) {
		"warning:   CurseForge lists $addon as an addon it manages here - it can overwrite this install"
	}
}
