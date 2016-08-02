#######################################################################################################
## Name:             Write-FileAnalysisResultToCache.ps1
## Description:      Whites the new file analysis to the cache file.
#######################################################################################################
function Write-FileAnalysisResultToCache {
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        $Context,

        [Parameter(Mandatory = $true)]
        $AnalyzedFile,

        [Parameter(Mandatory = $false)]
        [string[]]
        $OutputLinesToCache
    )

    Read-CacheXml -Context $Context
    if ($Context.CacheXml -eq $null) {
        return
    }

    $files = $Context.CacheXml.files

    if ($files.file.Count -gt 0) {
        $files.file `
            | Where-Object { $_ -ne $null -and $_.name -eq $AnalyzedFile.Path } `
            | ForEach-Object { $files.RemoveChild($_) } `
            | Out-Null
    }

    [System.Xml.XmlElement]$fileElement = $Context.CacheXml.CreateElement('file')
    $fileElement.SetAttribute('name', $AnalyzedFile.Path)
    $fileElement.SetAttribute('timestamp', $AnalyzedFile.Ticks)
    if ($OutputLinesToCache -ne $null -and $OutputLinesToCache.Count -gt 0) {
        $fileElement.InnerText = [String]::Join([Environment]::NewLine, $OutputLinesToCache)
    }
    else {
        $fileElement.InnerText = ''
    }
    $Context.CacheXml.DocumentElement.AppendChild($fileElement) | Out-Null
    $Context.CacheXml.Save($Context.CacheFile)
}