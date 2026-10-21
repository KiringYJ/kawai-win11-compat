# Kawai2004 local scratch launch recipe

This recipe reproduces the current Windows 11 scratch launch path for
`Kawai2004` without modifying the preserved original executable and without
writing host COM registry state.

## Status

Confirmed in scratch on 2026-06-11:

- `CoCreateInstance` for `{E1211353-8E94-11D1-8808-00C04FC2C602}` returns
  `S_OK` when `dx7vb.dll` is supplied through an external registration-free COM
  manifest.
- With `__COMPAT_LAYER=WINXPSP3`, the game process stays alive for a
  15-second probe and shows visible `ThunderRT5Form` and `ThunderRT5Main`
  windows.
- With DxWnd v2.06.14 and no `WINXPSP3` layer, the game reaches the
  title/menu window in an 816x639 top-level window while the Windows desktop
  remains at 2560x1440.
- Gameplay, input, audio, and repeated launch/exit are not yet fully verified.

## Inputs

Preserved corpus files:

- `Kawai2004/Kawai2004.exe`
- `Kawai2004/MSVBVM50.DLL`
- `Kawai2004/fmod.dll`

Ignored scratch runtime:

- `compat/re/dlls/xpsp3/dx7vb.dll`
- `compat/tools/dxwnd-latest/`

`dx7vb.dll` provenance:

- Source package:
  `compat/downloads/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe`
- Package SHA-1: `c81472f7eeea2eca421e116cd4c03e2300ebfde4`
- Package SHA-256:
  `62e524a552db9f6fd22d469010ea4d7e28ee06fa615a1c34362129f808916654`
- Extracted DLL SHA-1: `ff27d1d4cd4eb1ce6e8d786c1a5d69cfb6da1b17`
- Extracted DLL SHA-256:
  `617c432e02ba7c5b79d45e3d09aceb21e58a14b8f13d9be75164c3866c6c81c6`
- Version info: Microsoft DirectX for Visual Basic
  `5.03.2600.5512 (xpsp.080413-0845)`

## Prepare scratch files

Run from the repository root:

```powershell
$run = "compat/re/run/Kawai2004_dx7vb_regfree"
New-Item -ItemType Directory -Force -Path $run | Out-Null
Copy-Item Kawai2004/Kawai2004.exe $run/Kawai2004.exe -Force
Copy-Item Kawai2004/MSVBVM50.DLL $run/MSVBVM50.DLL -Force
Copy-Item Kawai2004/fmod.dll $run/fmod.dll -Force
Copy-Item compat/re/dlls/xpsp3/dx7vb.dll $run/dx7vb.dll -Force
```

Create `compat/re/run/Kawai2004_dx7vb_regfree/Kawai2004.exe.manifest`:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity type="win32" name="Kawai2004.dx7vb.regfree" version="1.0.0.0" processorArchitecture="x86"/>
  <file name="dx7vb.dll">
    <typelib tlbid="{E1211242-8E94-11D1-8808-00C04FC2C602}" version="1.0" helpdir="" resourceid="1"/>
    <comClass clsid="{E1211353-8E94-11D1-8808-00C04FC2C602}" threadingModel="Apartment" progid="DIRECT.DirectX6.0" tlbid="{E1211242-8E94-11D1-8808-00C04FC2C602}"/>
  </file>
</assembly>
```

## Launch

### Windowed launch with DxWnd

This is the current preferred local launch path because it avoids the
fullscreen 800x600 desktop mode switch.

Prepare DxWnd in ignored scratch:

```powershell
New-Item -ItemType Directory -Force -Path compat/downloads, compat/tools/dxwnd-latest | Out-Null
curl.exe -L -o compat/downloads/dxwnd-v2.06.14.rar `
  https://sourceforge.net/projects/dxwnd/files/Latest%20build/v2_06_14_build.rar/download
tar.exe -xf compat/downloads/dxwnd-v2.06.14.rar -C compat/tools/dxwnd-latest
```

Expected DxWnd archive SHA-256:

```text
1D439F18819BEA903659677AC0A94AAB5C08533A585B5473DFB656E225EE4B5C
```

Launch from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/launch-kawai2004-windowed-dxwnd.ps1
```

The script copies the original corpus files into ignored scratch, writes the
registration-free COM manifest, writes a DxWnd profile, and starts:

```text
compat/tools/dxwnd-latest/dxwnd.exe /Q /X /C:kawai2004_windowed.ini /R:1
```

Key DxWnd profile settings:

- `ver0=2` (`DirectX7` hook)
- `module0=dx7vb.dll` (additional module)
- `renderer0=3`
- `posx0=50`, `posy0=50`, `sizx0=800`, `sizy0=600`
- `msshims0=` (do not add `WINXPSP3` here; it produced
  `CreateProcess ... error=740` in this profile)

Windowed verification evidence:

- `compat/re/reports/Kawai2004.dxwnd.dx7_module.window_rect_probe.json`
- `compat/re/reports/Kawai2004.dxwnd.dx7_module.printwindow.png`

The probe showed `screenChangedDuring=false`, `screenChangedAfter=false`, a
visible `ThunderRT5Form` titled `Kawai2004 v1.01` with rect `42,19,858,658`,
and `dxwnd.dll` loaded into the `Kawai2004.exe` process.

### Direct compatibility-layer launch

```powershell
$run = (Resolve-Path "compat/re/run/Kawai2004_dx7vb_regfree").Path
$oldLayer = $env:__COMPAT_LAYER
$env:__COMPAT_LAYER = "WINXPSP3"
try {
  Start-Process -FilePath (Join-Path $run "Kawai2004.exe") -WorkingDirectory $run
} finally {
  if ($null -eq $oldLayer) {
    Remove-Item Env:\__COMPAT_LAYER -ErrorAction SilentlyContinue
  } else {
    $env:__COMPAT_LAYER = $oldLayer
  }
}
```

## Safety notes

- Do not run `regsvr32 dx7vb.dll` unless explicitly approved with a rollback
  plan.
- Keep original corpus binaries unmodified.
- Keep `compat/` scratch files ignored unless a future preservation decision
  explicitly promotes them.
