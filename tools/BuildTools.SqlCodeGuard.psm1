<#
    BuildTools.SqlCodeGuard - Copyright(c) 2015 - Objectivity BSS
    Version: %build.number%
    Based on the following file licensed under MS-PL:
    https://github.com/jonwagner/BuildTools.NET/blob/master/BuildTools.StyleCop/tools/StyleCop.psm1
#>

# define our variables
$thisFolder = (Split-Path $MyInvocation.MyCommand.Definition -Parent)
$packageID = 'BuildTools_SqlCodeGuard'
$targetsFile = Join-Path $thisFolder '..\build\BuildTools.SqlCodeGuard.targets'

# import the standard build module
$msbuildModule = (Join-Path $thisFolder BuildTools.MsBuild.psm1)
Import-Module $msbuildModule -Force

<#
.Synopsis
    Installs SqlCodeGuard into the given project.
.Description
    Installs SqlCodeGuard into the given project.

    The default installation enables SqlCodeGuard for Release builds and treats Warnings as Errors.
    You can change the behavior by running Enable-SqlCodeGuard or Set-SqlCodeGuardWarningsAs.
.Parameter Project
    The project to modify.
.Example
    Install-SqlCodeGuard $Project

    Installs SqlCodeGuard into the given project.
#>
function Install-SqlCodeGuard {
    param (
        $Project,
        [switch] $Quiet
    )

    # make sure that we always have an msbuild project
    $Project = Get-MsBuildProject $project

    if (!$Quiet) {
        Write-Host "Installing SqlCodeGuard in $($Project.FullPath)"
    }

    # import BuildTools.SqlCodeGuard.targets
    Add-MsBuildImport -Project $Project -ImportFile $targetsFile -PackageID $packageID -TestProperty 'SqlCodeGuardOutFile'

    if (!(Get-MsBuildProperty -Project $Project -Name BuildToolsSqlCodeGuardVersion)) {
        # the SqlCodeGuard default is enabled for debug and release, but that is excessive
        # let's just validate only on release mode, but we will treat those as errors
        # other users can run the scripts to change that if they want to
        Disable-SqlCodeGuard -Project $Project -Quiet
        Enable-SqlCodeGuard -Project $Project -Configuration Debug -TreatWarningsAs Warnings -Quiet:$Quiet
        Enable-SqlCodeGuard -Project $Project -Configuration Release -TreatWarningsAs Errors -Quiet:$Quiet

        # tag the installation with the version so we don't overwrite peoples' settings
        Set-MsBuildProperty -Project $Project -Name BuildToolsSqlCodeGuardVersion -Value '%build.number%'
    }
    else {
        if (!$Quiet) {
            Write-Host 'BuildTools.SqlCodeGuard was already installed. Not modifying settings.'
        }
    }
}

<#
.Synopsis
    Uninstalls SqlCodeGuard into the given project.
.Description
    Uninstalls SqlCodeGuard into the given project.
.Parameter Project
    The project to modify.
.Example
    Uninstall-SqlCodeGuard $Project

    Uninstall SqlCodeGuard from the given project.
#>
function Uninstall-SqlCodeGuard {
    param (
        $Project,
        [switch] $Quiet
    )

    # make sure that we always have an msbuild project
    $Project = Get-MsBuildProject $project

    if (!$Quiet) {
        Write-Host "Uninstalling SqlCodeGuard in $($Project.FullPath)"
    }

    # remove the import so the build doesn't use it anymore
    # leave the SqlCodeGuard variables around so our settings can survive an upgrade
    Remove-MsBuildImport -Project $Project -ImportFile $targetsFile -PackageID $packageID
}

<#
.Synopsis
    Enables SqlCodeGuard for a given project configuration.
.Description
    Enables SqlCodeGuard for a given project configuration.

    If Configuration and Platform are not specified, this enables SqlCodeGuard for all configurations.
    The Warnings setting is not modified uless TreatWarningsAs is specified.
.Parameter Project
    The project to modify.
.Parameter TreatWarningsAs
    Sets Warnings as Errors or Warnings for the given configurations.
.Parameter Configuration
    The configuration to modify (e.g. Debug or Release).
.Parameter Platform
    The platform configuration to modify (e.g. AnyCPU or x86)
.Parameter Quiet
    Suppresses installation messages.
.Example
    Enable-SqlCodeGuard $Project

    Enables SqlCodeGuard for all configurations.
.Example
    Enable-SqlCodeGuard $Project -Configuration Release

    Enables SqlCodeGuard for all Release configurations.
