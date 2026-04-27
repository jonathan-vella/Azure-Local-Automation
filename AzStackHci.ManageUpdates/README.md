# Azure Local - Managing Updates Module (AzStackHci.ManageUpdates)

> ⚠️ **Disclaimer**: This module is **NOT** a Microsoft supported service offering or product. It is provided as example code only, with no warranty or official support. Refer to the [MIT license](https://github.com/NeilBird/Azure-Local/blob/main/LICENSE) for further information.

**Latest Version:** v0.7.1

This folder contains the 'AzStackHci.ManageUpdates' PowerShell module for managing updates on Azure Local (Azure Stack HCI) clusters using the Azure Stack HCI REST API. The module supports both interactive use and CI/CD automation via Service Principal or Managed Identity authentication.

Azure Stack HCI REST API specification (includes update management endpoints): https://github.com/Azure/azure-rest-api-specs/blob/main/specification/azurestackhci/resource-manager/Microsoft.AzureStackHCI/StackHCI/stable/2026-02-01/hci.json

## What's New in v0.7.0

The jump from `0.6.5` to `0.7.0` is a large, fleet-scale release focused on correctness at 1500+ clusters, true parallel execution, HTML report performance, and a round of security hardening. No breaking public-surface changes. 

### Fixed - Correctness at scale
- **HIGH**: Azure Resource Graph queries were hardcoded to `az graph query --first 1000`. At 1500 clusters, 500 were silently dropped - no error, no warning. New private `Invoke-AzResourceGraphQuery` helper loops on the `$skipToken` until exhausted.
- **HIGH**: `Invoke-AzureLocalFleetOperation -ThrottleLimit` previously only affected retry-backoff math; the per-cluster loop was fully sequential. At 1500 clusters that meant 4+ hour runs. Extracted the parallel `Start-Job` pattern into a shared private helper `Invoke-FleetJobsInParallel` and rerouted all fleet operations through it. `-ThrottleLimit` now controls concurrent API calls (default 4, range 1-16). PowerShell 5.1 compatibility preserved.
- **HIGH**: `Get-AzureLocalClusterInventory` threw `The variable cannot be validated because the value '' is not a valid value for the UpdateRingValue variable.` whenever a cluster in the fleet was missing the `UpdateRing` tag. Root cause: the function's `[ValidatePattern]` parameter `$UpdateRingValue` collided with a loop-local `$updateRingValue` (PowerShell variable names are case-insensitive). Locals renamed to `$ringTagValue` / `$windowTagValue` / `$exclusionsTagValue`. `-AllClusters` reports now complete against real-world mixed-tag fleets.

### Changed - Performance (parallel by default)
- These per-cluster functions now run in parallel batches via the shared helper: `Get-AzureLocalClusterUpdateReadiness`, `Test-AzureLocalClusterHealth`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Set-AzureLocalClusterUpdateRingTag`, `Get-AzureLocalUpdateRuns`. Expected 5-10x speedup on 1500-cluster runs (readiness check from ~10 min to ~1-2 min).
- `New-AzureLocalFleetStatusHtmlReport` renderer rewritten for O(n) scaling: pre-indexed `LatestRuns` and `ClusterDetails` hashtables, HTML encoding moved to collection time, per-cluster portal URLs precomputed once. ~60% faster HTML render at 1500 clusters.
- HTML report output now written as UTF-8 **without BOM** via `[System.IO.File]::WriteAllText` + `UTF8Encoding($false)`.
- New opt-in pass-through parameters (`-UpdateSummary`, `-AvailableUpdates`) so pre-fetched data can be reused across a pipeline, avoiding redundant ARM reads.

### Changed - `-AllClusters` cap removed
- `New-AzureLocalFleetStatusHtmlReport -AllClusters` and `Get-AzureLocalFleetStatusData -AllClusters` previously truncated at the first 100 clusters silently. **The default cap is removed - all discovered clusters are now included.** New `-MaxClusters <int>` parameter (default 0 = no cap, range 1-100000) lets callers optionally trim the slice for targeted runs or testing.

### Fixed - Bugs and strict-mode hardening
- All `| ConvertFrom-Json` call sites outside `Invoke-AzRestJson` audited - previously any non-JSON ARM response (HTTP 204, error HTML, stray stderr on stdout) would throw uncaught under Strict Mode.
- Empty-pipeline guards added to health-failures and latest-run aggregation paths so they no longer silently return `$null`.
- Update-name sort is now deterministic (secondary sort on `$_.name`); unparseable YYMM components log a `Warning` instead of silently grouping at position 0.
- Parallel CSV log writes: each worker writes a per-job CSV; coordinator merges at the end. Eliminates line interleaving / header corruption that `Add-Content` cannot protect against.
- Tag property access is now robust to both `Hashtable` and `PSCustomObject` tag shapes returned by different ARM endpoints.
- Malformed `UpdateWindow` / `UpdateExclusions` tag values are now **blocking** by default (update skipped, `Error` logged) unless `-Force` is specified. Previously logged as a warning and the update proceeded.

### Security
- `-UpdateRingValue` is whitelist-validated against `^[a-zA-Z0-9._-]+$` before KQL interpolation in ARG queries.
- New private helper `ConvertTo-SafeCsvField` prefixes formula-leader characters (`=`, `+`, `-`, `@`, tab) with a single quote and strips embedded CR/LF. Applied uniformly to every field written by the CSV loggers. Prevents Excel formula injection via attacker-controlled cluster name / error message.
- User-supplied output paths (`-OutputPath`, `-ExportResultsPath`, `-LogFolderPath`, `-StateFilePath`) are resolved via `[IO.Path]::GetFullPath()`, length-capped at 248 chars, and rejected if they contain `..\` traversal sequences when a relative root was expected.
- Az CLI error output is scrubbed before being written to logs: `--password <value>` / `--secret <value>` echoes masked; token-shaped substrings redacted.
- `Invoke-AzRestJson` handles mid-run token expiry: on HTTP 401 it runs `az account get-access-token` once, refreshes, and retries. Long fleet operations crossing the 1-hour token boundary no longer fail partway through.
- `Stop-AzureLocalFleetUpdate` and `New-AzureLocalFleetStatusHtmlReport` now support `ShouldProcess` (`-WhatIf` / `-Confirm`).

### Changed - Maintenance window tag format
- **Breaking for pre-release consumers only (no one was using this yet)**: the `UpdateWindow` Azure resource tag now uses `_` as the separator between the day-spec and the time range, instead of `:`. This removes the ambiguity with the `HH:MM` time portion and makes the tag easier to read at a glance.
  - Old: `Mon-Fri:22:00-02:00`
  - **New: `Mon-Fri_22:00-02:00`**
  - Multi-window separator (`;`) and day-range separator (`-`) are unchanged.
  - The parser in `ConvertFrom-AzLocalUpdateWindow` will throw `Invalid window segment syntax` for the old format; combined with the fail-closed schedule-tag evaluation above, any cluster still carrying the old tag value will have its updates blocked until re-tagged. Use `Set-AzureLocalClusterUpdateRingTag -UpdateWindowValue 'Mon-Fri_22:00-02:00' -Force` to migrate.

### Changed - Fleet HTML report Recent Update Run History
- Duration now uses `HH:MM:SS` fixed-width format (was `N.N hours` fractional). Easier to read, no loss of precision, survives multi-day runs (`52:15:30` for 52h 15m).
- **Attempts are now aggregated per update**: when an update runs multiple times on a cluster (a re-run after failure), the report shows **one row** with `Update Attempts = N` and `Duration = <sum of all attempts>` instead of showing just the last attempt's duration. `StartTime` reflects the earliest attempt; `State` / `Progress` / `Current Step` reflect the latest attempt.
- New **Update Attempts** column is shown **only** when at least one cluster has >1 attempt on its current update, keeping single-attempt fleets uncluttered.
- Only the most-recently-started update per cluster is displayed (one row per cluster); historical update versions from prior cycles are no longer duplicated into separate rows.

### Changed - Cluster Information section (HTML report)
- New **Current SBE Version** column shows the solution-builder-extension version installed on each cluster, alongside the solution update version. Extracted from the `/updates` `additionalProperties.SBEVersion` of the most recent applied SBE update and surfaced through `Get-AzureLocalFleetStatusData` and the GitHub Actions / Azure DevOps fleet-status pipelines.

### Changed - `Start-AzureLocalClusterUpdate`
- `-WhatIf` output is no longer polluted by the module's own `Write-Log` / `Write-UpdateCsvLog` side effects, internal `Env:` cleanup, or log-folder creation. Previously every internal housekeeping line produced a `What if:` row. Now only the actual ARM `POST` `apply/action` call appears in the WhatIf preview.
- `-WhatIf` runs (and `ShouldProcess`-declined runs) now count as **WouldUpdate** in the final summary and are surfaced distinctly from `Started` / `Skipped` / `Failed`. Makes dry-runs at fleet scale actually auditable.

### Added - `Format-AzLocalDurationHuman` helper (private)
- Central helper for duration rendering; accepts `[TimeSpan]`, numeric seconds, or `HH:MM:SS` string. Emits `"1 hour 23 minutes"` style for the per-run `Get-AzureLocalUpdateRuns` output. The fleet HTML report uses its own `HH:MM:SS` formatter because it sums across attempts (see above).

### Notes
- No breaking changes to exported functions or parameter sets. All new helpers are private.
- Az CLI remains the ARM transport for v0.7.0; a native `Invoke-RestMethod` port is deferred.

> 📜 **Previous Release Notes**: See [Release History](#release-history) at the bottom of this document for v0.6.5 and earlier changes.

## Files

| File | Description |
|------|-------------|
| `AzStackHci.ManageUpdates.psd1` | PowerShell module manifest |
| `AzStackHci.ManageUpdates.psm1` | PowerShell module with functions to start updates on multiple Azure Local clusters |
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

Save this JSON to a file named `custom-role.json`, then create the custom role using Azure CLI:

```powershell
# Option 1: Create the file manually, then run:
az role definition create --role-definition custom-role.json

# Option 2: Create the file and role in one step using PowerShell:
@'
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
'@ | Out-File -FilePath "custom-role.json" -Encoding UTF8

az role definition create --role-definition custom-role.json
```

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
Import-Module .\AzStackHci.ManageUpdates.psd1
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
Import-Module .\AzStackHci.ManageUpdates.psd1
Connect-AzureLocalServicePrincipal
```

### 2. Install or Import the Module

**Option A: Install from PowerShell Gallery (Recommended)**
```powershell
# Install from PowerShell Gallery
Install-Module -Name AzStackHci.ManageUpdates -Scope CurrentUser

# Import the module
Import-Module AzStackHci.ManageUpdates
```

**Option B: Import from Local Clone**
```powershell
# Import the module from the current directory
Import-Module .\AzStackHci.ManageUpdates.psd1

# Or import using the full path
Import-Module "C:\Path\To\AzStackHci.ManageUpdates\AzStackHci.ManageUpdates.psd1"
```

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

1. **Stage**: Operator sets `UpdateSideloaded = False` on a target cluster, then sideloads the payload onto the cluster's nodes out-of-band.
2. **Block while not ready**: Any pipeline run of `Start-AzureLocalClusterUpdate` against this cluster sees `UpdateSideloaded = False` and skips with `Status = SideloadedBlocked` (visible in CSV log, JUnit XML, and HTML report skipped tally). The schedule and health gates are not even consulted.
3. **Release**: Operator confirms the payload is in place and flips `UpdateSideloaded = True`.
4. **Update**: Next pipeline run sees `True`, proceeds through schedule/health gates, and starts the update. As the run kicks off, the module writes `UpdateVersionInProgress = <update name>` to the cluster.
5. **Auto-reset**: When `Get-AzureLocalUpdateRuns` next reads runs for this cluster, it inspects the latest run. If it is `Succeeded` **and** its update name matches `UpdateVersionInProgress`, it flips `UpdateSideloaded` back to `False` and clears `UpdateVersionInProgress` in a single PATCH. The cluster is now re-armed for the next sideloaded payload.

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
- `-LogFolderPath` (Optional): Folder path for log files. Default: `C:\ProgramData\AzStackHci.ManageUpdates\`
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
- `-LogFolderPath` (Optional): Folder path for log files. Default: `C:\ProgramData\AzStackHci.ManageUpdates\`
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

Log file: C:\ProgramData\AzStackHci.ManageUpdates\UpdateRingTag_20260129_091500.log
CSV log: C:\ProgramData\AzStackHci.ManageUpdates\UpdateRingTag_20260129_091500.csv
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

## Fleet-Scale Operations (v0.5.6)

The following six functions enable enterprise-scale update management across fleets of 1000-3000+ clusters with batching, throttling, retry logic, health gates, and state management.

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

## Logging and Output

The module includes comprehensive logging capabilities for tracking update operations.

### Log Files

By default, log files are created in `C:\ProgramData\AzStackHci.ManageUpdates\` which is accessible across different user profiles. This folder is automatically created if it doesn't exist.

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
# Basic logging (logs created in default folder: C:\ProgramData\AzStackHci.ManageUpdates\)
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
| `UpdateAvailable` | Updates are available | ? Yes |
| `AppliedSuccessfully` | All updates applied | ? No updates to apply |
| `UpdateInProgress` | Update is running | ? Wait for completion |
| `UpdateFailed` | Last update failed | ?? Investigate first |
| `NeedsAttention` | Manual intervention needed | ? Resolve issues first |

### Individual Update States

| State | Description | Can Apply? |
|-------|-------------|------------|
| `Ready` | Update is ready to install | ? Yes |
| `ReadyToInstall` | Preparation complete | ? Yes |
| `HasPrerequisite` | Prerequisites required | ? Install prerequisites first |
| `Installing` | Currently installing | ? In progress |
| `Installed` | Successfully installed | ? Already done |
| `InstallationFailed` | Installation failed | ?? Retry or investigate |

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

The module supports Service Principal authentication for use in automated pipelines, and can export results in **JUnit XML format** for test result visualization in CI/CD tools.

> ðŸ“ **Complete Pipeline Examples**: For production-ready CI/CD pipeline examples including inventory collection, tag management, and update deployment workflows, see the **[Automation-Pipeline-Examples](./Automation-Pipeline-Examples/README.md)** folder. It includes:
> - Complete GitHub Actions workflows (3 pipelines)
> - Complete Azure DevOps pipelines (3 pipelines)
> - Service Principal setup instructions
> - Typical automation workflow diagrams

### JUnit XML Export for CI/CD Pipelines

Use the `.xml` extension with `-ExportResultsPath` to generate JUnit-compatible test results for CI/CD toolchains:

```powershell
# Export update results to JUnit XML
Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Ring1" -Force `
    -ExportResultsPath "C:\Results\update-results.xml"

# Export readiness check to JUnit XML
Get-AzureLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Ring1" `
    -ExportPath "C:\Results\readiness-results.xml"
```

**Supported CI/CD Tools:**

| CI/CD Tool | Integration |
|------------|-------------|
| **Azure DevOps** | Publish Test Results task |
| **GitHub Actions** | `dorny/test-reporter` or `mikepenz/action-junit-report` |
| **Jenkins** | Built-in JUnit plugin |
| **GitLab CI** | Native `artifacts:reports:junit` support |
| **TeamCity** | Built-in test report processing |

### GitHub Actions Example

```yaml
name: Update Azure Local Clusters

on:
  workflow_dispatch:
    inputs:
      update_ring:
        description: 'Update ring to target (e.g., Ring1, Ring2)'
        required: true
        default: 'Ring1'

jobs:
  update-clusters:
    runs-on: windows-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
    
    - name: Install Azure CLI
      run: |
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
        Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
    
    - name: Update Azure Local Clusters
      env:
        AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
        AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
        AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      run: |
        Import-Module ./AzureLocal-Manage-Updates-Using-AUM-APIs/AzStackHci.ManageUpdates.psd1
        
        # Authenticate using Service Principal
        Connect-AzureLocalServicePrincipal
        
        # Update clusters by tag - export to JUnit XML for visualization
        Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "${{ github.event.inputs.update_ring }}" `
            -Force -ExportResultsPath "./test-results/update-results.xml"
    
    - name: Publish Test Results
      uses: dorny/test-reporter@v1
      if: always()
      with:
        name: Azure Local Update Results
        path: test-results/update-results.xml
        reporter: java-junit
```

### Azure DevOps Pipeline Example

```yaml
trigger: none

parameters:
- name: updateRing
  displayName: 'Update Ring'
  type: string
  default: 'Ring1'
  values:
  - Ring1
  - Ring2
  - Production

pool:
  vmImage: 'windows-latest'

steps:
- task: AzureCLI@2
  displayName: 'Update Azure Local Clusters'
  inputs:
    azureSubscription: 'Your-Service-Connection'
    scriptType: 'pscore'
    scriptLocation: 'inlineScript'
    inlineScript: |
      Import-Module $(System.DefaultWorkingDirectory)/AzureLocal-Manage-Updates-Using-AUM-APIs/AzStackHci.ManageUpdates.psd1
      
      # Azure CLI is already authenticated via the AzureCLI task
      # Update clusters by tag - export to JUnit XML
      Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "${{ parameters.updateRing }}" `
          -Force -ExportResultsPath "$(Build.ArtifactStagingDirectory)/update-results.xml"

- task: PublishTestResults@2
  displayName: 'Publish Update Results'
  condition: always()
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: '$(Build.ArtifactStagingDirectory)/update-results.xml'
    testRunTitle: 'Azure Local Cluster Updates - ${{ parameters.updateRing }}'
```

### Service Principal Setup

1. **Create a Service Principal:**
```bash
az ad sp create-for-rbac --name "AzureLocal-UpdateAutomation" --role "Azure Stack HCI Administrator" --scopes /subscriptions/{subscription-id}
```

2. **Store the credentials securely:**
   - **GitHub Actions**: Add `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, and `AZURE_TENANT_ID` as repository secrets
   - **Azure DevOps**: Create a service connection with the Service Principal credentials

3. **Required permissions for the Service Principal:**
   - `Microsoft.AzureStackHCI/clusters/read`
   - `Microsoft.AzureStackHCI/clusters/updates/read`
   - `Microsoft.AzureStackHCI/clusters/updates/apply/action`
   - `Microsoft.AzureStackHCI/clusters/updateSummaries/read`
   - `Microsoft.AzureStackHCI/clusters/updateRuns/read`

## Troubleshooting

### Common Issues

1. **"Cluster not found"**: Verify the cluster name and ensure you have access to the subscription.

2. **"No updates available"**: The cluster may already be up to date. Check the update summary state.

3. **"Update not in Ready state"**: Updates may be downloading or have prerequisites. Check the update's state property.

4. **"Cluster not in valid state"**: The cluster must be "Connected" and the update summary state must be "UpdateAvailable".

5. **"Service Principal authentication failed"**: Verify the `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, and `AZURE_TENANT_ID` values are correct and the Service Principal has the required permissions.

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
