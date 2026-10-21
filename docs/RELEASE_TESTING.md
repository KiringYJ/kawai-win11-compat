# Kawai 2003-2005 release-candidate verification

Targets: Kawai2003 v1.00, Kawai2004 v1.01, and Kawai2005 v1.00 with
DxWnd 2.06.14, Windows 11 x64, and Windows PowerShell 5.1. Test record date:
2026-10-22. The release label is `0.1.0-rc.1`.

These are local prerelease candidates. Technical verification and permission
to redistribute binaries are separate gates; see
[REDISTRIBUTION.md](REDISTRIBUTION.md).

## Automated checks

Run from the repository or extracted assembly-kit root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiRuntimeInputs.ps1 `
  -Vb5Package inputs/Msvbvm50.exe `
  -XpSp3Package inputs/windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe `
  -DxWndArchive inputs/dxwnd-v2.06.14.rar
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiPackage.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-KawaiSourceKit.ps1
```

The repository-history guards run from a Git checkout, not an extracted kit:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-PublicRepository.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-PublicRepositoryGuard.ps1
```

The package suite has **22 cases**, the source-kit suite **9 cases**, and the
public-history guard suite **17 cases**. The input integration suite checks
real pinned extraction with and without XP SP3, tampered inputs, existing
outputs, and destination collisions. It treats installer cabinets as data;
it does not install runtimes or run the games.

All four suites passed under Windows PowerShell 5.1 on the record date. The
actual published-ref history check is a separate post-rewrite gate; passing
the guard's fixtures does not establish that the repository is already clean.

Package fixtures cover all three game definitions, schema-1 compatibility for
the old Kawai2004 entry point, exact ZIP inventories, required DirectX inputs,
typed Boolean policies, safe paths, corruption, unexpected files, and output
protection. They execute the actual verifier and `-PrepareOnly`, including
runtime-copy refresh and rejection of an injected runtime DLL. Synthetic
executables are never run.

Both builders test repeatability and real two-process same-version publication
races: one process wins, its output verifies, and the loser neither nests
staging nor removes the winner. The suites also extract ZIPs with inbox
Windows PowerShell 5.1 `Expand-Archive`. The original Kawai2004 Chinese readme
name and its 2788 bytes are preserved. ZIP entry names use canonical UTF-8
encoding with the EFS flag. The source-kit suite runs the complete copied
package suite from an actual extracted kit.

Real game archives were independently obtained from the author's archived
site. Each executable matches the preserved original. The Microsoft VB5 and
XP SP3 packages match the pinned hashes and have valid Microsoft Authenticode
signatures on this host. All three local candidates must additionally verify
after real assembly; fixture success alone is not runtime evidence.

## Per-game runtime evidence

The workstation is Windows 11 Enterprise 26H2, build **26300.9711**, x64.
The fresh Windows Sandbox guest is build **26100**. Sandbox networking,
clipboard, microphone, camera, and printer redirection are disabled; inputs
are mapped read-only and only QA results are mapped writable.

| Check | Kawai2003 | Kawai2004 | Kawai2005 |
| --- | --- | --- | --- |
| Generic package reaches its actual visible title/menu on the workstation | Passed; about 3.9-4.5 seconds in two launches | Passed; about 1.7 seconds | Passed; about 1.7-2.3 seconds in two final launches |
| Render a board and remove a matching pair | Passed with the generic package | Passed in fresh Sandbox with the generic package; score 0 to 1 | Passed with the final taskbar-only generic package on the workstation; score 0 to 10 |
| Pause/resume controls | Pending | Pause overlay appeared and dismissed; board changed after resume, original semantics not established | Pause/card backs appeared and resumed with score retained; board changed, original semantics not established |
| Actual X click, game/helper/launcher cleanup, then relaunch | Passed twice on the workstation | Passed twice in fresh Sandbox with the current generic launcher; inventory verified after both | Passed twice on the workstation using the game's original custom X |
| In-game exit | Passed in the direct-native baseline; generic-package repeat pending | Pending | Passed from the final generic package's main menu after gameplay |
| Complete a board and verify saved scores | Pending | Pending | Pending |
| Music and sound heard or independently measured | Pending | Pending | Pending |
| Fresh clean-machine title/close/relaunch | Blocked in the tested Sandbox during legacy MIDI initialization | Passed twice in fresh Sandbox; broader clean-VM gameplay acceptance pending | Blocked in the tested Sandbox during legacy MIDI initialization |
| Separate standard non-administrator account, including legacy writes | Pending | Pending | Pending |
| Downloaded ZIP with Mark of the Web and normal Defender/SmartScreen settings | Pending | Pending | Pending |
| 100%/150% scaling and single/multiple monitors | Pending | Pending | Pending |

An unchecked item is pending. Loaded audio modules or enabled music controls
do not establish audible playback. An existing workstation is not a clean
machine; an unelevated token is not a separate standard-account test. Do not
change security settings, register system COM DLLs, or install global runtimes
to make a test pass.

The final generic Kawai2004 Sandbox run started a board, removed an adjacent
pair, and changed the score from 0 to 1. A pause overlay appeared and could be
dismissed; the board then changed, so the original pause behavior needs a
separate gameplay check. Actual title-bar X clicks closed both successive
instances. In both cycles, game, helper, and launcher PIDs exited, package
inventory still verified, and no unexpected fixed-payload file appeared.
Sandbox desktop size remained 2032x1111.

Kawai2004 also has earlier Windows PowerShell 5.1 launch evidence from ASCII,
spaced, and Chinese folder paths, and four startup/cleanup probes with desktop
resolution unchanged at 2560x1440. These observations do not establish every
game's path, display, or full gameplay behavior. See
[KAWAI2004_LOCAL_LAUNCH.md](KAWAI2004_LOCAL_LAUNCH.md) for those earlier probes.

## Window identification and close behavior

VB5 creates a helper window as well as its real form. `Process.MainWindowTitle`
may select that helper. The launcher enumerates visible windows belonging to
the exact newly started game process and checks the configured title prefix.
It also checks executable path, new PID, and direct DxWnd parent through CIM
before reporting success. A startup failure stops only that owned launch.

Kawai2005 changes its caption while loading. Its final visible form is
`KAWAI 連連看 2005 v1.00 `, including the spaces and a trailing space; its
earlier caption lacks those spaces. The manifest pins the stable visible
prefix. The original form is borderless and has its own skinned X. Only this
game enables `showInTaskbar`: the launcher sets `WS_EX_APPWINDOW` and clears
`WS_EX_TOOLWINDOW` on the visible same-PID `ThunderRT5Form`. It preserves the
original skin, size, position, and client area. The resulting form was
discoverable by the desktop window API and accepted actual X clicks in both
final host cycles. During gameplay, this custom X returns to the main menu;
the menu X or its exit command then closes the game. This is the observed
original control behavior. A separate taskbar-button/Alt-Tab usability check remains
pending.

The Kawai2004/2005 profiles preserve `HALFFLIPEMULATION` (`0x10000`) and use
DxWnd's `TERMINATEONCLOSE` (`0x8000`), giving `flagk0=98304`. That compatibility
close may terminate a game immediately; use its in-game exit for the original
shutdown and score-saving path. Kawai2003 keeps its existing profile and
normal caption close behavior. Do not infer one game's close result from
another.

The launcher waits for the game by default, then stops only its own DxWnd
helper. `-NoWait` is a diagnostic opt-out whose caller owns cleanup; normal
`Play.cmd` does not use it. An existing DxWnd session is rejected before a new
one starts. During the host matrix, an attempted second game's launch was
rejected without disrupting the first game's session.

## Legacy MIDI initialization in Sandbox

Kawai2003 and Kawai2005 reach their menus on the workstation. In the tested
fresh Sandbox they instead remain in startup with a hidden VB5 form, even
when launched directly without this compatibility launcher. Embedded music
files are extracted successfully; a missing external media archive is not
the observed cause.

A read-only debugger attachment to the blocked Kawai2003 instance found its
main thread waiting through `RPCRT4`/ALPC and another thread in `MCISEQ`.
Loaded modules included the legacy MIDI mapping/sequence drivers and the
remote audio endpoint. This supports a legacy MIDI/audio initialization
block in that environment; it does not prove a specific Windows defect or
establish the exact original MCI command. Alternative MIDI bypass and extra
hook experiments did not resolve it and are absent from the shipped profiles.

These Sandbox failures remain a compatibility limitation. Broader clean-VM
gameplay acceptance is pending for all three games. The packages retain
the prerelease label and must not advertise universal Windows 11 support.

## Filesystem and runtime boundaries

Kawai2003 needs VB5 and DxWnd and has no DirectX VB manifest. Kawai2004 and
Kawai2005 currently use the pinned `dx7vb.dll` candidate with game-specific
registration-free COM manifests. None of these files is installed or
registered globally.

The fixed payload contains seven DxWnd runtime/notice files. The unused
separate `MinHook.x86.dll` is omitted; the BSD notice for statically linked
MinHook code is retained. DxWnd resolves its injected DLL relative to its
initial working directory, so the launcher refreshes only the checked subset
in `runtime/dxwnd/`, generates its profile there, and starts DxWnd there.
The immutable payload remains unchanged.

The original games may extract music under `%TEMP%` and use legacy score
locations such as `%WINDIR%\kawai2003.hst` or `%WINDIR%\Ki2005.hst`, potentially
redirected to VirtualStore. A writable package directory does not establish
that these legacy writes succeed for every account. Original corpus files
and pre-existing score files are preserved separately from test output.

Windows PowerShell 5.1's .NET Framework `Process.Modules` can report only
WOW64/system modules for these x86 programs. Module enumeration is diagnostic,
not a launch-success gate. A QA child launched from PowerShell 7 also required
its inbox Windows PowerShell module path to avoid inheriting incompatible
PowerShell 7 paths; that test-harness issue is separate from `Play.cmd` launched
normally from Explorer.

## Promotion criteria

Keep the prerelease label while gameplay, audio, standard-account, downloaded
artifact, and broader clean-machine acceptance remain incomplete. Resolve the
separate applicable gates in [REDISTRIBUTION.md](REDISTRIBUTION.md) before
uploading binary bundles. Windows 10, Windows on ARM, other game versions,
and arbitrary newer DxWnd builds are outside this candidate's support claim.
