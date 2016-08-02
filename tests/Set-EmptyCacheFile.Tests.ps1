$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\build\Set-EmptyCacheFile.ps1"

Describe 'Set-EmptyCacheFile' {

    Context 'When the empty cache file is saved' {

        # arrange
        Setup -File cache.xml -Content ''
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml]$null
            ToolsVersion = '1.2.3'
            ConfigTimestamp = '456'
        }

        # act
        Set-EmptyCacheFile -Context $context

        [xml]$xml = Get-Content $context.CacheFile
        [string]$toolsVersion = $xml.files.toolsVersion
        [string]$configTimestamp = $xml.files.configTimestamp

        # assert
        It 'should contain valid version and timestamp' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
        }

        It 'should update CacheXml property' {
            $context.CacheXml | Should Not Be $null
            $context.CacheXml.files.toolsVersion | Should Be '1.2.3'
            $context.CacheXml.files.configTimestamp | Should Be '456'
        }
    }

    Context 'When cache filename is not set' {

        # arrange
        Setup -File cache.xml -Content ''
        $context = [PSCustomObject]@{
            CacheFile = $null
        }

        # act, assert
        It 'should throw an exception' {
            { Set-EmptyCacheFile -Context $context } | Should Throw
        }
    }
}