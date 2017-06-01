#
# Move "abandoned" virtual disks to a "decomm" folder where they can be easily
# dispensed with.  It does so by:
#   - listing all VMs, then building an array of their associated disks
#   - listing all VHD or VHDX files on a given Volume
#   - comparing the two and acting on those that are not tied to a VM
# Any abandoned disk [.vhd, .vhdx, .avhd, .avhdx]

#### SETUP --------------------------------------------------------------------
# env
$dateString = Get-Date -UFormat "%Y%m%d"

## Change these to suit
# the host that needs cleanup
$remoteHost = "somehost.somedomain.net";
# the drive on said host that we'll be cleaning up
$drive = "D";

## Probably leave these alone unless you want to muck with how/where your spare
## v disks end up
$UNCPath = "\\$remoteHost\$drive$";
$decommFolder = "$UNCPath\decomm-$dateString"
$searchUNCPath = "$UNCPath";
$cleanupLog = "$decommFolder\README.txt";

## Internal
$knownDisks = @();
$allDisks = @();
$abandonedDisksLocal = @();
$abandonedDisksUNC = @();
$localPath = $drive + ":";


#### BUSINESS -----------------------------------------------------------------
# grab a list of vms
$vms = get-vm -ComputerName $remoteHost;

# loop through vm list
write-host "`n------------------------------`n- Reviwing VMs on $remoteHost`n------------------------------";
foreach ($vm in $vms) {
    Write-Host $vm.Name;

    # see if there are any snapshots for this vm
    $snapshots = get-vmsnapshot -ComputerName $remoteHost $vm.Name

    # ... if so, make sure that we grab the disk associated with each
    if ($snapshots.Count -gt 0 ) {
        foreach ($snapshot in $snapshots) {
            $disks = Get-VMHardDiskDrive $snapshot;
            foreach ($disk in $disks) {
                # everything goes into the $knownDisks array
                $knownDisks += $disk.Path;
            }
        }
    }

    # now get any disks assigned to the running vm
    $disks = Get-VMHardDiskDrive -VMName $vm.Name -ComputerName $remoteHost;
    foreach ($disk in $disks) {
        # everything goes into the $knownDisks array
        $knownDisks += $disk.Path;
    }
}

# grab a list of all disks on the drive in question
write-host "`n------------------------------`n- Searching $searchUNCPath for virtual disks`n------------------------------";
$allDisks = Get-ChildItem -Path $searchUNCPath -Include @("*.vhdx", "*.avhdx", "*.vhd", "*.avhd") -Recurse |foreach-object -process { $_.FullName };


# ... but we need local paths, not UNC paths
ForEach ($disk in $allDisks){
    $tempDisk = $disk.replace($UNCPath, $localPath)
    #check if we know of this drive
    if ($knownDisks -notcontains $tempDisk) {
        $abandonedDisksUNC += $disk;
        $abandonedDisksLocal += $tempDisk;
    }
}

# move abandoned disks to decomm folder
ForEach ($disk in $abandonedDisksUNC) {
    if (!(Test-Path $decommFolder)) {
        # create the decomm folder
        new-item $decommFolder -type Directory;
        # start the log
        set-content -Value "This folder created and VMs relocated on $dateString" -Path $cleanupLog;
    }
    # move abandoned disks to the decomm folder
    Move-Item $disk $decommFolder;
    # write a report
    add-content -Value "$disk moved to $decommFolder" -Path $cleanupLog;
    # give the console the same
    Write-Host "$disk moved to $decommFolder"

}

