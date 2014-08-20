# Copyright 2012 Aaron Jensen
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Get-DscError
{
    <#
    .SYNOPSIS
    Gets DSC errors from a computer's event log.

    .DESCRIPTION
    When a DSC Local Configuration Manager (LCM) encounters errors, they are written to the Windows event log. This function returns them.

    By default, errors on the local computer are returned. You can return errors from multiple computers via the `ComputerName` parameter.

    You can filter the results further with the `StartTime` and `EndTime` parameters. `StartTime` will only return entries after the given time. `EndTime` will return entries before the given time.

    If no items are found, nothing is returned.

    It can take several seconds for event log entries to get written to the log, so you might not get results back. If you want to wait for entries to come back, use the `-Wait` switch. You can control how long to wait (in seconds) via the `WaitTimeoutSeconds` parameter. The default is 10 seconds.

    When getting errors on a remote computer, that computer must have Remote Event Log Management firewall rules enabled. To enable them, run

        Get-FirewallRule -Name '*Remove Event Log Management*' |
            ForEach-Object { netsh advfirewall firewall set rule name= $_.Name new enable=yes }

    .OUTPUTS
    System.Diagnostics.Eventing.Reader.EventLogRecord

    .LINK
    Write-DscError

    .EXAMPLE
    Get-DscError

    Demonstrates how to get all the DSC errors from the local computer.

    .EXAMPLE
    Get-DscError -ComputerName 10.1.2.3

    Demonstrates how to get all the DSC errors from a specific computer.

    .EXAMPLE
    Get-DscError -StartTime '8/1/2014 0:00'

    Demonstrates how to get errors that occurred *after* a given time.

    .EXAMPLE
    Get-DscError -EndTime '8/30/2014 11:59:59'

    Demonstrates how to get errors that occurred *before* a given time.

    .EXAMPLE
    Get-DscError -StartTime '8/1/2014 2:58 PM' -Wait -WaitTimeoutSeconds 5

    Demonstrates how to wait for entries that match the specified criteria to appear in the event log. It can take several seconds between the time a log entry is written to when you can read it.
    #>
    [CmdletBinding(DefaultParameterSetName='NoWait')]
    [OutputType([Diagnostics.Eventing.Reader.EventLogRecord])]
    param(
        [string]
        # The computer whose DSC errors to return.
        $ComputerName,

        [DateTime]
        # Get errors that occurred after this date/time.
        $StartTime,

        [DateTime]
        # Get errors that occurred before this date/time.
        $EndTime,

        [Parameter(Mandatory=$true,ParameterSetName='Wait')]
        [Switch]
        # Wait for entries to appear, as it can sometimes take several seconds for entries to get written to the event log.
        $Wait,

        [Parameter(ParameterSetName='Wait')]
        [uint32]
        # The time to wait for entries to appear before giving up. Default is 10 seconds. There is no way to wait an infinite amount of time.
        $WaitTimeoutSeconds = 10
    )

    Set-StrictMode -Version 'Latest'

    $filter = @{ 
                    LogName = 'Microsoft-Windows-DSC/Operational'; 
                    ID = 4103;
                    Level = 2;
              }

    if( $StartTime )
    {
        $filter.StartTime = $StartTime
    }

    if( $EndTime )
    {
        $filter.EndTime = $EndTime
    }

    $startedAt = Get-Date
    $events = @()
    $getWinEventParams = @{ }
    if( $ComputerName )
    {
        # Check that the computers exist
        if( -not (Test-Connection -ComputerName $ComputerName -Quiet) )
        {
            Write-Error -Message ('Computer ''{0}'' not found.' -f $ComputerName)
            return
        }

        $getWinEventParams.ComputerName = $ComputerName
    }

    try
    {
        while( -not ($events = Get-WinEvent @getWinEventParams -FilterHashtable $filter -ErrorAction Ignore) )
        {
            if( $PSCmdlet.ParameterSetName -ne 'Wait' )
            {
                break
            }

            Start-Sleep -Milliseconds 100

            [timespan]$duration = (Get-Date) - $startedAt
            if( $duration.TotalSeconds -gt $WaitTimeoutSeconds )
            {
                break
            }
        }
    }
    catch
    {
        if( $_.Exception.Message -eq 'The RPC server is unavailable' )
        {
            Write-Error -Message ("Unable to connect to '{0}': it looks like Remote Event Log Management isn't running or is blocked by the computer's firewall. To allow this traffic through the firewall, run the following command on '{0}':`n`tGet-FirewallRule -Name '*Remove Event Log Management*' |`n`t`t ForEach-Object {{ netsh advfirewall firewall set rule name= `$_.Name new enable=yes }}." -f $ComputerName)
        }
        else
        {
            Write-Error -Exception $_.Exception
        }
    }

    $events
}