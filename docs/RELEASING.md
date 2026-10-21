# Kawai package release preparation

The scoped candidates are Kawai2003 v1.00, Kawai2004 v1.01, and Kawai2005
v1.00 on Windows 11 x64. Repository visibility and release publication require
separate user authorization. No build script creates a Git tag, uploads an
asset, changes repository visibility, or sends files to another person.

## Artifact model

The generic binary builder creates one independent artifact per game:

```text
Kawai2003-<version>.zip
Kawai2004-<version>.zip
Kawai2005-<version>.zip
```

Each has a matching extracted folder and `.zip.sha256` sidecar. Every package
contains:

- `PACKAGE-GAME.json`, identifying the selected game, original version,
  executable, and title prefix;
- `MANIFEST.json`, recording inputs, fixed payload hashes, and
  `redistributionStatus: not-cleared`;
- `CHECKSUMS-SHA256.txt` and `Verify-Package.ps1` for the exact fixed
  inventory; and
- a writable `runtime/` area created during launch for generated compatibility
  state.

Kawai2003 excludes `dx7vb.dll` and a COM manifest. Kawai2004 and Kawai2005
currently include the pinned XP `dx7vb.dll` compatibility candidate and their
game-specific registration-free manifests. All three use the verified VB5
runtime and selected DxWnd subset.

The original games may make legacy writes outside `runtime/`, including data
and MIDI files under `%TEMP%` and score files under `%WINDIR%\*.hst`. Treat standard-user and
write-path behavior as manual acceptance evidence, not as launcher guarantees.

The old `Expand-Kawai2004Inputs.ps1`, `Build-Kawai2004Package.ps1`, and
`Build-Kawai2004SourceKit.ps1` entry points remain thin backward-compatible
wrappers with their established Kawai2004 naming behavior. Use the generic
entry points for new work.

## Build final candidates

Follow [ASSEMBLY.md](ASSEMBLY.md) to obtain exact inputs and run
`Expand-KawaiRuntimeInputs.ps1`. Keep all generated output under ignored
`compat/`, and use a fresh output directory or version for every candidate.

Build each game with `Build-KawaiPackage.ps1 -Game <game>` and the applicable
runtime arguments. ZIP timestamps and ordering are normalized for the same
Windows PowerShell/.NET toolchain and unchanged inputs. If a different toolchain
produces a different ZIP, compare the extracted payload manifests before
calling it a binary change.

## Binary-free assembly kit

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiSourceKit.ps1
```

This creates `compat/releases/Kawai-assembly-kit-0.1.0-rc.1/`, its ZIP, and a
SHA-256 sidecar. The reviewed allowlist includes the generic three-game
scripts, compatibility wrappers, profiles, schema-2 input manifest, notices,
tests, and user documentation. It includes no game executable, Microsoft DLL,
DxWnd binary, downloaded archive, or Git history.

Before offering the kit, extract it to a fresh directory, run
`Verify-SourceKit.ps1`, and repeat representative Kawai2003 and DirectX-enabled
assembly paths from independently supplied inputs. The kit manifest proves
consistency, not publisher identity.

## Automated checks

Run the final source-state checks with Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiRuntimeInputs.ps1 `
  -Vb5Package inputs/Msvbvm50.exe `
  -XpSp3Package inputs/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe `
  -DxWndArchive inputs/dxwnd-v2.06.14.rar
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiPackage.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiSourceKit.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-PublicRepository.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-PublicRepositoryGuard.ps1
```

The runtime-input suite covers extraction with and without the optional XP
package. The current package, source-kit, and public-guard suites exercise 22,
9, and 17 cases respectively. Report the actual final command results; these
documented counts do not substitute for a fresh run after source changes.

## Manual acceptance and release gates

For each final game package:

1. Verify the folder and ZIP inventories and compare the independently
   supplied inputs with `packaging/inputs.json`.
2. Run the title-window, gameplay, input, audio, exit, relaunch, and legacy
   write-path checks in [RELEASE_TESTING.md](RELEASE_TESTING.md).
3. Complete clean-machine, standard-user, display-scaling, and downloaded-file
   tests before claiming general download-and-play support.
4. Record observed passes separately for Kawai2003, Kawai2004, and Kawai2005;
   do not generalize one game's result to the others.
5. Review final artifacts for absolute paths, caches, tools, screenshots,
   credentials, recovery material, and unexpected binaries.
6. Keep binary candidates private until every applicable gate in
   [REDISTRIBUTION.md](REDISTRIBUTION.md) is resolved. A source-kit release
   does not clear game, artwork, audio, FMOD, or Microsoft binary rights.

If a later approved release conveys DxWnd binaries, publish the exact
corresponding source archive identified in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) on the same release surface,
with the GPL and applicable notices.

## Publication boundary

Publication remains a separate requested action. Prepare a complete draft with
the tested version/commit, per-game support matrix, known limitations, notices,
and asset checksums before publishing. Complete the source-history and GitHub
surface checks in [PUBLICATION.md](PUBLICATION.md) before any visibility
change. Immutable release behavior is described in
[GitHub's documentation](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).
