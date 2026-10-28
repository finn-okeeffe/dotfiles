# Install oh-my-posh and make the Windows PowerShell 5.1 and PowerShell 7 profiles load
# powershell/profile.ps1 from this repository.
$ErrorActionPreference = 'Stop'

$dotfiles = Split-Path $PSScriptRoot
$documents = [Environment]::GetFolderPath('MyDocuments')

if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    winget install --id JanDeDobbeleer.OhMyPosh --source winget --scope user `
        --accept-package-agreements --accept-source-agreements
}

# Execution policy refuses to dot-source an unsigned script from a \\wsl.localhost path, so
# the loader runs the file's text as a script block instead. Rerunning this script leaves a
# profile alone once it contains the marker line.
$marker = '# dotfiles: powershell/profile.ps1'
$loader = @"
$marker
`$DotfilesDir = '$($dotfiles -replace "'", "''")'
if (Test-Path "`$DotfilesDir\powershell\profile.ps1") {
    . ([scriptblock]::Create((Get-Content -Raw -Encoding UTF8 "`$DotfilesDir\powershell\profile.ps1")))
}
"@
foreach ($profilePath in "$documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
                         "$documents\PowerShell\Microsoft.PowerShell_profile.ps1") {
    New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
    if (-not (Test-Path $profilePath) -or -not (Select-String $profilePath -SimpleMatch $marker -Quiet)) {
        Add-Content -Path $profilePath -Value "`r`n$loader"
        Write-Output "Added the dotfiles loader to $profilePath."
    }
}

# OneDrive can turn modules under Documents into cloud-only placeholders, and PowerShell then
# fails to load them (PowerToys' CommandNotFound module reports Microsoft.WinGet.Client as not
# loaded). Pin the folder so OneDrive keeps every file in it downloaded.
$modules = "$documents\PowerShell\Modules"
if ($documents -like '*\OneDrive*' -and (Test-Path $modules)) {
    attrib +P -U $modules
    attrib +P -U /S /D "$modules\*"
}
