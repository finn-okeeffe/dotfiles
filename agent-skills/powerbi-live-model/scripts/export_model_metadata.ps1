param(
    [Parameter(Mandatory = $true)]
    [string]$Port,

    [string]$Catalog,

    [Parameter(Mandatory = $true)]
    [string]$OutPath
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
    $tables = Invoke-AdomdRows $conn "SELECT [ID], [Name], [IsHidden] FROM `$SYSTEM.TMSCHEMA_TABLES"
    $tableById = @{}
    foreach ($table in $tables) {
        $tableById[[string]$table.ID] = [string]$table.Name
    }

    $measures = Invoke-AdomdRows $conn @"
SELECT
    [ID],
    [Name],
    [TableID],
    [Description],
    [Expression],
    [FormatString],
    [DataType],
    [IsHidden],
    [DisplayFolder]
FROM `$SYSTEM.TMSCHEMA_MEASURES
"@

    $columns = Invoke-AdomdRows $conn @"
SELECT
    [ID],
    [ExplicitName],
    [InferredName],
    [TableID],
    [ExplicitDataType],
    [InferredDataType],
    [FormatString],
    [IsHidden],
    [SummarizeBy],
    [Type],
    [SourceColumn],
    [DisplayFolder]
FROM `$SYSTEM.TMSCHEMA_COLUMNS
"@

    $dependencies = Invoke-AdomdRows $conn @"
SELECT
    [OBJECT_TYPE],
    [TABLE],
    [OBJECT],
    [REFERENCED_OBJECT_TYPE],
    [REFERENCED_TABLE],
    [REFERENCED_OBJECT]
FROM `$SYSTEM.DISCOVER_CALC_DEPENDENCY
"@

    $measureRows = foreach ($measure in $measures) {
        [pscustomobject]@{
            ID = $measure.ID
            Name = $measure.Name
            Table = $tableById[[string]$measure.TableID]
            Description = $measure.Description
            Expression = $measure.Expression
            FormatString = $measure.FormatString
            DataType = $measure.DataType
            IsHidden = $measure.IsHidden
            DisplayFolder = $measure.DisplayFolder
            UsesFormatFunction = ([string]$measure.Expression) -match '\bFORMAT\s*\('
        }
    }

    $columnRows = foreach ($column in $columns) {
        $name = if ($column.ExplicitName) { $column.ExplicitName } else { $column.InferredName }
        [pscustomobject]@{
            ID = $column.ID
            Name = $name
            Table = $tableById[[string]$column.TableID]
            DataType = if ($column.ExplicitDataType) { $column.ExplicitDataType } else { $column.InferredDataType }
            ExplicitDataType = $column.ExplicitDataType
            InferredDataType = $column.InferredDataType
            FormatString = $column.FormatString
            IsHidden = $column.IsHidden
            SummarizeBy = $column.SummarizeBy
            Type = $column.Type
            SourceColumn = $column.SourceColumn
            DisplayFolder = $column.DisplayFolder
        }
    }

    $result = [pscustomobject]@{
        Port = $Port
        Catalog = $Catalog
        ExtractedAt = (Get-Date).ToString("s")
        Tables = $tables
        Measures = $measureRows
        Columns = $columnRows
        Dependencies = $dependencies
    }

    $dir = Split-Path -Parent $OutPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutPath -Encoding UTF8

    [pscustomobject]@{
        Catalog = $Catalog
        MeasureCount = $measureRows.Count
        VisibleMeasureCount = @($measureRows | Where-Object { -not $_.IsHidden }).Count
        ColumnCount = $columnRows.Count
        DependencyCount = $dependencies.Count
        OutPath = $OutPath
    } | ConvertTo-Json -Depth 4
}
finally {
    $conn.Close()
}
