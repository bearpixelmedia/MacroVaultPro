# Uploads the built archive to the CurseForge project with the author Upload API.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/upload-curseforge.ps1 -DryRun
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/upload-curseforge.ps1 -Upload
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/upload-curseforge.ps1 -VerifyId 9810929
#
# Publishing is opt-in here too: a run without -Upload resolves the archive and
# changelog, runs the duplicate check and stops, so nothing reaches CurseForge
# because a flag was forgotten. -Upload sends it; -DryRun also prints the
# metadata. -VerifyId is unaffected - it never uploads anything.
#
# Needs an author API token: the project page has an "API Tokens" page, where a
# token can be generated. Put it in .curseforge-token at the repository root
# (gitignored) or in the CURSEFORGE_TOKEN environment variable. The token is
# read and used, never printed.
#
# -VerifyId checks one file id and exits before the archive, changelog or token
# are needed. It prints whether that id is live, pending or blocked on the site,
# so the check an upload prints can be exercised without uploading another file.
# It exits 0 only after the published bytes matched a build in dist/; 1 means they
# differ or there is nothing to compare with, and 2 means the id could not be
# checked at all. "Could not check" is not a pass: an unreadable record used to
# return 0, which reads as a verified file to anything that trusts the exit code.
#
# This covers files only: POST /api/projects/<id>/upload-file with a metadata
# field and the archive. The project description, gallery and settings live on
# the website - media-kit/ has the paste-ready columns for those, because the
# API has no endpoint for them.
#
# -DryRun resolves the game version and prints the metadata without uploading,
# so a release can be checked before it becomes public. The upload itself needs
# -Upload; without it the script stops after the checks, and does not even need
# a token, because it is not going to authenticate to anything.

