# MacroVaultPro media kit renderer.
#
# Builds every asset in one run: the banner and four gallery panels from
# build-media-kit.html via headless Edge at their exact pixel size, then the
# avatar art at 1024, 400 and 64 px. The 64 px cut is also written into the
# addon as an uncompressed 32-bit TGA, because that is the file the client
# shows in the addon list (see ## IconTexture in MacroVaultPro.toc).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File media-kit/build/render.ps1
#
# Each capture opens the page with #banner or #card1..#card4, which hides the
# other tiles, so no cropping is involved.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$build = $PSScriptRoot
$kit   = Split-Path -Parent $build
$out   = Join-Path $kit "images"
$page  = Join-Path $kit "build-media-kit.html"
$media = Join-Path (Split-Path -Parent $kit) "MacroVaultPro\Media"

$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { $edge = "C:\Program Files\Microsoft\Edge\Application\msedge.exe" }
if (-not (Test-Path $edge)) { throw "Microsoft Edge not found; edit `$edge in this script." }
if (-not (Test-Path $page)) { throw "Missing $page" }
if (-not (Test-Path $out))  { New-Item -ItemType Directory -Path $out | Out-Null }

$uri = ([System.Uri]$page).AbsoluteUri
$shots = @(
	@{ id = "banner"; w = 1280; h = 400; file = "banner-1280x400.png" },
	@{ id = "card1";  w = 1280; h = 720; file = "gallery-01-macros.png" },
	@{ id = "card2";  w = 1280; h = 720; file = "gallery-02-library.png" },
	@{ id = "card3";  w = 1280; h = 720; file = "gallery-03-tools.png" },
	@{ id = "card4";  w = 1280; h = 720; file = "gallery-04-forever.png" }
)

foreach ($shot in $shots) {
	$target = Join-Path $out $shot.file
	if (Test-Path $target) { Remove-Item $target -Force }

	$profile = Join-Path $env:TEMP ("mvkit-" + [guid]::NewGuid().ToString("N"))
	$edgeArgs = @(
		"--headless=new",
		"--disable-gpu",
		"--hide-scrollbars",
		"--force-device-scale-factor=1",
		"--no-first-run",
		"--no-default-browser-check",
		"--virtual-time-budget=4000",
		"--user-data-dir=$profile",
		"--window-size=$($shot.w),$($shot.h)",
		"--screenshot=$target",
		"$uri#$($shot.id)"
	)

	# Edge writes its "bytes written" line to stderr; with ErrorActionPreference
	# at Stop that is treated as a failed command, so relax it for the call and
	# verify the capture with the file check below instead.
	$previous = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	& $edge @edgeArgs 2>&1 | Out-Null
	$ErrorActionPreference = $previous
	Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue
	if (-not (Test-Path $target)) { throw "Render failed for $($shot.id)" }
}

# ---- avatars and icon -----------------------------------------------------
# One crop-and-scale routine feeds all three sizes; the 64 px bitmap is saved
# twice, as the PNG preview and as the addon's TGA.
function New-Square {
	param($Source, [int]$Size)
	$side = [Math]::Min($Source.Width, $Source.Height)
	$sx = [int](($Source.Width - $side) / 2)
	$sy = [int](($Source.Height - $side) / 2)

	$bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
	$g.Clear([System.Drawing.Color]::Transparent)
	$g.DrawImage(
		$Source,
		(New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)),
		(New-Object System.Drawing.Rectangle($sx, $sy, $side, $side)),
		[System.Drawing.GraphicsUnit]::Pixel
	)
	$g.Dispose()
	return $bmp
}

function Save-Square {
	param($Source, [int]$Size, [string]$Path)
	$bmp = New-Square -Source $Source -Size $Size
	$bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}

# The client reads BLP and TGA, not PNG, so the icon is written as an
# uncompressed 32-bit TGA by hand.
function Save-Tga {
	param($Bitmap, [string]$Path)
	$w = $Bitmap.Width
	$h = $Bitmap.Height

	$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
	$locked = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$pixels = New-Object byte[] ($locked.Stride * $h)
	[System.Runtime.InteropServices.Marshal]::Copy($locked.Scan0, $pixels, 0, $pixels.Length)
	$stride = $locked.Stride
	$Bitmap.UnlockBits($locked)

	# Header: no ID, no palette, type 2 (uncompressed true-colour), 32 bpp,
	# descriptor 0x28 = 8 alpha bits with rows written top to bottom.
	$tga = New-Object System.Collections.Generic.List[byte]
	$tga.AddRange([byte[]]@(
		0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		($w -band 0xFF), (($w -shr 8) -band 0xFF),
		($h -band 0xFF), (($h -shr 8) -band 0xFF),
		32, 0x28
	))
	for ($y = 0; $y -lt $h; $y++) {
		$row = $y * $stride
		for ($x = 0; $x -lt $w; $x++) {
			$i = $row + $x * 4
			# LockBits hands back BGRA, which is exactly TGA's byte order.
			$tga.Add($pixels[$i])
			$tga.Add($pixels[$i + 1])
			$tga.Add($pixels[$i + 2])
			$tga.Add($pixels[$i + 3])
		}
	}
	[System.IO.File]::WriteAllBytes($Path, $tga.ToArray())
}

# Required, not optional: the addon's .toc points at the icon this script cuts,
# so a missing source has to fail here rather than ship a broken icon path.
$avatarSource = Join-Path $build "avatar-source.png"
if (-not (Test-Path $avatarSource)) { throw "Missing $avatarSource" }

$art = [System.Drawing.Image]::FromFile($avatarSource)
Save-Square -Source $art -Size 1024 -Path (Join-Path $out "avatar-1024.png")
Save-Square -Source $art -Size 400  -Path (Join-Path $out "avatar-400.png")

# The 64 px cut is saved twice: the PNG preview, and the addon's TGA icon.
$icon = New-Square -Source $art -Size 64
$icon.Save((Join-Path $out "icon-64.png"), [System.Drawing.Imaging.ImageFormat]::Png)
if (-not (Test-Path $media)) { New-Item -ItemType Directory -Path $media | Out-Null }
$iconPath = Join-Path $media "icon.tga"
Save-Tga -Bitmap $icon -Path $iconPath
$icon.Dispose()
$art.Dispose()

# ---- report --------------------------------------------------------------
Get-ChildItem $out -Filter *.png | Sort-Object Name | ForEach-Object {
	$img = [System.Drawing.Image]::FromFile($_.FullName)
	"{0,-26} {1,5} x {2,-5} {3,7:N0} KB" -f $_.Name, $img.Width, $img.Height, ($_.Length / 1KB)
	$img.Dispose()
}

# Read the TGA back so a bad header, a flipped origin or a short pixel block
# cannot pass silently.
if (-not (Test-Path $iconPath)) { throw "icon.tga was not written to $iconPath" }
$tga = [System.IO.File]::ReadAllBytes($iconPath)
$w = $tga[12] + ($tga[13] -shl 8)
$h = $tga[14] + ($tga[15] -shl 8)
if ($tga[2] -ne 2 -or $tga[16] -ne 32 -or $tga[17] -ne 0x28 -or $w -ne 64 -or $h -ne 64 -or $tga.Length -ne (18 + 64 * 64 * 4)) {
	throw "icon.tga is not a top-down 64x64 uncompressed 32-bit TGA"
}
"{0,-26} {1,5} x {2,-5} {3,7:N0} KB   {4}" -f "icon.tga", $w, $h, ($tga.Length / 1KB), $iconPath
