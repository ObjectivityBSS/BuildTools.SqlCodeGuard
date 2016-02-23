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
[string]$cmdExe = '.\SqlCodeGuard.Cmd.exe'

[xml]$cacheXml = $null

# the following variables are used to check whether the cache is created by tool with current version and the config file was not modified since last analysis
[string]$currentToolsVersion = '%build.number%' # replaced with current tool version (TeamCity buildstep)
[string]$currentConfigTimestamp = ''
if (Test-Path -Path $Config) {
    $currentConfigTimestamp = [System.IO.File]::GetLastWriteTimeUtc($Config).Ticks.ToString()
}

# functions
function Format-CommandLine {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SqlFileToAnalyze
    )

    [string[]]$args = @()
    $args += ('-outfile "{0}"' -f "$outputFile")
    $args += ('-source "{0}"' -f "$SqlFileToAnalyze")
    if (![string]::IsNullOrWhiteSpace($Config)) {
        $args += ('-config "{0}"' -f "$Config")
    }
    $args += '-quiet'
    if (![string]::IsNullOrWhiteSpace($Include)) {
        $args += ('-include "{0}"' -f "$Include")
    }
    if (![string]::IsNullOrWhiteSpace($Exclude)) {
        $args += ('-exclude "{0}"' -f "$Exclude")
    }

    [string]$command = '"{0}" {1}' -f $cmdExe,($args -join ' ')
    return $command
}

function Invoke-SqlFileAnalysis {
    [OutputType([array])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    [string]$command = Format-CommandLine -SqlFileToAnalyze $Path
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

function Set-EmptyCacheFile {
    [OutputType([void])]
    param()

    Set-Content -Path $CacheFile -Value "<files toolsVersion='$currentToolsVersion' configTimestamp='$currentConfigTimestamp' />"
}

function Clear-CacheIfOutdated {
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        [xml]
        $Xml
    )

    $files = $Xml.files

    [string]$toolsVersion = $files.GetAttribute('toolsVersion')
    [string]$configTimestamp = $files.GetAttribute('configTimestamp')

    if ([string]::IsNullOrWhiteSpace($toolsVersion) -or ($currentToolsVersion -ne $toolsVersion) `
    -or [string]::IsNullOrWhiteSpace($configTimestamp) -or ($currentConfigTimestamp -ne $configTimestamp)) {
        Set-EmptyCacheFile
        $Xml = Get-Content -Path $CacheFile
    }
}

function Read-CacheXml {
    [OutputType([xml])]
    param()

    if ([string]::IsNullOrWhiteSpace($CacheFile)) {
        return $null
    }
    if ($cacheXml -eq $null) {
        if (-not(Test-Path -Path $CacheFile)) {
            Set-EmptyCacheFile
        }
        $cacheXml = Get-Content -Path $CacheFile

        Clear-CacheIfOutdated -Xml $cacheXml
    }

    return $cacheXml
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
    [xml]$xml = Read-CacheXml
    if ($xml -eq $null) {
        return $null
    }
    $files = $xml.files

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
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        $AnalyzedFile,

        [Parameter(Mandatory = $false)]
        [string[]]
        $OutputLinesToCache
    )

    [xml]$xml = Read-CacheXml
    if ($xml -eq $null) {
        return
    }
    $files = $xml.files

    if ($files.file.Count -gt 0) {
        $files.file `
            | Where-Object { $_ -ne $null -and $_.name -eq $AnalyzedFile.Path } `
            | ForEach-Object { $files.RemoveChild($_) } `
            | Out-Null
    }

    [System.Xml.XmlElement]$fileElement = $xml.CreateElement('file')
    $fileElement.SetAttribute('name', $AnalyzedFile.Path)
    $fileElement.SetAttribute('timestamp', $AnalyzedFile.Ticks)
    if ($OutputLinesToCache.Count -gt 0) {
        $fileElement.InnerText = [String]::Join([Environment]::NewLine, $OutputLinesToCache)
    }
    else {
        $fileElement.InnerText = ''
    }
    $xml.DocumentElement.AppendChild($fileElement) | Out-Null
    $xml.Save($CacheFile)
}

function Update-CacheXml {
    [OutputType([void])]
    param()

    [xml]$xml = Read-CacheXml
    if ($xml -eq $null) {
        return
    }
    $files = $xml.files
    $files.SetAttribute('toolsVersion', $currentToolsVersion)
    $files.SetAttribute('configTimestamp', $currentConfigTimestamp)

    $xml.Save($CacheFile)
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
        Write-FileAnalysisResultToCache -AnalyzedFile $fileToAnalyze -OutputLinesToCache $outputLinesToCache
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
        Write-FileAnalysisResultToCache -AnalyzedFile $fileToAnalyze -OutputLinesToCache $outputLinesToCache
    }
}
Update-CacheXml
exit $exitCode
