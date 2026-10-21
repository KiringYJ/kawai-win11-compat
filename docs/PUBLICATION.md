# Publishing the independent source-only repository

The public repository contains only the reviewed project source snapshot:
launcher code, configuration, documentation, tests, notices, and provenance
hashes for the Kawai2003, Kawai2004, and Kawai2005 assembly workflow. Obtain
all games and third-party runtimes independently through
[ASSEMBLY.md](ASSEMBLY.md).

The local `Kawai2003/`, `Kawai2004/`, `Kawai2005/`, `inputs/`, and `compat/`
directories remain untracked. Private recovery copies stay outside every
published ref and release asset.

## Independent-history policy

Create the canonical repository from a reviewed source-only directory with a
new Git initial commit. Do not copy or attach the old repository's `.git`
directory, refs, branches, tags, reflogs, worktrees, or other old-history and
private recovery state.

Ignored inputs and `compat/` content may be obtained or copied locally when
needed for assembly and runtime tests. Never stage, commit, attach, upload, or
otherwise publish those inputs or any generated binary output.

The new repository is an independent history. Do not merge an old branch,
push old tags, add a backup ref, or use `git push --mirror` from the old
working repository. Any later source changes should be applied and reviewed as
ordinary changes in the new history.

Keep private backups outside the canonical repository until their separately
authorized retention or deletion decision is complete. Removing or deleting
the old repository is a distinct cleanup action; the new repository does not
establish that old server objects or cached views have been purged.

## Pre-publication checks

Before any external write, verify the authenticated GitHub account and target
repository. Create or use only the intended canonical repository, initially
private, and confirm that its remote URL is correct before pushing.

From the new checkout root, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-PublicRepository.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-PublicRepositoryGuard.ps1
```

The source-history check rejects original-input directories, executable and
archive payloads, non-text blobs, Git LFS pointers, submodules, symlinks,
shallow history, grafts, replacement refs, and unsupported refs. The guard
tests these boundaries with isolated fixtures and does not execute game
binaries.

Also review the complete tracked inventory and commit metadata for
credentials, personal information, real machine paths, generated files, and
unexpected artifacts. This is a source payload boundary, not a comprehensive
secret scanner.

## Verify the private canonical repository

After pushing the new initial history while the repository is private:

1. Make a fresh clone from GitHub and run the source-history check against
   `HEAD`.
2. Make a fresh mirror clone and run
   `Test-PublicRepository.ps1 -RepositoryDirectory <mirror-directory> -AllRefs`
   so every server-advertised ref is covered. Clone and mirror checks establish
   advertised reachable history; they do not test cached or otherwise
   unadvertised server objects.
3. While the repository is private, use authenticated GitHub Git data API
   requests against the new canonical repository for each excluded old commit
   and blob object ID: `GET /repos/<owner>/<repo>/git/commits/<oid>` for commits
   and `GET /repos/<owner>/<repo>/git/blobs/<oid>` for blobs. The excluded
   requests must return not found. In the same session, query a known-new
   commit and blob through the corresponding endpoints as positive controls;
   those requests must succeed. Keep all
   actual object IDs in the private migration checklist and out of public
   documentation and release notes.
4. Confirm that no old branches, tags, backup refs, releases, Actions
   artifacts, PR attachments, wiki pages, Pages content, or other repository
   surfaces introduced excluded material.
5. Repeat the authentication and target-repository check immediately before
   changing visibility.
6. After the repository is public, repeat the excluded commit/blob API checks
   without authentication and repeat the known-new positive controls. Excluded
   objects must remain unavailable while the public positive controls succeed.

Passing these checks establishes the reviewed state of the independent new
repository. It does not make a claim about purging or deleting objects on any
separate old repository.

## Public source-kit release

Repository visibility and release publication are separate actions. A public
source-only repository or assembly kit does not clear redistribution rights
for complete game/runtime bundles. Keep the binary publication gates in
[REDISTRIBUTION.md](REDISTRIBUTION.md) and the runtime limitations in
[RELEASE_TESTING.md](RELEASE_TESTING.md).

Rebuild `Kawai-assembly-kit-0.1.0-rc.1.zip` from the final reviewed source,
extract and verify it, and repeat the representative independent-input builds
in [RELEASING.md](RELEASING.md). The only uploaded v0.1.0-rc.1 release assets
are:

- [`Kawai-assembly-kit-0.1.0-rc.1.zip`](https://github.com/KiringYJ/kawai-win11-compat/releases/download/v0.1.0-rc.1/Kawai-assembly-kit-0.1.0-rc.1.zip); and
- [`Kawai-assembly-kit-0.1.0-rc.1.zip.sha256`](https://github.com/KiringYJ/kawai-win11-compat/releases/download/v0.1.0-rc.1/Kawai-assembly-kit-0.1.0-rc.1.zip.sha256).

Publish those assets with the
[v0.1.0-rc.1 release notes](https://github.com/KiringYJ/kawai-win11-compat/releases/tag/v0.1.0-rc.1).
GitHub-generated source ZIP and tar archives also appear for the tag; audit
them as source-only archives before treating the release as complete.
Do not upload original game archives, executables, Microsoft or DxWnd binaries,
local inputs, generated game packages, or private recovery material.
