#Requires -Version 5.1
<#
.SYNOPSIS
Repair DSH command execution after Windows Job spawn EPERM (0.2.1-rc.3 only).
.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-DSH.ps1
.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-DSH.ps1 -Action Check
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Check', 'Install', 'Uninstall')][string]$Action = 'Install',
    [string]$AppRoot,
    [string]$ProfilePath
)
$ErrorActionPreference = 'Stop'
Write-Output 'DSH command / pwsh spawn EPERM repair (Desktop 0.2.1-rc.3)'
$options = @{} + $PSBoundParameters
$options['Action'] = $Action
& (Join-Path $PSScriptRoot 'scripts\Manage-Workaround.ps1') @options
