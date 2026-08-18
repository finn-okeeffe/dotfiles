param(
    [Parameter(Mandatory=$true)][string]$InputDocx,
    [Parameter(Mandatory=$true)][string]$OutputPdf
)
$ErrorActionPreference = 'Stop'
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$doc = $null
try {
    $doc = $word.Documents.Open((Resolve-Path -LiteralPath $InputDocx).Path, $false, $true)
    $doc.ExportAsFixedFormat([IO.Path]::GetFullPath($OutputPdf), 17)
}
finally {
    if ($doc) { try { $doc.Close(0) } catch {} }
    try { $word.Quit() } catch {}
    [Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}

