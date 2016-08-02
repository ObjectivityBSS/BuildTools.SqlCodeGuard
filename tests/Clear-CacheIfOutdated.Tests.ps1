$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\build\Set-EmptyCacheFile.ps1"
. "$here\..\build\Clear-CacheIfOutdated.ps1"

Describe 'Clear-CacheIfOutdated' {

    Context 'When the cache file is empty' {

        # arrange
        Setup -File cache.xml -Content ''
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml]$null
            ToolsVersion = '1.2.3'
            ConfigTimestamp = '456'
        }

        # act
        Clear-CacheIfOutdated -Context $context

        [string]$toolsVersion = $context.CacheXml.files.toolsVersion
        [string]$configTimestamp = $context.CacheXml.files.configTimestamp

        # assert
        It 'should be overwritten with new cache with valid version and timestamp' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
        }
    }

    Context 'When the cache file contains unexpected data' {

        # arrange
        Setup -File cache.xml -Content '<abc/>'
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml]$null
            ToolsVersion = '1.2.3'
            ConfigTimestamp = '456'
        }

        # act
        Clear-CacheIfOutdated -Context $context

        [string]$toolsVersion = $context.CacheXml.files.toolsVersion
        [string]$configTimestamp = $context.CacheXml.files.configTimestamp

        # assert
        It 'should be overwritten with new cache with valid version and timestamp' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
        }
    }

    Context 'When the cache file contains empty root element' {

        # arrange
        Setup -File cache.xml -Content '<files/>'
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml]$null
            ToolsVersion = '1.2.3'
            ConfigTimestamp = '456'
        }

        # act
        Clear-CacheIfOutdated -Context $context

        [string]$toolsVersion = $context.CacheXml.files.toolsVersion
        [string]$configTimestamp = $context.CacheXml.files.configTimestamp

        # assert
        It 'should be overwritten with new cache with valid version and timestamp' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
        }
    }

    Context 'When the cache file has different tools version' {

        # arrange
        Setup -File cache.xml -Content ''
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml]$null
            ToolsVersion = '1.2.2'
            ConfigTimestamp = '456'
        }
        Set-EmptyCacheFile -Context $context
        $context.ToolsVersion = '1.2.3'

        # act
        Clear-CacheIfOutdated -Context $context

        [string]$toolsVersion = $context.CacheXml.files.toolsVersion
        [string]$configTimestamp = $context.CacheXml.files.configTimestamp

        # assert
        It 'should be overwritten with new cache with valid version and timestamp' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
        }
    }

    Context 'When the cache file has different timestamp' {

        # arrange
        Setup -File cache.xml -Content ''
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml]$null
            ToolsVersion = '1.2.3'
            ConfigTimestamp = '789'
        }
        Set-EmptyCacheFile -Context $context
        $context.ConfigTimestamp = '456'

        # act
        Clear-CacheIfOutdated -Context $context

        [string]$toolsVersion = $context.CacheXml.files.toolsVersion
        [string]$configTimestamp = $context.CacheXml.files.configTimestamp

        # assert
        It 'should be overwritten with new cache with valid version and timestamp' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
        }
    }

    Context 'When the cache file has valid version and timestamp' {

        # arrange
        Setup -File cache.xml -Content '<files toolsVersion="1.2.3" configTimestamp="456"><filedata>data</filedata></files>'
        $context = [PSCustomObject]@{
            CacheFile = "$TestDrive\cache.xml"
            CacheXml = [xml](Get-Content -Path $TestDrive\cache.xml)
            ToolsVersion = '1.2.3'
            ConfigTimestamp = '456'
        }

        # act
        Clear-CacheIfOutdated -Context $context

        [string]$toolsVersion = $context.CacheXml.files.toolsVersion
        [string]$configTimestamp = $context.CacheXml.files.configTimestamp
        [string]$filedata = $context.CacheXml.files.filedata

        # assert
        It 'should be left as it is' {
            $toolsVersion | Should Be '1.2.3'
            $configTimestamp | Should Be '456'
            $filedata | Should Be 'data'
        }
    }
}