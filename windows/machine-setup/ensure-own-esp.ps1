<#
.SYNOPSIS
  Verify Windows boots from the EFI system partition on its own disk, and refresh
  its boot files there.

.DESCRIPTION
  With other drives' ESPs visible, Windows Setup can write its boot files to another
  drive's ESP (here: the Linux drive), leaving Windows unable to start once that
  drive is wiped. The installation procedure prevents this by hiding other ESPs
  during Setup (scripts/esp-visibility.sh), so Setup creates an ESP on the Windows
  disk. This script verifies that outcome and rewrites the boot files onto that ESP
  with bcdboot, which also points the firmware's "Windows Boot Manager" entry there.

  It never changes partitions: if the Windows disk has no ESP, it stops and explains.
  (Creating one after installation means resizing the system volume, which broke
  booting in the test VM.) Safe to run more than once; requires an elevated session.
#>
$ErrorActionPreference = 'Stop'

$espType = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
$systemLetter = $env:SystemDrive.TrimEnd(':')
$disk = (Get-Partition -DriveLetter $systemLetter).DiskNumber

$esp = @(Get-Partition -DiskNumber $disk | Where-Object { $_.GptType -eq $espType })
if ($esp.Count -ne 1) {
    throw ("Disk $disk (the Windows disk) has $($esp.Count) EFI system partitions; expected 1. " +
        'Windows Setup most likely used another drive''s ESP because it was visible during ' +
        'installation. Reinstall with other ESPs hidden (scripts/esp-visibility.sh hide); ' +
        'until then, do not wipe or remove the drive Windows boots from.')
}
$esp = $esp[0]

# Temporary drive letter for the ESP: the last free letter.
$used = (Get-PSDrive -PSProvider FileSystem).Name
$letter = [char[]](68..90) | Where-Object { $used -notcontains [string]$_ } | Select-Object -Last 1
if (-not $letter) { throw 'No free drive letter for the EFI system partition.' }
$access = "$($letter):\"

Write-Output "Windows is on disk $disk; its ESP is partition $($esp.PartitionNumber). Refreshing boot files there."
Add-PartitionAccessPath -DiskNumber $disk -PartitionNumber $esp.PartitionNumber -AccessPath $access
try {
    & bcdboot.exe $env:SystemRoot /s "$($letter):" /f UEFI
    if ($LASTEXITCODE -ne 0) { throw "bcdboot failed with exit code $LASTEXITCODE." }
}
finally {
    Remove-PartitionAccessPath -DiskNumber $disk -PartitionNumber $esp.PartitionNumber -AccessPath $access
}

Write-Output 'Boot manager now:'
& bcdedit.exe /enum '{bootmgr}'
