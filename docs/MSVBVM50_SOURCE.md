# MSVBVM50.DLL provenance

Date recorded: 2026-06-10

## Why this file is needed

The Kawai game executables are 32-bit Visual Basic 5 applications. On Windows 11, `Kawai2004.exe` first failed with:

> 程式碼執行無法繼續，因為找不到 MSVBVM50.DLL。重新安裝程式或許可以修正此問題。

`MSVBVM50.DLL` is the Microsoft Visual Basic 5 runtime library required by VB5 applications.

## Official Microsoft source used

Use the Microsoft redistributable package, not a random standalone DLL mirror:

- Direct Microsoft download URL: <https://download.microsoft.com/download/vb50pro/utility/1/win98/EN-US/Msvbvm50.exe>
- Microsoft Learn Q&A page that records the same direct Microsoft URL: <https://learn.microsoft.com/en-us/answers/questions/4186500/msvbvm50-dll-stil-available>
- Older Microsoft Learn Q&A references the historical Microsoft KB article `KB180071` / "Msvbvm50.exe Installs Visual Basic 5.0 Run-Time Files": <https://learn.microsoft.com/en-us/answers/questions/2451031/the-program-cant-start-because-msvbvm50-dll-is-mis>

## Local download and verification

Downloaded file:

```text
compat/downloads/Msvbvm50.exe
```

Download command used:

```powershell
Invoke-WebRequest `
  -Uri 'https://download.microsoft.com/download/vb50pro/utility/1/win98/EN-US/Msvbvm50.exe' `
  -OutFile '.\compat\downloads\Msvbvm50.exe'
```

Authenticode check:

```text
Status: Valid
Signer: Microsoft Corporation
```

Downloaded redistributable hash:

```text
SHA256: B5F8EA5B9D8B30822A2BE2CDCB89CDA99EC0149832659AD81F45360DAA6E6965
Size:   992,864 bytes
```

Extracted runtime DLL:

```text
compat/extracted/MSVBVM50.DLL
Version: 05.02.8244 (SP2)
SHA256:  8611DC1B60AE5C383BBA6CB3FFD8A51AEEBFF23B95844F0AB3D6E5ECD0FADC84
Size:    1,355,776 bytes
```

## Deployment choice for this project

I copied `MSVBVM50.DLL` beside each game executable instead of installing it globally into Windows system runtime directories:

```text
Kawai2003/MSVBVM50.DLL
Kawai2004/MSVBVM50.DLL
Kawai2005/MSVBVM50.DLL
```

This keeps the compatibility fix local to the game folders and avoids changing system-wide runtime state.
