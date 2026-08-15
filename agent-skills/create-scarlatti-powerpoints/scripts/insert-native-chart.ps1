[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 10000)]
    [int]$SlideNumber,

    [Parameter(Mandatory = $true)]
    [string]$SpecPath,

    [string]$ReplaceShapeName,

    [switch]$ShowOfficeWindows,

    [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

function Get-OptionalProperty {
    param($Object, [string]$Name, $Default)

    if ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]) {
        return $Object.$Name
    }
    return $Default
}

function Assert-NoActiveOfficeSessions {
    param([string[]]$ProcessNames)

    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    do {
        $active = @(Get-Process -Name $ProcessNames -ErrorAction SilentlyContinue)
        if ($active.Count -eq 0) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($active.Count -gt 0) {
        $names = ($active.ProcessName | Sort-Object -Unique) -join ", "
        throw "Close active Office applications before running this helper. Found: $names."
    }
}

function Get-Rgb {
    param([int]$Red, [int]$Green, [int]$Blue)

    return $Red + (256 * $Green) + (65536 * $Blue)
}

function Convert-HexToRgb {
    param([string]$Hex)

    if ($Hex -notmatch '^#[0-9A-Fa-f]{6}$') {
        throw "Invalid colour '$Hex'. Use #RRGGBB."
    }
    return Get-Rgb `
        ([Convert]::ToInt32($Hex.Substring(1, 2), 16)) `
        ([Convert]::ToInt32($Hex.Substring(3, 2), 16)) `
        ([Convert]::ToInt32($Hex.Substring(5, 2), 16))
}

function Get-ChartTypeConstant {
    param([string]$ChartType)

    $types = @{
        "line" = 4
        "clustered-column" = 51
        "stacked-column" = 52
        "clustered-bar" = 57
        "stacked-bar" = 58
        "pie" = 5
        "doughnut" = -4120
    }
    if (-not $types.ContainsKey($ChartType)) {
        throw "Unsupported chartType '$ChartType'."
    }
    return $types[$ChartType]
}

function Test-IsCircularChartType {
    param([string]$ChartType)

    return $ChartType -in @("pie", "doughnut")
}

function Get-ExcelColumnName {
    param([int]$ColumnNumber)

    $name = ""
    while ($ColumnNumber -gt 0) {
        $remainder = ($ColumnNumber - 1) % 26
        $name = [char](65 + $remainder) + $name
        $ColumnNumber = [math]::Floor(($ColumnNumber - 1) / 26)
    }
    return $name
}

function Get-SeriesColour {
    param($SeriesSpec, [int]$Index, [bool]$HasFocalSeries = $false)

    $explicitColour = Get-OptionalProperty $SeriesSpec "colour" $null
    if ($null -ne $explicitColour -and [string]$explicitColour -ne "") {
        return Convert-HexToRgb ([string]$explicitColour)
    }

    $role = ([string](Get-OptionalProperty $SeriesSpec "role" "")).ToLowerInvariant()
    $roles = @{
        "focal" = (Get-Rgb 228 129 63)
        "context" = (Get-Rgb 114 108 96)
        "positive" = (Get-Rgb 121 168 61)
        "negative" = (Get-Rgb 228 87 63)
    }
    if ($roles.ContainsKey($role)) {
        return $roles[$role]
    }

    $palette = @(
        (Get-Rgb 228 129 63),
        (Get-Rgb 27 153 139),
        (Get-Rgb 60 60 60),
        (Get-Rgb 23 126 137),
        (Get-Rgb 204 185 159),
        (Get-Rgb 231 185 83),
        (Get-Rgb 192 224 222),
        (Get-Rgb 8 76 97)
    )
    if ($HasFocalSeries) { $palette = $palette[1..($palette.Count - 1)] }
    return $palette[$Index % $palette.Count]
}

function Get-ContrastingTextColour {
    param([int]$BackgroundColour)

    $red = $BackgroundColour -band 255
    $green = ($BackgroundColour -shr 8) -band 255
    $blue = ($BackgroundColour -shr 16) -band 255
    $luminance = (0.299 * $red) + (0.587 * $green) + (0.114 * $blue)
    if ($luminance -ge 145) { return Get-Rgb 60 60 60 }
    return Get-Rgb 255 255 255
}

function Get-DashStyle {
    param([string]$Name)

    $styles = @{
        "solid" = 1
        "dot" = 3
        "dash" = 4
        "long-dash" = 7
    }
    $key = $Name.ToLowerInvariant()
    if (-not $styles.ContainsKey($key)) {
        throw "Unsupported dashStyle '$Name'."
    }
    return $styles[$key]
}

function Get-MarkerStyle {
    param([string]$Name)

    $styles = @{
        "none" = -4142
        "square" = 1
        "diamond" = 2
        "triangle" = 3
        "circle" = 8
    }
    $key = $Name.ToLowerInvariant()
    if (-not $styles.ContainsKey($key)) {
        throw "Unsupported markerStyle '$Name'."
    }
    return $styles[$key]
}

function Get-LabelPosition {
    param([string]$Name)

    $positions = @{
        "best-fit" = 5
        "above" = 0
        "below" = 1
        "left" = -4131
        "right" = -4152
        "centre" = -4108
        "inside-end" = 3
        "outside-end" = 2
    }
    $key = $Name.ToLowerInvariant()
    if (-not $positions.ContainsKey($key)) {
        throw "Unsupported labelPosition '$Name'."
    }
    return $positions[$key]
}

function Set-DataLabelFormat {
    param(
        $Label,
        $SeriesSpec,
        [int]$Colour,
        [string]$ChartType,
        [string]$DefaultNumberFormat
    )

    $showPercentage = [bool](Get-OptionalProperty $SeriesSpec "showPercentage" $false)
    $showValueDefault = -not $showPercentage
    $Label.ShowValue = [bool](Get-OptionalProperty $SeriesSpec "showValue" $showValueDefault)
    $Label.ShowCategoryName = [bool](Get-OptionalProperty $SeriesSpec "showCategoryName" $false)
    $Label.ShowSeriesName = [bool](Get-OptionalProperty $SeriesSpec "showSeriesName" $false)
    $Label.ShowPercentage = $showPercentage
    $positionName = [string](Get-OptionalProperty $SeriesSpec "labelPosition" "")
    # Keep PowerPoint's native placement when omitted. Some PowerPoint builds
    # also reject explicit best-fit placement for doughnut labels.
    if (-not [string]::IsNullOrWhiteSpace($positionName) -and
        -not ($ChartType -eq "doughnut" -and $positionName -eq "best-fit")) {
        $Label.Position = Get-LabelPosition $positionName
    }
    $Label.Font.Name = "Calibri Light"
    $Label.Font.Size = [double](Get-OptionalProperty $SeriesSpec "labelSize" 11)
    $useWhiteFill = Test-IsCircularChartType $ChartType
    $Label.Font.Bold = $(if ($useWhiteFill) { -1 } else { 0 })
    $Label.Font.Color = $Colour
    $Label.Format.Fill.Visible = $(if ($useWhiteFill) { -1 } else { 0 })
    if ($useWhiteFill) {
        $Label.Format.Fill.Solid() | Out-Null
        $Label.Format.Fill.ForeColor.RGB = Get-Rgb 255 255 255
        $Label.Format.Fill.Transparency = 0.1
    }
    $Label.Format.Line.Visible = 0
    $numberFormat = Get-OptionalProperty $SeriesSpec "numberFormat" $DefaultNumberFormat
    if ($null -ne $numberFormat -and [string]$numberFormat -ne "") {
        $Label.NumberFormat = [string]$numberFormat
    }
}

function Set-SeriesLabels {
    param($Series, $SeriesSpec, [int]$Colour, [string]$ChartType, [string]$DefaultNumberFormat)

    $mode = ([string](Get-OptionalProperty $SeriesSpec "dataLabels" "none")).ToLowerInvariant()
    if ($mode -notin @("none", "all", "last")) {
        throw "Unsupported dataLabels '$mode'."
    }
    if ($mode -eq "none") { return }

    $pointIndices = @()
    $values = @($SeriesSpec.values)
    for ($index = 0; $index -lt $values.Count; $index++) {
        if ($null -ne $values[$index]) { $pointIndices += ($index + 1) }
    }
    if ($pointIndices.Count -eq 0) { return }
    if ($mode -eq "last") { $pointIndices = @($pointIndices[-1]) }

    $isCircular = Test-IsCircularChartType $ChartType
    $positionName = ([string](Get-OptionalProperty $SeriesSpec "labelPosition" "")).ToLowerInvariant()
    $labelColour = if (-not $isCircular -and $positionName -in @("centre", "inside-end")) {
        Get-ContrastingTextColour $Colour
    }
    else {
        Get-Rgb 60 60 60
    }
    $labelText = Get-OptionalProperty $SeriesSpec "labelText" $null
    foreach ($pointIndex in $pointIndices) {
        $point = $Series.Points().Item($pointIndex)
        $point.ApplyDataLabels() | Out-Null
        $label = $point.DataLabel
        Set-DataLabelFormat `
            $label `
            $SeriesSpec `
            $labelColour `
            $ChartType `
            $DefaultNumberFormat
        if ($mode -eq "last" -and $null -ne $labelText -and [string]$labelText -ne "") {
            $label.Text = [string]$labelText
        }
    }
}

