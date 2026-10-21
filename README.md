# Kawai 2003-2005 on Windows 11

A source-only compatibility launcher and reproducible local assembly workflow
for:

- **KAWAI 連連看 2003 練習版 v1.00**;
- **KAWAI 連連看 2004 v1.01**; and
- **KAWAI 連連看 2005 v1.00**.

The original executables are supplied independently, verified by hash, and
kept unmodified. The initial support target is Windows 11 x64 with Windows
PowerShell 5.1.

## Release status

The current package version is **0.1.0-rc.1**. Local portable ZIPs can be
assembled for all three games, but complete binary bundles are **not cleared
for public redistribution**. Embedded artwork/audio rights, Microsoft runtime
files, and Kawai2004's historical FMOD conditions remain subject to the gates
in [REDISTRIBUTION.md](docs/REDISTRIBUTION.md).

All three generic packages reach their menus on the tested workstation.
Kawai2003 and Kawai2005 have matching-pair evidence on the workstation;
Kawai2004 has matching-pair and two X-close/relaunch cycles in fresh Windows
Sandbox. Kawai2003 and Kawai2005
also passed two actual X-close/relaunch cycles with owned-process cleanup on
the workstation. Fresh Sandbox runs for Kawai2003 and Kawai2005
remain blocked during legacy MIDI/RPC initialization, so these host results do
not establish universal clean-machine support. The authoritative per-game
matrix is [RELEASE_TESTING.md](docs/RELEASE_TESTING.md).

The binary-free assembly kit contains scripts, configuration, pinned hashes,
notices, and instructions for all three games. It contains no original game,
Microsoft runtime, or DxWnd binary. Repository visibility and any release
publication remain separate user-authorized actions.

