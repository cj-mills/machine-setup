<#
.SYNOPSIS
  Make Windows boot from the EFI system partition on its own disk.

.DESCRIPTION
  With other drives attached, Windows Setup can write its boot files to another
  drive's EFI system partition (here: the Linux drive), leaving Windows unable to
  start once that drive is wiped or removed. This rewrites the boot files onto the
  ESP of the disk Windows is installed on with bcdboot, which also points the
  firmware's "Windows Boot Manager" entry there. Safe to run more than once.

  Requires an elevated session. The Windows disk must already have exactly one ESP
  (scripts/prepare-windows-disk.sh creates it before installation).
#>
$ErrorActionPreference = 'Stop'

$espType = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
$systemLetter = $env:SystemDrive.TrimEnd(':')
$disk = (Get-Partition -DriveLetter $systemLetter).DiskNumber

$esp = @(Get-Partition -DiskNumber $disk | Where-Object { $_.GptType -eq $espType })
if ($esp.Count -ne 1) {
    throw "Expected exactly one EFI system partition on disk $disk (the Windows disk), found $($esp.Count)."
}
$esp = $esp[0]

# Temporary drive letter for the ESP: the last free letter.
$used = (Get-PSDrive -PSProvider FileSystem).Name
$letter = [char[]](68..90) | Where-Object { $used -notcontains [string]$_ } | Select-Object -Last 1
if (-not $letter) { throw 'No free drive letter for the EFI system partition.' }
$access = "$($letter):\"

Write-Output "Windows is on disk $disk; its ESP is partition $($esp.PartitionNumber). Writing boot files there."
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
