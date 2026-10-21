[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('Kawai2003','Kawai2004','Kawai2005')][string]$Game,
  [Parameter(Mandatory = $true)][string]$GameArchive,
  [Parameter(Mandatory = $true)][string]$Vb5Runtime,
  [string]$DirectXRuntime,
  [Parameter(Mandatory = $true)][string]$DxWndDirectory,
  [string]$OutputDirectory,
  [string]$Version = '0.1.0-rc.1',
  [string]$InputManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

switch ($Game.ToLowerInvariant()) {
  'kawai2003' { $Game = 'Kawai2003' }
  'kawai2004' { $Game = 'Kawai2004' }
  'kawai2005' { $Game = 'Kawai2005' }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $repoRoot 'compat\releases' }
if ([string]::IsNullOrWhiteSpace($InputManifest)) { $InputManifest = Join-Path $repoRoot 'packaging\inputs.json' }
if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
  throw "Version contains characters that are unsafe in a file name: $Version"
}

function Get-FullPath([string]$Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Assert-File([string]$Path, [string]$Description) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing $Description`: $Path" }
}

function Assert-ChildPath([string]$Parent, [string]$Child, [string]$Description) {
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
  $childFull = [System.IO.Path]::GetFullPath($Child)
  if (-not $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description is outside the intended directory: $childFull"
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

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-FileIdentity([string]$Path, $Expected, [string]$Description) {
  Assert-File $Path $Description
  $item = Get-Item -LiteralPath $Path
  if ([long]$item.Length -ne [long]$Expected.bytes) {
    throw "$Description has the wrong size. Expected $($Expected.bytes), got $($item.Length): $Path"
  }
  $actualHash = Get-Sha256 $Path
  if ($actualHash -ne ([string]$Expected.sha256).ToLowerInvariant()) {
    throw "$Description failed SHA-256 validation. Expected $($Expected.sha256), got $actualHash`: $Path"
  }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-ArtifactRelativePath([string]$Root, [string]$FullName) {
  $rootPrefix = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
  $fileFull = [System.IO.Path]::GetFullPath($FullName)
  if (-not $fileFull.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "File is outside the artifact root: $fileFull"
  }
  return $fileFull.Substring($rootPrefix.Length).Replace('\', '/')
}

function Assert-SafeRelativePath([string]$Path, [string]$Description, [switch]$AllowDirectory) {
  if ([string]::IsNullOrWhiteSpace($Path)) { throw "Unsafe $Description`: $Path" }
  foreach ($character in $Path.ToCharArray()) {
    if ([char]::IsControl($character)) { throw "Unsafe $Description`: $Path" }
  }
  if ([System.IO.Path]::IsPathRooted($Path) -or $Path.StartsWith('/') -or
      $Path.StartsWith('\') -or $Path.Contains(':')) {
    throw "Unsafe $Description`: $Path"
  }
  $normalized = $Path.Replace('\', '/')
  if ($AllowDirectory) { $normalized = $normalized.TrimEnd('/') }
  if ([string]::IsNullOrWhiteSpace($normalized) -or ((-not $AllowDirectory) -and $normalized.EndsWith('/'))) {
    throw "Unsafe $Description`: $Path"
  }
  foreach ($segment in $normalized.Split('/')) {
    if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..' -or
        $segment.EndsWith('.') -or $segment.EndsWith(' ') -or
        $segment.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
      throw "Unsafe $Description`: $Path"
    }
    $deviceName = $segment.Split('.')[0]
    if ($deviceName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
      throw "Unsafe $Description`: $Path"
    }
  }
  return $normalized
}

function Get-RepositoryFile([string]$RelativePath, [string]$Description) {
  $safePath = Assert-SafeRelativePath $RelativePath $Description
  $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ($safePath.Replace('/', '\'))))
  Assert-ChildPath $repoRoot $fullPath $Description
  Assert-File $fullPath $Description
  Assert-NoReparsePath $fullPath $Description
  return $fullPath
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

function Copy-VerifiedFile([string]$Source, [string]$Destination, $Expected, [string]$Description) {
  Assert-FileIdentity $Source $Expected $Description
  $parent = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void][System.IO.Directory]::CreateDirectory($parent) }
  Copy-Item -LiteralPath $Source -Destination $Destination
}

function Expand-GameArchive([string]$ArchivePath, $ArchiveSpec, [string]$GameDirectory, [string]$GameId) {
  Assert-FileIdentity $ArchivePath $ArchiveSpec "original $GameId archive"
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $expectedByPath = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
  $expectedPathCases = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $outputCases = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($expectedEntry in $ArchiveSpec.entries) {
    $expectedPath = Assert-SafeRelativePath ([string]$expectedEntry.path) 'game entry path in input manifest'
    $outputPath = Assert-SafeRelativePath ([string]$expectedEntry.outputPath) 'game output path in input manifest'
    if (-not $expectedPathCases.Add($expectedPath)) { throw "Case-colliding game entry path in input manifest: $expectedPath" }
    if (-not $outputCases.Add($outputPath)) { throw "Case-colliding game output path in input manifest: $outputPath" }
    $expectedByPath.Add($expectedPath, [pscustomobject]@{ spec = $expectedEntry; outputPath = $outputPath })
  }
  if ($expectedByPath.Count -eq 0) { throw "The $GameId archive inventory is empty." }

  $encoding = [System.Text.Encoding]::GetEncoding([int]$ArchiveSpec.entryNameEncoding)
  $stream = [System.IO.File]::OpenRead($ArchivePath)
  $archive = $null
  try {
    $archive = [System.Activator]::CreateInstance(
      [System.IO.Compression.ZipArchive],
      @($stream, [System.IO.Compression.ZipArchiveMode]::Read, $false, $encoding)
    )
    $seenFiles = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $seenEntries = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $archive.Entries) {
      $isDirectory = [string]::IsNullOrEmpty($entry.Name)
      $entryPath = Assert-SafeRelativePath ([string]$entry.FullName) 'path in game archive' -AllowDirectory:$isDirectory
      if (-not $seenEntries.Add($entryPath)) { throw "Duplicate or case-colliding path in game archive: $entryPath" }
      if ($isDirectory) { continue }
      if (-not $expectedByPath.ContainsKey($entryPath)) { throw "The game archive contains an unexpected entry: $entryPath" }
      if (-not $seenFiles.Add($entryPath)) { throw "The game archive contains a duplicate entry: $entryPath" }
      $expected = $expectedByPath[$entryPath]
      $destination = [System.IO.Path]::GetFullPath((Join-Path $GameDirectory ($expected.outputPath.Replace('/', '\'))))
      Assert-ChildPath $GameDirectory $destination 'game archive output'
      $destinationParent = Split-Path -Parent $destination
      if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
        [void][System.IO.Directory]::CreateDirectory($destinationParent)
      }
      $inputStream = $entry.Open()
      $outputStream = $null
      try {
        $outputStream = [System.IO.File]::Open($destination, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $inputStream.CopyTo($outputStream)
      } finally {
        if ($null -ne $outputStream) { $outputStream.Dispose() }
        $inputStream.Dispose()
      }
      Assert-FileIdentity $destination $expected.spec "game archive entry $entryPath"
    }
    foreach ($expectedPath in $expectedByPath.Keys) {
      if (-not $seenFiles.Contains($expectedPath)) { throw "The game archive is missing an expected entry: $expectedPath" }
    }
  } finally {
    if ($null -ne $archive) { $archive.Dispose() }
    $stream.Dispose()
  }
}

function New-DeterministicZip([string]$SourceDirectory, [string]$ZipPath, [string]$RootName) {
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $fileStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
  $zip = $null
  try {
    $zip = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $false, [System.Text.Encoding]::UTF8)
    $relativePaths = [string[]]@(Get-ChildItem -LiteralPath $SourceDirectory -Recurse -File | ForEach-Object {
      Get-ArtifactRelativePath $SourceDirectory $_.FullName
    })
    [Array]::Sort($relativePaths, [System.StringComparer]::Ordinal)
    foreach ($relativePath in $relativePaths) {
      $entry = $zip.CreateEntry("$RootName/$relativePath", [System.IO.Compression.CompressionLevel]::Optimal)
      $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
      $entryStream = $entry.Open()
      $sourceStream = [System.IO.File]::OpenRead((Join-Path $SourceDirectory ($relativePath.Replace('/', '\'))))
      try { $sourceStream.CopyTo($entryStream) } finally { $sourceStream.Dispose(); $entryStream.Dispose() }
    }
  } finally {
    if ($null -ne $zip) { $zip.Dispose() }
    $fileStream.Dispose()
  }
}

$GameArchive = Get-FullPath $GameArchive
$Vb5Runtime = Get-FullPath $Vb5Runtime
$DxWndDirectory = Get-FullPath $DxWndDirectory
$InputManifest = Get-FullPath $InputManifest
$OutputDirectory = Get-FullPath $OutputDirectory
if (-not [string]::IsNullOrWhiteSpace($DirectXRuntime)) { $DirectXRuntime = Get-FullPath $DirectXRuntime }

Assert-File $InputManifest 'package input manifest'
Assert-NoReparsePath $InputManifest 'package input manifest'
$inputSpec = Get-Content -LiteralPath $InputManifest -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$inputSpec.schemaVersion -eq 1) {
  if ($Game -cne 'Kawai2004') { throw 'Input manifest schema version 1 only supports Kawai2004.' }
  $gameSpec = [pscustomobject][ordered]@{
    executableName = 'Kawai2004.exe'
    windowTitlePrefix = 'Kawai2004 v'
    assemblyManifest = 'packaging/Kawai2004.exe.manifest'
    dxWndProfile = 'packaging/profiles/Kawai2004.dxwnd.ini.template'
    requiresDirectX = $true
    showInTaskbar = $false
    gameArchive = $inputSpec.inputs.gameArchive
  }
  $sharedInputs = $inputSpec.inputs
} elseif ([int]$inputSpec.schemaVersion -eq 2) {
  $gameProperty = $inputSpec.games.PSObject.Properties[$Game]
  if ($null -eq $gameProperty) { throw "Input manifest does not define game: $Game" }
  $gameSpec = $gameProperty.Value
  $sharedInputs = $inputSpec.sharedInputs
} else {
  throw "Unsupported input manifest schema: $($inputSpec.schemaVersion)"
}

$executableName = Assert-SafeRelativePath ([string]$gameSpec.executableName) 'game executable name'
if ($executableName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.exe$') {
  throw "$Game executableName is invalid: $executableName"
}
$requiresDirectXProperty = $gameSpec.PSObject.Properties['requiresDirectX']
if ($null -eq $requiresDirectXProperty -or $requiresDirectXProperty.Value -isnot [System.Boolean]) {
  throw "$Game requiresDirectX must be a Boolean."
}
$requiresDirectX = [bool]$requiresDirectXProperty.Value
$showInTaskbar = $false
$showInTaskbarProperty = $gameSpec.PSObject.Properties['showInTaskbar']
if ($null -ne $showInTaskbarProperty) {
  if ($showInTaskbarProperty.Value -isnot [System.Boolean]) {
    throw "$Game showInTaskbar must be a Boolean."
  }
  $showInTaskbar = [bool]$showInTaskbarProperty.Value
}
$windowTitlePrefix = [string]$gameSpec.windowTitlePrefix
if ([string]::IsNullOrWhiteSpace($windowTitlePrefix)) { throw "$Game windowTitlePrefix is missing." }
if ($windowTitlePrefix.Length -gt 128 -or $windowTitlePrefix -match '[\x00-\x1f\x7f]') {
  throw "$Game windowTitlePrefix is invalid."
}
if ([string]::IsNullOrWhiteSpace([string]$gameSpec.gameArchive.version)) { throw "$Game original version is missing." }
if ($requiresDirectX -and [string]::IsNullOrWhiteSpace($DirectXRuntime)) {
  throw "DirectXRuntime is required for $Game."
}
foreach ($archiveEntry in $gameSpec.gameArchive.entries) {
  $outputPath = Assert-SafeRelativePath ([string]$archiveEntry.outputPath) 'game output path in input manifest'
  if ($outputPath -ieq 'MSVBVM50.DLL' -or
      ($requiresDirectX -and ($outputPath -ieq 'dx7vb.dll' -or $outputPath -ieq "$executableName.manifest"))) {
    throw "Game output path collides with a packaged runtime file: $outputPath"
  }
}
$dxWndProperty = $sharedInputs.PSObject.Properties['dxWnd']
if ($null -eq $dxWndProperty -or $null -eq $dxWndProperty.Value) {
  throw 'sharedInputs.dxWnd is missing.'
}
$runtimeFilesProperty = $dxWndProperty.Value.PSObject.Properties['runtimeFiles']
$dxWndRuntimeFiles = @()
if ($null -ne $runtimeFilesProperty) { $dxWndRuntimeFiles = @($runtimeFilesProperty.Value) }
if ($dxWndRuntimeFiles.Count -eq 0) { throw 'DxWnd runtimeFiles must be a nonempty inventory.' }
$runtimeNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($runtimeFile in $dxWndRuntimeFiles) {
  $runtimeName = Assert-SafeRelativePath ([string]$runtimeFile.path) 'DxWnd runtime path'
  if ($runtimeName.Contains('/')) { throw "DxWnd runtime path must be a root file name: $runtimeName" }
  if (-not $runtimeNames.Add($runtimeName)) { throw "DxWnd runtimeFiles contains a duplicate or case-colliding path: $runtimeName" }
}
if (-not $runtimeNames.Contains('dxwnd.exe') -or -not $runtimeNames.Contains('dxwnd.dll')) {
  throw 'DxWnd runtimeFiles must contain dxwnd.exe and dxwnd.dll.'
}
if (-not (Test-Path -LiteralPath $DxWndDirectory -PathType Container)) { throw "Missing extracted DxWnd directory: $DxWndDirectory" }
Assert-NoReparsePath $DxWndDirectory 'extracted DxWnd directory'

$profileSource = Get-RepositoryFile ([string]$gameSpec.dxWndProfile) "$Game DxWnd profile"
$assemblyManifestSource = $null
if (-not [string]::IsNullOrWhiteSpace([string]$gameSpec.assemblyManifest)) {
  $assemblyManifestSource = Get-RepositoryFile ([string]$gameSpec.assemblyManifest) "$Game assembly manifest"
}
if ($requiresDirectX -and $null -eq $assemblyManifestSource) { throw "$Game requires DirectX but has no assembly manifest." }

$portableDirectory = Join-Path $repoRoot 'packaging\portable'
$portableFiles = @('Play.cmd','Launch-Kawai.ps1','Verify.cmd','Verify-Package.ps1','README.txt')
if ($Game -ceq 'Kawai2004') { $portableFiles += 'Launch-Kawai2004.ps1' }
$portableSources = @()
foreach ($portableName in $portableFiles) { $portableSources += Get-RepositoryFile "packaging/portable/$portableName" "portable file $portableName" }
$projectLicense = Get-RepositoryFile 'LICENSE' 'project license'
$requiredDocs = @('docs/THIRD_PARTY_NOTICES.md','docs/REDISTRIBUTION.md')
$optionalDocs = @('docs/ASSEMBLY.md','docs/RELEASE_TESTING.md')
$docSources = @()
foreach ($docPath in $requiredDocs) { $docSources += Get-RepositoryFile $docPath "package document $docPath" }
foreach ($docPath in $optionalDocs) {
  $candidate = Join-Path $repoRoot ($docPath.Replace('/', '\'))
  if (Test-Path -LiteralPath $candidate -PathType Leaf) { $docSources += Get-RepositoryFile $docPath "package document $docPath" }
}
$licenseDirectory = Join-Path $repoRoot 'packaging\licenses'
if (-not (Test-Path -LiteralPath $licenseDirectory -PathType Container)) { throw "Missing packaging license directory: $licenseDirectory" }
Assert-NoReparsePath $licenseDirectory 'packaging license directory'
$licenseItems = @(Get-ChildItem -LiteralPath $licenseDirectory -Recurse -Force)
foreach ($licenseItem in $licenseItems) { Assert-NoReparsePath $licenseItem.FullName 'packaging license input' }
$licenseFiles = @($licenseItems | Where-Object { -not $_.PSIsContainer })
if ($licenseFiles.Count -eq 0) { throw "Packaging license directory is empty: $licenseDirectory" }

Assert-FileIdentity $GameArchive $gameSpec.gameArchive "original $Game archive"
Assert-FileIdentity $Vb5Runtime $sharedInputs.vb5Runtime.output 'extracted MSVBVM50.DLL'
Assert-NoReparsePath $GameArchive "original $Game archive"
Assert-NoReparsePath $Vb5Runtime 'extracted MSVBVM50.DLL'
if ($requiresDirectX) {
  Assert-FileIdentity $DirectXRuntime $sharedInputs.directXRuntime 'dx7vb.dll'
  Assert-NoReparsePath $DirectXRuntime 'dx7vb.dll'
}
foreach ($runtimeFile in $dxWndRuntimeFiles) {
  $relative = Assert-SafeRelativePath ([string]$runtimeFile.path) 'DxWnd runtime path'
  $source = [System.IO.Path]::GetFullPath((Join-Path $DxWndDirectory ($relative.Replace('/', '\'))))
  Assert-ChildPath $DxWndDirectory $source 'DxWnd runtime file'
  Assert-FileIdentity $source $runtimeFile "DxWnd runtime file $relative"
  Assert-NoReparsePath $source "DxWnd runtime file $relative"
}

Assert-NoReparsePath $OutputDirectory 'output directory'
if (-not (Test-Path -LiteralPath $OutputDirectory)) { [void][System.IO.Directory]::CreateDirectory($OutputDirectory) }
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) { throw "Output path is not a directory: $OutputDirectory" }
Assert-NoReparsePath $OutputDirectory 'output directory'
$artifactName = "$Game-$Version"
$bundlePath = Join-Path $OutputDirectory $artifactName
$zipPath = Join-Path $OutputDirectory "$artifactName.zip"
$sidecarPath = "$zipPath.sha256"
$stagingPath = Join-Path $OutputDirectory ".$artifactName.$([Guid]::NewGuid().ToString('N')).staging"
$temporaryZip = Join-Path $OutputDirectory ".$artifactName.$([Guid]::NewGuid().ToString('N')).zip.tmp"
$temporarySidecar = Join-Path $OutputDirectory ".$artifactName.$([Guid]::NewGuid().ToString('N')).sha256.tmp"
foreach ($path in @($bundlePath,$zipPath,$sidecarPath,$stagingPath,$temporaryZip,$temporarySidecar)) { Assert-ChildPath $OutputDirectory $path 'artifact path' }
foreach ($candidate in @($bundlePath,$zipPath,$sidecarPath)) {
  if (Test-Path -LiteralPath $candidate) { throw "Output already exists. Choose another version or output directory: $candidate" }
}

$bundlePublished = $false
$zipPublished = $false
$sidecarPublished = $false
try {
  [void][System.IO.Directory]::CreateDirectory($stagingPath)
  $gameDirectory = Join-Path $stagingPath 'game'
  $dxWndOutput = Join-Path $stagingPath 'tools\dxwnd'
  [void][System.IO.Directory]::CreateDirectory($gameDirectory)
  [void][System.IO.Directory]::CreateDirectory($dxWndOutput)
  Expand-GameArchive $GameArchive $gameSpec.gameArchive $gameDirectory $Game
  if (-not (Test-Path -LiteralPath (Join-Path $gameDirectory $executableName) -PathType Leaf)) {
    throw "The game archive inventory does not output executableName: $executableName"
  }
  Copy-VerifiedFile $Vb5Runtime (Join-Path $gameDirectory 'MSVBVM50.DLL') $sharedInputs.vb5Runtime.output 'extracted MSVBVM50.DLL'
  if ($requiresDirectX) {
    Copy-VerifiedFile $DirectXRuntime (Join-Path $gameDirectory 'dx7vb.dll') $sharedInputs.directXRuntime 'dx7vb.dll'
    Copy-Item -LiteralPath $assemblyManifestSource -Destination (Join-Path $gameDirectory "$executableName.manifest")
  }
  foreach ($runtimeFile in $dxWndRuntimeFiles) {
    $relative = Assert-SafeRelativePath ([string]$runtimeFile.path) 'DxWnd runtime path'
    Copy-VerifiedFile (Join-Path $DxWndDirectory ($relative.Replace('/', '\'))) (Join-Path $dxWndOutput ($relative.Replace('/', '\'))) $runtimeFile "DxWnd runtime file $relative"
  }
  foreach ($portableSource in $portableSources) { Copy-Item -LiteralPath $portableSource -Destination $stagingPath }
  Copy-Item -LiteralPath $profileSource -Destination (Join-Path $stagingPath 'dxwnd.ini.template')
  Copy-Item -LiteralPath $projectLicense -Destination (Join-Path $stagingPath 'LICENSE')

  $packageGame = [pscustomobject][ordered]@{
    schemaVersion = 1
    game = $Game
    originalVersion = [string]$gameSpec.gameArchive.version
    executablePath = "game/$executableName"
    windowTitlePrefix = $windowTitlePrefix
    showInTaskbar = $showInTaskbar
  }
  Write-Utf8NoBom (Join-Path $stagingPath 'PACKAGE-GAME.json') (($packageGame | ConvertTo-Json -Depth 3) + "`n")

  $artifactDocs = Join-Path $stagingPath 'docs'
  [void][System.IO.Directory]::CreateDirectory($artifactDocs)
  foreach ($docSource in $docSources) { Copy-Item -LiteralPath $docSource -Destination $artifactDocs }
  $artifactLicenses = Join-Path $stagingPath 'licenses'
  [void][System.IO.Directory]::CreateDirectory($artifactLicenses)
  foreach ($licenseFile in $licenseFiles) {
    $relativeLicense = Get-ArtifactRelativePath $licenseDirectory $licenseFile.FullName
    $destination = Join-Path $artifactLicenses ($relativeLicense.Replace('/', '\'))
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void][System.IO.Directory]::CreateDirectory($parent) }
    Copy-Item -LiteralPath $licenseFile.FullName -Destination $destination
  }

  $manifestFiles = @()
  $payloadPaths = [string[]]@(Get-ChildItem -LiteralPath $stagingPath -Recurse -File | ForEach-Object { Get-ArtifactRelativePath $stagingPath $_.FullName })
  [Array]::Sort($payloadPaths, [System.StringComparer]::Ordinal)
  foreach ($relativePath in $payloadPaths) {
    if ($relativePath -eq 'MANIFEST.json' -or $relativePath -eq 'CHECKSUMS-SHA256.txt') { continue }
    $file = Get-Item -LiteralPath (Join-Path $stagingPath ($relativePath.Replace('/', '\')))
    $manifestFiles += [pscustomobject][ordered]@{ path=$relativePath; bytes=[long]$file.Length; sha256=Get-Sha256 $file.FullName }
  }
  $inputMetadata = [ordered]@{
    gameArchive = [pscustomobject][ordered]@{ id=$gameSpec.gameArchive.id; version=$gameSpec.gameArchive.version; sha256=$gameSpec.gameArchive.sha256 }
    vb5Runtime = [pscustomobject][ordered]@{ id=$sharedInputs.vb5Runtime.id; version=$sharedInputs.vb5Runtime.version; sha256=$sharedInputs.vb5Runtime.output.sha256 }
  }
  if ($requiresDirectX) {
    $inputMetadata.directXRuntime = [pscustomobject][ordered]@{ id=$sharedInputs.directXRuntime.id; version=$sharedInputs.directXRuntime.version; sha256=$sharedInputs.directXRuntime.sha256 }
  }
  $inputMetadata.dxWnd = [pscustomobject][ordered]@{
    id=$sharedInputs.dxWnd.id
    version=$sharedInputs.dxWnd.version
    binaryArchiveSha256=$sharedInputs.dxWnd.binaryArchiveSha256
    correspondingSourceSha256=$sharedInputs.dxWnd.correspondingSource.sha256
  }
  $artifactManifest = [pscustomobject][ordered]@{
    schemaVersion = 1
    version = $Version
    redistributionStatus = 'not-cleared'
    runtimeRoots = @('runtime')
    inputs = [pscustomobject]$inputMetadata
    files = $manifestFiles
  }
  Write-Utf8NoBom (Join-Path $stagingPath 'MANIFEST.json') (($artifactManifest | ConvertTo-Json -Depth 8) + "`n")

  $checksumPaths = [string[]]@(Get-ChildItem -LiteralPath $stagingPath -Recurse -File | ForEach-Object { Get-ArtifactRelativePath $stagingPath $_.FullName } | Where-Object { $_ -ne 'CHECKSUMS-SHA256.txt' })
  [Array]::Sort($checksumPaths, [System.StringComparer]::Ordinal)
  $checksumLines = New-Object System.Collections.Generic.List[string]
  foreach ($relativePath in $checksumPaths) { $checksumLines.Add("$(Get-Sha256 (Join-Path $stagingPath ($relativePath.Replace('/', '\'))))  $relativePath") }
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
    game=$Game
    version=$Version
    bundlePath=$bundlePath
    zipPath=$zipPath
    zipSha256=$zipHash
    checksumPath=Join-Path $bundlePath 'CHECKSUMS-SHA256.txt'
    manifestPath=Join-Path $bundlePath 'MANIFEST.json'
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
