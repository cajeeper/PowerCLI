<#  
 .SYNOPSIS  
  Script to update Template's Windows Updates
    
 .DESCRIPTION
  I use this script to convert my template to a VM, start the VM,
  apply any Windows Update, shutdown the VM, and convert it back
  to a template.
 
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2016-04-15
  Contact  : http://www.allthingstechie.net
  Revision : v1.1
  Changes  : v1.0 Original
			 v1.1 Add Logging

#>
#add-pssnapin VMware.VimAutomation.Core

#Connect-VIServer myvCenterServer.local

#Show Progress
$showProgress = $true

#Template/VM Name
$name = "Windows Server 2012 R2 Datacenter"
#Template/VM Local Account to Run Script
$user = "Administrator"
$pass = ConvertTo-SecureString 'SomePassword' -AsPlainText -Force

#Log and Write Log Function
$logRoot = "C:\Scripts\Install Windows Updates for Templates\logs"

$log = New-Object -TypeName "System.Text.StringBuilder" "";

function writeLog {
	$exist = Test-Path $logRoot\update-$name.log
	$logFile = New-Object System.IO.StreamWriter("$logRoot\update-$($name).log", $exist)
	$logFile.write($log)
	$logFile.close()
}

[void]$log.appendline((("[Start Batch - ")+(get-date)+("]")))

try {
	#Get Template
	$template = get-template $name

	#Convert Template to VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Converting Template: $($name) to VM" -PercentComplete 5 }
	[void]$log.appendline("Converting Template: $($name) to VM")
	$template | Set-Template -ToVM -Confirm:$false

	#Start VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Starting VM: $($name)" -PercentComplete 20 }
	[void]$log.appendline("Starting VM: $($name)")
	get-vm $name | Start-VM -RunAsync:$RunAsync

	#Wait for VMware Tools to start
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($name) 30 seconds to start VMwareTools" -PercentComplete 35 }
	[void]$log.appendline("Giving VM: $($name) 30 seconds to start VMwareTools")
	sleep 30

	#VM Local Account Credentials for Script
	$cred = New-Object System.Management.Automation.PSCredential $user, $pass

	#Script to run on VM
	$script = "Function WSUSUpdate {
		  param ( [switch]`$rebootIfNecessary,
				  [switch]`$forceReboot)  
		`$Criteria = ""IsInstalled=0 and Type='Software'""
		`$Searcher = New-Object -ComObject Microsoft.Update.Searcher
		try {
			`$SearchResult = `$Searcher.Search(`$Criteria).Updates
			if (`$SearchResult.Count -eq 0) {
				Write-Output ""There are no applicable updates.""
				exit
			} 
			else {
				`$Session = New-Object -ComObject Microsoft.Update.Session
				`$Downloader = `$Session.CreateUpdateDownloader()
				`$Downloader.Updates = `$SearchResult
				`$Downloader.Download()
				`$Installer = New-Object -ComObject Microsoft.Update.Installer
				`$Installer.Updates = `$SearchResult
				`$Result = `$Installer.Install()
			}
		}
		catch {
			Write-Output ""There are no applicable updates.""
		}
		If(`$rebootIfNecessary.IsPresent) { If (`$Result.rebootRequired) { Restart-Computer -Force} }
		If(`$forceReboot.IsPresent) { Restart-Computer -Force }
	}

	WSUSUpdate -rebootIfNecessary
	"
	
	#Running Script on Guest VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Running Script on Guest VM: $($name)" -PercentComplete 50 }
	[void]$log.appendline("Running Script on Guest VM: $($name)")
	get-vm $name | Invoke-VMScript -ScriptText $script -GuestCredential $cred
	
	#Wait for Windows Updates to finish after reboot
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($name) 600 seconds to finish rebooting after Windows Update" -PercentComplete 65 }
	[void]$log.appendline("Giving VM: $($name) 600 seconds to finish rebooting after Windows Update")
	sleep 600

	#Shutdown the VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Shutting Down VM: $($name)" -PercentComplete 80 }
	[void]$log.appendline("Shutting Down VM: $($name)")
	get-vm $name | Stop-VMGuest -Confirm:$false

	#Wait for shutdown to finish
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($name) 30 seconds to finish Shutting Down" -PercentComplete 90 }
	[void]$log.appendline("Giving VM: $($name) 30 seconds to finish Shutting Down")
	sleep 30
	
	#Convert VM back to Template
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Convert VM: $($name) back to template" -PercentComplete 100 }
	[void]$log.appendline("Convert VM: $($name) back to template")
	get-vm $name | Set-VM -ToTemplate -Confirm:$false
}
catch { 
	[void]$log.appendline("Error:")
	[void]$log.appendline($error)
	Write-Error $error
	}

[void]$log.appendline((("[End Batch - ")+(get-date)+("]")))

writeLog
