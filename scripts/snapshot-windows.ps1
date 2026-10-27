<#
.SYNOPSIS
  Read-only inventory of a Windows install: the counterpart of snapshot-system.sh.

.DESCRIPTION
  Captures what was installed and customised (winget export, registry and Store apps,
  Windows features, WSL distros, startup items, non-Microsoft services and scheduled
  tasks, PATH, page file, user-folder locations, Steam libraries, disk usage) so it can
  be curated into the declarative Windows setup. Changes nothing.

  Output contains personal data (paths, account names). Keep it out of git: inside a
  repository checkout it goes to inventory\raw\, which is git-ignored.

  Per-user state (HKCU installs, Store apps, profile folders) belongs to the account
  that runs the script, so run it once in each account you use; snapshots land in
  separate folders named after the account. Running elevated additionally captures
  Windows optional features and Store apps for all accounts.

.PARAMETER OutDir
  Output folder. Defaults to inventory\raw\<computer>-<user>-<date> in a repository
  checkout, otherwise a folder next to this script.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\snapshot-windows.ps1
#>
[CmdletBinding()]
param([string]$OutDir)

$ErrorActionPreference = 'Continue'
$stamp = "$($env:COMPUTERNAME.ToLower())-$($env:USERNAME.ToLower())-$(Get-Date -Format yyyy-MM-dd)"
if (-not $OutDir) {
    $repoInventory = Join-Path $PSScriptRoot '..\inventory'
    if (Test-Path $repoInventory) { $OutDir = Join-Path $repoInventory "raw\$stamp" }
    else { $OutDir = Join-Path $PSScriptRoot "windows-snapshot-$stamp" }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# Save <file> { block }: run a block, write its output; never abort the snapshot.
function Save([string]$Name, [scriptblock]$Block) {
    $path = Join-Path $OutDir $Name
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    Write-Host "  $Name"
    try { & $Block 2>&1 | Out-File -FilePath $path -Encoding utf8 -Width 500 }
    catch { "ERROR: $_" | Out-File -FilePath $path -Encoding utf8 }
}

# SaveCsv <file> { block }: same, for objects worth keeping as a table.
function SaveCsv([string]$Name, [scriptblock]$Block) {
    $path = Join-Path $OutDir $Name
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    Write-Host "  $Name"
    try { & $Block | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8 }
    catch { "ERROR: $_" | Out-File -FilePath $path -Encoding utf8 }
}

# Total size of a folder in GB (skips unreadable entries).
function FolderSizeGB([string]$Path) {
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if (-not $sum) { $sum = 0 }
    [math]::Round($sum / 1GB, 2)
}

Write-Host "Writing snapshot to $OutDir (elevated: $isAdmin)"

# --- system ------------------------------------------------------------------
Save 'system\computer.txt' {
    Get-ComputerInfo -Property OsName, OsVersion, OsBuildNumber, OsDisplayVersion, CsManufacturer,
        CsModel, CsProcessors, CsTotalPhysicalMemory, BiosSMBIOSBIOSVersion | Format-List
}
Save 'system\gpu.txt' { Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate | Format-List }
Save 'system\disks.txt' {
    Get-Disk | Select-Object Number, FriendlyName, SerialNumber, Size, PartitionStyle | Format-Table -AutoSize
    Get-Partition | Select-Object DiskNumber, PartitionNumber, DriveLetter, Size, Type | Format-Table -AutoSize
    Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem, Size, SizeRemaining | Format-Table -AutoSize
}
Save 'system\pagefile.txt' {
    'Settings:'; Get-CimInstance Win32_PageFileSetting | Select-Object Name, InitialSize, MaximumSize | Format-Table -AutoSize
    'Usage:'; Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage | Format-Table -AutoSize
    'Automatic management:'; (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
}
Save 'system\user-folders.txt' {
    Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' |
        Select-Object Desktop, Personal, 'My Pictures', 'My Music', 'My Video',
            '{374DE290-123F-4565-9164-39C4925E467B}' | Format-List
}
Save 'system\path.txt' {
    'Machine PATH:'; [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
    ''; 'User PATH:'; [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
}

# --- applications --------------------------------------------------------------
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host '  apps\winget-export.json'
    New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'apps') | Out-Null
    # Only the community `winget` source: the `msstore` source requires accepting
    # Store terms, which this read-only script never does on the user's behalf.
    winget export -o (Join-Path $OutDir 'apps\winget-export.json') --source winget --include-versions --disable-interactivity 2>&1 |
        Out-File -FilePath (Join-Path $OutDir 'apps\winget-export.log') -Encoding utf8
    Save 'apps\winget-list.txt' { winget list --source winget --disable-interactivity }
}
SaveCsv 'apps\installed-programs.csv' {
    $keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation,
            @{ n = 'SizeMB'; e = { [math]::Round(($_.EstimatedSize / 1KB), 1) } }, PSPath |
        Sort-Object DisplayName
}
SaveCsv 'apps\store-apps.csv' {
    Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.SignatureKind -eq 'Store' } |
        Select-Object Name, Version, Publisher | Sort-Object Name
}
if ($isAdmin) {
    SaveCsv 'apps\store-apps-all-users.csv' {
        Get-AppxPackage -AllUsers | Where-Object { -not $_.IsFramework -and $_.SignatureKind -eq 'Store' } |
            ForEach-Object {
                $pkg = $_
                $users = ($pkg.PackageUserInformation | ForEach-Object { $_.UserSecurityId.Username }) -join '; '
                [pscustomobject]@{ Name = $pkg.Name; Version = $pkg.Version; Users = $users }
            } | Sort-Object Name
    }
}
Save 'apps\steam-libraries.txt' {
    $vdf = Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) { Get-Content $vdf } else { 'Steam not found in the default location.' }
}
Save 'apps\dev-tools.txt' {
    foreach ($tool in 'git', 'python', 'conda', 'node', 'code', 'docker', 'nvidia-smi', 'nvcc') {
        $cmd = Get-Command $tool -ErrorAction SilentlyContinue
        if ($cmd) { "{0,-12} {1}" -f $tool, $cmd.Source } else { "{0,-12} (not found)" -f $tool }
    }
}

