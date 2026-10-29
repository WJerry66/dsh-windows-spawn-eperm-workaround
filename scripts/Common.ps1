Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:StartMarker = '# BEGIN dsh-windows-spawn-eperm-workaround v1'
$script:EndMarker = '# END dsh-windows-spawn-eperm-workaround v1'
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, $script:Utf8)
}

function Read-AsarText([string]$Archive, [string]$Entry) {
    $stream = [IO.File]::OpenRead($Archive)
    $reader = New-Object IO.BinaryReader($stream)
    try {
        $prefix = $reader.ReadBytes(16)
        if ($prefix.Length -ne 16) { throw 'Truncated ASAR header.' }
        $headerSize = [BitConverter]::ToUInt32($prefix, 4)
        $jsonSize = [BitConverter]::ToUInt32($prefix, 12)
        $dataStart = 8L + $headerSize
        if ($jsonSize -gt 33554432 -or $jsonSize -lt 2 -or
            16L + $jsonSize -gt $dataStart -or $dataStart -gt $stream.Length) {
            throw 'Invalid or oversized ASAR header.'
        }
        $bytes = $reader.ReadBytes([int]$jsonSize)
        if ($bytes.Length -ne $jsonSize) { throw 'Truncated ASAR JSON.' }
        $item = ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json)
        foreach ($part in $Entry.Split('/')) {
            $files = $item.PSObject.Properties['files']
            if (-not $files) { throw "ASAR directory missing: $Entry" }
            $property = $files.Value.PSObject.Properties[$part]
            if (-not $property) { throw "ASAR entry missing: $Entry" }
            $item = $property.Value
        }
        if ($item.PSObject.Properties['unpacked'] -and $item.unpacked) {
            throw "Unpacked ASAR entry is unsupported: $Entry"
        }
        if (-not $item.PSObject.Properties['size'] -or -not $item.PSObject.Properties['offset']) {
            throw "ASAR entry is not a regular packed file: $Entry"
        }
        $length = [long]$item.size
        $position = $dataStart + [long]$item.offset
        if ($length -lt 0 -or $length -gt 16777216 -or $position -lt $dataStart -or
            $position + $length -gt $stream.Length) { throw 'Invalid ASAR file bounds.' }
        $stream.Position = $position
        $body = $reader.ReadBytes([int]$length)
        if ($body.Length -ne $length) { throw 'Truncated ASAR entry.' }
        return [Text.Encoding]::UTF8.GetString($body)
    } finally { $reader.Dispose() }
}

function Get-AppInfo([string]$AppRoot) {
    $root = [IO.Path]::GetFullPath($AppRoot)
    $archive = Join-Path $root 'resources\app.asar'
    $prefix = 'dsh/node_modules/@deepseek-ai/dsh-subprocess-local/'
    $package = Read-AsarText $archive ($prefix + 'package.json') | ConvertFrom-Json
    if ($package.name -ne '@deepseek-ai/dsh-subprocess-local' -or $package.version -ne '0.2.1-rc.3') {
        throw "Unsupported runtime version: $($package.version). Only 0.2.1-rc.3 has been validated."
    }
    $code = Read-AsarText $archive ($prefix + 'lib/index.js')
    foreach ($signature in @('selectContainmentMode\(kind\)', 'warnFallback\(', 'launchWindowsJob\(')) {
        if ($code -notmatch $signature) { throw "Runtime API signature missing: $signature" }
    }
    $nativePath = Join-Path $archive ($prefix + 'lib/index.js')
    return [pscustomobject]@{ Version = $package.version; NativeUrl = ([Uri]$nativePath).AbsoluteUri }
}

function Get-OwnedBlock([string]$Newline = "`n") {
    return (@(
        $script:StartMarker
        '- id: subprocess'
        '  disabled: true'
        '- insert:'
        '    - id: subprocess-windows-compat'
        "      name: './compat/dsh-windows-spawn-eperm-workaround/loader.mjs'"
        $script:EndMarker
    ) -join $Newline) + $Newline
}

function Get-BlockSpan([string]$Text) {
    $starts = [regex]::Matches($Text, '(?m)^' + [regex]::Escape($script:StartMarker) + '\r?$')
    $ends = [regex]::Matches($Text, '(?m)^' + [regex]::Escape($script:EndMarker) + '\r?$')
    if ($starts.Count -eq 0 -and $ends.Count -eq 0) { return $null }
    if ($starts.Count -ne 1 -or $ends.Count -ne 1 -or $ends[0].Index -le $starts[0].Index) {
        throw 'Ambiguous patch markers; refusing to modify the profile.'
    }
    $start = $starts[0].Index
    $end = $ends[0].Index + $ends[0].Length
    if ($end -lt $Text.Length -and $Text[$end] -eq "`n") { $end++ }
    $actual = $Text.Substring($start, $end - $start)
    if (($actual -replace "`r`n", "`n").TrimEnd("`n") -cne (Get-OwnedBlock).TrimEnd("`n")) {
        throw 'Owned patch block was edited; refusing to remove or overwrite it.'
    }
    return [pscustomobject]@{ Start = $start; Length = $end - $start }
}

function Assert-ProfileShape([string]$Text) {
    if ($Text -match '(?m)^\s*\[\s*\]\s*$|^\s*(---|\.\.\.)\s*$') {
        throw 'Only a plain block-style top-level YAML list is supported.'
    }
    $meaningful = @($Text -split '\r?\n' | Where-Object { $_ -notmatch '^\s*(#.*)?$' })
    if ($meaningful.Count -gt 0 -and $meaningful[0] -notmatch '^- ') {
        throw 'Profile must be a block-style top-level YAML list.'
    }
    if ($Text -match '(?m)^\s*-\s+id:\s*[''"'']?subprocess(?:-windows-compat)?[''"'']?\s*(?:#.*)?$' -or
        $Text -match 'subprocess-windows\.mjs|dsh-windows-spawn-eperm-workaround') {
        throw 'Existing subprocess override detected. Review/remove the previous workaround first.'
    }
}

function Backup-Config([string]$Path) {
    $backup = $Path + '.backup-' + [Guid]::NewGuid().ToString('N')
    Copy-Item -LiteralPath $Path -Destination $backup
    return $backup
}
