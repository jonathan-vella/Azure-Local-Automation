# Azure Local Update Management Module (AzLocal.UpdateManagement)

> ⚠️ **Disclaimer**: This module is **NOT** a Microsoft supported service offering or product. It is provided as example code only, with no warranty or official support. Refer to the [MIT license](https://github.com/NeilBird/Azure-Local/blob/main/LICENSE) for further information.

**Latest Version:** v0.7.41 - [Published is PowerShell Gallery](https://www.powershellgallery.com/packages/AzLocal.UpdateManagement/0.7.41)

> 📢 **Renamed in v0.7.3**: this module was previously published as `AzStackHci.ManageUpdates`. The new module name aligns with the Azure Local product name (_Microsoft retired the *Azure Stack HCI* brand in late 2024_). The module GUID is preserved across the rename. If you have the old name installed, run:
>
> ```powershell
> Get-Module AzStackHci.ManageUpdates -ListAvailable | Uninstall-Module -Force -Verbose
> Install-Module AzLocal.UpdateManagement
> ```
>
> All previously-published `AzStackHci.ManageUpdates` versions have been unlisted from PSGallery. See [CHANGELOG.md](CHANGELOG.md) for the full migration note. This message will be removed in two releases time.

This folder contains the 'AzLocal.UpdateManagement' PowerShell module for managing updates on Azure Local (formerly Azure Stack HCI) clusters using the Azure Local REST API. The module supports both interactive use and CI/CD automation via Service Principal or Managed Identity authentication.

Azure Local REST API specification (includes update management endpoints): https://github.com/Azure/azure-rest-api-specs/blob/main/specification/azurestackhci/resource-manager/Microsoft.AzureStackHCI/StackHCI/stable/2026-02-01/hci.json

<details>
<summary><strong>📑 Table of Contents</strong> (click to expand)</summary>

- [Where to Start](#where-to-start)
  - [Getting started interactively](#getting-started-interactively)
  - [Common workflows (function-invocation order)](#common-workflows-function-invocation-order)
- [What's New in v0.7.41](#whats-new-in-v0741)
- [Files](#files)
- [Prerequisites](#prerequisites)
- [RBAC Requirements](#rbac-requirements)
  - [Recommended Built-in Roles](#recommended-built-in-roles)
  - [Specific Permissions Required](#specific-permissions-required)
  - [Roles That Do NOT Have Update Permissions](#roles-that-do-not-have-update-permissions)
  - [Custom "Azure Stack HCI Update Operator" Role Definition (Least Privilege)](#custom-azure-stack-hci-update-operator-role-definition-least-privilege)
  - [Assigning a Role](#assigning-a-role)
- [Quick Start](#quick-start)
  - [1. Authenticate to Azure](#1-authenticate-to-azure)
  - [2. Install or Import the Module](#2-install-or-import-the-module)
  - [3. Start an Update on a Single Cluster](#3-start-an-update-on-a-single-cluster)
  - [4. Start Updates on Multiple Clusters](#4-start-updates-on-multiple-clusters)
  - [5. Start a Specific Update](#5-start-a-specific-update)
  - [6. Check Update Progress](#6-check-update-progress)
  - [7. Set Up Update Management Tags for Staged Rollouts](#7-set-up-update-management-tags-for-staged-rollouts)
  - [7a. Sideloaded Payload Workflow (v0.7.1)](#7a-sideloaded-payload-workflow-v071)
  - [8. Assess Readiness and Health BEFORE Applying Updates (Recommended)](#8-assess-readiness-and-health-before-applying-updates-recommended)
- [Available Functions](#available-functions)
  - [`Connect-AzureLocalServicePrincipal`](#connect-azurelocalserviceprincipal)
  - [`Start-AzureLocalClusterUpdate`](#start-azurelocalclusterupdate)
  - [`Get-AzureLocalClusterUpdateReadiness`](#get-azurelocalclusterupdatereadiness)
  - [`Get-AzureLocalClusterInfo`](#get-azurelocalclusterinfo)
  - [`Get-AzureLocalUpdateSummary`](#get-azurelocalupdatesummary)
  - [`Get-AzureLocalAvailableUpdates`](#get-azurelocalavailableupdates)
  - [`Get-AzureLocalUpdateRuns`](#get-azurelocalupdateruns)
  - [`Test-AzureLocalClusterHealth`](#test-azurelocalclusterhealth)
  - [`Get-AzureLocalClusterInventory`](#get-azurelocalclusterinventory)
  - [`Set-AzureLocalClusterUpdateRingTag`](#set-azurelocalclusterupdateringtag)
- [Fleet-Scale Operations](#fleet-scale-operations)
  - [`Invoke-AzureLocalFleetOperation`](#invoke-azurelocalfleetoperation)
  - [`Get-AzureLocalFleetProgress`](#get-azurelocalfleetprogress)
  - [`Test-AzureLocalFleetHealthGate`](#test-azurelocalfleethealthgate)
  - [`Export-AzureLocalFleetState`](#export-azurelocalfleetstate)
  - [`Resume-AzureLocalFleetUpdate`](#resume-azurelocalfleetupdate)
  - [`Stop-AzureLocalFleetUpdate`](#stop-azurelocalfleetupdate)
  - [`Test-AzureLocalUpdateScheduleAllowed`](#test-azurelocalupdatescheduleallowed)
  - [`Reset-AzureLocalSideloadedTag`](#reset-azurelocalsideloadedtag)
  - [`Get-AzureLocalFleetStatusData`](#get-azurelocalfleetstatusdata)
  - [`New-AzureLocalFleetStatusHtmlReport`](#new-azurelocalfleetstatushtmlreport)
- [Logging and Output](#logging-and-output)
  - [Log Files](#log-files)
  - [Logging Examples](#logging-examples)
  - [Log Entry Format](#log-entry-format)
  - [Results Export Format](#results-export-format)
- [API Reference](#api-reference)
- [Update States](#update-states)
  - [Cluster Update Summary States](#cluster-update-summary-states)
  - [Individual Update States](#individual-update-states)
- [Using Azure CLI Directly](#using-azure-cli-directly)
- [Alternative: Az.StackHCI PowerShell Module](#alternative-azstackhci-powershell-module)
- [CI/CD Automation](#cicd-automation)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [`WARNING: Unable to encode the output with cp1252 encoding`](#warning-unable-to-encode-the-output-with-cp1252-encoding)
  - [ARM is stale - readiness recommends an already-installed update](#arm-is-stale---readiness-recommends-an-already-installed-update)
  - [Verbose Logging](#verbose-logging)
- [License](#license)
- [Release History](#release-history)
  - [What's New in v0.7.4](#whats-new-in-v074)
  - [What's New in v0.7.3](#whats-new-in-v073)
  - [What's New in v0.7.2](#whats-new-in-v072)
  - [What's New in v0.7.1](#whats-new-in-v071)
  - [What's New in v0.7.0](#whats-new-in-v070)
  - [What's New in v0.6.5](#whats-new-in-v065)
  - [What's New in v0.6.4](#whats-new-in-v064)
  - [What's New in v0.6.3](#whats-new-in-v063)
  - [What's New in v0.6.2](#whats-new-in-v062)
  - [What's New in v0.6.1](#whats-new-in-v061)
  - [What's New in v0.5.6 (since v0.5.0)](#whats-new-in-v056-since-v050)
  - [What's New in v0.5.0](#whats-new-in-v050)
  - [What's New in v0.4.2](#whats-new-in-v042)
  - [What's New in v0.4.1](#whats-new-in-v041)
  - [What's New in v0.4.0](#whats-new-in-v040)

</details>

## Where to Start

This module supports **two main paths**. Pick the one that matches your scenario:

| Path | Best for | Auth | Where to read next |
|------|----------|------|--------------------|
| **Interactive** | Manual ops, ad-hoc fleet checks, tag clean-up, learning the module | `az login` | Continue below - the [Quick Start](#quick-start) and per-function reference sections in this README |
| **CI/CD / scheduled automation** | GitHub Actions, Azure DevOps, scheduled fleet reports, gated wave deployments | OIDC, Managed Identity, or Service Principal | **[Automation-Pipeline-Examples/README.md](./Automation-Pipeline-Examples/README.md)** - end-to-end pipeline guide with copy-pasteable workflows |

### Getting started interactively

If you are new to this module, work through these in order from a regular PowerShell session. Each step links to the dedicated reference section further down the README.

| Step | Goal | Function(s) |
|------|------|-------------|
| 1 | Authenticate to Azure | `az login` (interactive) - see [Quick Start - 1. Authenticate](#1-authenticate-to-azure) |
| 2 | Discover what is in the fleet | [`Get-AzureLocalClusterInventory`](#get-azurelocalclusterinventory) |
| 3 | Tag clusters into rings (Wave1, Prod, Test, ...) | [`Set-AzureLocalClusterUpdateRingTag`](#set-azurelocalclusterupdateringtag) |
| 4 | Assess readiness for the wave | [`Get-AzureLocalClusterUpdateReadiness`](#get-azurelocalclusterupdatereadiness), [`Test-AzureLocalClusterHealth`](#test-azurelocalclusterhealth) |
| 5 | Apply the update | [`Start-AzureLocalClusterUpdate`](#start-azurelocalclusterupdate) (single cluster or `-ScopeByUpdateRingTag` for a wave) |
| 6 | Monitor and report | [`Get-AzureLocalUpdateRuns`](#get-azurelocalupdateruns), [`Get-AzureLocalFleetProgress`](#get-azurelocalfleetprogress), [`New-AzureLocalFleetStatusHtmlReport`](#new-azurelocalfleetstatushtmlreport) |

> **For CI/CD?** Skip this table and go straight to [Automation-Pipeline-Examples/README.md](./Automation-Pipeline-Examples/README.md) - it covers OIDC / Managed Identity / Service Principal setup, federated credentials, three GitHub Actions workflows, and three Azure DevOps pipelines.

### Common workflows (function-invocation order)

| Scenario | Recommended order |
|----------|-------------------|
| **One-off cluster update** | `az login` -> `Get-AzureLocalUpdateSummary` -> `Get-AzureLocalAvailableUpdates` -> `Start-AzureLocalClusterUpdate` -> `Get-AzureLocalUpdateRuns` |
| **Staged wave deployment** | `Get-AzureLocalClusterInventory` -> `Set-AzureLocalClusterUpdateRingTag` -> `Get-AzureLocalClusterUpdateReadiness -ScopeByUpdateRingTag` -> `Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag` -> `Get-AzureLocalFleetProgress` -> `New-AzureLocalFleetStatusHtmlReport` |
| **Daily fleet status report** | `Get-AzureLocalFleetStatusData -AllClusters -IncludeUpdateRuns -IncludeHealthDetails -ExportPath ...` -> `New-AzureLocalFleetStatusHtmlReport -StatusData $data -OutputPath ...` |
| **Pre-update health gate (CI/CD)** | `Test-AzureLocalClusterHealth -BlockingOnly` -> `Test-AzureLocalUpdateScheduleAllowed` -> `Test-AzureLocalFleetHealthGate` -> proceed only on pass |
| **Sideloaded payload (v0.7.1)** | Operator sets `UpdateSideloaded=False` -> stage payload out-of-band -> operator flips `UpdateSideloaded=True` -> `Start-AzureLocalClusterUpdate` (auto-stamps `UpdateVersionInProgress`) -> `Get-AzureLocalUpdateRuns` (auto-resets tags on success) -> `Reset-AzureLocalSideloadedTag -Force` only if a tag gets stuck |
| **Pause / resume long fleet run** | `Stop-AzureLocalFleetUpdate -SaveState` -> ... -> `Resume-AzureLocalFleetUpdate -StateFilePath ...` |
| **Recover from emergency** | `Stop-AzureLocalFleetUpdate` -> `Test-AzureLocalClusterHealth` (assess) -> `Resume-AzureLocalFleetUpdate -RetryFailed` |

> Most CI/CD pipelines in [Automation-Pipeline-Examples/](Automation-Pipeline-Examples/) are direct implementations of one of these workflows. Start there if you want a copy-pasteable end-to-end pipeline.

## What's New in v0.7.41

- **Hotfix - parallel fleet reads broken by the v0.7.3 NestedModules refactor**: v0.7.41 fixes two related regressions that surfaced on the PSGallery-installed v0.7.4 build whenever **`-ThrottleLimit > 1`** was used.
  - **Bug 1**: every fleet read dispatched through `Invoke-FleetJobsInParallel` (`Get-AzureLocalUpdateRuns`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalClusterUpdateReadiness`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalFleetProgress`, `Invoke-AzureLocalFleetOperation`, `Test-AzureLocalClusterHealth`, and `Start-AzureLocalClusterUpdate`'s parallel path) returned `State = Error` for every cluster with the message *"Cannot use '&' to invoke in the context of module 'Invoke-FleetJobsInParallel' because it is not imported."* Inline (`-ThrottleLimit 1`) execution was unaffected. Root cause: the v0.7.3 refactor that split the monolithic `.psm1` into `NestedModules` changed the meaning of `$PSCommandPath` inside `Invoke-FleetJobsInParallel.ps1` - it now resolves to that helper's own `.ps1`, **not** to the root `AzLocal.UpdateManagement.psd1`. Each per-batch `Start-Job` scriptblock then imported only that single `.ps1` in the child runspace as a transient module, so subsequent `& $module { Get-AzLocalClusterUpdateRuns ... }` calls resolved against a session state that contained none of the private helpers.
  - **Bug 2**: `New-AzureLocalFleetStatusHtmlReport -ThrottleLimit > 1` (via `Get-AzureLocalFleetStatusData`) threw at start-up: *"Parallel collection requires module path '...\\Public\\AzLocal.UpdateManagement.psm1' to be reachable by background jobs, but it does not exist."* Same class of regression but a separate code path: `Get-AzureLocalFleetStatusData` computed its own module path using `Join-Path $PSScriptRoot 'AzLocal.UpdateManagement.psm1'`, which under the post-v0.7.3 layout resolves to the `Public/` subfolder - one level too deep. `New-AzureLocalFleetStatusHtmlReport`'s footer manifest-fallback had the same flaw.
- **Centralised module-root resolution**: introduced a new private helper [`Get-AzLocalModuleRootManifestPath`](Private/Get-AzLocalModuleRootManifestPath.ps1) used by all three sites. It prefers the loaded module's `.Path` (`.psd1` over `.psm1`) and falls back to walking up from the caller's `$PSCommandPath`, so it returns the correct root manifest path from any file under `Public/` or `Private/`. Future helpers won't reintroduce the same "`$PSScriptRoot` is module root" assumption.
- **Regression coverage**: existing parallelisation tests only exercised the inline `-ThrottleLimit 1` fast-path, which reuses the parent runspace and so could not reproduce either bug. v0.7.41 adds Pester tests that (a) assert `Invoke-FleetJobsInParallel` passes the **root manifest path** (`.psd1`/`.psm1`) as the trailing `ModulePath` argument and **not** the helper's own `.ps1`, and (b) directly exercise `Get-AzLocalModuleRootManifestPath` with synthetic caller paths under `Public/` and `Private/`. Full suite: **354/354 green**.

> Previous release notes have moved into the [Release History](#release-history) appendix at the bottom of this document.

## Files

| File | Description |
|------|-------------|
| `AzLocal.UpdateManagement.psd1` | PowerShell module manifest |
| `AzLocal.UpdateManagement.psm1` | PowerShell module with functions to start updates on multiple Azure Local clusters |
| `example-update-request.json` | Example JSON showing API request/response structures for the Update Manager API |

## Prerequisites

- **Azure CLI** (`az`) installed and authenticated
- **PowerShell** 5.1 or later (Desktop or Core edition)
- **Permissions**: Azure Stack HCI Administrator or equivalent role (see RBAC Requirements below)
- **Cluster Requirements**: Cluster must be in "Connected" status with updates available
- **For tag-based filtering**: Azure CLI `resource-graph` extension (automatically installed by the module when using `-ScopeByUpdateRingTag`)

## RBAC Requirements

To start updates on Azure Local clusters, users need specific permissions on the `Microsoft.AzureStackHCI` resource provider.

### Recommended Built-in Roles

| Role | Role ID | Description |
|------|---------|-------------|
| **Azure Stack HCI Administrator** | `bda0d508-adf1-4af0-9c28-88919fc3ae06` | Full access to cluster and resources, including updates |
| **Azure Stack HCI Device Management Role** | `865ae368-6a45-4bd1-8fbf-0d5151f56fc1` | Full cluster operations including updates |

### Specific Permissions Required

The following permissions are required for update operations:

| Operation | Required Permission |
|-----------|---------------------|
| Read cluster info | `Microsoft.AzureStackHCI/clusters/read` |
| Read update summary | `Microsoft.AzureStackHCI/clusters/updateSummaries/read` |
| List available updates | `Microsoft.AzureStackHCI/clusters/updates/read` |
| **Start/Apply update** | `Microsoft.AzureStackHCI/clusters/updates/apply/action` |
| Monitor update runs | `Microsoft.AzureStackHCI/clusters/updateRuns/read` |
| Query clusters (Resource Graph) | `Microsoft.ResourceGraph/resources/read` |
| **Read/Write tags** | `Microsoft.Resources/tags/read`, `Microsoft.Resources/tags/write` |

### Roles That Do NOT Have Update Permissions

| Role | Reason |
|------|--------|
| Azure Stack HCI VM Contributor | Only has `clusters/read` - cannot apply updates |
| Azure Stack HCI VM Reader | Read-only access to VMs, no cluster update permissions |
| Contributor (generic) | Does not include `Microsoft.AzureStackHCI` permissions by default |

### Custom "Azure Stack HCI Update Operator" Role Definition (Least Privilege)

If you need a least-privilege custom role specifically for update operations:

```json
{
  "Name": "Azure Stack HCI Update Operator",
  "IsCustom": true,
  "Description": "Can view and apply updates on Azure Local clusters, manage UpdateRing tags",
  "Actions": [
    "Microsoft.AzureStackHCI/clusters/read",
    "Microsoft.AzureStackHCI/clusters/updateSummaries/read",
    "Microsoft.AzureStackHCI/clusters/updates/read",
    "Microsoft.AzureStackHCI/clusters/updates/apply/action",
    "Microsoft.AzureStackHCI/clusters/updateRuns/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.ResourceGraph/resources/read",
    "Microsoft.Resources/tags/read",
    "Microsoft.Resources/tags/write"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}"
  ]
}
```

Save this JSON to a file named `azlocal-update-management-custom-role.json`, then create the custom role using Azure CLI:

`AssignableScopes` must contain a real subscription ID - the literal `{subscription-id}` placeholder will be rejected by `az role definition create`. Capture the current subscription first, or hard-code the IDs you intend to manage:

```powershell
# Use the current az CLI subscription, or set $subId manually
$subId = az account show --query id -o tsv
```

```powershell
# Option 1: File already on disk - substitute the placeholder, then create
(Get-Content ./azlocal-update-management-custom-role.json -Raw) `
    -replace '\{subscription-id\}', $subId |
    Set-Content ./azlocal-update-management-custom-role.json -Encoding UTF8

az role definition create --role-definition ./azlocal-update-management-custom-role.json

# Option 2: Create the file and role in one step using PowerShell (expanding here-string - $subId is interpolated)
@"
{
  "Name": "Azure Stack HCI Update Operator",
  "IsCustom": true,
  "Description": "Can view and apply updates on Azure Local clusters, manage UpdateRing tags",
  "Actions": [
    "Microsoft.AzureStackHCI/clusters/read",
    "Microsoft.AzureStackHCI/clusters/updateSummaries/read",
    "Microsoft.AzureStackHCI/clusters/updates/read",
    "Microsoft.AzureStackHCI/clusters/updates/apply/action",
    "Microsoft.AzureStackHCI/clusters/updateRuns/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.ResourceGraph/resources/read",
    "Microsoft.Resources/tags/read",
    "Microsoft.Resources/tags/write"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/$subId"
  ]
}
"@ | Out-File -FilePath ./azlocal-update-management-custom-role.json -Encoding UTF8

az role definition create --role-definition ./azlocal-update-management-custom-role.json
```

> **Note**: Option 2 uses a double-quoted here-string (`@"..."@`) so PowerShell expands `$subId` before writing the JSON to disk. A literal here-string (`@'...'@`) would NOT expand the variable - you would have to substitute the placeholder yourself as in Option 1.

### Assigning a Role

```powershell
# Assign Azure Stack HCI Administrator role to a user
az role assignment create `
  --assignee "user@contoso.com" `
  --role "Azure Stack HCI Administrator" `
  --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}"
```

> **Reference**: [Azure built-in roles for Hybrid + multicloud](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/hybrid-multicloud)

## Quick Start

### 1. Authenticate to Azure

The module supports three authentication methods. Choose based on your scenario:

| Method | Best For | Secrets Required |
|--------|----------|------------------|
| **Interactive** | Manual/ad-hoc use | None (browser login) |
| **OpenID Connect (OIDC)** | GitHub Actions, Azure DevOps | None (federated) |
| **Managed Identity** | Azure VMs, self-hosted runners | None (assigned identity) |
| **Service Principal + Secret** | Legacy systems only | Client Secret |

> ⚠️ **For CI/CD pipelines, Microsoft recommends OpenID Connect (OIDC)** over client secrets. OIDC uses short-lived tokens with no stored secrets. See [Automation-Pipeline-Examples/](Automation-Pipeline-Examples/) for setup instructions.

**Interactive Login (for manual use):**
```powershell
# Login to Azure (add --tenant <TenantId> if you have multiple tenants)
az login

# Optionally, set the subscription context
az account set --subscription "Your-Subscription-Name-or-Id"
```

**Managed Identity Login (for Azure VMs/containers):**
```powershell
# Import module and authenticate with Managed Identity
Import-Module .\AzLocal.UpdateManagement.psd1
Connect-AzureLocalServicePrincipal -UseManagedIdentity

# For user-assigned managed identity, specify the client ID
Connect-AzureLocalServicePrincipal -UseManagedIdentity -ManagedIdentityClientId "your-client-id"
```

**OpenID Connect (OIDC) for CI/CD:**
```yaml
# In GitHub Actions - OIDC authentication (no secrets!)
- name: Azure CLI Login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

> See [Automation-Pipeline-Examples/README.md](Automation-Pipeline-Examples/README.md) for complete OIDC setup instructions.

**Service Principal + Secret (Legacy - not recommended):**
```powershell
# Using environment variables
$env:AZURE_CLIENT_ID = 'your-app-id'
$env:AZURE_CLIENT_SECRET = 'your-secret'  # Secrets can be leaked/expire
$env:AZURE_TENANT_ID = 'your-tenant-id'

# Import module and authenticate
Import-Module .\AzLocal.UpdateManagement.psd1
Connect-AzureLocalServicePrincipal
```

### 2. Install or Import the Module

**Option A: Install from PowerShell Gallery (Recommended)**
```powershell
# Install from PowerShell Gallery
Install-Module -Name AzLocal.UpdateManagement -Scope CurrentUser

# Import the module
Import-Module AzLocal.UpdateManagement
```

**Option B: Import from Local Clone**
```powershell
# Import the module from the current directory
Import-Module .\AzLocal.UpdateManagement.psd1

# Or import using the full path
Import-Module "C:\Path\To\AzLocal.UpdateManagement\AzLocal.UpdateManagement.psd1"
```

**Optional: copy the CI/CD pipeline samples out of the module install folder**

The module ships a working set of pipeline YAML files plus a step-by-step setup README under `Automation-Pipeline-Examples/`. They live inside the module install path (typically under `C:\Program Files\WindowsPowerShell\Modules\AzLocal.UpdateManagement\<version>\`), so the easiest way to start using them is to copy them somewhere you control:

```powershell
# Copy everything (GitHub + Azure DevOps + ITSM samples + README) to the current folder
Copy-AzureLocalPipelineExample

# Or only the GitHub Actions YAML, into a target folder of your choice
Copy-AzureLocalPipelineExample -Destination C:\repos\my-fleet -Platform GitHub
```

The function prints a short "next steps" summary pointing at the copied README and the platform-specific YAML folder. See [`Automation-Pipeline-Examples/README.md`](Automation-Pipeline-Examples/README.md) for the full step-by-step setup guide.

### 3. Start an Update on a Single Cluster

```powershell
# Start update on a single cluster (will prompt for confirmation)
Start-AzureLocalClusterUpdate -ClusterNames "MyCluster01" -ResourceGroupName "MyRG"

# Start update without prompting (use with caution)
Start-AzureLocalClusterUpdate -ClusterNames "MyCluster01" -ResourceGroupName "MyRG" -Force
```

### 4. Start Updates on Multiple Clusters

```powershell
# Update multiple clusters in the same resource group
Start-AzureLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02", "Cluster03") -ResourceGroupName "MyRG"

# Update clusters (function will search across all resource groups)
Start-AzureLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02")
```

### 5. Start a Specific Update

```powershell
# Apply a specific update version
Start-AzureLocalClusterUpdate -ClusterNames "MyCluster01" -UpdateName "Solution12.2601.1002.38"
```

### 6. Check Update Progress

```powershell
# Get update run status
Get-AzureLocalUpdateRuns -ClusterName "MyCluster01" -ResourceGroupName "MyRG"
```

### 7. Set Up Update Management Tags for Staged Rollouts

Three Azure resource tags control how clusters are grouped and when updates are applied:

| Tag | Purpose | Required? | Set By |
|-----|---------|-----------|--------|
| `UpdateRing` | Groups clusters into deployment waves (e.g., Pilot, Wave1, Production) | **Yes** - needed for `-ScopeByUpdateRingTag` | `Set-AzureLocalClusterUpdateRingTag` or CSV import |
| `UpdateWindow` | Defines allowed maintenance windows in UTC (e.g., `Sat-Sun_02:00-06:00`) | Optional | CSV import via `Set-AzureLocalClusterUpdateRingTag` |
| `UpdateExclusions` | Defines blackout/change-freeze periods (e.g., `2026-12-20/2027-01-03`) | Optional | CSV import via `Set-AzureLocalClusterUpdateRingTag` |
| `UpdateSideloaded` | Sideloaded-payload gate. Values `True`/`False`/`1`/`0` (case-insensitive). When `False`, `Start-AzureLocalClusterUpdate` skips the cluster with `Status = SideloadedBlocked`. Operator-set. | Optional (only used by the sideloaded-payload workflow) | Operator (Azure portal, CLI, or your tagging pipeline). Auto-reset to `False` by `Get-AzureLocalUpdateRuns` / `Reset-AzureLocalSideloadedTag` after the staged update succeeds. |
| `UpdateVersionInProgress` | Module-managed companion to `UpdateSideloaded`. Holds the staged update name (e.g. `Solution12.2604.1003.209`). | **Do not set manually.** | Module: written by `Start-AzureLocalClusterUpdate` at update start; cleared by `Get-AzureLocalUpdateRuns` / `Reset-AzureLocalSideloadedTag` once the matching run succeeds. |

> ℹ️ **Tag matching is case-insensitive throughout this module.** Tag *names* (`UpdateRing`, `UpdateWindow`, `UpdateExclusions`) and tag *values* (the ring name like `Prod1`, day tokens like `Mon`, the `Daily` keyword) are all compared without regard to case. So `prod1`, `Prod1`, and `PROD1` resolve to the same set of clusters via `-ScopeByUpdateRingTag -UpdateRingValue 'Prod1'` (Azure Resource Graph `=~` operator), and `Mon-Fri`, `mon-fri`, and `MON-FRI` parse to the same maintenance window. This applies to every function that scopes clusters by tag, every CSV import path, and the `UpdateWindow` / `UpdateExclusions` parsers. Note: the day tokens themselves still require the strict 3-letter form — `Mon Tue Wed Thu Fri Sat Sun` — case doesn't matter, but `Thur` / `Tues` / `Friday` will be rejected (see the `UpdateWindow` section below for the full table).

> **What happens if you only set `UpdateRing`?** Updates proceed immediately with **no schedule restrictions**. The `UpdateWindow` and `UpdateExclusions` tags are entirely optional - if neither is present on a cluster, the schedule check returns "No schedule restrictions defined" and the update starts as soon as the pipeline runs. Add `UpdateWindow` and `UpdateExclusions` tags when you need to control *when* updates can be applied.

**Step 1: Inventory clusters and export to CSV**
```powershell
# Get all clusters with their current tags, export to CSV
Get-AzureLocalClusterInventory -ExportPath "C:\Temp\cluster-inventory.csv"
```

The CSV includes columns for all three tags: `UpdateRing`, `UpdateWindow`, and `UpdateExclusions`.

**Step 2: Edit the CSV in Excel**

Open `cluster-inventory.csv` and populate the tag columns:

| ClusterName | UpdateRing | UpdateWindow | UpdateExclusions |
|-------------|------------|--------------|------------------|
| HCI-Pilot01 | Pilot | | |
| HCI-Pilot02 | Pilot | | |
| HCI-Prod01  | Wave1 | Sat-Sun_02:00-06:00 | 20**-12-20/20**-01-03 |
| HCI-Prod02  | Wave1 | Sat-Sun_02:00-06:00 | 20**-12-20/20**-01-03 |
| HCI-Critical| Production | Sat_02:00-06:00 | 20**-12-20/20**-01-03 |

- **UpdateRing** (required): The deployment wave for this cluster
- **UpdateWindow** (optional): UTC maintenance window. Format: `<days>_<HH:MM>-<HH:MM>`. Multiple windows separated by `;`.

  > ⏱️ **Important - `UpdateWindow` controls when an update is allowed to *START*, not how long it takes to complete.** The window is a **start gate** evaluated by `Test-AzureLocalUpdateScheduleAllowed` at the moment `Start-AzureLocalClusterUpdate` runs. Once the update has started, it runs to completion (or failure) regardless of whether the window is still open - Azure Local update runs are **not** paused, throttled, or aborted when the window closes. A typical Azure Local platform update can take **several hours** on a multi-node cluster (node drains, reboots, firmware/driver/SBE steps, validation), and a "happy path" run with no issues is still measured in hours, not minutes.
  >
  > **Plan your window to *start* far enough before any hard deadline that the full update can finish before that deadline** - for example, if updates must be complete before a retail store opens at 06:00 local time, or before a manufacturing line starts at 06:00 Mon-Fri, do **not** set `UpdateWindow` to (say) `Mon-Fri_04:00-06:00` and expect the update to be done by 06:00. Set it to start much earlier (e.g. `Sun-Thu_22:00-02:00` for an overnight start the evening before) so the run has enough headroom for the slowest realistic completion time, plus margin for retries and post-update validation. When in doubt, time a representative update on a non-production cluster first and add a safety buffer.


  **Day tokens** — strict 3-letter abbreviations only (case-insensitive — `Mon`, `mon`, `MON` all work):

  | Token | Day | Token | Day |
  |---|---|---|---|
  | `Mon` | Monday | `Fri` | Friday |
  | `Tue` | Tuesday | `Sat` | Saturday |
  | `Wed` | Wednesday | `Sun` | Sunday |
  | `Thu` | Thursday | `Daily` / `*` | All days |

  **Day specifiers**:
  - **Range**: `Mon-Fri` (Mon through Fri inclusive), `Sat-Sun`, `Fri-Mon` (wrap-around — Fri, Sat, Sun, Mon)
  - **Comma list**: `Mon,Wed,Fri` (Monday, Wednesday, Friday only — useful for non-contiguous days)
  - **Single day**: `Sat`
  - **All days**: `Daily` or `*`

  > ⚠️ Common mistakes: `Thur`, `Tues`, `Mond`, `Friday`, `tuesday-friday` — all rejected. Use the strict 3-letter form: `Thu`, `Tue`, `Mon`, `Fri`, `Tue-Fri`.

  **Time format**: 24-hour `HH:MM` UTC. Overnight wraps are supported (`22:00-02:00` means 10 PM today through 2 AM tomorrow).

  **Examples**:
  - `Sat-Sun_02:00-06:00` — Weekends 2-6 AM UTC
  - `Mon-Fri_22:00-06:00` — Weeknights 10 PM - 6 AM UTC (overnight wrap)
  - `Mon-Thu_20:00-04:00` — Mon/Tue/Wed/Thu nights 8 PM - 4 AM UTC (excludes Fri night)
  - `Mon,Wed,Fri_01:00-05:00` — Only Mon/Wed/Fri 1-5 AM UTC (note the **comma list**, not range)
  - `Sat_22:00-06:00;Sun_22:00-06:00` — Two separate Sat-night and Sun-night windows
  - `Sat-Sun_00:00-23:59` — Whole weekend
  - `Daily_02:00-06:00` (or `*_02:00-06:00`) — Every day 2-6 AM UTC
  - `Fri-Mon_22:00-06:00` — Long weekend (Fri/Sat/Sun/Mon nights, with wrap)

  > **Tag-value matching is case-insensitive everywhere** — both the day tokens above and the `UpdateRing` value used by `-ScopeByUpdateRingTag -UpdateRingValue 'Prod1'` (resolved via Azure Resource Graph `=~` operator), so `prod1`/`Prod1`/`PROD1` all match the same set of clusters.
- **UpdateExclusions** (optional): Change-freeze periods. Format: `YYYY-MM-DD/YYYY-MM-DD`. Multiple ranges separated by `,`. Wildcards with `*` for recurring annual patterns. Examples:
  - `2026-12-20/2027-01-03` — Specific date range
  - `20**-12-20/20**-01-03` — Every year, Dec 20 to Jan 3

Save the file.

**Step 3: Apply all tags from CSV**
```powershell
# Apply UpdateRing, UpdateWindow, and UpdateExclusions tags from the edited CSV
Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\cluster-inventory.csv"

# Preview changes first with -WhatIf
Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\cluster-inventory.csv" -WhatIf

# Force overwrite existing tags
Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\cluster-inventory.csv" -Force
```

The function reads `UpdateWindow` and `UpdateExclusions` columns from the CSV (if present) and sets them alongside the `UpdateRing` tag in a single PATCH operation. Existing tags on the cluster are preserved.

**Step 4: Verify tags were applied**
```powershell
# Re-run inventory to confirm all tags
Get-AzureLocalClusterInventory
```

**Step 5: Test schedule logic interactively (optional)**
```powershell
# Test if a specific time would be allowed by a maintenance window
Test-AzureLocalUpdateScheduleAllowed -UpdateWindow "Sat-Sun_02:00-06:00" -UpdateExclusions "2026-12-20/2027-01-03"

# Test a specific future time
Test-AzureLocalUpdateScheduleAllowed -UpdateWindow "Sat_02:00-06:00" -TestTime ([datetime]"2026-04-19 03:00:00")
```

**Step 6: Update clusters by UpdateRing**
```powershell
# Update all clusters in the "Pilot" ring first
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Pilot" -Force

# After validation, update Wave1
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force

# Finally, update Production
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Production" -Force
```

> 📝 **Note**: Tag operations require `Microsoft.Resources/tags/read` and `Microsoft.Resources/tags/write` permissions. Cluster inventory queries require `Microsoft.ResourceGraph/resources/read`. See [RBAC Requirements](#rbac-requirements) for the complete list. The v0.7.1 sideloaded-payload workflow (`UpdateSideloaded` / `UpdateVersionInProgress`) reads and writes through the same two tag permissions - **no new RBAC required**.

### 7a. Sideloaded Payload Workflow (v0.7.1)

Use this workflow when an admin manually copies an Azure Local update payload onto a cluster (sideloading) and wants the module to gate `Start-AzureLocalClusterUpdate` until the payload is in place, then automatically clear the gate once the run succeeds.

> ✅ **Fully opt-in.** Clusters that do not have the `UpdateSideloaded` tag behave exactly as in v0.7.0 - the gate is bypassed entirely and updates proceed through the existing schedule/health checks. You only "join" the workflow by setting the tag on a specific cluster when you want to stage a sideloaded payload. No new RBAC, no fleet-wide opt-out switch needed.

**Two tags coordinate the workflow:**

| Tag | Set by | Values | Purpose |
|-----|--------|--------|---------|
| `UpdateSideloaded` | **Operator** (you) | `True` / `False` / `1` / `0` (case-insensitive) | When `False`/`0`, `Start-AzureLocalClusterUpdate` skips the cluster with `Status = SideloadedBlocked`. When `True`/`1`, updates proceed normally. Empty/missing tag = no sideloaded gate (legacy behaviour). |
| `UpdateVersionInProgress` | **Module** (do not set manually) | The update name (e.g. `Solution12.2604.1003.209`) | Written automatically when an update kicks off. Cleared automatically once the matching run succeeds. Used to ensure auto-reset only fires for the run we actually started. |

**Typical flow (per cluster):**

1. **Stage**: Operator sets `UpdateSideloaded = False` on a target cluster, then sideloads the payload onto the cluster's nodes out-of-band. See [Import and discover Azure Local updates in offline / disconnected scenarios](https://learn.microsoft.com/en-us/azure/azure-local/update/import-discover-updates-offline-23h) for information and download links required to sideload updates.

   Set the gate tag on a cluster using the Az PowerShell module. `-Operation Merge` preserves all other tags already on the cluster (e.g. `UpdateRing`) and only adds/updates the `UpdateSideloaded` key:

   ```powershell
   $clusterId = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.AzureStackHCI/clusters/<cluster-name>'
   Update-AzTag -ResourceId $clusterId -Tag @{ UpdateSideloaded = 'False' } -Operation Merge
   ```

2. **Block while not ready**: Any pipeline run of `Start-AzureLocalClusterUpdate` against this cluster sees `UpdateSideloaded = False` and skips with `Status = SideloadedBlocked` (visible in CSV log, JUnit XML, and HTML report skipped tally). The schedule and health gates are not even consulted.
3. **Release**: Operator confirms the payload is in place and flips `UpdateSideloaded = True`:

   ```powershell
   Update-AzTag -ResourceId $clusterId -Tag @{ UpdateSideloaded = 'True' } -Operation Merge
   ```
4. **Update**: Next pipeline run sees `True`, proceeds through schedule/health gates, and starts the update. As the run kicks off, the module writes `UpdateVersionInProgress = <update name>` to the cluster.
5. **Auto-reset**: When `Get-AzureLocalUpdateRuns` next reads runs for this cluster, it inspects the latest run. If it is `Succeeded` **and** its update name matches `UpdateVersionInProgress`, it flips `UpdateSideloaded` back to `False` and clears `UpdateVersionInProgress` in a single PATCH. The cluster is now re-armed for the next sideloaded payload.

**Auto-reset action values** (returned by `Reset-AzureLocalSideloadedTag` and surfaced in `Get-AzureLocalUpdateRuns` verbose logs):

| Action | Meaning |
|--------|---------|
| `Reset` | Match success path - both tags flipped/cleared in a single PATCH. |
| `OrphanCleared` | `UpdateSideloaded` absent (cluster opted out) but a stale `UpdateVersionInProgress` tag matched the latest succeeded run name - the orphan tag was cleared. `UpdateSideloaded` is **never** written in this path. |
| `NoTag` | `UpdateSideloaded` tag is absent and there is nothing to clean up. Cluster is fully outside the workflow. |
| `NoRuns` | `UpdateSideloaded=True` but the cluster has no update-run history yet. Tag preserved. |
| `RunNotSucceeded` | Latest run is `InProgress` / `Failed`. Tag preserved (will be re-evaluated next run). |
| `Skipped` | `UpdateSideloaded=False` already, malformed tag value, version mismatch, or PATCH failure. Reason in the `Message` field. |

**Manual reset (escape hatch):**

```powershell
# Inspect (no changes) - relies on the default match-and-only-if-Succeeded gate
Reset-AzureLocalSideloadedTag -ClusterName 'mycluster' -ResourceGroupName 'rg-fleet' -WhatIf

# Force-reset a stuck cluster (skips the run-success / version-match check). Use with care.
Reset-AzureLocalSideloadedTag -ClusterName 'mycluster' -ResourceGroupName 'rg-fleet' -Force

# Bulk reset by tag (explicit scope - no implicit -AllClusters)
Reset-AzureLocalSideloadedTag -ScopeByUpdateRingTag -UpdateRingValue 'Wave1'
```

`Reset-AzureLocalSideloadedTag` is the same logic the auto-reset path uses; the difference is the entry point. Default behaviour requires `latest run = Succeeded` and a case-insensitive match between the run's update name and `UpdateVersionInProgress`. `-Force` bypasses both checks.

**Opt out of auto-reset:**

```powershell
# Read-only paths can suppress the PATCH
Get-AzureLocalUpdateRuns -ClusterName 'mycluster' -ResourceGroupName 'rg-fleet' -SkipSideloadedReset
```

> ℹ️ **Concurrent updates**: Azure Local's on-cluster ECE component already serialises updates - it will refuse to start a second run while another is in flight or in a failed state. The match-on-update-name guardrail in this workflow is a defense-in-depth check on top of that, not a replacement for it.

> 🔐 **RBAC**: Unchanged. The workflow only reads and writes cluster tags, which already require `Microsoft.Resources/tags/read` and `Microsoft.Resources/tags/write` (see [RBAC Requirements](#rbac-requirements)).

### 8. Assess Readiness and Health BEFORE Applying Updates (Recommended)

Before rolling updates to a wave, confirm every cluster in that wave is actually ready - on the supported solution version, healthy, with an update in a `Ready` / `ReadyToInstall` state, and not blocked by an SBE prerequisite. `Start-AzureLocalClusterUpdate` will already skip unhealthy clusters automatically, but running the assessment as a separate **readiness report** surfaces exactly what needs remediation so you can open tickets in parallel with the rollout - you do not need to block the entire wave for one or two unhealthy clusters.

**Step 1: Run the readiness check for the target ring**

```powershell
# Returns one row per cluster with: ReadyForUpdate, HealthState, UpdateState,
# HasPrerequisiteUpdates, SBEDependency, UpdateWindow, UpdateExclusions
$readiness = Get-AzureLocalClusterUpdateReadiness `
    -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' `
    -ExportPath 'C:\Reports\wave1-readiness.csv' -PassThru

# Quick triage
$readiness | Group-Object ReadyForUpdate | Select-Object Name, Count
$readiness | Where-Object { -not $_.ReadyForUpdate } |
    Select-Object ClusterName, HealthState, UpdateState, HasPrerequisiteUpdates, SBEDependency
```

**Step 2: Drill into the Critical health failures that will block updates**

```powershell
# -BlockingOnly returns only Critical/update-blocking failures, suitable for CI/CD reporting
$health = Test-AzureLocalClusterHealth `
    -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' `
    -BlockingOnly `
    -ExportPath 'C:\Reports\wave1-health.csv' `
    -ExportFormat Csv `
    -PassThru

$health | Where-Object Severity -eq 'Critical' |
    Select-Object ClusterName, Title, Description, Remediation
```

**Step 3: Remediate Critical issues (outside this module's scope)**

Critical health failures must be fixed at the cluster / infrastructure layer - this module only *detects* them. Typical failure classes and where to remediate them:

| Failure class | Where to fix |
|---------------|--------------|
| Storage / drive / stamp health, ADDS/DC connectivity | Microsoft Learn: [Azure Local solution upgrades](https://learn.microsoft.com/en-us/azure-local/manage/update) and the cluster's own Windows Admin Center / Environment Checker output |
| SBE (Solution Builder Extension) / firmware / driver prerequisite | Your **hardware vendor's** SBE package (Dell APEX, HPE, Lenovo, DataON, etc.). `SBEDependency` / `HasPrerequisiteUpdates` identify the publisher + family + release notes URL. |
| Certificate, trust, or identity drift | Azure Local operations runbook for certificate rotation |
| Workload / VM / cluster resource state | Windows Admin Center "Update" workload + cluster validation; evacuate affected nodes first |

After remediation, re-run Step 1 and Step 2 to confirm `ReadyForUpdate = $true` and `Critical = 0` for the clusters you've fixed. Clusters that are still red can stay in the ring - `Start-AzureLocalClusterUpdate` will skip them - but track them as follow-ups so the fleet converges over time.

**Step 4: Only now, apply updates**

```powershell
# Updates only start if the maintenance window / exclusion tags allow it.
# Start-AzureLocalClusterUpdate will *still* re-check health per cluster and
# skip anything that has regressed since the assessment.
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' -Force
```

**Step 5: Watch progress and capture a report**

```powershell
# Follow the run (PS 5.1 and Core safe)
Get-AzureLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue 'Wave1'

# Produce a self-contained HTML report for stakeholders (works for any scope)
New-AzureLocalFleetStatusHtmlReport `
    -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' `
    -OutputPath 'C:\Reports\wave1-status.html' `
    -IncludeHealthDetails -IncludeUpdateRuns
```

> 💡 **CI/CD**: this same assess -> remediate -> apply flow is wired into the pipeline examples under `Automation-Pipeline-Examples/`: see the `assess-update-readiness.yml` pipeline (report-only) and the `check-readiness` job inside `apply-updates.yml`.

## Available Functions

### `Copy-AzureLocalPipelineExample`

Copies the bundled `Automation-Pipeline-Examples/` folder (GitHub Actions YAML, Azure DevOps Pipelines YAML, ITSM sample config + ticket-body template, plus the step-by-step setup README) out of the module install location into a destination folder you control. The function is read-only relative to the module install and only destructive relative to the destination (and only when `-Force` is supplied and the target is already populated).

**Parameters:**

- `-Destination` (Optional, Position 0): Target folder. If missing, it is created. Default is `$PWD`.
- `-Platform` (Optional): `All` (default), `GitHub`, or `AzureDevOps`. Filters which `*-actions/` / `*-devops/` subfolders are copied. The top-level `README.md` and `.itsm/` sample folder are platform-agnostic and always copied.
- `-Flatten` (Optional Switch): Copy contents directly into `-Destination` (no `Automation-Pipeline-Examples` parent folder).
- `-Force` (Optional Switch): Required if the destination already contains pipeline files; overwrites them.
- `-PassThru` (Optional Switch): Return the destination `[DirectoryInfo]`.
- Supports `-WhatIf` and `-Confirm`.

**Returns:** `[System.IO.DirectoryInfo]` when `-PassThru` is specified. Nothing otherwise. Always prints a short "next steps" summary to the console.

**Examples:**

```powershell
# Default: copies into .\Automation-Pipeline-Examples\ under the current directory
Copy-AzureLocalPipelineExample

# Only the GitHub Actions YAML, into a target folder of your choice
Copy-AzureLocalPipelineExample -Destination C:\repos\my-fleet -Platform GitHub

# Drop the GitHub Actions YAML directly into .github\workflows (no parent folder), overwriting
New-Item -ItemType Directory .\.github\workflows -Force | Out-Null
Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub -Flatten -Force

# Capture the destination and cd into it
$dest = Copy-AzureLocalPipelineExample -Destination C:\repos\fleet -PassThru
Set-Location $dest
```

---

### `Connect-AzureLocalServicePrincipal`

Authenticates to Azure using a Service Principal or Managed Identity (MSI) for CI/CD automation scenarios.

**Authentication Methods:**
1. **Managed Identity** (`-UseManagedIdentity`): For Azure-hosted runners, VMs, or containers with an assigned identity
2. **Service Principal** (default): Using credentials from parameters or environment variables

**Parameters:**
- `-UseManagedIdentity` (Optional): Use Managed Identity authentication instead of Service Principal
- `-ManagedIdentityClientId` (Optional): Client ID of a user-assigned managed identity. If not specified, system-assigned identity is used.
- `-ServicePrincipalId` (Optional): Application (client) ID. Can also use `AZURE_CLIENT_ID` environment variable.
- `-ServicePrincipalSecret` (Optional): Client secret as `[SecureString]` (preferred) or `[string]`. Can also use `AZURE_CLIENT_SECRET` environment variable. A security warning is logged when a plaintext `[string]` is passed because command-line arguments may be visible to other users/EDR on the host.
- `-TenantId` (Optional): Azure AD tenant ID. Can also use `AZURE_TENANT_ID` environment variable.
- `-Force` (Optional): Force re-authentication even if already logged in.

**Returns:** `$true` if authentication succeeded, `$false` otherwise.

**Examples:**

```powershell
# Using Managed Identity (recommended for Azure-hosted agents/runners)
Connect-AzureLocalServicePrincipal -UseManagedIdentity

# Using user-assigned Managed Identity with specific client ID
Connect-AzureLocalServicePrincipal -UseManagedIdentity -ManagedIdentityClientId "12345678-1234-1234-1234-123456789012"

# Using environment variables for Service Principal (recommended for CI/CD)
$env:AZURE_CLIENT_ID = 'your-app-id'
$env:AZURE_CLIENT_SECRET = 'your-secret'
$env:AZURE_TENANT_ID = 'your-tenant-id'
Connect-AzureLocalServicePrincipal

# Using a SecureString for the secret (preferred when passing via parameter)
$secret = Read-Host -AsSecureString -Prompt 'Service Principal Secret'
Connect-AzureLocalServicePrincipal -ServicePrincipalId $appId -ServicePrincipalSecret $secret -TenantId $tenant

# Plaintext [string] still works but logs a security warning - prefer SecureString or env var
Connect-AzureLocalServicePrincipal -ServicePrincipalId $appId -ServicePrincipalSecret $secret -TenantId $tenant
```

---

### `Start-AzureLocalClusterUpdate`

Main function to start updates on one or more Azure Local clusters.

**Parameters:**
- `-ClusterNames` (Required*): Array of cluster names to update. Use this OR `-ClusterResourceIds` OR `-ScopeByUpdateRingTag`.
- `-ClusterResourceIds` (Required*): Array of full Azure Resource IDs for clusters. Use this when clusters are in different resource groups or subscriptions. Resource IDs are validated before processing: the subscription is verified via `az account set`, and the resource is confirmed to exist with the required permissions. Use this OR `-ClusterNames` OR `-ScopeByUpdateRingTag`.
- `-ScopeByUpdateRingTag` (Required*): Switch parameter to find clusters by their 'UpdateRing' tag value via Azure Resource Graph. Must be used with `-UpdateRingValue`. Use this OR `-ClusterNames` OR `-ClusterResourceIds`.
- `-UpdateRingValue` (Required*): The value of the 'UpdateRing' tag to match when using `-ScopeByUpdateRingTag`.
- `-ResourceGroupName` (Optional): Resource group containing the clusters (only used with `-ClusterNames`)
- `-SubscriptionId` (Optional): Azure subscription ID (defaults to current, only used with `-ClusterNames`)
- `-UpdateName` (Optional): Specific update name to apply (e.g., `Solution12.2603.1002.15`). If not specified, the latest cumulative update is auto-selected by YYMM version from the update name
- `-ApiVersion` (Optional): API version (default: "2025-10-01")
- `-Force` (Optional): Skip confirmation prompts
- `-WhatIf` (Optional): Show what would happen without executing
- `-LogFolderPath` (Optional): Folder path for log files. Default: `C:\ProgramData\AzLocal.UpdateManagement\`
- `-EnableTranscript` (Optional): Enable PowerShell transcript recording
- `-ExportResultsPath` (Optional): Export results to JSON (`.json`), CSV (`.csv`), or JUnit XML (`.xml`) file

**Examples using Resource IDs:**

```powershell
# Update clusters in different resource groups using Resource IDs
$resourceIds = @(
    "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01",
    "/subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02"
)
Start-AzureLocalClusterUpdate -ClusterResourceIds $resourceIds -Force
```

**Examples using Tags (Azure Resource Graph):**

```powershell
# Update all clusters tagged with "UpdateRing" = "Wave1" (across all subscriptions)
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force

# Update all production clusters
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Production" -Force

# Update clusters with specific UpdateRing and update version
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Pilot" -UpdateName "Solution12.2601.1002.38" -Force
```

> **Prerequisites for Tag-based Filtering:**
> 
> 1. **Azure CLI `resource-graph` extension** (required for `-ScopeByUpdateRingTag`):
>    The module **automatically installs** this extension if it's missing (using `az extension add --name resource-graph --yes`). This enables fully automated pipeline scenarios without manual intervention.
>
> 2. **Set up UpdateRing tags on your clusters** (if you haven't already):
>    If you want to use `-ScopeByUpdateRingTag` but your clusters don't have `UpdateRing` tags yet, use the [`Get-AzureLocalClusterInventory`](#get-azurelocalclusterinventory) and [`Set-AzureLocalClusterUpdateRingTag`](#set-azurelocalclusterupdateringtag) functions:
>    ```powershell
>    # Option 1: Export inventory to CSV, edit in Excel, then import
>    Get-AzureLocalClusterInventory -ExportPath "C:\Temp\ClusterInventory.csv"
>    # Edit the CSV in Excel to populate UpdateRing values, then:
>    Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv"
>    
>    # Option 2: Set tags directly using Resource IDs
>    $ring1Clusters = @(
>        "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01",
>        "/subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02"
>    )
>    Set-AzureLocalClusterUpdateRingTag -ClusterResourceIds $ring1Clusters -UpdateRingValue "Wave1"
>    
>    # Then, update all Wave1 clusters
>    Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force
>    ```

### `Get-AzureLocalClusterUpdateReadiness`

Assesses update readiness across Azure Local clusters and provides a summary report. This is a "pre-flight check" to help plan update deployments.

**Features:**
- Shows which clusters are in "Ready" state for updates
- Lists available and ready-to-install updates for each cluster
- Displays health check state and failures for each cluster
- Provides summary statistics with cluster counts per update version
- Identifies the most common applicable update across your fleet
- Shows clusters with health check issues and their failure reasons
- Exports results to CSV for reporting (includes all diagnostic columns)

**Parameters:**
- `-ClusterNames`, `-ClusterResourceIds`, or `-ScopeByUpdateRingTag`/`-UpdateRingValue` (same as `Start-AzureLocalClusterUpdate`)
- `-ExportPath` (Optional): Export results to a CSV file

**Output Columns (and CSV Export):**
| Column | Description |
|--------|-------------|
| `ClusterName` | Name of the Azure Local cluster |
| `ResourceGroup` | Resource group containing the cluster |
| `SubscriptionId` | Azure subscription ID |
| `ClusterState` | Cluster connection state (e.g., "ConnectedRecently") |
| `UpdateState` | Current update state (e.g., "UpdateAvailable", "NeedsAttention") |
| `HealthState` | Health check state: "Success", "Warning", "Failure", or "InProgress" |
| `ReadyForUpdate` | Boolean indicating if the cluster is ready for updates |
| `AvailableUpdates` | List of available update names |
| `ReadyUpdates` | List of updates in "Ready" state |
| `RecommendedUpdate` | The recommended (latest) ready update |
| `HealthCheckFailures` | Summary of failed health checks with severity |

**Examples:**

```powershell
# Assess all clusters with a specific UpdateRing tag value
Get-AzureLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Wave1"

# Assess specific clusters and export to CSV
Get-AzureLocalClusterUpdateReadiness -ClusterNames @("Cluster01", "Cluster02") -ExportPath "C:\Reports\readiness.csv"

# Assess clusters by UpdateRing tag across all subscriptions
Get-AzureLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Production"
```

**Sample Output:**

```
========================================
Azure Local Cluster Update Readiness Assessment
========================================

Assessing 5 cluster(s)...

  Checking: Cluster01... Ready (Solution12.2601.1002.38)
  Checking: Cluster02... Ready (Solution12.2601.1002.38)
  Checking: Cluster03... Update In Progress
  Checking: Cluster04... NeedsAttention (Failure)
  Checking: Cluster05... Ready (Solution12.2601.1002.38)

========================================
Summary
========================================

Total Clusters Assessed:    5
Ready for Update:           3
Not Ready / Other State:    2
Update In Progress:         1

Health Check Issues:
  Critical Failures:        1
  Warnings:                 0

Available Update Versions (clusters ready to install):
  Solution12.2601.1002.38: 3 cluster(s) (100%)

Most Common Applicable Update: Solution12.2601.1002.38

Detailed Results:

ClusterName   ResourceGroup  UpdateState       HealthState  ReadyForUpdate  RecommendedUpdate
-----------   -------------  -----------       -----------  --------------  -----------------
Cluster01     RG-West        UpdateAvailable   Success      True            Solution12.2601.1002.38
Cluster02     RG-West        UpdateAvailable   Success      True            Solution12.2601.1002.38
Cluster03     RG-East        UpdateInProgress  Success      False
Cluster04     RG-East        NeedsAttention    Failure      False
Cluster05     RG-North       UpdateAvailable   Success      True            Solution12.2601.1002.38

Clusters with Health Check Issues:
  Cluster04: [Critical] Test-CauSetup; [Warning] Test-ClusterQuorum
```

### `Get-AzureLocalClusterInfo`

Gets cluster information by name.

```powershell
$cluster = Get-AzureLocalClusterInfo -ClusterName "MyCluster" -SubscriptionId "xxx"
```

### `Get-AzureLocalUpdateSummary`

Gets the update summary for a cluster.

```powershell
$summary = Get-AzureLocalUpdateSummary -ClusterResourceId $cluster.id
Write-Host "Update State: $($summary.properties.state)"
```

### `Get-AzureLocalAvailableUpdates`

Lists all available updates for a cluster with enriched state information including SBE dependency details.

```powershell
# Get enriched update objects (default) - includes PackageType, SBEDependency, UpdateState
$updates = Get-AzureLocalAvailableUpdates -ClusterResourceId $cluster.id
$updates | Where-Object { $_.UpdateState -eq "Ready" }

# Get raw ARM API objects for programmatic processing
$raw = Get-AzureLocalAvailableUpdates -ClusterResourceId $cluster.id -Raw
$raw | Where-Object { $_.properties.state -eq "Ready" }
```

### `Get-AzureLocalUpdateRuns`

Gets update run history and status for one or more clusters. Returns formatted objects showing the update name, state, duration, step progress, and current/failed step.

**Parameters:**
- `-ClusterName` (Required*): Single cluster name (original behavior)
- `-ClusterNames`, `-ClusterResourceIds`, or `-ScopeByUpdateRingTag`/`-UpdateRingValue`: Multi-cluster mode
- `-ResourceGroupName` (Optional): Resource group (only with `-ClusterName`/`-ClusterNames`)
- `-UpdateName` (Optional): Filter runs for a specific update
- `-Latest` (Optional): Return only the most recent update run per cluster
- `-Raw` (Optional): Return raw API response objects instead of formatted output
- `-ExportPath` (Optional): Export results to CSV, JSON, or JUnit XML

**Output Properties:**
| Property | Description |
|----------|-------------|
| `UpdateName` | The update package name (e.g., `Solution12.2603.1002.500`) |
| `State` | Current state: `InProgress`, `Succeeded`, `Failed`, etc. |
| `StartTime` | When the update run started |
| `Duration` | How long the update took, human-readable (e.g., `2 hours 30 minutes`, `45 minutes (running)`) |
| `Progress` | Step completion (e.g., `3/5 steps`) |
| `CurrentStep` | Currently executing or failed step name |

**Examples:**

```powershell
# Get all update runs for a cluster
Get-AzureLocalUpdateRuns -ClusterName "MyCluster" -ResourceGroupName "MyRG"

# Get only the latest update run
Get-AzureLocalUpdateRuns -ClusterName "MyCluster" -Latest

# Get raw API response for programmatic processing
Get-AzureLocalUpdateRuns -ClusterName "MyCluster" -Raw

# Multi-cluster: Get latest run for all clusters in an update ring
Get-AzureLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Latest

# Export update run history to CSV
Get-AzureLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Production" -Latest -ExportPath "C:\Reports\runs.csv"
```

**Sample Output:**
```
UpdateName                State       StartTime        EndTime          Duration               Progress    CurrentStep
----------                -----       ---------        -------          --------               --------    -----------
Solution12.2603.1002.500  InProgress  2026-04-09 16:50                  1 hour 12 minutes      3/5 steps   DownloadSBE
Solution12.2602.1002.501  Succeeded   2026-03-15 09:00 2026-03-15 11:30 2 hours 30 minutes     5/5 steps
```

### `Test-AzureLocalClusterHealth`

Validates cluster health before applying updates by checking for blocking health check failures. Critical failures prevent updates from being applied.

**Parameters:**
- `-ClusterResourceIds`, `-ClusterNames`, or `-ScopeByUpdateRingTag`/`-UpdateRingValue`: Target clusters
- `-BlockingOnly` (Optional): Show only Critical severity failures (the ones that block updates)
- `-ExportPath` (Optional): Export results to CSV, JSON, or JUnit XML

**Examples:**

```powershell
# Check health for a single cluster
Test-AzureLocalClusterHealth -ClusterResourceIds @("/subscriptions/.../clusters/Seattle")

# Check only update-blocking issues for an update ring
Test-AzureLocalClusterHealth -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -BlockingOnly

# Export health results to CSV
Test-AzureLocalClusterHealth -ClusterNames @("Cluster01", "Cluster02") -ExportPath "C:\Reports\health.csv"
```

**Sample Output:**
```
========================================
Health Validation Summary
========================================
Total Clusters:  1
Passed:          0 (no critical failures)
Blocked:         1 (critical failures present)

Health Check Failures:

ClusterName  Severity  CheckName           Description
-----------  --------  ---------           -----------
Seattle      Critical  Test-CauSetup       CAU is not configured correctly
Seattle      Critical  Test-StoragePool    Storage pool health degraded

Remediation for Critical (Update-Blocking) Failures:
  Seattle - Test-CauSetup: Run Test-CauSetup on the cluster to validate CAU configuration
  Seattle - Test-StoragePool: Check storage pool health using Get-StoragePool

HEALTH VALIDATION FAILED - Critical health issues must be resolved before updates can proceed
```

> **Note**: `Start-AzureLocalClusterUpdate` automatically runs this check (Step 3b) before applying updates. If Critical failures are found, the cluster is skipped with detailed diagnostics.

---

### `Get-AzureLocalClusterInventory`

Gets an inventory of all Azure Local clusters with their UpdateRing tag status. This function supports both CSV and JSON export formats for different workflows.

**Features:**
- Queries all Azure Local clusters across all accessible subscriptions using Azure Resource Graph
- Shows the current UpdateRing tag value for each cluster (or indicates if tag doesn't exist)
- Retrieves subscription names for better readability
- Provides summary statistics showing UpdateRing distribution
- **CSV export**: For editing in Excel and re-importing with `Set-AzureLocalClusterUpdateRingTag`
- **JSON export**: For CI/CD pipelines, API integrations, dashboards, and CMDB systems

**Parameters:**
- `-SubscriptionId` (Optional): Limit query to a specific Azure subscription
- `-ExportPath` (Optional): Export inventory to CSV or JSON file. Format is auto-detected from file extension (`.csv` or `.json`)
- `-PassThru` (Optional): Return inventory objects even when exporting. Useful for CI/CD pipelines that need both the file artifact and objects for processing.

**Output Columns:**
| Column | Description |
|--------|-------------|
| `ClusterName` | Name of the Azure Local cluster |
| `ResourceGroup` | Resource group containing the cluster |
| `SubscriptionId` | Azure subscription ID |
| `SubscriptionName` | Human-readable subscription name |
| `UpdateRing` | Current UpdateRing tag value (empty if not set) |
| `HasUpdateRingTag` | "Yes" or "No" indicator |
| `ResourceId` | Full Azure Resource ID |

**CSV Workflow (for Excel editing):**

```powershell
# Step 1: Export inventory to CSV
Get-AzureLocalClusterInventory -ExportPath "C:\Temp\ClusterInventory.csv"

# Step 2: Open the CSV in Excel and populate the 'UpdateRing' column with values like:
#   - "Wave1", "Wave2", "Wave3" for wave-based deployments
#   - "Pilot", "Production" for environment-based rings
#   - "Ring1", "Ring2" for ring-based deployments

# Step 3: Import the CSV and apply tags
Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv"

# Step 4: Update clusters by their UpdateRing tag
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force
```

**JSON Export (for CI/CD and integrations):**

```powershell
# Export to JSON for API integrations, dashboards, or CMDB systems
Get-AzureLocalClusterInventory -ExportPath "C:\Reports\inventory.json"

# Export to JSON AND return objects for pipeline processing
$inventory = Get-AzureLocalClusterInventory -ExportPath "./artifacts/inventory.json" -PassThru
Write-Host "Total clusters: $($inventory.Count)"
```

**CI/CD Pipeline Example (export both formats):**

```powershell
# Export both CSV and JSON in CI/CD pipelines
# CSV: For human review and Excel editing workflow
Get-AzureLocalClusterInventory -ExportPath "./artifacts/inventory.csv"

# JSON: For dashboard integrations and programmatic processing
$inventory = Get-AzureLocalClusterInventory -ExportPath "./artifacts/inventory.json" -PassThru
$withoutTag = ($inventory | Where-Object { $_.HasUpdateRingTag -eq 'No' }).Count
Write-Host "Clusters needing UpdateRing tag: $withoutTag"
```

**Sample Output:**

```
========================================
Azure Local Cluster Inventory
========================================

Querying Azure Resource Graph for all Azure Local clusters...
  Querying across all accessible subscriptions
Found 5 Azure Local cluster(s)

Retrieving subscription details...

Inventory Summary:
  Total Clusters: 5
  Clusters with UpdateRing tag: 3
  Clusters without UpdateRing tag: 2

  UpdateRing Distribution:
    Wave1: 2 cluster(s)
    Wave2: 1 cluster(s)

Inventory exported to CSV: C:\Temp\ClusterInventory.csv

Next Steps (CSV export):
  1. Open the CSV in Excel
  2. Populate the 'UpdateRing' column with values (e.g., 'Wave1', 'Wave2', 'Pilot')
  3. Save the CSV file
  4. Run: Set-AzureLocalClusterUpdateRingTag -InputCsvPath 'C:\Temp\ClusterInventory.csv'
```

---

### `Set-AzureLocalClusterUpdateRingTag`

Sets or updates the "UpdateRing" tag on Azure Local clusters for organizing update deployment waves.

**Features:**
- **NEW**: Accepts CSV file input for bulk tag operations (`-InputCsvPath`)
- Validates that Resource IDs are valid `microsoft.azurestackhci/clusters` resources
- Checks if clusters already have an "UpdateRing" tag before applying
- Warns and skips clusters with existing tags unless `-Force` is specified
- Logs previous tag values when updating with `-Force`
- Outputs results to a timestamped CSV log file

**Parameters:**
- `-InputCsvPath` (Required*): Path to CSV file with ResourceId and UpdateRing columns. Use with output from `Get-AzureLocalClusterInventory`.
- `-ClusterResourceIds` (Required*): Array of full Azure Resource IDs for clusters to tag. Use this OR `-InputCsvPath`.
- `-UpdateRingValue` (Required*): Value to assign to the "UpdateRing" tag (required when using `-ClusterResourceIds`)
- `-Force` (Optional): Overwrite existing "UpdateRing" tags (logs previous value)
- `-LogFolderPath` (Optional): Folder path for log files. Default: `C:\ProgramData\AzLocal.UpdateManagement\`
- `-WhatIf` (Optional): Preview changes without applying

**Output Columns (CSV Log: `UpdateRingTag_YYYYMMDD_HHmmss.csv`):**
| Column | Description |
|--------|-------------|
| `ClusterName` | Name of the Azure Local cluster |
| `ResourceGroup` | Resource group containing the cluster |
| `SubscriptionId` | Azure subscription ID |
| `ResourceId` | Full Azure Resource ID |
| `Action` | Action taken: "Created", "Updated", "Skipped", or "Error" |
| `PreviousTagValue` | Previous tag value (if updating existing tag) |
| `NewTagValue` | New tag value being set |
| `Status` | Result status: "Success", "Failed", "Skipped", or "WhatIf" |
| `Message` | Detailed status message |

**Examples:**

```powershell
# Import tags from a CSV file (preferred workflow)
Get-AzureLocalClusterInventory -ExportPath "C:\Temp\ClusterInventory.csv"
# Edit CSV in Excel to set UpdateRing values, then:
Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv"

# Set UpdateRing tag on multiple clusters directly
$resourceIds = @(
    "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01",
    "/subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02",
    "/subscriptions/xxx/resourceGroups/RG3/providers/Microsoft.AzureStackHCI/clusters/Cluster03"
)
Set-AzureLocalClusterUpdateRingTag -ClusterResourceIds $resourceIds -UpdateRingValue "Wave1"

# Preview changes without applying
Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv" -WhatIf

# Force update existing tags (logs previous values)
Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv" -Force

# Use with Start-AzureLocalClusterUpdate for wave-based deployments
# Step 1: Tag clusters for Wave1
Set-AzureLocalClusterUpdateRingTag -ClusterResourceIds $wave1Clusters -UpdateRingValue "Wave1"

# Step 2: Update only Wave1 clusters
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force
```

**Sample Output:**

```
========================================
Azure Local Cluster UpdateRing Tag Management
========================================

Log file: C:\ProgramData\AzLocal.UpdateManagement\UpdateRingTag_20260129_091500.log
CSV log: C:\ProgramData\AzLocal.UpdateManagement\UpdateRingTag_20260129_091500.csv
Input mode: CSV file
CSV path: C:\Temp\ClusterInventory.csv
Found 3 row(s) with UpdateRing values to process
Force mode: False
Clusters to process: 3

Azure CLI authentication verified

----------------------------------------
Processing: /subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01
Target UpdateRing: Wave1
----------------------------------------
Cluster: Cluster01
Resource Group: RG1
Subscription: xxx
Verifying cluster exists and retrieving current tags...
Cluster verified: Cluster01
No existing UpdateRing tag - will create new tag
Applying UpdateRing tag with value: 'Wave1'...
Successfully created UpdateRing tag

----------------------------------------
Processing: /subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02
Target UpdateRing: Wave2
----------------------------------------
Cluster: Cluster02
Existing UpdateRing tag found with value: 'Wave1'
Skipping cluster - use -Force to overwrite existing tag

========================================
Summary
========================================

Total clusters processed: 3
Tags created: 1
Tags updated: 0
Skipped (existing tag, no -Force): 1
Failed: 1

ClusterName Action  PreviousTagValue NewTagValue Status
----------- ------  ---------------- ----------- ------
Cluster01   Created                  Ring1       Success
Cluster02   Skipped Wave1            Ring1       Skipped
Cluster03   Skipped                  Ring1       Failed
```

---

## Fleet-Scale Operations

The following six functions enable enterprise-scale update management across fleets of 1000-3000+ clusters with batching, throttling, retry logic, health gates, and state management. Originally introduced in v0.5.6 and extended through subsequent releases (parallelism + paginated ARG in v0.7.0, sideloaded payload workflow in v0.7.1, ThrottleLimit-safe private-helper dispatch in v0.7.2).

### `Invoke-AzureLocalFleetOperation`

Orchestrates fleet-wide update operations with enterprise-scale features including batch processing, throttling, and automatic retry with exponential backoff.

**Features:**
- **Batch Processing**: Process clusters in configurable batches (default: 50 clusters)
- **Throttling**: Control parallel execution (default: 10 concurrent operations)
- **Retry Logic**: Automatic retries with exponential backoff (default: 3 retries)
- **State Management**: Checkpoint/resume capability via state files
- **Progress Tracking**: Real-time status updates during execution

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Operation` | String | No | `ApplyUpdate` | Operation to perform: `ApplyUpdate`, `CheckReadiness`, or `GetStatus` |
| `-ScopeByUpdateRingTag` | Switch | Yes* | - | Target clusters by UpdateRing tag |
| `-UpdateRingValue` | String | Yes* | - | The UpdateRing tag value to filter by |
| `-ClusterResourceIds` | String[] | Yes* | - | Explicit list of cluster resource IDs |
| `-UpdateName` | String | No | - | Specific update version to apply |
| `-BatchSize` | Int | No | `50` | Clusters per batch (1-500) |
| `-ThrottleLimit` | Int | No | `10` | Max parallel operations per batch (1-50) |
| `-DelayBetweenBatchesSeconds` | Int | No | `30` | Seconds to wait between batches (0-600) |
| `-MaxRetries` | Int | No | `3` | Retry attempts per cluster (0-10) |
| `-RetryDelaySeconds` | Int | No | `30` | Base delay between retries - uses exponential backoff (5-300) |
| `-StateFilePath` | String | No | - | Path to save state for resume capability |
| `-Force` | Switch | No | - | Skip confirmation prompts |
| `-PassThru` | Switch | No | - | Return the fleet state object |

*One of `-ScopeByUpdateRingTag`/`-UpdateRingValue` OR `-ClusterResourceIds` is required.

**Examples:**

```powershell
# Start updates on all Wave1 clusters with default settings
Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force

# Large fleet with increased batching and parallelism
Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Production" `
    -BatchSize 100 -ThrottleLimit 20 -DelayBetweenBatchesSeconds 60 -Force

# Save state for resume capability
$state = Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Ring1" `
    -StateFilePath "C:\Logs\ring1-state.json" -Force -PassThru

# Check readiness across fleet (no updates applied)
Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Canary" `
    -Operation CheckReadiness

# Apply specific update version
Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Pilot" `
    -UpdateName "Solution12.2601.1002.38" -Force
```

**Sample Output:**

```
========================================
Fleet Operation: ApplyUpdate
Run ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
========================================
Configuration:
  Batch Size: 50
  Throttle Limit: 10
  Delay Between Batches: 30 seconds
  Max Retries: 3

Querying clusters with UpdateRing = 'Wave1'...
Total clusters to process: 150

========================================
Batch 1 of 3 (50 clusters)
========================================
Processing: Cluster001
  ✓ Cluster001 - Succeeded
Processing: Cluster002
  ✓ Cluster002 - Succeeded
...

========================================
Fleet Operation Complete
========================================
Run ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Duration: 45.2 minutes
Total Clusters: 150
Succeeded: 147
Failed: 3
```

---

### `Get-AzureLocalFleetProgress`

Gets real-time progress of a fleet-wide update operation with aggregated statistics and optional per-cluster details.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-State` | PSCustomObject | No | - | Fleet operation state object from `Invoke-AzureLocalFleetOperation` |
| `-ScopeByUpdateRingTag` | Switch | Yes* | - | Query clusters by UpdateRing tag |
| `-UpdateRingValue` | String | Yes* | - | The UpdateRing tag value to filter by |
| `-Detailed` | Switch | No | - | Include per-cluster status in output |

*Either `-State` OR `-ScopeByUpdateRingTag`/`-UpdateRingValue` is required.

**Output Properties:**
| Property | Description |
|----------|-------------|
| `Timestamp` | When the progress was checked |
| `TotalClusters` | Total clusters in scope |
| `Completed` | Clusters that have finished (succeeded + up to date) |
| `ProgressPercent` | Completion percentage |
| `Succeeded` | Clusters where update succeeded |
| `UpToDate` | Clusters already up to date |
| `InProgress` | Clusters with updates currently running |
| `Failed` | Clusters where update failed |
| `NotStarted` | Clusters not yet processed |
| `ClusterStatuses` | Per-cluster details (when `-Detailed` used) |

**Examples:**

```powershell
# Check progress during an operation
Get-AzureLocalFleetProgress -State $fleetState

# Check progress for all Production clusters
Get-AzureLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Production"

# Get detailed per-cluster status
Get-AzureLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Detailed

# Monitor in a loop
while ($true) {
    $progress = Get-AzureLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Wave1"
    if ($progress.InProgress -eq 0) { break }
    Start-Sleep -Seconds 60
}
```

**Sample Output:**

```
========================================
Fleet Update Progress Check
========================================

Checking status of 150 cluster(s)...

Progress Summary:
  Total Clusters: 150
  Completed: 135 (90%)
  - Succeeded: 130
  - Up to Date: 5
  In Progress: 10
  Failed: 3
  Not Started: 2
```

---

### `Test-AzureLocalFleetHealthGate`

Evaluates fleet health to determine if it's safe to proceed with additional update waves. Acts as a "gate" in CI/CD pipelines to prevent cascading failures.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-State` | PSCustomObject | No | - | Fleet operation state to evaluate |
| `-ScopeByUpdateRingTag` | Switch | Yes* | - | Evaluate clusters by UpdateRing tag |
| `-UpdateRingValue` | String | Yes* | - | The UpdateRing tag value to filter by |
| `-MaxFailurePercent` | Int | No | `5` | Maximum allowed failure percentage (0-100) |
| `-MinSuccessPercent` | Int | No | `90` | Minimum required success percentage (0-100) |
| `-WaitForCompletion` | Switch | No | - | Wait for in-progress updates to complete before evaluating |
| `-WaitTimeoutMinutes` | Int | No | `120` | Maximum wait time for completion (minutes) |
| `-PollIntervalSeconds` | Int | No | `60` | How often to check status while waiting |

*Either `-State` OR `-ScopeByUpdateRingTag`/`-UpdateRingValue` is required.

**Output Properties:**
| Property | Description |
|----------|-------------|
| `Passed` | Boolean - did the gate pass? |
| `Reason` | Explanation of pass/fail |
| `TotalClusters` | Total clusters evaluated |
| `Succeeded` | Clusters that succeeded |
| `Failed` | Clusters that failed |
| `InProgress` | Clusters still in progress |
| `SuccessPercent` | Calculated success rate |
| `FailurePercent` | Calculated failure rate |

**Examples:**

```powershell
# Basic health gate check
Test-AzureLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Canary"

# Strict gate for production (max 2% failure, min 95% success)
Test-AzureLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -MaxFailurePercent 2 -MinSuccessPercent 95

# Wait for completion before evaluating
Test-AzureLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -WaitForCompletion -WaitTimeoutMinutes 180

# CI/CD pipeline integration
$gate = Test-AzureLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -MaxFailurePercent 2 -WaitForCompletion
if (-not $gate.Passed) {
    Write-Error "Health gate failed: $($gate.Reason)"
    exit 1
}
# Proceed to Wave2...
```

**Sample Output (Passed):**

```
========================================
Fleet Health Gate Check
========================================
Criteria: MaxFailure=5%, MinSuccess=90%

✓ HEALTH GATE PASSED
  Success Rate: 97.3% (min: 90%)
  Failure Rate: 2% (max: 5%)
```

**Sample Output (Failed):**

```
========================================
Fleet Health Gate Check
========================================
Criteria: MaxFailure=5%, MinSuccess=90%

✗ HEALTH GATE FAILED
  - Failure rate (8%) exceeds maximum (5%)
  - 2 cluster(s) have critical health failures
  Success Rate: 85% (min: 90%)
  Failure Rate: 8% (max: 5%)
```

---

### `Export-AzureLocalFleetState`

Exports the current fleet operation state to a JSON file for resume capability, audit trails, and progress tracking across sessions.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-State` | PSCustomObject | No | - | State object to export. Uses current in-memory state if not provided. |
| `-Path` | String | No | Auto-generated | File path for the JSON state file |

**Returns:** The path where the state was saved.

**State File Contents:**
- Run ID and timestamps
- Operation configuration (batch size, throttle limit, etc.)
- Total/completed/failed/pending cluster counts
- Per-cluster status with attempt history and errors

**Examples:**

```powershell
# Export current state to default location
Export-AzureLocalFleetState

# Export to specific path
Export-AzureLocalFleetState -Path "C:\Logs\fleet-state.json"

# Export state from operation
$state = Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -PassThru
Export-AzureLocalFleetState -State $state -Path "C:\Logs\wave1-checkpoint.json"
```

**Sample State File:**

```json
{
  "RunId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "Operation": "ApplyUpdate",
  "StartTime": "2026-01-29T10:00:00Z",
  "TotalClusters": 150,
  "CompletedCount": 75,
  "SucceededCount": 73,
  "FailedCount": 2,
  "PendingCount": 75,
  "BatchSize": 50,
  "Clusters": [
    {
      "ClusterName": "Cluster001",
      "ResourceId": "/subscriptions/.../clusters/Cluster001",
      "Status": "Succeeded",
      "Attempts": 1
    },
    ...
  ]
}
```

---

### `Resume-AzureLocalFleetUpdate`

Resumes a previously interrupted fleet update operation from a saved state file. Enables recovery from pipeline timeouts, network interruptions, or manual cancellations.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-StateFilePath` | String | Yes* | - | Path to the saved state file |
| `-State` | PSCustomObject | Yes* | - | State object loaded via `Import-AzureLocalFleetState` |
| `-RetryFailed` | Switch | No | - | Also retry clusters that previously failed (not just pending) |
| `-MaxRetries` | Int | No | `3` | Maximum additional retry attempts for failed clusters (0-10) |
| `-Force` | Switch | No | - | Skip confirmation prompts |
| `-PassThru` | Switch | No | - | Return the updated state object |

*Either `-StateFilePath` OR `-State` is required.

**Examples:**

```powershell
# Resume from state file (process only pending clusters)
Resume-AzureLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -Force

# Resume and retry failed clusters
Resume-AzureLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -RetryFailed -Force

# Load state manually and resume
$state = Import-AzureLocalFleetState -Path "C:\Logs\fleet-state.json"
Resume-AzureLocalFleetUpdate -State $state -RetryFailed -MaxRetries 5 -Force
```

**Sample Output:**

```
========================================
Resuming Fleet Operation
Original Run ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
========================================
State Summary:
  Pending: 75
  Failed: 2
  Succeeded: 73

Clusters to process: 77
```

---

### `Stop-AzureLocalFleetUpdate`

Gracefully stops an in-progress fleet update operation after the current batch completes and saves state for later resumption.

> **Note:** This function signals the operation to stop but does NOT cancel individual cluster updates that are already in progress. For emergency cancellation, use Azure Portal or `az` CLI to cancel individual update runs.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-SaveState` | Switch | No | - | Save the current state to a file before stopping |
| `-StateFilePath` | String | No | Auto-generated | Path to save the state file |

**Examples:**

```powershell
# Stop and save state
Stop-AzureLocalFleetUpdate -SaveState

# Stop and save to specific location
Stop-AzureLocalFleetUpdate -SaveState -StateFilePath "C:\Logs\fleet-stopped.json"
```

**Sample Output:**

```
========================================
Stopping Fleet Operation
========================================

State saved to: C:\Logs\fleet-stopped.json
Use Resume-AzureLocalFleetUpdate to continue later.

Operation Status at Stop:
  Run ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Total: 150
  Completed: 75
  Succeeded: 73
  Failed: 2
  Pending: 75

Fleet operation marked for stop.
Note: Updates already in progress on individual clusters will continue.
```

---

### `Test-AzureLocalUpdateScheduleAllowed`

Master gate that evaluates whether an update is allowed against the `UpdateWindow` (maintenance schedule) and `UpdateExclusions` (blackout periods) tag values. Exclusions take priority over windows. Returns a structured result with `Allowed`, `Reason`, `WindowOpen`, `ExclusionActive`, and `Details`. Used internally by `Start-AzureLocalClusterUpdate` and exposed as a public function so pipelines can pre-flight a wave before triggering the apply step.

> **Fail-closed behaviour**: malformed `UpdateWindow` / `UpdateExclusions` tag values cause this function to throw rather than swallow - this is intentional so the calling apply path can block the update unless `-Force` is supplied.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-UpdateWindow` | String | No | (none) | The `UpdateWindow` tag value (e.g. `Mon-Fri_22:00-02:00;Sat-Sun_02:00-06:00`). Empty/null = no window restriction. |
| `-UpdateExclusions` | String | No | (none) | The `UpdateExclusions` tag value (e.g. `2026-12-20/2027-01-03;2027-04-05`). Empty/null = no exclusion restriction. |
| `-TestTime` | DateTime | No | `(Get-Date).ToUniversalTime()` | UTC time to test against. Local/Unspecified inputs are normalised to UTC automatically. |

**Examples:**

```powershell
# Pre-flight a wave: would now be allowed?
$gate = Test-AzureLocalUpdateScheduleAllowed `
    -UpdateWindow 'Sat-Sun_02:00-06:00' `
    -UpdateExclusions '2026-12-20/2027-01-03'

if (-not $gate.Allowed) {
    Write-Host "Wave blocked: $($gate.Reason) - $($gate.Details)"
    exit 1
}

# Test a specific UTC point in time (e.g. when the pipeline will run tonight)
Test-AzureLocalUpdateScheduleAllowed `
    -UpdateWindow 'Mon-Fri_22:00-02:00' `
    -TestTime ([DateTime]::UtcNow.AddHours(6))
```

---

### `Reset-AzureLocalSideloadedTag`

Explicit, scope-required entry point for the same auto-reset logic that `Get-AzureLocalUpdateRuns` runs by default. Use it to: (a) manually reset the sideloaded tags after an out-of-band update where `Get-AzureLocalUpdateRuns` was not executed (or was run with `-SkipSideloadedReset`), or (b) force-clear a stuck `UpdateSideloaded=True` tag with `-Force`.

For each in-scope cluster the function fetches the latest update run and applies the same decision matrix as the auto-reset path - see [the action-values table in section 7a](#7a-sideloaded-payload-workflow-v071) for the full meaning of `Reset` / `OrphanCleared` / `NoTag` / `RunNotSucceeded` / `Skipped`. **Scope must be explicit** - there is no implicit `-AllClusters`. Supports `-WhatIf` / `-Confirm` (`ConfirmImpact = Medium`).

**Parameter sets:**

| Parameter set | Required | Use when |
|---------------|----------|----------|
| `ByName` | `-ClusterNames <string[]>` (+ optional `-ResourceGroupName`) | Resetting one or a small list of named clusters. |
| `ByResourceId` | `-ClusterResourceIds <string[]>` | Resetting by full ARM resource IDs (e.g. piped from another query). |
| `ByTag` | `-ScopeByUpdateRingTag` + `-UpdateRingValue <string>` | Bulk reset across an UpdateRing (e.g. all of `Wave1`). |

**Common parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-SubscriptionId` | String | No | Current `az` subscription | Override subscription context. |
| `-ApiVersion` | String | No | Module default | ARM api-version for the cluster + tag PATCH calls. |
| `-Force` | Switch | No | - | Bypasses the `UpdateVersionInProgress` match check. **Still requires the cluster's latest run state to be `Succeeded`** - this prevents flipping the gate while an in-flight update is still running. |

**Returns:** `PSCustomObject[]` - one row per cluster with `ClusterName`, `Action`, `PreviousSideloaded`, `NewSideloaded`, `StagedVersion`, `MatchedRunUpdateName`, `Message`.

**Examples:**

```powershell
# Inspect a single cluster (no changes)
Reset-AzureLocalSideloadedTag -ClusterNames 'cl-01' -ResourceGroupName 'rg-fleet' -WhatIf

# Bulk reset across an UpdateRing, default behaviour: only succeeded runs get reset
Reset-AzureLocalSideloadedTag -ScopeByUpdateRingTag -UpdateRingValue 'Wave1'

# Force-clear a stuck cluster (operator abandoned the staged payload).
# -Force still requires latest run = Succeeded; it just bypasses the version-match check.
Reset-AzureLocalSideloadedTag -ClusterNames 'cl-stuck' -Force -Confirm:$false
```

> **No new RBAC required.** Uses the same `Microsoft.Resources/tags/read` + `Microsoft.Resources/tags/write` already required by `Set-AzureLocalClusterUpdateRingTag`.

---

### `Get-AzureLocalFleetStatusData`

Single-pass data collector that gathers everything `New-AzureLocalFleetStatusHtmlReport` needs, in one structured object. Returns a `PSCustomObject` with `SchemaVersion`, `Timestamp`, `ModuleVersion`, `Scope`, `Readiness`, `ClusterDetails`, `LatestRuns`, `HealthResults`. Use this when you want to:

- Decouple data collection from rendering (collect once in a CI/CD job, render in another).
- Pass data between pipeline stages as a JSON artifact (`-ExportPath`).
- Avoid the redundant API calls that happen if you call the readiness / inventory / health functions separately.

Honours `-ThrottleLimit 1-8` for parallel collection; default 4.

**Parameter sets:** `ByResourceId` / `ByName` / `ByTag` / `All` (mirrors the other fleet functions).

**Common parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-IncludeUpdateRuns` | Switch | - | Collect latest update run history per cluster. |
| `-IncludeHealthDetails` | Switch | - | Collect detailed health-check failure data per cluster. |
| `-ThrottleLimit` | Int 1-8 | 4 | Parallel workers. Set 1 for sequential / debugging. |
| `-MaxClusters` | Int 0-100000 | 0 (no cap) | Optional cap when `-AllClusters` is used. |
| `-ExportPath` | String | - | JSON path for the artifact. |

**Examples:**

```powershell
# One-step: collect + render
$data = Get-AzureLocalFleetStatusData -AllClusters -ThrottleLimit 4 -IncludeUpdateRuns -IncludeHealthDetails
New-AzureLocalFleetStatusHtmlReport -StatusData $data -OutputPath 'C:\Reports\fleet.html'

# CI/CD: collect in job 1, render in job 2 from the artifact
Get-AzureLocalFleetStatusData -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' `
    -IncludeUpdateRuns -IncludeHealthDetails `
    -ExportPath '$(Pipeline.Workspace)/fleet-data.json'
```

---

### `New-AzureLocalFleetStatusHtmlReport`

Renders a self-contained HTML report (executive summary, progress bar, cluster status table, optional health-details and update-run-history sections, embedded CSS). UTF-8 without BOM; safe to email or host on SharePoint. Supports `-WhatIf` / `-Confirm`.

Two ways to drive it:

1. **Self-collecting** (default): pass a scope (`-AllClusters` / `-ClusterNames` / `-ScopeByUpdateRingTag` / `-ClusterResourceIds`) and the function will call `Get-AzureLocalClusterInventory`, `Get-AzureLocalClusterUpdateReadiness`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates` (and optionally `Get-AzureLocalUpdateRuns` / `Test-AzureLocalClusterHealth`) itself.
2. **From pre-collected data**: pass `-StatusData $data` (the object returned by `Get-AzureLocalFleetStatusData`) and the function skips all API calls, going straight to rendering. **Use this in CI/CD to avoid double-billing yourself for ARM reads.**

**Common parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-OutputPath` | String | Yes | - | Destination `.html` / `.htm` file. Validated. |
| `-StatusData` | PSCustomObject | No | - | Pre-collected payload from `Get-AzureLocalFleetStatusData`. |
| `-IncludeUpdateRuns` | Switch | No | - | Add the **Recent Update Run History** section (now includes `End Time` column - v0.7.1). |
| `-IncludeHealthDetails` | Switch | No | - | Add the detailed health-check failure section. |
| `-Title` | String | No | Auto | Custom report title (auto-derived from scope if omitted). |
| `-MaxClusters` | Int 0-100000 | No | 0 (no cap) | Optional cap when `-AllClusters` is used. |
| `-ThrottleLimit` | Int 1-8 | No | 4 | Parallel workers (only relevant when self-collecting). |
| `-PassThru` | Switch | No | - | Also return the HTML string (useful for emailing). |

**Examples:**

```powershell
# Whole fleet, full detail
New-AzureLocalFleetStatusHtmlReport -AllClusters `
    -OutputPath 'C:\Reports\fleet.html' `
    -IncludeUpdateRuns -IncludeHealthDetails

# Wave-scoped, capture HTML for email body
$html = New-AzureLocalFleetStatusHtmlReport `
    -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' `
    -OutputPath 'C:\Reports\wave1.html' -PassThru

# Two-stage CI/CD pattern (no double API calls)
$data = Get-AzureLocalFleetStatusData -AllClusters -IncludeUpdateRuns -IncludeHealthDetails
New-AzureLocalFleetStatusHtmlReport -StatusData $data -OutputPath 'C:\Reports\fleet.html'
```

---

## Logging and Output

The module includes comprehensive logging capabilities for tracking update operations.

### Log Files

By default, log files are created in `C:\ProgramData\AzLocal.UpdateManagement\` which is accessible across different user profiles. This folder is automatically created if it doesn't exist.

When you run `Start-AzureLocalClusterUpdate`, the following files are automatically created:

| File | Description |
|------|-------------|
| `AzureLocalUpdate_YYYYMMDD_HHmmss.log` | Main log file with timestamped entries |
| `AzureLocalUpdate_YYYYMMDD_HHmmss_errors.log` | Separate error log (only created if errors occur) |
| `AzureLocalUpdate_YYYYMMDD_HHmmss_Update_Skipped.csv` | CSV of clusters where updates were skipped (not in Ready state) |
| `AzureLocalUpdate_YYYYMMDD_HHmmss_Update_Started.csv` | CSV of clusters where updates were successfully started |
| `AzureLocalUpdate_YYYYMMDD_HHmmss_transcript.log` | Full PowerShell transcript (if `-EnableTranscript` is used) |

#### CSV Summary Files

The `Update_Skipped.csv` and `Update_Started.csv` files provide a quick summary for reporting.

##### Update_Started.csv Columns

| Column | Description |
|--------|-------------|
| `ClusterName` | Name of the Azure Local cluster |
| `ResourceGroup` | Resource group containing the cluster |
| `SubscriptionId` | Azure subscription ID |
| `Message` | Status message (e.g., "Update Started: Solution12.2601.1002.38") |

##### Update_Skipped.csv Columns (Extended Diagnostics)

The skipped CSV includes additional diagnostic columns to help understand why clusters were not updated:

| Column | Description |
|--------|-------------|
| `ClusterName` | Name of the Azure Local cluster |
| `ResourceGroup` | Resource group containing the cluster |
| `SubscriptionId` | Azure subscription ID |
| `Message` | Status message explaining why the update was skipped |
| `UpdateState` | Current update state (e.g., "NeedsAttention", "UpdateFailed", "UpdateInProgress") |
| `HealthState` | Health check state: "Success", "Warning", "Failure", "InProgress", or "Unknown" |
| `HealthCheckFailures` | Summary of failed health checks with severity (e.g., "[Critical] StoragePool; [Warning] ClusterQuorum") |
| `LastUpdateErrorStep` | The specific step that failed in the last update run (if applicable) |
| `LastUpdateErrorMessage` | Error message from the last failed update step (truncated to 500 chars) |

This diagnostic information is sourced from:
- `healthCheckResult` property in the cluster's updateSummaries resource
- `progress.steps` property in the cluster's failed updateRuns (nested step traversal)

##### Example Update_Skipped.csv content:
```csv
"ClusterName","ResourceGroup","SubscriptionId","Message","UpdateState","HealthState","HealthCheckFailures","LastUpdateErrorStep","LastUpdateErrorMessage"
"Cluster01","RG-West","12345-abcd","Update Not started as Cluster NOT in Ready state (Current state: NeedsAttention)","NeedsAttention","Failure","[Critical] Test-CauSetup; [Warning] Test-VMNetAdapter","DownloadSBE","Failed to download SBE package from storage account."
"Cluster02","RG-East","12345-abcd","Update Not started as Cluster NOT in Ready state (Current state: UpdateInProgress)","UpdateInProgress","Success","","",""
"Cluster03","RG-North","12345-abcd","Update skipped by user","UpdateAvailable","Success","","",""
```

### Logging Examples

```powershell
# Basic logging (logs created in default folder: C:\ProgramData\AzLocal.UpdateManagement\)
Start-AzureLocalClusterUpdate -ClusterNames "MyCluster" -Force

# Custom log folder location (auto-creates folder if needed)
Start-AzureLocalClusterUpdate -ClusterNames "MyCluster" -LogFolderPath "D:\Logs\Updates" -Force

# Enable transcript recording for complete console output capture
Start-AzureLocalClusterUpdate -ClusterNames "MyCluster" -EnableTranscript -Force

# Export results to JSON for automation/reporting
Start-AzureLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02") -ExportResultsPath "C:\Logs\results.json" -Force

# Export results to CSV for Excel analysis
Start-AzureLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02") -ExportResultsPath "C:\Logs\results.csv" -Force

# Full logging with all options
Start-AzureLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02") `
    -LogFolderPath "D:\Logs\Updates" `
    -EnableTranscript `
    -ExportResultsPath "D:\Logs\Updates\results.json" `
    -Force
```

### Log Entry Format

Each log entry includes a timestamp and severity level:

```
[2026-01-28 14:30:45] [Info] Processing cluster: MyCluster01
[2026-01-28 14:30:46] [Success] Found cluster: /subscriptions/.../clusters/MyCluster01
[2026-01-28 14:30:47] [Warning] No updates in 'Ready' state for cluster 'MyCluster01'
[2026-01-28 14:30:48] [Error] Failed to start update on cluster 'MyCluster01'
```

### Results Export Format

**JSON Export** includes summary statistics:

```json
{
  "Timestamp": "2026-01-28 14:30:45",
  "TotalClusters": 3,
  "Succeeded": 2,
  "Failed": 0,
  "Skipped": 1,
  "Results": [...]
}
```

**CSV Export** includes one row per cluster with columns: ClusterName, Status, UpdateName, Duration, Message, StartTime, EndTime

## API Reference

The functions use the Azure Stack HCI REST API (version 2025-10-01):

| Operation | HTTP Method | Endpoint |
|-----------|-------------|----------|
| List Clusters | GET | `/subscriptions/{sub}/providers/Microsoft.AzureStackHCI/clusters` |
| Get Cluster | GET | `/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.AzureStackHCI/clusters/{cluster}` |
| Get Update Summary | GET | `...clusters/{cluster}/updateSummaries/default` |
| List Updates | GET | `...clusters/{cluster}/updates` |
| Get Update | GET | `...clusters/{cluster}/updates/{updateName}` |
| **Apply Update** | **POST** | `...clusters/{cluster}/updates/{updateName}/apply` |
| List Update Runs | GET | `...clusters/{cluster}/updates/{updateName}/updateRuns` |

## Update States

### Cluster Update Summary States

| State | Description | Can Start Update? |
|-------|-------------|-------------------|
| `UpdateAvailable` | Updates are available | Yes |
| `AppliedSuccessfully` | All updates applied | No - already up to date |
| `UpdateInProgress` | Update is running | No - wait for completion |
| `UpdateFailed` | Last update failed | Investigate first |
| `NeedsAttention` | Manual intervention needed | Resolve issues first |

### Individual Update States

| State | Description | Can Apply? |
|-------|-------------|------------|
| `Ready` | Update is ready to install | Yes |
| `ReadyToInstall` | Preparation complete | Yes |
| `HasPrerequisite` | Prerequisites required | No - install prerequisites first (see SBE dependency info) |
| `Installing` | Currently installing | No - in progress |
| `Installed` | Successfully installed | No - already done |
| `InstallationFailed` | Installation failed | Retry or investigate |

## Using Azure CLI Directly

You can also use `az rest` commands directly:

```powershell
# List all clusters in subscription
az rest --method GET --uri "https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.AzureStackHCI/clusters?api-version=2025-10-01"

# Get update summary
az rest --method GET --uri "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.AzureStackHCI/clusters/{clusterName}/updateSummaries/default?api-version=2025-10-01"

# List available updates
az rest --method GET --uri "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.AzureStackHCI/clusters/{clusterName}/updates?api-version=2025-10-01"

# Apply an update (no body required)
az rest --method POST --uri "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.AzureStackHCI/clusters/{clusterName}/updates/{updateName}/apply?api-version=2025-10-01"
```

## Alternative: Az.StackHCI PowerShell Module

Microsoft also provides native PowerShell cmdlets in the `Az.StackHCI` module:

```powershell
# Install the module
Install-Module -Name Az.StackHCI -Force

# Apply an update
Invoke-AzStackHciUpdate -ClusterName 'MyCluster' -Name 'Solution12.2601.1002.38' -ResourceGroupName 'MyRG'
```

## CI/CD Automation

> 📦 **The complete CI/CD guide lives in [Automation-Pipeline-Examples/README.md](./Automation-Pipeline-Examples/README.md).** It covers OIDC / Managed Identity / Service Principal setup, federated credentials, three ready-to-run GitHub Actions workflows, three Azure DevOps pipelines, and end-to-end automation diagrams. **Start there for any pipeline work.** This section only documents the module-level features that pipelines depend on.

The module is pipeline-friendly out of the box:

- **Authentication**: works with OIDC (recommended), Managed Identity, or Service Principal + secret. See `Connect-AzureLocalServicePrincipal` and the pipeline guide above.
- **JUnit XML export**: any function that takes `-ExportPath` / `-ExportResultsPath` will emit JUnit XML when the path ends in `.xml`. Consumed natively by Azure DevOps **Publish Test Results**, GitHub Actions (`dorny/test-reporter`, `mikepenz/action-junit-report`), Jenkins, GitLab CI (`artifacts:reports:junit`), and TeamCity.
- **CSV / JSON export**: pass `.csv` or `.json` for the same paths to drive downstream reporting / Power BI / Log Analytics ingestion.
- **`-WhatIf` and `-PassThru`**: every state-changing function supports `-WhatIf` (counted as `WouldUpdate` in the summary) so dry-runs are auditable; `-PassThru` returns structured objects for pipeline-stage chaining.
- **Parallelism**: `-ThrottleLimit 1..16` on per-cluster operations; default 4. Tune for your runner and ARM throttling envelope.

Minimal example - export update results as JUnit XML:

```powershell
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue 'Ring1' -Force `
    -ExportResultsPath './test-results/update-results.xml'
```

For full GitHub Actions / Azure DevOps YAML, federated-credential setup, and the recommended two-stage "collect once, render later" pattern, see [Automation-Pipeline-Examples/README.md](./Automation-Pipeline-Examples/README.md).

<!-- Detailed CI/CD examples removed in v0.7.1; canonical content now in Automation-Pipeline-Examples/README.md -->

## Troubleshooting

### Common Issues

1. **"Cluster not found"**: Verify the cluster name and ensure you have access to the subscription.

2. **"No updates available"**: The cluster may already be up to date. Check the update summary state.

3. **"Update not in Ready state"**: Updates may be downloading or have prerequisites. Check the update's state property.

4. **"Cluster not in valid state"**: The cluster must be "Connected" and the update summary state must be "UpdateAvailable".

5. **"Service Principal authentication failed"**: Verify the `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, and `AZURE_TENANT_ID` values are correct and the Service Principal has the required permissions.

### `WARNING: Unable to encode the output with cp1252 encoding`

**Symptom**

- One or more `WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.` lines appear in the module's verbose/output stream, often interspersed with empty result tables.
- `Get-AzureLocalUpdateRuns`, `Get-AzureLocalAvailableUpdates`, or `Get-AzureLocalFleetStatusData` returns placeholder `Error` rows for some clusters with otherwise valid Azure access.
- Affected clusters typically have non-ASCII characters somewhere in the ARM payload (smart quotes / accented characters in tag values, localised health-check messages, etc.).

**Cause**

On Windows hosts where the console code page is `cp1252` (the English-US default - includes default GitHub `windows-latest` runners and Azure DevOps `windows-2022` agents), the Azure CLI emits this warning to stderr whenever it cannot encode a response character. Captured via `2>&1` it is prepended to the JSON body and breaks `ConvertFrom-Json`. Setting `$env:PYTHONIOENCODING = 'utf-8'` does **not** help: `az.cmd` launches Python with `-I` (isolated mode), which causes Python to ignore all `PYTHON*` environment variables ([Azure/azure-cli#28497](https://github.com/Azure/azure-cli/issues/28497)).

**Fix**

Upgrade to **AzLocal.UpdateManagement v0.7.2 or later**. The module passes `--only-show-errors` to every `az rest` / `az graph query` invocation, which suppresses the warning at source ([Azure/azure-cli#14426](https://github.com/Azure/azure-cli/issues/14426)). Genuine errors (auth failures, 4xx/5xx ARM responses, invalid args) still surface normally.

```powershell
# Verify your installed module version is >= 0.7.2
(Get-Module AzLocal.UpdateManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
```

If you still see the warning after upgrading, you are most likely calling `az` directly outside the module (e.g. in a custom pre/post step). Add `--only-show-errors` to your direct calls.

### ARM is stale - readiness recommends an already-installed update

**Symptom**

- `Get-AzureLocalClusterUpdateReadiness` recommends an update that is already installed on the cluster (e.g. portal shows `CurrentVersion = 12.2603.1002.500` but `RecommendedUpdate = Solution12.2603.1002.500`).
- Azure portal shows contradictory banners on the cluster **Updates** blade ("Update(s) available" header + "There is no update available to install" banner).
- `updateSummaries.lastChecked` / `lastUpdated` timestamps are hours or days old.
- Running `Get-SolutionUpdate` on a cluster node shows the correct state (the newer update as `Ready`, older ones as `Installed`), but the ARM `/updates` and `/updateSummaries` child resources do not reflect it.

**Cause**

The `Azure Stack HCI Update Service` is a **manual-start, on-demand** Windows service on each cluster node. It is the component that pushes `/updates` and `/updateSummaries` state to ARM. If it has not been triggered recently (by the LCM scheduler or by a user action), ARM's view of the cluster drifts out of sync with the node-local `Get-SolutionUpdate` store. The module correctly reports what ARM returns - ARM is wrong, not the module.

Note: v0.7.0+ `Get-AzureLocalClusterUpdateReadiness` already mitigates this by short-circuiting to `UpToDate` when every entry in `/updates` is in the terminal `Installed` state, even if `updateSummaries.state` is stale. But once a genuinely new update (like `Solution12.2604.xxxx`) is published, the staleness becomes visible again until ARM is refreshed.

**Fix**

Start the update service on every node. It will reconcile with local LCM and push to ARM, then return to `Stopped` (that is normal - it is a one-shot worker, not a daemon):

```powershell
# From any machine with WinRM access to the cluster nodes:
$nodes = (Get-ClusterNode -Cluster <ClusterName>).Name
Invoke-Command -ComputerName $nodes -ScriptBlock {
    Write-Host "[$env:COMPUTERNAME] Starting 'Azure Stack HCI Update Service'..."
    Start-Service -Name 'Azure Stack HCI Update Service' -ErrorAction Continue
    Start-Sleep 3
    Get-Service 'Azure Stack HCI Update Service', 'HciCloudManagementSvc',
                'Azure Stack HCI Orchestrator Service' |
        Format-Table Name, Status, StartType -AutoSize
}
```

Give it ~2-5 minutes, then re-check ARM:

```powershell
$rid = '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.AzureStackHCI/clusters/<ClusterName>'
(az rest --method get --uri "https://management.azure.com$rid/updateSummaries?api-version=2025-10-01" |
    ConvertFrom-Json).value[0].properties |
    Select-Object state, currentVersion, lastChecked, lastUpdated
```

`lastChecked` should jump to a recent timestamp and `currentVersion` should match what `Get-SolutionUpdate` shows on the node.

**If it still does not refresh**

Check the ECE/HCI event logs on a node for push errors:

```powershell
Get-WinEvent -LogName Application -ProviderName ECEAgent -MaxEvents 30 |
    Select-Object TimeCreated, LevelDisplayName, Message | Format-List
```

Look for repeated ARM or `UpdateService` failures. If the Arc connected-machine agent (`himds`, `GCArcService`, `ExtensionService`) is unhealthy, the push side will be blocked regardless - `azcmagent show` on each node confirms Arc connectivity.

### Verbose Logging

Enable verbose output for debugging:

```powershell
Start-AzureLocalClusterUpdate -ClusterNames "MyCluster" -Verbose
```

## License

This code is provided as-is for educational and reference purposes.

---

## Release History

### What's New in v0.7.4

- **ITSM Connector - Phase 1 (ServiceNow)**: new opt-in capability for opening ServiceNow incidents directly from update / fleet pipeline output. Three new exported functions - `New-AzureLocalIncident`, `Get-AzureLocalItsmConfig`, `Test-AzureLocalItsmConnection` - plus supporting private helpers (`Resolve-AzLocalItsmSecret`, `Get-AzLocalItsmDedupeKey`, `Get-AzLocalItsmTriggerDecision`, `Format-AzLocalIncidentBody`, `Invoke-AzLocalItsmHttp`, `Invoke-AzLocalServiceNowAdapter`). `New-AzureLocalIncident` reads a JUnit results artifact (and an optional readiness CSV), applies the trigger matrix from the user's [`azurelocal-itsm.yml`](Automation-Pipeline-Examples/.itsm/azurelocal-itsm.yml) config, computes a deterministic SHA256 dedupe key per `{ClusterResourceId, UpdateName, TriggerCategory}` tuple, queries ServiceNow for an existing open ticket (`u_azlocal_dedupe_key`, `stateIN1,2,3`), and either creates a new incident or returns the existing ticket - so re-running the same pipeline is idempotent. Auth is OAuth 2.0 `client_credentials` only in Phase 1; secrets resolve from Azure Key Vault (`kv://<vault>/<secret>`), environment variables (`env://NAME`), or explicit literals (`literal://...` with `-AllowLiteral`). HTTP path is TLS 1.2+, default 30s timeout, exponential backoff on 429/5xx, `Retry-After` honoured. The CSV export from `-ExportPath` is sanitised by `ConvertTo-SafeCsvCollection`, neutralising the same formula-injection class already handled elsewhere in the module. `Test-AzureLocalItsmConnection` validates the config, resolves secrets, performs the OAuth token grant, and probes a one-row read against `/api/now/table/incident` (matching the least-privilege scope used by ticket creation). Full documentation under [`ITSM/`](ITSM/): [README](ITSM/README.md), [ITSM-Connector-Plan.md](ITSM/ITSM-Connector-Plan.md), [ITSM-Config-Reference.md](ITSM/ITSM-Config-Reference.md). A ready-to-copy sample config plus the Mustache ticket-body template live under [`Automation-Pipeline-Examples/.itsm/`](Automation-Pipeline-Examples/.itsm/). 33 new ITSM Pester tests; full suite green at 337/337.
- **Phase 2 and Phase 3 are not in this release.** Phase 2 (`Sync-AzureLocalIncident` - close-out / work-note sweep when the underlying cluster recovers) and Phase 3 (Microsoft Teams + Slack mirror adapters) are designed in [`ITSM/ITSM-Connector-Plan.md`](ITSM/ITSM-Connector-Plan.md) and tracked for a later release. The `lifecycle` and `notifications` config sections are parsed and stored in Phase 1 but not yet acted on. A small set of Phase 1.5 follow-ups is also tracked: cmdbCi token expansion, custom-field presence check, rate-limit-headroom probe, in-module token caching, `Invoke-AzLocalItsmHttp -AllowedThumbprints` cert pinning, and `raiseAfterConsecutiveOccurrences` enforcement (requires the run-history store).
- **Code hygiene**: removed the unused username/password OAuth grant path from the ServiceNow adapter (Phase 1 is `client_credentials` only) - silences the PSScriptAnalyzer `PSAvoidUsingUsernameAndPasswordParams` Error and `PSAvoidUsingPlainTextForPassword` Warning. Tightened the ITSM config validator so `secrets.source: mixed` now requires `secrets.keyvaultName`, matching the documented behaviour. Cleaned up legacy non-ASCII characters in [`Private/Format-AzLocalUpdateRun.ps1`](Private/Format-AzLocalUpdateRun.ps1) and [`Publish-Module.ps1`](Publish-Module.ps1) divider comments. Flattened `ITSM/Docs/` into [`ITSM/`](ITSM/) (removed the stale duplicate `ITSM/Docs/ITSM-Connector-Plan.md`).
- **`Copy-AzureLocalPipelineExample` (convenience)**: new exported function that copies the bundled [`Automation-Pipeline-Examples/`](Automation-Pipeline-Examples/) folder out of the module install location into a destination folder you control (default: current directory). Supports `-Platform GitHub | AzureDevOps | All`, `-Flatten` (drop contents directly into the destination), `-Force` (overwrite), `-PassThru`, `-WhatIf` and `-Confirm`. After copying, prints a short "next steps" summary pointing at the README and the platform-specific destination paths so you don't have to hunt through `$module.ModuleBase` to find the YAML samples.

### What's New in v0.7.3

- **Module renamed** from `AzStackHci.ManageUpdates` to `AzLocal.UpdateManagement`. The module GUID is preserved across the rename so PowerShell tooling sees this as the same module identity. All previously-published `AzStackHci.ManageUpdates` versions have been unlisted from PSGallery; a transitional v0.7.3 stub is published once to point legacy automation at the new name. Migration: `Uninstall-Module AzStackHci.ManageUpdates -AllVersions; Install-Module AzLocal.UpdateManagement`. Default log folder default also moved from `C:\ProgramData\AzStackHci.ManageUpdates\` to `C:\ProgramData\AzLocal.UpdateManagement\`.
- **Internal refactor**: the monolithic 11,679-line `.psm1` has been split into Public/Private dot-sourced files matching the layout of `AzLocal.DeploymentAutomation`. 20 exported functions live under `Public/`, 40 internal helpers under `Private/`. The manifest's `NestedModules` list enumerates every file. No functional change; the full Pester suite (299 tests) remains green.

### What's New in v0.7.2

- **Bug fix - fleet read paths under `-ThrottleLimit > 1`**: `Get-AzureLocalUpdateRuns`, `Get-AzureLocalUpdateSummary`, and `Get-AzureLocalClusterUpdateReadiness` previously failed for every cluster when invoked with `-ThrottleLimit` greater than 1, reporting `The term 'Get-AzLocalClusterUpdateRuns' is not recognized...` (or the equivalent for other private helpers). The per-cluster scriptblock dispatched via `Start-Job` called module-private helpers (`Invoke-AzRestJson`, `Get-AzLocalClusterUpdateRuns`, `Format-AzLocalUpdateRun`, `Get-LatestUpdateByYYMM`, `ConvertTo-AzLocalAdditionalProperties`, `Get-HealthCheckFailureSummary`, `Get-TagValue`) by name; because those helpers are filtered out by `Export-ModuleMember`, after `Import-Module` in the child runspace they were not visible at script command-resolution scope. Inline (`-ThrottleLimit 1`) execution was unaffected. Each affected scriptblock now captures a reference to the loaded module and either invokes the helper via `& $module { ... }` or rebinds the helper's bound scriptblock into the local function scope, so calls execute against the module's own session state and resolve all transitive private references. Reported against a 9-cluster Prod fleet.
- **Bug fix - cp1252 encoding warnings leaking into JSON parsing**: On Windows hosts where the console code page is `cp1252` (the English-US default), the Azure CLI (`az rest`, `az graph query`) emitted `WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.` whenever ARM responses contained non-cp1252 characters (smart quotes, accented characters in cluster tags, localised health-check messages, etc.). Captured via `2>&1`, that warning was prepended to the JSON body and broke `ConvertFrom-Json`, which silently dropped update runs and available updates for affected clusters. Earlier attempts to fix this via `$env:PYTHONIOENCODING = 'utf-8'` are structurally ineffective: `az.cmd` launches Python with the `-I` (isolated) flag, which implies `-E` and so causes Python to ignore all `PYTHON*` environment variables (including `PYTHONIOENCODING` and `PYTHONUTF8`) - confirmed in [Azure/azure-cli#28497](https://github.com/Azure/azure-cli/issues/28497). The actual fix is to pass `--only-show-errors` to every `az rest` and `az graph query` invocation (Azure CLI maintainer's recommended workaround per [Azure/azure-cli#14426](https://github.com/Azure/azure-cli/issues/14426)). This suppresses the encode warning at source so the captured stderr/stdout streams stay clean. Characters that fail to encode are still replaced silently inside the CLI, but for ARM cluster/update payloads (timestamps, GUIDs, status enums, resource IDs - all ASCII) this is a non-issue. Genuine errors (auth failures, 4xx/5xx ARM responses, invalid args) still surface normally.

### What's New in v0.7.1

- **Sideloaded payload workflow (new)**: opt-in two-tag protocol (`UpdateSideloaded` set by operator, `UpdateVersionInProgress` set by module) for staging out-of-band update payloads. `Start-AzureLocalClusterUpdate` blocks with `Status = SideloadedBlocked` while the payload is being staged. `Get-AzureLocalUpdateRuns` auto-resets the tags once the matching run succeeds. New public function [`Reset-AzureLocalSideloadedTag`](#reset-azurelocalsideloadedtag) for explicit / `-Force` recovery. See [section 7a](#7a-sideloaded-payload-workflow-v071) for the full flow. **No new RBAC required** - rides on the existing `Microsoft.Resources/tags/read|write` permissions.
- **EndTime column for update runs**: new `EndTime` column on `Get-AzureLocalUpdateRuns` table output, sourced from `properties.progress.endTimeUtc` (most accurate "work finished" timestamp), falling back to `properties.lastUpdatedTime`. Blank for `InProgress` runs. Per-run `Duration` now prefers ARM-reported `properties.duration` (ISO-8601 timespan) over the computed `EndTime - StartTime` delta, so it is immune to clock skew. Fleet HTML report's "Recent Update Run History" gains an `End Time` column; JUnit XML test bodies include `Start Time:` / `End Time:` lines per testcase (the JUnit `time=` attribute is unchanged).
- **Idempotent tag merges**: `Set-AzLocalClusterTagsMerge` (private helper used by both `Set-AzureLocalClusterUpdateRingTag` and the sideloaded workflow) now skips the PATCH when the merge produces no actual change against the cluster's current tags. Quieter logs and one less ARM write per no-op.
- **Enterprise-readiness review fixes**:
  - **Security**: `Write-UpdateCsvLog` (the diagnostic CSV path used during apply runs) now sanitises every field through `ConvertTo-SafeCsvField` before quote-escaping, closing the same Excel-formula-injection gap on the interim `Update_Skipped.csv` / `Update_Started.csv` logs that was already covered for the final exported results.
  - **Operational**: parallel `Get-AzureLocalFleetStatusData` job dispatch now treats `Stopped` and `Disconnected` job states as failures alongside `Failed`. Previously these terminal states fell through into `Receive-Job` and were misdiagnosed as "no output", obscuring the real cause of `Stop-Job` / Ctrl-C / remoting-disconnect scenarios.
  - **Performance**: `Get-AzureLocalUpdateSummary`, `Get-AzureLocalClusterUpdateReadiness`, `Start-AzureLocalClusterUpdate`, `Get-AzureLocalUpdateRuns`, and the private `Get-AzLocalClusterUpdateRuns` helper now accumulate per-cluster results in a `[System.Collections.Generic.List[object]]` (O(1) amortised `.Add()`) instead of an `Object[]` with `+=` (O(n^2) total). Measurable speed-up at fleet scale (1000+ clusters); no API surface change - the functions still return arrays.

### What's New in v0.7.0

The jump from `0.6.5` to `0.7.0` is a large, fleet-scale release focused on correctness at 1500+ clusters, true parallel execution, HTML report performance, and a round of security hardening. No breaking public-surface changes.

#### Fixed - Correctness at scale
- **HIGH**: Azure Resource Graph queries were hardcoded to `az graph query --first 1000`. At 1500 clusters, 500 were silently dropped - no error, no warning. New private `Invoke-AzResourceGraphQuery` helper loops on the `$skipToken` until exhausted.
- **HIGH**: `Invoke-AzureLocalFleetOperation -ThrottleLimit` previously only affected retry-backoff math; the per-cluster loop was fully sequential. At 1500 clusters that meant 4+ hour runs. Extracted the parallel `Start-Job` pattern into a shared private helper `Invoke-FleetJobsInParallel` and rerouted all fleet operations through it. `-ThrottleLimit` now controls concurrent API calls (default 4, range 1-16). PowerShell 5.1 compatibility preserved.
- **HIGH**: `Get-AzureLocalClusterInventory` threw `The variable cannot be validated because the value '' is not a valid value for the UpdateRingValue variable.` whenever a cluster in the fleet was missing the `UpdateRing` tag. Root cause: the function's `[ValidatePattern]` parameter `$UpdateRingValue` collided with a loop-local `$updateRingValue` (PowerShell variable names are case-insensitive). Locals renamed to `$ringTagValue` / `$windowTagValue` / `$exclusionsTagValue`. `-AllClusters` reports now complete against real-world mixed-tag fleets.

#### Changed - Performance (parallel by default)
- These per-cluster functions now run in parallel batches via the shared helper: `Get-AzureLocalClusterUpdateReadiness`, `Test-AzureLocalClusterHealth`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Set-AzureLocalClusterUpdateRingTag`, `Get-AzureLocalUpdateRuns`. Expected 5-10x speedup on 1500-cluster runs (readiness check from ~10 min to ~1-2 min).
- `New-AzureLocalFleetStatusHtmlReport` renderer rewritten for O(n) scaling: pre-indexed `LatestRuns` and `ClusterDetails` hashtables, HTML encoding moved to collection time, per-cluster portal URLs precomputed once. ~60% faster HTML render at 1500 clusters.
- HTML report output now written as UTF-8 **without BOM** via `[System.IO.File]::WriteAllText` + `UTF8Encoding($false)`.
- New opt-in pass-through parameters (`-UpdateSummary`, `-AvailableUpdates`) so pre-fetched data can be reused across a pipeline, avoiding redundant ARM reads.

#### Changed - `-AllClusters` cap removed
- `New-AzureLocalFleetStatusHtmlReport -AllClusters` and `Get-AzureLocalFleetStatusData -AllClusters` previously truncated at the first 100 clusters silently. **The default cap is removed - all discovered clusters are now included.** New `-MaxClusters <int>` parameter (default 0 = no cap, range 1-100000) lets callers optionally trim the slice for targeted runs or testing.

#### Fixed - Bugs and strict-mode hardening
- All `| ConvertFrom-Json` call sites outside `Invoke-AzRestJson` audited - previously any non-JSON ARM response (HTTP 204, error HTML, stray stderr on stdout) would throw uncaught under Strict Mode.
- Empty-pipeline guards added to health-failures and latest-run aggregation paths so they no longer silently return `$null`.
- Update-name sort is now deterministic (secondary sort on `$_.name`); unparseable YYMM components log a `Warning` instead of silently grouping at position 0.
- Parallel CSV log writes: each worker writes a per-job CSV; coordinator merges at the end. Eliminates line interleaving / header corruption that `Add-Content` cannot protect against.
- Tag property access is now robust to both `Hashtable` and `PSCustomObject` tag shapes returned by different ARM endpoints.
- Malformed `UpdateWindow` / `UpdateExclusions` tag values are now **blocking** by default (update skipped, `Error` logged) unless `-Force` is specified. Previously logged as a warning and the update proceeded.

#### Security
- `-UpdateRingValue` is whitelist-validated against `^[a-zA-Z0-9._-]+$` before KQL interpolation in ARG queries.
- New private helper `ConvertTo-SafeCsvField` prefixes formula-leader characters (`=`, `+`, `-`, `@`, tab) with a single quote and strips embedded CR/LF. Applied uniformly to every field written by the CSV loggers. Prevents Excel formula injection via attacker-controlled cluster name / error message.
- User-supplied output paths (`-OutputPath`, `-ExportResultsPath`, `-LogFolderPath`, `-StateFilePath`) are resolved via `[IO.Path]::GetFullPath()`, length-capped at 248 chars, and rejected if they contain `..\` traversal sequences when a relative root was expected.
- Az CLI error output is scrubbed before being written to logs: `--password <value>` / `--secret <value>` echoes masked; token-shaped substrings redacted.
- `Invoke-AzRestJson` handles mid-run token expiry: on HTTP 401 it runs `az account get-access-token` once, refreshes, and retries. Long fleet operations crossing the 1-hour token boundary no longer fail partway through.
- `Stop-AzureLocalFleetUpdate` and `New-AzureLocalFleetStatusHtmlReport` now support `ShouldProcess` (`-WhatIf` / `-Confirm`).

#### Changed - Maintenance window tag format
- **Breaking for pre-release consumers only (no one was using this yet)**: the `UpdateWindow` Azure resource tag now uses `_` as the separator between the day-spec and the time range, instead of `:`. This removes the ambiguity with the `HH:MM` time portion and makes the tag easier to read at a glance.
  - Old: `Mon-Fri:22:00-02:00`
  - **New: `Mon-Fri_22:00-02:00`**
  - Multi-window separator (`;`) and day-range separator (`-`) are unchanged.
  - The parser in `ConvertFrom-AzLocalUpdateWindow` will throw `Invalid window segment syntax` for the old format; combined with the fail-closed schedule-tag evaluation above, any cluster still carrying the old tag value will have its updates blocked until re-tagged. Use `Set-AzureLocalClusterUpdateRingTag -UpdateWindowValue 'Mon-Fri_22:00-02:00' -Force` to migrate.

#### Changed - Fleet HTML report Recent Update Run History
- Duration now uses `HH:MM:SS` fixed-width format (was `N.N hours` fractional). Easier to read, no loss of precision, survives multi-day runs (`52:15:30` for 52h 15m).
- **Attempts are now aggregated per update**: when an update runs multiple times on a cluster (a re-run after failure), the report shows **one row** with `Update Attempts = N` and `Duration = <sum of all attempts>` instead of showing just the last attempt's duration. `StartTime` reflects the earliest attempt; `State` / `Progress` / `Current Step` reflect the latest attempt.
- New **Update Attempts** column is shown **only** when at least one cluster has >1 attempt on its current update, keeping single-attempt fleets uncluttered.
- Only the most-recently-started update per cluster is displayed (one row per cluster); historical update versions from prior cycles are no longer duplicated into separate rows.

#### Changed - Cluster Information section (HTML report)
- New **Current SBE Version** column shows the solution-builder-extension version installed on each cluster, alongside the solution update version. Extracted from the `/updates` `additionalProperties.SBEVersion` of the most recent applied SBE update and surfaced through `Get-AzureLocalFleetStatusData` and the GitHub Actions / Azure DevOps fleet-status pipelines.

#### Changed - `Start-AzureLocalClusterUpdate`
- `-WhatIf` output is no longer polluted by the module's own `Write-Log` / `Write-UpdateCsvLog` side effects, internal `Env:` cleanup, or log-folder creation. Previously every internal housekeeping line produced a `What if:` row. Now only the actual ARM `POST` `apply/action` call appears in the WhatIf preview.
- `-WhatIf` runs (and `ShouldProcess`-declined runs) now count as **WouldUpdate** in the final summary and are surfaced distinctly from `Started` / `Skipped` / `Failed`. Makes dry-runs at fleet scale actually auditable.

#### Added - `Format-AzLocalDurationHuman` helper (private)
- Central helper for duration rendering; accepts `[TimeSpan]`, numeric seconds, or `HH:MM:SS` string. Emits `"1 hour 23 minutes"` style for the per-run `Get-AzureLocalUpdateRuns` output. The fleet HTML report uses its own `HH:MM:SS` formatter because it sums across attempts (see above).

#### Notes
- No breaking changes to exported functions or parameter sets. All new helpers are private.
- Az CLI remains the ARM transport for v0.7.0; a native `Invoke-RestMethod` port is deferred.

### What's New in v0.6.5

#### Fixed
- **`Set-AzureLocalClusterUpdateRingTag` now correctly applies `UpdateWindow` and `UpdateExclusions` tags from CSV** (HIGH). Inside the processing loop, four references used an undefined variable (`$cluster`) instead of the actual loop variable (`$clusterEntry`). Because `Set-StrictMode` is not enforced at module scope, the typo silently returned `$null`, so:
  - Clusters with an existing `UpdateRing` tag were skipped even when the CSV changed `UpdateWindow`/`UpdateExclusions`.
  - On new/forced writes the PATCH body only contained `UpdateRing`; `UpdateWindow`/`UpdateExclusions` columns from the CSV were never sent to Azure.
  - Round-trip `Get-AzureLocalClusterInventory` -> edit CSV -> `Set-AzureLocalClusterUpdateRingTag` now correctly preserves all three tag columns.

#### Added
- **New optional parameters `-UpdateWindowValue` and `-UpdateExclusionsValue` on `Set-AzureLocalClusterUpdateRingTag -ClusterResourceIds`**. Direct-invocation mode is now symmetrical with CSV mode and can set all three tags (`UpdateRing`, `UpdateWindow`, `UpdateExclusions`) in a single PATCH operation:

  ```powershell
  Set-AzureLocalClusterUpdateRingTag `
      -ClusterResourceIds $ids `
      -UpdateRingValue 'Wave1' `
      -UpdateWindowValue 'Mon-Fri_22:00-02:00' `
      -UpdateExclusionsValue '2026-12-20/2026-01-05' -Force
  ```

- **`Set-StrictMode -Version 1.0` is now enforced at module scope.** Catches references to uninitialized variables (the exact class of bug fixed above) at runtime instead of silently returning `$null`. All 239 Pester tests pass unchanged. `-Version Latest` was deliberately not selected because ARM REST responses legitimately omit optional properties (e.g. `additionalProperties.SBEPublisher`, `tags.UpdateRing`) and Latest would throw on every such dot-notation access.

### What's New in v0.6.4

#### Azure CLI Availability Check & Auto-Install
- **New internal function `Test-AzCliAvailable`**: Checks if Azure CLI (`az`) is installed before any `az` invocation
- In interactive sessions, prompts the user to download and install when `az` is not found
- In non-interactive environments (CI/CD pipelines), throws immediately with clear installation instructions
- All exported functions and SingleCluster code paths now call `Test-AzCliAvailable` before first `az` CLI usage

#### Fleet Status Data Collection
- **New function `Get-AzureLocalFleetStatusData`**: Single-pass data collection with parallel `Start-Job` support
- `-ThrottleLimit` parameter (default: 4, max: 8) splits cluster list into parallel batches
- `-ExportPath` exports fleet data as JSON artifact for CI/CD pipeline job passing
- `-StatusData` parameter on `New-AzureLocalFleetStatusHtmlReport` accepts pre-collected data to skip API calls
- Stable JSON schema (v1.0) with SchemaVersion, Timestamp, ModuleVersion, Scope, Readiness, ClusterDetails, LatestRuns, HealthResults

#### Update State Alignment
- All per-update state filters now use module-level constants (`$script:ReadyStates`, `$script:PrereqStates`) aligned with current ARM API states
- `ReadyToInstall` state is now recognized alongside `Ready` across all functions: `Start-AzureLocalClusterUpdate`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalClusterUpdateReadiness`, `Get-AzureLocalFleetStatusData`, `Get-AzureLocalUpdateSummary`
- Update summary state checks include `ReadyToInstall` for accurate "Update Available" counting

#### HasPrerequisite & SBE Dependency Awareness
- **`Get-AzureLocalAvailableUpdates`**: Now shows HasPrerequisite/AdditionalContentRequired counts alongside Ready counts in console output (both single-cluster and multi-cluster modes)
- **`Get-AzureLocalAvailableUpdates`**: Result objects include `PackageType` and `SBEDependency` properties for updates blocked by SBE prerequisites
- **`Get-AzureLocalAvailableUpdates`**: Summary section shows clusters blocked by SBE prerequisites with vendor dependency details (Publisher, Family, ReleaseNotes)
- **`Get-AzureLocalAvailableUpdates`**: New `-Raw` switch returns unprocessed ARM API objects for programmatic use (internal callers use this automatically)
- **`Start-AzureLocalClusterUpdate`**: Provides detailed SBE dependency info when updates are blocked by HasPrerequisite/AdditionalContentRequired state, with guidance to install the SBE from the hardware vendor
- **`Get-AzureLocalClusterUpdateReadiness`**: Surfaces `HasPrerequisiteUpdates` and `SBEDependency` in result objects for downstream consumption
- **`Get-AzureLocalClusterUpdateReadiness`**: Console output shows "Has Prerequisite (SBE update required)" for clusters with only prerequisite-blocked updates
- **`Get-AzureLocalClusterUpdateReadiness`**: Summary section includes count of clusters blocked by SBE prerequisites with vendor-specific guidance
- **`Get-AzureLocalFleetStatusData`**: Sequential collection now extracts HasPrerequisite and SBE dependency info into readiness data
- **`Get-AzureLocalFleetStatusData`**: Status output shows "Has Prerequisite" for clusters with only prerequisite-blocked updates

#### Maintenance Schedule Tag Support
- **New exported function `Test-AzureLocalUpdateScheduleAllowed`**: Master gate that evaluates `UpdateWindow` and `UpdateExclusions` Azure resource tags to determine if an update should proceed
- **New internal function `ConvertFrom-AzLocalUpdateWindow`**: Parses maintenance window tag syntax (`<days>_<HH:MM>-<HH:MM>`) including day ranges, wildcards (`*`/`Daily`), and overnight windows
- **New internal function `ConvertFrom-AzLocalUpdateExclusion`**: Parses exclusion/blackout period tag syntax (`YYYY-MM-DD/YYYY-MM-DD`) with wildcard year support for recurring patterns
- `Start-AzureLocalClusterUpdate` now checks schedule tags before applying updates; returns `ScheduleBlocked` status when outside maintenance windows or during exclusion periods
- Exclusion periods take priority over maintenance windows

#### Performance
- `New-AzureLocalFleetStatusHtmlReport` now uses single-pass data collection instead of calling 6 separate module functions
- Reduced Azure REST API calls from ~230 to ~85 for 21 clusters (~63% reduction)
- ByTag scope resolves resource IDs upfront via single ARG query instead of each downstream function querying independently
- Update summary, available updates, and health check data fetched once per cluster and reused
- Progress counter shows `[N/M]` per cluster during data collection for better visibility

#### CI/CD Pipeline Improvements
- **Apply Updates pipelines**: Summary now includes `ScheduleBlocked` count alongside Started/Skipped/Failed/HealthBlocked; adds "Actions Required" section with remediation guidance
- **Fleet Update Status pipelines**: HasPrerequisite clusters now appear as `Failed (HasPrerequisite)` in JUnit XML instead of silently passing; SBE vendor details shown in test output
- **Fleet Status JSON**: Summary block now includes `HasPrerequisite` count as a distinct metric (previously lumped into `NotReady`)
- **Fleet Status summaries**: Both GitHub Actions and Azure DevOps summaries now show `SBE Prerequisite Blocked` row and "Actions Required" section
- **Readiness CSV/JSON**: `UpdateWindow` and `UpdateExclusions` tag values now included in readiness output, so ops teams can see which clusters have schedule restrictions

#### Fixed
- `Get-AzureLocalClusterInfo`, `Invoke-AzureLocalUpdateApply`, and SingleCluster paths in `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalUpdateRuns` had no `az` CLI availability check - previously threw unhelpful `CommandNotFoundException`
- Existing auth check catch blocks now differentiate 'az not installed' from 'az not logged in' with distinct error messages
- 'Up to Date' counter now recognizes `AppliedSuccessfully` state from ARM API (was showing 0 for completed clusters)
- Recommended Update no longer shows the version a cluster is already on when state is `AppliedSuccessfully`/`UpToDate`

### What's New in v0.6.3

#### Bug Fixes, Security & Code Quality
- Fixed `-PassThru` parameter on `Get-AzureLocalUpdateSummary` (was missing from param declaration)
- `-OutputPath` now pre-validated upfront (drive existence, .html extension) to fail fast before API calls
- Portal URLs in HTML report now HTML-encoded to prevent attribute injection
- ARG KQL queries now escape single quotes in `UpdateRingValue` to prevent injection
- All dynamic HTML values consistently HTML-encoded
- `Get-CurrentStepPath` has MaxDepth=20 safety limit
- Cluster name matching uses exact segment comparison instead of suffix pattern

### What's New in v0.6.2

#### 📊 New: Fleet Status HTML Report
- **New function `New-AzureLocalFleetStatusHtmlReport`** generates self-contained HTML reports for fleet update status
- Collects readiness, update summaries, available updates, health checks, and update run history into a single report
- Executive summary cards with color-coded progress bar showing fleet-wide update adoption
- Cluster Information section with name, current version, node count, resource group, resource ID
- Cluster Status Details with Active Update column (shows in-progress/failed update) and Recommended Update
- Recent Update Run History with recursive Current Step traversal (up to 8+ levels deep)
- Health Check Failures with severity filter (Critical/Warning/Informational) and collapsible per-cluster groups for multi-cluster reports
- Azure Local purple gradient design with embedded Azure Local instance logo
- `-AllClusters` switch discovers all clusters via ARG (v0.6.2 capped at 100; v0.7.0 removes the cap - use `-MaxClusters` to trim); auto-generates title from cluster name for single-cluster reports
- Supports all input methods: `-ClusterResourceIds`, `-ClusterNames`, `-ScopeByUpdateRingTag`, `-AllClusters`
- Use `-PassThru` to capture the HTML string for email body or further processing

```powershell
# Generate HTML report for a single cluster (auto-titles as "Seattle - Update Status Report")
New-AzureLocalFleetStatusHtmlReport -ClusterNames Seattle `
    -OutputPath "C:\Reports\seattle.html" -IncludeHealthDetails -IncludeUpdateRuns

# Generate report for all clusters across the subscription (uncapped by default; use -MaxClusters to trim)
New-AzureLocalFleetStatusHtmlReport -AllClusters `
    -OutputPath "C:\Reports\fleet-all.html" -IncludeHealthDetails -IncludeUpdateRuns

# Generate report for all Wave1 clusters
New-AzureLocalFleetStatusHtmlReport -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -OutputPath "C:\Reports\wave1-status.html" -IncludeHealthDetails -IncludeUpdateRuns
```

#### ⚡ Performance: Resolve-Once Pattern
- All functions that accept `-ClusterNames` now resolve names to resource IDs **once upfront**
- Eliminates redundant API calls when multiple functions are called sequentially
- CI/CD pipelines use `-ClusterResourceIds` consistently (reduces ~800 to ~300 API calls for 100 clusters)
- `Test-AzureLocalClusterHealth` accepts `-UpdateSummary` to skip redundant fetch

### What's New in v0.6.1

#### 🏥 New: Pre-Update Health Check Validation
- **New function `Test-AzureLocalClusterHealth`** validates cluster health before applying updates
- Queries health check results from ARM (`updateSummaries` resource) to identify Critical, Warning, and Informational failures
- Critical failures block updates from being applied - this function shows you exactly what needs fixing
- Supports `-BlockingOnly` to show only update-blocking issues
- Export results to CSV, JSON, or JUnit XML for CI/CD integration

#### 🔒 Automatic Health Gate in `Start-AzureLocalClusterUpdate`
- Before applying an update, the function now automatically checks for Critical health failures (Step 3b)
- If blocking issues are found, the cluster is skipped with detailed failure information and remediation guidance
- No more cryptic "Update is blocked due to health check failure" errors without context

#### 📈 Enhanced Diagnostics in `Get-AzureLocalUpdateRuns`
- When the latest update run failed due to health check failures, the function automatically queries and displays the Critical failures
- Shows remediation steps inline so you know exactly what to fix

#### 🔇 Cleaner Console Output with `-PassThru`
- Functions no longer dump object lists to the console by default
- Formatted tables and diagnostics are still displayed — only the raw object output is suppressed
- Use `-PassThru` to return objects for pipeline/variable capture: `$results = Start-AzureLocalClusterUpdate ... -PassThru`
- CI/CD pipeline examples updated accordingly

### What's New in v0.5.6 (since v0.5.0)

#### 🚀 Fleet-Scale Operations (NEW)
Six new functions for managing updates across fleets of **1000-3000+ clusters**:

| Function | Description |
|----------|-------------|
| `Invoke-AzureLocalFleetOperation` | Orchestrates fleet-wide updates with batching, throttling, and retry logic |
| `Get-AzureLocalFleetProgress` | Real-time progress tracking with success/failure percentages |
| `Test-AzureLocalFleetHealthGate` | CI/CD health gate to prevent cascading failures between waves |
| `Export-AzureLocalFleetState` | Save operation state for resume capability |
| `Resume-AzureLocalFleetUpdate` | Resume interrupted operations from checkpoint |
| `Stop-AzureLocalFleetUpdate` | Graceful stop with state preservation |

**Enterprise-Scale Features:**
- 📦 **Batch Processing**: Process clusters in configurable batches (default: 50)
- 🔄 **Retry Logic**: Automatic retries with exponential backoff (default: 3 retries)
- 💾 **State Management**: Checkpoint/resume capability for long-running operations
- 🚦 **Health Gates**: Configurable thresholds (default: max 5% failure, min 90% success)
- 📊 **Progress Tracking**: Real-time visibility into fleet-wide operations

**Examples:**
```powershell
# Start fleet-wide update with batching
Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Production" `
    -BatchSize 100 -ThrottleLimit 20 -Force

# Check progress during operation
Get-AzureLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Production" -Detailed

# CI/CD health gate between waves
$gate = Test-AzureLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -MaxFailurePercent 2 -WaitForCompletion
if (-not $gate.Passed) { exit 1 }

# Resume after interruption
Resume-AzureLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -RetryFailed -Force
```

#### 🏷️ Fleet-Wide Tag Support for All Query Functions
Three functions now support tag-based filtering for fleet-wide operations:

| Function | New Capabilities |
|----------|------------------|
| `Get-AzureLocalUpdateSummary` | Query summaries across fleet by tag, name, or resource ID |
| `Get-AzureLocalAvailableUpdates` | List available updates across fleet by tag, name, or resource ID |
| `Get-AzureLocalUpdateRuns` | Get update run history across fleet by tag, name, or resource ID |

**New Parameters for All Three Functions:**
- `-ClusterNames` / `-ClusterResourceIds` - Query multiple specific clusters
- `-ScopeByUpdateRingTag` + `-UpdateRingValue` - Query clusters by UpdateRing tag
- `-ExportPath` - Export results to CSV, JSON, or JUnit XML (format auto-detected from extension)

**Examples:**
```powershell
# Get update summaries for all Wave1 clusters
Get-AzureLocalUpdateSummary -ScopeByUpdateRingTag -UpdateRingValue "Wave1"

# List available updates across Production clusters, export to CSV
Get-AzureLocalAvailableUpdates -ScopeByUpdateRingTag -UpdateRingValue "Production" -ExportPath "updates.csv"

# Get latest update run from all Ring2 clusters
Get-AzureLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Ring2" -Latest
```

#### 📊 Fleet Update Status Monitoring
- **New CI/CD Pipeline**: Added `fleet-update-status.yml` for both GitHub Actions and Azure DevOps
- **JUnit XML Reports**: Each cluster appears as a test case in CI/CD dashboards (passed=healthy, failed=issues)
- **Multiple Output Formats**: CSV, JSON, and JUnit XML exports for different use cases
- **Scheduled Monitoring**: Automated daily checks at 6 AM UTC with configurable scope
- **Dashboard Integration**: Results appear in GitHub Actions Tests tab and Azure DevOps Tests tab with analytics

#### ✅ Consistent Logging & Progress
- **Consistent Logging**: All functions now use `Write-Log` for consistent, timestamped, colored console output
- **Improved Progress Visibility**: `Get-AzureLocalUpdateRuns`, `Get-AzureLocalClusterUpdateReadiness`, and `Get-AzureLocalClusterInventory` now show detailed progress during API operations
- **File Logging Support**: When `$script:LogFilePath` is set, all functions write to log files
- **Severity Levels**: Messages use appropriate levels (Info=White, Warning=Yellow, Error=Red, Success=Green, Header=Cyan)

---

### What's New in v0.5.0

#### 🔐 Security Improvements
- **OpenID Connect (OIDC) Documentation**: Added comprehensive guidance for secretless authentication using federated credentials
- **Authentication Best Practices**: Documented three authentication methods ranked by security (OIDC > Managed Identity > Client Secret)
- **CI/CD Pipeline Updates**: All GitHub Actions workflows now default to OIDC authentication with `id-token: write` permission
- **Azure DevOps Guidance**: Added Workload Identity Federation setup instructions

#### 📖 Documentation
- Added authentication method comparison table with security ratings
- Updated Quick Start guide with OIDC examples
- Added links to Microsoft documentation for federated credentials setup
- Documented subject claim patterns for GitHub Actions (branch, PR, environment, tag)

---

### What's New in v0.4.2

#### 📖 Documentation
- Verified and documented that **all functions work with all three authentication methods**:
  1. **Interactive** - Standard user login via `az login`
  2. **Service Principal** - For CI/CD pipelines using `Connect-AzureLocalServicePrincipal`
  3. **Managed Identity (MSI)** - For Azure-hosted agents using `Connect-AzureLocalServicePrincipal -UseManagedIdentity`

---

### What's New in v0.4.1

#### 🚀 New Features
- **Managed Identity (MSI) Support**: `Connect-AzureLocalServicePrincipal` now supports Managed Identity authentication with `-UseManagedIdentity` switch, ideal for Azure-hosted runners, VMs, and containers

#### 🐛 Bug Fixes
- **CRITICAL**: Fixed Azure Resource Graph queries in `Get-AzureLocalClusterInventory`, `Start-AzureLocalClusterUpdate`, and `Get-AzureLocalClusterUpdateReadiness` that were returning incorrect resource types (mixed resources like networkInterfaces, virtualHardDisks instead of clusters only). The issue was caused by HERE-STRING query format causing malformed az CLI commands. Queries now use single-line string format.
- **CRITICAL**: Fixed `Set-AzureLocalClusterUpdateRingTag` failing with JSON deserialization errors when applying tags. Two issues were resolved:
  1. PowerShell/cmd.exe mangling JSON quotes when passed to `az rest --body` - now uses temp file with `@file` syntax
  2. PowerShell hashtable internal properties (`Keys`, `Values`, etc.) being included in JSON - now uses `[PSCustomObject]` with filtered `NoteProperty` members only

#### ✅ Improvements
- `Get-AzureLocalClusterInventory` no longer dumps objects to console when using `-ExportPath` (cleaner output with summary and next steps)
- Added `-PassThru` switch to `Get-AzureLocalClusterInventory` for CI/CD pipelines that need both CSV export AND returned objects

---

### What's New in v0.4.0

#### 🚀 New Features
- **Cluster Inventory Function**: New `Get-AzureLocalClusterInventory` function queries all clusters and their UpdateRing tag status
- **CSV-Based Tag Workflow**: Export inventory to CSV, edit UpdateRing values in Excel, then import back to apply tags
- **CSV Input for Tags**: `Set-AzureLocalClusterUpdateRingTag` now accepts `-InputCsvPath` for bulk tag operations
- **JUnit XML Export for CI/CD**: Export results to JUnit XML format for visualization in Azure DevOps, GitHub Actions, Jenkins, and other CI/CD tools

#### ✅ Improvements
- Renamed `-ScopeByTagName` to `-ScopeByUpdateRingTag` (now a switch parameter for clarity)
- Renamed `-TagValue` to `-UpdateRingValue` for consistency
- UpdateRing tag queries now use the standardized 'UpdateRing' tag name
- `-ExportResultsPath` and `-ExportPath` now support `.xml` extension for JUnit format
