# Kawai2003 permission evidence

Shared author permission is recorded in
`packaging/licenses/KAWAI-PERMISSION-EVIDENCE.md`.

## Author publication

- game page:
  <https://web.archive.org/web/20071012014331id_/http://cps-chen.myweb.hinet.net/kawai2003/kawai2003.htm>
- original archive:
  <https://web.archive.org/web/20060430053638id_/http://myweb.hinet.net/home4/cps-chen/kawai2003/kawai2003.zip>
- archive size: 1,119,696 bytes
- archive SHA-256:
  `40a56f3c04d40457048ba5f0d32b7579323903785ede997e0919928a87756e22`

The Big5/CP950 game page identifies KAWAI 連連看 2003 練習版 v1.00 and says
`本軟體程式為自由使用軟體` (this software program is free-use software).
It recommends Windows 98SE and provides no warranty for other environments.

The ZIP contains exactly one file:

- `Kawai2003/Kawai2003.exe`: 1,152,000 bytes; SHA-256
  `4ba6929c8c7dbe7518c7726b46f13cd7ec540b64a494baf078c70a9c60327137`

There is no archive readme or adjacent media file. The executable is v1.00,
identifies `CHEN PROGRAM STUDY`, and imports `MSVBVM50.DLL` as its only
non-system dependency.

## Embedded-content boundary

The executable contains embedded WAV-like and MIDI resources and presents
recognizable Pokémon character artwork. No per-resource license or provenance
statement accompanies the archive. The author's permission is verified, but
this audit does not independently clear those embedded works for public binary
redistribution. It also does not establish that the author lacked permission.

Kawai2003 does not ship FMOD, and the inspected executable has no identified
DirectX-for-Visual-Basic dependency. A separately bundled `MSVBVM50.DLL` still
requires the Microsoft analysis in `MICROSOFT-RUNTIME-EVIDENCE.md`.