function Set-LineSeriesFormat {
    param($Series, $SeriesSpec, [int]$Colour)

    $Series.Format.Line.Visible = -1
    $Series.Format.Line.ForeColor.RGB = $Colour
    $Series.Format.Line.Weight = [double](Get-OptionalProperty $SeriesSpec "weight" 2.25)
    $Series.Format.Line.DashStyle = Get-DashStyle `
        ([string](Get-OptionalProperty $SeriesSpec "dashStyle" "solid"))
    $Series.MarkerStyle = Get-MarkerStyle `
        ([string](Get-OptionalProperty $SeriesSpec "markerStyle" "none"))
    $Series.Smooth = $false
}

function Set-CircularSeriesFormat {
    param($Series, $SeriesSpec)

    $pointColours = @(Get-OptionalProperty $SeriesSpec "pointColours" @())
    for ($pointIndex = 1; $pointIndex -le $Series.Points().Count; $pointIndex++) {
        $pointColour = if ($pointColours.Count -gt 0) {
            Convert-HexToRgb ([string]$pointColours[$pointIndex - 1])
        }
        else {
            Get-SeriesColour $null ($pointIndex - 1)
        }
        $point = $Series.Points().Item($pointIndex)
        $point.Format.Fill.Visible = -1
        $point.Format.Fill.Solid() | Out-Null
        $point.Format.Fill.ForeColor.RGB = $pointColour
        $point.Format.Line.Visible = -1
        $point.Format.Line.ForeColor.RGB = Get-Rgb 255 255 255
        $point.Format.Line.Weight = 0.75
    }
}

