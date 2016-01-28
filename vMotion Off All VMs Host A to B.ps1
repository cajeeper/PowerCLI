#Show Progress
$showProgress = $true
#maintenance host
$srchostesx = "esxA.domain.local"
#temp VM host
$dsthostesx = "esxB.domain.local"

#VMs to be migrated around
$vms = get-vm | ? { $_.vmhost -like $srchostesx }

#Disconenct any cds as needed
# $vms | % { get-vm -name $_.name | Get-CDDrive  } | ? { $_.IsoPath -like "*.iso" -OR $_.HostDevice -match "/" } | % { $_ | Set-CDDrive -NoMedia -Confirm:$false }

#move VMs off
if ($vms.Count -gt 0) { $vms | % {$i=0} { 
	$i++
	if($showProgress) { Write-Progress -Activity "vMotion Off All VMs: $($srchostesx) to $($dsthostesx)" -Status "$($i)/$($vms.Count): VM:$($_.Name) - Attempting to vMotion to $($dsthostesx)..." -PercentComplete (($i/$vms.Count)*100) }
	Move-VM $_ -Destination $dsthostesx -VMotionPriority High
	if($showProgress) { Write-Progress -Activity "vMotion Off All VMs: $($srchostesx) to $($dsthostesx)" -Status "$($i)/$($vms.Count): VM:$($_.Name) - Pausing 10 seconds..." -PercentComplete (($i/$vms.Count)*100) }
	sleep 10
	}
}

#enter host maintenance 
Get-VMHost -Name $srchostesx | Set-VMHost -State Maintenance
#enter host maintenance - VSAN
# Get-View -ViewType HostSystem -Filter @{"Name" = $srchostesx }|?{!$_.Runtime.InMaintenanceMode}|%{$_.EnterMaintenanceMode(0, $false, (new-object VMware.Vim.HostMaintenanceSpec -Property @{vsanMode=(new-object VMware.Vim.VsanHostDecommissionMode -Property @{objectAction=[VMware.Vim.VsanHostDecommissionModeObjectAction]::NoAction})}))}

#
# do my thang ¯\_(ツ)_/¯
#

#exit host maintenance
Get-VMHost -name $srchostesx | Set-VMHost -State Connected

#move VMs back
if ($vms.Count -gt 0) { $vms | % {$i=0} { 
	$i++
	if($showProgress) { Write-Progress -Activity "vMotion Off All VMs: $($dsthostesx) to $($srchostesx)" -Status "$($i)/$($vms.Count): VM:$($_.Name) - Attempting to vMotion to $($srchostesx)..." -PercentComplete (($i/$vms.Count)*100) }
	Move-VM $_ -Destination $srchostesx -VMotionPriority High
	if($showProgress) { Write-Progress -Activity "vMotion Off All VMs: $($dsthostesx) to $($srchostesx)" -Status "$($i)/$($vms.Count): VM:$($_.Name) - Pausing 10 seconds..." -PercentComplete (($i/$vms.Count)*100) }
	sleep 10
	}
}
