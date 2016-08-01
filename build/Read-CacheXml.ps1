#######################################################################################################
## Name:             Read-CacheXml.ps1
## Description:      Reads the current SCG output cache.
#######################################################################################################
function Read-CacheXml {
    [OutputType([xml])]
    param(
        [Parameter(Mandatory = $false)]
        [xml]
        $CurrentCache = $null,

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

    if ([string]::IsNullOrWhiteSpace($CacheFile)) {
        return $null
    }

    if ($CurrentCache -eq $null) {
        if (-not(Test-Path -Path $CacheFile)) {
            Set-EmptyCacheFile -CacheFile $CacheFile -CurrentToolsVersion $CurrentToolsVersion -CurrentConfigTimestamp $CurrentConfigTimestamp
        }
        $CurrentCache = Get-Content -Path $CacheFile

        $CurrentCache = Clear-CacheIfOutdated -CurrentCache $CurrentCache -CacheFile $CacheFile -CurrentToolsVersion $CurrentToolsVersion -CurrentConfigTimestamp $CurrentConfigTimestamp
    }

    return $CurrentCache
}