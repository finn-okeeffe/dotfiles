param(
    [Parameter(Mandatory = $true)]
    [string]$Port,

    [string]$Catalog,

    [Parameter(Mandatory = $true)]
    [string]$Query
)

$ErrorActionPreference = "Stop"
$adomd = "C:\Program Files\Microsoft.NET\ADOMD.NET\160\Microsoft.AnalysisServices.AdomdClient.dll"
Add-Type -Path $adomd

function Invoke-AdomdRows {
    param(
        [Microsoft.AnalysisServices.AdomdClient.AdomdConnection]$Connection,
        [string]$CommandText
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $CommandText
    $reader = $cmd.ExecuteReader()
    $rows = New-Object System.Collections.Generic.List[object]
    try {
        while ($reader.Read()) {
            $row = [ordered]@{}
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $name = $reader.GetName($i)
                $row[$name] = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
            }
            $rows.Add([pscustomobject]$row)
        }
    }
    finally {
        $reader.Close()
    }
    return $rows
}

if (-not $Catalog) {
    $serverConn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection(
        "Provider=MSOLAP;Data Source=localhost:$Port;Integrated Security=SSPI;"
    )
    $serverConn.Open()
    try {
        $catalogs = Invoke-AdomdRows $serverConn "SELECT [CATALOG_NAME] FROM `$SYSTEM.DBSCHEMA_CATALOGS"
        if ($catalogs.Count -eq 0) {
            throw "No catalog found on localhost:$Port"
        }
        $Catalog = [string]$catalogs[0].CATALOG_NAME
    }
    finally {
        $serverConn.Close()
    }
}

$conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection(
    "Provider=MSOLAP;Data Source=localhost:$Port;Initial Catalog=$Catalog;Integrated Security=SSPI;"
)
$conn.Open()
try {
    Invoke-AdomdRows $conn $Query | ConvertTo-Json -Depth 8
}
finally {
    $conn.Close()
}