function Set-FilledSeriesFormat {
    param($Series, [int]$Colour)

    $Series.Format.Fill.Visible = -1
    $Series.Format.Fill.Solid() | Out-Null
    $Series.Format.Fill.ForeColor.RGB = $Colour
    $Series.Format.Line.Visible = 0
    $Series.InvertIfNegative = $false
}

function Set-SeriesFormat {
    param(
        $Series,
        $SeriesSpec,
        [int]$Index,
        [string]$ChartType,
        [bool]$HasFocalSeries,
        [string]$DefaultNumberFormat
    )

    $isCircular = Test-IsCircularChartType $ChartType
    $colour = $(if ($isCircular) { 0 } else { Get-SeriesColour $SeriesSpec $Index $HasFocalSeries })
    if ($ChartType -eq "line") {
        Set-LineSeriesFormat $Series $SeriesSpec $colour
    }
    elseif ($isCircular) {
        Set-CircularSeriesFormat $Series $SeriesSpec
    }
    else {
        Set-FilledSeriesFormat $Series $colour
    }
    Set-SeriesLabels $Series $SeriesSpec $colour $ChartType $DefaultNumberFormat
}

function Set-ValueAxisOptions {
    param($Axis, $AxisSpec, [bool]$ShowGridlines)

    foreach ($setting in @(
        @("minimum", "MinimumScale"),
        @("maximum", "MaximumScale"),
        @("majorUnit", "MajorUnit")
    )) {
        $value = Get-OptionalProperty $AxisSpec $setting[0] $null
        if ($null -ne $value) { $Axis.($setting[1]) = [double]$value }
    }
    $Axis.HasMajorGridlines = $ShowGridlines
    if ($ShowGridlines) {
        $Axis.MajorGridlines.Format.Line.ForeColor.RGB = Get-Rgb 215 211 205
        $Axis.MajorGridlines.Format.Line.Weight = 0.5
    }
}

function Set-AxisFormat {
    param($Axis, $AxisSpec, [bool]$IsValueAxis, [bool]$ShowGridlines)

    if ($null -eq $Axis) { return }
    $midGrey = Get-Rgb 114 108 96
    $showLabels = [bool](Get-OptionalProperty $AxisSpec "showLabels" $true)
    $Axis.TickLabelPosition = $(if ($showLabels) { 4 } else { -4142 })
    $Axis.MajorTickMark = -4142
    $Axis.MinorTickMark = -4142
    $Axis.Format.Line.ForeColor.RGB = $midGrey
    $Axis.Format.Line.Weight = 0.75
    if ($showLabels) {
        $Axis.TickLabels.Font.Name = "Calibri Light"
        $Axis.TickLabels.Font.Size = [double](Get-OptionalProperty $AxisSpec "labelSize" 11)
        $Axis.TickLabels.Font.Color = $midGrey
        $numberFormat = Get-OptionalProperty $AxisSpec "numberFormat" $null
        if ($null -ne $numberFormat -and [string]$numberFormat -ne "") {
            $Axis.TickLabels.NumberFormat = [string]$numberFormat
        }
    }
    $title = Get-OptionalProperty $AxisSpec "title" $null
    if ($null -ne $title -and [string]$title -ne "") {
        $Axis.HasTitle = $true
        $Axis.AxisTitle.Text = [string]$title
        $Axis.AxisTitle.Font.Name = "Calibri Light"
        $Axis.AxisTitle.Font.Size = [double](Get-OptionalProperty $AxisSpec "titleSize" 11)
        $Axis.AxisTitle.Font.Color = $midGrey
    }
    if (-not $IsValueAxis) {
        $interval = Get-OptionalProperty $AxisSpec "labelInterval" $null
        if ($null -ne $interval) { $Axis.TickLabelSpacing = [int]$interval }
        return
    }

    Set-ValueAxisOptions $Axis $AxisSpec $ShowGridlines
}

function Find-ShapeIndices {
    param($Slide, [string]$Name)

    $matches = @()
    for ($index = 1; $index -le $Slide.Shapes.Count; $index++) {
        if ($Slide.Shapes.Item($index).Name -ceq $Name) { $matches += $index }
    }
    return $matches
}

function Test-IsJsonNumber {
    param($Value)

    return (
        $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64] -or
        $Value -is [single] -or $Value -is [double] -or
        $Value -is [decimal]
    )
}

function Assert-OptionalBoolean {
    param($Object, [string]$Name, [string]$Context)

    if ($null -ne $Object.PSObject.Properties[$Name] -and $Object.$Name -isnot [bool]) {
        throw "$Context.$Name must be a JSON boolean."
    }
}

function Assert-OptionalNumber {
    param($Object, [string]$Name, [string]$Context)

    if ($null -ne $Object.PSObject.Properties[$Name] -and -not (Test-IsJsonNumber $Object.$Name)) {
        throw "$Context.$Name must be a JSON number."
    }
}

