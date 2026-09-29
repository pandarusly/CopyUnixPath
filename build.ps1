#Requires -Version 5.1
<#
.SYNOPSIS
    Build CopyUnixPath.exe into the repository root (next to CopyUnixPath.ini).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root    = $PSScriptRoot
$source  = Join-Path $root 'src\CopyUnixPath.cpp'
$exe     = Join-Path $root 'CopyUnixPath.exe'
$ini     = Join-Path $root 'CopyUnixPath.ini'
$example = Join-Path $root 'CopyUnixPath.ini.example'

$clang = Get-Command clang++ -ErrorAction SilentlyContinue
if (-not $clang) {
    throw 'clang++ not found in PATH. Install LLVM first.'
}

if (-not (Test-Path $ini) -and (Test-Path $example)) {
    Copy-Item $example $ini
    Write-Host "Created $ini from CopyUnixPath.ini.example"
}

& $clang.Source -o $exe $source -Os -fno-exceptions -fno-rtti -DNDEBUG -static -lshell32 -luser32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "clang++ exited with code $LASTEXITCODE"
}

Write-Host ("Built {0} ({1} bytes)" -f $exe, (Get-Item $exe).Length)
