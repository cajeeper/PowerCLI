<#  
 .SYNOPSIS  
  Script to update Template's Windows Updates
    
 .DESCRIPTION
  I use this script to convert my template to a VM, start the VM,
  apply any Windows Update, shutdown the VM, and convert it back
  to a template.
  Optionally, it can create a copy of the template to another site to maintain
 
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2016-07-20
  Contact  : http://www.allthingstechie.net
  Revision : v1.2
  Changes  : v1.0 Original
			 v1.1 Added Logging, 2016-04-15
			 v1.2 Added template copy to post update, 2016-07-20

#>
#add-pssnapin VMware.VimAutomation.Core

#Connect-VIServer myvCenterServer.local

#Show Progress
$showProgress = $true


#Update Template Parameters

	#Update Template Name
	$updateTempName = "Windows Server 2012 R2 Datacenter"

	#Update Template Local Account to Run Script
	$updateTempUser = "Administrator"
	$updateTempPass = ConvertTo-SecureString 'SomePassword' -AsPlainText -Force


#Copy Template Parameters

	#Enable Post Update Copy of Template
	$copyTemplate = $true

	#Copy Template Name
	$copyTempSource = $updateTempName
	$copyTempName = "$($copyTempSource)_copy"
	$copyTempDatastore = "mydatastore"
	$copyTempLocation = Get-Folder -Location "SiteName" "Templates"
	$copyTempESXHost = "myESXHost.local"


#Log Parameters and Write Log Function
$logRoot = "C:\Scripts\Install Windows Updates for Templates\logs"

$log = New-Object -TypeName "System.Text.StringBuilder" "";

function writeLog {
	$exist = Test-Path $logRoot\update-$updateTempName.log
	$logFile = New-Object System.IO.StreamWriter("$logRoot\update-$($updateTempName).log", $exist)
	$logFile.write($log)
	$logFile.close()
}

[void]$log.appendline((("[Start Batch - ")+(get-date)+("]")))
[void]$log.appendline($error)

#---------------------
#Update Template
#---------------------

try {
	#Get Template
	$template = get-template $updateTempName

	#Convert Template to VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Converting Template: $($updateTempName) to VM" -PercentComplete 5 }
	[void]$log.appendline("Converting Template: $($updateTempName) to VM")
	$template | Set-Template -ToVM -Confirm:$false

	#Start VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Starting VM: $($updateTempName)" -PercentComplete 20 }
	[void]$log.appendline("Starting VM: $($updateTempName)")
	get-vm $updateTempName | Start-VM -RunAsync:$RunAsync

	#Wait for VMware Tools to start
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) 30 seconds to start VMwareTools" -PercentComplete 35 }
	[void]$log.appendline("Giving VM: $($updateTempName) 30 seconds to start VMwareTools")
	sleep 30

	#VM Local Account Credentials for Script
	$cred = New-Object System.Management.Automation.PSCredential $updateTempUser, $updateTempPass

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
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Running Script on Guest VM: $($updateTempName)" -PercentComplete 50 }
	[void]$log.appendline("Running Script on Guest VM: $($updateTempName)")
	get-vm $updateTempName | Invoke-VMScript -ScriptText $script -GuestCredential $cred
	
	#Wait for Windows Updates to finish after reboot
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) 600 seconds to finish rebooting after Windows Update" -PercentComplete 65 }
	[void]$log.appendline("Giving VM: $($updateTempName) 600 seconds to finish rebooting after Windows Update")
	sleep 600

	#Shutdown the VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Shutting Down VM: $($updateTempName)" -PercentComplete 80 }
	[void]$log.appendline("Shutting Down VM: $($updateTempName)")
	get-vm $updateTempName | Stop-VMGuest -Confirm:$false

	#Wait for shutdown to finish
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) 30 seconds to finish Shutting Down" -PercentComplete 90 }
	[void]$log.appendline("Giving VM: $($updateTempName) 30 seconds to finish Shutting Down")
	sleep 30
	
	#Convert VM back to Template
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Convert VM: $($updateTempName) back to template" -PercentComplete 100 }
	[void]$log.appendline("Convert VM: $($updateTempName) back to template")
	get-vm $updateTempName | Set-VM -ToTemplate -Confirm:$false
}
catch { 
	[void]$log.appendline("Error:")
	[void]$log.appendline($error)
	Write-Error $error
	#stops post-update copy of template
	$updateError = $true
	}
#---------------------
#End of Update Template
#---------------------
	

#---------------------
#Copy Template
#---------------------

if($copyTemplate -and !($updateError)) {
	try {
		#Remove Existing Template if exists
		get-template | ? {$_.Name -eq $copyTempName} | % {
			if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Remove Existing Template: $($copyTempName)" -PercentComplete 30 }
			[void]$log.appendline("Remove Existing Template: $($copyTempName)")
			Get-Template "$($copyTempName)" | Remove-Template -DeletePermanently -Confirm:$false
		}

		#Copy Template
		if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Create new VM (Template): Copy Template Source: $($copyTempSource) to New VM: $($copyTempName)" -PercentComplete 60 }
		[void]$log.appendline("Create new VM (Template): Copy Template Source: $($copyTempSource) to New VM: $($copyTempName)")
		New-VM -Name "$($copyTempName)" -Template $copyTempSource -VMHost $copyTempESXHost -Datastore $copyTempDatastore -Location $copyTempLocation

		#Change VM to Template
		if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Change new VM to Template: $($copyTempName)" -PercentComplete 90 }
		[void]$log.appendline("Change new VM to Template: $($copyTempName)")
		Get-VM "$($copyTempName)" | Set-VM -ToTemplate -Confirm:$false
		
	} catch { 
		[void]$log.appendline("Error:")
		[void]$log.appendline($error)
		Write-Error $error
	}
}
#---------------------
#End of Copy Template
#---------------------

#Write Log
[void]$log.appendline((("[End Batch - ")+(get-date)+("]")))

writeLog