function Assert-OptionalString {
    param($Object, [string]$Name, [string]$Context)

    if ($null -ne $Object.PSObject.Properties[$Name] -and $Object.$Name -isnot [string]) {
        throw "$Context.$Name must be a JSON string."
    }
}

function Assert-OptionalEnum {
    param($Object, [string]$Name, [string]$Context, [string[]]$Allowed)

    Assert-OptionalString $Object $Name $Context
    if ($null -ne $Object.PSObject.Properties[$Name]) {
        $value = ([string]$Object.$Name).ToLowerInvariant()
        if ($value -notin $Allowed) {
            throw "$Context.$Name '$value' is not supported."
        }
    }
}

function Assert-AxisSpec {
    param($AxisSpec, [string]$Context, [bool]$IsValueAxis)

    if ($AxisSpec -isnot [pscustomobject]) { throw "$Context must be a JSON object." }
    Assert-OptionalString $AxisSpec "title" $Context
    Assert-OptionalString $AxisSpec "numberFormat" $Context
    Assert-OptionalBoolean $AxisSpec "showLabels" $Context
    foreach ($field in @("titleSize", "labelSize")) {
        Assert-OptionalNumber $AxisSpec $field $Context
    }
    if ($IsValueAxis) {
        foreach ($field in @("minimum", "maximum", "majorUnit")) {
            Assert-OptionalNumber $AxisSpec $field $Context
        }
    }
    else {
        Assert-OptionalNumber $AxisSpec "labelInterval" $Context
    }
}

function Assert-ChartBounds {
    param($Bounds)

    if ($Bounds -isnot [pscustomobject]) { throw "bounds must be a JSON object." }
    foreach ($bound in @("left", "top", "width", "height")) {
        if ($null -eq $Bounds.PSObject.Properties[$bound]) {
            throw "Chart bounds are missing '$bound'."
        }
        if (-not (Test-IsJsonNumber $Bounds.$bound)) {
            throw "bounds.$bound must be a JSON number."
        }
    }
    if ([double]$Bounds.left -lt 0 -or [double]$Bounds.top -lt 0 -or
        [double]$Bounds.width -le 0 -or [double]$Bounds.height -le 0) {
        throw "Chart bounds must have non-negative left/top and positive width/height."
    }
}

function Assert-LabelPositionForChart {
    param([string]$ChartType, $Series)

    $position = ([string](Get-OptionalProperty $Series "labelPosition" "")).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($position)) { return }
    $allowed = if ($ChartType -eq "line") {
        @("best-fit", "above", "below", "left", "right", "centre")
    }
    elseif (Test-IsCircularChartType $ChartType) {
        @("best-fit", "centre", "inside-end", "outside-end")
    }
    else {
        @("centre", "inside-end", "outside-end")
    }
    if ($position -notin $allowed) {
        throw "labelPosition '$position' is not supported for chartType '$ChartType'."
    }
}

function Assert-SeriesProperties {
    param([string]$ChartType, $Series)

    if ($Series -isnot [pscustomobject]) { throw "Every series must be a JSON object." }
    Assert-OptionalString $Series "name" "series"
    foreach ($field in @("labelText", "numberFormat", "labelPosition")) {
        Assert-OptionalString $Series $field "series '$($Series.name)'"
    }
    Assert-OptionalEnum $Series "dataLabels" "series '$($Series.name)'" @("none", "all", "last")
    foreach ($field in @("showCategoryName", "showSeriesName", "showPercentage", "showValue")) {
        Assert-OptionalBoolean $Series $field "series '$($Series.name)'"
    }
    foreach ($field in @("labelSize", "weight")) {
        Assert-OptionalNumber $Series $field "series '$($Series.name)'"
    }
    Assert-LabelPositionForChart $ChartType $Series
    if ([string]::IsNullOrWhiteSpace([string](Get-OptionalProperty $Series "name" ""))) {
        throw "Every series requires a non-empty name."
    }
}

function Assert-SeriesValues {
    param([string]$ChartType, $Series, [int]$ExpectedCount)

    if ($null -eq $Series.PSObject.Properties["values"]) {
        throw "Series '$($Series.name)' is missing values."
    }
    if ($Series.values -isnot [System.Array]) {
        throw "Series '$($Series.name)'.values must be a JSON array."
    }
    $values = @($Series.values)
    if ($values.Count -ne $ExpectedCount) {
        throw "Series '$($Series.name)' has $($values.Count) values; expected $ExpectedCount."
    }
    foreach ($value in $values) {
        if ($null -ne $value -and -not (Test-IsJsonNumber $value)) {
            throw "Series '$($Series.name)' contains non-numeric JSON value '$value'."
        }
    }
    if (-not (Test-IsCircularChartType $ChartType)) { return }

    [double]$total = 0
    foreach ($value in $values) {
        if ($null -eq $value) { continue }
        if ([double]$value -lt 0) {
            throw "Pie and doughnut series values must be non-negative."
        }
        $total += [double]$value
    }
    if ($total -le 0) {
        throw "Pie and doughnut series values must have a positive total."
    }
}