#>
function Enable-SqlCodeGuard {
    param (
        $Project,
        [ValidateSet('Errors', 'Warnings')] [string] $TreatWarningsAs,
        [string] $Configuration,
        [string] $Platform,
        [switch] $Quiet
    )

    # make sure that we always have an msbuild project
    $Project = Get-MsBuildProject $project

    if (!$Quiet) {
        $whichConfig = $Configuration
        if (!$whichConfig) { $whichConfig = 'All Configurations' }
        $whichPlat = $Platform
        if (!$whichPlat) { $whichPlat = 'All Platforms' }
        Write-Host "Enabling SqlCodeGuard in $($Project.FullPath) for $whichConfig $whichPlat"
    }

    # enable SqlCodeGuard for the specified configurations
    Set-MsBuildConfigurationProperty -Project $Project `
        -Name "SqlCodeGuardEnabled" -Value $true `
        -Configuration $Configuration -Platform $Platform

    # set warnings as warnings/errors if not null
    if ($TreatWarningsAs) {
        Set-SqlCodeGuardWarningsAs $Project -TreatWarningsAs $TreatWarningsAs -Configuration $Configuration -Platform $Platform -Quiet:$Quiet
    }
}

<#
.Synopsis
    Disables SqlCodeGuard for a given project configuration.
.Description
    Disables SqlCodeGuard for a given project configuration.

    If Configuration and Platform are not specified, this disables SqlCodeGuard for all configurations.
.Parameter Project
    The project to modify.
.Parameter Configuration
    The configuration to modify (e.g. Debug or Release).
.Parameter Platform
    The platform configuration to modify (e.g. AnyCPU or x86)
.Parameter Quiet
    Suppresses installation messages.
.Example
    Disable-SqlCodeGuard $Project

    Disables SqlCodeGuard for all configurations.
.Example
    Disable-SqlCodeGuard $Project -Configuration Debug

    Disables SqlCodeGuard for all Debug configurations.
#>
function Disable-SqlCodeGuard {
    param (
        $Project,
        [string] $Configuration,
        [string] $Platform,
        [switch] $Quiet
    )

    # make sure that we always have an msbuild project
    $Project = Get-MsBuildProject $project

    if (!$Quiet) {
        Write-Host "Disabling SqlCodeGuard in $($Project.FullPath)"
    }

    # set SqlCodeGuardEnabled to false (default is true)
    Set-MsBuildConfigurationProperty -Project $Project `
        -Name "SqlCodeGuardEnabled" -Value $false `
        -Configuration $Configuration -Platform $Platform
}

<#
.Synopsis
    Sets SqlCodeGuard Warnings as compile Errors or Warnings.
.Description
    Sets SqlCodeGuard Warnings as compile Errors or Warnings.
.Parameter TreatWarningsAs
    Sets Warnings as Errors or Warnings for the given configurations.
.Parameter Project
    The project to modify.
.Parameter Configuration
    The configuration to modify (e.g. Debug or Release).
.Parameter Platform
    The platform configuration to modify (e.g. AnyCPU or x86)
.Example
    Set-SqlCodeGuardWarningsAs Warnings

    Sets SqlCodeGuard warnings to be treated as warnings for all configurations of the active project.

.Example
    Set-SqlCodeGuardWarningsAs Errors $Project -Configuration Debug

    Sets SqlCodeGuard warnings to be treated as errors for all Debug configurations of the given project.
#>
function Set-SqlCodeGuardWarningsAs {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Errors', 'Warnings')] [string] $TreatWarningsAs,
        $Project,
        [string] $Configuration,
        [string] $Platform,
        [switch] $Quiet
    )

    # make sure that we always have an msbuild project
    $Project = Get-MsBuildProject $project

    if (!$Quiet) {
        Write-Host "SqlCodeGuard Warnings are now $TreatWarningsAs in $($Project.FullPath)"
    }

    if ($TreatWarningsAs -eq 'Errors') {
        $TreatWarningsAsErrors = 1
    }
    else {
        $TreatWarningsAsErrors = 0
    }

    Set-MsBuildConfigurationProperty -Project $Project `
        -Name "SqlCodeGuardTreatWarningsAsErrors" -Value $TreatWarningsAsErrors `
        -Configuration $Configuration -Platform $Platform
}

Export-ModuleMember Install-SqlCodeGuard, Uninstall-SqlCodeGuard, Enable-SqlCodeGuard, Disable-SqlCodeGuard, Set-SqlCodeGuardWarningsAs