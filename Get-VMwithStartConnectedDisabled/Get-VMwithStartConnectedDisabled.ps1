
Function Get-VMwithStartConnectedDisabled {
<#
.SYNOPSIS
	This function will take in a PowerCLI VM object and inspect each network adapter to see if any active network connections are not set to connect at system start-up.

.DESCRIPTION
	This function grew from the continued discovery of running VMs with misconfiguration of network connections that are only discovered after the VM's reboot. This returns only VMs with a active Network Adapter that is Connected, but not set to connect on reboot.

.EXAMPLE
	PS C:\>Get-VM | Get-VMwithStartConnectedDisabled

	This example will find the any VM and return results if a network adapter will not reconnect on reboot.
.EXAMPLE
	PS C:\>Get-VM test-01 | Get-VMwithStartConnectedDisabled

	This example will check the VM named 'test-01' and return results if a network adapter will not reconnect on reboot.
.EXAMPLE
	PS C:\>Get-VMwithStartConnectedDisabled -VMs (Get-VM test-01)

	This example will check the VM named 'test-01' and return results if a network adapter will not reconnect on reboot.
.NOTE
	This function was tested on vCenter 6.0 with VMware vSphere PowerCLI 6.0 Release 1 build 2548067 
	Author:Justin Bennett
	Last Modified: 9/15/2015
#>
    [CmdletBinding()]
	Param(
	[Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
	[array]$VMs
	)
	process {
		foreach ($vm in $VMs) {
			$netadapters = ($vm | Get-NetworkAdapter);
			foreach ($netadapter in $netadapters) {
				if ($netadapter.ConnectionState.StartConnected -eq $false -and $netadapter.ConnectionState.Connected -eq $true) {
					[pscustomobject]@{
						VMName			=	$vm.name
						VMHost			=	$vm.host
						NetName			=	$netadapter.Name
						NetNetwork		=	$netadapter.NetworkName
						NetConnected 	=	$netadapter.ConnectionState.Connected
						NetStartConnected =	$netadapter.ConnectionState.StartConnected
					}
				}
			}
		}
	}
}

# Get all the VMs (if already connected to vCenter) and check them
#  Get-VM | Get-VMwithStartConnectedDisabled


# Different ways of doing the same as before 

#  Get-VM | Get-VMwithStartConnectedDisabled | ft

#  $results = Get-VM | Get-VMwithStartConnectedDisabled
#  $results | ft


# Get VMs test1, test2, and test3 and check them
#  $vms = Get-VM test1, test2, test3
#  Get-VMwithStartConnectedDisabled -VMs $vms

