$storageDir = "c:\users\username\desktop"
$webclient = New-Object System.Net.WebClient
$url = "http://partnerweb.vmware.com/service/vsan/all.json"
$file = "$storageDir\all.json"
$webclient.DownloadFile($url,$file)
