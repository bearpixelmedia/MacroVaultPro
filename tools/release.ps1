# Cuts a release: bumps the version and build stamp, writes the changelog from
# the commits that made the release necessary, then packages, installs and
# uploads.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -DryRun
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Version 1.1.0 -NoUpload -NoInstall
#
# MV.VERSION is bumped with the .toc: the addon prints that value on login and in
# /mvpro selftest, so a release that only renamed the archive left the addon
# reporting an older version than the file it came from.
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
	[switch]$NoInstall,
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

# The version the addon prints; it has to move with the .toc, or the login line
# names a build nobody can find.
$versionMatch = [regex]::Match($coreText, 'MV\.VERSION\s*=\s*"([^"]*)"')
if (-not $versionMatch.Success) { throw "No MV.VERSION line in $core" }
$oldCoreVersion = $versionMatch.Groups[1].Value

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
# A git that cannot answer must not read as "nothing changed": a failed command
# and an empty range both produce no lines, and -Force would carry on either way,
# so the exit code is checked before the output is believed.
$since = @(git -C $root log -1 --format=%H -G"^## Version:" -- "MacroVaultPro/$addon.toc" 2>$null)
if ($LASTEXITCODE -ne 0) {
	throw "git log failed (exit $LASTEXITCODE), so the last version change is unknown and this release's range cannot be built"
}
$since = ($since | Select-Object -First 1)
if (-not $since) {
	$roots = @(git -C $root rev-list --max-parents=0 HEAD 2>$null)
	if ($LASTEXITCODE -ne 0) {
		throw "git rev-list failed (exit $LASTEXITCODE), so the first commit is unknown and this release's range cannot be built"
	}
	$since = ($roots | Select-Object -Last 1)
	if (-not $since) {
		throw "git returned no first commit, so there is no history to compare against and what this release contains cannot be determined"
	}
}
$range = "$since..HEAD"

$subjects = @(git -C $root log --no-merges --pretty=format:"- %s (%h)" $range -- "MacroVaultPro/" 2>$null)
if ($LASTEXITCODE -ne 0) {
	throw "git log $range failed (exit $LASTEXITCODE), so the commits in this release are unknown - not empty"
}
if (-not $subjects.Count -and -not $Force) {
	throw "No commits have changed $addon/ since the last version change ($since) - nothing to release. Use -Force to repackage anyway."
}
if (-not $subjects.Count) {
	"commits:   git lists none in $range - continuing because -Force was given"
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
"addon:     MV.VERSION {0} -> {1}" -f $oldCoreVersion, $Version
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

# Only the quoted value is replaced, so the column alignment of both lines stays
# as it is in the file.
$newCore = [regex]::Replace($coreText, '(MV\.VERSION\s*=\s*)"[^"]*"', ('$1"' + $Version + '"'))
$newCore = [regex]::Replace($newCore, '(MV\.BUILD\s*=\s*)"[^"]*"', ('$1"' + $stamp + '"'))
[System.IO.File]::WriteAllText($core, $newCore, $utf8)

New-Item -ItemType Directory -Path (Split-Path -Parent $changelogPath) -Force | Out-Null
[System.IO.File]::WriteAllText($changelogPath, $changelogText, $utf8)
"wrote:     $toc"
"wrote:     $core"
"wrote:     $changelogPath"

# ---- build, install, upload ---------------------------------------------
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "package.ps1")
if ($LASTEXITCODE -ne 0) { throw "package.ps1 failed" }

if ($NoInstall) {
	"install:   skipped (-NoInstall)"
} else {
	& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "install.ps1")
	if ($LASTEXITCODE -ne 0) { throw "install.ps1 failed" }
}

if ($NoUpload) {
	"upload:    skipped (-NoUpload)"
	exit 0
}
$uploadScript = Join-Path $PSScriptRoot "upload-curseforge.ps1"
# The file id comes back through a file, not through the uploader's console text.
# Parsing formatted output would break silently if a line were reworded, and a
# regex that matches nothing has no way to tell "no id" from "new format". The
# uploader writes the id; reading it either succeeds or it does not.
$idFile = [System.IO.Path]::GetTempFileName()
try {
	& powershell -NoProfile -ExecutionPolicy Bypass -File $uploadScript -ProjectId $ProjectId -IdFile $idFile
	if ($LASTEXITCODE -ne 0) { throw "upload failed - the archive and changelog are written, so this can be retried" }
	# An empty temp file reads as $null, which used to fail on .Trim() instead of
	# on the missing id; the check below is the one that should say so.
	$rawId  = Get-Content -LiteralPath $idFile -Raw
	$fileId = if ($rawId) { $rawId.Trim() } else { "" }
	if ($fileId -notmatch '^\d+$') { throw "the upload did not write a file id, so the published archive cannot be verified" }

	# ---- verify the published bytes ---------------------------------------
	# The upload receipt is only an id. The one proof the site holds this build is to
	# fetch it back and compare hashes, so the release asks -VerifyId to do exactly
	# that and refuses to finish on anything but IDENTICAL. A file still in review has
	# no public record to hash, which is not proof either, so that stops here too with
	# the id to re-check once it is approved.
	""
	$verifyLog = & powershell -NoProfile -ExecutionPolicy Bypass -File $uploadScript -VerifyId $fileId 2>&1
	$verifyLog | ForEach-Object { "$_" }
	# 2 is "could not check" (no public record, or the site refused the probe),
	# which is not the same as a mismatch and must not be reported as one.
	if ($LASTEXITCODE -eq 2) {
		throw "file $fileId is uploaded but could not be verified - the site has no public record for it yet. Run tools/upload-curseforge.ps1 -VerifyId $fileId once it is approved; the release is not complete until that prints IDENTICAL."
	}
	if ($LASTEXITCODE -ne 0) {
		throw "the published file $fileId does not match dist\$addon-$Version.zip - the release is not complete"
	}
	if (-not (($verifyLog -join "`n") -match 'verdict:\s+IDENTICAL')) {
		throw "file $fileId is uploaded but has no public record yet, so its bytes could not be verified - run tools/upload-curseforge.ps1 -VerifyId $fileId once it is approved"
	}
	"verified:  published bytes match dist\$addon-$Version.zip"
} finally {
	Remove-Item -LiteralPath $idFile -ErrorAction SilentlyContinue
}
