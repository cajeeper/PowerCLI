$srchostesx = "esxA.domain.local"
$dsthostesx = "esxB.domain.local"
$vms = get-vm | ? { $_.vmhost -like $srchostesx }

foreach($vm in $vms) { Move-VM $vm -Destination $dsthostesx -VMotionPriority High; sleep 10; }