Read the [v0.1.0-rc.1 release notes](https://github.com/KiringYJ/kawai-win11-compat/releases/tag/v0.1.0-rc.1).
The release has two uploaded assets: the binary-free kit and its checksum
sidecar:

- [`Kawai-assembly-kit-0.1.0-rc.1.zip`](https://github.com/KiringYJ/kawai-win11-compat/releases/download/v0.1.0-rc.1/Kawai-assembly-kit-0.1.0-rc.1.zip); and
- [`Kawai-assembly-kit-0.1.0-rc.1.zip.sha256`](https://github.com/KiringYJ/kawai-win11-compat/releases/download/v0.1.0-rc.1/Kawai-assembly-kit-0.1.0-rc.1.zip.sha256).

No original game or third-party runtime binary is a release asset while the
redistribution gates remain open.

GitHub also generates source ZIP and tar archives for the tag. Those archives
must be audited as source-only outputs; they are not substitutes for the
reviewed assembly kit and its checksum.

## Run a locally assembled package

1. Extract one complete `Kawai2003-0.1.0-rc.1.zip`,
   `Kawai2004-0.1.0-rc.1.zip`, or `Kawai2005-0.1.0-rc.1.zip` to a writable
   folder.
2. Run `Verify.cmd`, then double-click `Play.cmd` as a normal user.
3. Keep `game/`, `tools/`, and the launcher together, and close any existing
   DxWnd session before relaunching.

The launcher validates the fixed package inventory, prepares its own DxWnd
copies and profile under `runtime/`, and starts the selected original game. It
does not download files, install system DLLs, register COM servers, change the
saved PowerShell execution policy, or request administrator privileges.

Kawai2004 and Kawai2005 candidates use a local DirectX-for-Visual-Basic DLL
through an external registration-free COM manifest. Kawai2003 does not use
that DLL or manifest. The original games may still write extracted data/MIDI
files under `%TEMP%` and legacy score data under `%WINDIR%\*.hst`;
standard-user behavior for those paths remains part of manual acceptance
testing.

Use the games' own exit commands for their normal shutdown and score-saving
paths. The title-bar close behavior and other runtime observations are tracked
per game in [RELEASE_TESTING.md](docs/RELEASE_TESTING.md).

## Obtain the inputs independently

| Input | Primary source | Pinned version | SHA-256 |
| --- | --- | --- | --- |
| Kawai2003 | [Author page](https://web.archive.org/web/20071012014331id_/http://cps-chen.myweb.hinet.net/kawai2003/kawai2003.htm) · [Original ZIP](https://web.archive.org/web/20060430053638id_/http://myweb.hinet.net/home4/cps-chen/kawai2003/kawai2003.zip) | v1.00 | `40a56f3c04d40457048ba5f0d32b7579323903785ede997e0919928a87756e22` |
| Kawai2004 | [Author page](https://web.archive.org/web/20080604052530/http://cps-chen.myweb.hinet.net/kawai2004/kawai2004.htm) · [Original ZIP](https://web.archive.org/web/20070227095657id_/http://cps-chen.myweb.hinet.net/kawai2004/kawai2004v101.zip) | v1.01 | `3e722be316006e07fa3da8c39fa7926db41966b1501f756513df2335a93142c8` |
| Kawai2005 | [Author page](https://web.archive.org/web/20070227095642id_/http://cps-chen.myweb.hinet.net/kawai2005/kawai2005.htm) · [Original ZIP](https://web.archive.org/web/20070227095614id_/http://cps-chen.myweb.hinet.net/kawai2005/ki2005v1.zip) | v1.00 | `79b12f1190a2e13f60e3481502184d39f967c1785252a3eca850e74fb7f728b0` |
| Visual Basic runtime | [Microsoft `Msvbvm50.exe`](https://download.microsoft.com/download/vb50pro/utility/1/win98/EN-US/Msvbvm50.exe) | VB5 SP2, 05.02.8244 | `b5f8ea5b9d8b30822a2be2cdcb89cda99ec0149832659ad81f45360daa6e6965` |
| DirectX VB runtime source package | [Microsoft Update Catalog: KB936929](https://www.catalog.update.microsoft.com/Search.aspx?q=KB936929) | English x86 XP SP3; `dx7vb.dll` 5.03.2600.5512 | `62e524a552db9f6fd22d469010ea4d7e28ee06fa615a1c34362129f808916654` |
| Windowed compatibility tool | [DxWnd v2.06.14 build](https://sourceforge.net/projects/dxwnd/files/Latest%20build/v2_06_14_build.rar/download) · [matching source](https://sourceforge.net/projects/dxwnd/files/Sources/v2_06_14_src.rar/download) | 2.06.14 | `1d439f18819bea903659677ac0a94aab5c08533a585b5473dfb656e225ee4b5c` |

[packaging/inputs.json](packaging/inputs.json) is the canonical schema-2
manifest for game-specific archives and shared inputs. Use the exact pinned
versions, not standalone DLL mirrors or an untested latest build. The XP
package is optional when assembling only Kawai2003 and must come from a
lawfully licensed source when used.

## Assemble locally

The full workflow is in [ASSEMBLY.md](docs/ASSEMBLY.md). Extract the common
runtimes once for all three games:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Expand-KawaiRuntimeInputs.ps1 `
  -Vb5Package inputs/Msvbvm50.exe `
  -XpSp3Package inputs/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe `
  -DxWndArchive inputs/dxwnd-v2.06.14.rar
```

If assembling only Kawai2003, omit `-XpSp3Package`; the extractor then creates
only the VB5 and DxWnd inputs.

Build one package per game:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 -Game Kawai2003 -GameArchive inputs/kawai2003.zip -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL -DxWndDirectory compat/assembly-inputs/dxwnd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 -Game Kawai2004 -GameArchive inputs/kawai2004v101.zip -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL -DirectXRuntime compat/assembly-inputs/directx/dx7vb.dll -DxWndDirectory compat/assembly-inputs/dxwnd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 -Game Kawai2005 -GameArchive inputs/ki2005v1.zip -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL -DirectXRuntime compat/assembly-inputs/directx/dx7vb.dll -DxWndDirectory compat/assembly-inputs/dxwnd
```

The default output is three separate folders, ZIPs, and SHA-256 sidecars under
ignored `compat/releases/`. Every package includes checksummed
`PACKAGE-GAME.json` metadata. Existing output is protected; select a different
`-Version` or `-OutputDirectory` rather than overwriting it.

## Sources and licensing

The [author's archived software page](https://web.archive.org/web/20080604014823id_/http://cps-chen.myweb.hinet.net/public/menu_pc.htm)
invites downloading, free use, copying, and distribution of the author's
listed software works. That statement does not independently establish rights
in embedded artwork, music, or third-party runtimes.

The project's original scripts, manifests, configuration, and documentation
use the [MIT license](LICENSE). The MIT license does not cover independently
obtained games or third-party software. Read
[THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md) and
[REDISTRIBUTION.md](docs/REDISTRIBUTION.md) before sharing any binary package.

The public source history must exclude original games and third-party runtime
binaries. Local `Kawai2003/`, `Kawai2004/`, `Kawai2005/`, `inputs/`, and
`compat/` content remains ignored.

## Maintainer references

- [Release preparation](docs/RELEASING.md)
- [Repository publication checks](docs/PUBLICATION.md)
- [Runtime test matrix](docs/RELEASE_TESTING.md)
- [Third-party evidence](docs/THIRD_PARTY_NOTICES.md)
- [Local corpus hashes](docs/CORPUS_MANIFEST.md)
- [Reverse-engineering log](docs/RE_LOG.md)
