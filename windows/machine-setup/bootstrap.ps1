<#
.SYNOPSIS
  Apply the Windows workstation configuration: the Windows counterpart of bootstrap.sh.

.DESCRIPTION
  Run once after the first sign-in (and the password change), from Terminal (Admin),
  with a network connection:

    C:\machine-setup\bootstrap.ps1

  Re-runnable: units already in their desired state are left alone. Enables winget's
  configuration feature if this winget version needs it (it updates winget from the
  Microsoft Store), runs a read-only test pass (which also installs the configuration's
  modules), then applies configuration.winget. Without -AcceptAgreements, winget shows
  the configuration's agreement prompt once, at the test pass.

.PARAMETER AcceptAgreements
  Accept the configuration agreements without prompting (unattended runs, e.g. the
  test VM).
#>
[CmdletBinding()]
param([switch]$AcceptAgreements)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = Join-Path $here 'configuration.winget'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this from an elevated terminal (Terminal (Admin)).' }

Write-Output "winget $(& winget.exe --version)"

# Some winget versions ship configuration as an extended feature that must be enabled
# first ("Configuration is not enabled"); `--enable` takes no other arguments. Enabling
# updates App Installer (winget itself) from the Store, so winget is unusable for a
# while afterwards: wait until validation works again before applying.
& winget.exe configure validate -f $config --disable-interactivity *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output 'Enabling winget configuration (updates winget from the Microsoft Store)...'
    & winget.exe configure --enable
    $ready = $false
    foreach ($attempt in 1..60) {
        Start-Sleep -Seconds 10
        & winget.exe configure validate -f $config --disable-interactivity *> $null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    }
    if (-not $ready) {
        & winget.exe configure validate -f $config --disable-interactivity
        throw "winget configuration is still unavailable 10 minutes after enabling (exit code $LASTEXITCODE)."
    }
    Write-Output "winget $(& winget.exe --version) is ready."
}

# Test pass first: read-only, and it installs every PowerShell module the configuration
# uses. On a fresh machine, the unit that first triggers a module's install can fail to
# find its resource ("Unable to find resource after install"); with the modules already
# present, the apply pass doesn't hit that. The agreement prompt (unless
# -AcceptAgreements) is shown here; the apply pass then runs with it accepted.
Write-Output 'Checking the system against the configuration (no changes yet)...'
$testArguments = @('configure', 'test', '-f', $config)
if ($AcceptAgreements) { $testArguments += '--accept-configuration-agreements', '--disable-interactivity' }
& winget.exe @testArguments

Write-Output 'Applying the configuration...'
& winget.exe configure -f $config --accept-configuration-agreements --disable-interactivity
$code = $LASTEXITCODE

Write-Output ''
if ($code -eq 0) {
    Write-Output 'Configuration applied. Restart Windows to finish (features, Fast Startup, sounds).'
} else {
    Write-Output "Some units failed (exit code $code); see above. Re-run after fixing; applied units are skipped."
}
exit $code
