<#
.SYNOPSIS
Tests if .NET is installed.

.DESCRIPTION
Currently, this function only tests if .NET 2 or 4 is installed.  Perhaps some friendly people out there will extend it to perform further checks?

.LINK
http://msdn.microsoft.com/en-us/kb/kbarticle.aspx?id=318785

.EXAMPLE
Test-DotNet -v2

Demonstrates how to test if .NET 2 is installed.

.EXAMPLE
Test-DotNet -v4 -Full

Demonstrates how to test if the full .NET v4 is installed.
#>
function Test-DotNet
{
    param(
        [Parameter(Mandatory=$true,ParameterSetName='v2')]
        [Switch]
        # Test if .NET 2.0 is installed.
        $V2,

        [Parameter(Mandatory=$true,ParameterSetName='v4Client')]
        [Parameter(Mandatory=$true,ParameterSetName='v4Full')]
        [Switch]
        # Test if .NET 4.0 is installed.
        $V4,

        [Parameter(Mandatory=$true,ParameterSetName='v4Client')]
        [Switch]
        # Test if hte .NET 4 client profile is installed.
        $Client,

        [Parameter(Mandatory=$true,ParameterSetName='v4Full')]
        [Switch]
        # Test if the .NET 4 full profile is installed.
        $Full
    )

    Set-StrictMode -Version 'Latest'

    $runtimeSetupRegPath = switch( $PSCmdlet.ParameterSetName )
    {
        'v2' { 'hklm:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v2.0.50727' }
        'v4Client' { 'hklm:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client' }
        'v4Full' { 'hklm:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' }
        default { Write-Error ('Unknown parameter set ''{0}''.' -f $PSCmdlet.ParameterSetName) }
    }

    if( -not $runtimeSetupRegPath )
    {
        return
    }

    if( -not (Test-RegistryKeyValue -Path $runtimeSetupRegPath -Name 'Install') )
    {
        return $false
    }

    $value = Get-RegistryKeyValue -Path $runtimeSetupRegPath -Name 'Install'
    return ($value -eq 1)
}