# DxWnd v2.06.14 notice

DxWnd copyright (C) 2004-2024 SFB7/GHO and contributors.

The inspected DxWnd source states that the hook module and host are free
software under the GNU General Public License, version 3 or later. The
distribution includes the GPLv3 text as `gpl-3.0.txt`.

Selected upstream build:

- <https://sourceforge.net/projects/dxwnd/files/Latest%20build/v2_06_14_build.rar/download>
- size: 12,127,475 bytes
- SHA-256:
  `1d439f18819bea903659677ac0a94aab5c08533a585b5473dfb656e225ee4b5c`

Complete corresponding source:

- <https://sourceforge.net/projects/dxwnd/files/Sources/v2_06_14_src.rar/download>
- size: 14,041,449 bytes
- SHA-256:
  `3802ffe8692811401dea69dac65ec72136412d2e0d9ee08f1f2cb019d527cbd7`

The source archive includes:

- OllyDbg Disassembling Engine 2.01 source for `Disasm.dll`, marked
  GPL-3.0-or-later by Oleh Yuschuk;
- MinHook 1.3.4 source and its two-clause BSD notice; and
- the DxWnd project files that link `libMinHook.x86.lib` into `dxwnd.dll`.

When conveying DxWnd binaries, accompany them with the complete GPL text,
`MINHOOK-BSD-2-CLAUSE.txt`, and the exact corresponding source archive above.
Host the source on the same release surface rather than relying only on a
mutable third-party link. Do not assume DxWnd's GPL grants rights to Kawai2004,
FMOD, or Microsoft runtime files distributed beside it.
