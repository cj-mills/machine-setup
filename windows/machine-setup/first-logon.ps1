<#
.SYNOPSIS
  First sign-in after an unattended install (run by autounattend.xml).

.DESCRIPTION
  1. Moves Windows' boot files onto the Windows disk's own ESP (ensure-own-esp.ps1).
  2. Runs optional test hooks (test VM only; absent on real installation media).
  3. Requires a new password at the next sign-in, then locks the session so you set
     it now: the answer file creates the account with a blank password so that no
     password is ever written to the installation media.

  Output is logged to C:\machine-setup\first-logon.log.
#>
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Start-Transcript -Path (Join-Path $here 'first-logon.log') -Append | Out-Null

try {
    & (Join-Path $here 'ensure-own-esp.ps1')
}
catch {
    Write-Warning "Boot files were NOT moved to the Windows disk: $_"
    Write-Warning 'Run C:\machine-setup\ensure-own-esp.ps1 elevated before removing or wiping other drives.'
}

$hooks = Join-Path $here 'test-hooks'
$isTestVm = Test-Path $hooks
if ($isTestVm) {
    Get-ChildItem -Path $hooks -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        Write-Output "Running test hook $($_.Name)"
        & $_.FullName
    }
}

if (-not $isTestVm) {
    # Blank password -> must be set now. The test VM keeps the blank password, since
    # a pending password change would block its SSH key sign-in; it holds no secrets.
    & net.exe user $env:USERNAME /logonpasswordchg:yes | Out-Null
    Stop-Transcript | Out-Null
    & rundll32.exe user32.dll, LockWorkStation
}
else {
    Stop-Transcript | Out-Null
}
