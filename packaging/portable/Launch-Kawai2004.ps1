# Backward-compatible entry point for Kawai2004 packages.
[CmdletBinding()]
param(
    [switch]$PrepareOnly,
    [switch]$NoWait,
    [ValidateRange(1, 60)][int]$StartupTimeoutSeconds = 20
)

& (Join-Path $PSScriptRoot 'Launch-Kawai.ps1') @PSBoundParameters
