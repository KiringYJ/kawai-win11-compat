# Reverse-engineering log

This log records evidence from local compatibility and reverse-engineering probes.
Keep original corpus binaries unmodified; scratch copies, unpacked files, patched
experiments, debugger logs, and helper scripts remain under ignored `compat/`.

## 2026-06-11: Kawai2004 startup failure narrowed to first VB object creation

### Scope

- Target: `Kawai2004/Kawai2004.exe`
- Original SHA-256: `b0a5f68e0e2f63db07fad33c54dd4ef654ca5c317d4a62d9ef5cfe63494934f9`
- Runtime DLL present side-by-side: `Kawai2004/MSVBVM50.DLL`
- Scratch working copies: `compat/re/`

### Unpacking

UPX 5.2.0 confirmed all three preserved executables are UPX-packed and unpacked
ignored working copies:

| Source | Unpacked copy | Unpacked size | Unpacked SHA-256 |
| --- | --- | ---: | --- |
| `Kawai2003/Kawai2003.exe` | `compat/re/unpacked/Kawai2003.unpacked.exe` | 2264576 | `993e22fc4a6ef716eaff4ab211c8e96ed3272b871e49d3319298f52c6fb3b2d3` |
| `Kawai2004/Kawai2004.exe` | `compat/re/unpacked/Kawai2004.unpacked.exe` | 1415168 | `f1eab078fa65f6fe63b2d5966adcddd1a24abfc99c6706ec30f033965e58f75a` |
| `Kawai2005/KI2005.EXE` | `compat/re/unpacked/KI2005.unpacked.exe` | 1119232 | `97affb91bb8fa67521ca851fbb1ce1e1d7d46bf60a7a61ea2e6ca6b30775bf47` |

Original executable hashes were rechecked after unpacking and still match
`docs/CORPUS_MANIFEST.md`.

### Static evidence

Generated scratch reports:

- `compat/re/reports/Kawai2004.unpacked.static.md`
- `compat/re/reports/Kawai2004.unpacked.resources.json`
- `compat/re/reports/Kawai2004.import_iat.json`
- `compat/re/reports/Kawai2004.objdump.txt`
- `compat/re/reports/Kawai2004.procedure_map.txt`

Findings:

- The unpacked PE imports only `MSVBVM50.DLL` directly.
- VB Declare/dynamic-call strings show `kernel32.dll`, `winmm.dll`,
  `shell32.dll`, and `FMOD.DLL`.
- No `*.ocx`, `dx7vb.dll`, DirectX typelib path, or brace-form GUID string was
  found in the static string pass.
- The VB metadata object names are `Form_Main`, `Module1`, and `FMod`.
- The VB external table references `C:\Program Files\DevStudio\VB\VB5.OLB`.
  No external DirectX or ActiveX control reference was identified in the parsed
  tables.
- `Form_Main` exposes event names `Form_KeyDown`, `Form_Load`,
  `Form_MouseDown`, `Form_MouseMove`, and `Form_Paint`.
- Kawai2004 resources are embedded image/music/sound/icon/version resources:
  `CUSTOM` 101-103 are BMP-like resources, `CUSTOM` 104 is an extended-module
  music resource, and `SOUND` 201-209 are RIFF/WAV resources.

### Startup probes

A scratch startup probe (`compat/re/run/probe_process.ps1`) starts copied
executables from ignored run directories, captures top-level and child window
text, then closes or kills the process.

Observed results:

- `Kawai2004` packed scratch copy with `MSVBVM50.DLL` and `fmod.dll`: modal
  `Run-time error '91': Object variable or With block variable not set`.
- `Kawai2004` unpacked scratch copy: same error.
- `Kawai2004` scratch copy without `fmod.dll`: same error. This weakens
  `FMOD.DLL` as the immediate startup blocker.
- `Kawai2004` with `__COMPAT_LAYER` variants `WIN98`,
  `WIN98 256COLOR 640X480`, `WINXPSP3`, and
  `DISABLETHEMES DISABLEDWM DISABLEDXMAXIMIZEDWINDOWEDMODE`: same error.
- `Kawai2003` scratch copy starts without an error-91 dialog under the same
  probe method.
- `Kawai2005` scratch copy reaches a music-load warning and an error-91 dialog;
  this is related but not identical to the Kawai2004 startup path.