function Assert-SeriesChartTypeOptions {
    param([string]$ChartType, $Series)

    $isCircular = Test-IsCircularChartType $ChartType
    if (-not $isCircular -and [bool](Get-OptionalProperty $Series "showPercentage" $false)) {
        throw "showPercentage is only supported by pie and doughnut charts."
    }
    if ($isCircular -and
        ($null -ne $Series.PSObject.Properties["role"] -or
         $null -ne $Series.PSObject.Properties["colour"])) {
        throw "Series role/colour are not used by circular charts; use pointColours."
    }
    if (-not $isCircular -and $null -ne $Series.PSObject.Properties["pointColours"]) {
        throw "pointColours is only supported by pie and doughnut charts."
    }
    if ($ChartType -ne "line") {
        foreach ($field in @("weight", "dashStyle", "markerStyle")) {
            if ($null -ne $Series.PSObject.Properties[$field]) {
                throw "$field is only supported by line charts."
            }
        }
        return
    }

    foreach ($field in @("dashStyle", "markerStyle")) {
        Assert-OptionalString $Series $field "series '$($Series.name)'"
    }
    if ($null -ne $Series.PSObject.Properties["dashStyle"]) {
        [void](Get-DashStyle ([string]$Series.dashStyle))
    }
    if ($null -ne $Series.PSObject.Properties["markerStyle"]) {
        [void](Get-MarkerStyle ([string]$Series.markerStyle))
    }
}

function Assert-SeriesColours {
    param([string]$ChartType, $Series, [int]$ExpectedCount)

    if (-not (Test-IsCircularChartType $ChartType)) {
        Assert-OptionalEnum $Series "role" "series '$($Series.name)'" @("focal", "context", "positive", "negative")
        Assert-OptionalString $Series "colour" "series '$($Series.name)'"
        $colour = Get-OptionalProperty $Series "colour" $null
        if ($null -ne $colour) { [void](Convert-HexToRgb ([string]$colour)) }
        return
    }

    if ($null -ne $Series.PSObject.Properties["pointColours"] -and
        $Series.pointColours -isnot [System.Array]) {
        throw "Series '$($Series.name)'.pointColours must be a JSON array."
    }
    $pointColours = @(Get-OptionalProperty $Series "pointColours" @())
    if ($pointColours.Count -gt 0 -and $pointColours.Count -ne $ExpectedCount) {
        throw "Series '$($Series.name)' has $($pointColours.Count) pointColours; expected $ExpectedCount."
    }
    foreach ($pointColour in $pointColours) {
        [void](Convert-HexToRgb ([string]$pointColour))
    }
}

function Assert-ChartSeries {
    param([string]$ChartType, $Categories, $SeriesItems)

    if ($Categories -isnot [System.Array]) { throw "categories must be a JSON array." }
    if ($SeriesItems -isnot [System.Array]) { throw "series must be a JSON array." }
    $categoryArray = @($Categories)
    $seriesArray = @($SeriesItems)
    if ($categoryArray.Count -eq 0) { throw "At least one category is required." }
    if ($seriesArray.Count -eq 0) { throw "At least one series is required." }
    if ((Test-IsCircularChartType $ChartType) -and $seriesArray.Count -ne 1) {
        throw "Pie and doughnut charts require exactly one series."
    }
    foreach ($series in $seriesArray) {
        Assert-SeriesProperties $ChartType $series
        Assert-SeriesValues $ChartType $series $categoryArray.Count
        Assert-SeriesChartTypeOptions $ChartType $series
        Assert-SeriesColours $ChartType $series $categoryArray.Count
    }
}

function Assert-ChartSpec {
    param($Spec)

    if ($Spec -isnot [pscustomobject]) { throw "Chart specification must be a JSON object." }
    foreach ($required in @("chartType", "bounds", "categories", "series")) {
        if ($null -eq $Spec.PSObject.Properties[$required]) {
            throw "Chart specification is missing '$required'."
        }
    }
    if ($Spec.chartType -isnot [string]) { throw "chartType must be a JSON string." }
    $chartType = ([string]$Spec.chartType).ToLowerInvariant()
    [void](Get-ChartTypeConstant $chartType)
    foreach ($field in @("name", "title")) { Assert-OptionalString $Spec $field "chart" }
    foreach ($field in @("showLegend", "showGridlines")) { Assert-OptionalBoolean $Spec $field "chart" }
    foreach ($field in @("titleSize", "legendSize", "holeSize")) { Assert-OptionalNumber $Spec $field "chart" }
    Assert-OptionalEnum $Spec "legendPosition" "chart" @("bottom", "top", "left", "right")
    if ($null -ne $Spec.PSObject.Properties["categoryAxis"]) {
        Assert-AxisSpec $Spec.categoryAxis "categoryAxis" $false
    }
    if ($null -ne $Spec.PSObject.Properties["valueAxis"]) {
        Assert-AxisSpec $Spec.valueAxis "valueAxis" $true
    }
    if ((Test-IsCircularChartType $chartType) -and
        ($null -ne $Spec.PSObject.Properties["categoryAxis"] -or
         $null -ne $Spec.PSObject.Properties["valueAxis"] -or
         $null -ne $Spec.PSObject.Properties["showGridlines"])) {
        throw "Axis and gridline options are not supported by pie or doughnut charts."
    }
    if ($chartType -ne "doughnut" -and $null -ne $Spec.PSObject.Properties["holeSize"]) {
        throw "holeSize is only supported by doughnut charts."
    }
    if ($chartType -eq "doughnut" -and $null -ne $Spec.PSObject.Properties["holeSize"] -and
        ([double]$Spec.holeSize -lt 10 -or [double]$Spec.holeSize -gt 90)) {
        throw "holeSize must be between 10 and 90."
    }
    foreach ($category in @($Spec.categories)) {
        if ($null -eq $category -or ($category -isnot [string] -and -not (Test-IsJsonNumber $category))) {
            throw "Every category must be a JSON string or number."
        }
    }
    Assert-ChartBounds $Spec.bounds
    Assert-ChartSeries $chartType $Spec.categories $Spec.series
}

