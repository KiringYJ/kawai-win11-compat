[CmdletBinding()]
param(
  [string]$Vb5Package,
  [string]$XpSp3Package,
  [string]$DxWndArchive
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

& (Join-Path $PSScriptRoot 'Test-KawaiRuntimeInputs.ps1') @PSBoundParameters