The Kawai2004 error window appears while `ThunderRT5Form` titled
`Kawai2004 v1.01` is still hidden and before normal gameplay controls are
visible.

### Debugger trace

GDB against `compat/re/run/Kawai2004_unpacked/Kawai2004.exe` identified the
first native startup/Form_Load-equivalent routine at `0x408020`.

Checkpoint trace:

- `0x408020`: routine entry.
- `0x408070`: VB error handler setup.
- `0x408086`: call through the `__vbaNew2` import slot (`IAT 0x004212fc`).
  The call is made with object metadata `0x403354` and destination field
  `[Form_Main + 0x34]`.
- The normal next checkpoint at `0x40808c` is not reached.
- Execution diverts to cleanup/error path `0x408316`.

Debugger output also emitted two OLE picture warnings before the routine entry:
`oleaut32\stdtypes\pictobj.cpp(3114)` with HRESULT `0x8007029C`.

Initial interpretation, before the follow-up COM trace below: the failure was
known to occur during the first VB object/control creation in the startup
routine, with OLE picture loading warnings nearby. The picture/control
hypothesis is now downgraded because the follow-up trace identifies a missing
COM class as the failing condition.

### Negative patch experiment

The three `CUSTOM` BMP resources in Kawai2004 have BMP file-size fields two
bytes smaller than their resource sizes. A scratch-only unpacked copy corrected
those three fields:

| Resource | File offset patched | Old size field | New size field |
| --- | ---: | ---: | ---: |
| `CUSTOM/101/1028` | `1045370` | 148486 | 148488 |
| `CUSTOM/102/1028` | `127610` | 436678 | 436680 |
| `CUSTOM/103/1028` | `564290` | 481078 | 481080 |

Patched scratch copy:
`compat/re/run/Kawai2004_bmp_size_patch/Kawai2004.exe`
SHA-256 `b31d41e6fcc6c134789776faa0922a9e07f3277b67d6b5a775236ccface1bf79`.

Result: startup still reaches the same error-91 dialog. Therefore the BMP size
field anomaly alone is not sufficient to explain the failure.

### Follow-up: missing COM class during `CoCreateInstance`

Generated scratch reports:

- `compat/re/reports/Kawai2004.gdb_directx6_return_addr.log`
- `compat/re/reports/Kawai2004.directx_com_registry_check.txt`

GDB breakpoints around `CoCreateInstance` captured the failing object creation
from the earlier `__vbaNew2` path:

- Entry return address: `0x740cc92b`
- `CLSCTX`: `0x00000005` (`INPROC_SERVER | LOCAL_SERVER`)
- CLSID memory at `0x403334`:
  `0xe1211353 0x11d18e94 0xc0000888 0x02c6c24f`
- Decoded CLSID: `{E1211353-8E94-11D1-8808-00C04FC2C602}`
- IID memory at `0x740df578`:
  `0x00000000 0x00000000 0x000000c0 0x46000000`
- Decoded IID: `{00000000-0000-0000-C000-000000000046}` (`IID_IUnknown`)
- Return HRESULT in `EAX`: `0x80040154`

`0x80040154` is `REGDB_E_CLASSNOTREG` ("Class not registered"). This provides
direct evidence that the first object creation fails because the requested COM
class is absent from the test host registration state.

Read-only PowerShell checks found no registration for the CLSID, related
legacy DirectX/VB GUIDs checked during the trace, or matching DirectX VB runtime
DLL names:

- `HKCR\CLSID\{E1211353-8E94-11D1-8808-00C04FC2C602}`: absent
- `HKCR\WOW6432Node\CLSID\{E1211353-8E94-11D1-8808-00C04FC2C602}`: absent
- `HKCR\Interface\{E1211353-8E94-11D1-8808-00C04FC2C602}`: absent
- `HKCR\WOW6432Node\Interface\{E1211353-8E94-11D1-8808-00C04FC2C602}`:
  absent
- `dx6vb.dll`, `dx7vb.dll`, and `dx8vb.dll`: not found under
  `C:\Windows\System32`, `C:\Windows\SysWOW64`, or the repository root

No registry writes or system changes were made.

