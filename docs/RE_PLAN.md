# Reverse-engineering work plan

## Goal

Make the Kawai Win98-era games start and run on Windows 11 with the smallest practical compatibility layer or binary patch.

## Baseline evidence

- `Kawai2004.exe` failed first due to missing `MSVBVM50.DLL`.
- Side-by-side deployment of Microsoft VB5 runtime file `MSVBVM50.DLL` resolved the missing-DLL startup blocker.
- `Kawai2004.exe` now reaches `Run-time error '91': Object variable or With block variable not set`.
- `Kawai2004` readme says the game was built for DirectX 7-era systems and tested on Windows 98SE.
- The first reverse-engineering pass is recorded in [`RE_LOG.md`](RE_LOG.md).
  It first narrowed `Kawai2004` error 91 to the first `__vbaNew2` object
  creation in the startup/Form_Load-equivalent routine.
- Follow-up `CoCreateInstance` tracing now shows that object creation requests
  CLSID `{E1211353-8E94-11D1-8808-00C04FC2C602}` with `IID_IUnknown` and
  `CLSCTX 0x5`, then returns `0x80040154` (`REGDB_E_CLASSNOTREG`).
- Read-only registry and file checks found no local COM registration for that
  class and no `dx6vb.dll`, `dx7vb.dll`, or `dx8vb.dll` under the Windows
  system directories or repository tree.
- Microsoft XP SP3 contains `dx7vb.dll`; its embedded type library identifies
  `DirectX7` as coclass `{E1211353-8E94-11D1-8808-00C04FC2C602}`.
- A scratch-only registration-free COM manifest for `dx7vb.dll` makes that
  `CoCreateInstance` return `S_OK`. Without a compatibility layer the next
  blocker is runtime error 445 after a DirectDraw display-mode call returns
  `0x80004001` (`E_NOTIMPL`).
- Adding the built-in `WINXPSP3` compatibility layer to the scratch reg-free
  COM setup gets `Kawai2004` to a visible main window for a 15-second probe.
  The earlier `FMOD.DLL`, BMP-size, and OLE-picture hypotheses are lower
  priority unless new evidence puts them back on the failing path.

## Next investigation steps

1. Use [`KAWAI2004_LOCAL_LAUNCH.md`](KAWAI2004_LOCAL_LAUNCH.md) as the current
   reproducible local launch recipe, keeping `dx7vb.dll` provenance and hashes
   documented.
2. Run gameplay-oriented smoke tests: title screen visibility, tile rendering,
   mouse input, audio, window close, and repeated launch/exit.
3. Investigate whether `WINXPSP3` is required only for DirectDraw
   `SetDisplayMode(800, 600, 16, 0, 0)`, and whether a wrapper/shim can provide
   the same behavior without global registry writes.
4. Do not write host registry state without explicit approval and a rollback
   note.
5. If a binary patch is required, document offsets, original bytes, replacement
   bytes, file hash, and rationale.

## Current focus

Continue from `docs/RE_LOG.md` by validating the scratch launch recipe:
`MSVBVM50.DLL` side-by-side, XP SP3 `dx7vb.dll`, external
`Kawai2004.exe.manifest`, and `__COMPAT_LAYER=WINXPSP3`. Treat `FMOD.DLL`,
the BMP-size anomaly, and OLE-picture warnings as secondary until gameplay
testing or later traces put them back on the failing path.

## Patch policy

- Keep the preserved original corpus binaries unmodified.
- Generate patched copies or external loader/shim files for experiments.
- Record exact hashes before and after any patch.
- The private corpus directories may be committed intentionally; keep generated patched copies, unpacked working copies, downloaded installers, extracted scratch runtimes, and local reverse-engineering tools out of product history unless explicitly promoted.
