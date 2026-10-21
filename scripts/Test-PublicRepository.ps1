[CmdletBinding()]
param(
  [string]$RepositoryDirectory,
  [string]$Revision = 'HEAD',
  [switch]$AllRefs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ([string]::IsNullOrWhiteSpace($RepositoryDirectory)) {
  $RepositoryDirectory = Join-Path $PSScriptRoot '..'
}
$RepositoryDirectory = (Resolve-Path -LiteralPath $RepositoryDirectory).Path

$isShallow = & git --no-replace-objects -C $RepositoryDirectory rev-parse --is-shallow-repository
if ($LASTEXITCODE -ne 0) { throw 'The selected directory is not a Git repository.' }
if ($isShallow -eq 'true') { throw 'Shallow history cannot establish the public source boundary.' }
$replacementRefs = @(& git --no-replace-objects -C $RepositoryDirectory for-each-ref '--format=%(refname)' refs/replace/)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect replacement refs.' }
if ($replacementRefs.Count -ne 0) { throw 'Replacement refs can hide history; inspect an unmodified mirror clone.' }
if (-not [string]::IsNullOrEmpty($env:GIT_GRAFT_FILE)) { throw 'A custom Git graft file can hide history.' }
$graftsPath = & git --no-replace-objects -C $RepositoryDirectory rev-parse --git-path info/grafts
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Git grafts.' }
if (-not [IO.Path]::IsPathRooted($graftsPath)) { $graftsPath = Join-Path $RepositoryDirectory $graftsPath }
if (Test-Path -LiteralPath $graftsPath) { throw 'Git grafts can hide history; inspect an unmodified mirror clone.' }

function Read-GitBytes([string]$Arguments) {
  $start = New-Object Diagnostics.ProcessStartInfo
  $start.FileName = 'git'
  $start.Arguments = '--no-replace-objects ' + $Arguments
  $start.WorkingDirectory = $RepositoryDirectory
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $process = New-Object Diagnostics.Process
  $process.StartInfo = $start
  $buffer = New-Object IO.MemoryStream
  try {
    [void]$process.Start()
    $errorTask = $process.StandardError.ReadToEndAsync()
    $process.StandardOutput.BaseStream.CopyTo($buffer)
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
      throw "Git inspection failed: $($errorTask.Result.Trim())"
    }
    return ,$buffer.ToArray()
  } finally {
    $buffer.Dispose()
    $process.Dispose()
  }
}

# Resolve user-supplied revisions before passing only validated object IDs to
# the byte-reading helper. No working-tree files, refs, or configuration change.
if ($AllRefs) {
  $refs = @(& git --no-replace-objects -C $RepositoryDirectory for-each-ref '--format=%(refname)%09%(objecttype)%09%(*objecttype)')
  if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect selected refs.' }
  foreach ($ref in $refs) {
    $fields = $ref.Split([char]9)
    $targetType = $fields[1]
    if ($targetType -eq 'tag') { $targetType = $fields[2] }
    if ($targetType -ne 'commit') {
      throw "Selected ref does not point to a commit: $($fields[0])"
    }
  }
  $commits = @(& git --no-replace-objects -C $RepositoryDirectory rev-list --all)
} else {
  $commit = & git --no-replace-objects -C $RepositoryDirectory rev-parse --verify --end-of-options "$Revision^{commit}"
  if ($LASTEXITCODE -ne 0) { throw 'The requested revision is not a commit.' }
  $commits = @(& git --no-replace-objects -C $RepositoryDirectory rev-list $commit)
}
if ($LASTEXITCODE -ne 0 -or $commits.Count -eq 0) {
  throw 'No readable Git history was selected.'
}

$utf8 = New-Object Text.UTF8Encoding($false, $true)
$seenBlobs = New-Object 'Collections.Generic.HashSet[string]'
$problems = New-Object 'Collections.Generic.List[string]'
$forbiddenRoot = '^(?i:Kawai2003|Kawai2004|Kawai2005|inputs|compat)(?:/|$)'
$forbiddenExtension = '\.(?i:exe|dll|ocx|cab|msi|msp|zip|rar|7z|pdb|lib|obj|dmp|iso|vhd|vhdx)$'

foreach ($commit in $commits) {
  if ($commit -notmatch '^[a-f0-9]{40,64}$') { throw 'Unexpected Git object ID.' }
  $tree = $utf8.GetString((Read-GitBytes "ls-tree -r -z $commit"))
  foreach ($record in $tree.Split([char]0)) {
    if ($record.Length -eq 0) { continue }
    if ($record -notmatch '(?s)^([0-7]{6}) (\S+) ([a-f0-9]{40,64})\t(.+)$') {
      throw 'Unexpected Git tree record.'
    }
    $mode = $Matches[1]
    $kind = $Matches[2]
    $objectId = $Matches[3]
    $path = $Matches[4]
    if ($path -match '[\x00-\x1f\x7f]') { throw 'Control character in a Git path.' }
    $location = "$($commit.Substring(0, 12)) $path"
    if ($path -match $forbiddenRoot -or $path -match $forbiddenExtension) {
      $problems.Add("Excluded input or binary path: $location")
      continue
    }
    if ($kind -ne 'blob' -or $mode -notin @('100644', '100755')) {
      $problems.Add("Unsupported source entry: $location")
      continue
    }
    if (-not $seenBlobs.Add($objectId)) { continue }
    $bytes = Read-GitBytes "cat-file blob $objectId"
    try {
      $content = $utf8.GetString($bytes)
      if ($content.IndexOf([char]0) -ge 0) {
        $problems.Add("Non-text payload: $location")
      }
      if ($content -match '(?m)^version https://git-lfs\.github\.com/spec/v1\r?$') {
        $problems.Add("Git LFS pointer: $location")
      }
    } catch [Text.DecoderFallbackException] {
      $problems.Add("Payload is not UTF-8 text: $location")
    }
  }
}

if ($problems.Count -gt 0) {
  # Report locations only, never the contents of an unexpected blob.
  $preview = @($problems | Select-Object -First 20) -join [Environment]::NewLine
  throw "Public source history rejected ($($problems.Count) findings):`n$preview"
}

[pscustomobject]@{
  Status = 'Passed'
  Commits = $commits.Count
  TextBlobs = $seenBlobs.Count
  Scope = $(if ($AllRefs) { 'all local refs' } else { $Revision })
}