Interpretation: the leading Kawai2004 startup blocker is now a missing or
unregistered legacy DirectX/VB COM class, not `FMOD.DLL` and not the BMP size
field anomaly. The earlier OLE picture warnings may still matter later, but
they are not the proven condition that returns error 91 on this path.

### External source triage for the candidate runtime

External lookup is only a guide for the next local proof step:

- Microsoft's DirectX End-User Runtime page documents optional legacy DirectX
  SDK side-by-side components for older games, but it lists D3DX, HLSL
  Compiler, XInput, XAudio, XACT, and Managed DirectX components rather than
  proving that `dx7vb.dll` is included:
  <https://www.microsoft.com/en-us/download/details.aspx?id=35>
- Microsoft Update Catalog exposes Windows XP Service Pack 3 (`KB936929`) as an
  official 319.3 MB service-pack package:
  <https://www.catalog.update.microsoft.com/Search.aspx?q=KB936929>
- A Windows Update CDN URL for the English XP SP3 package responded with
  HTTP 200, `Content-Length: 331805736`, and `Last-Modified:
  Fri, 25 Apr 2008 01:19:56 GMT`:
  <http://www.download.windowsupdate.com/msdownload/update/software/dflt/2008/04/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe>.
- Community compatibility pages associate `dx7vb.dll` with Microsoft DirectX
  for Visual Basic and say it was extracted from Windows XP Service Pack 3, but
  those pages are hints, not authoritative artifact provenance:
  <https://community.pcgamingwiki.com/files/file/56-microsoft-directx-for-visual-basic-dx7vbdll/>
- A Stack Overflow answer by a DirectX maintainer describes `dx7vb.dll` and
  `dx8vb.dll` as the old Visual Basic DirectX 7/8 automation components and
  says they are not available on Windows versions newer than XP, but this is
  still contextual support rather than local proof:
  <https://stackoverflow.com/questions/31751781/updating-from-old-directx-7-c-code-dx7vb-dll>

Working conclusion: `dx7vb.dll` is the strongest candidate name for the missing
legacy COM server, but the next proof step should inspect an official Microsoft
package or original-era media, extract metadata under `compat/`, and verify the
DLL's registration data before any deployment test. Avoid third-party DLL
mirrors as binary sources.

### Official XP SP3 extraction and `dx7vb.dll` proof

The user downloaded the official XP SP3 package to the repository root. It was
then moved into ignored scratch storage:

- Package path:
  `compat/downloads/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe`
- Size: `331805736`
- SHA-1: `c81472f7eeea2eca421e116cd4c03e2300ebfde4`
- SHA-256:
  `62e524a552db9f6fd22d469010ea4d7e28ee06fa615a1c34362129f808916654`
- Authenticode: valid Microsoft Corporation signature on the self-extracting
  cabinet.

The package was extracted only to ignored scratch (`compat/extract/xpsp3`) with
the package extraction switch. It was not installed. The relevant compressed
files were:

- `compat/extract/xpsp3/i386/dx7vb.dl_` (`166558` bytes)
- `compat/extract/xpsp3/i386/dx8vb.dl_` (`419746` bytes)

Expanded scratch DLLs:

| DLL | Size | SHA-1 | SHA-256 | Version info |
| --- | ---: | --- | --- | --- |
| `compat/re/dlls/xpsp3/dx7vb.dll` | 619008 | `ff27d1d4cd4eb1ce6e8d786c1a5d69cfb6da1b17` | `617c432e02ba7c5b79d45e3d09aceb21e58a14b8f13d9be75164c3866c6c81c6` | Microsoft DirectX for Visual Basic `5.03.2600.5512 (xpsp.080413-0845)` |
| `compat/re/dlls/xpsp3/dx8vb.dll` | 1227264 | `52078fcbb069670c425622dfd730802ffcec63da` | `19149f082f3ca68aa893adaf0309e5e6c8ea8710c0fe2040f95e8da5a329f846` | Microsoft DirectX for Visual Basic `5.03.2600.5512 (xpsp.080413-0845)` |

Static proof files:

- `compat/re/reports/xpsp3_dx7vb.dll.objdump_p.txt`
- `compat/re/reports/xpsp3_dx8vb.dll.objdump_p.txt`
- `compat/re/reports/xpsp3_dxvb_string_offsets.txt`
- `compat/re/reports/xpsp3_dxvb_typelib_inspection.txt`
- `compat/re/reports/xpsp3_dxvb_focused_typeinfo.txt`

