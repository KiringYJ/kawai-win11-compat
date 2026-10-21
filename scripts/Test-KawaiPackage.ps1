[CmdletBinding()]
param([switch]$KeepTemporaryFiles)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$genericBuilder = Join-Path $PSScriptRoot 'Build-KawaiPackage.ps1'
$legacyBuilder = Join-Path $PSScriptRoot 'Build-Kawai2004Package.ps1'
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$testRootName = "kawai-package-tests-$([Guid]::NewGuid().ToString('N'))"
$testRoot = [System.IO.Path]::GetFullPath((Join-Path $tempRoot $testRootName))
if ((Split-Path -Parent $testRoot) -ne $tempRoot -or
    [System.IO.Path]::GetFileName($testRoot) -ne $testRootName) {
  throw "Temporary test root escaped the system temp directory: $testRoot"
}
$results = New-Object System.Collections.Generic.List[object]

function Write-TestBytes([string]$Path, [byte[]]$Bytes) {
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $parent)
  }
  [System.IO.File]::WriteAllBytes($Path, $Bytes)
}

function Get-TestHash([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TestBytesHash([byte[]]$Bytes) {
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha256.Dispose()
  }
}

function New-TestBytes([int]$Length, [byte]$Seed) {
  $bytes = New-Object byte[] $Length
  for ($index = 0; $index -lt $bytes.Length; $index++) {
    $bytes[$index] = [byte](($Seed + $index) % 251)
  }
  return $bytes
}

function New-TestZip([string]$Path, $Entries) {
  Add-Type -AssemblyName System.IO.Compression
  $stream = [System.IO.File]::Create($Path)
  $archive = $null
  try {
    $archive = [System.Activator]::CreateInstance(
      [System.IO.Compression.ZipArchive],
      @($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false, [System.Text.Encoding]::GetEncoding(950))
    )
    foreach ($name in @($Entries.Keys | Sort-Object)) {
      $entry = $archive.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
      $entryStream = $entry.Open()
      try {
        $bytes = [byte[]]$Entries[$name]
        $entryStream.Write($bytes, 0, $bytes.Length)
      } finally {
        $entryStream.Dispose()
      }
    }
  } finally {
    if ($null -ne $archive) { $archive.Dispose() }
    $stream.Dispose()
  }
}

function Write-TestJson([string]$Path, $Value) {
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 10) + "`n"), $encoding)
}

