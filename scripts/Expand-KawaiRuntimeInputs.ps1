[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Vb5Package,
  [string]$XpSp3Package,
  [Parameter(Mandatory = $true)][string]$DxWndArchive,
  [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$compatRoot = Join-Path $repoRoot 'compat'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $compatRoot 'assembly-inputs'
}

$pinnedInputs = @{
  vb5 = [pscustomobject]@{
    bytes = 992864L
    sha256 = 'b5f8ea5b9d8b30822a2be2cdcb89cda99ec0149832659ad81f45360daa6e6965'
  }
  xpsp3 = [pscustomobject]@{
    bytes = 331805736L
    sha256 = '62e524a552db9f6fd22d469010ea4d7e28ee06fa615a1c34362129f808916654'
  }
  dxwnd = [pscustomobject]@{
    bytes = 12127475L
    sha256 = '1d439f18819bea903659677ac0a94aab5c08533a585b5473dfb656e225ee4b5c'
  }
}

$expectedOutputs = @{
  vb5 = [pscustomobject]@{
    bytes = 1355776L
    sha256 = '8611dc1b60ae5c383bba6cb3ffd8a51aeebff23b95844f0ab3d6e5ecd0fadc84'
  }
  dx7vb = [pscustomobject]@{
    bytes = 619008L
    sha256 = '617c432e02ba7c5b79d45e3d09aceb21e58a14b8f13d9be75164c3866c6c81c6'
  }
}

function Get-FullPath([string]$Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Assert-File([string]$Path, [string]$Description) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing $Description`: $Path"
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

function Assert-MicrosoftSignature([string]$Path, [string]$Description) {
  $signature = Get-AuthenticodeSignature -LiteralPath $Path
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "$Description does not have a valid Authenticode signature: $($signature.Status): $Path"
  }
  if ($null -eq $signature.SignerCertificate -or
      $signature.SignerCertificate.Subject -notmatch '(^|,\s*)O=Microsoft Corporation(,|$)') {
    throw "$Description is not signed by Microsoft Corporation: $Path"
  }
}

function Invoke-NativeTool([string]$Tool, [string[]]$Arguments, [string]$Description) {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $toolOutput = @(& $Tool @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($exitCode -ne 0) {
    $details = ($toolOutput | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($details)) { $details = 'no diagnostic output' }
    throw "$Description failed with exit code $exitCode`: $details"
  }
  return $toolOutput
}

