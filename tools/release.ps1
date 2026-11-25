# Cuts a release: bumps the version and build stamp, writes the changelog from
# the commits that made the release necessary, then packages, installs and
# uploads.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -DryRun
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Version 1.1.0 -NoUpload
#
# This exists because the version, the build stamp and the changelog were three
# things somebody had to remember, and forgetting them is invisible: the archive
# keeps the old version in its name, the upload keeps looking for a changelog
# file that was never written, and CurseForge keeps showing the previous release
# while the addon moves on.
#
# The changelog is what players read on the CurseForge file page, so it is not
# copied from commit subjects: "Wire OnDragStart/OnDragStop beside the press
# drags" is a sentence for whoever wrote it, not for whoever installs it. Each
# release takes its text from a '## <version>' section in
# media-kit/release-notes.md, or from -Notes. Git only decides whether anything
# changed, and supplies raw material when the section is missing.

param(
	[string]$Version,
	[string]$Notes,
	[int]$ProjectId = 1827533,
	[switch]$NoUpload,
	[switch]$Force,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root  = Split-Path -Parent $PSScriptRoot
$addon = "MacroVaultPro"
$src   = Join-Path $root $addon
$toc   = Join-Path $src "$addon.toc"
$core  = Join-Path $src "Core.lua"

if (-not (Test-Path $toc))  { throw "Missing $toc" }
if (-not (Test-Path $core)) { throw "Missing $core" }

$tocText  = [System.IO.File]::ReadAllText($toc)
$coreText = [System.IO.File]::ReadAllText($core)

$tocMatch = [regex]::Match($tocText, '(?m)^##\s*Version:[^\r\n]*')
if (-not $tocMatch.Success) { throw "No '## Version:' line in $toc" }
$current = [regex]::Match($tocMatch.Value, '([0-9]+(?:\.[0-9]+)*)').Groups[1].Value
if (-not $current) { throw "Could not read a version number from '$($tocMatch.Value)'" }

$stampMatch = [regex]::Match($coreText, 'MV\.BUILD\s*=\s*"([^"]*)"')
if (-not $stampMatch.Success) { throw "No MV.BUILD line in $core" }
$oldStamp = $stampMatch.Groups[1].Value

# ---- next version --------------------------------------------------------
if (-not $Version) {
	$parts = $current.Split(".")
	$parts[$parts.Count - 1] = [string]([int]$parts[$parts.Count - 1] + 1)
	$Version = $parts -join "."
}
if ($Version -notmatch '^[0-9]+(\.[0-9]+)*$') { throw "-Version '$Version' is not a dotted number" }
if ($Version -eq $current -and -not $Force) {
	throw "Version is already $current - pass -Version to choose another, or -Force to repackage it"
}

# ---- next build stamp ----------------------------------------------------
# Same shape the addon already uses: the date, plus a letter when more than one
# build lands in a day. /mvpro selftest prints this, so it must keep its shape.
$today = Get-Date -Format "yyyy-MM-dd"
if ($oldStamp -match "^$([regex]::Escape($today))([a-z])$") {
	$letter = [char]([int][char]$Matches[1] + 1)
	if ($letter -gt 'z') { throw "Build letter ran past z for $today" }
	$stamp = "$today$letter"
} else {
	$stamp = "${today}a"
}

# ---- changelog -----------------------------------------------------------
# The last commit that touched `## Version:` is the boundary: everything after
# it is what this release contains.
$since = (git -C $root log -1 --format=%H -G"^## Version:" -- "MacroVaultPro/$addon.toc" 2>$null)
if (-not $since) { $since = (git -C $root rev-list --max-parents=0 HEAD | Select-Object -Last 1) }
$range = "$since..HEAD"

$subjects = @(git -C $root log --no-merges --pretty=format:"- %s (%h)" $range -- "MacroVaultPro/" 2>$null)
if (-not $subjects.Count -and -not $Force) {
	throw "No commits have changed $addon/ since the last version change ($since) - nothing to release. Use -Force to repackage anyway."
}

$changelogPath = Join-Path $root "media-kit\changelog-$Version.md"

$notesPath   = Join-Path $root "media-kit\release-notes.md"
$notesSource = "media-kit/release-notes.md"
$section     = $null

if ($Notes) {
	$section     = $Notes.Trim()
	$notesSource = "-Notes"
} else {
	if (-not (Test-Path $notesPath)) {
		throw "Missing $notesPath. The changelog is what players read on CurseForge, so each release needs a '## $Version' section there, or pass -Notes."
	}
	$notesText = [System.IO.File]::ReadAllText($notesPath)
	# Only '## <version>' starts a section, so a section may carry '### Added'
	# or a '## Added' line without being cut in half.
	$pattern = '(?ms)^##\s+v?(\d+(?:\.\d+)*)[^\r\n]*\r?\n(.*?)(?=^##\s+v?\d|\z)'
	foreach ($block in [regex]::Matches($notesText, $pattern)) {
		if ($block.Groups[1].Value -eq $Version) {
			$section = $block.Groups[2].Value.Trim()
			break
		}
	}
	if (-not $section) {
		throw "No '## $Version' section in $notesPath. Those notes are what players read on CurseForge, so write them by hand. These commits are the raw material:`n  " + ($subjects -join "`n  ")
	}
}
if (-not $section) { throw "The notes for $Version are empty" }

# Lines are kept as written, indentation included, so multi-line bullets stay
# multi-line bullets in the rendered changelog.
$bodyLines  = @($section -split "`r?`n")
$entryCount = @($bodyLines | Where-Object { $_ -match '^\s*-\s' }).Count
if ($entryCount -eq 0) { throw "The notes for $Version have no '- ' entries - that is not a changelog" }

$lines = @(
	"# $addon $Version"
	""
	"For World of Warcraft: Forever (interface 16001), build $stamp."
	""
) + $bodyLines

$changelogText = ($lines -join "`n") + "`n"

# ---- report --------------------------------------------------------------
"version:   {0} -> {1}" -f $current, $Version
"build:     {0} -> {1}" -f $oldStamp, $stamp
"changelog: {0}  ({1} entries from {2})" -f $changelogPath, $entryCount, $notesSource

# ---- pre-flight ----------------------------------------------------------
# Runs before anything is written, and on -DryRun as well, so a dry run exercises
# the same hand-off a real release does instead of skipping it. A failed check
# leaves the version, the stamp and the changelog exactly as they were. The checks
# are the moderation list in media-kit/README.md: avatar, name, changelog, gallery
# disclosure, summary.
""
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "preflight.ps1") -Version $Version
if ($LASTEXITCODE -ne 0) {
	throw "preflight.ps1 failed - nothing was written or packaged"
}

