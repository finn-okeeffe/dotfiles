param(
    [int]$ProcessId
)

$ErrorActionPreference = "Stop"

function Convert-PortText {
    param([string]$Text)
    return (($Text -replace "`0", "") -replace "\s", "")
}

function Get-Catalog {
    param([string]$Port)

    $adomd = "C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll"
    if (-not (Test-Path -LiteralPath $adomd)) {
        return $null
    }

    Add-Type -Path $adomd
    $conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection(
        "Provider=MSOLAP;Data Source=localhost:$Port;Integrated Security=SSPI;"
    )
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT [CATALOG_NAME] FROM `$SYSTEM.DBSCHEMA_CATALOGS"
        $reader = $cmd.ExecuteReader()
        try {
            if ($reader.Read()) {
                return [string]$reader.GetValue(0)
            }
            return $null
        }
        finally {
            $reader.Close()
        }
    }
    finally {
        $conn.Close()
    }
}

$desktopProcesses = Get-CimInstance Win32_Process -Filter "Name = 'PBIDesktop.exe'"
if ($ProcessId) {
    $desktopProcesses = $desktopProcesses | Where-Object { $_.ProcessId -eq $ProcessId }
}

$engineProcesses = Get-CimInstance Win32_Process -Filter "Name = 'msmdsrv.exe'"
$rows = foreach ($desktop in $desktopProcesses) {
    $pbixPath = $null
    if ($desktop.CommandLine -match 'PBIDesktop\.exe"\s+"([^"]+\.pbix)"') {
        $pbixPath = $Matches[1]
    }

    foreach ($engine in $engineProcesses) {
        $dataPath = $null
        if ($engine.CommandLine -match '-s\s+"([^"]+)"') {
            $dataPath = $Matches[1]
        }
        if (-not $dataPath) {
            continue
        }

        $workspace = if ($engine.CommandLine -match 'AnalysisServicesWorkspaces\\([^\\"]+)\\Data') { $Matches[1] } else { $null }
        $portPath = Join-Path $dataPath "msmdsrv.port.txt"
        $port = if (Test-Path -LiteralPath $portPath) { Convert-PortText (Get-Content -LiteralPath $portPath -Raw) } else { $null }
        $catalog = if ($port) { Get-Catalog $port } else { $null }

        [pscustomobject]@{
            PBIDesktopPid = $desktop.ProcessId
            PBIXPath = $pbixPath
            MsmdsrvPid = $engine.ProcessId
            Workspace = $workspace
            DataPath = $dataPath
            PortPath = $portPath
            Port = $port
            Catalog = $catalog
            PBIDesktopCommandLine = $desktop.CommandLine
            MsmdsrvCommandLine = $engine.CommandLine
        }
    }
}

$rows | ConvertTo-Json -Depth 5
