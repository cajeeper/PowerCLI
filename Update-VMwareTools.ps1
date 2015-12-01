<#  
 .SYNOPSIS  
  Function to trigger VMware Tools update on VMs.  
    
 .DESCRIPTION   
  You can specify a single VM, multiple VMs, or discover all VMs in your environment and either trigger updates or view the results.  
    
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2015-11-30  
  Contact  : http://www.allthingstechie.net
  Revision : v1  
   
 .PARAMETER VM  
  Name of VM 
  or
  
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
 #> 
Function Update-VMwareTools {
     [CmdletBinding()]  
      param (  
           [parameter(ValueFromPipeline=$True)] $VM
		   )

  End {
 
    $list = @($input)
    $VM = if($list.Count) { $list } 
      elseif(!$VM) { @(get-vm) } 
      else { @($VM) }
 
	$curVer = "9.10.5"
	
	$allVMs = get-vm $VM
	
	$needTools = $allVMs | ? { $_.Guest.ToolsVersion -ne $curVer -and $_.PowerState -ne "PoweredOff" }

	$options = [System.Management.Automation.Host.ChoiceDescription[]] @("&Update VMs Running Tools", "Update &All VMs that Need Tools", "&View VMs", "&Quit")
	$opt =  $host.UI.PromptForChoice("Proceed with updating VMware Tools?" , " Found VMs: $($allVMs.Count)`n  -Has Outdated Tools Running: $(($needTools | ? { $_.Guest.State -eq "Running"}).Count)`n  -Has No Tools Running: $(($needTools | ? { $_.Guest.State -eq "NotRunning"}).Count)" , $Options, [int]3)

	switch($opt)
	{
	0 { Write-Host "Updating VMs Running Tools..." -ForegroundColor Green; Write-Host "Ctrl-C to cancel"; sleep 10; $needTools | ? { $_.Guest.State -eq "Running"} | % { Write-Host "Starting update for $($_.Name)"; try { $_ | Update-Tools -NoReboot } catch { Write-Host "Failed to update $($_)" }; } }
	1 { Write-Host "Updating All VMs that Need Tools..." -ForegroundColor Green; Write-Host "Ctrl-C to cancel"; sleep 10; $needTools | % { Write-Host "Starting update for $($_.Name)"; try { $_ | Update-Tools -NoReboot } catch { Write-Host "Failed to update $($_)" }; }  }
	2 { $allVMs | % {
		New-Object -TypeName PSCustomObject -Property ([ordered]@{
			Name= $_.Name
			Host= $_.Host
			ToolState= $_.Guest.State
			ToolVersion= $_.Guest.ToolsVersion
			GuestOS = $_.Guest.OSFullName
		}) } | Out-GridView -Title "All VMs"
		
	}	
	default {}
	}
}
}

#Update-VMwareTools
