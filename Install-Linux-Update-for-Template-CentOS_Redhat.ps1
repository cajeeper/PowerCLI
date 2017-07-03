<#  
 .SYNOPSIS  
  Script to update Template's Linux Updates and copy template - CentOS / Redhat
    
 .DESCRIPTION
  I use this script to convert my template to a VM, start the VM,
  apply any Linux Update, shutdown the VM, and convert it back
  to a template.
  Optionally, it can create a copy of the template to another site
  to maintain a duplicate copy of the template.
 
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2017-07-03
  Contact  : http://www.allthingstechie.net
  Revision : v1.0
  Changes  : v1.0 Original
#>
add-pssnapin VMware.VimAutomation.Core

#Connect-VIServer myvCenterServer.local

#Show Progress
$showProgress = $true


#Update Template Parameters

	#Update Template Name
	$updateTempName = "CentOS-7-x86_64-Minimal-1611"

	#Update Template Local Account to Run Script
	$updateTempUser = "root"
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
$logRoot = "C:\Scripts\Install Linux Updates for Templates\logs"

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
	$template = Get-Template $updateTempName

	#Convert Template to VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Converting Template: $($updateTempName) to VM" -PercentComplete 5 }
	[void]$log.appendline("Converting Template: $($updateTempName) to VM")
	$template | Set-Template -ToVM -Confirm:$false

	#Start VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Starting VM: $($updateTempName)" -PercentComplete 20 }
	[void]$log.appendline("Starting VM: $($updateTempName)")
	Get-VM $updateTempName | Start-VM -RunAsync:$RunAsync

	#Wait for VMware Tools to start
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) 30 seconds to start VMwareTools" -PercentComplete 35 }
	[void]$log.appendline("Giving VM: $($updateTempName) 30 seconds to start VMwareTools")
	sleep 30

	#VM Local Account Credentials for Script
	$cred = New-Object System.Management.Automation.PSCredential $updateTempUser, $updateTempPass

	#Script to run on VM and replace `r`n with `n
	$script = @'
cat /etc/redhat-release
uname -r
yum clean all
yum update -y
'@ -replace "`r`n?","`n"

	#Running Script on Guest VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Running Script on Guest VM: $($updateTempName)" -PercentComplete 50 }
	[void]$log.appendline("Running Script on Guest VM: $($updateTempName)")
	$output = Get-VM $updateTempName | Invoke-VMScript -ScriptText $script -GuestCredential $cred -ScriptType bash
	
	$updatesFound = $output -notmatch "No packages marked for update" -and $output.exitcode -eq 0
	$updateError = !($updatesFound)
	
	if($updatesFound) {
		if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) Linux Updates Loaded" -PercentComplete 65 }
		[void]$log.appendline("Giving VM: $($updateTempName) Linux Updates Loaded")
		[void]$log.appendline($output)
	}
	else {
		if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) No Updates found. Stopping process" -PercentComplete 65 }
		[void]$log.appendline("Giving VM: $($updateTempName) No Updates found. Stopping process")
		[void]$log.appendline($output)
	}
	
	#Shutdown the VM
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Shutting Down VM: $($updateTempName)" -PercentComplete 80 }
	[void]$log.appendline("Shutting Down VM: $($updateTempName)")
	Get-VM $updateTempName | Stop-VMGuest -Confirm:$false

	#Wait for shutdown to finish
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Giving VM: $($updateTempName) 30 seconds to finish Shutting Down" -PercentComplete 90 }
	[void]$log.appendline("Giving VM: $($updateTempName) 30 seconds to finish Shutting Down")
	sleep 30
	
	#Convert VM back to Template
	if($showProgress) { Write-Progress -Activity "Update Template" -Status "Convert VM: $($updateTempName) back to template" -PercentComplete 100 }
	[void]$log.appendline("Convert VM: $($updateTempName) back to template")
	Get-VM $updateTempName | Set-VM -ToTemplate -Confirm:$false
}
catch { 
	[void]$log.appendline("Error:")
	[void]$log.appendline($error)
	[void]$log.appendline($output)
	Throw $error
	#stops post-update copy of template
	$updateError = $true
	}
#---------------------
#End of Update Template
#---------------------
	

#---------------------
#Copy Template
#---------------------

#Copy if copyTemplate true and either updateError false or no existing template
if($copyTemplate -and (!($updateError) -or ((Get-Template | ? {$_.Name -eq $copyTempName}).count -eq 0)))
	try {
		#Remove Existing Template if exists
		Get-Template | ? {$_.Name -eq $copyTempName} | % {
			if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Remove Existing Template: $($copyTempName)" -PercentComplete 30 }
			[void]$log.appendline("Remove Existing Template: $($copyTempName)")
			Get-Template $copyTempName | Remove-Template -DeletePermanently -Confirm:$false
		}

		#Copy Template
		if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Create new VM (Template): Copy Template Source: $($copyTempSource) to New VM: $($copyTempName)" -PercentComplete 60 }
		[void]$log.appendline("Create new VM (Template): Copy Template Source: $($copyTempSource) to New VM: $($copyTempName)")
		New-VM -Name $copyTempName -Template $copyTempSource -VMHost $copyTempESXHost -Datastore $copyTempDatastore -Location $copyTempLocation

		#Change VM to Template
		if($showProgress) { Write-Progress -Activity "Copy Template" -Status "Change new VM to Template: $($copyTempName)" -PercentComplete 90 }
		[void]$log.appendline("Change new VM to Template: $($copyTempName)")
		Get-VM $copyTempName | Set-VM -ToTemplate -Confirm:$false
		
	} catch { 
		[void]$log.appendline("Error:")
		[void]$log.appendline($error)
		Throw $error
	}
}
#---------------------
#End of Copy Template
#---------------------

#Write Log
[void]$log.appendline((("[End Batch - ")+(get-date)+("]")))

writeLog