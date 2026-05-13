# AzStackHci.ManageUpdates - Transitional Stub

> **This folder is temporary.** It exists at the repo's old name so that anyone
> visiting `github.com/NeilBird/Azure-Local/tree/main/AzStackHci.ManageUpdates`
> (e.g. from a stale bookmark, blog post, or search result) lands on the
> migration message. Delete it (in a follow-up PR) once the transitional
> `AzStackHci.ManageUpdates` v0.7.3 stub has been published to PSGallery and
> any remaining automation has been migrated.

## What this is

This folder contains a one-time, no-code "stub" of the **deprecated** module
`AzStackHci.ManageUpdates`. It exists solely to surface a migration message
to anyone who still runs:

```powershell
Install-Module AzStackHci.ManageUpdates
Import-Module AzStackHci.ManageUpdates
```

The stub exports **zero functions**. Importing it emits a `Write-Warning`
that tells the user to install the renamed module instead:

```powershell
Uninstall-Module AzStackHci.ManageUpdates -AllVersions
Install-Module AzLocal.UpdateManagement
```

See [`AzLocal.UpdateManagement/CHANGELOG.md`](../AzLocal.UpdateManagement/CHANGELOG.md)
for the full migration note.

## Why a separate folder

The real module lives in [`../AzLocal.UpdateManagement/`](../AzLocal.UpdateManagement/).
This folder is deliberately named `AzStackHci.ManageUpdates/` (the legacy name) so
that GitHub.com URLs of the form
`github.com/NeilBird/Azure-Local/tree/main/AzStackHci.ManageUpdates` continue to
resolve and land users on this deprecation README. When the legacy name is fully
retired, this whole folder goes away with a single
`git rm -r AzStackHci.ManageUpdates/` commit.

## Files

| File | Purpose |
|---|---|
| `AzStackHci.ManageUpdates.psd1` | Module manifest. Same GUID as previously-published AzStackHci.ManageUpdates versions (PSGallery requirement). Exports no functions. |
| `AzStackHci.ManageUpdates.psm1` | Stub script. Emits a `Write-Warning` on import; contains no functions. |
| `Publish-TransitionalLegacyName.ps1` | **One-shot.** Publishes the stub to PSGallery. Run once, after publishing `AzLocal.UpdateManagement` v0.7.3. |

## Publish workflow (run-once)

1. From the repo, publish the **renamed** module first:
   ```powershell
   cd AzLocal.UpdateManagement
   .\Publish-Module.ps1
   ```
2. Then publish the transitional stub:
   ```powershell
   cd ..\AzStackHci.ManageUpdates
   .\Publish-TransitionalLegacyName.ps1
   ```
3. (Optional, recommended) After a few weeks of no installs, log in to
   [PSGallery](https://www.powershellgallery.com/packages/AzStackHci.ManageUpdates)
   and **unlist** this v0.7.3 too.
4. Open a follow-up PR titled e.g. `chore: remove AzStackHci.ManageUpdates
   transitional stub` that `git rm -r`'s this folder.

## Module identity

The stub keeps the original `AzStackHci.ManageUpdates` GUID
(`a8b9c0d1-e2f3-4a5b-6c7d-8e9f0a1b2c3d`). The renamed module
(`AzLocal.UpdateManagement`) also keeps that same GUID. They are two
different PSGallery module IDs but share an identity — by design, so that
PowerShell tooling recognises the rename as one continuous module history.

If a user has both installed and tries to import both into the same session,
PowerShell will refuse the second import with a "module GUID already loaded"
error. This is the **correct** behaviour and is preferable to silent
duplicate-function shadowing.
