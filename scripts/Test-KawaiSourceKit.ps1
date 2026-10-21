[CmdletBinding()]
param([switch]$KeepTemporaryFiles)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$builder = Join-Path $PSScriptRoot 'Build-KawaiSourceKit.ps1'
$legacyBuilder = Join-Path $PSScriptRoot 'Build-Kawai2004SourceKit.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kawai-source-kit-tests-" + [Guid]::NewGuid().ToString('N'))
$results = New-Object System.Collections.Generic.List[object]
$version = 'test.1'

function Get-TestHash([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-RelativePath([string]$Root, [string]$FullName) {
  return $FullName.Substring($Root.TrimEnd('\').Length + 1).Replace('\', '/')
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

function Add-TestResult([string]$Name, [scriptblock]$Body) {
  try {
    & $Body
    $script:results.Add([pscustomobject]@{ name = $Name; status = 'pass'; error = $null })
  } catch {
    $script:results.Add([pscustomobject]@{ name = $Name; status = 'fail'; error = $_.Exception.Message })
  }
}

function Invoke-TestBuild([string]$OutputDirectory) {
  return & $builder -OutputDirectory $OutputDirectory -Version $version
}

function Invoke-SourceKitVerifier([string]$BundlePath) {
  return & (Join-Path $BundlePath 'Verify-SourceKit.ps1') -Quiet
}

function Get-ExpectedPayloadPaths {
  return [string[]]@(
    'LICENSE',
    'README.md',
    'Verify-SourceKit.ps1',
    'docs/ASSEMBLY.md',
    'docs/CORPUS_MANIFEST.md',
    'docs/KAWAI2004_LOCAL_LAUNCH.md',
    'docs/MSVBVM50_SOURCE.md',
    'docs/PUBLICATION.md',
    'docs/REDISTRIBUTION.md',
    'docs/RELEASE_TESTING.md',
    'docs/RELEASING.md',
    'docs/RE_LOG.md',
    'docs/RE_PLAN.md',
    'docs/THIRD_PARTY_NOTICES.md',
    'packaging/KI2005.EXE.manifest',
    'packaging/Kawai2004.exe.manifest',
    'packaging/inputs.json',
    'packaging/profiles/Kawai2003.dxwnd.ini.template',
    'packaging/profiles/Kawai2004.dxwnd.ini.template',
    'packaging/profiles/Kawai2005.dxwnd.ini.template',
    'packaging/licenses/DXWND-NOTICE.md',
    'packaging/licenses/FMOD-3-NOTICE.md',
    'packaging/licenses/KAWAI-PERMISSION-EVIDENCE.md',
    'packaging/licenses/KAWAI2003-PERMISSION-EVIDENCE.md',
    'packaging/licenses/KAWAI2004-PERMISSION-EVIDENCE.md',
    'packaging/licenses/KAWAI2005-PERMISSION-EVIDENCE.md',
    'packaging/licenses/MICROSOFT-RUNTIME-EVIDENCE.md',
    'packaging/licenses/MINHOOK-BSD-2-CLAUSE.txt',
    'packaging/portable/Launch-Kawai.ps1',
    'packaging/portable/Launch-Kawai2004.ps1',
    'packaging/portable/Play.cmd',
    'packaging/portable/README.txt',
    'packaging/portable/Verify-Package.ps1',
    'packaging/portable/Verify.cmd',
    'scripts/Build-KawaiPackage.ps1',
    'scripts/Build-Kawai2004Package.ps1',
    'scripts/Build-KawaiSourceKit.ps1',
    'scripts/Build-Kawai2004SourceKit.ps1',
    'scripts/Expand-KawaiRuntimeInputs.ps1',
    'scripts/Expand-Kawai2004Inputs.ps1',
    'scripts/Test-KawaiPackage.ps1',
    'scripts/Test-Kawai2004Inputs.ps1',
    'scripts/Test-Kawai2004Package.ps1',
    'scripts/Test-KawaiRuntimeInputs.ps1',
    'scripts/Test-KawaiSourceKit.ps1',
    'scripts/Test-Kawai2004SourceKit.ps1',
    'scripts/Test-PublicRepository.ps1',
    'scripts/Test-PublicRepositoryGuard.ps1'
  )
}

[void](New-Item -ItemType Directory -Path $testRoot)
try {
  $outputOne = Join-Path $testRoot 'one'
  $outputTwo = Join-Path $testRoot 'two'
  $firstBuild = $null
  $secondBuild = $null
  $extractedBundle = $null

  Add-TestResult 'fresh build has the exact reviewed inventory' {
    $script:firstBuild = Invoke-TestBuild $outputOne
    Assert-True (Test-Path -LiteralPath $script:firstBuild.bundlePath -PathType Container) 'Bundle directory was not created.'
    Assert-True (Test-Path -LiteralPath $script:firstBuild.zipPath -PathType Leaf) 'ZIP was not created.'
    Assert-True (Test-Path -LiteralPath ($script:firstBuild.zipPath + '.sha256') -PathType Leaf) 'ZIP hash sidecar was not created.'

    $manifest = Get-Content -LiteralPath $script:firstBuild.manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ([int]$manifest.schemaVersion -eq 1) 'Manifest schemaVersion is wrong.'
    Assert-True ([string]$manifest.version -ceq $version) 'Manifest version is wrong.'
    Assert-True ([string]$manifest.type -ceq 'assembly-kit') 'Manifest type is wrong.'
    Assert-True (@($manifest.runtimeRoots).Count -eq 0) 'Source-kit runtimeRoots must be empty.'

    $expectedPayload = @(Get-ExpectedPayloadPaths | Sort-Object)
    $manifestPaths = @($manifest.files.path | Sort-Object)
    Assert-True (($manifestPaths -join "`n") -ceq ($expectedPayload -join "`n")) 'MANIFEST.json does not contain the exact reviewed payload.'

    $diskPaths = @(Get-ChildItem -LiteralPath $script:firstBuild.bundlePath -Recurse -File | ForEach-Object {
      Get-RelativePath $script:firstBuild.bundlePath $_.FullName
    } | Sort-Object)
    $expectedDisk = @($expectedPayload + @('CHECKSUMS-SHA256.txt', 'MANIFEST.json') | Sort-Object)
    Assert-True (($diskPaths -join "`n") -ceq ($expectedDisk -join "`n")) 'Bundle disk inventory is not exact.'

    foreach ($entry in $manifest.files) {
      $path = Join-Path $script:firstBuild.bundlePath (([string]$entry.path).Replace('/', '\'))
      Assert-True ((Get-Item -LiteralPath $path).Length -eq [long]$entry.bytes) "Manifest size mismatch: $($entry.path)"
      Assert-True ((Get-TestHash $path) -ceq [string]$entry.sha256) "Manifest hash mismatch: $($entry.path)"
      $sourceRelativePath = [string]$entry.path
      if ($sourceRelativePath -ceq 'Verify-SourceKit.ps1') {
        $sourceRelativePath = 'packaging/portable/Verify-Package.ps1'
      }
      $sourcePath = Join-Path $repoRoot ($sourceRelativePath.Replace('/', '\'))
      Assert-True ((Get-TestHash $path) -ceq (Get-TestHash $sourcePath)) "Reviewed source was rewritten: $($entry.path)"
    }

    $checksumPaths = @(Get-Content -LiteralPath $script:firstBuild.checksumPath -Encoding UTF8 | ForEach-Object {
      if ($_ -notmatch '^([a-f0-9]{64})  (.+)$') { throw "Malformed checksum line: $_" }
      $Matches[2]
    } | Sort-Object)
    $expectedChecksums = @($expectedPayload + 'MANIFEST.json' | Sort-Object)
    Assert-True (($checksumPaths -join "`n") -ceq ($expectedChecksums -join "`n")) 'Checksum inventory is not exact.'
    Invoke-SourceKitVerifier $script:firstBuild.bundlePath
  }

  Add-TestResult 'source kit contains no executable payload' {
    if ($null -eq $script:firstBuild) { throw 'Fresh build prerequisite failed.' }
    foreach ($file in Get-ChildItem -LiteralPath $script:firstBuild.bundlePath -Recurse -File) {
      Assert-True ($file.Extension -notmatch '^(?i:\.exe|\.dll)$') "Binary payload path was included: $($file.FullName)"
      $stream = [System.IO.File]::OpenRead($file.FullName)
      try {
        if ($stream.Length -ge 2) {
          $first = $stream.ReadByte()
          $second = $stream.ReadByte()
          Assert-True (-not ($first -eq 0x4d -and $second -eq 0x5a)) "MZ payload was included: $($file.FullName)"
        }
      } finally {
        $stream.Dispose()
      }
    }
  }

  Add-TestResult 'same version is deterministic across output directories' {
    if ($null -eq $script:firstBuild) { throw 'Fresh build prerequisite failed.' }
    $script:secondBuild = Invoke-TestBuild $outputTwo
    Assert-True ($script:firstBuild.zipSha256 -ceq $script:secondBuild.zipSha256) 'ZIP hashes differ across output directories.'
    Assert-True ((Get-TestHash $script:firstBuild.zipPath) -ceq (Get-TestHash $script:secondBuild.zipPath)) 'ZIP bytes differ across output directories.'

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($script:firstBuild.zipPath)
    try {
      $entryNames = [string[]]@($zip.Entries | ForEach-Object FullName)
      $sortedNames = [string[]]@($entryNames)
      [Array]::Sort($sortedNames, [System.StringComparer]::Ordinal)
      Assert-True (($entryNames -join "`n") -ceq ($sortedNames -join "`n")) 'ZIP entries are not in ordinal order.'
      foreach ($entry in $zip.Entries) {
        $timestamp = $entry.LastWriteTime
        Assert-True ($timestamp.Year -eq 2000 -and $timestamp.Month -eq 1 -and $timestamp.Day -eq 1 -and
          $timestamp.Hour -eq 0 -and $timestamp.Minute -eq 0 -and $timestamp.Second -eq 0) "ZIP timestamp is not normalized: $($entry.FullName)"
      }
    } finally {
      $zip.Dispose()
    }
  }

  Add-TestResult 'Windows PowerShell 5.1 expands and verifies the ZIP exactly' {
    if ($null -eq $script:firstBuild) { throw 'Fresh build prerequisite failed.' }
    Assert-True ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSEdition -eq 'Desktop') 'This extraction regression must run under Windows PowerShell 5.1.'

    $extractionRoot = Join-Path $testRoot 'expanded'
    Expand-Archive -LiteralPath $script:firstBuild.zipPath -DestinationPath $extractionRoot
    $script:extractedBundle = Join-Path $extractionRoot ([System.IO.Path]::GetFileNameWithoutExtension($script:firstBuild.zipPath))
    Assert-True (Test-Path -LiteralPath $script:extractedBundle -PathType Container) 'Expanded source-kit root is missing.'
    Invoke-SourceKitVerifier $script:extractedBundle

    $sourcePaths = @(Get-ChildItem -LiteralPath $script:firstBuild.bundlePath -Recurse -File | ForEach-Object {
      Get-RelativePath $script:firstBuild.bundlePath $_.FullName
    } | Sort-Object)
    $extractedPaths = @(Get-ChildItem -LiteralPath $script:extractedBundle -Recurse -File | ForEach-Object {
      Get-RelativePath $script:extractedBundle $_.FullName
    } | Sort-Object)
    Assert-True (($sourcePaths -join "`n") -ceq ($extractedPaths -join "`n")) 'Expanded ZIP inventory differs from the built source kit.'
    foreach ($relativePath in $sourcePaths) {
      $sourcePath = Join-Path $script:firstBuild.bundlePath ($relativePath.Replace('/', '\'))
      $extractedPath = Join-Path $script:extractedBundle ($relativePath.Replace('/', '\'))
      Assert-True ((Get-TestHash $sourcePath) -ceq (Get-TestHash $extractedPath)) "Expanded ZIP hash mismatch: $relativePath"
    }
  }

  Add-TestResult 'expanded source kit runs all package tests without repository fallback' {
    if ($null -eq $script:extractedBundle) { throw 'Expanded source-kit prerequisite failed.' }
    $packageTest = Join-Path $script:extractedBundle 'scripts\Test-KawaiPackage.ps1'
    Assert-True (Test-Path -LiteralPath $packageTest -PathType Leaf) 'Expanded package test script is missing.'
    $escapedPackageTest = $packageTest.Replace("'", "''")
    $runner = @"
`$ErrorActionPreference = 'Stop'
try {
  `$output = @(& '$escapedPackageTest')
  `$summary = `$output[`$output.Count - 1]
  `$testCount = [int]`$summary.tests
  if ([string]`$summary.status -cne 'pass' -or `$testCount -le 0) {
    throw "Expected a positive passing package-test result, got status='`$(`$summary.status)' tests='`$testCount'."
  }
  [Console]::Out.WriteLine("status=pass;tests=`$testCount")
  exit 0
} catch {
  [Console]::Error.WriteLine(`$_.Exception.ToString())
  exit 1
}
"@
    $encodedRunner = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($runner))
    $stdout = Join-Path $testRoot 'extracted-package-tests.stdout.txt'
    $stderr = Join-Path $testRoot 'extracted-package-tests.stderr.txt'
    $process = Start-Process -FilePath 'powershell.exe' -WorkingDirectory $script:extractedBundle `
      -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encodedRunner) `
      -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru -Wait
    $process.Refresh()
    $standardOutput = (Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue).Trim()
    $standardError = (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue).Trim()
    Assert-True ($process.ExitCode -eq 0) "Extracted package tests failed with exit code $($process.ExitCode): $standardError"
    Assert-True ($standardOutput -match '^status=pass;tests=([1-9][0-9]*)$') "Extracted package test summary was unexpected: $standardOutput"
  }

  Add-TestResult 'unexpected file and tampering are rejected' {
    if ($null -eq $script:secondBuild) { throw 'Deterministic build prerequisite failed.' }
    $unexpected = Join-Path $script:secondBuild.bundlePath 'runtime\unexpected.txt'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $unexpected))
    [System.IO.File]::WriteAllText($unexpected, 'unexpected')
    Assert-ThrowsLike { Invoke-SourceKitVerifier $script:secondBuild.bundlePath } '*Unexpected file*'
    [System.IO.Directory]::Delete((Split-Path -Parent $unexpected), $true)

    $tampered = Join-Path $script:secondBuild.bundlePath 'README.md'
    [System.IO.File]::AppendAllText($tampered, "`nTampered.`n")
    Assert-ThrowsLike { Invoke-SourceKitVerifier $script:secondBuild.bundlePath } '*Checksum mismatch*'
  }

  Add-TestResult 'existing output is protected' {
    if ($null -eq $script:firstBuild) { throw 'Fresh build prerequisite failed.' }
    $zipHashBefore = Get-TestHash $script:firstBuild.zipPath
    Assert-ThrowsLike { Invoke-TestBuild $outputOne } '*Output already exists*'
    Assert-True ((Get-TestHash $script:firstBuild.zipPath) -ceq $zipHashBefore) 'Existing ZIP changed after a rejected rebuild.'
  }

  Add-TestResult 'concurrent same-version builds preserve one complete winner' {
    $raceOutput = Join-Path $testRoot 'race'
    $raceVersion = 'race.1'
    $startTicks = [DateTime]::UtcNow.AddSeconds(2).Ticks
    $escapedBuilder = $builder.Replace("'", "''")
    $escapedOutput = $raceOutput.Replace("'", "''")
    $runnerSource = @"
`$ErrorActionPreference = 'Stop'
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
while ([DateTime]::UtcNow.Ticks -lt $startTicks) { Start-Sleep -Milliseconds 10 }
try {
  & '$escapedBuilder' -OutputDirectory '$escapedOutput' -Version '$raceVersion' | Out-Host
  [System.IO.File]::WriteAllText('__RESULT_PATH__', '0')
  exit 0
} catch {
  [Console]::Error.WriteLine(`$_.Exception.ToString())
  [System.IO.File]::WriteAllText('__RESULT_PATH__', '1')
  exit 1
}
"@

    $processes = @()
    for ($index = 0; $index -lt 2; $index++) {
      $runner = Join-Path $testRoot "race-$index-runner.ps1"
      $resultPath = Join-Path $testRoot "race-$index.result.txt"
      $escapedResultPath = $resultPath.Replace("'", "''")
      [System.IO.File]::WriteAllText(
        $runner,
        $runnerSource.Replace('__RESULT_PATH__', $escapedResultPath),
        (New-Object System.Text.UTF8Encoding($false))
      )
      $stdout = Join-Path $testRoot "race-$index.stdout.txt"
      $stderr = Join-Path $testRoot "race-$index.stderr.txt"
      $processes += Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"' + $runner + '"')
      ) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    }
    foreach ($process in $processes) {
      $process.WaitForExit()
      $process.Refresh()
    }
    $exitCodes = @(0..1 | ForEach-Object {
      $resultPath = Join-Path $testRoot "race-$_.result.txt"
      Assert-True (Test-Path -LiteralPath $resultPath -PathType Leaf) "Concurrent build $_ did not write a result."
      (Get-Content -LiteralPath $resultPath -Raw).Trim()
    })
    $successes = @($exitCodes | Where-Object { $_ -ceq '0' })
    Assert-True ($successes.Count -eq 1) "Concurrent success count was $($successes.Count); exit codes: $($exitCodes -join ', ')."

    $artifactName = "Kawai-assembly-kit-$raceVersion"
    $winner = Join-Path $raceOutput $artifactName
    $winnerZip = Join-Path $raceOutput "$artifactName.zip"
    $winnerSidecar = "$winnerZip.sha256"
    Assert-True (Test-Path -LiteralPath $winner -PathType Container) 'Concurrent winner bundle is missing.'
    Assert-True (Test-Path -LiteralPath $winnerZip -PathType Leaf) 'Concurrent winner ZIP is missing.'
    Assert-True (Test-Path -LiteralPath $winnerSidecar -PathType Leaf) 'Concurrent winner ZIP sidecar is missing.'
    Invoke-SourceKitVerifier $winner

    $nestedStaging = @(Get-ChildItem -LiteralPath $winner -Recurse -Force | Where-Object {
      $_.PSIsContainer -and $_.Name -like ".$artifactName.*.staging"
    })
    Assert-True ($nestedStaging.Count -eq 0) 'A losing staging directory was nested inside the winner.'
    $outputNames = @(Get-ChildItem -LiteralPath $raceOutput -Force | ForEach-Object Name | Sort-Object)
    $expectedOutputNames = @(@($artifactName, "$artifactName.zip", "$artifactName.zip.sha256") | Sort-Object)
    Assert-True (($outputNames -join "`n") -ceq ($expectedOutputNames -join "`n")) 'Concurrent build left unexpected output artifacts.'
  }

  Add-TestResult 'legacy builder preserves the Kawai2004 artifact name' {
    $legacyOutput = Join-Path $testRoot 'legacy'
    $legacyBuild = & $legacyBuilder -OutputDirectory $legacyOutput -Version $version
    Assert-True ([System.IO.Path]::GetFileName($legacyBuild.bundlePath) -ceq "Kawai2004-assembly-kit-$version") 'Legacy bundle name changed.'
    Assert-True ([System.IO.Path]::GetFileName($legacyBuild.zipPath) -ceq "Kawai2004-assembly-kit-$version.zip") 'Legacy ZIP name changed.'
    Invoke-SourceKitVerifier $legacyBuild.bundlePath
  }

  $failed = @($results | Where-Object status -eq 'fail')
  $results | Format-Table -AutoSize
  if ($failed.Count -gt 0) {
    throw "$($failed.Count) source-kit test(s) failed."
  }
  [pscustomobject]@{ status = 'pass'; tests = $results.Count; temporaryRoot = $(if ($KeepTemporaryFiles) { $testRoot } else { $null }) }
} finally {
  if (-not $KeepTemporaryFiles -and (Test-Path -LiteralPath $testRoot)) {
    [System.IO.Directory]::Delete($testRoot, $true)
  }
}
