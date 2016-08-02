$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\build\Set-EmptyCacheFile.ps1"
. "$here\..\build\Clear-CacheIfOutdated.ps1"
. "$here\..\build\Read-CacheXml.ps1"

Describe 'Read-CacheXml' {

    Context 'When cache filename is not set' {

        # arrange
        $context = [PSCustomObject]@{
            CacheFile = $null
            CacheXml = 76
        }

        # act
        $result = Read-CacheXml -Context $context

        # assert
        It 'should return $false' {
            $result | Should Be $false
        }

        It 'should set CacheXml property to null' {
            $context.CacheXml | Should Be $null
        }
    }

    Context 'When cache does not exist' {

        # arrange
        Setup -File cache.xml -Content ''
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml]$null
            ToolsVersion = '1.2.3'
            ConfigTimestamp = '456'
        }

        # act
        $result = Read-CacheXml -Context $context

        [string]$toolsVersion = $context.CacheXml.files.toolsVersion
        [string]$configTimestamp = $context.CacheXml.files.configTimestamp

        # assert
        It 'should return $true' {
            $result | Should Be $true
        }

        It 'should return new empty cache' {
            $context.CacheXml | Should Not Be $null
        }

        It 'should be overwritten with new cache with valid version and timestamp' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
        }
    }

    Context 'When cache exists' {

        # arrange
        Setup -File cache.xml -Content '<files toolsVersion="1.2.3" configTimestamp="456"><filedata>data</filedata></files>'
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml](Get-Content -Path $TestDrive\cache.xml)
            ToolsVersion = '1.2.3'
            ConfigTimestamp = '456'
        }

        # act
        $result = Read-CacheXml -Context $context

        [string]$toolsVersion = $context.CacheXml.files.toolsVersion
        [string]$configTimestamp = $context.CacheXml.files.configTimestamp
        [string]$filedata = $context.CacheXml.files.filedata

        # assert
        It 'should return $true' {
            $result | Should Be $true
        }

        It 'should not clear cache' {
            $context.CacheXml | Should Not Be $null
        }

        It 'should not modify cache data' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
            $filedata | Should Be 'data'
        }
    }
}