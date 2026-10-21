[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scratchParent = Join-Path $repoRoot 'compat'
$scratchRoot = Join-Path $scratchParent ('public-guard-test-' + [Guid]::NewGuid().ToString('N'))
$guard = Join-Path $PSScriptRoot 'Test-PublicRepository.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)
$results = New-Object 'Collections.Generic.List[object]'

function Invoke-TestGit([string]$Directory, [string[]]$Arguments) {
  $result = @(& git -C $Directory @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "Fixture Git command failed: $($result -join ' ')" }
}

function New-Fixture([string]$Name) {
  $directory = Join-Path $scratchRoot $Name
  [void][IO.Directory]::CreateDirectory($directory)
  Invoke-TestGit $directory @('init', '--quiet')
  Invoke-TestGit $directory @('config', 'user.name', 'Public source guard fixture')
  Invoke-TestGit $directory @('config', 'user.email', 'fixture@example.invalid')
  Invoke-TestGit $directory @('config', 'core.autocrlf', 'false')
  [IO.File]::WriteAllText((Join-Path $directory 'README.md'), 'Source-only fixture.', $utf8)
  Invoke-TestGit $directory @('add', '--', 'README.md')
  Invoke-TestGit $directory @('commit', '--quiet', '-m', 'test: add source fixture')
  return $directory
}

function Assert-Guard([string]$Name, [string]$Directory, [bool]$ShouldPass, [string]$ExpectedReason = '') {
  $savedPreference = $ErrorActionPreference
  try {
    # Rejections intentionally write to stderr; inspect the process exit code.
    $ErrorActionPreference = 'Continue'
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guard -RepositoryDirectory $Directory -AllRefs 2>&1)
    $passed = $LASTEXITCODE -eq 0
  } finally {
    $ErrorActionPreference = $savedPreference
  }
  if ($passed -ne $ShouldPass) {
    throw "Unexpected guard result for ${Name}: $($output -join ' ')"
  }
  if (-not $ShouldPass -and ($output -join ' ') -notmatch [regex]::Escape($ExpectedReason)) {
    throw "Guard rejected ${Name} for an unexpected reason: $($output -join ' ')"
  }
  $results.Add([pscustomobject]@{ Check = $Name; Passed = $true })
}

# Retain fixtures under ignored compat/ for local inspection, including failures.
[void][IO.Directory]::CreateDirectory($scratchRoot)
$clean = New-Fixture 'clean'
Assert-Guard 'clean UTF-8 source history' $clean $true

$defaultDirectory = New-Fixture 'default-directory'
$defaultScripts = Join-Path $defaultDirectory 'scripts'
[void][IO.Directory]::CreateDirectory($defaultScripts)
$defaultGuard = Join-Path $defaultScripts 'Test-PublicRepository.ps1'
Copy-Item -LiteralPath $guard -Destination $defaultGuard
Invoke-TestGit $defaultDirectory @('add', '--', 'scripts/Test-PublicRepository.ps1')
Invoke-TestGit $defaultDirectory @('commit', '--quiet', '-m', 'test: add standalone guard entry point')
$unrelatedDirectory = New-Fixture 'unrelated-directory'
[IO.File]::WriteAllBytes((Join-Path $unrelatedDirectory 'unrelated.EXE'), [byte[]](77, 90, 0, 1))
Invoke-TestGit $unrelatedDirectory @('add', '--', 'unrelated.EXE')
Invoke-TestGit $unrelatedDirectory @('commit', '--quiet', '-m', 'test: reject auditing the caller repository instead')
$savedPreference = $ErrorActionPreference
Push-Location $unrelatedDirectory
try {
  $ErrorActionPreference = 'Continue'
  $defaultOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $defaultGuard 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "No-argument guard failed from an unrelated directory: $($defaultOutput -join ' ')" }
  $results.Add([pscustomobject]@{ Check = 'no-argument entry point resolves its own checkout'; Passed = $true })
} finally {
  $ErrorActionPreference = $savedPreference
  Pop-Location
}

