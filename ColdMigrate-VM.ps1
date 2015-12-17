<#  
 .SYNOPSIS  
  Script to intiate migration of VM that is not able to be migrated live/high priority
    
 .DESCRIPTION
  When migrating VMs between ESXi hosts that have different hardware or configurations,
  you're not always allowed to perform live/high priority migrations. This script allows
  for this process to happen unattended or scheduled. There's - as of yet - no fail safe
  checking, just the simple (Shutdown) (Move) (Start) tasks with easy to enter variables.
 
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2015-12-17
  Contact  : http://www.allthingstechie.net
  Revision : v1.0
  Changes  : v1.0 Original
#>

$vmName = "My-VM1"
$ip = "192.168.01"
$dstDatastore = Get-Datastore MyDatastore
$dstIP = "MyESXiHost"

#shutdown VM via VMware Tools
$nul = get-vm -name $vmName | Stop-VMGuest -Confirm:$false # -RunAsync:$RunAsync

#wait for VM to stop responding - Check for ping response
while (Test-Connection -Quiet $ip -Count 1) { sleep 5; }

#wait for VM to stop responding - Check VM PowerState, double check
while ((Get-VM -Name $vmName).PowerState -eq "PoweredOn") { sleep 5; }

#migrate the VM
Get-VM -Name $vmName | Move-VM -Datastore $dstDatastore -Destination $dstIP 

#start VM
Get-VM -Name $vmName | Start-VM