Findings:

- `dx7vb.dll` exports `DllCanUnloadNow`, `DllGetClassObject`,
  `DllRegisterServer`, and `DllUnregisterServer`.
- `dx7vb.dll` contains the missing CLSID bytes for
  `{E1211353-8E94-11D1-8808-00C04FC2C602}` at file offsets `3756` and
  `267988`.
- `dx7vb.dll` contains the `DIRECT.DirectX6.0` ProgID string at file offset
  `9420`.
- `dx7vb.dll` embeds type library
  `{E1211242-8E94-11D1-8808-00C04FC2C602}`, version `1.0`, `SYS_WIN32`.
- That type library identifies `DirectX7` as coclass
  `{E1211353-8E94-11D1-8808-00C04FC2C602}` and `IDirectX7` as interface
  `{FAFA3599-8B72-11D2-90B2-00C04FC2C602}`.
- `dx8vb.dll` embeds the DirectX 8 VB type library
  `{E1211242-8E94-11D1-8808-00C04FC2C603}` and does not contain the failing
  DirectX7 coclass GUID.

Conclusion: XP SP3's `dx7vb.dll` is the authentic local candidate for the
missing COM server that caused the original `REGDB_E_CLASSNOTREG` failure.

### Scratch registration-free COM launch probe

To avoid writing host registry state, a scratch run folder was created:

- `compat/re/run/Kawai2004_dx7vb_regfree/Kawai2004.exe`
- `compat/re/run/Kawai2004_dx7vb_regfree/MSVBVM50.DLL`
- `compat/re/run/Kawai2004_dx7vb_regfree/fmod.dll`
- `compat/re/run/Kawai2004_dx7vb_regfree/dx7vb.dll`
- `compat/re/run/Kawai2004_dx7vb_regfree/Kawai2004.exe.manifest`

The manifest maps the missing CLSID to the local `dx7vb.dll` and type library:

- COM class: `{E1211353-8E94-11D1-8808-00C04FC2C602}`
- ProgID: `DIRECT.DirectX6.0`
- Type library: `{E1211242-8E94-11D1-8808-00C04FC2C602}`, version `1.0`

No `regsvr32` call and no registry write were made.

Debugger confirmation:

- Report: `compat/re/reports/Kawai2004.gdb_directx6_regfree_return_addr.log`
- The same `CoCreateInstance` call for
  `{E1211353-8E94-11D1-8808-00C04FC2C602}` returned `EAX=00000000` (`S_OK`)
  with the registration-free COM manifest.

Startup probes:

- `compat/re/reports/Kawai2004.dx7vb_regfree.start_probe.json`: after 2.5
  seconds, the process stayed alive and showed visible `ThunderRT5Form` and
  `ThunderRT5Main` windows instead of error 91.
- `compat/re/reports/Kawai2004.dx7vb_regfree.delay8s.start_probe.json`: without
  a compatibility layer, the process reached a modal
  `Run-time error '445': Object doesn't support this action`.
- `compat/re/reports/Kawai2004.gdb_regfree_445_trace.log`: after successful
  COM creation, the startup routine reached `0x408121` with `EAX=80004001`
  (`E_NOTIMPL`) after the call at `0x40811e`. The arguments immediately before
  that call are `800`, `600`, `16`, `0`, `0`, which is consistent with a
  DirectDraw display-mode call such as `SetDisplayMode(800, 600, 16, 0, 0)`.
- `compat/re/reports/Kawai2004.dx7vb_regfree.layer.WINXPSP3.delay15s.start_probe.json`:
  with `__COMPAT_LAYER=WINXPSP3`, the process stayed alive for 15 seconds and
  showed visible `ThunderRT5Form` and `ThunderRT5Main` windows with no modal
  error captured by the probe.
- `compat/re/reports/Kawai2004.dx7vb_regfree.layer.WIN98_256COLOR_640X480.start_probe.json`:
  with `__COMPAT_LAYER='WIN98 256COLOR 640X480'`, the process exited with code
  `0` before the 8-second probe captured windows.

Interpretation: the error-91 blocker is resolved by a reversible local
registration-free COM shim using XP SP3 `dx7vb.dll`. The next blocker is
DirectDraw display-mode behavior on modern Windows; the built-in `WINXPSP3`
compatibility layer is currently enough to get through the 15-second startup
probe, but gameplay, input, rendering, audio, and clean-exit behavior still
need direct testing.

