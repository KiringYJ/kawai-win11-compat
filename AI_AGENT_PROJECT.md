# Project-Specific Agent Context

## Architecture

This source-only repository contains the launcher, configuration,
documentation, and tests for locally assembling Kawai2003, Kawai2004, and
Kawai2005 compatibility packages for modern Windows, especially Windows 11.
Repository visibility and release publication remain separate user actions.

The canonical workflow is:

- `packaging/inputs.json` — schema-2 game definitions and shared pinned inputs;
- `scripts/Expand-KawaiRuntimeInputs.ps1` — verified VB5/DxWnd extraction with
  optional XP SP3 DirectX extraction;
- `scripts/Build-KawaiPackage.ps1` — generic per-game package builder;
- `scripts/Build-KawaiSourceKit.ps1` — unified binary-free assembly-kit
  builder; and
- `docs/ASSEMBLY.md`, `docs/RELEASE_TESTING.md`, and
  `docs/REDISTRIBUTION.md` — user workflow, runtime evidence, and publication
  boundaries.

The `Kawai2004`-named scripts are backward-compatible wrappers. New work
should use the generic entry points.

Original `Kawai2003/`, `Kawai2004/`, and `Kawai2005/` files may remain on the
maintainer's machine as ignored, untracked references. Their hashes and
provenance belong in tracked manifests and evidence documents. `inputs/`,
`compat/`, downloaded tools, screenshots, and generated packages also remain
ignored.

## Build Commands

Obtain the inputs described in `docs/ASSEMBLY.md`, then extract the shared
runtimes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Expand-KawaiRuntimeInputs.ps1 -Vb5Package inputs/Msvbvm50.exe -XpSp3Package inputs/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe -DxWndArchive inputs/dxwnd-v2.06.14.rar
```

`-XpSp3Package` is optional. Omit it for a Kawai2003-only extraction.

Build separate packages:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 -Game Kawai2003 -GameArchive inputs/kawai2003.zip -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL -DxWndDirectory compat/assembly-inputs/dxwnd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 -Game Kawai2004 -GameArchive inputs/kawai2004v101.zip -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL -DirectXRuntime compat/assembly-inputs/directx/dx7vb.dll -DxWndDirectory compat/assembly-inputs/dxwnd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiPackage.ps1 -Game Kawai2005 -GameArchive inputs/ki2005v1.zip -Vb5Runtime compat/assembly-inputs/vb5/MSVBVM50.DLL -DirectXRuntime compat/assembly-inputs/directx/dx7vb.dll -DxWndDirectory compat/assembly-inputs/dxwnd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-KawaiSourceKit.ps1
```

Default outputs are ignored `compat/releases/Kawai2003-<version>`,
`Kawai2004-<version>`, `Kawai2005-<version>`, and
`Kawai-assembly-kit-<version>` folders, ZIPs, and checksum sidecars. Existing
outputs are never overwritten. Windows PowerShell 5.1 and built-in Windows
extraction tools are the target toolchain; do not install dependencies as part
of this workflow.

## Test Commands

For extraction, packaging, source-kit, and repository-history behavior:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiRuntimeInputs.ps1 -Vb5Package inputs/Msvbvm50.exe -XpSp3Package inputs/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe -DxWndArchive inputs/dxwnd-v2.06.14.rar
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiPackage.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiSourceKit.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-PublicRepository.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-PublicRepositoryGuard.ps1
```

The runtime-input test covers extraction with and without XP SP3. The current
package, source-kit, and public-guard suites contain 22, 9, and 17 cases. Run
fresh checks after relevant changes and report actual results.

For each final package, run its `Verify-Package.ps1`, then the per-game manual
matrix in `docs/RELEASE_TESTING.md`. Separate build success, title-window
evidence, gameplay, input, audio, exit/relaunch, standard-user writes, and
clean-machine coverage. Do not infer one game's result from another. No binary
artifact is approved for public upload while `docs/REDISTRIBUTION.md` has an
applicable blocker.

## Important Files and Directories

- `README.md` — user-facing scope and assembly summary.
- `docs/ASSEMBLY.md` — exact independent-input workflow.
- `docs/RELEASING.md` — maintainer artifact and verification gates.
- `docs/PUBLICATION.md` — source-history, privacy, and GitHub-surface checks.
- `docs/RELEASE_TESTING.md` — authoritative current runtime matrix.
- `docs/THIRD_PARTY_NOTICES.md` — hashes, provenance, and license evidence.
- `packaging/profiles/` — per-game DxWnd templates.
- `packaging/portable/` — generic launcher and verifier payload.
- `Kawai2003/`, `Kawai2004/`, `Kawai2005/` — ignored local reference
  directories; never implicit build inputs.
- `compat/` — ignored downloads, extracted runtimes, probes, and outputs.

## Runtime Boundaries

- All three games use the selected VB5 runtime.
- Kawai2003 does not require the DirectX VB DLL or a COM manifest.
- Kawai2004 and Kawai2005 currently use the pinned XP SP3 `dx7vb.dll`
  compatibility candidate and game-specific registration-free manifests.
- `PACKAGE-GAME.json` is generated and checksummed in every package.
- The launcher writes generated compatibility state under `runtime/` and does
  not install DLLs, register COM servers, change saved execution policy, or
  request elevation.
- The original games may write data/MIDI files under `%TEMP%` and legacy score
  data under `%WINDIR%\*.hst`; standard-user behavior remains an
  explicit manual test boundary.

## Workspace Configuration

This project tracks agent-workbench managed agent/editor files in normal
history. `main` is the source of truth for `AI_AGENT_GUIDE.md`,
`AI_AGENT_PROJECT.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
`.agent-workbench.yaml`, `.agent-workbench.lock.json`, `.agents/`, `.codex/`,
`.claude/`, and `opencode.json`. Do not recreate the retired
`workspace-config` branch or hide project-wide files through local excludes.

## Commit Message Requirements

Follow the repository Lore and Conventional Commit rules. Include useful
`Tested:` or `Not-tested:` evidence for non-trivial product commits.

## Project-Specific Constraints

- Do not commit original games, third-party runtime binaries, downloaded
  installers, private recovery material, or assembled binary packages.
- Preserve original binaries unmodified in ignored local directories. Keep
  patched copies and experiments under ignored scratch paths.
- Prefer external manifests, profiles, shims, and launchers before binary
  patching.
- Any proposal to add a third-party binary requires an explicit policy
  decision and complete redistribution audit.
- Keep reverse-engineering and runtime notes evidence-backed. Distinguish
  confirmed behavior, hypotheses, and untested environments.
