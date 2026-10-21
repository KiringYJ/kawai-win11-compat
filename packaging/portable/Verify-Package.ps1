# Verify the immutable payload; generated configuration and game state live in runtime/.
[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$packageRoot = $PSScriptRoot
$rootPrefix = $packageRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar

function Get-PayloadPath([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        $RelativePath.Contains('\') -or $RelativePath.Contains(':') -or
        $RelativePath -match '(^|/)(\.|\.\.)(/|$)|[\r\n]' -or
        [IO.Path]::IsPathRooted($RelativePath)) {
        throw "Invalid inventory path: $RelativePath"
    }
    $fullPath = [IO.Path]::GetFullPath((Join-Path $packageRoot $RelativePath))
    if (-not $fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Inventory path escapes the package: $RelativePath"
    }
    return $fullPath
}

$manifestPath = Join-Path $packageRoot 'MANIFEST.json'
$checksumsPath = Join-Path $packageRoot 'CHECKSUMS-SHA256.txt'
foreach ($requiredPath in @($manifestPath, $checksumsPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw 'Package inventory is missing. Extract the complete ZIP again.'
    }
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) { throw 'Unsupported package manifest version.' }
$runtimeRoots = @($manifest.runtimeRoots)
if ($runtimeRoots.Count -gt 1 -or ($runtimeRoots.Count -eq 1 -and $runtimeRoots[0] -cne 'runtime')) {
    throw 'Unsupported generated-runtime policy in package manifest.'
}
$allowRuntime = $runtimeRoots.Count -eq 1
$payload = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $manifest.files) {
    $relativePath = [string]$entry.path
    [void](Get-PayloadPath $relativePath)
    if ($relativePath -match '^(runtime/|MANIFEST\.json$|CHECKSUMS-SHA256\.txt$)' -or
        $entry.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $entry.bytes -lt 0 -or
        $payload.ContainsKey($relativePath)) {
        throw "Invalid or duplicate payload entry: $relativePath"
    }
    $payload.Add($relativePath, $entry)
}
if ($payload.Count -eq 0) { throw 'The package manifest contains no payload files.' }
$checksums = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($line in Get-Content -LiteralPath $checksumsPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -notmatch '^([a-fA-F0-9]{64})  (.+)$') { throw 'Malformed checksum entry.' }
    $hash = $Matches[1]
    $relativePath = $Matches[2]
    [void](Get-PayloadPath $relativePath)
    if ($checksums.ContainsKey($relativePath)) { throw "Duplicate checksum: $relativePath" }
    $checksums.Add($relativePath, $hash)
}
if ($checksums.Count -ne ($payload.Count + 1) -or -not $checksums.ContainsKey('MANIFEST.json')) {
    throw 'Checksums must cover exactly the payload and MANIFEST.json.'
}
foreach ($relativePath in $payload.Keys) {
    if (-not $checksums.ContainsKey($relativePath) -or
        $checksums[$relativePath] -ne $payload[$relativePath].sha256) {
        throw "Manifest and checksums disagree: $relativePath"
    }
}

# Walk directories explicitly so junctions cannot hide files outside the package.
$directories = [Collections.Generic.Stack[string]]::new()
$directories.Push($packageRoot)
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
while ($directories.Count -gt 0) {
    foreach ($item in Get-ChildItem -LiteralPath $directories.Pop() -Force) {
        $relativePath = $item.FullName.Substring($rootPrefix.Length).Replace('\', '/')
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Links and junctions are not allowed in the package: $relativePath"
        }
        if ($item.PSIsContainer) {
            if (-not ($allowRuntime -and $relativePath -eq 'runtime')) { $directories.Push($item.FullName) }
            continue
        }
        if ($relativePath -eq 'CHECKSUMS-SHA256.txt') { continue }
        if (-not $checksums.ContainsKey($relativePath)) {
            throw "Unexpected file in package: $relativePath"
        }
        $actualHash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        if ($actualHash -ne $checksums[$relativePath]) { throw "Checksum mismatch: $relativePath" }
        if ($payload.ContainsKey($relativePath) -and $item.Length -ne $payload[$relativePath].bytes) {
            throw "File size mismatch: $relativePath"
        }
        [void]$seen.Add($relativePath)
    }
}
foreach ($relativePath in $checksums.Keys) {
    if (-not $seen.Contains($relativePath)) { throw "Missing package file: $relativePath" }
}
if (-not $Quiet) {
    [pscustomobject]@{ Status = 'Verified'; Files = $seen.Count; Version = $manifest.version }
}
