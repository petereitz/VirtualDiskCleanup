# VirtualDiskCleanup
Round up virtual disks left behind when HyperV VMs are deleted.

## Install
- Copy vhdCleanup.ps1 to a machine running PowerShell4 + that can see the HyperV system
- Edit `$remoteHost` and `$drive`
- Run the script as a user that has modify access to drive in question