### Windowed DirectDraw wrapper probes

Goal: avoid the visible fullscreen mode switch where launching `Kawai2004`
shrinks the Windows desktop from the host resolution to 800x600.

Baseline display during these probes:

- Host desktop before testing: `2560x1440`, 32 bpp, 144 Hz.

cnc-ddraw v7.1.0.0 was downloaded from
`https://github.com/FunkyFr3sh/cnc-ddraw/releases/download/v7.1.0.0/cnc-ddraw.zip`
to ignored scratch:

- `compat/downloads/cnc-ddraw-v7.1.0.0.zip`
- SHA-256:
  `0B13AB89A64C9918189B1DADD449EF6ED3CB3B7B19CABD96D8ADBD95505BB908`
- Extracted to `compat/tools/cnc-ddraw-v7.1.0.0/`

cnc-ddraw results:

- `compat/re/reports/Kawai2004.dx7vb_cncddraw_windowed.no_layer_8s.screen_probe.jsonl`:
  without `WINXPSP3`, the process exited with code `0` before the 8-second
  probe captured a visible window; the desktop stayed at `2560x1440`.
- `compat/re/reports/Kawai2004.dx7vb_cncddraw_windowed.winxpsp3_15s.screen_probe.jsonl`:
  with `WINXPSP3`, the game stayed alive and showed visible windows, but the
  display still changed to `800x600` during the probe and returned to
  `2560x1440` after close.
- Module inspection during the `WINXPSP3` run showed
  `C:\WINDOWS\system32\ddraw.dll`, not the app-local cnc-ddraw `ddraw.dll`.
  This is consistent with `dx7vb.dll` using COM/DirectDraw activation in a way
  that bypasses the normal app-local `ddraw.dll` proxy path.

DxWnd v2.06.14 was downloaded from the SourceForge latest-build archive:

- Source:
  `https://sourceforge.net/projects/dxwnd/files/Latest%20build/v2_06_14_build.rar/download`
- Downloaded to `compat/downloads/dxwnd-v2.06.14.rar`
- SHA-256:
  `1D439F18819BEA903659677AC0A94AAB5C08533A585B5473DFB656E225EE4B5C`
- Extracted to `compat/tools/dxwnd-latest/`

Working DxWnd profile:

- Config: `compat/tools/dxwnd-latest/kawai2004_windowed.ini`
- Launcher: `scripts/launch-kawai2004-windowed-dxwnd.ps1`
- Invocation:
  `dxwnd.exe /Q /X /C:kawai2004_windowed.ini /R:1`
- Key settings: DirectX7 hook (`ver0=2`), additional module
  `module0=dx7vb.dll`, `renderer0=3`, 800x600 window size, and no Microsoft
  compatibility shim in `msshims0`.

DxWnd verification:

- `compat/re/reports/Kawai2004.dxwnd.dx7_module.window_rect_probe.json`:
  `screenChangedDuring=false` and `screenChangedAfter=false`; `dxwnd.dll` was
  loaded into the `Kawai2004.exe` process; the visible `ThunderRT5Form` titled
  `Kawai2004 v1.01` had rect `42,19,858,658` (`816x639` including the window
  frame).
- `compat/re/reports/Kawai2004.dxwnd.dx7_module.printwindow.png`: captured the
  title/menu window content from the hooked process.
- The tracked launcher script was also smoke-tested: after 8 seconds,
  `Kawai2004.exe` was alive with main title `Kawai2004` and the desktop
  remained `2560x1440` at 32 bpp.

Remaining uncertainty: this proves a windowed title/menu launch without the
desktop shrink. It does not yet prove full gameplay, input, sound effects,
music, save/load, or repeated exit stability.

### Next steps

1. Smoke-test gameplay behavior from the DxWnd windowed launch: title screen,
   tile rendering, mouse input,
   audio, repeated launch/exit, and window close.
2. Keep avoiding host registry writes unless explicitly approved with a
   documented rollback plan.
3. If a binary patch becomes necessary, keep using unpacked/patched scratch
   copies first and record exact original bytes, replacement bytes, offsets,
   hashes, and rationale before promotion.
