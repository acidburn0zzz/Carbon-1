
Import-Module -Name 'Carbon'

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[string]
        # The name of the environment variable.
		$Name
	)
    
    Set-StrictMode -Version 'Latest'

    $target = [EnvironmentVariableTarget]::Machine
    $forComputer = ([Environment]::GetEnvironmentVariable($Name,[EnvironmentVariableTarget]::Machine) -ne $null)
    if( -not $forComputer )
    {
        $forUser = ([Environment]::GetEnvironmentVariable($Name,[EnvironmentVariableTarget]::User) -ne $null)
        if( $forUser )
        {
            $target = [EnvironmentVariableTarget]::User
        }
        else
        {
            $forProcess = ([Environment]::GetEnvironmentVariable($Name,[EnvironmentVariableTarget]::Process) -ne $null)
            if( $forProcess )
            {
                $target = [EnvironmentVariableTarget]::Process
            }
        }
    }

    $value = [Environment]::GetEnvironmentVariable($Name)
    Write-Verbose ('{0} = {1}' -f $Name,$value)
    @{
        Name = $Name;
        Ensure = ($value -ne $null);
        Target = $target;
        Value = $value;
    }
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[System.String]
		$Value,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[String]
        [ValidateSet('Machine','User','Process')]
        # The level of the environment variable. Defaults to Machine level.
		$Target = 'Machine'
	)

    Set-StrictMode -Version 'Latest'

    Write-Verbose ('{0} {1} environment variable {1} value to {2}' -f $Ensure,$Target,$Name,$Value)

    foreach( $level in ([Enum]::GetValues([System.EnvironmentVariableTarget])) )
    {
        if( [Environment]::GetEnvironmentVariable($Name,$level) -ne $null )
        {
            if( $PSCmdlet.ShouldProcess(('{0} environment variable {1}' -f $level,$Name), 'remove') )
            {
                Write-Verbose ('Removing {0} variable {1}.' -f $level,$Name)
                [Environment]::SetEnvironmentVariable($Name,$null,$level)
            }
        }
    }

    if( $Ensure -eq 'Present' )
    {
        Write-Verbose ('Setting {0} variable {1} = {2}.' -f $Target,$Name,$Value)
        Set-EnvironmentVariable -Name $Name -Value $Value -ForProcess:($Target -eq 'Process') -ForUser:($Target -eq 'User') -ForComputer:($Target -eq 'Machine')
        if( $Target -eq 'User' -or $Target -eq 'Machine' )
        {
            Write-Verbose ('Setting Process environment variable {0} = {1}.' -f $Name,$Value)
            Set-EnvironmentVariable -Name $Name -Value $Value -ForProcess
        }
    }

}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[System.String]
		$Value,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[String]
        [ValidateSet('Machine','User','Process')]
        # The level of the environment variable. Defaults to Machine level.
		$Target = 'Machine'
	)

    Set-StrictMode -Version 'Latest'

    Write-Verbose ('Getting current value of ''{0}'' environment variable.' -f $Name)

    $resource = $null
    $resource = Get-TargetResource -Name $Name
    if( -not $resource )
    {
        Write-Verbose ('Environment variable ''{0}'' not found.' -f $Name)
        return $false
    }

    if( $Ensure -eq 'Present' )
    {
        Write-Verbose ('{0} -eq {1} -and {2} -eq {3}' -f $resource.Value,$Value,$resource.Target,$Target)
        return ($resource.Value -eq $Value -and $resource.Target -eq $Target);
    }
    else
    {
        Write-Verbose ('{0}@{1}: {2}' -f $Name,$Target,$Value)
        return ($resource.Value -eq $null)
    }
}


Export-ModuleMember -Function '*-TargetResource'

