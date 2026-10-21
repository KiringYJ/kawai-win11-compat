Kawai - Windows 11 portable compatibility package
================================================

This ZIP contains one original game, identified by its filename and
PACKAGE-GAME.json. This local candidate is for testing on your own computer.
Public binary redistribution is NOT cleared; read docs/REDISTRIBUTION.md
before sharing it.

1. Extract the entire ZIP to a writable folder.
2. Double-click Play.cmd as a normal user.
3. Close the game normally when finished. Close any older DxWnd session first.

Leave the launcher console open while playing. It waits for the game to end,
then closes its own DxWnd helper and exits.

Use the in-game exit for the game's normal shutdown and score-saving path.
Title-bar close behavior is verified separately for each game; consult
RELEASE_TESTING.md for the current results and remaining gaps.

Keep game/ and tools/ intact. Verify.cmd checks the complete fixed inventory,
including unexpected files; runtime/ holds generated configuration and state.
Compare the ZIP's SHA-256 with its separate .sha256 sidecar before extraction.
For example, from the folder containing your downloaded ZIPs:

  Get-FileHash .\Kawai*-0.1.0-rc.1.zip -Algorithm SHA256

The launcher verifies the package and prepares only its own DxWnd runtime
copies and selected profile. It runs the original, unpatched game in a window.
It does not download files, register COM DLLs, install system DLLs, or request
administrator rights. Where required, a side-by-side COM manifest supplies
the local legacy DirectX VB runtime; Kawai2003 does not use that runtime.
Play.cmd uses ExecutionPolicy Bypass only for its one PowerShell process;
it does not change the computer's saved execution-policy setting.

If Windows blocks a download, inspect its source, hashes and notices before
deciding what to run. Do not disable Defender, SmartScreen or antivirus, or
elevate the game to work around a warning. Managed device policies may prevent
unsigned software from running. An ASCII folder name may be needed on systems
whose legacy ANSI code page cannot represent the selected folder name.

This package is unsigned. Hash verification proves consistency, not safety or
publisher identity. See docs/THIRD_PARTY_NOTICES.md for versions and sources,
docs/REDISTRIBUTION.md for licensing limits, and the source project's README.md
and docs/ASSEMBLY.md to assemble your own copy from independent inputs.

Support target: Windows 11 x64. See docs/RELEASE_TESTING.md for observed tests
and remaining gaps. A title-window launch is not a complete gameplay test.