function Export-EmbeddedCabinet([string]$PackagePath, [string]$CabinetPath, [string]$Description) {
  # Both pinned Microsoft packages contain one outer cabinet near the start of
  # the signed executable. Read only a bounded prefix to locate its MSCF header,
  # then copy the declared cabinet bytes without launching the executable.
  $stream = [System.IO.File]::OpenRead($PackagePath)
  try {
    $prefixLength = [int][Math]::Min(1048576L, $stream.Length)
    $prefix = New-Object byte[] $prefixLength
    if ($stream.Read($prefix, 0, $prefixLength) -ne $prefixLength) {
      throw "Could not read the header of $Description."
    }
    $cabinetOffset = -1L
    $cabinetLength = 0L
    for ($index = 0; $index -le $prefix.Length - 36; $index++) {
      if ($prefix[$index] -ne 0x4d -or $prefix[$index + 1] -ne 0x53 -or
          $prefix[$index + 2] -ne 0x43 -or $prefix[$index + 3] -ne 0x46) { continue }
      $candidateLength = [long][BitConverter]::ToUInt32($prefix, $index + 8)
      if ([BitConverter]::ToUInt32($prefix, $index + 4) -eq 0 -and
          $prefix[$index + 24] -eq 3 -and $prefix[$index + 25] -eq 1 -and
          $candidateLength -ge 36 -and ([long]$index + $candidateLength) -le $stream.Length) {
        $cabinetOffset = [long]$index
        $cabinetLength = $candidateLength
        break
      }
    }
    if ($cabinetOffset -lt 0) {
      throw "$Description does not contain the expected embedded cabinet in its first 1 MiB."
    }

    $stream.Position = $cabinetOffset
    $output = [System.IO.File]::Create($CabinetPath)
    try {
      $buffer = New-Object byte[] 1048576
      $remaining = $cabinetLength
      while ($remaining -gt 0) {
        $requested = [int][Math]::Min([long]$buffer.Length, $remaining)
        $read = $stream.Read($buffer, 0, $requested)
        if ($read -le 0) { throw "Unexpected end of $Description while copying its embedded cabinet." }
        $output.Write($buffer, 0, $read)
        $remaining -= $read
      }
    } finally {
      $output.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

function Assert-SafeArchiveEntries([string[]]$Entries, [string]$Description) {
  if ($Entries.Count -eq 0) { throw "$Description is empty." }
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
  foreach ($entry in $Entries) {
    $normalized = ([string]$entry).Replace('\', '/').TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($normalized) -or $normalized.StartsWith('/') -or
        $normalized -match '^[A-Za-z]:' -or $normalized.Split('/') -contains '..') {
      throw "$Description contains an unsafe path: $entry"
    }
    if (-not $seen.Add($normalized)) {
      throw "$Description contains a duplicate path: $entry"
    }
  }
}

function Assert-SafeCleanupTarget([string]$Path, [string]$Root) {
  $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
  $prefix = $fullRoot + '\'
  if (-not $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean a path outside the extraction scratch root: $fullPath"
  }
}

function Assert-NoReparseDirectoryChain([string]$Path, [string]$Root) {
  $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
  $current = $fullPath
  while ($true) {
    $item = Get-Item -LiteralPath $current -Force
    if (-not $item.PSIsContainer) {
      throw "Expected an ordinary directory in the cleanup path: $current"
    }
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Refusing to clean through a reparse-point directory: $current"
    }
    if ($current.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) { break }
    $parent = [System.IO.Directory]::GetParent($current)
    if ($null -eq $parent -or
        -not $parent.FullName.StartsWith($fullRoot + '\', [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $parent.FullName.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Cleanup path does not descend from its expected root: $fullPath"
    }
    $current = $parent.FullName.TrimEnd('\')
  }
}

$Vb5Package = Get-FullPath $Vb5Package
$includeDirectX = -not [string]::IsNullOrWhiteSpace($XpSp3Package)
if ($includeDirectX) {
  $XpSp3Package = Get-FullPath $XpSp3Package
}
$DxWndArchive = Get-FullPath $DxWndArchive
$OutputDirectory = Get-FullPath $OutputDirectory

# Validate every source before creating a staging directory or extracting content.
Assert-FileIdentity $Vb5Package $pinnedInputs.vb5 'Visual Basic 5 runtime package'
Assert-MicrosoftSignature $Vb5Package 'Visual Basic 5 runtime package'
if ($includeDirectX) {
  Assert-FileIdentity $XpSp3Package $pinnedInputs.xpsp3 'Windows XP SP3 package'
  Assert-MicrosoftSignature $XpSp3Package 'Windows XP SP3 package'
}
Assert-FileIdentity $DxWndArchive $pinnedInputs.dxwnd 'DxWnd 2.06.14 archive'

if (Test-Path -LiteralPath $OutputDirectory) {
  throw "Output already exists; choose a new directory: $OutputDirectory"
}

$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
$expand = Join-Path $env:SystemRoot 'System32\expand.exe'
Assert-File $tar 'Windows tar.exe'
Assert-File $expand 'Windows expand.exe'

$dxWndEntries = @(Invoke-NativeTool $tar @('-tf', $DxWndArchive) 'listing the DxWnd archive')
Assert-SafeArchiveEntries $dxWndEntries 'DxWnd archive'

$scratchRoot = Join-Path $compatRoot '.kawai-input-extraction'
[void](New-Item -ItemType Directory -Path $scratchRoot -Force)
Assert-NoReparseDirectoryChain $scratchRoot $compatRoot
$stagingRoot = Join-Path $scratchRoot ([Guid]::NewGuid().ToString('N'))
$stagedOutput = Join-Path $stagingRoot 'output'
$packageScratch = Join-Path $stagingRoot 'scratch'

try {
  [void](New-Item -ItemType Directory -Path (Join-Path $stagedOutput 'vb5') -Force)
  [void](New-Item -ItemType Directory -Path (Join-Path $stagedOutput 'dxwnd') -Force)
  [void](New-Item -ItemType Directory -Path (Join-Path $packageScratch 'vb5') -Force)
  if ($includeDirectX) {
    [void](New-Item -ItemType Directory -Path (Join-Path $stagedOutput 'directx') -Force)
    [void](New-Item -ItemType Directory -Path (Join-Path $packageScratch 'xpsp3') -Force)
  }

  $vb5Cabinet = Join-Path $packageScratch 'vb5\package.cab'
  Export-EmbeddedCabinet $Vb5Package $vb5Cabinet 'Visual Basic 5 runtime package'
  [void](Invoke-NativeTool $expand @('-F:MSVBVM50.DLL', $vb5Cabinet, (Join-Path $packageScratch 'vb5')) 'extracting MSVBVM50.DLL from the VB5 package')
  $vb5Source = Join-Path $packageScratch 'vb5\MSVBVM50.DLL'
  Assert-FileIdentity $vb5Source $expectedOutputs.vb5 'extracted MSVBVM50.DLL'
  Move-Item -LiteralPath $vb5Source -Destination (Join-Path $stagedOutput 'vb5\MSVBVM50.DLL')

  if ($includeDirectX) {
    $xpCabinet = Join-Path $packageScratch 'xpsp3\package.cab'
    Export-EmbeddedCabinet $XpSp3Package $xpCabinet 'Windows XP SP3 package'
    [void](Invoke-NativeTool $expand @('-F:dx7vb.dl_', $xpCabinet, (Join-Path $packageScratch 'xpsp3')) 'extracting dx7vb.dl_ from the XP SP3 package')
    $compressedDx7Candidates = @(Get-ChildItem -LiteralPath (Join-Path $packageScratch 'xpsp3') -Recurse -File | Where-Object { $_.Name -ieq 'dx7vb.dl_' })
    if ($compressedDx7Candidates.Count -ne 1) {
      throw "The XP SP3 package did not yield exactly one dx7vb.dl_ file."
    }
    $compressedDx7 = $compressedDx7Candidates[0].FullName
    [void](Invoke-NativeTool $expand @($compressedDx7, (Join-Path $stagedOutput 'directx\dx7vb.dll')) 'expanding dx7vb.dll')
    Assert-FileIdentity (Join-Path $stagedOutput 'directx\dx7vb.dll') $expectedOutputs.dx7vb 'extracted dx7vb.dll'
  }

  [void](Invoke-NativeTool $tar @('-xf', $DxWndArchive, '-C', (Join-Path $stagedOutput 'dxwnd')) 'extracting the DxWnd archive')
  foreach ($requiredDxWndFile in @('dxwnd.exe', 'dxwnd.dll', 'dxwplay.dll', 'gpl-3.0.txt', 'minhook-LICENSE.txt')) {
    Assert-File (Join-Path $stagedOutput "dxwnd\$requiredDxWndFile") "DxWnd file $requiredDxWndFile"
  }

  $outputParent = Split-Path -Parent $OutputDirectory
  if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $outputParent -Force)
  }
  [System.IO.Directory]::Move($stagedOutput, $OutputDirectory)

  $directXRuntime = $null
  if ($includeDirectX) {
    $directXRuntime = Join-Path $OutputDirectory 'directx\dx7vb.dll'
  }
  [pscustomobject][ordered]@{
    outputDirectory = $OutputDirectory
    vb5Runtime = Join-Path $OutputDirectory 'vb5\MSVBVM50.DLL'
    directXRuntime = $directXRuntime
    dxWndDirectory = Join-Path $OutputDirectory 'dxwnd'
  }
} finally {
  Assert-SafeCleanupTarget $stagingRoot $scratchRoot
  if (Test-Path -LiteralPath $stagingRoot) {
    Assert-NoReparseDirectoryChain $stagingRoot $scratchRoot
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
  }
}
