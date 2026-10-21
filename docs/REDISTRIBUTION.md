# Redistribution policy and assembly routes

## Release posture

Do not publish a self-contained three-game binary package. It contains exact
binary components whose redistribution conditions have not all been cleared.
`docs/THIRD_PARTY_NOTICES.md` is the component-by-component evidence record.

A locally assembled package may be used for private compatibility testing. Do
not upload it, attach it to a public release, mirror it, or send it to another
person while the table below contains a blocking status.

| Gate | Status | Required change or evidence |
| --- | --- | --- |
| Author's Kawai2003/2004/2005 distribution permission | Verified, but not sufficient to clear the complete games | The archived author menu lists all three works and invites free use, copying, and distribution; the individual pages/readme identify them as free-use software or freeware. Preserve each exact archive and its original contents, but do not treat the statement as proof of rights in every embedded work. |
| Embedded character artwork and music/audio in all three games | Blocking evidence gap | The games present recognizable Pokémon character artwork and embedded audio. Their provenance and permissions have not all been independently verified. This does not establish that the original author lacked permission; it prevents this audit from clearing the executables for public redistribution. |
| Kawai2005 embedded MIDI resources | Blocking evidence gap | Resource metadata names third-party songs or artists and contains rights-reservation text, but the archive supplies no per-resource license or provenance statement. |
| FMOD 3.6 runtime in Kawai2004 | Conditional and unresolved | Keep any qualifying distribution entirely non-commercial and unpromoted, preserve integration with Kawai2004, add the required Firelight credit, and obtain a conservative release decision or project-specific confirmation about applying the available terms to this historical bundle. |
| `MSVBVM50.DLL` for all three games | Blocking if rebundled | Do not rebundle the loose DLL without license evidence. Have each user obtain the Authenticode-valid Microsoft redistributable and extract/install it locally. |
| XP SP3 `dx7vb.dll` for DirectX VB compatibility | Blocking if rebundled | Do not rebundle the extracted OS component. Require a user-supplied copy from a lawfully licensed source. |
| DxWnd v2.06.14 | Clear only with conditions | Ship the full GPL text, applicable notices, and exact complete corresponding source beside any conveyed binaries. |

## Public-safe binary-free assembly kit

A public repository or release can contain a binary-free kit: the project's
scripts, configuration, manifests, hashes, documentation, and the license or
permission notices that authorize their own reproduction. The assembly step
must run on the recipient's machine and require the recipient to supply these
inputs:

1. The exact author-published game archives:

   | Game | Archive SHA-256 |
   | --- | --- |
   | Kawai2003 v1.00 | `40a56f3c04d40457048ba5f0d32b7579323903785ede997e0919928a87756e22` |
   | Kawai2004 v1.01 | `3e722be316006e07fa3da8c39fa7926db41966b1501f756513df2335a93142c8` |
   | Kawai2005 v1.00 | `79b12f1190a2e13f60e3481502184d39f967c1785252a3eca850e74fb7f728b0` |

   Kawai2003 and Kawai2005 archives contain only their executable; Kawai2004
   also contains `fmod.dll` and the original Big5 readme.
2. Microsoft's `Msvbvm50.exe`, obtained from the official Microsoft URL and
   matching SHA-256
   `b5f8ea5b9d8b30822a2be2cdcb89cda99ec0149832659ad81f45360daa6e6965`.
3. For Kawai2004 and Kawai2005, a user-supplied `dx7vb.dll` from a lawfully
   licensed Windows XP SP3 source,
   matching SHA-256
   `617c432e02ba7c5b79d45e3d09aceb21e58a14b8f13d9be75164c3866c6c81c6`.
4. DxWnd v2.06.14 from its official SourceForge build, matching SHA-256
   `1d439f18819bea903659677ac0a94aab5c08533a585b5473dfb656e225ee4b5c`.

The kit should fail closed on any hash mismatch and should not fetch from DLL
mirrors or republish the supplied inputs. Requiring local inputs keeps the
public kit independent of a right to convey those binaries; it does not tell a
recipient that obtaining or using any file is lawful in their jurisdiction.

The intended source-only repository likewise excludes the local
`Kawai2003/`, `Kawai2004/`, and `Kawai2005/` directories, downloaded tools,
extracted runtimes, and assembled packages. Those files may remain in an
ignored local workspace, but they are not source-archive content. Repository
visibility is changed only through a separate user-authorized action after the
published history has been checked.

The bounded search for an alternative Microsoft source found historical
DirectX 7/7a redistributable installers, but no surviving official Microsoft
download and license evidence for extracting and app-local deploying their
`dx7vb.dll`. Those older installers also contain an earlier DirectX build, not
the exact XP SP3 file above. They are therefore not a verified substitute for
this assembly recipe.

## If a public binary bundle is later approved

Before producing it:

1. Resolve both Microsoft blockers or remove those files and switch to a
   user-supplied assembly step.
2. Resolve the embedded artwork and audio evidence gaps for every executable,
   including the identified Kawai2005 MIDI metadata, or keep the executables as
   user-supplied local inputs.
3. Resolve the FMOD condition for the intended Kawai2004 release model. At minimum,
   keep the bundle free of charges, monetisation, sponsorship, and promotion,
   keep `fmod.dll` integrated with Kawai2004, and include:

   ```text
   FMOD Sound System by Firelight Technologies Pty Ltd.
   ```

4. Use the exact original Kawai archive files and preserve the Kawai2004
   author readme. Do not describe the author permission as applying to
   third-party runtimes or embedded artwork and audio without separate
   evidence.
5. Limit DxWnd to files required by the verified profiles. Include
   `gpl-3.0.txt`, `packaging/licenses/MINHOOK-BSD-2-CLAUSE.txt`, and
   `packaging/licenses/DXWND-NOTICE.md`.
6. Publish the exact 14,041,449-byte
   `v2_06_14_src.rar` corresponding-source archive, SHA-256
   `3802ffe8692811401dea69dac65ec72136412d2e0d9ee08f1f2cb019d527cbd7`,
   on the same release surface as the DxWnd binaries.
7. Generate a final manifest of every conveyed file, size, SHA-256, origin,
   applicable license or permission, and source counterpart. Re-audit any file
   not listed in `docs/THIRD_PARTY_NOTICES.md`.

Do not publish until every blocking row is removed or replaced by a
user-supplied local assembly step.
