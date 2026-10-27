# Install Contour on Windows and link it to the configuration in this repository.
#
# Creating symbolic links needs Developer Mode (Settings > System > For developers) or an
# elevated PowerShell.
$ErrorActionPreference = 'Stop'

$configDir = Join-Path $env:LOCALAPPDATA 'contour'

# Install the latest release from GitHub unless that version or a newer one is already installed.
# The MSI replaces an older install. winget lags behind GitHub releases, so it is not used here.
$installed = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like 'Contour*' } |
    ForEach-Object { [version]$_.DisplayVersion } |
    Sort-Object -Descending | Select-Object -First 1
$release = Invoke-RestMethod 'https://api.github.com/repos/contour-terminal/contour/releases/latest'
$latest = [version]$release.tag_name.TrimStart('v')
if (-not $installed -or $installed -lt $latest) {
    if ($installed) { Write-Output "Upgrading Contour $installed to $latest." }
    $asset = $release.assets | Where-Object { $_.name -like '*-win64.msi' } | Select-Object -First 1
    $msi = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $msi
    Start-Process msiexec.exe -ArgumentList '/i', "`"$msi`"", '/passive' -Wait
}

# Link the shared config and the Windows profile overrides, moving aside any real files.
$links = @{
    (Join-Path $configDir 'contour.yml')       = Join-Path $PSScriptRoot 'contour.yml'
    (Join-Path $configDir 'profiles\main.yml') = Join-Path $PSScriptRoot 'windows-profile.yml'
}
foreach ($link in $links.Keys) {
    New-Item -ItemType Directory -Force (Split-Path $link) | Out-Null
    $item = Get-Item $link -ErrorAction SilentlyContinue
    if ($item -and -not $item.LinkType) { Move-Item $link "$link.backup" -Force }
    New-Item -ItemType SymbolicLink -Path $link -Target $links[$link] -Force | Out-Null
}

# Write the colour scheme once, then rotate the background at logon and every 30 minutes.
# conhost --headless runs the script without flashing a console window.
& (Join-Path $PSScriptRoot 'rotate-background.ps1')
$script = Join-Path $PSScriptRoot 'rotate-background.ps1'
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`""
$every30 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)
$atLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
Register-ScheduledTask -TaskName 'Contour background' -Action $action -Trigger $every30, $atLogon `
    -Principal $principal -Force `
    -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries) | Out-Null

Write-Output 'Contour is set up. Install Mononoki Nerd Font if it is not already installed.'
