<#
.SYNOPSIS
  Make Windows boot from the EFI system partition on its own disk.

.DESCRIPTION
  With other drives attached, Windows Setup can write its boot files to another
  drive's EFI system partition (here: the Linux drive), leaving Windows unable to
  start once that drive is wiped or removed. This rewrites the boot files onto the
  ESP of the disk Windows is installed on with bcdboot, which also points the
  firmware's "Windows Boot Manager" entry there. Safe to run more than once.

  If Setup put the system partition on another disk, the Windows disk has no ESP:
  one is created by shrinking the Windows partition by 300 MB.

  Requires an elevated session.
#>
$ErrorActionPreference = 'Stop'

$espType = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
$basicDataType = '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
$systemLetter = $env:SystemDrive.TrimEnd(':')
$systemPartition = Get-Partition -DriveLetter $systemLetter
$disk = $systemPartition.DiskNumber

$esp = @(Get-Partition -DiskNumber $disk | Where-Object { $_.GptType -eq $espType })
if ($esp.Count -eq 0) {
    Write-Output "Disk $disk has no EFI system partition (Setup used another disk's). Creating one."
    Resize-Partition -DiskNumber $disk -PartitionNumber $systemPartition.PartitionNumber `
        -Size ($systemPartition.Size - 300MB)
    # Created as basic data so it can be formatted, then retyped as an ESP.
    $new = New-Partition -DiskNumber $disk -Size 300MB -GptType $basicDataType
    Format-Volume -Partition $new -FileSystem FAT32 -NewFileSystemLabel SYSTEM -Confirm:$false | Out-Null
    Set-Partition -DiskNumber $disk -PartitionNumber $new.PartitionNumber -GptType $espType
    $esp = @(Get-Partition -DiskNumber $disk -PartitionNumber $new.PartitionNumber)
}
if ($esp.Count -ne 1) {
    throw "Expected one EFI system partition on disk $disk (the Windows disk), found $($esp.Count)."
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
