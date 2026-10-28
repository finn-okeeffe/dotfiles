# Shared profile for Windows PowerShell 5.1 and PowerShell 7. The per-user profiles load it
# with the snippet that powershell/setup-windows.ps1 adds, which sets $DotfilesDir first.
# Keep this file ASCII: Windows PowerShell reads it as UTF-8 only because the loader says so.

# Prompt: oh-my-posh, laid out like the Powerlevel10k prompt in zsh/p10k-gruvbox.zsh.
# Stop venv activation scripts from adding "(.venv)" in front of it; the theme shows the venv.
$env:VIRTUAL_ENV_DISABLE_PROMPT = 1
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $poshShell = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    oh-my-posh init $poshShell --config "$DotfilesDir\oh-my-posh\p10k-gruvbox.omp.json" |
        Invoke-Expression

    # oh-my-posh has no background jobs segment. It runs Set-PoshContext before each prompt,
    # and an alias takes precedence over its built-in function, so set POSH_JOBS from here.
    function Set-PoshJobs {
        $env:POSH_JOBS = if (Get-Job -State Running -ErrorAction SilentlyContinue) { 1 } else { $null }
    }
    New-Alias -Name Set-PoshContext -Value Set-PoshJobs -Scope Global -Force
}

$prj = "C:/projects"
$scarlatti = "C:/Users/FinnO'Keeffe/Scarlatti"

# Chocolatey tab completion for `choco`. See https://ch0.co/tab-completion.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module $ChocolateyProfile
}

# yazi, changing to the directory it was in on exit.
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
    }
    Remove-Item -Path $tmp
}

function ycli {y "C:/Users/FinnO'Keeffe/Scarlatti/Clients - Documents"}
function yint {y "C:/Users/FinnO'Keeffe/Scarlatti/Internal - Documents"}
