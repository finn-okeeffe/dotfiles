[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PresentationPath,

    [string]$OutputDirectory,

    [ValidateRange(320, 7680)]
    [int]$Width = 1600,

    [int]$Height = 0,

    [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

function Assert-NoActivePowerPoint {
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    do {
        $active = @(Get-Process -Name "POWERPNT" -ErrorAction SilentlyContinue)
        if ($active.Count -eq 0) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($active.Count -gt 0) {
        throw "Close PowerPoint before rendering so the helper cannot alter or quit an existing session."
    }
}

function Get-RenderDirectoryFingerprint {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $null }
    $parts = @(
        Get-ChildItem -LiteralPath $Path -Force |
            Sort-Object Name |
            ForEach-Object {
                $kind = $(if ($_.PSIsContainer) { "D" } else { "F" })
                "$kind|$($_.Name)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)"
            }
    )
    return $parts -join "`n"
}

function Assert-RenderDestinationUnchanged {
    param($Paths)

    $currentFingerprint = Get-RenderDirectoryFingerprint $Paths.Output
    if ($Paths.OutputExistedAtStart) {
        if ($null -eq $currentFingerprint -or $currentFingerprint -ne $Paths.OutputFingerprint) {
            throw "OutputDirectory changed while PowerPoint was rendering; refusing to replace it."
        }
    }
    elseif ($null -ne $currentFingerprint) {
        throw "OutputDirectory was created while PowerPoint was rendering; refusing to replace it."
    }
}

function Resolve-RenderPaths {
    param([string]$Presentation, [string]$Output)

    $presentationFullPath = [IO.Path]::GetFullPath($Presentation)
    if (-not (Test-Path -LiteralPath $presentationFullPath -PathType Leaf)) {
        throw "Presentation not found: $presentationFullPath"
    }
    if ([string]::IsNullOrWhiteSpace($Output)) {
        $Output = Join-Path ([IO.Path]::GetTempPath()) (
            "powerpoint-render-" + [guid]::NewGuid().ToString("N")
        )
    }
    $outputFullPath = [IO.Path]::GetFullPath($Output)
    $outputParent = [IO.Path]::GetDirectoryName($outputFullPath)
    if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
        throw "Output parent directory not found: $outputParent"
    }
    if ((Test-Path -LiteralPath $outputFullPath) -and
        -not (Test-Path -LiteralPath $outputFullPath -PathType Container)) {
        throw "OutputDirectory is not a directory: $outputFullPath"
    }
    return [pscustomobject]@{
        Presentation = $presentationFullPath
        Output = $outputFullPath
        Parent = $outputParent
        OutputExistedAtStart = Test-Path -LiteralPath $outputFullPath -PathType Container
        OutputFingerprint = Get-RenderDirectoryFingerprint $outputFullPath
    }
}

function Assert-RenderDirectorySafe {
    param([string]$Output, [bool]$AllowOverwrite)

    if (-not (Test-Path -LiteralPath $Output)) { return }
    $items = @(Get-ChildItem -LiteralPath $Output -Force)
    $unrelated = @(
        $items | Where-Object { $_.PSIsContainer -or $_.Name -notmatch '^slide-\d+\.png$' }
    )
    if ($unrelated.Count -gt 0) {
        throw "OutputDirectory contains files not created by this renderer. Use a fresh directory."
    }
    if ($items.Count -gt 0 -and -not $AllowOverwrite) {
        throw "OutputDirectory already contains slide renders. Pass -Overwrite to replace the complete render set."
    }
}

function Get-RenderHeight {
    param($Presentation, [int]$Width, [int]$RequestedHeight)

    if ($RequestedHeight -ne 0 -and ($RequestedHeight -lt 180 -or $RequestedHeight -gt 4320)) {
        throw "Height must be 0 (automatic) or between 180 and 4320 pixels."
    }
    $slideRatio = $Presentation.PageSetup.SlideWidth / $Presentation.PageSetup.SlideHeight
    $automaticHeight = [int][math]::Round($Width / $slideRatio)
    if ($RequestedHeight -eq 0) {
        if ($automaticHeight -lt 180 -or $automaticHeight -gt 4320) {
            throw "Automatic render height $automaticHeight is outside the supported 180–4320 pixel range. Reduce Width."
        }
        return $automaticHeight
    }

    $requestedRatio = $Width / [double]$RequestedHeight
    if ([math]::Abs(($requestedRatio / $slideRatio) - 1) -gt 0.01) {
        throw "Width and Height do not match the presentation aspect ratio. Omit Height to derive it automatically."
    }
    return $RequestedHeight
}

Assert-NoActivePowerPoint
$paths = Resolve-RenderPaths $PresentationPath $OutputDirectory
Assert-RenderDirectorySafe $paths.Output ([bool]$Overwrite)
$tempDirectory = Join-Path $paths.Parent (
    ".powerpoint-render-tmp-" + [guid]::NewGuid().ToString("N")
)
$backupDirectory = $null
$published = $false
$powerPoint = $null
$presentation = $null
try {
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    $powerPoint = New-Object -ComObject PowerPoint.Application
    $presentation = $powerPoint.Presentations.Open($paths.Presentation, $true, $false, $false)
    $renderHeight = Get-RenderHeight $presentation $Width $Height
    $slideCount = $presentation.Slides.Count
    $digits = [math]::Max(3, $slideCount.ToString().Length)
    $fileNames = @()
    for ($index = 1; $index -le $slideCount; $index++) {
        $fileName = "slide-" + $index.ToString("D$digits") + ".png"
        $fileNames += $fileName
        $presentation.Slides.Item($index).Export(
            (Join-Path $tempDirectory $fileName),
            "PNG",
            $Width,
            $renderHeight
        )
    }

    Assert-RenderDestinationUnchanged $paths
    if (Test-Path -LiteralPath $paths.Output) {
        $backupDirectory = Join-Path $paths.Parent (
            ".powerpoint-render-backup-" + [guid]::NewGuid().ToString("N")
        )
        Move-Item -LiteralPath $paths.Output -Destination $backupDirectory
    }
    Move-Item -LiteralPath $tempDirectory -Destination $paths.Output
    $published = $true
    if ($null -ne $backupDirectory) {
        Remove-Item -LiteralPath $backupDirectory -Recurse -Force
        $backupDirectory = $null
    }

    foreach ($fileName in $fileNames) {
        Write-Output (Join-Path $paths.Output $fileName)
    }
    Write-Output "slides=$slideCount"
    Write-Output "dimensions=${Width}x${renderHeight}"
    Write-Output "output_directory=$($paths.Output)"
}
catch {
    if (-not $published -and $null -ne $backupDirectory -and
        (Test-Path -LiteralPath $backupDirectory) -and
        -not (Test-Path -LiteralPath $paths.Output)) {
        Move-Item -LiteralPath $backupDirectory -Destination $paths.Output
        $backupDirectory = $null
    }
    throw
}
finally {
    if ($null -ne $presentation) { try { $presentation.Close() } catch {} }
    if ($null -ne $powerPoint) { try { $powerPoint.Quit() } catch {} }
    foreach ($comObject in @($presentation, $powerPoint)) {
        if ($null -ne $comObject -and [Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject)
        }
    }
    if (Test-Path -LiteralPath $tempDirectory) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