$historical = New-Fixture 'historical-binary'
[IO.File]::WriteAllBytes((Join-Path $historical 'GAME.EXE'), [byte[]](77, 90, 0, 1))
Invoke-TestGit $historical @('add', '--', 'GAME.EXE')
Invoke-TestGit $historical @('commit', '--quiet', '-m', 'test: add excluded binary')
Invoke-TestGit $historical @('rm', '--quiet', '--', 'GAME.EXE')
Invoke-TestGit $historical @('commit', '--quiet', '-m', 'test: remove binary from latest tree')
Assert-Guard 'binary deleted at HEAD still fails history audit' $historical $false 'Excluded input or binary path'

$renamed = New-Fixture 'renamed-binary'
[IO.File]::WriteAllBytes((Join-Path $renamed 'payload.txt'), [byte[]](77, 90, 0, 1))
Invoke-TestGit $renamed @('add', '--', 'payload.txt')
Invoke-TestGit $renamed @('commit', '--quiet', '-m', 'test: add disguised binary')
Assert-Guard 'binary content with a text extension' $renamed $false 'Non-text payload'

$corpus = New-Fixture 'excluded-corpus'
[void][IO.Directory]::CreateDirectory((Join-Path $corpus 'Kawai2004'))
[IO.File]::WriteAllText((Join-Path $corpus 'Kawai2004\readme.txt'), 'Local original metadata.', $utf8)
Invoke-TestGit $corpus @('add', '--', 'Kawai2004/readme.txt')
Invoke-TestGit $corpus @('commit', '--quiet', '-m', 'test: add local corpus path')
Assert-Guard 'local original directory with text-only contents' $corpus $false 'Excluded input or binary path'

$tagged = New-Fixture 'tagged-history'
[IO.File]::WriteAllText((Join-Path $tagged 'runtime.DLL'), 'Excluded even without PE bytes.', $utf8)
Invoke-TestGit $tagged @('add', '--', 'runtime.DLL')
Invoke-TestGit $tagged @('commit', '--quiet', '-m', 'test: add excluded DLL')
Invoke-TestGit $tagged @('tag', 'unsafe-fixture')
Invoke-TestGit $tagged @('reset', '--soft', 'HEAD~1')
Assert-Guard 'tag outside the current branch is audited' $tagged $false 'Excluded input or binary path'

$treeTag = New-Fixture 'tree-tag'
Invoke-TestGit $treeTag @('tag', 'tree-fixture', 'HEAD^{tree}')
Assert-Guard 'non-commit refs cannot silently skip inspection' $treeTag $false 'Selected ref does not point to a commit'

$replacement = New-Fixture 'replacement-ref'
Invoke-TestGit $replacement @('replace', 'HEAD', 'HEAD')
Assert-Guard 'replacement refs cannot hide original history' $replacement $false 'Replacement refs can hide history'

$customReplacement = New-Fixture 'custom-replacement-ref'
$cleanCommit = & git -C $customReplacement rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve clean fixture commit.' }
[IO.File]::WriteAllText((Join-Path $customReplacement 'hidden.EXE'), 'Excluded historical payload.', $utf8)
Invoke-TestGit $customReplacement @('add', '--', 'hidden.EXE')
Invoke-TestGit $customReplacement @('commit', '--quiet', '-m', 'test: add payload hidden by custom replacement')
$unsafeCommit = & git -C $customReplacement rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve unsafe fixture commit.' }
$savedReplacementBase = $env:GIT_REPLACE_REF_BASE
try {
  $env:GIT_REPLACE_REF_BASE = 'refs/custom-replace/'
  Invoke-TestGit $customReplacement @('replace', $unsafeCommit, $cleanCommit)
  Assert-Guard 'custom replacement namespaces do not hide original objects' $customReplacement $false 'Excluded input or binary path'
} finally {
  $env:GIT_REPLACE_REF_BASE = $savedReplacementBase
}

