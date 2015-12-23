<#  
 .SYNOPSIS  
  Script to download VSAN HCL for VSAN Health Check Offline
 
 .NOTES   
  Author   : Justin Bennett   
  Date     : 2015-12-22
  Contact  : http://www.allthingstechie.net
  Revision : v1.0
  Changes  : v1.0 Original
#>
#Connect-VIServer myVcenterServer.local

$storageDir = "c:\users\username\desktop"
$webclient = New-Object System.Net.WebClient
$url = "http://partnerweb.vmware.com/service/vsan/all.json"
$file = "$storageDir\all.json"

write-progress "Downloading file $($url)`n Saving to $($file)"
$webclient.DownloadFile($url,$file)

#PowerCLI to update HCL DB to be added...
