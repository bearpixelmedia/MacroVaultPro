# Uploads the built archive to the CurseForge project with the author Upload API.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/upload-curseforge.ps1 -DryRun
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/upload-curseforge.ps1
#
# Needs an author API token: the project page has an "API Tokens" page, where a
# token can be generated. Put it in .curseforge-token at the repository root
# (gitignored) or in the CURSEFORGE_TOKEN environment variable. The token is
# read and used, never printed.
#
# This covers files only: POST /api/projects/<id>/upload-file with a metadata
# field and the archive. The project description, gallery and settings live on
# the website - media-kit/ has the paste-ready columns for those, because the
# API has no endpoint for them.
#
# -DryRun resolves the game version and prints the metadata without uploading,
# so a release can be checked before it becomes public.

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
	[string]$TokenFile,
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
if (-not $token -and -not $DryRun) {
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
		$gameVersionId = $hit.id
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

if ($DryRun) {
	"--- metadata (dry run, nothing uploaded) ---"
	$json
	exit 0
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
	$fileContent = New-Object System.Net.Http.ByteArrayContent(@([System.IO.File]::ReadAllBytes($Zip)))
	$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
	$body.Add($fileContent, "file", [System.IO.Path]::GetFileName($Zip))

	$url = "$base/api/projects/$ProjectId/upload-file"
	$response = $client.PostAsync($url, $body).Result
	$result = $response.Content.ReadAsStringAsync().Result
	if (-not $response.IsSuccessStatusCode) {
		throw "Upload failed: HTTP $([int]$response.StatusCode) from $url`: $result"
	}

	try {
		$parsed = $result | ConvertFrom-Json
		"uploaded:     file id {0}  {1}" -f $parsed.id, $parsed.fileName
	} catch {
		"uploaded:     $result"
	}
	"project:      https://www.curseforge.com/wow/addons/macrovaultpro/files"
} finally { $client.Dispose() }
