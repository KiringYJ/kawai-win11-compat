[CmdletBinding()]
param(
  [string]$OutputDirectory,
  [string]$Version = '0.1.0-rc.1',
  [switch]$UseLegacyKawai2004Name
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $repoRoot 'compat\releases'
}
if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
  throw "Version contains characters that are unsafe in a file name: $Version"
}

function Get-FullPath([string]$Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Assert-ChildPath([string]$Parent, [string]$Child, [string]$Description) {
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
  $childFull = [System.IO.Path]::GetFullPath($Child)
  if (-not $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description is outside the intended output directory: $childFull"
  }
}

function Assert-NoReparsePath([string]$Path, [string]$Description) {
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $current = Get-Item -LiteralPath ([System.IO.Path]::GetPathRoot($fullPath)) -Force
  $remainder = $fullPath.Substring($current.FullName.TrimEnd('\').Length).TrimStart('\')
  foreach ($component in @($remainder.Split('\') | Where-Object { $_.Length -gt 0 })) {
    $candidate = Join-Path $current.FullName $component
    if (-not (Test-Path -LiteralPath $candidate)) { break }
    $current = Get-Item -LiteralPath $candidate -Force
    if (($current.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "$Description must not contain a reparse point: $($current.FullName)"
    }
  }
}

function Assert-SourceFile([string]$RelativePath) {
  $source = Join-Path $repoRoot ($RelativePath.Replace('/', '\'))
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Missing reviewed source-kit file: $RelativePath"
  }
  Assert-NoReparsePath $source "source-kit file $RelativePath"
  return $source
}

function Remove-OwnedDirectory([string]$OutputRoot, [string]$Path) {
  Assert-ChildPath $OutputRoot $Path 'cleanup path'
  if (Test-Path -LiteralPath $Path) {
    Assert-NoReparsePath $Path 'cleanup path'
    [System.IO.Directory]::Delete([System.IO.Path]::GetFullPath($Path), $true)
  }
}

function Remove-OwnedFile([string]$OutputRoot, [string]$Path) {
  Assert-ChildPath $OutputRoot $Path 'cleanup path'
  if (Test-Path -LiteralPath $Path) {
    Assert-NoReparsePath $Path 'cleanup path'
    [System.IO.File]::Delete([System.IO.Path]::GetFullPath($Path))
  }
}

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-ArtifactRelativePath([string]$Root, [string]$FullName) {
  $rootWithSeparator = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
  $fileFull = [System.IO.Path]::GetFullPath($FullName)
  if (-not $fileFull.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "File is outside the artifact root: $fileFull"
  }
  return $fileFull.Substring($rootWithSeparator.Length).Replace('\', '/')
}

function Get-SortedArtifactPaths([string]$Root, [string[]]$ExcludedPaths) {
  $paths = [string[]]@(Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
    Get-ArtifactRelativePath $Root $_.FullName
  } | Where-Object { $ExcludedPaths -notcontains $_ })
  [Array]::Sort($paths, [System.StringComparer]::Ordinal)
  return $paths
}

function New-DeterministicZip([string]$SourceDirectory, [string]$ZipPath, [string]$RootName) {
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $fileStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
  $zip = $null
  try {
    $zip = New-Object System.IO.Compression.ZipArchive(
      $fileStream,
      [System.IO.Compression.ZipArchiveMode]::Create,
      $false,
      [System.Text.Encoding]::UTF8
    )
    foreach ($relativePath in (Get-SortedArtifactPaths $SourceDirectory @())) {
      $sourcePath = Join-Path $SourceDirectory ($relativePath.Replace('/', '\'))
      $entry = $zip.CreateEntry("$RootName/$relativePath", [System.IO.Compression.CompressionLevel]::Optimal)
      $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
      $entryStream = $entry.Open()
      $sourceStream = [System.IO.File]::OpenRead($sourcePath)
      try {
        $sourceStream.CopyTo($entryStream)
      } finally {
        $sourceStream.Dispose()
        $entryStream.Dispose()
      }
    }
  } finally {
    if ($null -ne $zip) { $zip.Dispose() }
    $fileStream.Dispose()
  }
}

$reviewedPaths = [string[]]@(
  'README.md',
  'LICENSE',
  'scripts/Build-KawaiPackage.ps1',
  'scripts/Build-Kawai2004Package.ps1',
  'scripts/Expand-KawaiRuntimeInputs.ps1',
  'scripts/Expand-Kawai2004Inputs.ps1',
  'scripts/Test-KawaiPackage.ps1',
  'scripts/Test-Kawai2004Package.ps1',
  'scripts/Test-KawaiRuntimeInputs.ps1',
  'scripts/Test-Kawai2004Inputs.ps1',
  'scripts/Build-KawaiSourceKit.ps1',
  'scripts/Build-Kawai2004SourceKit.ps1',
  'scripts/Test-KawaiSourceKit.ps1',
  'scripts/Test-Kawai2004SourceKit.ps1',
  'scripts/Test-PublicRepository.ps1',
  'scripts/Test-PublicRepositoryGuard.ps1',
  'packaging/inputs.json',
  'packaging/KI2005.EXE.manifest',
  'packaging/Kawai2004.exe.manifest',
  'packaging/profiles/Kawai2003.dxwnd.ini.template',
  'packaging/profiles/Kawai2004.dxwnd.ini.template',
  'packaging/profiles/Kawai2005.dxwnd.ini.template',
  'packaging/portable/Launch-Kawai.ps1',
  'packaging/portable/Launch-Kawai2004.ps1',
  'packaging/portable/Play.cmd',
  'packaging/portable/README.txt',
  'packaging/portable/Verify-Package.ps1',
  'packaging/portable/Verify.cmd',
  'packaging/licenses/DXWND-NOTICE.md',
  'packaging/licenses/FMOD-3-NOTICE.md',
  'packaging/licenses/KAWAI-PERMISSION-EVIDENCE.md',
  'packaging/licenses/KAWAI2003-PERMISSION-EVIDENCE.md',
  'packaging/licenses/KAWAI2004-PERMISSION-EVIDENCE.md',
  'packaging/licenses/KAWAI2005-PERMISSION-EVIDENCE.md',
  'packaging/licenses/MICROSOFT-RUNTIME-EVIDENCE.md',
  'packaging/licenses/MINHOOK-BSD-2-CLAUSE.txt',
  'docs/ASSEMBLY.md',
  'docs/RELEASING.md',
  'docs/PUBLICATION.md',
  'docs/RELEASE_TESTING.md',
  'docs/THIRD_PARTY_NOTICES.md',
  'docs/REDISTRIBUTION.md',
  'docs/MSVBVM50_SOURCE.md',
  'docs/CORPUS_MANIFEST.md',
  'docs/KAWAI2004_LOCAL_LAUNCH.md',
  'docs/RE_LOG.md',
  'docs/RE_PLAN.md'
)

$sourceByRelativePath = @{}
foreach ($relativePath in $reviewedPaths) {
  if ($sourceByRelativePath.ContainsKey($relativePath)) {
    throw "Duplicate reviewed source-kit path: $relativePath"
  }
  $sourceByRelativePath.Add($relativePath, (Assert-SourceFile $relativePath))
}

$OutputDirectory = Get-FullPath $OutputDirectory
Assert-NoReparsePath $OutputDirectory 'output directory'
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
  [void][System.IO.Directory]::CreateDirectory($OutputDirectory)
}
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
  throw "Output path is not a directory: $OutputDirectory"
}
Assert-NoReparsePath $OutputDirectory 'output directory'

$artifactPrefix = 'Kawai-assembly-kit'
if ($UseLegacyKawai2004Name) {
  $artifactPrefix = 'Kawai2004-assembly-kit'
}
$artifactName = "$artifactPrefix-$Version"
$bundlePath = Join-Path $OutputDirectory $artifactName
$zipPath = Join-Path $OutputDirectory "$artifactName.zip"
$sidecarPath = "$zipPath.sha256"
$stagingPath = Join-Path $OutputDirectory ".$artifactName.$([Guid]::NewGuid().ToString('N')).staging"
$temporaryZip = Join-Path $OutputDirectory ".$artifactName.$([Guid]::NewGuid().ToString('N')).zip.tmp"
$temporarySidecar = Join-Path $OutputDirectory ".$artifactName.$([Guid]::NewGuid().ToString('N')).sha256.tmp"
foreach ($path in @($bundlePath, $zipPath, $sidecarPath, $stagingPath, $temporaryZip, $temporarySidecar)) {
  Assert-ChildPath $OutputDirectory $path 'artifact path'
}
foreach ($candidate in @($bundlePath, $zipPath, $sidecarPath)) {
  if (Test-Path -LiteralPath $candidate) {
    throw "Output already exists. Choose another version or output directory: $candidate"
  }
}

$bundlePublished = $false
$zipPublished = $false
$sidecarPublished = $false
try {
  [void](New-Item -ItemType Directory -Path $stagingPath)
  foreach ($relativePath in $reviewedPaths) {
    $destination = Join-Path $stagingPath ($relativePath.Replace('/', '\'))
    $destinationParent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
      [void](New-Item -ItemType Directory -Path $destinationParent)
    }
    Copy-Item -LiteralPath $sourceByRelativePath[$relativePath] -Destination $destination
  }

  $sourceKitVerifierPath = Join-Path $stagingPath 'Verify-SourceKit.ps1'
  Copy-Item -LiteralPath $sourceByRelativePath['packaging/portable/Verify-Package.ps1'] -Destination $sourceKitVerifierPath

  $manifestFiles = @()
  foreach ($relativePath in (Get-SortedArtifactPaths $stagingPath @('MANIFEST.json', 'CHECKSUMS-SHA256.txt'))) {
    $file = Get-Item -LiteralPath (Join-Path $stagingPath ($relativePath.Replace('/', '\')))
    $manifestFiles += [pscustomobject][ordered]@{
      path = $relativePath
      bytes = [long]$file.Length
      sha256 = Get-Sha256 $file.FullName
    }
  }
  $manifest = [pscustomobject][ordered]@{
    schemaVersion = 1
    version = $Version
    type = 'assembly-kit'
    runtimeRoots = @()
    files = $manifestFiles
  }
  Write-Utf8NoBom (Join-Path $stagingPath 'MANIFEST.json') (($manifest | ConvertTo-Json -Depth 5) + "`n")

  $checksumLines = New-Object System.Collections.Generic.List[string]
  foreach ($relativePath in (Get-SortedArtifactPaths $stagingPath @('CHECKSUMS-SHA256.txt'))) {
    $path = Join-Path $stagingPath ($relativePath.Replace('/', '\'))
    $checksumLines.Add("$(Get-Sha256 $path)  $relativePath")
  }
  Write-Utf8NoBom (Join-Path $stagingPath 'CHECKSUMS-SHA256.txt') (($checksumLines -join "`n") + "`n")

  New-DeterministicZip $stagingPath $temporaryZip $artifactName
  [System.IO.Directory]::Move($stagingPath, $bundlePath)
  $bundlePublished = $true
  [System.IO.File]::Move($temporaryZip, $zipPath)
  $zipPublished = $true
  $zipHash = Get-Sha256 $zipPath
  Write-Utf8NoBom $temporarySidecar "$zipHash  $([System.IO.Path]::GetFileName($zipPath))`n"
  [System.IO.File]::Move($temporarySidecar, $sidecarPath)
  $sidecarPublished = $true

  [pscustomobject][ordered]@{
    version = $Version
    bundlePath = $bundlePath
    zipPath = $zipPath
    zipSha256 = $zipHash
    checksumPath = Join-Path $bundlePath 'CHECKSUMS-SHA256.txt'
    manifestPath = Join-Path $bundlePath 'MANIFEST.json'
  }
} catch {
  if ($sidecarPublished) { Remove-OwnedFile $OutputDirectory $sidecarPath }
  if ($zipPublished) { Remove-OwnedFile $OutputDirectory $zipPath }
  if ($bundlePublished) { Remove-OwnedDirectory $OutputDirectory $bundlePath }
  throw
} finally {
  Remove-OwnedDirectory $OutputDirectory $stagingPath
  Remove-OwnedFile $OutputDirectory $temporaryZip
  Remove-OwnedFile $OutputDirectory $temporarySidecar
}
