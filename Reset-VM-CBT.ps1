<#  
 .SYNOPSIS  
  Script reset VMs CBT and tag them as being reset if ESXi600-201511001 has been loaded on its host.
    
 .DESCRIPTION
  CBT Bug VMWare KB 2137546 is no bueno. I wanted a way to patch VMs possibly affected
  and keep track of ones that were patched - so as I progress through and patch for
  this bug, I don't have to keep running the patch process on  VMs multiple time
  unnecessarily.
 
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2015-12-23
  Contact  : http://www.allthingstechie.net
  Revision : v1.0
  Changes  : v1.0 Original
#>
#Connect-VIServer myvCenterServer.local

#Show Progress
$showProgress = $true

#Gather VM Hosts
$ESXHosts = Get-VMHost

#Gather VM Hosts that have corrected for CBT Bug build
$patchedESXHosts =  $ESXHosts | ? { $_.Build -ge 3247720 }

#Gather VMs from ESX hosts with corrected for CBT Bug build
$VMs = $patchedESXHosts | Get-VM

#Create tags if necessary
$nul = New-TagCategory PowerCLI -ErrorAction SilentlyContinue
$nul = New-Tag -Name ResetCBT -Category PowerCLI -Description "bit.ly/1U5nyxz" -ErrorAction SilentlyContinue

#Get the ResetCBT Tag
$Tag = Get-Tag ResetCBT

#VMs already patched
$existingResetCBTVMs = (Get-TagAssignment -Category "PowerCLI" | ? { $_.Tag.Name -eq $Tag.Name -and $_.Entity.Uid -like "*VirtualMachine=*"} | select Entity).Entity

#Gather VMs not already CBT Reset and ChangeTrackingEnabled is Enabled (No need to reset if CBT already disabled)
$resetCBTVMs = $VMs | ? { $_.Id -notin $existingResetCBTVMs.Id -and ($_.ExtensionData.Config).ChangeTrackingEnabled }
$resetCBTVMsCount = 0

if ($resetCBTVMs.Count -gt 0) { $resetCBTVMs | % {$i=0} {
		$i++
		if ($_.PowerState -eq "PoweredOn" -and ($_ | Get-View).snapshot -eq $null) {
			try {
				#Disable CBT Spec
				if($showProgress) { Write-Progress -Activity "Reset-VM CBT" -Status "$($i)/$($resetCBTVMs.Count): VM:$($_.Name) - Disabling CBT" -PercentComplete (($i/$resetCBTVMs.Count)*100) }
				$VMConf = New-Object VMware.Vim.VirtualMachineConfigSpec 
				$VMConf.ChangeTrackingEnabled = $false

				$_.ExtensionData.ReconfigVM($VMConf)

				#Creating snapshot
				if($showProgress) { Write-Progress -Activity "Reset-VM CBT" -Status "$($i)/$($resetCBTVMs.Count): VM:$($_.Name) - Creating Snapshot to Clear CBT" -PercentComplete (($i/$resetCBTVMs.Count)*100) }
				$snap=$_ | New-Snapshot -Name 'Clear CBT'
				
				#Removing snapshot
				if($showProgress) { Write-Progress -Activity "Reset-VM CBT" -Status "$($i)/$($resetCBTVMs.Count): VM:$($_.Name) - Removing Snapshot" -PercentComplete (($i/$resetCBTVMs.Count)*100) }
				$snap | Remove-Snapshot -confirm:$false
				
				#Enable CBT
				if($showProgress) { Write-Progress -Activity "Reset-VM CBT" -Status "$($i)/$($resetCBTVMs.Count): VM:$($_.Name) - Enabling CBT" -PercentComplete (($i/$resetCBTVMs.Count)*100) }
				$VMConf.ChangeTrackingEnabled = $true
				$_.ExtensionData.ReconfigVM($VMConf)
				
				#Tagging Reset CBT VM
				$nul = $_ | New-TagAssignment $Tag
				
				$resetCBTVMsCount++
			} catch { write-warning "Failed to reset CBT on VM: $($_.Name)" }
		} else { 
			if($_.PowerState -ne "PoweredOn") { write-warning "VM: $($_.Name) Not completed - Needs to be in PoweredOn state" }
			if(($_ | Get-View).snapshot -ne $null) { write-warning "VM: $($_.Name) Not completed - Needs to have no existing snapshots" }
		}
	}
} else { write-warning "No VMs to Reset CBT on" }

New-Object -TypeName PSCustomObject -Property ([ordered]@{
	ESXHosts = $ESXHosts.Count
	patchedESXHosts = $patchedESXHosts.Count
	VMCount = $VMs.Count
	existingResetCBTVMs = $existingResetCBTVMs.Count
	resetCBTVMs = $resetCBTVMs.Count
	CompletedCBTVMs = $resetCBTVMsCount
})

