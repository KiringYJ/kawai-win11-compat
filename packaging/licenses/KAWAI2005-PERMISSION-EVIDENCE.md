# Kawai2005 permission evidence

Shared author permission is recorded in
`packaging/licenses/KAWAI-PERMISSION-EVIDENCE.md`.

## Author publication

- game page:
  <https://web.archive.org/web/20070227095642id_/http://cps-chen.myweb.hinet.net/kawai2005/kawai2005.htm>
- original archive:
  <https://web.archive.org/web/20070227095614id_/http://cps-chen.myweb.hinet.net/kawai2005/ki2005v1.zip>
- archive size: 493,601 bytes
- archive SHA-256:
  `79b12f1190a2e13f60e3481502184d39f967c1785252a3eca850e74fb7f728b0`

The Big5/CP950 game page identifies KAWAI 連連看 2005 v1.00 and says
`本軟體程式為自由使用軟體(Freeware)`. It says the game uses DirectX 7 to
play music, was developed on Windows 98SE, and was tested with DirectX 8.0
without warranting operation in other environments.

The ZIP contains exactly one file:

- `kawai2005/KI2005.EXE`: 508,416 bytes; SHA-256
  `0e12c1b83ef61a7238a228c933637579cc4ecfb5a571c27a2eed2768bc9ff485`

There is no archive readme or adjacent media file. The executable is v1.00,
identifies `CHEN PROGRAM STUDY`, and imports `MSVBVM50.DLL` as its only
non-system static dependency.

## Embedded-content boundary

The executable contains embedded WAV and MIDI resources and presents
recognizable Pokémon character artwork. MIDI metadata identifies third-party
songs or artists and includes rights-reservation text. No per-resource license
or provenance statement accompanies the archive. The author's permission is
verified, but this audit does not independently clear those embedded works for
public binary redistribution. It also does not establish that the author
lacked permission.

Any package that supplies `MSVBVM50.DLL` or an extracted DirectX-for-Visual-
Basic runtime must separately satisfy the Microsoft evidence and license
boundaries in `MICROSOFT-RUNTIME-EVIDENCE.md`.
