# Assemble Kawai2003, Kawai2004, and Kawai2005

These steps create separate local portable packages from independently
obtained inputs. The scripts do not download inputs, run installers, or use
ignored local game directories as hidden fallbacks.

## Requirements

- Windows 11 x64 and Windows PowerShell 5.1.
- Built-in `expand.exe` and a `tar.exe` capable of reading the pinned DxWnd
  RAR archive.
- A source checkout or extracted `Kawai-assembly-kit-0.1.0-rc.1.zip`.
- Exact inputs matching [packaging/inputs.json](../packaging/inputs.json).

No Python, Node.js, compiler installation, administrator rights, or COM
registration is required. Local assembly does not establish redistribution
rights; read [REDISTRIBUTION.md](REDISTRIBUTION.md).

Run commands from the checkout or kit root. `ExecutionPolicy Bypass` applies
only to the invoked PowerShell process and does not change the saved machine
policy.

## 1. Obtain the original games and shared inputs

Create `inputs/`, then obtain these files independently:

| Saved file | Primary source | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `inputs/kawai2003.zip` | [Author archive](https://web.archive.org/web/20060430053638id_/http://myweb.hinet.net/home4/cps-chen/kawai2003/kawai2003.zip) | 1119696 | `40a56f3c04d40457048ba5f0d32b7579323903785ede997e0919928a87756e22` |
| `inputs/kawai2004v101.zip` | [Author archive](https://web.archive.org/web/20070227095657id_/http://cps-chen.myweb.hinet.net/kawai2004/kawai2004v101.zip) | 422228 | `3e722be316006e07fa3da8c39fa7926db41966b1501f756513df2335a93142c8` |
| `inputs/ki2005v1.zip` | [Author archive](https://web.archive.org/web/20070227095614id_/http://cps-chen.myweb.hinet.net/kawai2005/ki2005v1.zip) | 493601 | `79b12f1190a2e13f60e3481502184d39f967c1785252a3eca850e74fb7f728b0` |
| `inputs/Msvbvm50.exe` | [Microsoft](https://download.microsoft.com/download/vb50pro/utility/1/win98/EN-US/Msvbvm50.exe) | 992864 | `b5f8ea5b9d8b30822a2be2cdcb89cda99ec0149832659ad81f45360daa6e6965` |
| `inputs/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe` | [Microsoft Update Catalog: KB936929](https://www.catalog.update.microsoft.com/Search.aspx?q=KB936929) | 331805736 | `62e524a552db9f6fd22d469010ea4d7e28ee06fa615a1c34362129f808916654` |
| `inputs/dxwnd-v2.06.14.rar` | [SourceForge](https://sourceforge.net/projects/dxwnd/files/Latest%20build/v2_06_14_build.rar/download) | 12127475 | `1d439f18819bea903659677ac0a94aab5c08533a585b5473dfb656e225ee4b5c` |

The three game archives and the HTTPS-hosted VB5 and DxWnd files can be saved
with a browser or existing `curl.exe`, for example:

```powershell
New-Item -ItemType Directory -Path inputs

curl.exe -fL -o inputs/kawai2003.zip `
  'https://web.archive.org/web/20060430053638id_/http://myweb.hinet.net/home4/cps-chen/kawai2003/kawai2003.zip'
curl.exe -fL -o inputs/kawai2004v101.zip `
  'https://web.archive.org/web/20070227095657id_/http://cps-chen.myweb.hinet.net/kawai2004/kawai2004v101.zip'
curl.exe -fL -o inputs/ki2005v1.zip `
  'https://web.archive.org/web/20070227095614id_/http://cps-chen.myweb.hinet.net/kawai2005/ki2005v1.zip'
curl.exe -fL -o inputs/Msvbvm50.exe `
  'https://download.microsoft.com/download/vb50pro/utility/1/win98/EN-US/Msvbvm50.exe'
curl.exe -fL -o inputs/dxwnd-v2.06.14.rar `
  'https://sourceforge.net/projects/dxwnd/files/Latest%20build/v2_06_14_build.rar/download'
```

The tested `dx7vb.dll` source is the English x86 Windows XP SP3 package. Its
historical Microsoft CDN endpoint currently uses HTTP:

```text
http://www.download.windowsupdate.com/msdownload/update/software/dflt/2008/04/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe
```

HTTP does not authenticate the package. The extractor requires both the exact
SHA-256 and a valid Microsoft Authenticode signature before reading it. Do not
bypass either check, install XP SP3 on Windows 11, or substitute a DLL mirror.
The XP input is unnecessary when assembling only Kawai2003.

## 2. Extract the shared runtimes

For Kawai2004 and Kawai2005, or for all three games together:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Expand-KawaiRuntimeInputs.ps1 `
  -Vb5Package inputs/Msvbvm50.exe `
  -XpSp3Package inputs/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe `
  -DxWndArchive inputs/dxwnd-v2.06.14.rar
```

For Kawai2003 alone, omit the optional XP package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Expand-KawaiRuntimeInputs.ps1 `
  -Vb5Package inputs/Msvbvm50.exe `
  -DxWndArchive inputs/dxwnd-v2.06.14.rar
```

The default output is:

```text
compat/assembly-inputs/vb5/MSVBVM50.DLL
compat/assembly-inputs/directx/dx7vb.dll   # only when -XpSp3Package is supplied
compat/assembly-inputs/dxwnd/
```

The extractor validates package identities and Microsoft signatures, reads
installer cabinets as data, and publishes its staged output atomically. It
does not overwrite an existing output directory. Use `-OutputDirectory` for a
separate extraction. If the bundled `tar.exe` cannot read RAR, stop or use an
extractor you already trust, then supply that verified DxWnd directory to the
builder.

## 3. Build one package per game

Kawai2003 needs VB5 and DxWnd, without DirectX VB or a COM manifest:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 `
  -Game Kawai2003 `
  -GameArchive inputs/kawai2003.zip `
  -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL `
  -DxWndDirectory compat/assembly-inputs/dxwnd
```

Kawai2004 and Kawai2005 currently use the tested XP `dx7vb.dll` compatibility
candidate and their game-specific registration-free manifests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 `
  -Game Kawai2004 `
  -GameArchive inputs/kawai2004v101.zip `
  -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL `
  -DirectXRuntime compat/assembly-inputs/directx/dx7vb.dll `
  -DxWndDirectory compat/assembly-inputs/dxwnd

powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 `
  -Game Kawai2005 `
  -GameArchive inputs/ki2005v1.zip `
  -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL `
  -DirectXRuntime compat/assembly-inputs/directx/dx7vb.dll `
  -DxWndDirectory compat/assembly-inputs/dxwnd
```

Optional builder parameters are `-OutputDirectory`, `-Version`, and
`-InputManifest`. The default schema-2 manifest selects the exact game
archive, profile, executable name, DirectX requirement, and shared inputs.
Each package receives a checksummed `PACKAGE-GAME.json` describing the selected
game.

Default outputs are:

```text
compat/releases/Kawai2003-0.1.0-rc.1/
compat/releases/Kawai2003-0.1.0-rc.1.zip
compat/releases/Kawai2003-0.1.0-rc.1.zip.sha256
compat/releases/Kawai2004-0.1.0-rc.1/
compat/releases/Kawai2004-0.1.0-rc.1.zip
compat/releases/Kawai2004-0.1.0-rc.1.zip.sha256
compat/releases/Kawai2005-0.1.0-rc.1/
compat/releases/Kawai2005-0.1.0-rc.1.zip
compat/releases/Kawai2005-0.1.0-rc.1.zip.sha256
```

Existing artifacts are protected. A different version changes the output name
but does not establish broader compatibility or distribution rights. The old
Kawai2004-named builder and extractor remain compatibility wrappers; new work
should use the generic commands above.

## 4. Verify and test

For each package you built:

```powershell
Get-FileHash -LiteralPath compat/releases/Kawai2003-0.1.0-rc.1.zip -Algorithm SHA256
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File compat/releases/Kawai2003-0.1.0-rc.1/Verify-Package.ps1
```

Repeat with the Kawai2004 or Kawai2005 artifact name. Compare each ZIP hash
with its separate `.sha256` sidecar. A checksum stored inside an untrusted ZIP
is not an independent authenticity check.

After verification, extract the ZIP and use `Play.cmd`. The launcher writes
only its generated compatibility state under `runtime/`, but the original
games may extract data/MIDI files to `%TEMP%` and may attempt legacy score
writes under `%WINDIR%\*.hst`. Standard-user behavior for those game
writes is still being tested. The launcher does not install DLLs, register COM
servers, or elevate the game.

Runtime readiness differs by game. Consult [RELEASE_TESTING.md](RELEASE_TESTING.md)
for title-window, gameplay, input, audio, exit, relaunch, clean-machine, and
standard-user results. A package build or title-window observation alone is
not a gameplay pass.

## Troubleshooting

| Observation | Action |
| --- | --- |
| Hash or signature mismatch | Stop and recheck the exact source/version. Never disable validation. |
| Output already exists | Choose another `-Version` or `-OutputDirectory`; preserve the existing build. |
| Missing or unexpected package file | Extract to a fresh directory and run `Verify.cmd`. |
| Legacy path encoding error | Move the complete package to a short ASCII path. |
| Windows security or organization policy blocks an unsigned binary | Follow the device owner's policy; do not disable protection or elevate the game. |
| Title window is hidden or times out | Preserve visible dialogs, run `Verify.cmd`, and report the game, OS build, package hash, and observed process/window state. |

Local binary packages remain private while the gates in
[REDISTRIBUTION.md](REDISTRIBUTION.md) are unresolved.
