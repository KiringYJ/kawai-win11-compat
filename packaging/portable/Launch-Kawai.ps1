[CmdletBinding()]
param(
    [switch]$PrepareOnly,
    [switch]$NoWait,
    [ValidateRange(1, 60)][int]$StartupTimeoutSeconds = 20
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
& (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Quiet

$gameSpec = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'PACKAGE-GAME.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($gameSpec.schemaVersion -ne 1 -or $gameSpec.game -notin @('Kawai2003', 'Kawai2004', 'Kawai2005')) {
    throw 'Unsupported game package metadata.'
}
$gameId = [string]$gameSpec.game
$gameExecutableName = [IO.Path]::GetFileName([string]$gameSpec.executablePath)
if ($gameExecutableName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.exe$' -or
    [string]$gameSpec.executablePath -cne ('game/' + $gameExecutableName)) {
    throw 'The game executable must be a file directly inside game/.'
}
$windowTitlePrefix = [string]$gameSpec.windowTitlePrefix
if ([string]::IsNullOrWhiteSpace($windowTitlePrefix) -or $windowTitlePrefix.Length -gt 128 -or
    $windowTitlePrefix -match '[\x00-\x1f\x7f]') {
    throw 'Invalid game title-window metadata.'
}
$gameProcessName = [IO.Path]::GetFileNameWithoutExtension($gameExecutableName)
$showInTaskbar = $false
$taskbarProperty = $gameSpec.PSObject.Properties['showInTaskbar']
if ($null -ne $taskbarProperty) {
    if ($taskbarProperty.Value -isnot [bool]) { throw 'Invalid taskbar visibility policy.' }
    $showInTaskbar = $taskbarProperty.Value
}
$gameDirectory = Join-Path $PSScriptRoot 'game'
$gameExecutable = Join-Path $gameDirectory $gameExecutableName
$dxWndSourceDirectory = Join-Path $PSScriptRoot 'tools\dxwnd'
$dxWndSourceExecutable = Join-Path $dxWndSourceDirectory 'dxwnd.exe'
$runtimeDirectory = Join-Path $PSScriptRoot 'runtime'
$dxWndWorkingDirectory = Join-Path $runtimeDirectory 'dxwnd'
$dxWndExecutable = Join-Path $dxWndWorkingDirectory 'dxwnd.exe'
if ($PSScriptRoot -match '[\r\n]' -or $gameExecutable.Length -gt 240) {
    throw 'Move the package to a shorter folder path without line breaks.'
}
foreach ($required in @($gameExecutable, $dxWndSourceExecutable)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw 'Required executable is missing. Extract the complete ZIP again.'
    }
}
if (-not $PrepareOnly) {
    if (@(Get-Process -Name dxwnd -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'Close the existing DxWnd session before starting this package.'
    }
    if (@(Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -eq $gameExecutable
    }).Count -gt 0) {
        throw "This copy of $gameId is already running."
    }
}
if (-not ('KawaiRuntimeNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
using System;
using System.Text;
public static class KawaiRuntimeNative {
    [DllImport("kernel32.dll")] public static extern uint GetACP();
    private delegate bool WindowCallback(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] private static extern bool EnumWindows(WindowCallback callback, IntPtr parameter);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll", EntryPoint="GetWindowLongW")] private static extern int GetWindowStyle(IntPtr window, int index);
    [DllImport("user32.dll", EntryPoint="SetWindowLongW")] private static extern int SetWindowStyle(IntPtr window, int index, int value);
    private static IntPtr FindTitleWindow(int processId, string titlePrefix) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr window, IntPtr parameter) {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            if (owner == processId && IsWindowVisible(window)) {
                StringBuilder text = new StringBuilder(256);
                GetWindowText(window, text, text.Capacity);
                if (text.ToString().StartsWith(titlePrefix, StringComparison.Ordinal)) {
                    found = window;
                    return false;
                }
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static bool HasTitleWindow(int processId, string titlePrefix) {
        return FindTitleWindow(processId, titlePrefix) != IntPtr.Zero;
    }
    public static bool EnsureTaskbarWindow(int processId, string titlePrefix) {
        IntPtr window = FindTitleWindow(processId, titlePrefix);
        if (window == IntPtr.Zero) return false;
        StringBuilder name = new StringBuilder(128);
        GetClassName(window, name, name.Capacity);
        if (name.ToString() != "ThunderRT5Form") return false;
        uint extended = unchecked((uint)GetWindowStyle(window, -20));
        // The original skin owns its frame and X. Expose only the main app
        // window to the taskbar; do not resize, move, or restyle its client area.
        uint visibleStyle = (extended & ~0x00000080u) | 0x00040000u;
        if (extended == visibleStyle) return true;
        SetWindowStyle(window, -20, unchecked((int)visibleStyle));
        return unchecked((uint)GetWindowStyle(window, -20)) == visibleStyle;
    }
}
'@
}
$ansi = [Text.Encoding]::GetEncoding([int][KawaiRuntimeNative]::GetACP(),
    [Text.EncoderFallback]::ExceptionFallback, [Text.DecoderFallback]::ExceptionFallback)
$profile = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'dxwnd.ini.template'))
$profile = $profile.Replace('@GAME_EXE@', $gameExecutable).Replace('@GAME_DIR@', $gameDirectory)
try { $profileBytes = $ansi.GetBytes($profile) } catch {
    throw 'The legacy runtime cannot represent this folder name. Use a short ASCII folder path.'
}
if (-not (Test-Path -LiteralPath $runtimeDirectory)) {
    [void](New-Item -ItemType Directory -Path $runtimeDirectory)
}
if (Test-Path -LiteralPath $dxWndWorkingDirectory) {
    if ((Get-Item -LiteralPath $dxWndWorkingDirectory).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'The runtime DxWnd directory must not be a link or junction.'
    }
} else {
    [void](New-Item -ItemType Directory -Path $dxWndWorkingDirectory)
}
$toolFiles = @(Get-ChildItem -LiteralPath $dxWndSourceDirectory -File)
$toolNames = @($toolFiles | ForEach-Object { $_.Name })
foreach ($runtimeItem in Get-ChildItem -LiteralPath $dxWndWorkingDirectory -Force) {
    if ($runtimeItem.PSIsContainer -or
        ($runtimeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        ($runtimeItem.Name -notin $toolNames -and $runtimeItem.Name -ne 'dxwnd.ini' -and
            $runtimeItem.Extension -ne '.log')) {
        throw 'Unexpected content in runtime/dxwnd. Use a fresh extracted package.'
    }
}
# DxWnd also resolves its injected DLL relative to its initial working directory.
# Refresh only the known runtime copies; the checksummed payload stays unchanged.
foreach ($toolFile in $toolFiles) {
    Copy-Item -LiteralPath $toolFile.FullName -Destination (Join-Path $dxWndWorkingDirectory $toolFile.Name) -Force
}
[IO.File]::WriteAllBytes((Join-Path $dxWndWorkingDirectory 'dxwnd.ini'), $profileBytes)
if ($PrepareOnly) {
    [pscustomobject]@{ Status = 'Prepared'; Profile = (Join-Path $dxWndWorkingDirectory 'dxwnd.ini') }
    return
}
# DxWnd 2.06.14 resolves /C relative to its initial working directory.
$previousGameIds = @(Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$dxWnd = $null
$started = $false
try {
    $dxWnd = Start-Process -FilePath $dxWndExecutable -WorkingDirectory $dxWndWorkingDirectory `
        -ArgumentList '/Q /X /C:dxwnd.ini /R:1' -WindowStyle Normal -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
    do {
        foreach ($candidate in @(Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue)) {
            if ($candidate.Path -ne $gameExecutable -or $candidate.Id -in $previousGameIds) { continue }
            $candidateDetails = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($candidate.Id)" -ErrorAction SilentlyContinue
            if ($null -eq $candidateDetails -or [int]$candidateDetails.ParentProcessId -ne $dxWnd.Id) { continue }
            # VB5 also owns a helper window; Process.MainWindowTitle may select
            # that helper while the actual title form is visible.
            if ([KawaiRuntimeNative]::HasTitleWindow($candidate.Id, $windowTitlePrefix)) {
                if ($showInTaskbar -and -not [KawaiRuntimeNative]::EnsureTaskbarWindow($candidate.Id, $windowTitlePrefix)) { continue }
                # .NET Framework may report only WOW64 modules for this x86 game.
                # The verified executable and its visible title form are the health check.
                $started = $true
                [pscustomobject]@{ Status = 'Started'; GameProcessId = $candidate.Id; DxWndProcessId = $dxWnd.Id }
                if (-not $NoWait) {
                    try {
                        $candidate.WaitForExit()
                    } finally {
                        if (-not $dxWnd.HasExited) {
                            Stop-Process -Id $dxWnd.Id -ErrorAction SilentlyContinue
                        }
                    }
                }
                return
            }
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "$gameId did not reach its title window. This launch was stopped. Run Verify.cmd and check the known issues in docs/RELEASE_TESTING.md. Do not disable antivirus or run the game as administrator."
} finally {
    if (-not $started) {
        $ownedGameIds = @()
        if ($null -ne $dxWnd) {
            $ownedGameIds = @(Get-CimInstance -ClassName Win32_Process `
                -Filter "ParentProcessId = $($dxWnd.Id) AND Name = '$gameExecutableName'" `
                -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.ProcessId })
        }
        foreach ($failedGame in @(Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue)) {
            if ($failedGame.Path -eq $gameExecutable -and $failedGame.Id -in $ownedGameIds -and
                $failedGame.Id -notin $previousGameIds) {
                Stop-Process -Id $failedGame.Id -ErrorAction SilentlyContinue
            }
        }
        if ($null -ne $dxWnd -and -not $dxWnd.HasExited) {
            Stop-Process -Id $dxWnd.Id -ErrorAction SilentlyContinue
        }
    }
}