$grafted = New-Fixture 'grafted-history'
[IO.File]::WriteAllText((Join-Path $grafted '.git\info\grafts'), '')
Assert-Guard 'grafts cannot hide original history' $grafted $false 'Git grafts can hide history'
$savedGraftFile = $env:GIT_GRAFT_FILE
try {
  $env:GIT_GRAFT_FILE = Join-Path $grafted '.git\info\grafts'
  Assert-Guard 'custom graft paths cannot hide original history' $grafted $false 'A custom Git graft file can hide history'
} finally {
  $env:GIT_GRAFT_FILE = $savedGraftFile
}

$shallowOrigin = New-Fixture 'shallow-origin'
[IO.File]::WriteAllText((Join-Path $shallowOrigin 'README.md'), 'Second source revision.', $utf8)
Invoke-TestGit $shallowOrigin @('add', '--', 'README.md')
Invoke-TestGit $shallowOrigin @('commit', '--quiet', '-m', 'test: add another source revision')
$shallow = Join-Path $scratchRoot 'shallow-clone'
Invoke-TestGit $scratchRoot @('clone', '--quiet', '--depth', '1', '--no-local', $shallowOrigin, $shallow)
Assert-Guard 'shallow clones cannot claim complete history' $shallow $false 'Shallow history cannot establish'

$lfs = New-Fixture 'lfs-pointer'
$pointer = "version https://git-lfs.github.com/spec/v1`noid sha256:$('0' * 64)`nsize 4`n"
[IO.File]::WriteAllText((Join-Path $lfs 'payload.dat'), $pointer, $utf8)
Invoke-TestGit $lfs @('add', '--', 'payload.dat')
Invoke-TestGit $lfs @('commit', '--quiet', '-m', 'test: add binary object pointer')
Assert-Guard 'LFS pointers cannot introduce external binary payloads' $lfs $false 'Git LFS pointer'

$symbolic = New-Fixture 'symlink'
$readmeBlob = & git -C $symbolic rev-parse 'HEAD:README.md'
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve fixture blob.' }
Invoke-TestGit $symbolic @('update-index', '--add', '--cacheinfo', "120000,$readmeBlob,source-link")
Invoke-TestGit $symbolic @('commit', '--quiet', '-m', 'test: add symbolic source entry')
Assert-Guard 'symbolic links do not bypass the source inventory' $symbolic $false 'Unsupported source entry'

$submodule = New-Fixture 'submodule'
$fixtureCommit = & git -C $submodule rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve fixture commit.' }
Invoke-TestGit $submodule @('update-index', '--add', '--cacheinfo', "160000,$fixtureCommit,dependency")
Invoke-TestGit $submodule @('commit', '--quiet', '-m', 'test: add external source entry')
Assert-Guard 'submodules require a separate explicit policy' $submodule $false 'Unsupported source entry'

$archive = New-Fixture 'archive'
[IO.File]::WriteAllText((Join-Path $archive 'download.ZIP'), 'An archive path is excluded regardless of bytes.', $utf8)
Invoke-TestGit $archive @('add', '--', 'download.ZIP')
Invoke-TestGit $archive @('commit', '--quiet', '-m', 'test: add archive extension')
Assert-Guard 'uppercase archive extensions are excluded' $archive $false 'Excluded input or binary path'

$invalidText = New-Fixture 'invalid-utf8'
[IO.File]::WriteAllBytes((Join-Path $invalidText 'payload.txt'), [byte[]](195, 40))
Invoke-TestGit $invalidText @('add', '--', 'payload.txt')
Invoke-TestGit $invalidText @('commit', '--quiet', '-m', 'test: add invalid text encoding')
Assert-Guard 'invalid UTF-8 is rejected without a NUL byte' $invalidText $false 'Payload is not UTF-8 text'

$results
