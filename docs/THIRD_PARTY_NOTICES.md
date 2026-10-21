# Third-party notices and release status

This document records the evidence used to assess a possible non-commercial
compatibility package for Kawai2003, Kawai2004, and Kawai2005. It is a release
checklist, not legal advice. Possession of a file, an official download, or a
permission for one component does not grant rights to the rest of the bundle.

The components below are independently supplied local assembly inputs or
generated-package contents. Listing their hashes and terms does not mean their
binaries are included in the intended source-only repository or its normal
source archives.

## Current decision

The complete three-game binary bundle is **not cleared for public
redistribution**. The author's archived permission establishes an invitation
to copy and distribute all three listed software works, but it does not by
itself establish rights in every embedded work. The games present recognizable
Pokémon character artwork and contain embedded music or audio whose provenance
and permissions have not all been independently verified. This is an evidence
gap, not a finding that the original author lacked permission. The Microsoft,
FMOD, and DxWnd components retain the separate conditions below.

## Original games

| Game | Exact author publication | Permission evidence | Unresolved content | Public binary status |
| --- | --- | --- | --- | --- |
| Kawai2003 v1.00 | ZIP: 1,119,696 bytes; SHA-256 `40a56f3c04d40457048ba5f0d32b7579323903785ede997e0919928a87756e22`. Its sole file is `Kawai2003.exe`, SHA-256 `4ba6929c8c7dbe7518c7726b46f13cd7ec540b64a494baf078c70a9c60327137`. | The author page calls it free-use software, and the common author menu invites download, free use, copying, and distribution. The ZIP has no readme. | Recognizable character artwork and embedded WAV-like/MIDI resources have no accompanying per-resource provenance or license. | **Author permission verified; executable not release-cleared.** See `packaging/licenses/KAWAI2003-PERMISSION-EVIDENCE.md`. |
| Kawai2004 v1.01 | ZIP: 422,228 bytes; SHA-256 `3e722be316006e07fa3da8c39fa7926db41966b1501f756513df2335a93142c8`. Executable SHA-256 `b0a5f68e0e2f63db07fad33c54dd4ef654ca5c317d4a62d9ef5cfe63494934f9`; original 2,788-byte readme SHA-256 `844e12932ab2ac992a565c1ed5a3588d4fb9698213e39903cdce69a5e24037b1`. | The original readme calls it `FREEWARE`, and the common author menu supplies the same copy/distribution invitation. | Recognizable character artwork and embedded music/audio lack independent provenance evidence; bundled FMOD has separate conditions below. | **Author permission verified; executable not release-cleared.** See `packaging/licenses/KAWAI2004-PERMISSION-EVIDENCE.md`. |
| Kawai2005 v1.00 | ZIP: 493,601 bytes; SHA-256 `79b12f1190a2e13f60e3481502184d39f967c1785252a3eca850e74fb7f728b0`. Its sole file is `KI2005.EXE`, SHA-256 `0e12c1b83ef61a7238a228c933637579cc4ecfb5a571c27a2eed2768bc9ff485`. | The author page calls it free-use software (`Freeware`), and the common author menu supplies the same copy/distribution invitation. The ZIP has no readme. | Recognizable character artwork and embedded WAV/MIDI resources lack accompanying licenses. MIDI metadata names third-party songs or artists and contains rights-reservation text. | **Author permission verified; executable not release-cleared.** See `packaging/licenses/KAWAI2005-PERMISSION-EVIDENCE.md`. |

The shared permission text and its limits are recorded in
`packaging/licenses/KAWAI-PERMISSION-EVIDENCE.md`.

## Shared and compatibility components