function Get-FileFingerprint {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $item = Get-Item -LiteralPath $Path
    return "$($item.Length):$($item.LastWriteTimeUtc.Ticks)"
}

function Assert-OutputUnchanged {
    param($Paths)

    $currentFingerprint = Get-FileFingerprint $Paths.Output
    if ($Paths.OutputExistedAtStart) {
        if ($null -eq $currentFingerprint -or $currentFingerprint -ne $Paths.OutputFingerprint) {
            throw "Output changed while PowerPoint was running; refusing to overwrite it."
        }
    }
    elseif ($null -ne $currentFingerprint) {
        throw "Output was created while PowerPoint was running; refusing to overwrite it."
    }
}

function Resolve-ChartInputs {
    param([string]$Source, [string]$Output, [string]$Specification, [bool]$AllowOverwrite)

    $sourceFullPath = [IO.Path]::GetFullPath($Source)
    $outputFullPath = [IO.Path]::GetFullPath($Output)
    $specFullPath = [IO.Path]::GetFullPath($Specification)
    if (-not (Test-Path -LiteralPath $sourceFullPath -PathType Leaf)) {
        throw "Source presentation not found: $sourceFullPath"
    }
    if (-not (Test-Path -LiteralPath $specFullPath -PathType Leaf)) {
        throw "Chart specification not found: $specFullPath"
    }
    if ([IO.Path]::GetExtension($sourceFullPath).ToLowerInvariant() -ne ".pptx" -or
        [IO.Path]::GetExtension($outputFullPath).ToLowerInvariant() -ne ".pptx") {
        throw "SourcePath and OutputPath must be .pptx files."
    }
    $outputDirectory = [IO.Path]::GetDirectoryName($outputFullPath)
    if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
        throw "Output directory not found: $outputDirectory"
    }
    if ((Test-Path -LiteralPath $outputFullPath) -and
        -not (Test-Path -LiteralPath $outputFullPath -PathType Leaf)) {
        throw "OutputPath exists but is not a file: $outputFullPath"
    }
    $outputExistedAtStart = Test-Path -LiteralPath $outputFullPath -PathType Leaf
    if (($sourceFullPath -ieq $outputFullPath -or $outputExistedAtStart) -and -not $AllowOverwrite) {
        throw "Output already exists or resolves to the source. Pass -Overwrite only for intentional replacement."
    }
    return [pscustomobject]@{
        Source = $sourceFullPath
        Output = $outputFullPath
        Spec = $specFullPath
        OutputDirectory = $outputDirectory
        OutputExistedAtStart = $outputExistedAtStart
        OutputFingerprint = Get-FileFingerprint $outputFullPath
    }
}

function Get-ReplacementIndex {
    param($Slide, [string]$ReplaceName, [string]$ChartName, [int]$SlideNumber)

    $replaceIndex = 0
    if (-not [string]::IsNullOrWhiteSpace($ReplaceName)) {
        $replaceMatches = @(Find-ShapeIndices $Slide $ReplaceName)
        if ($replaceMatches.Count -ne 1) {
            throw "Expected exactly one shape named '$ReplaceName' on slide $SlideNumber; found $($replaceMatches.Count)."
        }
        $replaceIndex = $replaceMatches[0]
    }
    $nameMatches = @(Find-ShapeIndices $Slide $ChartName)
    $nameIsReplacement = $nameMatches.Count -eq 1 -and $nameMatches[0] -eq $replaceIndex
    if ($nameMatches.Count -gt 0 -and -not $nameIsReplacement) {
        throw "A shape named '$ChartName' already exists on slide $SlideNumber."
    }
    return $replaceIndex
}

function Assert-ChartFitsSlide {
    param($Presentation, $Bounds)

    $slideWidth = [double]$Presentation.PageSetup.SlideWidth
    $slideHeight = [double]$Presentation.PageSetup.SlideHeight
    if ([double]$Bounds.left + [double]$Bounds.width -gt $slideWidth -or
        [double]$Bounds.top + [double]$Bounds.height -gt $slideHeight) {
        throw "Chart bounds extend beyond the slide (${slideWidth}x${slideHeight} points)."
    }
}

