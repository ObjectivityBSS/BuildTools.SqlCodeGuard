param (
    [Parameter(Mandatory = $true)]
    [string]
    $BaseDirectory,

    [Parameter(Mandatory = $true)]
    [string]
    $InputFile,

    [Parameter(Mandatory = $false)]
    [string]
    $CacheFile = '',

    [Parameter(Mandatory = $false)]
    [string]
    $Config = '',

    [Parameter(Mandatory = $false)]
    [string]
    $Include = '',

    [Parameter(Mandatory = $false)]
    [string]
    $Exclude = '',

    [Parameter(Mandatory = $false)]
    [int]
    $TreatWarningsAsErrors = 0,

    [Parameter(Mandatory = $false)]
    [string]
    $TreatIssueAsWarning = '',

    [Parameter(Mandatory = $false)]
    [string]
    $TreatIssueAsError = ''
)

# load used scripts
$curDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$curDir\Format-CommandLine.ps1"
. "$curDir\Set-EmptyCacheFile.ps1"
. "$curDir\Clear-CacheIfOutdated.ps1"
. "$curDir\Read-CacheXml.ps1"
. "$curDir\Update-CacheXmlConfig.ps1"

# preparing and validating input files
if (-not(Test-Path -Path $InputFile)) {
    throw "File does not exist: $InputFile"
}
[string[]]$InputFiles = [System.IO.File]::ReadAllLines($InputFile) | Where-Object { -not([string]::IsNullOrWhiteSpace($_)) } | Sort-Object
$filesToAnalyze = @()
foreach ($relativeInputFile in $InputFiles) {
    $InputFile = [System.IO.Path]::Combine($BaseDirectory, $relativeInputFile)
    if (-not(Test-Path -Path $InputFile)) {
        throw "File does not exist: $InputFile"
    }
    [bool]$isSql = $InputFile.ToUpperInvariant().EndsWith('.SQL')
    [bool]$isResx = $InputFile.ToUpperInvariant().EndsWith('.RESX')
    [long]$InputFileLastWriteTime = [System.IO.File]::GetLastWriteTimeUtc($InputFile).Ticks
    if (-not $isSql -and -not $isResx) {
        throw 'Input file must be a SQL or RESX file.'
    }
    $filesToAnalyze += @{
        Path = $InputFile
        IsSql = $isSql
        IsResx = $isResx
        Ticks = $InputFileLastWriteTime
    }
}

# variables
[int]$exitCode = 0

[string[]]$issuesAsWarnings = $TreatIssueAsWarning.Split(';')
[string[]]$issuesAsErrors = $TreatIssueAsError.Split(';')

[string]$outputFile = "$($env:TEMP)\SqlCodeGuard.xml"
[string]$sqlFromResxInputFile = "$($env:TEMP)\SqlCodeGuard.SqlFromResxInputFile.sql"

[xml]$global:cacheXml = '<files/>'

# the following variables are used to check whether the cache is created by tool with current version and the config file was not modified since last analysis
[string]$currentToolsVersion = '%build.number%' # replaced with current tool version (TeamCity buildstep)
[string]$currentConfigTimestamp = ''
if (Test-Path -Path $Config) {
    $currentConfigTimestamp = [System.IO.File]::GetLastWriteTimeUtc($Config).Ticks.ToString()
}

