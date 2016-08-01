#######################################################################################################
## Name:             Update-CacheXmlConfig.ps1
## Description:      Updates the config attributes in the cache file.
#######################################################################################################
function Update-CacheXmlConfig {
    [OutputType([xml])]
    param(
        [Parameter(Mandatory = $true)]
        [xml]
        $CurrentCache,

        [Parameter(Mandatory = $true)]
        [string]
        $CacheFile,

        [Parameter(Mandatory = $true)]
        [string]
        $CurrentToolsVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $CurrentConfigTimestamp
    )

    [xml]$xml = Read-CacheXml -CurrentCache $CurrentCache -CacheFile $CacheFile -CurrentToolsVersion $CurrentToolsVersion -CurrentConfigTimestamp $CurrentConfigTimestamp
    if ($xml -eq $null) {
        return
    }
    $files = $xml.files
    $files.SetAttribute('toolsVersion', $CurrentToolsVersion)
    $files.SetAttribute('configTimestamp', $CurrentConfigTimestamp)

    $xml.Save($CacheFile)

    return $xml
}