| Component | Identified version and hash | Evidence | Public binary status |
| --- | --- | --- | --- |
| `fmod.dll` (Kawai2004 only) | FMOD 3.6; SHA-256 `9879a9200fe52adfedaf7a6f9b8d726aa6370fde249dcc7a608eedef3388f36c` | Firelight's contemporaneous 2003 licensing page allowed FMOD free in a product that made no money and was not charged for; its current EULA expressly includes FMOD 3 runtime redistribution when integrated in a non-commercial product, subject to no monetisation, sponsorship, or promotion and a credit requirement. | **Conditional; not yet release-cleared.** Evidence supports a free, integrated game distribution, but the 2004 archive did not include a license text, the current EULA says the credit is required in-game, and no project-specific confirmation from Firelight has been obtained. Do not distribute the DLL alone or use it in a monetized, sponsored, promoted, or commercial release. |
| `MSVBVM50.DLL` (all three, if bundled) | 05.02.8244 (SP2); SHA-256 `8611dc1b60ae5c383bba6cb3ffd8a51aeebff23b95844f0ab3d6e5ecd0fadc84` | All three executables depend on the VB5 runtime. The selected file is extracted from Microsoft's Authenticode-valid `Msvbvm50.exe`, SHA-256 `b5f8ea5b9d8b30822a2be2cdcb89cda99ec0149832659ad81f45360daa6e6965`. The package contains no license text granting this project standalone loose-DLL redistribution. | **Not cleared for rebundling as a loose DLL.** A public assembly flow should have the user obtain the Microsoft package from Microsoft and extract/install it locally. |
| `dx7vb.dll` (DirectX VB compatibility path) | 5.03.2600.5512; SHA-256 `617c432e02ba7c5b79d45e3d09aceb21e58a14b8f13d9be75164c3866c6c81c6` | Kawai2004 and Kawai2005 use DirectX 7-era functionality. The tested DLL is extracted from Windows XP SP3 package `windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe`, SHA-256 `62e524a552db9f6fd22d469010ea4d7e28ee06fa615a1c34362129f808916654`. Its Supplemental EULA requires a validly licensed XP copy and grants no standalone redistribution right for an extracted OS component. | **Not cleared for public redistribution.** Require a user-supplied file from a lawfully licensed source. |
| DxWnd shared compatibility tool | v2.06.14 build archive SHA-256 `1d439f18819bea903659677ac0a94aab5c08533a585b5473dfb656e225ee4b5c` | DxWnd source headers and its bundled `gpl-3.0.txt` state GPL-3.0-or-later. | **Redistributable only with GPL compliance.** Include the GPL, notices, and complete corresponding source. |
| `Disasm.dll` | SHA-256 `f413a207787da88281500aaeae07fb98d7d438ecb4d67f8fcdf0aff2f988717f` | The v2.06.14 source archive contains the OllyDbg Disassembling Engine 2.01 source and marks it GPL-3.0-or-later. | **Redistributable with the same GPL source-and-license handling.** It is dynamically loaded for assembly-inspection features such as exception handling. |
| MinHook | 1.3.4; bundled `MinHook.x86.dll` SHA-256 `32667dbd34787133d0cda2cbb1aebc543daef4abf435f346527ed6aa5d47b313` | MinHook and its Hacker Disassembler Engine portions use the two-clause BSD conditions reproduced in `packaging/licenses/MINHOOK-BSD-2-CLAUSE.txt`. The v2.06.14 `dxwnd.dll` project links `libMinHook.x86.lib` statically. | **Redistributable with the BSD notice.** The separate `MinHook.x86.dll` is not an import of the examined `dxwnd.exe` or `dxwnd.dll`; omit it unless a selected feature actually requires it. |

## DxWnd corresponding source

The exact upstream source archive matching the selected build is:

- [DxWnd v2.06.14 source](https://sourceforge.net/projects/dxwnd/files/Sources/v2_06_14_src.rar/download)
- size: 14,041,449 bytes
- SHA-256: `3802ffe8692811401dea69dac65ec72136412d2e0d9ee08f1f2cb019d527cbd7`

An upstream link by itself is not the project's durable GPL compliance plan.
If a public release conveys DxWnd binaries, place this exact source archive on
the same release surface, include the full GPL text and the MinHook notice,
and keep the source available for as long as the binary is offered. If a
written-offer route is used instead, it must meet GPLv3 section 6, including
its duration and fulfillment requirements.

The complete upstream build archive contains many optional tools and bundled
libraries that the selected launch paths do not need. A release should use
the smallest verified DxWnd subset rather than treating GPL coverage as a
license for every file in that archive.

## Primary evidence

- Kawai software-page capture (Big5):
  <https://web.archive.org/web/20080604014823id_/http://cps-chen.myweb.hinet.net/public/menu_pc.htm>
- Author-published Kawai2003 v1.00 page and archive:
  <https://web.archive.org/web/20071012014331id_/http://cps-chen.myweb.hinet.net/kawai2003/kawai2003.htm>
  and
  <https://web.archive.org/web/20060430053638id_/http://myweb.hinet.net/home4/cps-chen/kawai2003/kawai2003.zip>
- Author-published Kawai2004 v1.01 page and archive:
  <https://web.archive.org/web/20080604052530/http://cps-chen.myweb.hinet.net/kawai2004/kawai2004.htm>
  and
  <https://web.archive.org/web/20070227095657id_/http://cps-chen.myweb.hinet.net/kawai2004/kawai2004v101.zip>
- Author-published Kawai2005 v1.00 page and archive:
  <https://web.archive.org/web/20070227095642id_/http://cps-chen.myweb.hinet.net/kawai2005/kawai2005.htm>
  and
  <https://web.archive.org/web/20070227095614id_/http://cps-chen.myweb.hinet.net/kawai2005/ki2005v1.zip>
- Firelight's contemporaneous licensing page (capture dated 2003-10-08):
  <https://web.archive.org/web/20031008115624id_/http://fmod.org/fmodlicense.html>
- [Current FMOD EULA](https://www.fmod.com/legal), especially clauses 1.2,
  2, and 3
- Microsoft VB5 runtime package:
  <https://download.microsoft.com/download/vb50pro/utility/1/win98/EN-US/Msvbvm50.exe>
- [Microsoft guidance on redistributable DLL selection](https://learn.microsoft.com/en-us/cpp/windows/determining-which-dlls-to-redistribute)
- [DxWnd v2.06.14 source listing](https://sourceforge.net/projects/dxwnd/files/Sources/)
- [DxWnd maintainer's GPL statement](https://sourceforge.net/p/dxwnd/discussion/general/thread/f03dcd9fe7/)
- [OllyDbg disassembler source license](https://ollydbg.org/srcdescr.htm)

The Windows XP SP3 EULA evidence is preserved locally from the original
package at `compat/extract/xpsp3/i386/update/eula.txt`; `compat/` is ignored
research material and is not itself a publication surface.
