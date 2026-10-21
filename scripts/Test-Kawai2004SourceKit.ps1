[CmdletBinding()]
param([switch]$KeepTemporaryFiles)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

& (Join-Path $PSScriptRoot 'Test-KawaiSourceKit.ps1') @PSBoundParameters