function Add-OrReplaceChartShape {
    param(
        $Slide,
        $Bounds,
        [string]$ChartType,
        [string]$ChartName,
        [string]$ReplaceShapeName,
        [int]$SlideNumber
    )

    $replaceIndex = Get-ReplacementIndex $Slide $ReplaceShapeName $ChartName $SlideNumber
    $replacementZOrder = $null
    if ($replaceIndex -gt 0) {
        $replacementShape = $Slide.Shapes.Item($replaceIndex)
        $replacementZOrder = [int]$replacementShape.ZOrderPosition
        $replacementShape.Delete() | Out-Null
    }

    $chartShape = $Slide.Shapes.AddChart(
        (Get-ChartTypeConstant $ChartType),
        [single]$Bounds.left,
        [single]$Bounds.top,
        [single]$Bounds.width,
        [single]$Bounds.height
    )
    $chartShape.Name = $ChartName
    if ($null -eq $replacementZOrder) { return $chartShape }

    $remainingMoves = $Slide.Shapes.Count
    while ([int]$chartShape.ZOrderPosition -gt $replacementZOrder -and $remainingMoves -gt 0) {
        $chartShape.ZOrder(3) | Out-Null
        $remainingMoves--
    }
    if ([int]$chartShape.ZOrderPosition -ne $replacementZOrder) {
        throw "Could not restore the replacement shape's layer position."
    }
    return $chartShape
}

function Set-WorkbookData {
    param($Worksheet, $Categories, $SeriesSpecs)

    $Worksheet.Cells.Item(1, 1).Value2 = [string]"Category"
    for ($seriesIndex = 0; $seriesIndex -lt $SeriesSpecs.Count; $seriesIndex++) {
        $Worksheet.Cells.Item(1, $seriesIndex + 2).Value2 = [string]$SeriesSpecs[$seriesIndex].name
    }
    for ($categoryIndex = 0; $categoryIndex -lt $Categories.Count; $categoryIndex++) {
        $Worksheet.Cells.Item($categoryIndex + 2, 1).Value2 = [string]$Categories[$categoryIndex]
        for ($seriesIndex = 0; $seriesIndex -lt $SeriesSpecs.Count; $seriesIndex++) {
            $cell = $Worksheet.Cells.Item($categoryIndex + 2, $seriesIndex + 2)
            $value = @($SeriesSpecs[$seriesIndex].values)[$categoryIndex]
            if ($null -eq $value) {
                $cell.ClearContents() | Out-Null
            }
            else {
                $cell.Value2 = [double]::Parse(
                    [string]$value,
                    [Globalization.CultureInfo]::InvariantCulture
                )
            }
        }
    }
}

function Add-ChartSeries {
    param($Chart, $Categories, $SeriesSpecs, [string]$ChartType, [string]$DefaultNumberFormat)

    while ($Chart.SeriesCollection().Count -gt 0) {
        $Chart.SeriesCollection().Item(1).Delete() | Out-Null
    }
    $lastRow = $Categories.Count + 1
    $hasFocalSeries = @(
        $SeriesSpecs | Where-Object {
            ([string](Get-OptionalProperty $_ "role" "")).ToLowerInvariant() -eq "focal"
        }
    ).Count -gt 0
    for ($seriesIndex = 0; $seriesIndex -lt $SeriesSpecs.Count; $seriesIndex++) {
        $column = Get-ExcelColumnName ($seriesIndex + 2)
        $series = $Chart.SeriesCollection().NewSeries()
        $series.Name = "='Chart data'!`$$column`$1"
        $series.XValues = "='Chart data'!`$A`$2:`$A`$$lastRow"
        $series.Values = "='Chart data'!`$$column`$2:`$$column`$$lastRow"
        Set-SeriesFormat `
            $series `
            $SeriesSpecs[$seriesIndex] `
            $seriesIndex `
            $ChartType `
            $hasFocalSeries `
            $DefaultNumberFormat
    }
}

function Set-ChartPresentationFormat {
    param($Chart, $Spec, [string]$ChartType)

    $Chart.ChartArea.Format.Fill.Visible = 0
    $Chart.ChartArea.Format.Line.Visible = 0
    $Chart.PlotArea.Format.Fill.Visible = 0
    $Chart.PlotArea.Format.Line.Visible = 0

    $title = Get-OptionalProperty $Spec "title" $null
    if ($null -ne $title -and [string]$title -ne "") {
        $Chart.HasTitle = $true
        $Chart.ChartTitle.Text = [string]$title
        $Chart.ChartTitle.Font.Name = "Calibri Light"
        $Chart.ChartTitle.Font.Size = [double](Get-OptionalProperty $Spec "titleSize" 14)
        $Chart.ChartTitle.Font.Bold = -1
        $Chart.ChartTitle.Font.Color = Get-Rgb 60 60 60
    }

    $showLegend = [bool](Get-OptionalProperty $Spec "showLegend" $false)
    $Chart.HasLegend = $showLegend
    if ($showLegend) {
        $legendPositions = @{ "bottom" = -4107; "left" = -4131; "right" = -4152; "top" = -4160 }
        $legendPosition = ([string](Get-OptionalProperty $Spec "legendPosition" "bottom")).ToLowerInvariant()
        if (-not $legendPositions.ContainsKey($legendPosition)) {
            throw "Unsupported legendPosition '$legendPosition'."
        }
        $Chart.Legend.Position = $legendPositions[$legendPosition]
        $Chart.Legend.Font.Name = "Calibri Light"
        $Chart.Legend.Font.Size = [double](Get-OptionalProperty $Spec "legendSize" 11)
        $Chart.Legend.Font.Color = Get-Rgb 60 60 60
    }

    if (-not (Test-IsCircularChartType $ChartType)) {
        Set-AxisFormat `
            ($Chart.Axes(1, 1)) `
            (Get-OptionalProperty $Spec "categoryAxis" ([pscustomobject]@{})) `
            $false `
            $false
        Set-AxisFormat `
            ($Chart.Axes(2, 1)) `
            (Get-OptionalProperty $Spec "valueAxis" ([pscustomobject]@{})) `
            $true `
            ([bool](Get-OptionalProperty $Spec "showGridlines" $false))
    }
    if ($ChartType -eq "doughnut") {
        $holeSize = [int](Get-OptionalProperty $Spec "holeSize" 55)
        if ($holeSize -lt 10 -or $holeSize -gt 90) {
            throw "holeSize must be between 10 and 90."
        }
        $Chart.ChartGroups(1).DoughnutHoleSize = $holeSize
    }
}

