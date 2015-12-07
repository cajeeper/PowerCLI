<#  
 .SYNOPSIS  
  Function to trigger VMware Tools update on VMs.  
    
 .DESCRIPTION   
  You can specify a single VM, multiple VMs, or discover all VMs in your environment and either trigger updates or view the VM(s) found.  
    
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2015-12-07  
  Contact  : http://www.allthingstechie.net
  Revision : v1.1
  Changes  : v1.0 Original
			 v1.1 Changed version dependency to build number of VMware tools
   
 .PARAMETER VM  
  Name of VM 
  or
  VM Object from Get-VM

 .PARAMETER MinimumBuildVersion
  Minimum VMware Tools Build Number Desired
  See https://packages.vmware.com/tools/versions for specific builds
  
 .PARAMETER Update
  Run updates for VMware Tools without prompt

 .PARAMETER UpdateAll
  Run updates for all VMs VMware Tools without prompt  
 
 .PARAMETER ViewOnly
  View all VMs int out-grid without prompt  
  
 .EXAMPLE  
  C:\PS> #Update any VM
  C:\PS> Update-VMwareTools
  
 .EXAMPLE  
  C:\PS> #Update Specific VM
  C:\PS> Update-VMwareTools My-VM1
  
 .EXAMPLE  
  C:\PS> #Update Specific VM
  C:\PS> Get-VM My-VM1 | Update-VMwareTools
  
 .EXAMPLE  
  C:\PS> #Update Specific VMs
  C:\PS> Update-VMwareTools My-VM*

 .EXAMPLE  
  C:\PS> #Update Specific VMs
  C:\PS> Get-VM My-VM* | Update-VMwareTools
  
 .EXAMPLE  
  C:\PS> #Update Cluster Specific VMs
  C:\PS> Get-VMHost | ? { $_.Parent -match "My-Cluster1" } | Get-VM | Update-VMwareTools 
 #> 
Function Update-VMwareTools {
     [CmdletBinding()]  
      param (  
           [parameter(Mandatory=$True,ValueFromPipeline=$True)] $VM,
		   [parameter(Mandatory=$False)] [ValidateScript({$_ -ge 0})] [Int] $MinimumBuildVersion = 9541,
		   [parameter(Mandatory=$False)] [boolean] $Update = $False,
		   [parameter(Mandatory=$False)] [boolean] $UpdateAll = $False,
		   [parameter(Mandatory=$False)] [boolean] $ViewOnly = $False
		   )
  End {
 
    $list = @($input)
    $VM = if($list.Count) { $list } 
      elseif(!$VM) { @(get-vm) } 
      else { @($VM) }

	$allVMs = get-vm $VM
	
	$needTools = $allVMs | ? { $_.Guest.ExtensionData.ToolsVersion -lt $MinimumBuildVersion -and $_.PowerState -ne "PoweredOff" }

	if (!($Update) -and !($UpdateAll) -and !($ViewOnly)) {
		$options = [System.Management.Automation.Host.ChoiceDescription[]] @("&Update VMs Running Tools", "Update &All VMs that Need Tools", "&View VMs", "&Quit")
		$opt =  $host.UI.PromptForChoice("Proceed with updating VMware Tools?" , " Found VMs: $($allVMs.Count)`n  -Has Outdated Tools Running: $(($needTools | ? { $_.Guest.State -eq "Running"}).Count)`n  -Has No Tools Running: $(($needTools | ? { $_.Guest.State -eq "NotRunning"}).Count)" , $Options, [int]3)
	} else { 
		if($Update) { $opt = 0 }
		if($UpdateAll) { $opt = 1 }
		if($ViewOnly) { $opt = 2 }
	}

	switch($opt)
	{
	0 { Write-Verbose "Updating VMs Running Tools..." -ForegroundColor Green; Write-Verbose "Ctrl-C to cancel"; sleep 10; $needTools | ? { $_.Guest.State -eq "Running"} | % { Write-Verbose "Starting update for $($_.Name)"; try { $_ | Update-Tools -NoReboot } catch { Write-Warning "Failed to update $($_)" }; } }
	1 { Write-Verbose "Updating All VMs that Need Tools..." -ForegroundColor Green; Write-Verbose "Ctrl-C to cancel"; sleep 10; $needTools | % { Write-Verbose "Starting update for $($_.Name)"; try { $_ | Update-Tools -NoReboot } catch { Write-Warning "Failed to update $($_)" }; }  }
	2 { $allVMs | % {
		New-Object -TypeName PSCustomObject -Property ([ordered]@{
			Name= $_.Name
			Host= $_.Host
			ToolState= $_.Guest.State
			ToolVersion= $_.Guest.ExtensionData.ToolsVersion
			GuestOS = $_.Guest.OSFullName
			NeedUpgrade= if ($_.Guest.ExtensionData.ToolsVersion -lt $MinimumBuildVersion) { $True } else { $false }
		}) } | Out-GridView -Title "All VMs - Minimum VMware Tools Build Version $($MinimumBuildVersion)"
		
	}	
	default {}
	}
}
}

#Update-VMwareTools
