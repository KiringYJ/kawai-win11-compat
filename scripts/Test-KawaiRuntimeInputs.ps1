[CmdletBinding()]
param(
  [string]$Vb5Package,
  [string]$XpSp3Package,
  [string]$DxWndArchive
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$compatRoot = Join-Path $repoRoot 'compat'
if ([string]::IsNullOrWhiteSpace($Vb5Package)) {
  $Vb5Package = Join-Path $compatRoot 'downloads\Msvbvm50.exe'
}
if ([string]::IsNullOrWhiteSpace($XpSp3Package)) {
  $XpSp3Package = Join-Path $compatRoot 'downloads\windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe'
}
if ([string]::IsNullOrWhiteSpace($DxWndArchive)) {
  $DxWndArchive = Join-Path $compatRoot 'downloads\dxwnd-v2.06.14.rar'
}

function Assert-Equal($Expected, $Actual, [string]$Description) {
  if ($Expected -ne $Actual) {
    throw "$Description failed. Expected '$Expected', got '$Actual'."
  }
}

function Assert-SafeTestPath([string]$Path, [string]$Root) {
  $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
  if (-not $fullPath.StartsWith($fullRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a test path outside compat: $fullPath"
  }
}

function Assert-NoReparseTestPath([string]$Path, [string]$Root) {
  foreach ($candidate in @($Root, $Path)) {
    $item = Get-Item -LiteralPath $candidate -Force
    if (-not $item.PSIsContainer -or
        ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Refusing to remove a test path through a reparse point: $candidate"
    }
  }
}

$testRoot = Join-Path $compatRoot ('.test-kawai-runtime-inputs.' + [Guid]::NewGuid().ToString('N'))
$output = Join-Path $testRoot 'with-directx'
$withoutDirectXOutput = Join-Path $testRoot 'without-directx'

try {
  [void](New-Item -ItemType Directory -Path $testRoot)
  $result = & (Join-Path $PSScriptRoot 'Expand-KawaiRuntimeInputs.ps1') `
    -Vb5Package $Vb5Package `
    -XpSp3Package $XpSp3Package `
    -DxWndArchive $DxWndArchive `
    -OutputDirectory $output

  Assert-Equal ([System.IO.Path]::GetFullPath($output)) $result.outputDirectory 'reported output directory'
  Assert-Equal 1355776L (Get-Item -LiteralPath (Join-Path $output 'vb5\MSVBVM50.DLL')).Length 'MSVBVM50.DLL size'
  Assert-Equal '8611DC1B60AE5C383BBA6CB3FFD8A51AEEBFF23B95844F0AB3D6E5ECD0FADC84' `
    (Get-FileHash -LiteralPath (Join-Path $output 'vb5\MSVBVM50.DLL') -Algorithm SHA256).Hash 'MSVBVM50.DLL hash'
  Assert-Equal 619008L (Get-Item -LiteralPath (Join-Path $output 'directx\dx7vb.dll')).Length 'dx7vb.dll size'
  Assert-Equal '617C432E02BA7C5B79D45E3D09ACEB21E58A14B8F13D9BE75164C3866C6C81C6' `
    (Get-FileHash -LiteralPath (Join-Path $output 'directx\dx7vb.dll') -Algorithm SHA256).Hash 'dx7vb.dll hash'
  foreach ($requiredDxWndFile in @('dxwnd.exe', 'dxwnd.dll', 'dxwplay.dll', 'gpl-3.0.txt', 'minhook-LICENSE.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $output "dxwnd\$requiredDxWndFile") -PathType Leaf)) {
      throw "Missing extracted DxWnd file: $requiredDxWndFile"
    }
  }

  $withoutDirectX = & (Join-Path $PSScriptRoot 'Expand-KawaiRuntimeInputs.ps1') `
    -Vb5Package $Vb5Package `
    -DxWndArchive $DxWndArchive `
    -OutputDirectory $withoutDirectXOutput
  Assert-Equal ([System.IO.Path]::GetFullPath($withoutDirectXOutput)) $withoutDirectX.outputDirectory 'reported output directory without DirectX'
  Assert-Equal $null $withoutDirectX.directXRuntime 'omitted DirectX runtime result'
  Assert-Equal $false (Test-Path -LiteralPath (Join-Path $withoutDirectXOutput 'directx')) 'omitted DirectX output directory'
  Assert-Equal '8611DC1B60AE5C383BBA6CB3FFD8A51AEEBFF23B95844F0AB3D6E5ECD0FADC84' `
    (Get-FileHash -LiteralPath (Join-Path $withoutDirectXOutput 'vb5\MSVBVM50.DLL') -Algorithm SHA256).Hash 'MSVBVM50.DLL hash without DirectX'
  foreach ($requiredDxWndFile in @('dxwnd.exe', 'dxwnd.dll', 'dxwplay.dll', 'gpl-3.0.txt', 'minhook-LICENSE.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $withoutDirectXOutput "dxwnd\$requiredDxWndFile") -PathType Leaf)) {
      throw "Missing extracted DxWnd file without DirectX: $requiredDxWndFile"
    }
  }

  $tamperedVb5Package = Join-Path $testRoot 'tampered-vb5.exe'
  [System.IO.File]::Copy([System.IO.Path]::GetFullPath($Vb5Package), $tamperedVb5Package)
  $tamperedStream = [System.IO.File]::Open($tamperedVb5Package, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
  try {
    $firstByte = $tamperedStream.ReadByte()
    $tamperedStream.Position = 0
    $tamperedStream.WriteByte([byte]($firstByte -bxor 0xff))
  } finally {
    $tamperedStream.Dispose()
  }
  $rejectedTamperedInput = $false
  $tamperedOutput = Join-Path $testRoot 'tampered-output'
  try {
    & (Join-Path $PSScriptRoot 'Expand-KawaiRuntimeInputs.ps1') `
      -Vb5Package $tamperedVb5Package `
      -XpSp3Package $XpSp3Package `
      -DxWndArchive $DxWndArchive `
      -OutputDirectory $tamperedOutput | Out-Null
  } catch {
    if ($_.Exception.Message -like '*failed SHA-256 validation*') {
      $rejectedTamperedInput = $true
    } else {
      throw
    }
  }
  Assert-Equal $true $rejectedTamperedInput 'tampered-input rejection'
  Assert-Equal $false (Test-Path -LiteralPath $tamperedOutput) 'no output from tampered input'

  $rejectedExistingOutput = $false
  try {
    & (Join-Path $PSScriptRoot 'Expand-KawaiRuntimeInputs.ps1') `
      -Vb5Package $Vb5Package `
      -XpSp3Package $XpSp3Package `
      -DxWndArchive $DxWndArchive `
      -OutputDirectory $output | Out-Null
  } catch {
    if ($_.Exception.Message -like 'Output already exists*') {
      $rejectedExistingOutput = $true
    } else {
      throw
    }
  }
  Assert-Equal $true $rejectedExistingOutput 'existing-output rejection'

  $legacyRejectedExistingOutput = $false
  try {
    & (Join-Path $PSScriptRoot 'Expand-Kawai2004Inputs.ps1') `
      -Vb5Package $Vb5Package `
      -XpSp3Package $XpSp3Package `
      -DxWndArchive $DxWndArchive `
      -OutputDirectory $output | Out-Null
  } catch {
    if ($_.Exception.Message -like 'Output already exists*') {
      $legacyRejectedExistingOutput = $true
    } else {
      throw
    }
  }
  Assert-Equal $true $legacyRejectedExistingOutput 'legacy-wrapper delegation'

  $atomicSource = Join-Path $testRoot 'atomic-source'
  $atomicExisting = Join-Path $testRoot 'atomic-existing'
  [void](New-Item -ItemType Directory -Path $atomicSource)
  [void](New-Item -ItemType Directory -Path $atomicExisting)
  $atomicCollisionRejected = $false
  try {
    [System.IO.Directory]::Move($atomicSource, $atomicExisting)
  } catch [System.IO.IOException] {
    $atomicCollisionRejected = $true
  }
  Assert-Equal $true $atomicCollisionRejected 'atomic publication collision rejection'
  Assert-Equal $true (Test-Path -LiteralPath $atomicSource -PathType Container) 'atomic publication source preservation'
  Assert-Equal $false (Test-Path -LiteralPath (Join-Path $atomicExisting 'atomic-source')) 'atomic publication nesting prevention'

  [pscustomobject][ordered]@{
    status = 'PASS'
    outputFileCount = @(Get-ChildItem -LiteralPath $output -Recurse -File).Count
    tamperedInputRejected = $rejectedTamperedInput
    existingOutputRejected = $rejectedExistingOutput
    atomicCollisionRejected = $atomicCollisionRejected
    withoutDirectXSupported = ($null -eq $withoutDirectX.directXRuntime)
    legacyWrapperDelegated = $legacyRejectedExistingOutput
  }
} finally {
  Assert-SafeTestPath $testRoot $compatRoot
  if (Test-Path -LiteralPath $testRoot) {
    Assert-NoReparseTestPath $testRoot $compatRoot
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
