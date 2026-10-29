#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Check', 'Install', 'Uninstall')][string]$Action = 'Check',
    [string]$AppRoot = (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness'),
    [string]$ProfilePath = ''
)
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not $ProfilePath) {
    $dshRoot = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
    $ProfilePath = Join-Path $dshRoot 'profiles\desktop'
}
$ProfilePath = [IO.Path]::GetFullPath($ProfilePath)
$configPath = Join-Path $ProfilePath 'cordis.patch.yml'
$moduleDir = Join-Path $ProfilePath 'compat\dsh-windows-spawn-eperm-workaround'
$text = if (Test-Path -LiteralPath $configPath) { [IO.File]::ReadAllText($configPath) } else { '' }
$span = Get-BlockSpan $text

if ($Action -eq 'Uninstall') {
    if (-not $span) { Write-Output 'No package-owned patch found; nothing changed.'; return }
    if ($PSCmdlet.ShouldProcess($configPath, 'Back up and remove only the package-owned patch block')) {
        $backup = Backup-Config $configPath
        Write-Utf8 $configPath ($text.Remove($span.Start, $span.Length))
        Write-Output "Uninstalled. Config backup: $backup"
        Write-Output 'Module files retained for recovery. Quit and reopen DSH to apply.'
    }
    return
}

$info = Get-AppInfo $AppRoot
Write-Output "Validated subprocess package: $($info.Version)"
if ($Action -eq 'Check') {
    Write-Output "Package-owned patch present: $([bool]$span)"
    if ($span) {
        foreach ($file in @('loader.mjs', 'create-compatible-runtime.mjs')) {
            if (-not (Test-Path -LiteralPath (Join-Path $moduleDir $file))) { throw "Installed file missing: $file" }
        }
    }
    Write-Output 'Static check only. Verify command execution inside DSH after a full restart.'
    return
}

if ($span) { Write-Output 'Already installed; no files changed. Use Uninstall before reinstalling.'; return }
Assert-ProfileShape $text
if (-not (Test-Path -LiteralPath $ProfilePath -PathType Container)) { throw 'Existing DSH profile directory required.' }
if (Test-Path -LiteralPath $moduleDir) { throw 'Compatibility directory already exists. Review retained files before reinstalling.' }
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$prefixText = $text
if ($prefixText.Length -gt 0 -and -not $prefixText.EndsWith("`n")) { $prefixText += $newline }
$updated = $prefixText + (Get-OwnedBlock $newline)
$factory = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\src\create-compatible-runtime.mjs'))
$nativeJson = ConvertTo-Json -InputObject $info.NativeUrl -Compress
$loader = "import NativeRuntime from $nativeJson;`nimport { createCompatibleRuntime } from './create-compatible-runtime.mjs';`nexport default createCompatibleRuntime(NativeRuntime);`n"
if ($PSCmdlet.ShouldProcess($configPath, 'Back up config, write compatibility module and append patch')) {
    $backup = if (Test-Path -LiteralPath $configPath) { Backup-Config $configPath } else { '(new config)' }
    New-Item -ItemType Directory -Path $moduleDir | Out-Null
    try {
        Write-Utf8 (Join-Path $moduleDir 'create-compatible-runtime.mjs') $factory
        Write-Utf8 (Join-Path $moduleDir 'loader.mjs') $loader
        # Commit the profile last; installed module files remain if a write fails.
        Write-Utf8 $configPath $updated
    } catch {
        throw "Install failed. Config backup: $backup. Review retained module directory. $($_.Exception.Message)"
    }
    Write-Output "Installed. Config backup: $backup"
    Write-Output 'Quit and reopen DSH. Then run the smoke probes from README.md inside DSH.'
}