# --- Windows features and WSL ------------------------------------------------------
if ($isAdmin) {
    Save 'features\optional-features.txt' {
        Get-WindowsOptionalFeature -Online | Where-Object State -eq 'Enabled' |
            Select-Object FeatureName | Sort-Object FeatureName | Format-Table -AutoSize
    }
} else {
    Save 'features\optional-features.txt' { 'Skipped: run elevated to list enabled optional features.' }
}
Save 'features\wsl.txt' {
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        $env:WSL_UTF8 = '1'
        wsl --status
        ''; wsl --list --verbose
    } else { 'WSL not installed.' }
}

# --- things that run automatically ----------------------------------------------
SaveCsv 'autostart\startup-commands.csv' {
    Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User
}
SaveCsv 'autostart\non-microsoft-services.csv' {
    Get-CimInstance Win32_Service |
        Where-Object { $_.PathName -and $_.PathName -notmatch '(?i)\\Windows\\(System32|SysWOW64|servicing)\\' } |
        Select-Object Name, DisplayName, StartMode, State, PathName | Sort-Object Name
}
SaveCsv 'autostart\scheduled-tasks.csv' {
    Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
        Select-Object TaskPath, TaskName, State, Author | Sort-Object TaskPath, TaskName
}

# --- where the space goes ---------------------------------------------------------
SaveCsv 'space\profile-folders.csv' {
    Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
        ForEach-Object { [pscustomobject]@{ Folder = $_.FullName; SizeGB = FolderSizeGB $_.FullName } } |
        Sort-Object SizeGB -Descending
}
SaveCsv 'space\appdata-local-folders.csv' {
    Get-ChildItem -LiteralPath $env:LOCALAPPDATA -Directory -Force -ErrorAction SilentlyContinue |
        ForEach-Object { [pscustomobject]@{ Folder = $_.FullName; SizeGB = FolderSizeGB $_.FullName } } |
        Where-Object SizeGB -gt 0.1 | Sort-Object SizeGB -Descending
}
SaveCsv 'space\program-folders.csv' {
    $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -Force -ErrorAction SilentlyContinue } |
        ForEach-Object { [pscustomobject]@{ Folder = $_.FullName; SizeGB = FolderSizeGB $_.FullName } } |
        Where-Object SizeGB -gt 0.1 | Sort-Object SizeGB -Descending
}

Write-Host "Done. Snapshot written to $OutDir"