function Add-TestResult([string]$Name, [scriptblock]$Body) {
  try {
    & $Body
    $script:results.Add([pscustomobject]@{ name = $Name; status = 'pass'; error = $null })
  } catch {
    $script:results.Add([pscustomobject]@{ name = $Name; status = 'fail'; error = $_.Exception.Message })
  }
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-ThrowsLike([scriptblock]$Body, [string]$Pattern) {
  try {
    & $Body
  } catch {
    if ($_.Exception.Message -notlike $Pattern) {
      throw "Expected error like '$Pattern', got '$($_.Exception.Message)'"
    }
    return
  }
  throw "Expected an error like '$Pattern', but the command succeeded."
}

function Invoke-TestBuild([string]$Manifest, [string]$Archive, [string]$VbDll, [string]$DxDll, [string]$DxWnd, [string]$Output) {
  $parameters = @{
    GameArchive = $Archive
    Vb5Runtime = $VbDll
    DirectXRuntime = $DxDll
    DxWndDirectory = $DxWnd
    OutputDirectory = $Output
    Version = 'test.1'
    InputManifest = $Manifest
  }
  return & $legacyBuilder @parameters
}

function Invoke-GenericTestBuild([string]$Game, [string]$Manifest, [string]$Archive, [string]$VbDll, [string]$DxDll, [string]$DxWnd, [string]$Output, [string]$Version = 'schema2.1') {
  $parameters = @{
    Game = $Game
    GameArchive = $Archive
    Vb5Runtime = $VbDll
    DxWndDirectory = $DxWnd
    OutputDirectory = $Output
    Version = $Version
    InputManifest = $Manifest
  }
  if (-not [string]::IsNullOrWhiteSpace($DxDll)) { $parameters.DirectXRuntime = $DxDll }
  return & $genericBuilder @parameters
}

[void](New-Item -ItemType Directory -Path $testRoot)
try {
  $fixture = Join-Path $testRoot 'fixture'
  $output = Join-Path $testRoot 'output'
  $dxWnd = Join-Path $fixture 'dxwnd'
  [void](New-Item -ItemType Directory -Path $dxWnd -Force)

  $readmeName = -join @([char]0x8acb, [char]0x5148, [char]0x8b80, [char]0x6211) + '.txt'
  $gameEntries = [ordered]@{}
  $gameEntries['Kawai2004/Kawai2004.exe'] = (New-TestBytes 257 3)
  $gameEntries['Kawai2004/fmod.dll'] = (New-TestBytes 113 7)
  $gameEntries[('Kawai2004/' + $readmeName)] = (New-TestBytes 89 11)
  $archive = Join-Path $fixture 'game.zip'
  New-TestZip $archive $gameEntries
  $vbDll = Join-Path $fixture 'MSVBVM50.DLL'
  $dxDll = Join-Path $fixture 'dx7vb.dll'
  Write-TestBytes $vbDll (New-TestBytes 173 13)
  Write-TestBytes $dxDll (New-TestBytes 191 17)

  $runtimeNames = @('dxwnd.exe','dxwnd.dll','dxwplay.dll','Disasm.dll','dxwnd.wav','gpl-3.0.txt','minhook-LICENSE.txt')
  $runtimeSpecs = @()
  $seed = 21
  foreach ($name in $runtimeNames) {
    $path = Join-Path $dxWnd $name
    Write-TestBytes $path (New-TestBytes (80 + $seed) ([byte]$seed))
    $item = Get-Item -LiteralPath $path
    $runtimeSpecs += [pscustomobject][ordered]@{ path = $name; bytes = [long]$item.Length; sha256 = Get-TestHash $path }
    $seed++
  }

  $entrySpecs = @()
  foreach ($name in $gameEntries.Keys) {
    $bytes = [byte[]]$gameEntries[$name]
    $entryFile = Join-Path $fixture ([IO.Path]::GetRandomFileName())
    Write-TestBytes $entryFile $bytes
    $entrySpecs += [pscustomobject][ordered]@{
      path = $name
      outputPath = $name.Substring($name.LastIndexOf('/') + 1)
      bytes = [long]$bytes.Length
      sha256 = Get-TestHash $entryFile
    }
    [System.IO.File]::Delete($entryFile)
  }
  $expectedReadmeHash = @($entrySpecs | Where-Object { $_.outputPath -ceq $readmeName })[0].sha256
  $archiveItem = Get-Item -LiteralPath $archive
  $vbItem = Get-Item -LiteralPath $vbDll
  $dxItem = Get-Item -LiteralPath $dxDll
  $manifestObject = [pscustomobject][ordered]@{
    schemaVersion = 1
    inputs = [pscustomobject][ordered]@{
      gameArchive = [pscustomobject][ordered]@{ id='test-game'; version='1'; kind='zip'; bytes=[long]$archiveItem.Length; sha256=Get-TestHash $archive; entryNameEncoding=950; entries=$entrySpecs }
      vb5Runtime = [pscustomobject][ordered]@{ id='test-vb'; version='1'; outputName='MSVBVM50.DLL'; sourcePackage=[pscustomobject][ordered]@{bytes=1;sha256='test-only'}; output=[pscustomobject][ordered]@{bytes=[long]$vbItem.Length;sha256=Get-TestHash $vbDll} }
      directXRuntime = [pscustomobject][ordered]@{ id='test-dx';version='1';outputName='dx7vb.dll';bytes=[long]$dxItem.Length;sha256=Get-TestHash $dxDll }
      dxWnd = [pscustomobject][ordered]@{ id='test-dxwnd';version='1';binaryArchiveSha256='test-only';correspondingSource=[pscustomobject][ordered]@{sha256='test-source-only'};runtimeFiles=$runtimeSpecs }
    }
  }
  $manifest = Join-Path $fixture 'inputs.json'
  Write-TestJson $manifest $manifestObject

  $game2003Bytes = New-TestBytes 211 73
  $game2003Entries = [ordered]@{ 'Kawai2003/Kawai2003.exe' = $game2003Bytes }
  $archive2003 = Join-Path $fixture 'game-2003.zip'
  New-TestZip $archive2003 $game2003Entries
  $game2005Bytes = New-TestBytes 223 79
  $game2005Entries = [ordered]@{ 'kawai2005/KI2005.EXE' = $game2005Bytes }
  $archive2005 = Join-Path $fixture 'game-2005.zip'
  New-TestZip $archive2005 $game2005Entries
  $schema2Object = [pscustomobject][ordered]@{
    schemaVersion = 2
    games = [pscustomobject][ordered]@{
      Kawai2003 = [pscustomobject][ordered]@{
        executableName='Kawai2003.exe'; windowTitlePrefix='Kawai2003 v'; assemblyManifest=$null
        dxWndProfile='packaging/profiles/Kawai2003.dxwnd.ini.template'; requiresDirectX=$false; showInTaskbar=$false
        gameArchive=[pscustomobject][ordered]@{
          id='test-game-2003'; version='1.00'; kind='zip'; bytes=[long](Get-Item $archive2003).Length
          sha256=Get-TestHash $archive2003; entryNameEncoding=950
          entries=@([pscustomobject][ordered]@{path='Kawai2003/Kawai2003.exe';outputPath='Kawai2003.exe';bytes=[long]$game2003Bytes.Length;sha256=Get-TestBytesHash $game2003Bytes})
        }
      }
      Kawai2004 = [pscustomobject][ordered]@{
        executableName='Kawai2004.exe'; windowTitlePrefix='Kawai2004 v'; assemblyManifest='packaging/Kawai2004.exe.manifest'
        dxWndProfile='packaging/profiles/Kawai2004.dxwnd.ini.template'; requiresDirectX=$true; showInTaskbar=$false
        gameArchive=[pscustomobject][ordered]@{
          id='test-game-2004'; version='1.01'; kind='zip'; bytes=[long]$archiveItem.Length
          sha256=Get-TestHash $archive; entryNameEncoding=950; entries=$entrySpecs
        }
      }
      Kawai2005 = [pscustomobject][ordered]@{
        executableName='KI2005.EXE'; windowTitlePrefix='KAWAI 連連看 2005 v'; assemblyManifest='packaging/KI2005.EXE.manifest'
        dxWndProfile='packaging/profiles/Kawai2005.dxwnd.ini.template'; requiresDirectX=$true; showInTaskbar=$true
        gameArchive=[pscustomobject][ordered]@{
          id='test-game-2005'; version='1.00'; kind='zip'; bytes=[long](Get-Item $archive2005).Length
          sha256=Get-TestHash $archive2005; entryNameEncoding=950
          entries=@([pscustomobject][ordered]@{path='kawai2005/KI2005.EXE';outputPath='KI2005.EXE';bytes=[long]$game2005Bytes.Length;sha256=Get-TestBytesHash $game2005Bytes})
        }
      }
    }
    sharedInputs = [pscustomobject][ordered]@{
      vb5Runtime = $manifestObject.inputs.vb5Runtime
      directXRuntime = $manifestObject.inputs.directXRuntime
      dxWnd = $manifestObject.inputs.dxWnd
    }
  }
  $schema2Manifest = Join-Path $fixture 'inputs-schema2.json'
  Write-TestJson $schema2Manifest $schema2Object

  $successfulBuild = $null
  Add-TestResult 'correct pinned inputs build a complete package' {
    $script:successfulBuild = Invoke-TestBuild $manifest $archive $vbDll $dxDll $dxWnd $output
    Assert-True (Test-Path -LiteralPath $script:successfulBuild.bundlePath -PathType Container) 'Bundle directory was not created.'
    Assert-True (Test-Path -LiteralPath $script:successfulBuild.zipPath -PathType Leaf) 'ZIP was not created.'
    Assert-True ((Get-TestHash $script:successfulBuild.zipPath) -eq $script:successfulBuild.zipSha256) 'Reported ZIP hash is wrong.'
    Assert-True (Test-Path -LiteralPath ($script:successfulBuild.zipPath + '.sha256') -PathType Leaf) 'ZIP hash sidecar was not created.'
  }

  Add-TestResult 'artifact manifest and checksum inventory are exact' {
    if ($null -eq $script:successfulBuild) { throw 'Successful build prerequisite failed.' }
    $root = $script:successfulBuild.bundlePath
    $artifactManifest = Get-Content -LiteralPath (Join-Path $root 'MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($artifactManifest.redistributionStatus -eq 'not-cleared') 'Redistribution status was not fail-closed.'
    Assert-True (@($artifactManifest.runtimeRoots).Count -eq 1 -and $artifactManifest.runtimeRoots[0] -eq 'runtime') 'runtimeRoots is wrong.'
    $manifestPaths = @($artifactManifest.files.path | Sort-Object)
    $diskPaths = @(Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
      $_.FullName.Substring($root.Length + 1).Replace('\','/')
    } | Where-Object { $_ -ne 'MANIFEST.json' -and $_ -ne 'CHECKSUMS-SHA256.txt' -and -not $_.StartsWith('runtime/') } | Sort-Object)
    Assert-True (($manifestPaths -join "`n") -ceq ($diskPaths -join "`n")) 'MANIFEST.json does not exactly describe immutable files.'
    foreach ($entry in $artifactManifest.files) {
      $path = Join-Path $root (([string]$entry.path).Replace('/','\'))
      Assert-True ((Get-TestHash $path) -eq $entry.sha256) "Manifest hash mismatch: $($entry.path)"
    }
    $checksumLines = @(Get-Content -LiteralPath (Join-Path $root 'CHECKSUMS-SHA256.txt') -Encoding UTF8)
    $checksummedPaths = @($checksumLines | ForEach-Object {
      if ($_ -notmatch '^([a-f0-9]{64})  (.+)$') { throw "Malformed checksum line: $_" }
      $matches[2]
    } | Sort-Object)
    $expectedChecksummed = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Name -ne 'CHECKSUMS-SHA256.txt' } | ForEach-Object {
      $_.FullName.Substring($root.Length + 1).Replace('\','/')
    } | Sort-Object)
    Assert-True (($checksummedPaths -join "`n") -ceq ($expectedChecksummed -join "`n")) 'Checksum inventory is not exact.'
  }

  Add-TestResult 'portable verifier and PrepareOnly produce a valid runtime' {
    if ($null -eq $script:successfulBuild) { throw 'Successful build prerequisite failed.' }
    $root = $script:successfulBuild.bundlePath
    $verifier = Join-Path $root 'Verify-Package.ps1'
    $launcher = Join-Path $root 'Launch-Kawai2004.ps1'
    & $verifier -Quiet
    $prepared = & $launcher -PrepareOnly
    Assert-True ($prepared.Status -eq 'Prepared') 'PrepareOnly did not report Prepared.'
    $expectedProfile = Join-Path $root 'runtime\dxwnd\dxwnd.ini'
    Assert-True ($prepared.Profile -eq $expectedProfile) 'PrepareOnly returned the wrong profile path.'
    Assert-True (Test-Path -LiteralPath $expectedProfile -PathType Leaf) 'PrepareOnly did not create the runtime profile.'
    $profileText = [System.IO.File]::ReadAllText($expectedProfile, [Text.Encoding]::Default)
    $expectedGame = Join-Path $root 'game\Kawai2004.exe'
    $expectedGameDirectory = Join-Path $root 'game'
    Assert-True ($profileText.Contains("path0=$expectedGame")) 'Runtime profile does not point to the packaged game executable.'
    Assert-True ($profileText.Contains("startfolder0=$expectedGameDirectory")) 'Runtime profile does not point to the packaged game directory.'
    foreach ($runtimeName in $runtimeNames) {
      $source = Join-Path $root "tools\dxwnd\$runtimeName"
      $runtimeCopy = Join-Path $root "runtime\dxwnd\$runtimeName"
      Assert-True (Test-Path -LiteralPath $runtimeCopy -PathType Leaf) "PrepareOnly did not copy $runtimeName."
      Assert-True ((Get-TestHash $runtimeCopy) -eq (Get-TestHash $source)) "PrepareOnly changed $runtimeName."
    }
    & $verifier -Quiet
  }

  Add-TestResult 'PrepareOnly rejects unexpected runtime DLL before execution' {
    if ($null -eq $script:successfulBuild) { throw 'Successful build prerequisite failed.' }
    $root = $script:successfulBuild.bundlePath
    $unexpected = Join-Path $root 'runtime\dxwnd\unexpected.dll'
    Write-TestBytes $unexpected (New-TestBytes 31 67)
    try {
      Assert-ThrowsLike { & (Join-Path $root 'Launch-Kawai2004.ps1') -PrepareOnly } '*Unexpected content in runtime/dxwnd*'
    } finally {
      [System.IO.File]::Delete($unexpected)
    }
  }

  Add-TestResult 'portable verifier rejects corrupt immutable payload' {
    if ($null -eq $script:successfulBuild) { throw 'Successful build prerequisite failed.' }
    $root = $script:successfulBuild.bundlePath
    $verifier = Join-Path $root 'Verify-Package.ps1'
    $payloadPath = Join-Path $root 'game\fmod.dll'
    $originalBytes = [System.IO.File]::ReadAllBytes($payloadPath)
    try {
      $corruptBytes = [byte[]]$originalBytes.Clone()
      $corruptBytes[0] = $corruptBytes[0] -bxor 0xff
      [System.IO.File]::WriteAllBytes($payloadPath, $corruptBytes)
      Assert-ThrowsLike { & $verifier -Quiet } '*Checksum mismatch: game/fmod.dll*'
    } finally {
      [System.IO.File]::WriteAllBytes($payloadPath, $originalBytes)
    }
    & $verifier -Quiet
  }

  Add-TestResult 'portable verifier rejects unexpected root file' {
    if ($null -eq $script:successfulBuild) { throw 'Successful build prerequisite failed.' }
    $root = $script:successfulBuild.bundlePath
    $verifier = Join-Path $root 'Verify-Package.ps1'
    $unexpected = Join-Path $root 'unexpected-root.bin'
    Write-TestBytes $unexpected (New-TestBytes 23 71)
    try {
      Assert-ThrowsLike { & $verifier -Quiet } '*Unexpected file in package: unexpected-root.bin*'
    } finally {
      [System.IO.File]::Delete($unexpected)
    }
    & $verifier -Quiet
  }

  Add-TestResult 'corrupt dependency is rejected' {
    $corrupt = Join-Path $fixture 'corrupt-dx7vb.dll'
    Write-TestBytes $corrupt (New-TestBytes 191 99)
    Assert-ThrowsLike { Invoke-TestBuild $manifest $archive $vbDll $corrupt $dxWnd (Join-Path $testRoot 'corrupt-output') } '*failed SHA-256 validation*'
  }

  Add-TestResult 'missing dependency is rejected' {
    Assert-ThrowsLike { Invoke-TestBuild $manifest $archive $vbDll (Join-Path $fixture 'missing.dll') $dxWnd (Join-Path $testRoot 'missing-output') } '*Missing dx7vb.dll*'
  }

  Add-TestResult 'unexpected game archive entry is rejected' {
    $extraArchive = Join-Path $fixture 'game-extra.zip'
    $extraEntries = [ordered]@{}
    foreach ($name in $gameEntries.Keys) { $extraEntries[$name] = $gameEntries[$name] }
    $extraEntries['Kawai2004/unexpected.bin'] = (New-TestBytes 19 41)
    New-TestZip $extraArchive $extraEntries
    $extraManifestObject = $manifestObject | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $extraManifestObject.inputs.gameArchive.bytes = (Get-Item -LiteralPath $extraArchive).Length
    $extraManifestObject.inputs.gameArchive.sha256 = Get-TestHash $extraArchive
    $extraManifest = Join-Path $fixture 'inputs-extra.json'
    Write-TestJson $extraManifest $extraManifestObject
    Assert-ThrowsLike { Invoke-TestBuild $extraManifest $extraArchive $vbDll $dxDll $dxWnd (Join-Path $testRoot 'extra-output') } '*unexpected entry*'
  }

  Add-TestResult 'existing output is protected without Force' {
    if ($null -eq $script:successfulBuild) { throw 'Successful build prerequisite failed.' }
    Assert-ThrowsLike { Invoke-TestBuild $manifest $archive $vbDll $dxDll $dxWnd $output } '*Output already exists*'
  }

  Add-TestResult 'same fixture produces byte-identical ZIPs in different output roots' {
    if ($null -eq $script:successfulBuild) { throw 'Successful build prerequisite failed.' }
    $repeatBuild = Invoke-TestBuild $manifest $archive $vbDll $dxDll $dxWnd (Join-Path $testRoot 'repeat-output')
    Assert-True ($repeatBuild.zipSha256 -eq $script:successfulBuild.zipSha256) 'Repeated build produced a different ZIP hash.'
    Assert-True ((Get-TestHash $repeatBuild.zipPath) -eq (Get-TestHash $script:successfulBuild.zipPath)) 'Repeated ZIP bytes differ.'
  }

  Add-TestResult 'inbox Expand-Archive preserves the original Chinese readme' {
    if ($null -eq $script:successfulBuild) { throw 'Successful build prerequisite failed.' }
    $extractParent = Join-Path $testRoot 'expand-archive-output'
    Expand-Archive -LiteralPath $script:successfulBuild.zipPath -DestinationPath $extractParent -ErrorAction Stop
    $extractedRoot = Join-Path $extractParent 'Kawai2004-test.1'
    Assert-True (Test-Path -LiteralPath $extractedRoot -PathType Container) 'Expand-Archive did not create the expected package root.'
    $extractedReadme = Join-Path $extractedRoot "game\$readmeName"
    Assert-True (Test-Path -LiteralPath $extractedReadme -PathType Leaf) 'Expand-Archive did not preserve the Chinese readme file name.'
    $actualReadmeName = (Get-Item -LiteralPath $extractedReadme).Name
    Assert-True ($actualReadmeName -ceq $readmeName) 'Expanded readme file name differs from the original Unicode name.'
    Assert-True ((Get-TestHash $extractedReadme) -eq $expectedReadmeHash) 'Expanded readme bytes differ from the original fixture entry.'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($script:successfulBuild.zipPath)
    try {
      $expectedFileCount = @($zip.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) }).Count
    } finally {
      $zip.Dispose()
    }
    $actualFileCount = @(Get-ChildItem -LiteralPath $extractedRoot -Recurse -File).Count
    Assert-True ($actualFileCount -eq $expectedFileCount) "Expand-Archive file count differs: expected $expectedFileCount, got $actualFileCount."
    & (Join-Path $extractedRoot 'Verify-Package.ps1') -Quiet
  }

  Add-TestResult 'concurrent same-version builds publish exactly one intact winner' {
    $raceOutput = Join-Path $testRoot 'race-output'
    $literal = {
      param([string]$Value)
      return "'" + $Value.Replace("'", "''") + "'"
    }
    $workerCommand = @(
      '& ' + (& $literal $legacyBuilder),
      '-GameArchive ' + (& $literal $archive),
      '-Vb5Runtime ' + (& $literal $vbDll),
      '-DirectXRuntime ' + (& $literal $dxDll),
      '-DxWndDirectory ' + (& $literal $dxWnd),
      '-OutputDirectory ' + (& $literal $raceOutput),
      '-Version race.1',
      '-InputManifest ' + (& $literal $manifest)
    ) -join ' '
    $processes = @()
    for ($worker = 1; $worker -le 2; $worker++) {
      $stdout = Join-Path $testRoot "race-$worker.stdout.txt"
      $stderr = Join-Path $testRoot "race-$worker.stderr.txt"
      $successMarker = Join-Path $testRoot "race-$worker.success"
      $failureMarker = Join-Path $testRoot "race-$worker.failure"
      $wrappedCommand = "try { $workerCommand | Out-String | Out-Null; " +
        "[IO.File]::WriteAllText($(& $literal $successMarker), 'success'); exit 0 " +
        "} catch { [IO.File]::WriteAllText($(& $literal $failureMarker), `$_.Exception.Message); exit 1 }"
      $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wrappedCommand))
      $processes += Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encodedCommand) `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    }
    foreach ($process in $processes) { $process.WaitForExit(); $process.Refresh() }
    Assert-True (@($processes | Where-Object { $_.HasExited }).Count -eq 2) 'Concurrent build workers did not both exit.'
    $successMarkers = @(Get-ChildItem -LiteralPath $testRoot -File -Filter 'race-*.success')
    $failureMarkers = @(Get-ChildItem -LiteralPath $testRoot -File -Filter 'race-*.failure')
    Assert-True ($successMarkers.Count -eq 1) "Expected one successful concurrent build; success markers: $($successMarkers.Count)."
    Assert-True ($failureMarkers.Count -eq 1) "Expected one rejected concurrent build; failure markers: $($failureMarkers.Count)."

    $winnerRoot = Join-Path $raceOutput 'Kawai2004-race.1'
    $winnerZip = Join-Path $raceOutput 'Kawai2004-race.1.zip'
    $winnerSidecar = "$winnerZip.sha256"
    Assert-True (Test-Path -LiteralPath $winnerRoot -PathType Container) 'Concurrent winner bundle is missing.'
    Assert-True (Test-Path -LiteralPath $winnerZip -PathType Leaf) 'Concurrent winner ZIP is missing.'
    Assert-True (Test-Path -LiteralPath $winnerSidecar -PathType Leaf) 'Concurrent winner ZIP sidecar is missing.'
    & (Join-Path $winnerRoot 'Verify-Package.ps1') -Quiet
    $nestedStaging = @(Get-ChildItem -LiteralPath $winnerRoot -Recurse -Directory -Force | Where-Object { $_.Name -like '*.staging' })
    Assert-True ($nestedStaging.Count -eq 0) 'A losing staging directory was nested inside the winner bundle.'
    $orphanStaging = @(Get-ChildItem -LiteralPath $raceOutput -Directory -Force | Where-Object { $_.Name -like '*.staging' })
    Assert-True ($orphanStaging.Count -eq 0) 'A concurrent build left an orphan staging directory.'
    $sidecarLine = (Get-Content -LiteralPath $winnerSidecar -Raw -Encoding UTF8).Trim()
    Assert-True ($sidecarLine.StartsWith((Get-TestHash $winnerZip) + '  ')) 'Concurrent winner ZIP sidecar has the wrong hash.'
  }

  $schema2Builds = @{}
  Add-TestResult 'schema version 2 selects exact metadata manifest and profile for all games' {
    $cases = @(
      [pscustomobject]@{game='Kawai2003';archive=$archive2003;exe='Kawai2003.exe';title='Kawai2003 v';originalVersion='1.00';profile='Kawai2003.dxwnd.ini.template';directX=$false;showTaskbar=$false;module='module0=';ver='ver0=0'},
      [pscustomobject]@{game='Kawai2004';archive=$archive;exe='Kawai2004.exe';title='Kawai2004 v';originalVersion='1.01';profile='Kawai2004.dxwnd.ini.template';directX=$true;showTaskbar=$false;module='module0=dx7vb.dll';ver='ver0=2'},
      [pscustomobject]@{game='Kawai2005';archive=$archive2005;exe='KI2005.EXE';title='KAWAI 連連看 2005 v';originalVersion='1.00';profile='Kawai2005.dxwnd.ini.template';directX=$true;showTaskbar=$true;module='module0=dx7vb.dll';ver='ver0=2'}
    )
    foreach ($case in $cases) {
      $caseOutput = Join-Path $testRoot ("schema2-" + $case.game)
      $directX = $(if ($case.directX) { $dxDll } else { $null })
      $build = Invoke-GenericTestBuild $case.game $schema2Manifest $case.archive $vbDll $directX $dxWnd $caseOutput
      $script:schema2Builds[$case.game] = $build
      Assert-True ((Split-Path -Leaf $build.bundlePath) -ceq "$($case.game)-schema2.1") "Wrong artifact name for $($case.game)."
      $metadataPath = Join-Path $build.bundlePath 'PACKAGE-GAME.json'
      $metadata = Get-Content -LiteralPath $metadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
      Assert-True ([int]$metadata.schemaVersion -eq 1 -and [string]$metadata.game -ceq $case.game) "Wrong package game metadata for $($case.game)."
      Assert-True ([string]$metadata.originalVersion -ceq $case.originalVersion) "Wrong original version for $($case.game)."
      Assert-True ([string]$metadata.executablePath -ceq "game/$($case.exe)") "Wrong executable path for $($case.game)."
      Assert-True ([string]$metadata.windowTitlePrefix -ceq $case.title) "Wrong title prefix for $($case.game)."
      Assert-True ($metadata.showInTaskbar -is [System.Boolean] -and [bool]$metadata.showInTaskbar -eq $case.showTaskbar) "Wrong taskbar policy for $($case.game)."
      Assert-True (Test-Path -LiteralPath (Join-Path $build.bundlePath "game\$($case.exe)") -PathType Leaf) "Selected executable missing for $($case.game)."
      Assert-True ((Get-TestHash (Join-Path $build.bundlePath 'dxwnd.ini.template')) -ceq (Get-TestHash (Join-Path $repoRoot "packaging\profiles\$($case.profile)"))) "Wrong profile copied for $($case.game)."
      $profileText = Get-Content -LiteralPath (Join-Path $build.bundlePath 'dxwnd.ini.template') -Raw
      Assert-True ($profileText.Contains($case.module) -and $profileText.Contains($case.ver)) "Profile baseline is wrong for $($case.game)."
      $dxPath = Join-Path $build.bundlePath 'game\dx7vb.dll'
      $assemblyPath = Join-Path $build.bundlePath "game\$($case.exe).manifest"
      Assert-True ((Test-Path -LiteralPath $dxPath -PathType Leaf) -eq $case.directX) "DirectX payload selection is wrong for $($case.game)."
      Assert-True ((Test-Path -LiteralPath $assemblyPath -PathType Leaf) -eq $case.directX) "Assembly manifest selection is wrong for $($case.game)."
      $artifactManifest = Get-Content -LiteralPath (Join-Path $build.bundlePath 'MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
      $hasDirectXMetadata = $null -ne $artifactManifest.inputs.PSObject.Properties['directXRuntime']
      Assert-True ($hasDirectXMetadata -eq $case.directX) "DirectX manifest metadata selection is wrong for $($case.game)."
      Assert-True (@($artifactManifest.runtimeRoots).Count -eq 1 -and $artifactManifest.runtimeRoots[0] -ceq 'runtime') "runtimeRoots is wrong for $($case.game)."
      Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $build.bundlePath 'tools\dxwnd') -File).Count -eq 7) "DxWnd subset is wrong for $($case.game)."
      & (Join-Path $build.bundlePath 'Verify-Package.ps1') -Quiet
      Assert-True ((Test-Path -LiteralPath (Join-Path $build.bundlePath 'Launch-Kawai2004.ps1') -PathType Leaf) -eq ($case.game -ceq 'Kawai2004')) "Legacy launcher selection is wrong for $($case.game)."
    }
  }

  Add-TestResult 'schema compatibility rejects non-2004 schema 1 missing games and missing DirectX' {
    Assert-ThrowsLike {
      Invoke-GenericTestBuild 'Kawai2003' $manifest $archive $vbDll $null $dxWnd (Join-Path $testRoot 'schema1-non2004')
    } '*schema version 1 only supports Kawai2004*'
    $missingGameObject = $schema2Object | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $missingGameObject.games.PSObject.Properties.Remove('Kawai2005')
    $missingGameManifest = Join-Path $fixture 'inputs-schema2-missing-game.json'
    Write-TestJson $missingGameManifest $missingGameObject
    Assert-ThrowsLike {
      Invoke-GenericTestBuild 'Kawai2005' $missingGameManifest $archive2005 $vbDll $dxDll $dxWnd (Join-Path $testRoot 'missing-game')
    } '*does not define game: Kawai2005*'
    Assert-ThrowsLike {
      Invoke-GenericTestBuild 'Kawai2005' $schema2Manifest $archive2005 $vbDll $null $dxWnd (Join-Path $testRoot 'missing-directx')
    } '*DirectXRuntime is required for Kawai2005*'
  }

  Add-TestResult 'safe nested outputs build while unsafe and case-colliding outputs are rejected' {
    $nestedExe = New-TestBytes 137 83
    $nestedAsset = New-TestBytes 41 89
    $nestedEntries = [ordered]@{
      'Kawai2003/' = [byte[]]@()
      'Kawai2003/assets/' = [byte[]]@()
      'Kawai2003/Kawai2003.exe' = $nestedExe
      'Kawai2003/assets/score.dat' = $nestedAsset
    }
    $nestedArchive = Join-Path $fixture 'nested-game.zip'
    New-TestZip $nestedArchive $nestedEntries
    $nestedObject = $schema2Object | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $nestedObject.games.Kawai2003.gameArchive.bytes = [long](Get-Item $nestedArchive).Length
    $nestedObject.games.Kawai2003.gameArchive.sha256 = Get-TestHash $nestedArchive
    $nestedObject.games.Kawai2003.gameArchive.entries = @(
      [pscustomobject][ordered]@{path='Kawai2003/Kawai2003.exe';outputPath='Kawai2003.exe';bytes=[long]$nestedExe.Length;sha256=Get-TestBytesHash $nestedExe},
      [pscustomobject][ordered]@{path='Kawai2003/assets/score.dat';outputPath='data/score.dat';bytes=[long]$nestedAsset.Length;sha256=Get-TestBytesHash $nestedAsset}
    )
    $nestedManifest = Join-Path $fixture 'inputs-schema2-nested.json'
    Write-TestJson $nestedManifest $nestedObject
    $nestedBuild = Invoke-GenericTestBuild 'Kawai2003' $nestedManifest $nestedArchive $vbDll $null $dxWnd (Join-Path $testRoot 'nested-output') 'nested.1'
    Assert-True (Test-Path -LiteralPath (Join-Path $nestedBuild.bundlePath 'game\data\score.dat') -PathType Leaf) 'Safe nested output was not created.'
    & (Join-Path $nestedBuild.bundlePath 'Verify-Package.ps1') -Quiet

    foreach ($unsafePath in @('../escape.dat','C:/escape.dat','safe.dat:stream',("bad" + [char]10 + "name.dat"))) {
      $unsafeObject = $nestedObject | ConvertTo-Json -Depth 10 | ConvertFrom-Json
      $unsafeObject.games.Kawai2003.gameArchive.entries[1].outputPath = $unsafePath
      $unsafeManifest = Join-Path $fixture ("inputs-unsafe-$([Guid]::NewGuid().ToString('N')).json")
      Write-TestJson $unsafeManifest $unsafeObject
      Assert-ThrowsLike {
        Invoke-GenericTestBuild 'Kawai2003' $unsafeManifest $nestedArchive $vbDll $null $dxWnd (Join-Path $testRoot ("unsafe-" + [Guid]::NewGuid().ToString('N'))) 'unsafe.1'
      } '*Unsafe game output path in input manifest*'
    }
    $collisionObject = $nestedObject | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $collisionObject.games.Kawai2003.gameArchive.entries[0].outputPath = 'Data/File.dat'
    $collisionObject.games.Kawai2003.gameArchive.entries[1].outputPath = 'data/file.dat'
    $collisionManifest = Join-Path $fixture 'inputs-case-collision.json'
    Write-TestJson $collisionManifest $collisionObject
    Assert-ThrowsLike {
      Invoke-GenericTestBuild 'Kawai2003' $collisionManifest $nestedArchive $vbDll $null $dxWnd (Join-Path $testRoot 'case-collision') 'collision.1'
    } '*Case-colliding game output path*'
  }

  Add-TestResult 'PACKAGE-GAME metadata is immutable and PrepareOnly consumes verified metadata' {
    $build = $script:schema2Builds['Kawai2003']
    if ($null -eq $build) { throw 'Schema version 2 build prerequisite failed.' }
    $root = $build.bundlePath
    $launcher = Join-Path $root 'Launch-Kawai.ps1'
    $verifier = Join-Path $root 'Verify-Package.ps1'
    $prepared = & $launcher -PrepareOnly
    Assert-True ($prepared.Status -ceq 'Prepared') 'Generic PrepareOnly did not report Prepared.'
    $profileText = [System.IO.File]::ReadAllText($prepared.Profile, [Text.Encoding]::Default)
    Assert-True ($profileText.Contains("path0=$(Join-Path $root 'game\Kawai2003.exe')")) 'PrepareOnly ignored package metadata executablePath.'
    $metadataPath = Join-Path $root 'PACKAGE-GAME.json'
    $originalMetadata = [System.IO.File]::ReadAllBytes($metadataPath)
    try {
      [System.IO.File]::AppendAllText($metadataPath, "`n")
      Assert-ThrowsLike { & $verifier -Quiet } '*Checksum mismatch: PACKAGE-GAME.json*'
      Assert-ThrowsLike { & $launcher -PrepareOnly } '*Checksum mismatch: PACKAGE-GAME.json*'
    } finally {
      [System.IO.File]::WriteAllBytes($metadataPath, $originalMetadata)
    }
    & $verifier -Quiet
  }

  Add-TestResult 'lowercase game API values normalize schema 1 and 2 outputs metadata and wrappers' {
    $schema1Lower = Invoke-GenericTestBuild 'kawai2004' $manifest $archive $vbDll $dxDll $dxWnd (Join-Path $testRoot 'lower-schema1') 'lower1.1'
    Assert-True ((Split-Path -Leaf $schema1Lower.bundlePath) -ceq 'Kawai2004-lower1.1') 'Schema 1 lowercase game produced a noncanonical root.'
    $schema1Metadata = Get-Content -LiteralPath (Join-Path $schema1Lower.bundlePath 'PACKAGE-GAME.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ([string]$schema1Metadata.game -ceq 'Kawai2004') 'Schema 1 lowercase game produced noncanonical metadata.'
    Assert-True (Test-Path -LiteralPath (Join-Path $schema1Lower.bundlePath 'Launch-Kawai2004.ps1') -PathType Leaf) 'Schema 1 lowercase game omitted the compatibility launcher.'
    & (Join-Path $schema1Lower.bundlePath 'Verify-Package.ps1') -Quiet

    $schema2Lower = Invoke-GenericTestBuild 'kawai2004' $schema2Manifest $archive $vbDll $dxDll $dxWnd (Join-Path $testRoot 'lower-schema2') 'lower2.1'
    Assert-True ((Split-Path -Leaf $schema2Lower.bundlePath) -ceq 'Kawai2004-lower2.1') 'Schema 2 lowercase game produced a noncanonical root.'
    $schema2Metadata = Get-Content -LiteralPath (Join-Path $schema2Lower.bundlePath 'PACKAGE-GAME.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ([string]$schema2Metadata.game -ceq 'Kawai2004') 'Schema 2 lowercase game produced noncanonical metadata.'
    Assert-True (Test-Path -LiteralPath (Join-Path $schema2Lower.bundlePath 'Launch-Kawai2004.ps1') -PathType Leaf) 'Schema 2 lowercase game omitted the compatibility launcher.'
    & (Join-Path $schema2Lower.bundlePath 'Verify-Package.ps1') -Quiet

    Assert-True ((Split-Path -Leaf $script:successfulBuild.bundlePath) -ceq 'Kawai2004-test.1') 'Legacy builder wrapper produced a noncanonical root.'
    Assert-True (Test-Path -LiteralPath (Join-Path $script:successfulBuild.bundlePath 'Launch-Kawai2004.ps1') -PathType Leaf) 'Legacy builder wrapper omitted its launcher wrapper.'
  }

  Add-TestResult 'launcher-incompatible executable and title metadata are rejected before output creation' {
    $invalidCases = @(
      [pscustomobject]@{name='bad-executable';executableName='Bad!.exe';title='Valid title'},
      [pscustomobject]@{name='long-title';executableName='Kawai2003.exe';title=(-join ([string[]](1..129 | ForEach-Object { 'x' })))},
      [pscustomobject]@{name='control-title';executableName='Kawai2003.exe';title=('Bad' + [char]0x1f + 'Title')}
    )
    foreach ($invalidCase in $invalidCases) {
      $invalidObject = $schema2Object | ConvertTo-Json -Depth 10 | ConvertFrom-Json
      $invalidObject.games.Kawai2003.executableName = $invalidCase.executableName
      $invalidObject.games.Kawai2003.windowTitlePrefix = $invalidCase.title
      $invalidManifest = Join-Path $fixture ("inputs-$($invalidCase.name).json")
      Write-TestJson $invalidManifest $invalidObject
      $invalidOutput = Join-Path $testRoot ("invalid-metadata-" + $invalidCase.name)
      Assert-ThrowsLike {
        Invoke-GenericTestBuild 'Kawai2003' $invalidManifest $archive2003 $vbDll $null $dxWnd $invalidOutput 'invalid.1'
      } $(if ($invalidCase.name -eq 'bad-executable') { '*executableName is invalid*' } else { '*windowTitlePrefix is invalid*' })
      Assert-True (-not (Test-Path -LiteralPath $invalidOutput)) "Invalid metadata created an output directory: $($invalidCase.name)"
    }
  }

  Add-TestResult 'requiresDirectX must be a present JSON Boolean before output creation' {
    $cases = @(
      [pscustomobject]@{name='missing';value=$null;remove=$true},
      [pscustomobject]@{name='null';value=$null;remove=$false},
      [pscustomobject]@{name='string';value='false';remove=$false},
      [pscustomobject]@{name='object';value=[pscustomobject]@{enabled=$false};remove=$false}
    )
    foreach ($case in $cases) {
      $invalidObject = $schema2Object | ConvertTo-Json -Depth 10 | ConvertFrom-Json
      if ($case.remove) {
        $invalidObject.games.Kawai2003.PSObject.Properties.Remove('requiresDirectX')
      } else {
        $invalidObject.games.Kawai2003.requiresDirectX = $case.value
      }
      $invalidManifest = Join-Path $fixture ("inputs-requires-directx-$($case.name).json")
      Write-TestJson $invalidManifest $invalidObject
      $invalidOutput = Join-Path $testRoot ("invalid-requires-directx-" + $case.name)
      Assert-ThrowsLike {
        Invoke-GenericTestBuild 'Kawai2003' $invalidManifest $archive2003 $vbDll $null $dxWnd $invalidOutput 'invalid.1'
      } '*requiresDirectX must be a Boolean*'
      Assert-True (-not (Test-Path -LiteralPath $invalidOutput)) "Malformed requiresDirectX created an output directory: $($case.name)"
    }
  }

  Add-TestResult 'DxWnd runtime inventory requires unique root launcher files before output creation' {
    $cases = @('empty','nested','case-collision','missing-dll')
    foreach ($case in $cases) {
      $invalidObject = $schema2Object | ConvertTo-Json -Depth 10 | ConvertFrom-Json
      $expectedError = $null
      switch ($case) {
        'empty' {
          $invalidObject.sharedInputs.dxWnd.runtimeFiles = @()
          $expectedError = '*runtimeFiles must be a nonempty inventory*'
        }
        'nested' {
          $invalidObject.sharedInputs.dxWnd.runtimeFiles[0].path = 'bin/dxwnd.exe'
          $expectedError = '*must be a root file name*'
        }
        'case-collision' {
          $duplicate = $invalidObject.sharedInputs.dxWnd.runtimeFiles[0] | ConvertTo-Json -Depth 4 | ConvertFrom-Json
          $duplicate.path = 'DXWND.EXE'
          $invalidObject.sharedInputs.dxWnd.runtimeFiles = @($invalidObject.sharedInputs.dxWnd.runtimeFiles) + @($duplicate)
          $expectedError = '*duplicate or case-colliding path*'
        }
        'missing-dll' {
          $invalidObject.sharedInputs.dxWnd.runtimeFiles = @($invalidObject.sharedInputs.dxWnd.runtimeFiles | Where-Object { $_.path -cne 'dxwnd.dll' })
          $expectedError = '*must contain dxwnd.exe and dxwnd.dll*'
        }
      }
      $invalidManifest = Join-Path $fixture ("inputs-dxwnd-inventory-$case.json")
      Write-TestJson $invalidManifest $invalidObject
      $invalidOutput = Join-Path $testRoot ("invalid-dxwnd-inventory-" + $case)
      Assert-ThrowsLike {
        Invoke-GenericTestBuild 'Kawai2003' $invalidManifest $archive2003 $vbDll $null $dxWnd $invalidOutput 'invalid.1'
      } $expectedError
      Assert-True (-not (Test-Path -LiteralPath $invalidOutput)) "Malformed DxWnd inventory created an output directory: $case"
    }
  }

  Add-TestResult 'showInTaskbar propagates defaults false and rejects non-Boolean values' {
    $kawai2004Metadata = Get-Content -LiteralPath (Join-Path $script:schema2Builds['Kawai2004'].bundlePath 'PACKAGE-GAME.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $kawai2005Metadata = Get-Content -LiteralPath (Join-Path $script:schema2Builds['Kawai2005'].bundlePath 'PACKAGE-GAME.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $schema1Metadata = Get-Content -LiteralPath (Join-Path $script:successfulBuild.bundlePath 'PACKAGE-GAME.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($kawai2005Metadata.showInTaskbar -is [System.Boolean] -and $kawai2005Metadata.showInTaskbar) 'Kawai2005 did not propagate showInTaskbar=true.'
    Assert-True ($kawai2004Metadata.showInTaskbar -is [System.Boolean] -and -not $kawai2004Metadata.showInTaskbar) 'Kawai2004 did not propagate showInTaskbar=false.'
    Assert-True ($schema1Metadata.showInTaskbar -is [System.Boolean] -and -not $schema1Metadata.showInTaskbar) 'Schema version 1 did not default showInTaskbar=false.'

    $absentObject = $schema2Object | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $absentObject.games.Kawai2003.PSObject.Properties.Remove('showInTaskbar')
    $absentManifest = Join-Path $fixture 'inputs-show-in-taskbar-absent.json'
    Write-TestJson $absentManifest $absentObject
    $absentBuild = Invoke-GenericTestBuild 'Kawai2003' $absentManifest $archive2003 $vbDll $null $dxWnd (Join-Path $testRoot 'show-in-taskbar-absent') 'absent.1'
    $absentMetadata = Get-Content -LiteralPath (Join-Path $absentBuild.bundlePath 'PACKAGE-GAME.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($absentMetadata.showInTaskbar -is [System.Boolean] -and -not $absentMetadata.showInTaskbar) 'Absent showInTaskbar did not default false.'
    & (Join-Path $absentBuild.bundlePath 'Verify-Package.ps1') -Quiet

    $invalidValues = @($null, 'true', 1, [pscustomobject]@{enabled=$true})
    for ($index = 0; $index -lt $invalidValues.Count; $index++) {
      $invalidObject = $schema2Object | ConvertTo-Json -Depth 10 | ConvertFrom-Json
      $invalidObject.games.Kawai2005.showInTaskbar = $invalidValues[$index]
      $invalidManifest = Join-Path $fixture "inputs-show-in-taskbar-invalid-$index.json"
      Write-TestJson $invalidManifest $invalidObject
      $invalidOutput = Join-Path $testRoot "invalid-show-in-taskbar-$index"
      Assert-ThrowsLike {
        Invoke-GenericTestBuild 'Kawai2005' $invalidManifest $archive2005 $vbDll $dxDll $dxWnd $invalidOutput 'invalid.1'
      } '*showInTaskbar must be a Boolean*'
      Assert-True (-not (Test-Path -LiteralPath $invalidOutput)) "Malformed showInTaskbar created an output directory: $index"
    }
  }

  $failed = @($results | Where-Object status -eq 'fail')
  $results | Format-Table -AutoSize
  if ($failed.Count -gt 0) {
    $failed | Format-List
    throw "$($failed.Count) packaging test(s) failed."
  }
  [pscustomobject]@{ status = 'pass'; tests = $results.Count; temporaryRoot = $(if ($KeepTemporaryFiles) { $testRoot } else { $null }) }
} finally {
  if (-not $KeepTemporaryFiles -and (Test-Path -LiteralPath $testRoot)) {
    $cleanupPath = [System.IO.Path]::GetFullPath($testRoot)
    if ((Split-Path -Parent $cleanupPath) -ne $tempRoot -or
        [System.IO.Path]::GetFileName($cleanupPath) -ne $testRootName) {
      throw "Refusing to clean an unexpected path: $cleanupPath"
    }
    $cleanupItem = Get-Item -LiteralPath $cleanupPath -Force
    if (($cleanupItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Refusing to recursively clean a linked test root: $cleanupPath"
    }
    [System.IO.Directory]::Delete($cleanupPath, $true)
  }
}
