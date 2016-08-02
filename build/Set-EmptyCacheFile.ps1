#######################################################################################################
## Name:             Set-EmptyCacheFile.ps1
## Description:      Clears the SCG-output cache file.
#######################################################################################################
function Set-EmptyCacheFile {
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        $Context
    )

    if ([string]::IsNullOrWhiteSpace($Context.CacheFile)) {
        throw '$Context.CacheFile is not set'
    }

    Set-Content -Path $Context.CacheFile -Value "<files toolsVersion='$($Context.ToolsVersion)' configTimestamp='$($Context.ConfigTimestamp)' />"
    $Context.CacheXml = [xml](Get-Content -Path $Context.CacheFile)
}