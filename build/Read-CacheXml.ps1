#######################################################################################################
## Name:             Read-CacheXml.ps1
## Description:      Reads the current SCG output cache.
#######################################################################################################
function Read-CacheXml {
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        $Context
    )

    if ([string]::IsNullOrWhiteSpace($Context.CacheFile)) {
        $Context.CacheXml = $null
        return $false
    }

    if ($Context.CacheXml -eq $null) {
        if (-not(Test-Path -Path $Context.CacheFile)) {
            Set-EmptyCacheFile -Context $Context
        }

        $Context.CacheXml = Get-Content -Path $Context.CacheFile
        Clear-CacheIfOutdated -Context $Context
    }

    return $true
}