# functions
function Invoke-SqlFileAnalysis {
    [OutputType([array])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    [string]$command = Format-CommandLine -SqlFileToAnalyze $Path -OutputFile $outputFile -Config $Config -Include $Include -Exclude $Exclude
    Invoke-Expression "& $command"

    [xml]$xml = Get-Content -Path $outputFile

    $outputIssues = @()

    foreach ($issue in $xml.root.file.issue) {
        $code = $issue.code
        $line = $issue.line
        $column = $issue.column
        $text = $issue.text
        $message = $issue.message
        $severity = $issue.severity

        if (![string]::IsNullOrEmpty($message)) {
            $text = "$text ($message)"
        }

        if ($TreatWarningsAsErrors -ne 0 -and $severity -eq 'warning') {
            $severity = 'error'
        }

        if ($issuesAsWarnings.Count -gt 0 -and $issuesAsWarnings -contains $code) {
            $severity = 'warning'
        }

        if ($issuesAsErrors.Count -gt 0 -and $issuesAsErrors -contains $code) {
            $severity = 'error'
        }

        if ($severity -eq 'error') {
            $exitCode = 1
        }

        $issueInfo = @{
            Line = [int]$line
            Column = [int]$column
            Severity = $severity
            Code = $code
            Text = $text
        }
        $outputIssues += $issueInfo
    }

    return ,$outputIssues
}

function Read-FileAnalysisResultFromCache {
    [OutputType([string])]
    param (
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
    $global:cacheXml = Read-CacheXml -CurrentCache $global:cacheXml -CacheFile $CacheFile -CurrentToolsVersion $CurrentToolsVersion -CurrentConfigTimestamp $CurrentConfigTimestamp
    if ($global:cacheXml -eq $null) {
        return $null
    }
    $files = $global:cacheXml.files

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

function Write-FileAnalysisResultToCache {
    [OutputType([xml])]
    param (
        [Parameter(Mandatory = $false)]
        [xml]
        $CurrentCache = $null,

        [Parameter(Mandatory = $true)]
        $AnalyzedFile,

        [Parameter(Mandatory = $false)]
        [string[]]
        $OutputLinesToCache
    )

    $CurrentCache = Read-CacheXml -CurrentCache $CurrentCache -CacheFile $CacheFile -CurrentToolsVersion $CurrentToolsVersion -CurrentConfigTimestamp $CurrentConfigTimestamp
    if ($CurrentCache -eq $null) {
        return
    }
    $files = $CurrentCache.files

    if ($files.file.Count -gt 0) {
        $files.file `
            | Where-Object { $_ -ne $null -and $_.name -eq $AnalyzedFile.Path } `
            | ForEach-Object { $files.RemoveChild($_) } `
            | Out-Null
    }

    [System.Xml.XmlElement]$fileElement = $CurrentCache.CreateElement('file')
    $fileElement.SetAttribute('name', $AnalyzedFile.Path)
    $fileElement.SetAttribute('timestamp', $AnalyzedFile.Ticks)
    if ($OutputLinesToCache.Count -gt 0) {
        $fileElement.InnerText = [String]::Join([Environment]::NewLine, $OutputLinesToCache)
    }
    else {
        $fileElement.InnerText = ''
    }
    $CurrentCache.DocumentElement.AppendChild($fileElement) | Out-Null
    $CurrentCache.Save($CacheFile)

    return $CurrentCache
    }

# main code
foreach ($fileToAnalyze in $filesToAnalyze) {
    $outputFromCache = Read-FileAnalysisResultFromCache -AnalyzedFile $fileToAnalyze
    [string[]]$outputLinesToCache = @()

    if ($outputFromCache -ne $null) {
        if (-not([string]::IsNullOrWhiteSpace($outputFromCache))) {
            Write-Host -Object $outputFromCache
        }
    }
    elseif ($fileToAnalyze.IsSql) {
        $issues = Invoke-SqlFileAnalysis -Path $fileToAnalyze.Path
        foreach ($issue in $issues) {
            [string]$outputLine = "$($fileToAnalyze.Path)($($issue.Line),$($issue.Column)): $($issue.Severity) $($issue.code): $($issue.text)"
            $outputLinesToCache += $outputLine
            Write-Host -Object $outputLine
        }
        $global:cacheXml = Write-FileAnalysisResultToCache -CurrentCache $global:cacheXml -AnalyzedFile $fileToAnalyze -OutputLinesToCache $outputLinesToCache
    }
    elseif ($fileToAnalyze.IsResx) {
        [Reflection.Assembly]::LoadWithpartialName("System.Xml.Linq") | Out-Null

        $resx = [System.Xml.Linq.XDocument]::Load($fileToAnalyze.Path, [System.Xml.Linq.LoadOptions]::SetLineInfo)

        foreach ($data in $resx.Descendants('data')) {
            $name = $data.Attribute('name')
            # we want to analyze only the resx data which name ends with .SqlScript
            if ($name -ne $null -and $name.Value.EndsWith('.SqlScript')) {
                # getting the script name without the .SqlScript extension
                [string]$resxPartName = $name.Value
                $resxPartName = $resxPartName.Substring(0, $resxPartName.Length - 10)

                # value element contains the script text
                $value = $data.Element('value')

                if ($value -ne $null) {
                    # xml file loaded with SetLineInfo option contains line information we can use
                    $info = [System.Xml.IXmlLineInfo]$value
                    [int]$lineNumber = $info.LineNumber
                    [int]$linePosition = $info.LinePosition + 6 # adjusting position by a length of the element name with an ending bracket

                    # saving the sql file we want to analyze
                    $value.Value | Out-File -FilePath $sqlFromResxInputFile

                    $issues = Invoke-SqlFileAnalysis -Path $sqlFromResxInputFile
                    foreach ($issue in $issues) {
                        if ($issue.Line -eq 1) {
                            $issue.Column += $linePosition - 1 # for the first line of the sql script we have to add the position of the <value> tag
                        }
                        $issue.Line += $lineNumber - 1
                        [string]$outputLine = "$($fileToAnalyze.Path)($($issue.Line),$($issue.Column)): $($issue.Severity) $($issue.code): [$($resxPartName)] $($issue.text)"
                        $outputLinesToCache += $outputLine
                        Write-Host -Object $outputLine
                    }
                }
            }
        }
        $global:cacheXml = Write-FileAnalysisResultToCache -CurrentCache $global:cacheXml -AnalyzedFile $fileToAnalyze -OutputLinesToCache $outputLinesToCache
    }
}
Update-CacheXmlConfig -CurrentCache $global:cacheXml -CacheFile $CacheFile -CurrentToolsVersion $currentToolsVersion -CurrentConfigTimestamp $currentConfigTimestamp | Out-Null
exit $exitCode
