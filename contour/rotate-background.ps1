# Switch Contour to a random background from backgrounds\, different from the current one.
#
# Windows counterpart of rotate-background.sh. Contour caches a background by its path,
# so this writes the colour scheme (with the chosen background) to
# colorschemes\gruvbox-dark-hard.yml beside contour.yml, then bumps contour.yml's
# timestamp so live_config reloads it.
$ErrorActionPreference = 'Stop'

$configDir = Join-Path $env:LOCALAPPDATA 'contour'
$schemeFile = Join-Path $configDir 'colorschemes\gruvbox-dark-hard.yml'

$current = ''
if (Test-Path $schemeFile) {
    $match = Select-String -Path $schemeFile -Pattern "^    path: '(.*)'$"
    if ($match) { $current = $match.Matches[0].Groups[1].Value }
}

$images = @(Get-ChildItem (Join-Path $PSScriptRoot 'backgrounds') -Filter '*.png' | ForEach-Object FullName)
if ($images.Count -eq 0) { throw "No images in $PSScriptRoot\backgrounds" }
$candidates = @($images | Where-Object { $_ -ne $current })
if ($candidates.Count -eq 0) { $candidates = $images }
$choice = Get-Random -InputObject $candidates

$scheme = (Get-Content -Raw (Join-Path $PSScriptRoot 'gruvbox-dark-hard.yml')) + @"

# Written by rotate-background.ps1; images are pre-blended onto #1d2021.
background_image:
    path: '$choice'
    opacity: 1.0
    blur: false
"@
New-Item -ItemType Directory -Force (Split-Path $schemeFile) | Out-Null
$tmp = "$schemeFile.tmp"
[IO.File]::WriteAllText($tmp, $scheme)  # UTF-8 without a byte order mark
Move-Item -Force $tmp $schemeFile

# contour.yml is a link into this repository, so bump the target's timestamp, and write a
# stamp file in the config directory too: Windows reports changes per directory, and the
# link's directory would otherwise see nothing happen.
(Get-Item (Join-Path $PSScriptRoot 'contour.yml')).LastWriteTime = Get-Date
Set-Content -Path (Join-Path $configDir '.background-stamp') -Value (Get-Date -Format o)

Write-Output "Contour background: $(Split-Path -Leaf $choice)"