if ($DryRun) {
	"--- changelog (dry run, nothing written) ---"
	$changelogText
	exit 0
}

# ---- write it ------------------------------------------------------------
# No BOM: these are Lua and .toc files, and the client reads them as bytes.
$utf8 = New-Object System.Text.UTF8Encoding($false)

$newToc = $tocText.Substring(0, $tocMatch.Index) + "## Version: $Version" + $tocText.Substring($tocMatch.Index + $tocMatch.Length)
[System.IO.File]::WriteAllText($toc, $newToc, $utf8)

$newCore = $coreText.Substring(0, $stampMatch.Index) + ('MV.BUILD         = "' + $stamp + '"') + $coreText.Substring($stampMatch.Index + $stampMatch.Length)
[System.IO.File]::WriteAllText($core, $newCore, $utf8)

New-Item -ItemType Directory -Path (Split-Path -Parent $changelogPath) -Force | Out-Null
[System.IO.File]::WriteAllText($changelogPath, $changelogText, $utf8)
"wrote:     $toc"
"wrote:     $core"
"wrote:     $changelogPath"

# ---- build, install, upload ---------------------------------------------
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "package.ps1")
if ($LASTEXITCODE -ne 0) { throw "package.ps1 failed" }

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "install.ps1")
if ($LASTEXITCODE -ne 0) { throw "install.ps1 failed" }

if ($NoUpload) {
	"upload:    skipped (-NoUpload)"
	exit 0
}
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "upload-curseforge.ps1") -ProjectId $ProjectId
if ($LASTEXITCODE -ne 0) { throw "upload failed - the archive and changelog are written, so this can be retried" }