param(
	[int]$ProjectId = 1827533,
	[string]$Zip,
	[string]$Changelog,
	[ValidateSet("release", "beta", "alpha")]
	[string]$ReleaseType = "release",
	[string]$GameVersion = "1.60.1",
	# Forever's version type. Several flavors ship a version called "1.60.1", and
	# tagging the file with the wrong one is how an addon ends up hidden as
	# incompatible with the client it was built for.
	[int]$GameVersionTypeId = 88568,
	[string]$DisplayName,
	# Used only to build the public file URL the upload is checked against.
	[string]$Slug = "macrovaultpro",
	[string]$TokenFile,
	# Optional path that receives the new file id. A caller that chains this script
	# (release.ps1) reads the id from there instead of parsing console text.
	[string]$IdFile,
	# Check one file id and exit, without uploading anything: -VerifyId 9810929
	[int]$VerifyId,
	# The only way to publish. A bare run checks and stops.
	[switch]$Upload,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# The changelog is UTF-8 and full of em dashes. Windows PowerShell 5.1 reads
# UTF-8 without a BOM as ANSI unless told otherwise, which turns every dash into
# mojibake in the uploaded text, so the encoding is set on both ends.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$root  = Split-Path -Parent $PSScriptRoot
$addon = "MacroVaultPro"
$toc   = Join-Path (Join-Path $root $addon) "$addon.toc"

# The API's paths are relative to the site the project is on: the docs say so
# plainly, and their own WoW examples read wow.curseforge.com/api/projects/...
# One host, no fallbacks - a second host would only hide a wrong URL.
$base = "https://wow.curseforge.com"

# The file's own page cannot be used as the check: Cloudflare answers 403 to any
# non-browser client, for a live file as readily as a missing one, so a page probe
# would always read as "blocked". The site's JSON endpoint is not gated the same
# way and does discriminate - it returns the file record with its name, size and
# approval status once the file is public, and {"data":null} for an id that is
# pending, rejected or unknown. -VerifyId runs this on its own, without uploading.
function Get-FileStatus {
	param([int]$Id)

	$pageUrl  = "https://www.curseforge.com/wow/addons/$Slug/files/$Id"
	$probeUrl = "https://www.curseforge.com/api/v1/mods/$ProjectId/files/$Id"
	$code     = 0
	$record   = $null
	$probe    = New-Object System.Net.Http.HttpClient
	$probe.Timeout = [TimeSpan]::FromSeconds(30)
	$probe.DefaultRequestHeaders.Add("User-Agent",
		"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
	$probe.DefaultRequestHeaders.Add("Accept", "application/json")
	try {
		$page = $probe.GetAsync($probeUrl).Result
		$code = [int]$page.StatusCode
		if ($code -eq 200) {
			$record = ($page.Content.ReadAsStringAsync().Result | ConvertFrom-Json).data
		}
	} catch {
		$code = 0
	} finally { $probe.Dispose() }

	if ($code -eq 200 -and $record -and $record.fileName) {
		$listedSize = [long]0
		$sizeText = if ([long]::TryParse([string]$record.fileLength, [ref]$listedSize)) { "{0:N0} bytes" -f $listedSize } else { "size not listed" }
		if ([int]$record.status -eq 4) {
			$text = "live - {0}  {1}  file id {2}" -f $record.fileName, $sizeText, $record.id
		} else {
			$text = "pending - {0} is on the site but approval status is {1}, so it is not public yet" -f $record.fileName, $record.status
		}
	} elseif ($code -eq 200) {
		$text = "pending - the site has no public record for file id {0} yet (review, or rejected)" -f $Id
	} elseif ($code -eq 403) {
		$text = "blocked - the site refused the check (HTTP 403), so the upload is unconfirmed either way"
	} else {
		$text = "unknown - HTTP $code from $probeUrl"
	}

	[pscustomobject]@{ Id = $Id; Text = $text; PageUrl = $pageUrl; Record = $record }
}

if ($VerifyId) {
	$checked = Get-FileStatus -Id $VerifyId
	"file id:      $VerifyId"
	"status:       $($checked.Text)"
	"file page:    $($checked.PageUrl)"

	$record = $checked.Record
	if (-not $record -or -not $record.fileName) {
		"archive:      not checked - the site has no public record for this id"
		"verdict:      UNVERIFIED - no bytes were hashed, so this is not a pass. Re-run once the file is public."
		exit 2
	}

	# The CDN path is mechanical: the id split at its last three digits, then the name
	# the site reports. It is the only route that serves the bytes to a script, because
	# /wow/addons/<slug>/download/<id> answers 403 to anything but a browser.
	$chunkA = [int][math]::Floor($VerifyId / 1000)
	$chunkB = $VerifyId % 1000
	$archiveUrl = "https://mediafilez.forgecdn.net/files/$chunkA/$chunkB/$($record.fileName)"
	$localPath  = Join-Path $root ("dist\" + $record.fileName)
	"archive url:  $archiveUrl"

	$exitCode = 0
	$temp = $null
	try {
		$get = New-Object System.Net.Http.HttpClient
		$get.Timeout = [TimeSpan]::FromMinutes(3)
		$get.DefaultRequestHeaders.Add("User-Agent",
			"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
		try {
			$download = $get.GetAsync($archiveUrl).Result
			if (-not $download.IsSuccessStatusCode) {
				"archive:      download failed - HTTP $([int]$download.StatusCode) from the CDN"
				$exitCode = 1
			} else {
				$bytes = $download.Content.ReadAsByteArrayAsync().Result
				$temp = [System.IO.Path]::GetTempFileName()
				[System.IO.File]::WriteAllBytes($temp, $bytes)
				"live:         {0:N0} bytes" -f $bytes.Length
				if (-not (Test-Path $localPath)) {
					"local:        missing - no {0} in dist\" -f $record.fileName
					$exitCode = 1
				} else {
					"local:        {0:N0} bytes  {1}" -f (Get-Item $localPath).Length, $localPath
					$liveHash  = (Get-FileHash $temp      -Algorithm SHA256).Hash
					$localHash = (Get-FileHash $localPath -Algorithm SHA256).Hash
					"sha256 live:  $liveHash"
					"sha256 local: $localHash"
					if ($liveHash -eq $localHash) {
						"verdict:      IDENTICAL - the published archive is the build in dist\"
					} else {
						"verdict:      DIFFERENT - the published archive is not this build"
						$exitCode = 1
					}
				}
			}
		} finally { $get.Dispose() }
	} finally {
		if ($temp) { Remove-Item $temp -ErrorAction SilentlyContinue }
	}
	exit $exitCode
}

if (-not (Test-Path $toc)) { throw "Missing $toc" }
$match = Select-String -Path $toc -Pattern '^##\s*Version:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $match) { throw "No '## Version:' line in $toc" }
$version = $match.Matches[0].Groups[1].Value

if (-not $Zip) { $Zip = Join-Path $root "dist\$addon-$version.zip" }
if (-not (Test-Path $Zip)) { throw "No archive at $Zip - run tools/package.ps1 first" }
$Zip = (Resolve-Path $Zip).Path

if (-not $Changelog) { $Changelog = Join-Path $root "media-kit\changelog-$version.md" }
if (-not (Test-Path $Changelog)) { throw "No changelog at $Changelog - the upload API rejects an empty one" }
$changelogText = Get-Content $Changelog -Raw -Encoding UTF8
if (-not $changelogText.Trim()) { throw "$Changelog is empty - the upload API rejects an empty changelog" }

if (-not $DisplayName) { $DisplayName = "$addon $version" }

if (-not $TokenFile) {
	$TokenFile = Join-Path $root ".curseforge-token"
}
$token = $env:CURSEFORGE_TOKEN
if (-not $token -and (Test-Path $TokenFile)) {
	$token = [System.IO.File]::ReadAllText($TokenFile).Trim()
}
if ($token) { $token = $token.Trim() }
# Only a publish run needs to authenticate, so only a publish run demands a token.
if (-not $token -and -not $DryRun -and $Upload) {
	throw "No API token. Generate one at the project's API Tokens page and save it to $TokenFile (gitignored), or set CURSEFORGE_TOKEN."
}

# ---- resolve the game version --------------------------------------------
# The site wants the numeric id from /api/game/versions, not the label, and the
# Forever entries are not interchangeable with the mainline ones.
$gameVersionId = $null
if ($token) {
	$client = New-Object System.Net.Http.HttpClient
	$client.DefaultRequestHeaders.Add("X-Api-Token", $token)
	try {
		$response = $client.GetAsync("$base/api/game/versions").Result
		if (-not $response.IsSuccessStatusCode) {
			throw "Could not read $base/api/game/versions - HTTP $([int]$response.StatusCode). Check the token."
		}
		$versions = $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json

		$hit = @($versions | Where-Object { $_.name -eq $GameVersion -and $_.gameVersionTypeID -eq $GameVersionTypeId }) | Select-Object -First 1
		if (-not $hit) {
			# Fall back to the name, but say so: the file may land on another flavor.
			$hit = @($versions | Where-Object { $_.name -eq $GameVersion }) | Select-Object -First 1
			if ($hit) {
				"warning:   no version '$GameVersion' under type $GameVersionTypeId - using type $($hit.gameVersionTypeID)"
			}
		}
		if (-not $hit) {
			$near = @($versions | Where-Object { $_.name -like "$GameVersion*" } | Select-Object -First 6 |
				ForEach-Object { "$($_.name) (id $($_.id), type $($_.gameVersionTypeID))" })
			throw "No game version named '$GameVersion'. Closest: $($near -join '; ')"
		}
		$gameVersionId = 0
		$parsedVersionId = 0
		# A record with no usable id would otherwise drop gameVersions from the
		# metadata silently, and the file would upload with no client tag at all.
		if (-not [int]::TryParse([string]$hit.id, [ref]$parsedVersionId) -or $parsedVersionId -le 0) {
			throw "The game version '$GameVersion' has no usable id in the API response (id '$($hit.id)'), so the file cannot be tagged with the client it was built for."
		}
		$gameVersionId = $parsedVersionId
		"game version: {0}  id {1}  type {2}" -f $hit.name, $hit.id, $hit.gameVersionTypeID
	} finally { $client.Dispose() }
} else {
	"game version: {0}  (not resolved - no token)" -f $GameVersion
}

# ---- metadata ------------------------------------------------------------
$metadata = [ordered]@{
	changelog     = $changelogText.Trim()
	changelogType = "markdown"
	displayName   = $DisplayName
	releaseType   = $ReleaseType
}
if ($gameVersionId) { $metadata.gameVersions = @($gameVersionId) }
$json = $metadata | ConvertTo-Json -Depth 4

"archive:      {0}  ({1:N0} bytes)" -f $Zip, (Get-Item $Zip).Length
"changelog:    {0}  ({1:N0} characters, markdown)" -f $Changelog, $changelogText.Trim().Length
"display name: {0}" -f $DisplayName
"release type: {0}" -f $ReleaseType

# ---- duplicate guard ------------------------------------------------------
# A hash identifies a build; a name does not. The site's public record carries no
# hash, so the check fetches the published file and hashes it, and refuses the
# upload when those bytes are already there - a renamed archive is still a
# re-upload without changes under the fair-play rule. The file list gives
# fileLength for free and equal bytes always have equal length, so only published
# files of exactly this size are downloaded: usually none, at most a couple. A
# record whose fileLength is missing or not a number is a candidate as well,
# because an incomplete listing must not be able to hide a duplicate.
# The check runs on -DryRun too, so a release can be tested without uploading.
$sizeBytes = (Get-Item $Zip).Length
$localHash  = (Get-FileHash $Zip -Algorithm SHA256).Hash

function Get-PublishedHash {
	param([string]$Url)

	$temp = $null
	$get  = New-Object System.Net.Http.HttpClient
	$get.Timeout = [TimeSpan]::FromMinutes(3)
	$get.DefaultRequestHeaders.Add("User-Agent",
		"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
	try {
		$download = $get.GetAsync($Url).Result
		if (-not $download.IsSuccessStatusCode) { return $null }
		$bytes = $download.Content.ReadAsByteArrayAsync().Result
		$temp = [System.IO.Path]::GetTempFileName()
		[System.IO.File]::WriteAllBytes($temp, $bytes)
		return (Get-FileHash $temp -Algorithm SHA256).Hash
	} catch {
		return $null
	} finally {
		$get.Dispose()
		if ($temp) { Remove-Item $temp -ErrorAction SilentlyContinue }
	}
}
$published = @()
$listClient = New-Object System.Net.Http.HttpClient
$listClient.Timeout = [TimeSpan]::FromSeconds(30)
$listClient.DefaultRequestHeaders.Add("User-Agent",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
$listClient.DefaultRequestHeaders.Add("Accept", "application/json")
try {
	for ($index = 0; $index -lt 300; $index += 50) {
		$listUrl = "https://www.curseforge.com/api/v1/mods/$ProjectId/files?pageSize=50&index=$index"
		$listResponse = $listClient.GetAsync($listUrl).Result
		if (-not $listResponse.IsSuccessStatusCode) {
			throw "Could not read the project's file list: HTTP $([int]$listResponse.StatusCode) from $listUrl"
		}
		$page = @(($listResponse.Content.ReadAsStringAsync().Result | ConvertFrom-Json).data | Where-Object { $_ })
		if ($page.Count -eq 0) { break }
		$published += $page
		if ($page.Count -lt 50) { break }
	}
} finally { $listClient.Dispose() }

$duplicate  = $null
function Test-SizeCandidate {
	param($File)
	if (-not $File.fileName) { return $false }
	$length = [long]0
	# Unknown size: cannot be excluded by size, so it is fetched and hashed.
	if (-not [long]::TryParse([string]$File.fileLength, [ref]$length)) { return $true }
	return ($length -eq $sizeBytes)
}
$candidates = @($published | Where-Object { Test-SizeCandidate $_ })
foreach ($candidate in $candidates) {
	$candidateId = [int]$candidate.id
	$chunkA = [int][math]::Floor($candidateId / 1000)
	$chunkB = $candidateId % 1000
	$archiveUrl = "https://mediafilez.forgecdn.net/files/$chunkA/$chunkB/$($candidate.fileName)"
	$listedSize = [long]0
	$sizeText = if ([long]::TryParse([string]$candidate.fileLength, [ref]$listedSize)) {
		"{0:N0} bytes" -f $listedSize
	} else {
		"size not listed"
	}
	"checking:     file id {0}  {1}  {2}" -f $candidateId, $candidate.fileName, $sizeText
	$publishedHash = Get-PublishedHash -Url $archiveUrl
	if (-not $publishedHash) {
		throw "Refusing to upload: published file id $candidateId ($sizeText) could not be downloaded from $archiveUrl, so it cannot be ruled out as a duplicate of this archive. Retry, or check it with -VerifyId $candidateId."
	}
	if ($publishedHash -eq $localHash) { $duplicate = $candidate; break }
}
if ($duplicate) {
	throw ("Refusing to upload: file id {0} ({1}) is byte-for-byte this archive - sha256 {2}. Renaming a build does not make it a new one; bump the version for real changes, or check the file with -VerifyId {0}." -f $duplicate.id, $duplicate.fileName, $localHash)
}
if ($candidates.Count -eq 0) {
	"duplicate:    none - no published file has this archive's size ({0:N0} bytes)" -f $sizeBytes
} else {
	"duplicate:    none - {0} published file(s) of this size or of unlisted size hashed, none matched $localHash" -f $candidates.Count
}

if ($DryRun) {
	"--- metadata (dry run, nothing uploaded) ---"
	$json
	exit 0
}

# Publishing is opt-in. This script used to upload on every run that did not pass
# -DryRun, which made "check the archive" and "publish it" the same command with
# one word between them; a release went up by accident that way.
if (-not $Upload) {
	"upload:       skipped - nothing was sent to CurseForge. Re-run with -Upload to publish this archive."
	exit 0
}

# An untagged file is not a smaller upload, it is one the client may hide as
# incompatible, so a version id that never resolved stops the upload here.
if (-not $gameVersionId) {
	throw "No game version id was resolved, so this file would upload with no client tag. Check the token and the -GameVersion/-GameVersionTypeId pair."
}

# ---- upload --------------------------------------------------------------
# multipart/form-data with "metadata" (JSON) and "file" (the archive), which is
# what POST /api/projects/<id>/upload-file expects.
$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromMinutes(5)
$client.DefaultRequestHeaders.Add("X-Api-Token", $token)
try {
	$body = New-Object System.Net.Http.MultipartFormDataContent
	$body.Add((New-Object System.Net.Http.StringContent($json, [System.Text.Encoding]::UTF8)), "metadata")
	# PowerShell unrolls an array passed to New-Object into separate arguments, so a
	# 38 KB archive became 38,510 constructor arguments. ::new() takes the array whole.
	$fileBytes = [System.IO.File]::ReadAllBytes($Zip)
	$fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)
	$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
	$body.Add($fileContent, "file", [System.IO.Path]::GetFileName($Zip))

	$url = "$base/api/projects/$ProjectId/upload-file"
	$response = $client.PostAsync($url, $body).Result
	$result = $response.Content.ReadAsStringAsync().Result
	if (-not $response.IsSuccessStatusCode) {
		throw "Upload failed: HTTP $([int]$response.StatusCode) from $url`: $result"
	}

	# The receipt is an id and nothing else - that is all this endpoint returns - so
	# it cannot say whether the file exists. The file's own page can: 200 means it
	# is public, 404 means the record exists but is not visible yet (uploads sit in
	# review), and 403 means the check itself was refused rather than the file
	# missing. None of those is treated as a failed upload, because the file was
	# already created; the point is to say which of the three it is.
	$parsed = $null
	try { $parsed = $result | ConvertFrom-Json } catch { }
	if (-not $parsed -or -not $parsed.id) {
		throw "Upload returned no file id. Raw response: $result"
	}
	"uploaded:     file id {0}" -f $parsed.id
	if ($IdFile) {
		[System.IO.File]::WriteAllText($IdFile, [string]$parsed.id)
	}

	$status = Get-FileStatus -Id ([int]$parsed.id)
	"status:       $($status.Text)"
	"file page:    $($status.PageUrl)"
	"project:      https://www.curseforge.com/wow/addons/$Slug/files"
} finally { $client.Dispose() }
