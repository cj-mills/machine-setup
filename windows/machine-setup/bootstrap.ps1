<#
.SYNOPSIS
  Apply the Windows workstation configuration: the Windows counterpart of bootstrap.sh.

.DESCRIPTION
  Run once after the first sign-in (and the password change), from Terminal (Admin),
  with a network connection:

    C:\machine-setup\bootstrap.ps1

  Re-runnable: units already in their desired state are left alone. Enables winget's
  configuration feature if this winget version needs it (it downloads components from
  the Microsoft Store), then applies configuration.winget. Without -AcceptAgreements,
  winget shows the configuration's agreement prompt for you to accept.

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
# first ("Configuration is not enabled"); `--enable` takes no other arguments.
& winget.exe configure validate -f $config --disable-interactivity *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output 'Enabling winget configuration (downloads components from the Microsoft Store)...'
    & winget.exe configure --enable
    & winget.exe configure validate -f $config --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "winget can't validate $config (exit code $LASTEXITCODE)." }
}

$arguments = @('configure', '-f', $config)
if ($AcceptAgreements) { $arguments += '--accept-configuration-agreements', '--disable-interactivity' }
& winget.exe @arguments
$code = $LASTEXITCODE

Write-Output ''
if ($code -eq 0) {
    Write-Output 'Configuration applied. Restart Windows to finish (features, Fast Startup, sounds).'
} else {
    Write-Output "Some units failed (exit code $code); see above. Re-run after fixing; applied units are skipped."
}
exit $code
