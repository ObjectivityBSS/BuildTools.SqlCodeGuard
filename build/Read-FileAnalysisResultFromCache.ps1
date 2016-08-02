#######################################################################################################
## Name:             Read-FileAnalysisResultFromCache.ps1
## Description:      Reads the cached file analysis.
#######################################################################################################
function Read-FileAnalysisResultFromCache {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        $Context = $null,

        [Parameter(Mandatory = $true)]
        $AnalyzedFile
    )
    <#
    cache file structure:
    <files toolsVersion="version" configTimestamp="number">
        <file name="path" timestamp="utc-ticks">
            output lines
        </file>
    </files>
    #>
    Read-CacheXml -Context $Context
    if ($Context.CacheXml -eq $null) {
        return $null
    }
    $files = $Context.CacheXml.files

    if ($files.file.Count -eq 0) {
        return $null
    }

    $fileElement = $files.file `
        | Where-Object { $_.name -eq $AnalyzedFile.Path } `
        | Sort-Object -Property timestamp -Descending `
        | Select-Object -First 1

    if ($fileElement -ne $null) {
        [long]$timestamp = $fileElement.timestamp
        if ($timestamp -eq $AnalyzedFile.Ticks) {
            return $fileElement.InnerText
        }
    }
    return $null
}