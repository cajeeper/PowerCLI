function Update-VMwareTools {
	$curVer = "9.10.5"
	$UpdateArgs = "-NoReboot"
	
	$allVMs = get-vm 
	
	$needTools = $allVMs | ? { $_.Guest.ToolsVersion -ne $curVer -and $_.PowerState -ne "PoweredOff" }

	$options = [System.Management.Automation.Host.ChoiceDescription[]] @("&Update VMs Running Tools", "Update &All VMs that Need Tools", "&View VMs", "&Quit")
	$opt =  $host.UI.PromptForChoice("Proceed with updating VMware Tools?" , " Found VMs: $($allVMs.Count)`n  -Has Outdated Tools Running: $(($needTools | ? { $_.Guest.State -eq "Running"}).Count)`n  -Has No Tools Running: $(($needTools | ? { $_.Guest.State -eq "NotRunning"}).Count)" , $Options, [int]3)

	switch($opt)
	{
	0 { Write-Host "Updating VMs Running Tools..." -ForegroundColor Green; Write-Host "Ctrl-C to cancel"; sleep 10; $needTools | ? { $_.Guest.State -eq "Running"} | % { Write-Host "Starting update for $($_)"; <#try { $_ | Update-Tools $UpdateArgs } catch { Write-Host "Failed to update $_" }#>; } }
	1 { Write-Host "Updating All VMs that Need Tools..." -ForegroundColor Green; Write-Host "Ctrl-C to cancel"; sleep 10; $needTools | % { Write-Host "Starting update for $($_)"; <#try { $_ | Update-Tools $UpdateArgs } catch { Write-Host "Failed to update $_" }#>; }  }
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

#Update-VMwareTools
