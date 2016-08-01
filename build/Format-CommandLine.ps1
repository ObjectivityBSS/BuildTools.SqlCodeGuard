#######################################################################################################
## Name:             Format-CommandLine.ps1
## Description:      Formats the command-line for invoking SQL Code Guard.
#######################################################################################################
function Format-CommandLine {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SqlFileToAnalyze,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputFile,

        [Parameter(Mandatory = $false)]
        [string]
        $Config = '',

        [Parameter(Mandatory = $false)]
        [string]
        $Include = '',

        [Parameter(Mandatory = $false)]
        [string]
        $Exclude = ''
    )

    [string]$cmdExe = '.\SqlCodeGuard.Cmd.exe'

    [string[]]$args = @()
    $args += ('-outfile "{0}"' -f "$OutputFile")
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