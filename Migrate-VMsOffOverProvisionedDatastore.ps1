<#  
 .SYNOPSIS  
  Script to intiate migration of VMs if datastore is over provisioned
 
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2015-12-22
  Contact  : http://www.allthingstechie.net
  Revision : v1.0
  Changes  : v1.0 Original
#>
#Connect-VIServer myVcenterServer.local

#Gather my stores and its associated VMs
$myDatastore = get-datastore myDatastoreLun
$myDatastoreVMs = $myDatastore | get-vm

#Migration Destination
$dstDatastore = Get-Datastore myDatastoreDest
$dstIP = "MyESXiHost"

#Gather Sizes - Size and Provisioned Size
$ProvisionedSpaceGB = ($myDatastoreVMs | select ProvisionedSpaceGB | Measure-Object ProvisionedSpaceGB -Sum).Sum
$DatastoreSizeGB = $myDatastore.CapacityMB / 1024

#Threshold for provision alert
$ProvisionedSpaceAlert = .70

#Actual provisioned percent
$ProvisionedPercent = $ProvisionedSpaceGB / $DatastoreSizeGB

if($ProvisionedPercent -gt $ProvisionedSpaceAlert) {
	$msg = "$($myDatastore.Name) datastore is over provisioned by $([math]::Round(($ProvisionedPercent-$ProvisionedSpaceAlert)*100,2))%`n Datastore:$($myDatastore.Name)`n - DatastoreSizeGB: $([math]::Round($DatastoreSizeGB,2))`n - ProvisionedSizeGB: $([math]::Round($ProvisionedSpaceGB,2))`n - ProvisionedPercent: $([math]::Round($ProvisionedPercent*100,2))%"
	Write-Warning $msg
	
	#Move my VMs Move-VM yada yada
	$myDatastoreVMs | % { $_ | Move-VM -Datastore $dstDatastore -Destination $dstIP -VMotionPriority High }
}  
