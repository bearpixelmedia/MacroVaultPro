# Checks the CurseForge pre-flight list in media-kit/README.md before a release is
# packaged. Read-only: it never writes a file or calls an endpoint that changes
# anything, so release.ps1 can run it before it touches the version or the archive.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/preflight.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/preflight.ps1 -Version 1.0.1
#
# Exits 1 if any check fails. Each failure names the rule, because the point is to
# stop a packaging run, not to print a report nobody reads.

param(
	[string]$Version
)

$ErrorActionPreference = "Stop"

$root  = Split-Path -Parent $PSScriptRoot
$addon = "MacroVaultPro"
$toc   = Join-Path (Join-Path $root $addon) "$addon.toc"

$failed = 0
function Pass([string]$message) { "PASS  $message" }
function Fail([string]$message) { "FAIL  $message"; $script:failed++ }

# ---- which version is being checked --------------------------------------
if (-not $Version) {
	if (-not (Test-Path $toc)) { Fail "no $toc, so the version cannot be read"; $Version = "" }
	else {
		$match = Select-String -Path $toc -Pattern '^##\s*Version:\s*(.+?)\s*$' | Select-Object -First 1
		if ($match) { $Version = $match.Matches[0].Groups[1].Value }
		else { Fail "no '## Version:' line in $toc"; $Version = "" }
	}
}

# ---- avatar --------------------------------------------------------------
# The site asks for 400x400 and has a known bug with webp, so the bytes are read
# rather than trusted from the file extension: a renamed JPEG fails here.
$avatar = Join-Path $root "media-kit\images\avatar-400.png"
if (-not (Test-Path $avatar)) {
	Fail "media-kit/images/avatar-400.png is missing"
} else {
	$head = [System.IO.File]::ReadAllBytes($avatar)
	$isPng = $head.Length -gt 8 -and $head[0] -eq 0x89 -and $head[1] -eq 0x50 -and
		$head[2] -eq 0x4E -and $head[3] -eq 0x47
	if (-not $isPng) {
		Fail "avatar-400.png is not a PNG (webp and jpg are not accepted)"
	} else {
		Add-Type -AssemblyName System.Drawing
		$img = [System.Drawing.Image]::FromFile($avatar)
		try {
			if ($img.Width -ne 400 -or $img.Height -ne 400) {
				Fail ("avatar is {0}x{1}, the site requires 400x400" -f $img.Width, $img.Height)
			} else {
				Pass "avatar 400x400 PNG"
			}
		} finally { $img.Dispose() }
	}
}

# ---- name ----------------------------------------------------------------
# "Names should not contain game name, class name versions, file versions".
$forbidden = @("wow", "world of warcraft", "worldofwarcraft", "classic", "retail", "forever")
$lower = $addon.ToLower()
$found = @($forbidden | Where-Object { $lower.Contains($_) })
if ($addon -match '\d') {
	Fail "'$addon' contains a number; the project name must not carry a version"
} elseif ($found.Count) {
	Fail ("'{0}' contains {1}; the game name belongs in the description and tags" -f $addon, ($found -join ", "))
} else {
	Pass "project name '$addon' has no game name or version"
}

# ---- changelog -----------------------------------------------------------
# Same section release.ps1 extracts; checked here so a missing section stops the
# run before the version is bumped.
if ($Version) {
	$notes = Join-Path $root "media-kit\release-notes.md"
	if (-not (Test-Path $notes)) {
		Fail "media-kit/release-notes.md is missing"
	} else {
		$notesText = [System.IO.File]::ReadAllText($notes)
		$pattern = '(?ms)^##\s+v?(\d+(?:\.\d+)*)[^\r\n]*\r?\n(.*?)(?=^##\s+v?\d|\z)'
		$section = $null
		foreach ($block in [regex]::Matches($notesText, $pattern)) {
			if ($block.Groups[1].Value -eq $Version) { $section = $block.Groups[2].Value.Trim(); break }
		}
		if (-not $section) {
			Fail "release-notes.md has no '## $Version' section"
		} else {
			$entries = @($section -split "`r?`n" | Where-Object { $_ -match '^\s*-\s' }).Count
			if ($entries -eq 0) { Fail "the '## $Version' section has no '- ' entries" }
			else { Pass "changelog for $Version, $entries entries" }
		}
	}
}

# ---- gallery disclosure --------------------------------------------------
# The panels are HTML renderings, so the description has to say they are not
# in-game screenshots. If real captures replace them, drop this check with them.
foreach ($file in @("curseforge-description.md", "curseforge-description.html")) {
	$path = Join-Path $root "media-kit\$file"
	if (-not (Test-Path $path)) {
		Fail "media-kit/$file is missing"
	} elseif (-not (Select-String -Path $path -Pattern 'not in-game screenshots' -Quiet)) {
		Fail "$file does not disclose that the gallery panels are not in-game screenshots"
	} else {
		Pass "gallery disclosure in $file"
	}
}

# ---- summary -------------------------------------------------------------
# "preferably no longer than 1 sentence", and not a copy of the description's
# opening line. Length and a full stop are what can be checked mechanically.
$listing = Join-Path $root "media-kit\curseforge-listing.md"
if (-not (Test-Path $listing)) {
	Fail "media-kit/curseforge-listing.md is missing"
} else {
	$listingText = [System.IO.File]::ReadAllText($listing)
	$block = [regex]::Match($listingText, '(?ms)^\*\*Summary[^\r\n]*\*\*\s*\r?\n\s*```\r?\n(.*?)\r?\n```')
	if (-not $block.Success) {
		Fail "curseforge-listing.md has no fenced summary line"
	} else {
		$summary = $block.Groups[1].Value.Trim()
		if ($summary.Length -gt 160) {
			Fail ("summary is {0} characters; one sentence, and the site shows it truncated" -f $summary.Length)
		} elseif ($summary -notmatch '\.$') {
			Fail "summary does not end in a full stop, so it is not one sentence"
		} else {
			Pass "summary, $($summary.Length) characters"
		}
	}
}

# ---- result --------------------------------------------------------------
""
if ($failed) {
	"preflight: $failed check(s) failed - nothing was packaged"
	exit 1
}
"preflight: all checks passed"
exit 0
