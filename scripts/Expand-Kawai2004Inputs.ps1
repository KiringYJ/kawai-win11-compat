[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Vb5Package,
  [Parameter(Mandatory = $true)][string]$XpSp3Package,
  [Parameter(Mandatory = $true)][string]$DxWndArchive,
  [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

& (Join-Path $PSScriptRoot 'Expand-KawaiRuntimeInputs.ps1') @PSBoundParameters
