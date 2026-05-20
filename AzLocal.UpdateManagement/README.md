# Azure Local Update Management Module (AzLocal.UpdateManagement)

> ⚠️ **Disclaimer**: This module is **NOT** a Microsoft supported service offering or product. It is provided as example code only, with no warranty or official support. Refer to the [MIT license](https://github.com/NeilBird/Azure-Local/blob/main/LICENSE) for further information.

**Latest Version:** v0.7.75 - [Published in PowerShell Gallery](https://www.powershellgallery.com/packages/AzLocal.UpdateManagement/0.7.75)

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
- [What's New in v0.7.75](#whats-new-in-v0775)
- [What's New in v0.7.74](#whats-new-in-v0774)
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
  - [Cmdlet Inventory & Design (Reads vs Writes)](#cmdlet-inventory--design-reads-vs-writes)
  - [`Connect-AzLocalServicePrincipal`](#connect-azlocalserviceprincipal)
  - [`Start-AzLocalClusterUpdate`](#start-azlocalclusterupdate)
  - [`Get-AzLocalClusterUpdateReadiness`](#get-azlocalclusterupdatereadiness)
  - [`Get-AzLocalClusterInfo`](#get-azlocalclusterinfo)
  - [`Get-AzLocalUpdateSummary`](#get-azlocalupdatesummary)
  - [`Get-AzLocalAvailableUpdates`](#get-azlocalavailableupdates)
  - [`Get-AzLocalUpdateRuns`](#get-azlocalupdateruns)
  - [`Test-AzLocalClusterHealth`](#test-azlocalclusterhealth)
  - [`Get-AzLocalClusterInventory`](#get-azlocalclusterinventory)
  - [`Set-AzLocalClusterUpdateRingTag`](#set-azlocalclusterupdateringtag)
- [Fleet-Scale Operations](#fleet-scale-operations)
  - [`Invoke-AzLocalFleetOperation`](#invoke-azlocalfleetoperation)
  - [`Get-AzLocalFleetProgress`](#get-azlocalfleetprogress)
  - [`Test-AzLocalFleetHealthGate`](#test-azlocalfleethealthgate)
  - [`Export-AzLocalFleetState`](#export-azlocalfleetstate)
  - [`Resume-AzLocalFleetUpdate`](#resume-azlocalfleetupdate)
  - [`Stop-AzLocalFleetUpdate`](#stop-azlocalfleetupdate)
  - [`Test-AzLocalUpdateScheduleAllowed`](#test-azlocalupdatescheduleallowed)
  - [`Reset-AzLocalSideloadedTag`](#reset-azlocalsideloadedtag)
  - [`Get-AzLocalFleetStatusData`](#get-azlocalfleetstatusdata)
  - [`New-AzLocalFleetStatusHtmlReport`](#new-azlocalfleetstatushtmlreport)
  - [`Get-AzLocalFleetHealthFailures`](#get-azlocalfleethealthfailures)
  - [`Test-AzLocalApplyUpdatesScheduleCoverage`](#test-azlocalapplyupdatesschedulecoverage)
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
  - [What's New in v0.7.67](#whats-new-in-v0767)
  - [What's New in v0.7.66](#whats-new-in-v0766)
  - [What's New in v0.7.65](#whats-new-in-v0765)
  - [What's New in v0.7.64](#whats-new-in-v0764)
  - [What's New in v0.7.63](#whats-new-in-v0763)
  - [What's New in v0.7.61](#whats-new-in-v0761)
  - [What's New in v0.7.60](#whats-new-in-v0760)
  - [What's New in v0.7.50](#whats-new-in-v0750)
  - [What's New in v0.7.41](#whats-new-in-v0741)
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
| 2 | Discover what is in the fleet | [`Get-AzLocalClusterInventory`](#get-azlocalclusterinventory) |
| 3 | Tag clusters into rings (Wave1, Prod, Test, ...) | [`Set-AzLocalClusterUpdateRingTag`](#set-azlocalclusterupdateringtag) |
| 4 | Assess readiness for the wave | [`Get-AzLocalClusterUpdateReadiness`](#get-azlocalclusterupdatereadiness), [`Test-AzLocalClusterHealth`](#test-azlocalclusterhealth) |
| 5 | Apply the update | [`Start-AzLocalClusterUpdate`](#start-azlocalclusterupdate) (single cluster or `-ScopeByUpdateRingTag` for a wave) |
| 6 | Monitor and report | [`Get-AzLocalUpdateRuns`](#get-azlocalupdateruns), [`Get-AzLocalFleetProgress`](#get-azlocalfleetprogress), [`New-AzLocalFleetStatusHtmlReport`](#new-azlocalfleetstatushtmlreport) |

> **For CI/CD?** Skip this table and go straight to [Automation-Pipeline-Examples/README.md](./Automation-Pipeline-Examples/README.md) - it covers OIDC / Managed Identity / Service Principal setup, federated credentials, eight GitHub Actions workflows, and eight Azure DevOps pipelines (including the two pipelines introduced in v0.7.65: `Step.7_fleet-health-status` and `Step.3_apply-updates-schedule-audit`).

### Common workflows (function-invocation order)

| Scenario | Recommended order |
|----------|-------------------|
| **One-off cluster update** | `az login` -> `Get-AzLocalUpdateSummary` -> `Get-AzLocalAvailableUpdates` -> `Start-AzLocalClusterUpdate` -> `Get-AzLocalUpdateRuns` |
| **Staged wave deployment** | `Get-AzLocalClusterInventory` -> `Set-AzLocalClusterUpdateRingTag` -> `Get-AzLocalClusterUpdateReadiness -ScopeByUpdateRingTag` -> `Start-AzLocalClusterUpdate -ScopeByUpdateRingTag` -> `Get-AzLocalFleetProgress` -> `New-AzLocalFleetStatusHtmlReport` |
| **Daily fleet status report** | `Get-AzLocalFleetStatusData -AllClusters -IncludeUpdateRuns -IncludeHealthDetails -ExportPath ...` -> `New-AzLocalFleetStatusHtmlReport -StatusData $data -OutputPath ...` |
| **Daily fleet health audit (v0.7.65)** | `Get-AzLocalFleetHealthFailures -View Summary -ExportPath fleet-health-summary.csv` -> review top failure reasons by cluster impact -> drill into [`Get-AzLocalFleetHealthFailures -View Detail`](#get-azlocalfleethealthfailures) for per-cluster remediation |
| **Schedule coverage drift audit (v0.7.65)** | `Test-AzLocalApplyUpdatesScheduleCoverage -View Audit -PipelineYamlPath .\.github\workflows` -> for any `Uncovered` rows, copy the `RequiredCronUTC` value and paste it into `Step.5_apply-updates.yml` -> re-run `-View Audit` to confirm `Covered` -> wire the bundled `Step.3_apply-updates-schedule-audit.yml` pipeline (weekly Mon 05:00 UTC) so future tag drift is caught automatically. Full runbook: [`Automation-Pipeline-Examples/README.md` section 8.3](./Automation-Pipeline-Examples/README.md#83-end-to-end-runbook-apply-updates-schedule-coverage-audit) |
| **Pre-update health gate (CI/CD)** | `Test-AzLocalClusterHealth -BlockingOnly` -> `Test-AzLocalUpdateScheduleAllowed` -> `Test-AzLocalFleetHealthGate` -> proceed only on pass |
| **Sideloaded payload (v0.7.1)** | Operator sets `UpdateSideloaded=False` -> stage payload out-of-band -> operator flips `UpdateSideloaded=True` -> `Start-AzLocalClusterUpdate` (auto-stamps `UpdateVersionInProgress`) -> `Get-AzLocalUpdateRuns` (auto-resets tags on success) -> `Reset-AzLocalSideloadedTag -Force` only if a tag gets stuck |
| **Pause / resume long fleet run** | `Stop-AzLocalFleetUpdate -SaveState` -> ... -> `Resume-AzLocalFleetUpdate -StateFilePath ...` |
| **Recover from emergency** | `Stop-AzLocalFleetUpdate` -> `Test-AzLocalClusterHealth` (assess) -> `Resume-AzLocalFleetUpdate -RetryFailed` |

> Most CI/CD pipelines in [Automation-Pipeline-Examples/](Automation-Pipeline-Examples/) are direct implementations of one of these workflows. Start there if you want a copy-pasteable end-to-end pipeline.

## What's New in v0.7.75

v0.7.75 is a **hardening** release on top of v0.7.74. v0.7.74 patched the `Test-AzLocalApplyUpdatesScheduleCoverage` cross-platform-noise bug at the **yml layer** by adding `-Platform GitHubActions` / `-Platform AzureDevOps` arguments to the bundled Step.3 yml templates - but that fix only takes effect for consumers who refresh their yml via `Update-AzLocalPipelineExample`. Consumers whose Step.3 yml is a verbatim pre-v0.7.74 copy (i.e. they copied it once early on and have not run `Update-AzLocalPipelineExample` since) still see both the GitHub Actions snippet AND the Azure DevOps snippet in their Step Summary, because their yml does not pass `-Platform` and the cmdlet's default is `-Platform Both`. v0.7.75 closes that gap by adding the same auto-selection at the **cmdlet layer** so stale yml self-heals at runtime. Pipeline pin bumps to `'0.7.75'`; refresh existing copies via `Update-AzLocalPipelineExample` (still recommended for the pin bump, but the noise fix no longer requires it).

### Test-AzLocalApplyUpdatesScheduleCoverage auto-detects the CI host platform when -Platform is omitted

When the caller does **not** bind `-Platform`, the cmdlet inspects the well-known CI environment variables and self-selects:

- `$env:GITHUB_ACTIONS -eq 'true'` -> `-Platform GitHubActions` (emit only the GitHub Actions snippet)
- `$env:TF_BUILD -eq 'True'` OR any non-empty `$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI` -> `-Platform AzureDevOps` (emit only the Azure DevOps snippet)
- Neither set (interactive operator-at-workstation) -> existing `-Platform Both` default preserved (emit both side by side)

Detection is gated on `$PSBoundParameters.ContainsKey('Platform')` so an **explicit** caller value (including an explicit `-Platform Both`) always wins over the auto-detect. Effect on stale-yml consumers: the very next workflow run against the v0.7.75 module emits only the GH snippet on GitHub Actions runners and only the ADO snippet on Azure DevOps agents - **no yml change required**. The v0.7.74 explicit `-Platform GitHubActions` / `-Platform AzureDevOps` arguments in the bundled yml stay in place as defence in depth so runs against older modules continue to behave correctly.

### Audit confirmed scope - only Test-AzLocalApplyUpdatesScheduleCoverage needed the fix

Before adding the auto-detect, every exported cmdlet that branches its output by platform was audited. Only `Test-AzLocalApplyUpdatesScheduleCoverage` had the cross-platform-noise symptom (it is the only cmdlet whose default branches its emitted **snippet** by platform). `Copy-AzLocalPipelineExample` and `Update-AzLocalPipelineExample` were intentionally NOT changed: `Copy-AzLocalPipelineExample`'s default `'All'` is correct for the operator-at-workstation case (copy both platforms' samples so the operator can choose); `Update-AzLocalPipelineExample` is mandatory-no-default by design so the operator must opt into which existing destination to refresh. All other GH-vs-ADO conditional output happens **inside** the yml templates (`>> $env:GITHUB_STEP_SUMMARY`, `##vso[task.uploadsummary]`), not in cmdlets - cmdlets emit platform-neutral PowerShell that the yml then routes.

### Test coverage

Four new Pester tests (AS7-AS10) in the existing `Test-AzLocalApplyUpdatesScheduleCoverage` Describe verify all four auto-detect cases:

- **AS7** - `$env:GITHUB_ACTIONS='true'` + no `-Platform` -> GH snippet only.
- **AS8** - `$env:TF_BUILD='True'` + no `-Platform` -> ADO snippet only.
- **AS9** - `$env:GITHUB_ACTIONS='true'` + explicit `-Platform Both` -> both snippets (explicit-wins / auto-detect suppressed).
- **AS10** - no CI env vars + no `-Platform` -> both snippets (interactive default preserved).

`BeforeEach` / `AfterEach` blocks clear `$env:GITHUB_ACTIONS`, `$env:TF_BUILD`, and `$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI` so the new tests do not pollute or depend on the calling environment.

### Pipeline pin bumps + migration

All 14 `Step.{1..7}.yml` files (7 GitHub Actions + 7 Azure DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.74'` to `'0.7.75'`. Refresh existing copies via the marker-aware merge (preserves operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs):

```powershell
Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps
```

### Compatibility

All v0.7.75 changes are backward compatible. `[ValidateSet('GitHubActions','AzureDevOps','Both')] [string]$Platform = 'Both'` is unchanged - the default value is still `'Both'`, the new behaviour only fires when the caller does **not** bind the parameter. Interactive operators see no change. Operators who explicitly want both snippets in a CI run (rare - e.g. one-off comparison) can pass `-Platform Both` explicitly; the `$PSBoundParameters.ContainsKey('Platform')` guard ensures explicit binding always wins.

> Previous release notes have moved into the [Release History](#release-history) appendix at the bottom of this document.

### Step.3 markdown render fix (was rendering as one grey code block)

`Test-AzLocalApplyUpdatesScheduleCoverage -View Recommend -ExportPath *.md` was wrapping the multi-section snippet inside an outer ```yaml ... ``` fence. From v0.7.69 onwards the snippet itself carries markdown headings, action-required tables, AND its own **inner** ```yaml ... ``` fence around just the cron block. CommonMark fence-matching is by triple-backtick count: the outer ```yaml opened fence A; the inner ``` closed fence A; the outer ``` then **opened a new fence that was never closed**. Result: every markdown element the Step.3 pipeline appended after the recommend block (`### Audit Detail - Cron coverage` table, `### Reports Available` list, timestamp) was swallowed into the unclosed fence and rendered as a single grey monospace code block. The cmdlet now emits the snippet verbatim - the inner pair stays balanced, and downstream content renders as proper markdown again.

### Step.4 critical-count under-reporting fix (was 0, should be N)

`Step.4_assess-update-readiness.yml` (GH + ADO) was reporting `Critical health failures: 0` in the markdown summary while the JUnit XML showed 46 critical findings. Root cause: the pipeline was filtering `$health | Where-Object { $_.Severity -eq 'Critical' }`, but `Test-AzLocalClusterHealth -PassThru` returns **per-cluster summary objects** (`ClusterName`, `HealthState`, `Passed`, `CriticalCount`, `WarningCount`, `Failures` (nested array)), NOT flat finding rows. `Severity` lives on items inside the nested `Failures` array; the outer summary has `CriticalCount` instead. The pipeline now aggregates correctly via `($health | Measure-Object -Property CriticalCount -Sum).Sum` and counts affected clusters via `@($health | Where-Object { [int]$_.CriticalCount -gt 0 }).Count`.

### Step.3 `-View Recommend` - new "Action required - simplify unparseable cron expression(s)" section

When one or more YAML cron lines used syntax the advisor cannot evaluate (DayOfMonth restrictions, step values, named day-of-week tokens), the Audit view surfaced them as `UnparseableCron` rows but the Recommend view ignored them - the operator had to cross-reference the Audit Detail table to find each one. `-View Recommend` now emits a new `## Action required - simplify unparseable cron expression(s)` section between the schedule-fix sections (`add these rings`, `prune orphaned rings`) and the cron-coverage section. The table lists every offending cron with its source `file:line` and the parser's error message so the operator can rewrite the line directly from the Step Summary. Sequenced **before** cron coverage so parser-blind crons are fixed BEFORE the operator accepts the cron-coverage recommendation (which may otherwise over-suggest entries that duplicate what an already-correct-but-unparseable line is doing). When only one action overall applies the `(N of M)` numbering prefix is still dropped.

### Step.6 Update Run History table - Cluster portal link + collapsible Verbose Error

The `### Update Run History and Error Details` markdown table in the Step.6 pipeline summary gains two UX upgrades:
- **Cluster Name** renders as a `[ClusterName](portalUrl)` markdown link so the operator can jump straight to the Azure portal cluster blade. The per-row `ClusterPortalUrl` is now projected directly by `Get-AzLocalUpdateRunFailures` (new property in v0.7.71, see below) so the link is fleet-wide accurate (each row carries its own subscriptionId-bearing resource id).
- **Verbose Error Details** renders inside an inline `<details><summary>Show error</summary><br><code>...</code></details>` block so the full parser/orchestrator stack is preserved (no more 250-char truncation) but the table stays scannable - rows expand on click. HTML-special chars (`<`, `>`, `&`) are escaped to keep the renderer honest; newlines collapse to `<br>` so multi-line stack traces remain readable inside the collapsible block; pipes are escaped so the table row stays intact.

Both changes apply to GH Actions and Azure DevOps twins.

### `Get-AzLocalUpdateRunFailures` - new `ClusterPortalUrl` property

Every output row now carries a `ClusterPortalUrl` property (`https://portal.azure.com/#@/resource{ClusterResourceId}`) alongside the existing `UpdateRunPortalUrl`. Consumed by Step.6 to render Cluster Name as a deep link, and available to any other consumer that wants a cluster portal link without rebuilding the URL.

### GitHub Actions: AZURE_SUBSCRIPTION_ID is now a Variable, not a Secret

All 8 GitHub Actions `Step.*.yml` workflows now read the Azure subscription id from `vars.AZURE_SUBSCRIPTION_ID` instead of `secrets.AZURE_SUBSCRIPTION_ID`. The value is consumed **ONLY** by `azure/login@v3` to set the default `az account` context for the small subset of cmdlets that REQUIRE a single-subscription default. It is **NOT** used to scope Azure Resource Graph queries (the module's `Invoke-AzResourceGraphQuery` helper omits `--subscriptions` when no `-SubscriptionId` is supplied, so ARG runs fleet-wide against every subscription the federated identity can read) and it is **NOT** interpolated into portal URLs (every cmdlet projects `subscriptionId` per-row from ARG and builds portal deep-links from that, so each link points to the cluster's actual subscription regardless of the workflow's default context). Treating the id as a Variable also means it appears plaintext in workflow logs, matching its public non-sensitive nature, and removes the need for an extra Secret rotation in tenants where the value already lives in a tenant-scope Variable. Azure DevOps pipelines were already authenticating via a service connection and need no change.

### Pipeline pin bumps + migration

All 16 `Step.*.yml` files (8 GitHub Actions + 8 Azure DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.70'` to `'0.7.71'`. Refresh existing copies via the marker-aware merge (preserves operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs):

```powershell
Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps
```

### Compatibility

All v0.7.71 changes are backward compatible. The new `ClusterPortalUrl` property on `Get-AzLocalUpdateRunFailures` is additive; the new `## Action required - simplify unparseable cron expression(s)` section in `-View Recommend` only renders when unparseable cron lines exist; the GH Variable switch is a per-tenant setup change (see updated docs in `Automation-Pipeline-Examples/README.md`).

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
| Monitor update runs | `Microsoft.AzureStackHCI/clusters/updates/updateRuns/read` |
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
    "Microsoft.AzureStackHCI/clusters/updates/updateRuns/read",
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
    "Microsoft.AzureStackHCI/clusters/updates/updateRuns/read",
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
Connect-AzLocalServicePrincipal -UseManagedIdentity

# For user-assigned managed identity, specify the client ID
Connect-AzLocalServicePrincipal -UseManagedIdentity -ManagedIdentityClientId "your-client-id"
```

**OpenID Connect (OIDC) for CI/CD:**
```yaml
# In GitHub Actions - OIDC authentication (no client secret).
# AZURE_TENANT_ID and AZURE_SUBSCRIPTION_ID are repository *Variables* (vars.*) not Secrets.
# Both are public ARM/AAD identifiers (not credentials) and each is consumed in exactly one
# place here: the `tenant-id:` / `subscription-id:` inputs to azure/login@v3, which exchange
# the OIDC token in the named tenant and set the runner's default `az account` context. The
# bundled cmdlets run Azure Resource Graph queries fleet-wide (no --subscriptions scoping)
# and build portal deep-link URLs from the per-row `subscriptionId` returned by ARG.
- name: Azure CLI Login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
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
Connect-AzLocalServicePrincipal
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
Copy-AzLocalPipelineExample

# Or only the GitHub Actions YAML, into a target folder of your choice
Copy-AzLocalPipelineExample -Destination C:\repos\my-fleet -Platform GitHub
```

The function prints a short "next steps" summary pointing at the copied README and the platform-specific YAML folder. See [`Automation-Pipeline-Examples/README.md`](Automation-Pipeline-Examples/README.md) for the full step-by-step setup guide.

### 3. Start an Update on a Single Cluster

```powershell
# Start update on a single cluster (will prompt for confirmation)
Start-AzLocalClusterUpdate -ClusterNames "MyCluster01" -ResourceGroupName "MyRG"

# Start update without prompting (use with caution)
Start-AzLocalClusterUpdate -ClusterNames "MyCluster01" -ResourceGroupName "MyRG" -Force
```

### 4. Start Updates on Multiple Clusters

```powershell
# Update multiple clusters in the same resource group
Start-AzLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02", "Cluster03") -ResourceGroupName "MyRG"

# Update clusters (function will search across all resource groups)
Start-AzLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02")
```

### 5. Start a Specific Update

```powershell
# Apply a specific update version
Start-AzLocalClusterUpdate -ClusterNames "MyCluster01" -UpdateName "Solution12.2601.1002.38"
```

### 6. Check Update Progress

```powershell
# Get update run status
Get-AzLocalUpdateRuns -ClusterName "MyCluster01" -ResourceGroupName "MyRG"
```

### 7. Set Up Update Management Tags for Staged Rollouts

Three Azure resource tags control how clusters are grouped and when updates are applied:

| Tag | Purpose | Required? | Set By |
|-----|---------|-----------|--------|
| `UpdateRing` | Groups clusters into deployment waves (e.g., Pilot, Wave1, Production) | **Yes** - needed for `-ScopeByUpdateRingTag` | `Set-AzLocalClusterUpdateRingTag` or CSV import |
| `UpdateWindow` | Defines allowed maintenance windows in UTC (e.g., `Sat-Sun_02:00-06:00`) | Optional | CSV import via `Set-AzLocalClusterUpdateRingTag` |
| `UpdateExclusions` | Defines blackout/change-freeze periods (e.g., `2026-12-20/2027-01-03`) | Optional | CSV import via `Set-AzLocalClusterUpdateRingTag` |
| `UpdateSideloaded` | Sideloaded-payload gate. Values `True`/`False`/`1`/`0` (case-insensitive). When `False`, `Start-AzLocalClusterUpdate` skips the cluster with `Status = SideloadedBlocked`. Operator-set. | Optional (only used by the sideloaded-payload workflow) | Operator (Azure portal, CLI, or your tagging pipeline). Auto-reset to `False` by `Get-AzLocalUpdateRuns` / `Reset-AzLocalSideloadedTag` after the staged update succeeds. |
| `UpdateVersionInProgress` | Module-managed companion to `UpdateSideloaded`. Holds the staged update name (e.g. `Solution12.2604.1003.209`). | **Do not set manually.** | Module: written by `Start-AzLocalClusterUpdate` at update start; cleared by `Get-AzLocalUpdateRuns` / `Reset-AzLocalSideloadedTag` once the matching run succeeds. |

> ℹ️ **Tag matching is case-insensitive throughout this module.** Tag *names* (`UpdateRing`, `UpdateWindow`, `UpdateExclusions`) and tag *values* (the ring name like `Prod1`, day tokens like `Mon`, the `Daily` keyword) are all compared without regard to case. So `prod1`, `Prod1`, and `PROD1` resolve to the same set of clusters via `-ScopeByUpdateRingTag -UpdateRingValue 'Prod1'` (Azure Resource Graph `=~` operator), and `Mon-Fri`, `mon-fri`, and `MON-FRI` parse to the same maintenance window. This applies to every function that scopes clusters by tag, every CSV import path, and the `UpdateWindow` / `UpdateExclusions` parsers. Note: the day tokens themselves still require the strict 3-letter form — `Mon Tue Wed Thu Fri Sat Sun` — case doesn't matter, but `Thur` / `Tues` / `Friday` will be rejected (see the `UpdateWindow` section below for the full table).

> **What happens if you only set `UpdateRing`?** Updates proceed immediately with **no schedule restrictions**. The `UpdateWindow` and `UpdateExclusions` tags are entirely optional - if neither is present on a cluster, the schedule check returns "No schedule restrictions defined" and the update starts as soon as the pipeline runs. Add `UpdateWindow` and `UpdateExclusions` tags when you need to control *when* updates can be applied.

**Step 1: Inventory clusters and export to CSV**
```powershell
# Get all clusters with their current tags, export to CSV
Get-AzLocalClusterInventory -ExportPath "C:\Temp\cluster-inventory.csv"
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

  > ⏱️ **Important - `UpdateWindow` controls when an update is allowed to *START*, not how long it takes to complete.** The window is a **start gate** evaluated by `Test-AzLocalUpdateScheduleAllowed` at the moment `Start-AzLocalClusterUpdate` runs. Once the update has started, it runs to completion (or failure) regardless of whether the window is still open - Azure Local update runs are **not** paused, throttled, or aborted when the window closes. A typical Azure Local platform update can take **several hours** on a multi-node cluster (node drains, reboots, firmware/driver/SBE steps, validation), and a "happy path" run with no issues is still measured in hours, not minutes.
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
Set-AzLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\cluster-inventory.csv"

# Preview changes first with -WhatIf
Set-AzLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\cluster-inventory.csv" -WhatIf

# Force overwrite existing tags
Set-AzLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\cluster-inventory.csv" -Force
```

The function reads `UpdateWindow` and `UpdateExclusions` columns from the CSV (if present) and sets them alongside the `UpdateRing` tag in a single PATCH operation. Existing tags on the cluster are preserved.

**Step 4: Verify tags were applied**
```powershell
# Re-run inventory to confirm all tags
Get-AzLocalClusterInventory
```

**Step 5: Test schedule logic interactively (optional)**
```powershell
# Test if a specific time would be allowed by a maintenance window
Test-AzLocalUpdateScheduleAllowed -UpdateWindow "Sat-Sun_02:00-06:00" -UpdateExclusions "2026-12-20/2027-01-03"

# Test a specific future time
Test-AzLocalUpdateScheduleAllowed -UpdateWindow "Sat_02:00-06:00" -TestTime ([datetime]"2026-04-19 03:00:00")
```

**Step 6: Update clusters by UpdateRing**
```powershell
# Update all clusters in the "Pilot" ring first
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Pilot" -Force

# After validation, update Wave1
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force

# Finally, update Production
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Production" -Force
```

> 📝 **Note**: Tag operations require `Microsoft.Resources/tags/read` and `Microsoft.Resources/tags/write` permissions. Cluster inventory queries require `Microsoft.ResourceGraph/resources/read`. See [RBAC Requirements](#rbac-requirements) for the complete list. The v0.7.1 sideloaded-payload workflow (`UpdateSideloaded` / `UpdateVersionInProgress`) reads and writes through the same two tag permissions - **no new RBAC required**.

### 7a. Sideloaded Payload Workflow (v0.7.1)

Use this workflow when an admin manually copies an Azure Local update payload onto a cluster (sideloading) and wants the module to gate `Start-AzLocalClusterUpdate` until the payload is in place, then automatically clear the gate once the run succeeds.

> ✅ **Fully opt-in.** Clusters that do not have the `UpdateSideloaded` tag behave exactly as in v0.7.0 - the gate is bypassed entirely and updates proceed through the existing schedule/health checks. You only "join" the workflow by setting the tag on a specific cluster when you want to stage a sideloaded payload. No new RBAC, no fleet-wide opt-out switch needed.

**Two tags coordinate the workflow:**

| Tag | Set by | Values | Purpose |
|-----|--------|--------|---------|
| `UpdateSideloaded` | **Operator** (you) | `True` / `False` / `1` / `0` (case-insensitive) | When `False`/`0`, `Start-AzLocalClusterUpdate` skips the cluster with `Status = SideloadedBlocked`. When `True`/`1`, updates proceed normally. Empty/missing tag = no sideloaded gate (legacy behaviour). |
| `UpdateVersionInProgress` | **Module** (do not set manually) | The update name (e.g. `Solution12.2604.1003.209`) | Written automatically when an update kicks off. Cleared automatically once the matching run succeeds. Used to ensure auto-reset only fires for the run we actually started. |

**Typical flow (per cluster):**

1. **Stage**: Operator sets `UpdateSideloaded = False` on a target cluster, then sideloads the payload onto the cluster's nodes out-of-band. See [Import and discover Azure Local updates in offline / disconnected scenarios](https://learn.microsoft.com/en-us/azure/azure-local/update/import-discover-updates-offline-23h) for information and download links required to sideload updates.

   Set the gate tag on a cluster using the Az PowerShell module. `-Operation Merge` preserves all other tags already on the cluster (e.g. `UpdateRing`) and only adds/updates the `UpdateSideloaded` key:

   ```powershell
   $clusterId = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.AzureStackHCI/clusters/<cluster-name>'
   Update-AzTag -ResourceId $clusterId -Tag @{ UpdateSideloaded = 'False' } -Operation Merge
   ```

2. **Block while not ready**: Any pipeline run of `Start-AzLocalClusterUpdate` against this cluster sees `UpdateSideloaded = False` and skips with `Status = SideloadedBlocked` (visible in CSV log, JUnit XML, and HTML report skipped tally). The schedule and health gates are not even consulted.
3. **Release**: Operator confirms the payload is in place and flips `UpdateSideloaded = True`:

   ```powershell
   Update-AzTag -ResourceId $clusterId -Tag @{ UpdateSideloaded = 'True' } -Operation Merge
   ```
4. **Update**: Next pipeline run sees `True`, proceeds through schedule/health gates, and starts the update. As the run kicks off, the module writes `UpdateVersionInProgress = <update name>` to the cluster.
5. **Auto-reset**: When `Get-AzLocalUpdateRuns` next reads runs for this cluster, it inspects the latest run. If it is `Succeeded` **and** its update name matches `UpdateVersionInProgress`, it flips `UpdateSideloaded` back to `False` and clears `UpdateVersionInProgress` in a single PATCH. The cluster is now re-armed for the next sideloaded payload.

**Auto-reset action values** (returned by `Reset-AzLocalSideloadedTag` and surfaced in `Get-AzLocalUpdateRuns` verbose logs):

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
Reset-AzLocalSideloadedTag -ClusterName 'mycluster' -ResourceGroupName 'rg-fleet' -WhatIf

# Force-reset a stuck cluster (skips the run-success / version-match check). Use with care.
Reset-AzLocalSideloadedTag -ClusterName 'mycluster' -ResourceGroupName 'rg-fleet' -Force

# Bulk reset by tag (explicit scope - no implicit -AllClusters)
Reset-AzLocalSideloadedTag -ScopeByUpdateRingTag -UpdateRingValue 'Wave1'
```

`Reset-AzLocalSideloadedTag` is the same logic the auto-reset path uses; the difference is the entry point. Default behaviour requires `latest run = Succeeded` and a case-insensitive match between the run's update name and `UpdateVersionInProgress`. `-Force` bypasses both checks.

**Opt out of auto-reset:**

```powershell
# Read-only paths can suppress the PATCH
Get-AzLocalUpdateRuns -ClusterName 'mycluster' -ResourceGroupName 'rg-fleet' -SkipSideloadedReset
```

> ℹ️ **Concurrent updates**: Azure Local's on-cluster ECE component already serialises updates - it will refuse to start a second run while another is in flight or in a failed state. The match-on-update-name guardrail in this workflow is a defense-in-depth check on top of that, not a replacement for it.

> 🔐 **RBAC**: Unchanged. The workflow only reads and writes cluster tags, which already require `Microsoft.Resources/tags/read` and `Microsoft.Resources/tags/write` (see [RBAC Requirements](#rbac-requirements)).

### 8. Assess Readiness and Health BEFORE Applying Updates (Recommended)

Before rolling updates to a wave, confirm every cluster in that wave is actually ready - on the supported solution version, healthy, with an update in a `Ready` / `ReadyToInstall` state, and not blocked by an SBE prerequisite. `Start-AzLocalClusterUpdate` will already skip unhealthy clusters automatically, but running the assessment as a separate **readiness report** surfaces exactly what needs remediation so you can open tickets in parallel with the rollout - you do not need to block the entire wave for one or two unhealthy clusters.

**Step 1: Run the readiness check for the target ring**

```powershell
# Returns one row per cluster with: ReadyForUpdate, HealthState, UpdateState,
# HasPrerequisiteUpdates, SBEDependency, UpdateWindow, UpdateExclusions
$readiness = Get-AzLocalClusterUpdateReadiness `
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
$health = Test-AzLocalClusterHealth `
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

After remediation, re-run Step 1 and Step 2 to confirm `ReadyForUpdate = $true` and `Critical = 0` for the clusters you've fixed. Clusters that are still red can stay in the ring - `Start-AzLocalClusterUpdate` will skip them - but track them as follow-ups so the fleet converges over time.

**Step 4: Only now, apply updates**

```powershell
# Updates only start if the maintenance window / exclusion tags allow it.
# Start-AzLocalClusterUpdate will *still* re-check health per cluster and
# skip anything that has regressed since the assessment.
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' -Force
```

**Step 5: Watch progress and capture a report**

```powershell
# Follow the run (PS 5.1 and Core safe)
Get-AzLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue 'Wave1'

# Produce a self-contained HTML report for stakeholders (works for any scope)
New-AzLocalFleetStatusHtmlReport `
    -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' `
    -OutputPath 'C:\Reports\wave1-status.html' `
    -IncludeHealthDetails -IncludeUpdateRuns
```

> 💡 **CI/CD**: this same assess -> remediate -> apply flow is wired into the pipeline examples under `Automation-Pipeline-Examples/`: see the `Step.4_assess-update-readiness.yml` pipeline (report-only) and the `check-readiness` job inside `Step.5_apply-updates.yml`.

## Available Functions

### Cmdlet Inventory & Design (Reads vs Writes)

This table is the canonical index of every public cmdlet the module ships. It is the answer to "what does each function actually do, and does it touch Azure?"

**Design principle.** This module is **ARG-first for READs and ARM-fan-out for WRITEs**. Read cmdlets converge on a single Azure Resource Graph query no matter how many clusters are in scope, so they finish in seconds and do not need parallelism (no `-ThrottleLimit` parameter). Write cmdlets still call ARM (or Azure REST) once per cluster - ARG is a read-only plane and cannot mutate resources - so write cmdlets keep `-ThrottleLimit` to bound concurrent fan-out. Composite cmdlets that only delegate to other module cmdlets inherit the type of the cmdlets they call.

**Type legend:**

- **READ** - calls only Azure Resource Graph and/or Azure REST GET. No state changes.
- **READ (composite)** - calls other READ cmdlets in this module, optionally writes a local report file.
- **READ (validation)** - evaluates local inputs (schedules, pipeline YAML); no Azure calls.
- **WRITE** - mutates Azure resources via ARM PUT/POST/PATCH or tag update.
- **WRITE (local)** - writes only to the local filesystem (scaffolding/templates).
- **AUTH** - establishes an Azure context; no data-plane calls.

#### Azure data-plane: READ cmdlets

| Cmdlet | Type | Target |
|---|---|---|
| [`Get-AzLocalClusterInfo`](#get-azlocalclusterinfo) | READ | Azure REST (single cluster lookup) |
| [`Get-AzLocalClusterInventory`](#get-azlocalclusterinventory) | READ | Azure Resource Graph |
| [`Get-AzLocalAvailableUpdates`](#get-azlocalavailableupdates) | READ | Azure Resource Graph |
| [`Get-AzLocalUpdateSummary`](#get-azlocalupdatesummary) | READ | Azure Resource Graph |
| [`Get-AzLocalUpdateRuns`](#get-azlocalupdateruns) | READ | Azure Resource Graph |
| `Get-AzLocalUpdateRunFailures` | READ | Azure Resource Graph |
| [`Get-AzLocalClusterUpdateReadiness`](#get-azlocalclusterupdatereadiness) | READ | Azure Resource Graph |
| [`Get-AzLocalFleetHealthFailures`](#get-azlocalfleethealthfailures) | READ | Azure Resource Graph |
| `Get-AzLocalFleetHealthOverview` | READ | Azure Resource Graph |
| `Get-AzLocalLatestSolutionVersion` | READ | Microsoft public catalog (`aka.ms/AzureEdgeUpdates`, unauthenticated) |
| [`Get-AzLocalFleetProgress`](#get-azlocalfleetprogress) | READ | Azure Resource Graph |
| [`Test-AzLocalClusterHealth`](#test-azlocalclusterhealth) | READ | Azure Resource Graph |
| [`Test-AzLocalFleetHealthGate`](#test-azlocalfleethealthgate) | READ (composite) | Azure (via `Test-AzLocalClusterHealth`) |
| [`Get-AzLocalFleetStatusData`](#get-azlocalfleetstatusdata) | READ (composite) | Azure (delegates to four READ cmdlets above) |
| [`New-AzLocalFleetStatusHtmlReport`](#new-azlocalfleetstatushtmlreport) | READ (composite) | Azure + local HTML report file |
| [`Export-AzLocalFleetState`](#export-azlocalfleetstate) | READ (composite) | Azure + local JSON state file |

#### Azure data-plane: WRITE cmdlets

| Cmdlet | Type | Target |
|---|---|---|
| [`Start-AzLocalClusterUpdate`](#start-azlocalclusterupdate) | **WRITE** | Azure REST (ARM `PUT .../updateRuns/{id}`) |
| [`Stop-AzLocalFleetUpdate`](#stop-azlocalfleetupdate) | **WRITE** | Azure REST (ARM `POST .../updateRuns/{id}/cancel`) |
| [`Resume-AzLocalFleetUpdate`](#resume-azlocalfleetupdate) | **WRITE** | Azure REST (ARM `POST .../updateRuns/{id}/retry`) |
| [`Invoke-AzLocalFleetOperation`](#invoke-azlocalfleetoperation) | **WRITE** | Azure REST (generic per-cluster mutation) |
| [`Set-AzLocalClusterUpdateRingTag`](#set-azlocalclusterupdateringtag) | **WRITE** | Azure tags (`UpdateRing`, `UpdateWindow`) |
| [`Reset-AzLocalSideloadedTag`](#reset-azlocalsideloadedtag) | **WRITE** | Azure tags (`UpdateSideloaded`, `UpdateVersionInProgress`) |

#### Local-only validation and scaffolding

| Cmdlet | Type | Target |
|---|---|---|
| [`Test-AzLocalApplyUpdatesScheduleCoverage`](#test-azlocalapplyupdatesschedulecoverage) | READ (validation) | Local pipeline YAML + tag inputs |
| [`Test-AzLocalUpdateScheduleAllowed`](#test-azlocalupdatescheduleallowed) | READ (validation) | Local schedule input |
| [`Connect-AzLocalServicePrincipal`](#connect-azlocalserviceprincipal) | AUTH | Az PowerShell context (no data-plane calls) |
| [`Copy-AzLocalPipelineExample`](#copy-azlocalpipelineexample) | WRITE (local) | Local file scaffold |
| `Copy-AzLocalItsmSample` | WRITE (local) | Local file scaffold |

#### ITSM integration

| Cmdlet | Type | Target |
|---|---|---|
| `Get-AzLocalItsmConfig` | READ | Local ITSM config file |
| `Test-AzLocalItsmConnection` | READ | External ITSM endpoint |
| `New-AzLocalIncident` | **WRITE** | External ITSM (creates ticket) |

### `Copy-AzLocalPipelineExample`

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
# Default (-Platform All): copies the full sample tree into
# .\Automation-Pipeline-Examples\ under the current directory (browse mode)
Copy-AzLocalPipelineExample

# Drop the GitHub Actions workflow YAML files DIRECTLY into .github\workflows\
# (no wrapper folder, no README, no .itsm). This is the canonical layout for a
# GitHub Actions runner, which only scans .github/workflows/*.yml non-recursively.
New-Item -ItemType Directory .\.github\workflows -Force | Out-Null
Copy-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub

# Same idea for Azure DevOps (ADO has no fixed-path convention)
New-Item -ItemType Directory .\pipelines -Force | Out-Null
Copy-AzLocalPipelineExample -Destination .\pipelines -Platform AzureDevOps

# Capture the destination and cd into it
$dest = Copy-AzLocalPipelineExample -Destination C:\repos\fleet -PassThru
Set-Location $dest
```

> By default the function refuses to overwrite any file that already exists in the destination - all conflicts are listed in the error message and the copy is aborted. To refresh after a module upgrade, pass `-Update`: you will be prompted per file (`Y` / `A` / `N` / `L` / `S` / `?`) before each overwrite. Use `-Update -Confirm:$false` to bypass the prompts in scripted / CI scenarios, or `-Update -WhatIf` to preview the changes. Pipeline files are expected to be under git source control so `git diff` gives you the post-overwrite safety net.
>
> ```powershell
> # Interactive refresh - prompt per file
> Copy-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub -Update
>
> # Scripted / CI refresh - no prompts, review afterwards with 'git diff'
> Copy-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub -Update -Confirm:$false
> ```

---

### `Connect-AzLocalServicePrincipal`

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
Connect-AzLocalServicePrincipal -UseManagedIdentity

# Using user-assigned Managed Identity with specific client ID
Connect-AzLocalServicePrincipal -UseManagedIdentity -ManagedIdentityClientId "12345678-1234-1234-1234-123456789012"

# Using environment variables for Service Principal (recommended for CI/CD)
$env:AZURE_CLIENT_ID = 'your-app-id'
$env:AZURE_CLIENT_SECRET = 'your-secret'
$env:AZURE_TENANT_ID = 'your-tenant-id'
Connect-AzLocalServicePrincipal

# Using a SecureString for the secret (preferred when passing via parameter)
$secret = Read-Host -AsSecureString -Prompt 'Service Principal Secret'
Connect-AzLocalServicePrincipal -ServicePrincipalId $appId -ServicePrincipalSecret $secret -TenantId $tenant

# Plaintext [string] still works but logs a security warning - prefer SecureString or env var
Connect-AzLocalServicePrincipal -ServicePrincipalId $appId -ServicePrincipalSecret $secret -TenantId $tenant
```

> **Security note (Service Principal + secret path):** internally `Connect-AzLocalServicePrincipal` invokes `az login --service-principal --password <secret>`. The secret is materialised as a plaintext command-line argument for the duration of the `az login` call, which means on Windows it can be visible to other processes via the `Win32_Process.CommandLine` WMI surface (and likewise to EDR, audit, and process-creation logs). The module always tries the safer paths first (OIDC, Managed Identity, and only then SP) and clears the plaintext copy in a `finally` block, but you should still prefer **OIDC** or **Managed Identity** for any production runner. If you must use SP + secret, run on an isolated, EDR-aware host, keep secrets in `AZURE_CLIENT_SECRET` (env var) or a `[SecureString]` rather than a literal `[string]`, and rotate frequently.

---

### `Start-AzLocalClusterUpdate`

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
Start-AzLocalClusterUpdate -ClusterResourceIds $resourceIds -Force
```

**Examples using Tags (Azure Resource Graph):**

```powershell
# Update all clusters tagged with "UpdateRing" = "Wave1" (across all subscriptions)
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force

# Update all production clusters
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Production" -Force

# Update clusters with specific UpdateRing and update version
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Pilot" -UpdateName "Solution12.2601.1002.38" -Force
```

> **Prerequisites for Tag-based Filtering:**
> 
> 1. **Azure CLI `resource-graph` extension** (required for `-ScopeByUpdateRingTag`):
>    The module **automatically installs** this extension if it's missing (using `az extension add --name resource-graph --yes`). This enables fully automated pipeline scenarios without manual intervention.
>
> 2. **Set up UpdateRing tags on your clusters** (if you haven't already):
>    If you want to use `-ScopeByUpdateRingTag` but your clusters don't have `UpdateRing` tags yet, use the [`Get-AzLocalClusterInventory`](#get-azlocalclusterinventory) and [`Set-AzLocalClusterUpdateRingTag`](#set-azlocalclusterupdateringtag) functions:
>    ```powershell
>    # Option 1: Export inventory to CSV, edit in Excel, then import
>    Get-AzLocalClusterInventory -ExportPath "C:\Temp\ClusterInventory.csv"
>    # Edit the CSV in Excel to populate UpdateRing values, then:
>    Set-AzLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv"
>    
>    # Option 2: Set tags directly using Resource IDs
>    $ring1Clusters = @(
>        "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01",
>        "/subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02"
>    )
>    Set-AzLocalClusterUpdateRingTag -ClusterResourceIds $ring1Clusters -UpdateRingValue "Wave1"
>    
>    # Then, update all Wave1 clusters
>    Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force
>    ```

### `Get-AzLocalClusterUpdateReadiness`

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
- `-ClusterNames`, `-ClusterResourceIds`, or `-ScopeByUpdateRingTag`/`-UpdateRingValue` (same as `Start-AzLocalClusterUpdate`)
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
Get-AzLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Wave1"

# Assess specific clusters and export to CSV
Get-AzLocalClusterUpdateReadiness -ClusterNames @("Cluster01", "Cluster02") -ExportPath "C:\Reports\readiness.csv"

# Assess clusters by UpdateRing tag across all subscriptions
Get-AzLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Production"
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

### `Get-AzLocalClusterInfo`

Gets cluster information by name.

```powershell
$cluster = Get-AzLocalClusterInfo -ClusterName "MyCluster" -SubscriptionId "xxx"
```

### `Get-AzLocalUpdateSummary`

Gets the update summary for a cluster.

```powershell
$summary = Get-AzLocalUpdateSummary -ClusterResourceId $cluster.id
Write-Host "Update State: $($summary.properties.state)"
```

### `Get-AzLocalAvailableUpdates`

Lists all available updates for a cluster with enriched state information including SBE dependency details.

```powershell
# Get enriched update objects (default) - includes PackageType, SBEDependency, UpdateState
$updates = Get-AzLocalAvailableUpdates -ClusterResourceId $cluster.id
$updates | Where-Object { $_.UpdateState -eq "Ready" }

# Get raw ARM API objects for programmatic processing
$raw = Get-AzLocalAvailableUpdates -ClusterResourceId $cluster.id -Raw
$raw | Where-Object { $_.properties.state -eq "Ready" }
```

### `Get-AzLocalUpdateRuns`

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
Get-AzLocalUpdateRuns -ClusterName "MyCluster" -ResourceGroupName "MyRG"

# Get only the latest update run
Get-AzLocalUpdateRuns -ClusterName "MyCluster" -Latest

# Get raw API response for programmatic processing
Get-AzLocalUpdateRuns -ClusterName "MyCluster" -Raw

# Multi-cluster: Get latest run for all clusters in an update ring
Get-AzLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Latest

# Export update run history to CSV
Get-AzLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Production" -Latest -ExportPath "C:\Reports\runs.csv"
```

**Sample Output:**
```
UpdateName                State       StartTime        EndTime          Duration               Progress    CurrentStep
----------                -----       ---------        -------          --------               --------    -----------
Solution12.2603.1002.500  InProgress  2026-04-09 16:50                  1 hour 12 minutes      3/5 steps   DownloadSBE
Solution12.2602.1002.501  Succeeded   2026-03-15 09:00 2026-03-15 11:30 2 hours 30 minutes     5/5 steps
```

### `Test-AzLocalClusterHealth`

Validates cluster health before applying updates by checking for blocking health check failures. Critical failures prevent updates from being applied.

**Parameters:**
- `-ClusterResourceIds`, `-ClusterNames`, or `-ScopeByUpdateRingTag`/`-UpdateRingValue`: Target clusters
- `-BlockingOnly` (Optional): Show only Critical severity failures (the ones that block updates)
- `-ExportPath` (Optional): Export results to CSV, JSON, or JUnit XML

**Examples:**

```powershell
# Check health for a single cluster
Test-AzLocalClusterHealth -ClusterResourceIds @("/subscriptions/.../clusters/Seattle")

# Check only update-blocking issues for an update ring
Test-AzLocalClusterHealth -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -BlockingOnly

# Export health results to CSV
Test-AzLocalClusterHealth -ClusterNames @("Cluster01", "Cluster02") -ExportPath "C:\Reports\health.csv"
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

> **Note**: `Start-AzLocalClusterUpdate` automatically runs this check (Step 3b) before applying updates. If Critical failures are found, the cluster is skipped with detailed diagnostics.

---

### `Get-AzLocalClusterInventory`

Gets an inventory of all Azure Local clusters with their UpdateRing tag status. This function supports both CSV and JSON export formats for different workflows.

**Features:**
- Queries all Azure Local clusters across all accessible subscriptions using Azure Resource Graph
- Shows the current UpdateRing tag value for each cluster (or indicates if tag doesn't exist)
- Retrieves subscription names for better readability
- Provides summary statistics showing UpdateRing distribution
- **CSV export**: For editing in Excel and re-importing with `Set-AzLocalClusterUpdateRingTag`
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
Get-AzLocalClusterInventory -ExportPath "C:\Temp\ClusterInventory.csv"

# Step 2: Open the CSV in Excel and populate the 'UpdateRing' column with values like:
#   - "Wave1", "Wave2", "Wave3" for wave-based deployments
#   - "Pilot", "Production" for environment-based rings
#   - "Ring1", "Ring2" for ring-based deployments

# Step 3: Import the CSV and apply tags
Set-AzLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv"

# Step 4: Update clusters by their UpdateRing tag
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force
```

**JSON Export (for CI/CD and integrations):**

```powershell
# Export to JSON for API integrations, dashboards, or CMDB systems
Get-AzLocalClusterInventory -ExportPath "C:\Reports\inventory.json"

# Export to JSON AND return objects for pipeline processing
$inventory = Get-AzLocalClusterInventory -ExportPath "./artifacts/inventory.json" -PassThru
Write-Host "Total clusters: $($inventory.Count)"
```

**CI/CD Pipeline Example (export both formats):**

```powershell
# Export both CSV and JSON in CI/CD pipelines
# CSV: For human review and Excel editing workflow
Get-AzLocalClusterInventory -ExportPath "./artifacts/inventory.csv"

# JSON: For dashboard integrations and programmatic processing
$inventory = Get-AzLocalClusterInventory -ExportPath "./artifacts/inventory.json" -PassThru
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
  4. Run: Set-AzLocalClusterUpdateRingTag -InputCsvPath 'C:\Temp\ClusterInventory.csv'
```

---

### `Set-AzLocalClusterUpdateRingTag`

Sets or updates the "UpdateRing" tag on Azure Local clusters for organizing update deployment waves.

**Features:**
- **NEW**: Accepts CSV file input for bulk tag operations (`-InputCsvPath`)
- Validates that Resource IDs are valid `microsoft.azurestackhci/clusters` resources
- Checks if clusters already have an "UpdateRing" tag before applying
- Warns and skips clusters with existing tags unless `-Force` is specified
- Logs previous tag values when updating with `-Force`
- Outputs results to a timestamped CSV log file

**Parameters:**
- `-InputCsvPath` (Required*): Path to CSV file with ResourceId and UpdateRing columns. Use with output from `Get-AzLocalClusterInventory`.
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
Get-AzLocalClusterInventory -ExportPath "C:\Temp\ClusterInventory.csv"
# Edit CSV in Excel to set UpdateRing values, then:
Set-AzLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv"

# Set UpdateRing tag on multiple clusters directly
$resourceIds = @(
    "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01",
    "/subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02",
    "/subscriptions/xxx/resourceGroups/RG3/providers/Microsoft.AzureStackHCI/clusters/Cluster03"
)
Set-AzLocalClusterUpdateRingTag -ClusterResourceIds $resourceIds -UpdateRingValue "Wave1"

# Preview changes without applying
Set-AzLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv" -WhatIf

# Force update existing tags (logs previous values)
Set-AzLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv" -Force

# Use with Start-AzLocalClusterUpdate for wave-based deployments
# Step 1: Tag clusters for Wave1
Set-AzLocalClusterUpdateRingTag -ClusterResourceIds $wave1Clusters -UpdateRingValue "Wave1"

# Step 2: Update only Wave1 clusters
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force
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

### `Invoke-AzLocalFleetOperation`

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
Invoke-AzLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force

# Large fleet with increased batching and parallelism
Invoke-AzLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Production" `
    -BatchSize 100 -ThrottleLimit 20 -DelayBetweenBatchesSeconds 60 -Force

# Save state for resume capability
$state = Invoke-AzLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Ring1" `
    -StateFilePath "C:\Logs\ring1-state.json" -Force -PassThru

# Check readiness across fleet (no updates applied)
Invoke-AzLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Canary" `
    -Operation CheckReadiness

# Apply specific update version
Invoke-AzLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Pilot" `
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

### `Get-AzLocalFleetProgress`

Gets real-time progress of a fleet-wide update operation with aggregated statistics and optional per-cluster details.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-State` | PSCustomObject | No | - | Fleet operation state object from `Invoke-AzLocalFleetOperation` |
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
Get-AzLocalFleetProgress -State $fleetState

# Check progress for all Production clusters
Get-AzLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Production"

# Get detailed per-cluster status
Get-AzLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Detailed

# Monitor in a loop
while ($true) {
    $progress = Get-AzLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Wave1"
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

### `Test-AzLocalFleetHealthGate`

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
Test-AzLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Canary"

# Strict gate for production (max 2% failure, min 95% success)
Test-AzLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -MaxFailurePercent 2 -MinSuccessPercent 95

# Wait for completion before evaluating
Test-AzLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -WaitForCompletion -WaitTimeoutMinutes 180

# CI/CD pipeline integration
$gate = Test-AzLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
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

### `Export-AzLocalFleetState`

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
Export-AzLocalFleetState

# Export to specific path
Export-AzLocalFleetState -Path "C:\Logs\fleet-state.json"

# Export state from operation
$state = Invoke-AzLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -PassThru
Export-AzLocalFleetState -State $state -Path "C:\Logs\wave1-checkpoint.json"
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

### `Resume-AzLocalFleetUpdate`

Resumes a previously interrupted fleet update operation from a saved state file. Enables recovery from pipeline timeouts, network interruptions, or manual cancellations.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-StateFilePath` | String | Yes* | - | Path to the saved state file |
| `-State` | PSCustomObject | Yes* | - | State object loaded via `Import-AzLocalFleetState` |
| `-RetryFailed` | Switch | No | - | Also retry clusters that previously failed (not just pending) |
| `-MaxRetries` | Int | No | `3` | Maximum additional retry attempts for failed clusters (0-10) |
| `-Force` | Switch | No | - | Skip confirmation prompts |
| `-PassThru` | Switch | No | - | Return the updated state object |

*Either `-StateFilePath` OR `-State` is required.

**Examples:**

```powershell
# Resume from state file (process only pending clusters)
Resume-AzLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -Force

# Resume and retry failed clusters
Resume-AzLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -RetryFailed -Force

# Load state manually and resume
$state = Import-AzLocalFleetState -Path "C:\Logs\fleet-state.json"
Resume-AzLocalFleetUpdate -State $state -RetryFailed -MaxRetries 5 -Force
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

### `Stop-AzLocalFleetUpdate`

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
Stop-AzLocalFleetUpdate -SaveState

# Stop and save to specific location
Stop-AzLocalFleetUpdate -SaveState -StateFilePath "C:\Logs\fleet-stopped.json"
```

**Sample Output:**

```
========================================
Stopping Fleet Operation
========================================

State saved to: C:\Logs\fleet-stopped.json
Use Resume-AzLocalFleetUpdate to continue later.

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

### `Test-AzLocalUpdateScheduleAllowed`

Master gate that evaluates whether an update is allowed against the `UpdateWindow` (maintenance schedule) and `UpdateExclusions` (blackout periods) tag values. Exclusions take priority over windows. Returns a structured result with `Allowed`, `Reason`, `WindowOpen`, `ExclusionActive`, and `Details`. Used internally by `Start-AzLocalClusterUpdate` and exposed as a public function so pipelines can pre-flight a wave before triggering the apply step.

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
$gate = Test-AzLocalUpdateScheduleAllowed `
    -UpdateWindow 'Sat-Sun_02:00-06:00' `
    -UpdateExclusions '2026-12-20/2027-01-03'

if (-not $gate.Allowed) {
    Write-Host "Wave blocked: $($gate.Reason) - $($gate.Details)"
    exit 1
}

# Test a specific UTC point in time (e.g. when the pipeline will run tonight)
Test-AzLocalUpdateScheduleAllowed `
    -UpdateWindow 'Mon-Fri_22:00-02:00' `
    -TestTime ([DateTime]::UtcNow.AddHours(6))
```

---

### `Reset-AzLocalSideloadedTag`

Explicit, scope-required entry point for the same auto-reset logic that `Get-AzLocalUpdateRuns` runs by default. Use it to: (a) manually reset the sideloaded tags after an out-of-band update where `Get-AzLocalUpdateRuns` was not executed (or was run with `-SkipSideloadedReset`), or (b) force-clear a stuck `UpdateSideloaded=True` tag with `-Force`.

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
Reset-AzLocalSideloadedTag -ClusterNames 'cl-01' -ResourceGroupName 'rg-fleet' -WhatIf

# Bulk reset across an UpdateRing, default behaviour: only succeeded runs get reset
Reset-AzLocalSideloadedTag -ScopeByUpdateRingTag -UpdateRingValue 'Wave1'

# Force-clear a stuck cluster (operator abandoned the staged payload).
# -Force still requires latest run = Succeeded; it just bypasses the version-match check.
Reset-AzLocalSideloadedTag -ClusterNames 'cl-stuck' -Force -Confirm:$false
```

> **No new RBAC required.** Uses the same `Microsoft.Resources/tags/read` + `Microsoft.Resources/tags/write` already required by `Set-AzLocalClusterUpdateRingTag`.

---

### `Get-AzLocalFleetStatusData`

Single-pass data collector that gathers everything `New-AzLocalFleetStatusHtmlReport` needs, in one structured object. Returns a `PSCustomObject` with `SchemaVersion`, `Timestamp`, `ModuleVersion`, `Scope`, `Readiness`, `ClusterDetails`, `LatestRuns`, `HealthResults`. Use this when you want to:

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
$data = Get-AzLocalFleetStatusData -AllClusters -ThrottleLimit 4 -IncludeUpdateRuns -IncludeHealthDetails
New-AzLocalFleetStatusHtmlReport -StatusData $data -OutputPath 'C:\Reports\fleet.html'

# CI/CD: collect in job 1, render in job 2 from the artifact
Get-AzLocalFleetStatusData -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' `
    -IncludeUpdateRuns -IncludeHealthDetails `
    -ExportPath '$(Pipeline.Workspace)/fleet-data.json'
```

---

### `New-AzLocalFleetStatusHtmlReport`

Renders a self-contained HTML report (executive summary, progress bar, cluster status table, optional health-details and update-run-history sections, embedded CSS). UTF-8 without BOM; safe to email or host on SharePoint. Supports `-WhatIf` / `-Confirm`.

Two ways to drive it:

1. **Self-collecting** (default): pass a scope (`-AllClusters` / `-ClusterNames` / `-ScopeByUpdateRingTag` / `-ClusterResourceIds`) and the function will call `Get-AzLocalClusterInventory`, `Get-AzLocalClusterUpdateReadiness`, `Get-AzLocalUpdateSummary`, `Get-AzLocalAvailableUpdates` (and optionally `Get-AzLocalUpdateRuns` / `Test-AzLocalClusterHealth`) itself.
2. **From pre-collected data**: pass `-StatusData $data` (the object returned by `Get-AzLocalFleetStatusData`) and the function skips all API calls, going straight to rendering. **Use this in CI/CD to avoid double-billing yourself for ARM reads.**

**Common parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-OutputPath` | String | Yes | - | Destination `.html` / `.htm` file. Validated. |
| `-StatusData` | PSCustomObject | No | - | Pre-collected payload from `Get-AzLocalFleetStatusData`. |
| `-IncludeUpdateRuns` | Switch | No | - | Add the **Recent Update Run History** section (now includes `End Time` column - v0.7.1). |
| `-IncludeHealthDetails` | Switch | No | - | Add the detailed health-check failure section. |
| `-Title` | String | No | Auto | Custom report title (auto-derived from scope if omitted). |
| `-MaxClusters` | Int 0-100000 | No | 0 (no cap) | Optional cap when `-AllClusters` is used. |
| `-ThrottleLimit` | Int 1-8 | No | 4 | Parallel workers (only relevant when self-collecting). |
| `-PassThru` | Switch | No | - | Also return the HTML string (useful for emailing). |

**Examples:**

```powershell
# Whole fleet, full detail
New-AzLocalFleetStatusHtmlReport -AllClusters `
    -OutputPath 'C:\Reports\fleet.html' `
    -IncludeUpdateRuns -IncludeHealthDetails

# Wave-scoped, capture HTML for email body
$html = New-AzLocalFleetStatusHtmlReport `
    -ScopeByUpdateRingTag -UpdateRingValue 'Wave1' `
    -OutputPath 'C:\Reports\wave1.html' -PassThru

# Two-stage CI/CD pattern (no double API calls)
$data = Get-AzLocalFleetStatusData -AllClusters -IncludeUpdateRuns -IncludeHealthDetails
New-AzLocalFleetStatusHtmlReport -StatusData $data -OutputPath 'C:\Reports\fleet.html'
```

---

### `Get-AzLocalFleetHealthFailures`

*Added in v0.7.65.*

Surfaces the in-flight **24-hour system health-check failures** across every Azure Local cluster the caller can read. The 24-hour system health checks continue to run on the cluster even when no update is in flight, which means clusters that are **already "up to date" can still surface Critical or Warning health issues** that administrators need to triage. This cmdlet is the dedicated entry point for that workflow.

Under the covers it executes a single Azure Resource Graph query against the `extensibilityresources` table (paging transparently for fleets larger than 1000 entries), `mv-expand`s `properties.healthCheckResult` so each failing entry becomes its own row, and projects to a stable output schema.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-SubscriptionId` | String | No | All accessible | Optional. Limit the query to a single subscription. |
| `-Severity` | String | No | `All` | `Critical`, `Warning`, or `All` (Critical + Warning). Informational entries are always excluded. |
| `-View` | String | No | `Detail` | `Detail` (one row per (cluster, failing check)) or `Summary` (aggregated by `FailureReason` + `Severity`, ordered "most widespread first"). |
| `-UpdateRingTag` | String | No | - | Optional. Narrow to clusters whose `UpdateRing` tag matches. Accepts a single ring (`Wave1`), a semicolon-delimited list (`Prod;Ring2`), or the literal `***` wildcard for every cluster with a non-empty `UpdateRing` tag (untagged clusters are excluded). Single `*`, double `**`, and quadruple `****` are deliberately rejected. Validated `^(\*\*\*\|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$`. |
| `-ExportPath` | String | No | - | Optional `.csv` or `.json` path; format auto-detected from extension. |
| `-PassThru` | Switch | No | - | Emit objects to the pipeline **even when** `-ExportPath` is used. |

**Detail view columns:** `ClusterName`, `ResourceGroup`, `SubscriptionId`, `Severity`, `FailureReason`, `FailureName`, `Description`, `Remediation`, `LastOccurrence`, `ClusterResourceId`. Rows are ordered Critical-before-Warning, then by ClusterName, then by FailureReason.

**Summary view columns:** `FailureReason`, `Severity`, `ClusterCount`, `FailureCount`, `AffectedClusters` (semicolon-separated), `LatestOccurrence`, `Description`, `Remediation`. Rows are ordered by `ClusterCount desc, Critical-before-Warning, FailureCount desc` so the highest-impact issues are at the top.

**Examples:**

```powershell
# Per-cluster detail across the entire fleet (default view)
Get-AzLocalFleetHealthFailures

# Pivot by failure reason - "what should we fix first?" - and export
Get-AzLocalFleetHealthFailures -View Summary -ExportPath .\fleet-health-summary.csv

# Critical issues only, narrowed to one ring, for a focussed report
Get-AzLocalFleetHealthFailures -Severity Critical -UpdateRingTag 'Wave1'

# CI/CD pipeline: detail for JUnit emission, summary for the markdown summary
$detail  = Get-AzLocalFleetHealthFailures -View Detail  -ExportPath .\reports\fleet-health-detail.csv  -PassThru
$summary = Get-AzLocalFleetHealthFailures -View Summary -ExportPath .\reports\fleet-health-summary.csv -PassThru
```

> **CI/CD**: the bundled `Step.7_fleet-health-status.yml` pipeline samples (GitHub Actions and Azure DevOps) wire this cmdlet into a daily-scheduled run that emits JUnit XML, CSV/JSON exports, and a Markdown step summary. See [Automation-Pipeline-Examples/README.md](./Automation-Pipeline-Examples/README.md).

**Required permissions** (read-only):
- `Microsoft.AzureStackHCI/clusters/read`
- `Microsoft.AzureStackHCI/clusters/updateSummaries/read`
- `Microsoft.ResourceGraph/resources/read`

`Reader` on the cluster (or the containing resource group / subscription) is sufficient.

---

### `Test-AzLocalApplyUpdatesScheduleCoverage`

*Added in v0.7.65.*

Read-only **schedule-coverage advisor**. Compares the cron schedule(s) declared in your `Step.5_apply-updates.yml` pipeline (GitHub Actions and/or Azure DevOps) to the `UpdateWindow` tag values actually present on your clusters, and flags every `(UpdateRing, UpdateWindow)` pair that no cron in the pipeline will ever reach. Never edits cluster tags. Never edits pipeline YAML. It is the safety net that closes the loop between section 8 of [`Automation-Pipeline-Examples/README.md`](./Automation-Pipeline-Examples/README.md) (the `UpdateWindow` tag is a *gate*, not a *trigger*) and `Test-AzLocalUpdateScheduleAllowed` (the runtime per-cluster gate inside `Start-AzLocalClusterUpdate`).

Under the covers it pre-scans the pipeline YAML file(s) with a regex (no `powershell-yaml` dependency), runs a single Azure Resource Graph query against `resources` for clusters with `UpdateWindow` / `UpdateRing` tags, parses each tag value with the same `ConvertFrom-AzLocalUpdateWindow` helper used by the runtime gate, then enumerates every cron fire time over a reference week and compares it to each parsed window (with a configurable lead-time buffer).

**Parameters:**

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `-SubscriptionId` | String | No | All accessible | Optional. Limit the ARG query to a single subscription. |
| `-View` | String | No | `Audit` | `Audit` (one row per `(Ring, Window)` pair with `Covered` / `Uncovered` / `PartiallyCovered` / `MalformedTag` / `NoWindowTag` / `UnparseableCron` status + remediation), `Matrix` (every distinct `(Ring, Window)` pair with the cron expression the advisor would generate for it), or `Recommend` (ready-to-paste GH Actions + Azure DevOps cron blocks). |
| `-PipelineYamlPath` | String | Audit only | - | Path to `Step.5_apply-updates.yml` file(s) or a folder containing them. Required when `-View Audit`. |
| `-Platform` | String | No | `Both` | `GitHubActions`, `AzureDevOps`, or `Both`. Filters which YAML files are scanned and which cron blocks the Recommend view emits. |
| `-LeadTimeMinutes` | Int | No | `5` | Range 0-60. How many minutes the cron should fire **before** the window opens (so cluster enumeration + auth completes before `Test-AzLocalUpdateScheduleAllowed` evaluates). |
| `-UpdateRingTag` | String[] | No | - | Optional. Narrow the audit to one or more `UpdateRing` tag values. |
| `-IncludeUntagged` | Switch | No | - | Include clusters that have no `UpdateWindow` tag in the Audit view (`Status = NoWindowTag`). |
| `-ExportPath` | String | No | - | Optional `.csv` / `.json` / `.md` path; format auto-detected from extension. `.md` emits the YAML snippet for Recommend, a markdown table for Audit/Matrix. |
| `-PassThru` | Switch | No | - | Emit objects to the pipeline even when `-ExportPath` is used. |

**Audit view columns:** `UpdateRing`, `UpdateWindow`, `ClusterCount`, `Status`, `Issue`, `Recommendation`, `MatchingCrons`, `RequiredCronUTC`. Rows are ordered by `Status` (Uncovered first), then `ClusterCount desc`.

**Matrix view columns:** `UpdateRing`, `UpdateWindow`, `ClusterCount`, `RequiredCronUTC`, `Segment`, `Days`.

**Recommend view columns:** `Platform`, `CronExpression`, `WindowsServed`, `ClustersServed`, `Comment`.

**Examples:**

```powershell
# Audit the in-repo pipeline samples against the live fleet (default view)
Test-AzLocalApplyUpdatesScheduleCoverage `
    -PipelineYamlPath .\AzLocal.UpdateManagement\Automation-Pipeline-Examples

# Audit only the GitHub Actions sample, with a 10-minute lead time
Test-AzLocalApplyUpdatesScheduleCoverage `
    -PipelineYamlPath .\.github\workflows\Step.5_apply-updates.yml `
    -Platform GitHubActions `
    -LeadTimeMinutes 10

# Just emit the recommended cron block(s), no comparison required
Test-AzLocalApplyUpdatesScheduleCoverage -View Recommend -Platform GitHubActions

# Inventory every (Ring, Window) pair with its required cron, export to CSV
Test-AzLocalApplyUpdatesScheduleCoverage -View Matrix -ExportPath .\windows.csv

# CI/CD pipeline: emit all three artefacts for the schedule audit pipeline
$audit  = Test-AzLocalApplyUpdatesScheduleCoverage -View Audit  -PipelineYamlPath .\.github\workflows -ExportPath .\schedule-coverage-audit.csv     -PassThru
$matrix = Test-AzLocalApplyUpdatesScheduleCoverage -View Matrix -ExportPath .\schedule-coverage-matrix.csv -PassThru
$rec    = Test-AzLocalApplyUpdatesScheduleCoverage -View Recommend -ExportPath .\schedule-coverage-recommend.md -PassThru
```

> **CI/CD**: the bundled `Step.3_apply-updates-schedule-audit.yml` pipeline samples (GitHub Actions and Azure DevOps) wire this cmdlet into a weekly-scheduled run (Mon 05:00 UTC) that emits JUnit XML, three CSV/MD exports, and a Markdown step summary. Full end-to-end runbook in [`Automation-Pipeline-Examples/README.md` section 8.3](./Automation-Pipeline-Examples/README.md#83-end-to-end-runbook-apply-updates-schedule-coverage-audit).

**Required permissions** (read-only):
- `Microsoft.Resources/subscriptions/resourceGroups/read`
- `Microsoft.AzureStackHCI/clusters/read`
- `Microsoft.ResourceGraph/resources/read`

`Reader` on the cluster scope (or the containing resource group / subscription) is sufficient. No write actions are ever taken.

---

The module includes comprehensive logging capabilities for tracking update operations.

### Log Files

By default, log files are created in `C:\ProgramData\AzLocal.UpdateManagement\` which is accessible across different user profiles. This folder is automatically created if it doesn't exist.

When you run `Start-AzLocalClusterUpdate`, the following files are automatically created:

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
Start-AzLocalClusterUpdate -ClusterNames "MyCluster" -Force

# Custom log folder location (auto-creates folder if needed)
Start-AzLocalClusterUpdate -ClusterNames "MyCluster" -LogFolderPath "D:\Logs\Updates" -Force

# Enable transcript recording for complete console output capture
Start-AzLocalClusterUpdate -ClusterNames "MyCluster" -EnableTranscript -Force

# Export results to JSON for automation/reporting
Start-AzLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02") -ExportResultsPath "C:\Logs\results.json" -Force

# Export results to CSV for Excel analysis
Start-AzLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02") -ExportResultsPath "C:\Logs\results.csv" -Force

# Full logging with all options
Start-AzLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02") `
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

- **Authentication**: works with OIDC (recommended), Managed Identity, or Service Principal + secret. See `Connect-AzLocalServicePrincipal` and the pipeline guide above.
- **JUnit XML export**: any function that takes `-ExportPath` / `-ExportResultsPath` will emit JUnit XML when the path ends in `.xml`. Consumed natively by Azure DevOps **Publish Test Results**, GitHub Actions (`dorny/test-reporter`, `mikepenz/action-junit-report`), Jenkins, GitLab CI (`artifacts:reports:junit`), and TeamCity.
- **CSV / JSON export**: pass `.csv` or `.json` for the same paths to drive downstream reporting / Power BI / Log Analytics ingestion.
- **`-WhatIf` and `-PassThru`**: every state-changing function supports `-WhatIf` (counted as `WouldUpdate` in the summary) so dry-runs are auditable; `-PassThru` returns structured objects for pipeline-stage chaining.
- **Parallelism**: `-ThrottleLimit 1..16` on per-cluster operations; default 4. Tune for your runner and ARM throttling envelope.

Minimal example - export update results as JUnit XML:

```powershell
Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue 'Ring1' -Force `
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
- `Get-AzLocalUpdateRuns`, `Get-AzLocalAvailableUpdates`, or `Get-AzLocalFleetStatusData` returns placeholder `Error` rows for some clusters with otherwise valid Azure access.
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

- `Get-AzLocalClusterUpdateReadiness` recommends an update that is already installed on the cluster (e.g. portal shows `CurrentVersion = 12.2603.1002.500` but `RecommendedUpdate = Solution12.2603.1002.500`).
- Azure portal shows contradictory banners on the cluster **Updates** blade ("Update(s) available" header + "There is no update available to install" banner).
- `updateSummaries.lastChecked` / `lastUpdated` timestamps are hours or days old.
- Running `Get-SolutionUpdate` on a cluster node shows the correct state (the newer update as `Ready`, older ones as `Installed`), but the ARM `/updates` and `/updateSummaries` child resources do not reflect it.

**Cause**

The `Azure Stack HCI Update Service` is a **manual-start, on-demand** Windows service on each cluster node. It is the component that pushes `/updates` and `/updateSummaries` state to ARM. If it has not been triggered recently (by the LCM scheduler or by a user action), ARM's view of the cluster drifts out of sync with the node-local `Get-SolutionUpdate` store. The module correctly reports what ARM returns - ARM is wrong, not the module.

Note: v0.7.0+ `Get-AzLocalClusterUpdateReadiness` already mitigates this by short-circuiting to `UpToDate` when every entry in `/updates` is in the terminal `Installed` state, even if `updateSummaries.state` is stale. But once a genuinely new update (like `Solution12.2604.xxxx`) is published, the staleness becomes visible again until ARM is refreshed.

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
Start-AzLocalClusterUpdate -ClusterNames "MyCluster" -Verbose
```

## License

This code is provided as-is for educational and reference purposes.

---

## Release History

The full What's-New history (v0.7.74 and earlier) has moved to [docs/release-history.md](docs/release-history.md).

The most recent release notes for **v0.7.75** stay above under [`What's New in v0.7.75`](#whats-new-in-v0775).

---

_Generated by `AzLocal.UpdateManagement` for Azure Local at-scale fleet updates._