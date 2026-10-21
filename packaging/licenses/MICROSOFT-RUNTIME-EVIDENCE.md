# Microsoft runtime evidence

This file records provenance and unresolved redistribution boundaries. An
official download or a valid signature proves origin, not a right to rehost an
extracted component.

## Visual Basic 5 runtime

- Microsoft package: `Msvbvm50.exe`
- official URL:
  <https://download.microsoft.com/download/vb50pro/utility/1/win98/EN-US/Msvbvm50.exe>
- package size: 992,864 bytes
- package SHA-256:
  `b5f8ea5b9d8b30822a2be2cdcb89cda99ec0149832659ad81f45360daa6e6965`
- local Authenticode status: valid; signer `Microsoft Corporation`
- extracted `MSVBVM50.DLL`: version 05.02.8244 (SP2), 1,355,776 bytes,
  SHA-256
  `8611dc1b60ae5c383bba6cb3ffd8a51aeebff23b95844f0ab3d6e5ecd0fadc84`

Microsoft and its support records describe the package as the Visual Basic 5
runtime redistributable. The extracted package contains no local EULA that
establishes this project's right to rehost the DLL by itself. The public-safe
route therefore requires each user to obtain the Microsoft package from
Microsoft and perform the local extraction or installation.

## DirectX for Visual Basic runtime

- selected file: XP SP3 `dx7vb.dll` version 5.03.2600.5512
- size: 619,008 bytes
- SHA-256:
  `617c432e02ba7c5b79d45e3d09aceb21e58a14b8f13d9be75164c3866c6c81c6`
- source package: Windows XP SP3
  `windowsxp-kb936929-sp3-x86-enu_c81472f7eeea2eca421e116cd4c03e2300ebfde4.exe`
- package size: 331,805,736 bytes
- package SHA-256:
  `62e524a552db9f6fd22d469010ea4d7e28ee06fa615a1c34362129f808916654`

The source package's Supplemental EULA says that a user without a validly
licensed copy of Windows XP may not install, copy, or otherwise use the OS
components. It does not provide a standalone redistribution grant for an
extracted `dx7vb.dll`.

Historical DirectX 7 redistributable installers carried an earlier 4.07 build
and are not the source of this exact 5.03.2600.5512 file. The bounded audit did
not find a surviving official Microsoft download and license path authorizing
app-local extraction of the earlier DLL either. Do not substitute an
unverified mirror or claim that the old DirectX installer clears this file.
