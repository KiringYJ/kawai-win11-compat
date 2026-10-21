[CmdletBinding()]
param([switch]$KeepTemporaryFiles)

& (Join-Path $PSScriptRoot 'Test-KawaiPackage.ps1') @PSBoundParameters
