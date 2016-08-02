#######################################################################################################
## Name:             Update-CacheXmlConfig.ps1
## Description:      Updates the config attributes in the cache file.
#######################################################################################################
function Update-CacheXmlConfig {
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    Read-CacheXml -Context $Context
    if ($Context.CacheXml -eq $null) {
        return
    }

    $files = $Context.CacheXml.files
    $files.SetAttribute('toolsVersion', $Context.ToolsVersion)
    $files.SetAttribute('configTimestamp', $Context.ConfigTimestamp)

    $Context.CacheXml.Save($Context.CacheFile)
}