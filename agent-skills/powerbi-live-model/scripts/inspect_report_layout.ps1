param(
    [Parameter(Mandatory = $true)]
    [string]$PBIXPath,

    [Parameter(Mandatory = $true)]
    [string]$OutPath
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-LiteralValue {
    param($Node)
    if ($null -eq $Node) {
        return $null
    }
    if ($Node.expr -and $Node.expr.Literal) {
        return [string]$Node.expr.Literal.Value
    }
    return ($Node | ConvertTo-Json -Depth 12 -Compress)
}

function Add-FieldUsage {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Page,
        [string]$VisualType,
        [string]$VisualName,
        [string]$Field,
        [string]$Source
    )
    if ([string]::IsNullOrWhiteSpace($Field)) {
        return
    }
    $List.Add([pscustomobject]@{
        Page = $Page
        VisualType = $VisualType
        VisualName = $VisualName
        Field = $Field
        Source = $Source
    })
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($PBIXPath)
try {
    $entry = $zip.GetEntry("Report/Layout")
    if (-not $entry) {
        throw "Report/Layout not found in PBIX."
    }

    $stream = $entry.Open()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::Unicode)
    $layoutText = $reader.ReadToEnd()
    $reader.Close()
    $layout = $layoutText | ConvertFrom-Json

    $pages = New-Object System.Collections.Generic.List[object]
    $visuals = New-Object System.Collections.Generic.List[object]
    $fieldUsage = New-Object System.Collections.Generic.List[object]
    $columnProperties = New-Object System.Collections.Generic.List[object]
    $objectProperties = New-Object System.Collections.Generic.List[object]

    foreach ($section in $layout.sections) {
        $pages.Add([pscustomobject]@{
            Page = $section.displayName
            Name = $section.name
            Ordinal = $section.ordinal
            Visibility = $section.visibility
            VisualCount = @($section.visualContainers).Count
        })

        foreach ($container in $section.visualContainers) {
            if (-not $container.config) {
                continue
            }

            $config = $container.config | ConvertFrom-Json
            $singleVisual = $config.singleVisual
            $visualType = $singleVisual.visualType
            $visualName = $config.name

            $visuals.Add([pscustomobject]@{
                Page = $section.displayName
                VisualType = $visualType
                VisualName = $visualName
                X = $container.x
                Y = $container.y
                Width = $container.width
                Height = $container.height
            })

            if ($singleVisual.projections) {
                $projectionText = $singleVisual.projections | ConvertTo-Json -Depth 40 -Compress
                foreach ($match in [regex]::Matches($projectionText, '"queryRef":"([^"]+)"')) {
                    Add-FieldUsage $fieldUsage $section.displayName $visualType $visualName $match.Groups[1].Value "projection"
                }
            }

            if ($singleVisual.columnProperties) {
                foreach ($prop in $singleVisual.columnProperties.PSObject.Properties) {
                    Add-FieldUsage $fieldUsage $section.displayName $visualType $visualName $prop.Name "columnProperties"
                    $columnProperties.Add([pscustomobject]@{
                        Page = $section.displayName
                        VisualType = $visualType
                        VisualName = $visualName
                        Field = $prop.Name
                        DisplayName = $prop.Value.displayName
                        FormatString = $prop.Value.formatString
                    })
                }
            }

            if ($singleVisual.objects) {
                foreach ($objectProp in $singleVisual.objects.PSObject.Properties) {
                    foreach ($instance in @($objectProp.Value)) {
                        if ($null -eq $instance.properties) {
                            continue
                        }
                        foreach ($property in $instance.properties.PSObject.Properties) {
                            if ($property.Name -match 'Format|Precision|DisplayUnits|Units') {
                                $objectProperties.Add([pscustomobject]@{
                                    Page = $section.displayName
                                    VisualType = $visualType
                                    VisualName = $visualName
                                    Object = $objectProp.Name
                                    Property = $property.Name
                                    Value = Get-LiteralValue $property.Value
                                })
                            }
                        }
                    }
                }
            }

            foreach ($blob in @($container.query, $container.dataTransforms)) {
                if (-not $blob) {
                    continue
                }
                foreach ($match in [regex]::Matches([string]$blob, '"queryRef":"([^"]+)"')) {
                    Add-FieldUsage $fieldUsage $section.displayName $visualType $visualName $match.Groups[1].Value "query"
                }
            }
        }
    }

    $result = [pscustomobject]@{
        PBIXPath = $PBIXPath
        ExtractedAt = (Get-Date).ToString("s")
        Pages = $pages
        Visuals = $visuals
        FieldUsage = $fieldUsage
        ColumnProperties = $columnProperties
        ObjectProperties = $objectProperties
    }

    $dir = Split-Path -Parent $OutPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutPath -Encoding UTF8

    [pscustomobject]@{
        PageCount = $pages.Count
        VisualCount = $visuals.Count
        FieldUsageCount = $fieldUsage.Count
        ColumnPropertyCount = $columnProperties.Count
        ObjectPropertyCount = $objectProperties.Count
        OutPath = $OutPath
    } | ConvertTo-Json -Depth 4
}
finally {
    $zip.Dispose()
}
