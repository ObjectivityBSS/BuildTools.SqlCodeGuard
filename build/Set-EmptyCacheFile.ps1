#######################################################################################################
## Name:             Set-EmptyCacheFile.ps1
## Description:      Clears the SCG-output cache file.
#######################################################################################################
function Set-EmptyCacheFile {
    [OutputType([void])]
    param(
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

    Set-Content -Path $CacheFile -Value "<files toolsVersion='$CurrentToolsVersion' configTimestamp='$CurrentConfigTimestamp' />"
}