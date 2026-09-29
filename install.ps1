#Requires -Version 5.1
<#
.SYNOPSIS
    Register or remove the "Copy Unix Path" Explorer context menu entry.
.DESCRIPTION
    Writes the CopyUnixPath.exe located next to this script into the registry, so the
    exe path comes from the script location instead of being hard coded.

    The entry has two possible locations:
      per-user     HKCU\Software\Classes\AllFilesystemObjects\shell\CopyUnixPath
      machine-wide HKLM\Software\Classes\AllFilesystemObjects\shell\CopyUnixPath

    Windows merges both into HKEY_CLASSES_ROOT and the per-user entry wins there, so a
    per-user install hides a machine-wide one instead of producing a second menu item.
    A plain -Uninstall therefore clears both locations, otherwise the hidden one would
    silently take over again once the visible entry is gone.
.PARAMETER AllUsers
    Register (or, together with -Uninstall, remove) the machine-wide entry.
    Needs an elevated shell.
.PARAMETER Uninstall
    Remove entries. Without -AllUsers both locations are cleared.
.PARAMETER Label
    Menu text. Default: Copy Unix Path.
.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -AllUsers
.EXAMPLE
    .\install.ps1 -Uninstall
.EXAMPLE
    .\install.ps1 -Uninstall -AllUsers
#>
[CmdletBinding()]
param(
    [switch]$AllUsers,
    [switch]$Uninstall,
    [string]$Label = 'Copy Unix Path'
)

$ErrorActionPreference = 'Stop'

$exe        = Join-Path $PSScriptRoot 'CopyUnixPath.exe'
$verbPath   = 'AllFilesystemObjects\shell\CopyUnixPath'
$userKey    = Join-Path 'HKCU:\Software\Classes' $verbPath
$machineKey = Join-Path 'HKLM:\Software\Classes' $verbPath

function Get-RegisteredCommand {
    param([string]$Key)

    if (-not (Test-Path $Key)) { return $null }
    $commandKey = Join-Path $Key 'command'
    if (-not (Test-Path $commandKey)) { return '(no command subkey)' }
    $value = (Get-ItemProperty -Path $commandKey -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
    if ([string]::IsNullOrEmpty($value)) { return '(no command value)' }
    return $value
}

function Test-Elevated {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Remove-MenuEntry {
    param([string]$Key, [string]$Scope)

    if (-not (Test-Path $Key)) { return $false }
    try {
        Remove-Item -Path $Key -Recurse -Force
        Write-Host ("Removed {0} entry: {1}" -f $Scope, $Key)
        return $true
    }
    catch {
        Write-Warning ("Cannot remove {0} entry (needs an elevated shell): {1}" -f $Scope, $Key)
        Write-Host    '  Run this from an elevated PowerShell: .\install.ps1 -Uninstall -AllUsers'
        return $false
    }
}

if ($Uninstall) {
    $targets = if ($AllUsers) {
        @(@{ Key = $machineKey; Scope = 'machine-wide' })
    }
    else {
        @(@{ Key = $userKey;    Scope = 'per-user' }
          @{ Key = $machineKey; Scope = 'machine-wide' })
    }

    $found = 0
    foreach ($target in $targets) {
        if (Test-Path $target.Key) { $found++ }
        Remove-MenuEntry -Key $target.Key -Scope $target.Scope | Out-Null
    }
    if ($found -eq 0) { Write-Host 'No menu entry found.' }
    return
}

if (-not (Test-Path $exe)) {
    throw "$exe not found. Run build.ps1 first."
}

$scope      = if ($AllUsers) { 'machine-wide' } else { 'per-user' }
$targetKey  = if ($AllUsers) { $machineKey } else { $userKey }
$otherKey   = if ($AllUsers) { $userKey } else { $machineKey }
$otherScope = if ($AllUsers) { 'per-user' } else { 'machine-wide' }
$commandKey = Join-Path $targetKey 'command'
$command    = '"{0}" "%V"' -f $exe

if ($AllUsers -and -not (Test-Elevated)) {
    throw 'Registering the machine-wide entry needs an elevated shell.'
}

$previous = Get-RegisteredCommand -Key $targetKey

New-Item -Path $commandKey -Force | Out-Null
Set-ItemProperty -Path $targetKey  -Name '(default)' -Value $Label
Set-ItemProperty -Path $commandKey -Name '(default)' -Value $command

Write-Host ("Registered {0} entry: {1}" -f $scope, $targetKey)
Write-Host ("  (default) = {0}" -f $Label)
Write-Host ("  command\(default) = {0}" -f $command)
if ($previous -and $previous -ne $command) {
    Write-Host ("  replaced  = {0}" -f $previous)
}

$otherCommand = Get-RegisteredCommand -Key $otherKey
if ($otherCommand) {
    Write-Warning ("A {0} entry also exists: {1}" -f $otherScope, $otherKey)
    Write-Host ("  command = {0}" -f $otherCommand)
    if ($AllUsers) {
        Write-Host '  The per-user entry wins for the same key path, so the menu keeps using that one.'
        Write-Host '  Remove both: .\install.ps1 -Uninstall'
    }
    else {
        Write-Host '  The per-user entry wins for the same key path, so the entry just registered hides this one.'
        Write-Host '  Remove the stale machine-wide entry from an elevated shell: .\install.ps1 -Uninstall -AllUsers'
    }
}