function Invoke-NativeChartInsertion {
    param(
        $Paths,
        $Spec,
        [int]$SlideNumber,
        [string]$ReplaceShapeName,
        [bool]$ShowWindows
    )

    $chartType = ([string]$Spec.chartType).ToLowerInvariant()
    $chartName = [string](Get-OptionalProperty $Spec "name" "Scarlatti native chart")
    $tempPath = Join-Path $Paths.OutputDirectory (
        [IO.Path]::GetFileNameWithoutExtension($Paths.Output) +
        ".charttmp." + [guid]::NewGuid().ToString("N") + ".pptx"
    )
    $powerPoint = $null
    $presentation = $null
    $workbook = $null
    $excel = $null
    $saved = $false
    try {
        $powerPoint = New-Object -ComObject PowerPoint.Application
        $powerPoint.Visible = -1
        if (-not $ShowWindows) { $powerPoint.WindowState = 2 }
        $presentation = $powerPoint.Presentations.Open($Paths.Source, $false, $false, $true)
        if ($SlideNumber -gt $presentation.Slides.Count) {
            throw "Slide $SlideNumber does not exist; presentation has $($presentation.Slides.Count) slides."
        }
        $slide = $presentation.Slides.Item($SlideNumber)
        $presentation.Windows.Item(1).View.GotoSlide($SlideNumber)
        $slide.Select() | Out-Null

        Assert-ChartFitsSlide $presentation $Spec.bounds
        $chartShape = Add-OrReplaceChartShape `
            $slide `
            $Spec.bounds `
            $chartType `
            $chartName `
            $ReplaceShapeName `
            $SlideNumber
        $chart = $chartShape.Chart
        $chart.HasTitle = $false
        $chart.HasLegend = $false

        $chart.ChartData.Activate() | Out-Null
        $workbook = $chart.ChartData.Workbook
        $excel = $workbook.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $worksheet = $workbook.Worksheets.Item(1)
        $worksheet.Name = "Chart data"
        $worksheet.Cells.Clear() | Out-Null

        $categories = @($Spec.categories)
        $seriesSpecs = @($Spec.series)
        $valueAxisSpec = Get-OptionalProperty $Spec "valueAxis" ([pscustomobject]@{})
        $defaultNumberFormat = [string](Get-OptionalProperty $valueAxisSpec "numberFormat" "")
        Set-WorkbookData $worksheet $categories $seriesSpecs
        Add-ChartSeries $chart $categories $seriesSpecs $chartType $defaultNumberFormat
        Set-ChartPresentationFormat $chart $Spec $chartType

        $workbook.Close($true) | Out-Null
        $workbook = $null
        $presentation.SaveAs($tempPath, 24) | Out-Null
        $presentation.Close() | Out-Null
        $presentation = $null
        Assert-OutputUnchanged $Paths
        if ($Paths.OutputExistedAtStart) {
            Move-Item -LiteralPath $tempPath -Destination $Paths.Output -Force
        }
        else {
            Move-Item -LiteralPath $tempPath -Destination $Paths.Output
        }
        $saved = $true

        Write-Output "chart_name=$chartName"
        Write-Output "chart_type=$chartType"
        Write-Output "series=$($seriesSpecs.Count)"
        Write-Output "output=$($Paths.Output)"
    }
    catch {
        Write-Error (
            "Chart insertion failed at line " + $_.InvocationInfo.ScriptLineNumber +
            ": " + $_.Exception.Message
        )
        throw
    }
    finally {
        if ($null -ne $workbook) { try { $workbook.Close($false) } catch {} }
        if ($null -ne $excel) { try { $excel.Quit() } catch {} }
        if ($null -ne $presentation) { try { $presentation.Close() } catch {} }
        if ($null -ne $powerPoint) { try { $powerPoint.Quit() } catch {} }
        foreach ($comObject in @($workbook, $excel, $presentation, $powerPoint)) {
            if ($null -ne $comObject -and [Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject)
            }
        }
        if (-not $saved -and (Test-Path -LiteralPath $tempPath)) {
            Remove-Item -LiteralPath $tempPath -Force
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

Assert-NoActiveOfficeSessions @("POWERPNT", "EXCEL")
$paths = Resolve-ChartInputs $SourcePath $OutputPath $SpecPath ([bool]$Overwrite)
$spec = Get-Content -LiteralPath $paths.Spec -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-ChartSpec $spec
Invoke-NativeChartInsertion $paths $spec $SlideNumber $ReplaceShapeName ([bool]$ShowOfficeWindows)
