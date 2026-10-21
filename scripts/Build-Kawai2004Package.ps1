[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$GameArchive,
  [Parameter(Mandatory = $true)][string]$Vb5Runtime,
  [Parameter(Mandatory = $true)][string]$DirectXRuntime,
  [Parameter(Mandatory = $true)][string]$DxWndDirectory,
  [string]$OutputDirectory,
  [string]$Version = '0.1.0-rc.1',
  [string]$InputManifest
)

$parameters = @{
  Game = 'Kawai2004'
  GameArchive = $GameArchive
  Vb5Runtime = $Vb5Runtime
  DirectXRuntime = $DirectXRuntime
  DxWndDirectory = $DxWndDirectory
  Version = $Version
}
if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) { $parameters.OutputDirectory = $OutputDirectory }
if (-not [string]::IsNullOrWhiteSpace($InputManifest)) { $parameters.InputManifest = $InputManifest }
& (Join-Path $PSScriptRoot 'Build-KawaiPackage.ps1') @parameters
