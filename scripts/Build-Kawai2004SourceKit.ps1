[CmdletBinding()]
param(
  [string]$OutputDirectory,
  [string]$Version = '0.1.0-rc.1'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

& (Join-Path $PSScriptRoot 'Build-KawaiSourceKit.ps1') @PSBoundParameters -UseLegacyKawai2004Name
