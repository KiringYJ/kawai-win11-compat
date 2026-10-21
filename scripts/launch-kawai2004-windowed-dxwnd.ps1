# Launch Kawai2004 through DxWnd in a window without changing desktop resolution.
# Requires DxWnd extracted to compat/tools/dxwnd-latest and dx7vb.dll extracted to
# compat/re/dlls/xpsp3/dx7vb.dll. The script only writes ignored scratch files.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceDir = Join-Path $repoRoot 'Kawai2004'
$runDir = Join-Path $repoRoot 'compat\re\run\Kawai2004_dx7vb_dxwnd'
$dx7vbSource = Join-Path $repoRoot 'compat\re\dlls\xpsp3\dx7vb.dll'
$dxWndDir = Join-Path $repoRoot 'compat\tools\dxwnd-latest'
$dxWndExe = Join-Path $dxWndDir 'dxwnd.exe'
$configName = 'kawai2004_windowed.ini'
$configPath = Join-Path $dxWndDir $configName
$gameExe = Join-Path $runDir 'Kawai2004.exe'

function Assert-File([string]$Path, [string]$Hint) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path`n$Hint"
  }
}

Assert-File $dxWndExe 'Download DxWnd v2.06.14 from https://sourceforge.net/projects/dxwnd/files/Latest%20build/v2_06_14_build.rar/download and extract it to compat/tools/dxwnd-latest.'
Assert-File $dx7vbSource 'Extract dx7vb.dll from the official Windows XP SP3 package into compat/re/dlls/xpsp3 first.'
foreach ($name in 'Kawai2004.exe','MSVBVM50.DLL','fmod.dll') {
  Assert-File (Join-Path $sourceDir $name) 'The preserved Kawai2004 corpus files must be present.'
}
if (@(Get-Process dxwnd -ErrorAction SilentlyContinue).Count -gt 0) {
  throw 'Close the existing DxWnd session before launching Kawai2004.'
}
$previousGameIds = @(Get-Process Kawai2004 -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })

New-Item -ItemType Directory -Force -Path $runDir | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceDir 'Kawai2004.exe') -Destination (Join-Path $runDir 'Kawai2004.exe') -Force
Copy-Item -LiteralPath (Join-Path $sourceDir 'MSVBVM50.DLL') -Destination (Join-Path $runDir 'MSVBVM50.DLL') -Force
Copy-Item -LiteralPath (Join-Path $sourceDir 'fmod.dll') -Destination (Join-Path $runDir 'fmod.dll') -Force
Copy-Item -LiteralPath $dx7vbSource -Destination (Join-Path $runDir 'dx7vb.dll') -Force

$manifest = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity type="win32" name="Kawai2004.dx7vb.regfree" version="1.0.0.0" processorArchitecture="x86"/>
  <file name="dx7vb.dll">
    <typelib tlbid="{E1211242-8E94-11D1-8808-00C04FC2C602}" version="1.0" helpdir="" resourceid="1"/>
    <comClass clsid="{E1211353-8E94-11D1-8808-00C04FC2C602}" threadingModel="Apartment" progid="DIRECT.DirectX6.0" tlbid="{E1211242-8E94-11D1-8808-00C04FC2C602}"/>
  </file>
</assembly>
"@
$manifest | Set-Content -LiteralPath (Join-Path $runDir 'Kawai2004.exe.manifest') -Encoding UTF8

@"
[target]
title0=Kawai2004 windowed
path0=$gameExe
startfolder0=$runDir
launchpath0=
cmdline0=
msshims0=
module0=dx7vb.dll
opengllib0=
notes0=Kawai2004 local windowed profile. Uses DxWnd DirectX7 hook plus dx7vb.dll additional module. Do not add WINXPSP3 here; it caused CreateProcess error 740 in this profile.
registry0=
ver0=2
monitorid0=-1
filterid0=0
renderer0=3
coord0=0
flag0=673194025
flagg0=1207959552
flagh0=22
flagi0=138412036
flagj0=4224
flagk0=98304
flagl0=32768
flagm0=0
flagn0=17825796
flago0=0
tflag0=0
dflag0=0
posx0=50
posy0=50
sizx0=800
sizy0=600
maxfps0=0
initts0=0
winver0=0
maxres0=-1
swapeffect0=0
maxddinterface0=7
slowratio0=2
scanline0=0
initresw0=800
initresh0=600
fakec0=
faked0=
flagp0=0
flagq0=0
flagr0=0
flags0=0
flagt0=0
flagu0=0
dflagb0=0
fakehddrive0=C:
fakecddrive0=D:
cdvol0=0
codepage0=0
lang0=0
country0=0
commitaddress0=0
commitlength0=0
[stamp]
version=v2.06.14.kawai-windowed
time=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@ | Set-Content -LiteralPath $configPath -Encoding ASCII

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class DxWndPromptCloser {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
  [DllImport("user32.dll", SetLastError=true)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  [DllImport("user32.dll", SetLastError=true)] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
"@
function Get-WindowTextLocal([IntPtr]$Handle) {
  $sb = New-Object Text.StringBuilder 2048
  [void][DxWndPromptCloser]::GetWindowText($Handle, $sb, $sb.Capacity)
  $sb.ToString()
}
function Get-ClassLocal([IntPtr]$Handle) {
  $sb = New-Object Text.StringBuilder 256
  [void][DxWndPromptCloser]::GetClassName($Handle, $sb, $sb.Capacity)
  $sb.ToString()
}
function Close-DxWndDocumentationPrompt([int]$DxWndPid) {
  $script:closedDxWndDocPrompt = $false
  $callback = [DxWndPromptCloser+EnumWindowsProc]{ param([IntPtr]$h, [IntPtr]$l)
    [uint32]$wpid = 0
    [void][DxWndPromptCloser]::GetWindowThreadProcessId($h, [ref]$wpid)
    if ([int]$wpid -eq $DxWndPid -and (Get-ClassLocal $h) -eq '#32770') {
      $script:hasDocText = $false
      $scanChild = [DxWndPromptCloser+EnumWindowsProc]{ param([IntPtr]$ch, [IntPtr]$cl)
        if ((Get-WindowTextLocal $ch) -like '*ATTENTION: to read DxWnd documentation*') {
          $script:hasDocText = $true
        }
        return $true
      }
      [void][DxWndPromptCloser]::EnumChildWindows($h, $scanChild, [IntPtr]::Zero)
      if ($script:hasDocText) {
        $clickChild = [DxWndPromptCloser+EnumWindowsProc]{ param([IntPtr]$ch, [IntPtr]$cl)
          if ((Get-ClassLocal $ch) -eq 'Button' -and [DxWndPromptCloser]::IsWindowVisible($ch)) {
            [void][DxWndPromptCloser]::SendMessage($ch, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)
            $script:closedDxWndDocPrompt = $true
            return $false
          }
          return $true
        }
        [void][DxWndPromptCloser]::EnumChildWindows($h, $clickChild, [IntPtr]::Zero)
      }
    }
    return (-not $script:closedDxWndDocPrompt)
  }
  [void][DxWndPromptCloser]::EnumWindows($callback, [IntPtr]::Zero)
}

$dxWndProcess = Start-Process -FilePath $dxWndExe -WorkingDirectory $dxWndDir -ArgumentList "/Q /X /C:$configName /R:1" -PassThru
$gameProcess = $null
for ($i = 0; $i -lt 10; $i++) {
  Start-Sleep -Milliseconds 300
  Close-DxWndDocumentationPrompt $dxWndProcess.Id
  $gameInfo = Get-CimInstance Win32_Process -Filter "Name = 'Kawai2004.exe' AND ParentProcessId = $($dxWndProcess.Id)" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -eq $gameExe -and $_.ProcessId -notin $previousGameIds } | Select-Object -First 1
  if ($null -ne $gameInfo) { $gameProcess = Get-Process -Id $gameInfo.ProcessId -ErrorAction SilentlyContinue }
  if ($null -ne $gameProcess) { break }
}
if ($null -eq $gameProcess) {
  if (-not $dxWndProcess.HasExited) { Stop-Process -Id $dxWndProcess.Id -ErrorAction SilentlyContinue }
  throw 'Kawai2004 did not start as a child of this DxWnd session.'
}
Write-Host "Launched Kawai2004 through DxWnd using $configPath"
if ($null -ne $gameProcess) {
  try {
    $gameProcess.WaitForExit()
  } finally {
    if (-not $dxWndProcess.HasExited) { Stop-Process -Id $dxWndProcess.Id -ErrorAction SilentlyContinue }
  }
}
