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


### What's New in v0.7.74

v0.7.74 is a **bug-fix + UX** release on top of v0.7.73. It addresses **two distinct findings** raised against v0.7.73 against the same live 20-cluster fleet: **(1)** `Get-AzLocalFleetHealthOverview` started failing with a KQL `ParserFailure: token=<EOF>` at character `2757` because the v0.7.73 query growth crossed the `az graph query -q` argument-truncation threshold (~2.8 KB wire-side); **(2)** the `Step.3 - Apply-Updates Schedule Coverage Audit` recommendation block was reported as "very hard to follow and understand what to do" - it was a four-section advisory but lacked an explicit fix-in-this-order checklist, did not explain *why* each finding mattered, did not include a before/after YAML snippet for missing rings, and shipped a commented-out cron block that operators were copy-pasting verbatim including the `# ` prefixes. Both are fixed. Pipeline pin bumps to `'0.7.74'`; refresh existing copies via `Update-AzLocalPipelineExample`.

### Get-AzLocalFleetHealthOverview `ParserFailure: token=<EOF>` at char 2757 - fixed

The v0.7.73 change (HealthStatus normalisation via `case()`) added ~250 chars of KQL projection, and the v0.7.73 commit also added a six-line `//` KQL comment block above the projection (~470 chars). The combined wire query grew from `~2400` chars (v0.7.72 baseline) to `3115` chars. On Windows the Azure CLI's `az graph query -q <query>` argument layer truncates very long single-arg payloads around the 2.8 KB mark; the truncated query lands mid-projection, so ARG returns:

```json
{
  "error": {
    "code": "BadRequest",
    "details": [
      { "code": "InvalidQuery", "message": "Query is invalid." },
      { "code": "ParserFailure",
        "message": "... characterPositionInLine=2757 token=<EOF> ..." }
    ]
  }
}
```

Symptom: `Step.7 - Fleet Health Status` failed with exit code 1 the moment the cmdlet was invoked. Step.7's separate, shorter "Detail" ARG query (rendered after Overview) was unaffected, which made the failure look like a HealthStatus-projection bug rather than an arg-length bug.

**Fix:** (1) the six `//` KQL comment lines are removed from the here-string and re-expressed as PowerShell `#` source comments above the `$kql` assignment - documentation for the source reader, no wire-side bytes. (2) The `case()` projection is compacted to one line (semantically identical). The wire query is now `2396` chars, back below the v0.7.72 baseline. A new inline `IMPORTANT` source comment above `$kql` flags the constraint so future contributors do not re-introduce it.

Verified end-to-end against the same live 20-cluster fleet: 20 cluster rows returned; HealthStatus distribution preserved from v0.7.73 (`10 Healthy / 7 Critical / 2 Warning / 1 In progress`); Step.7 `HEALTHY_CLUSTERS` output still writes `10` and the Fleet Health Overview table still renders the intended icons.

### Step.3 recommendation block rewritten as a step-by-step remediation guide

Operators reported the v0.7.73 Step.3 output was "very hard to follow and understand what to do, it needs much more detail and step by step for exactly what the operator needs to do to 'fix' the Apply Updates schedules, across the CRON jump for Step 5 and the Config YML file." v0.7.74 adds:

- **Top-of-block "Fix-in-this-order checklist"** when 2+ action sections are emitted, with N+1 ordered bullets that name the file to edit AND the silent-skip consequence of skipping that step (e.g. `Resolve-AzLocalCurrentUpdateRing` returns nothing for missing rings so Step.5 silently skips them; `Test-AzLocalUpdateScheduleAllowed` never opens the gate for uncovered UpdateWindows). The checklist surfaces the order the advisor uses internally (ring diff -> orphans -> unparseable crons -> cron coverage -> re-run) so the operator does not have to derive it from the section headings.
- **`**Why this matters.**` paragraph in every section** that names the specific runtime cmdlet that depends on the configuration being fixed (`Resolve-AzLocalCurrentUpdateRing`, `Test-AzLocalUpdateScheduleAllowed`) and the silent-skip failure mode the operator avoids by following the fix.
- **"How to fix - edit `<file>`" subsection in the missing-rings section** with a full `apply-updates-schedule.yml` skeleton snippet showing the existing `schedule:` block AND a placeholder row PER missing ring (`TODO:` markers on `weeksInCycle`, `daysOfWeek`, `notes`, annotated with the cluster count for the missing ring). The snippet carries an `AzLocal.UpdateManagement v<version> advisor: add row(s) like these <<<` header so it is unambiguous where the operator-edited content begins.
- **Ready-to-paste (uncommented) cron block** in the cron-coverage section. Replaces the prior `# commented` form (which operators were copy-pasting verbatim including the `# ` prefixes). The snippet is now a real `on:` (GitHub Actions) / `schedules:` (Azure DevOps) block, with one cron line per UpdateWindow plus a trailing yaml-`#` annotation showing the rings and cluster count served by each cron.
- **Platform-aware file labels.** When `-Platform` is pinned to a single platform, the text names the exact pipeline file (`.github/workflows/Step.5_apply-updates.yml` vs `.azuredevops/Step.5_apply-updates.yml`) and the exact schedule file (`.github/apply-updates-schedule.yml` vs `.azuredevops/apply-updates-schedule.yml`).
- **Two-choice fix tables for orphaned rings** spell out both options (retag a cluster onto the ring via `Set-AzLocalClusterUpdateRingTag`, OR remove the ring from the schedule file) so operators do not default to deletion when they actually wanted to bring a cluster onto the ring.

### Step.3 pipeline scripts pin `-Platform` so cross-platform noise is gone

`Test-AzLocalApplyUpdatesScheduleCoverage` defaults to `-Platform Both`, which surfaced both the GitHub Actions `schedule:` block AND the Azure DevOps `schedules:` block in every Step.3 run regardless of which CI platform was running it. Both Step.3 yml files now pin `-Platform GitHubActions` (GH) / `-Platform AzureDevOps` (ADO) on both `-View Audit` and `-View Recommend` calls so the Step Summary contains exactly one platform-appropriate snippet.

### Pipeline pin bumps + migration

All 14 `Step.{1..7}.yml` files (7 GitHub Actions + 7 Azure DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.73'` to `'0.7.74'`. Refresh existing copies via the marker-aware merge (preserves operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs):

```powershell
Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps
```

### Compatibility

All v0.7.74 changes are backward compatible. `Get-AzLocalFleetHealthOverview` returns the same shape and the same normalised `HealthStatus` vocabulary it returned in v0.7.73 - only the underlying wire query is shorter so it no longer trips the truncation. The v0.7.74 Step.3 yml changes (adding `-Platform GitHubActions` / `-Platform AzureDevOps`) are recommended-but-not-required - the cmdlet still works against the v0.7.73 yml; you just continue to see the cross-platform noise until the yml is refreshed.

### What's New in v0.7.73

v0.7.73 is a **bug-fix** release on top of v0.7.72. `Get-AzLocalFleetHealthOverview` (the cmdlet that powers `Step.7 - Fleet Health Status`) was emitting the raw Azure Resource Graph `properties.healthState` enum values (`Success` / `Failure` / `Warning` / `InProgress` / `NotKnown`) on the `HealthStatus` column, but the cmdlet's own doc comment, the Step.7 pipeline filter `Where-Object { $_.HealthStatus -eq 'Healthy' }`, and the Step.7 Fleet Health Overview rendering `switch ($o.HealthStatus)` all expected the operator-friendly vocabulary `Healthy` / `Critical` / `Warning` / `In progress` / `Unknown`. Symptom: Step.7 reported `Healthy Clusters = 0` against any fleet (live-verified against a 20-cluster fleet: 10 Success / 8 Failure / 2 Warning) and the overview table rendered the `[Success]` / `[Failure]` default-bracket fallback instead of the intended `✅ Healthy` / `❌ Critical` icons. The KQL projection in the cmdlet now normalises in a `case()` clause so the `HealthStatus` column matches the documented contract; no pipeline-sample YAML change is required (the v0.7.72 pin already used the correct vocabulary). Pipeline pin bumps to `'0.7.73'`; refresh existing copies via `Update-AzLocalPipelineExample`.

### Step.7 "Healthy Clusters = 0" against any fleet - fixed

`Get-AzLocalFleetHealthOverview.HealthStatus` is documented (and consumed) as one of `Healthy` / `Critical` / `Warning` / `In progress` / `Unknown`. The KQL projection joining `microsoft.azurestackhci/clusters` with the `updateSummaries` extensibility resource was, however, a one-line passthrough:

```kusto
HealthStatus = iif(isempty(HealthState), 'Unknown', HealthState),
```

The upstream ARG field `properties.healthState` emits the raw ARM enum values `Success` / `Failure` / `Warning` / `InProgress` / `NotKnown`, so `Healthy` / `Critical` / `In progress` literally never appeared on any row. The pipeline filter `Where-Object { $_.HealthStatus -eq 'Healthy' }` therefore matched zero rows and the `HEALTHY_CLUSTERS` GitHub Actions output was always `0`; the rendering switch fell through to the default arm and rendered `[Success]` / `[Failure]` instead of `✅ Healthy` / `❌ Critical`. The projection is now:

```kusto
HealthStatus = case(
    isempty(HealthState),         'Unknown',
    HealthState =~ 'Success',     'Healthy',
    HealthState =~ 'Failure',     'Critical',
    HealthState =~ 'InProgress',  'In progress',
    HealthState =~ 'NotKnown',    'Unknown',
    HealthState
),
```

`Warning` is passed through unchanged, and any unrecognised future state also passes through (rather than being silently bucketed as `Unknown`) so a platform addition stays visible. Verified end-to-end against a live 20-cluster fleet (10 Success / 8 Failure / 2 Warning): after the fix, Step.7 reports `Healthy Clusters = 10`, the Fleet Health Overview table renders the intended icons, and the Step.7 numbers are internally consistent with the Step.6 panel for the same fleet (Step.6 reports `Up to Date = 10` and `Critical Health Status: 12 passed / 8 failed`; the 2 Warning clusters surface as `⚠️ Warning` in the overview without being counted as either Healthy or Critical). The cmdlet's doc comment is also corrected to describe the normalised vocabulary and to spell out the raw-to-normalised mapping for future-proof clarity.

### Pipeline pin bumps + migration

All 14 `Step.{1..7}.yml` files (7 GitHub Actions + 7 Azure DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.72'` to `'0.7.73'`. The Step.0 authentication validation workflow does not pin a module version. **No filter or switch changes required in the pipeline samples** - the v0.7.72 pin already used the correct vocabulary; the v0.7.73 module simply emits values that match. Refresh existing copies via the marker-aware merge (preserves operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs):

```powershell
Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps
```

### Compatibility

All v0.7.73 changes are backward compatible. The `HealthStatus` column type (`string`) and column position (third column, after `ClusterName` and `ClusterPortalUrl`) are unchanged - only the value set narrows from the raw ARG enum to the documented operator-friendly vocabulary. Operators who built custom downstream automation that explicitly filtered for the **raw** `Success` / `Failure` / `InProgress` / `NotKnown` strings against the v0.7.70 - v0.7.72 builds must update those filters to the new `Healthy` / `Critical` / `In progress` / `Unknown` vocabulary (or pull the raw value back via a separate ARG call on `updateSummaries.properties.healthState` if they specifically need the platform enum).

### What's New in v0.7.72

v0.7.72 is a **pipeline-samples hotfix** release on top of v0.7.71. Two issues observed when operators ran the v0.7.71 GitHub Actions samples in production: (1) the Step.1 / Step.2 / Step.5 GitHub Actions `Summary` panels rendered empty because the workflows used `Write-Host "<markdown>" >> $env:GITHUB_STEP_SUMMARY` - `Write-Host` writes to the PowerShell information/host stream (6), not stdout (1), so the `>>` redirect appended nothing to the summary file; (2) `AZURE_TENANT_ID` was stored as a GitHub Secret on the same rationale as the v0.7.71 `AZURE_SUBSCRIPTION_ID` treatment - a public ARM/AAD identifier, not a credential. Both are fixed. **No PowerShell source files changed** - this release is scoped to pipeline-sample YAMLs and Markdown docs. Refresh existing copies via `Update-AzLocalPipelineExample`.

### Step.1 / Step.2 / Step.5 GitHub Actions `Summary` blocks now render content (was blank)

Across these three workflows, 62 `Write-Host "<markdown>" >> $env:GITHUB_STEP_SUMMARY` lines were silent no-ops because `Write-Host` emits to PowerShell's information stream (stream 6), not stdout (stream 1). The file-redirect operator `>>` only attaches to stdout, so the GitHub Actions Summary file received an empty append on every line. The job log printed the markdown to the runner console (where operators do not normally look) but the GitHub Actions Summary panel - the canonical post-run report surface - rendered blank. All 62 lines now use the bare-string-to-stdout form (`"<markdown>" >> $env:GITHUB_STEP_SUMMARY`), so the totals/tables/actions-required block coded in v0.7.71 finally surface in the GitHub Actions UI. Affected:

- **Step.1**: cluster-inventory totals + UpdateRing distribution.
- **Step.2**: UpdateRing tag-management settings + dry-run notice.
- **Step.5**: update-application readiness/results matrix + actions-required block + `no-clusters-ready` job summary.

ADO pipelines were unaffected (they use the `##vso[task.uploadsummary]` mechanism, not stdout redirection).

### GitHub Actions: AZURE_TENANT_ID is now a Variable, not a Secret

All 8 GitHub Actions `Step.*.yml` workflows (including the four commented-out legacy `azure/login@v3` `creds:` JSON examples in Step.1 / Step.2 / Step.5) now read the Entra ID tenant id from `vars.AZURE_TENANT_ID` instead of `secrets.AZURE_TENANT_ID`. Rationale matches the v0.7.71 `AZURE_SUBSCRIPTION_ID` switch: the tenant id is a public ARM/AAD identifier - it is rendered in workflow telemetry on every `azure/login@v3` run, present in the OIDC token issuer URL, and visible to anyone with read access to the App Registration - not a credential. It is consumed in exactly one place: the `tenant-id:` input to `azure/login@v3`, which exchanges the OIDC token for an Azure AD token in the named tenant. It is **NOT** used to scope Azure Resource Graph queries and is **NOT** interpolated into portal deep-link URLs. Treating it as a Variable also means it appears plaintext in workflow logs (matching its non-sensitive nature) and removes the need for an extra Secret rotation in tenants that already track it as a Variable. Steady-state setup is now **one repo-level Secret** (`AZURE_CLIENT_ID`) and **two repo-level Variables** (`AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`); see updated docs in `Automation-Pipeline-Examples/README.md`. Azure DevOps pipelines authenticate via a service connection and need no change (the connection itself stores `tenantId`).

### Pipeline pin bumps + migration

All 14 `Step.{1..7}.yml` files (7 GitHub Actions + 7 Azure DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.71'` to `'0.7.72'`. The Step.0 authentication validation workflow does not pin a module version. Refresh existing copies via the marker-aware merge (preserves operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs):

```powershell
Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps
```

GitHub Actions operators must also create `AZURE_TENANT_ID` as a **repository Variable** (`gh variable set AZURE_TENANT_ID --body <tenantId>`) and delete the existing `AZURE_TENANT_ID` **Secret** to avoid drift between the two values.

### Compatibility

All v0.7.72 changes are backward compatible. No cmdlet signatures or output shapes change. The Variable migration is a per-tenant setup change (GitHub Actions only).


### What's New in v0.7.71

v0.7.71 is a **bug-fix + UX polish** release on top of v0.7.70. Two render-correctness fixes (Step.3 markdown rendering as a code block, Step.4 critical-count under-reporting as 0), one new action-required section in `Test-AzLocalApplyUpdatesScheduleCoverage -View Recommend` for unparseable cron expressions, hyperlinked Cluster Name + collapsible Verbose Error in the Step.6 Update Run History table, and the AZURE_SUBSCRIPTION_ID Secret -> Variable migration for GitHub Actions samples. All changes are additive over v0.7.70; no behaviour change for callers that don't read the new columns.

### What's New in v0.7.70

v0.7.70 is the **Step.0 recurring authentication audit + Step.6 Update Run History section + Step.6 manifest-anchored rolling support window + Step.3 dual-section UX + Step.7 fleet-health hyperlinks** release, plus two new exported cmdlets - `Get-AzLocalFleetHealthOverview` (ARG-first fleet-scale view of cluster health and update status) and `Get-AzLocalLatestSolutionVersion` (unauthenticated probe of the Microsoft Azure Local public solution-update catalog at `aka.ms/AzureEdgeUpdates`, used by Step.6 to anchor the SupportStatus column on the upstream release calendar). All changes are additive over v0.7.69; no behaviour change for callers that don't read the new columns.


### Step.0 repositioned as a recurring audit: Authentication Validation and Subscription Scope Report

`Step.0_authentication-test.yml` (GitHub Actions + Azure DevOps twins) is renamed from "Authentication Validation Test" to **"Step.0 - Authentication Validation and Subscription Scope Report"** and repositioned from a one-shot smoke test into a **recurring audit** intended to be re-run monthly (or after any RBAC change in the tenant). The pipeline now emits:
- A **JUnit XML** report (`auth-report.xml`) with three testsuites - **Authentication**, **Subscription Scope** (one testcase per accessible subscription, plus a count testcase), and **Resource Graph Reachability** (cluster count visible to the pipeline identity). Rendered in the GitHub Checks UI via `dorny/test-reporter@v3` and in the Azure DevOps **Tests** tab via `PublishTestResults@2`.
- A **markdown summary** at the top of every run with `Count of subscriptions = N` and a per-subscription detail table (Name / SubscriptionId / TenantId / State). Written to `$GITHUB_STEP_SUMMARY` on GitHub Actions and uploaded via `##vso[task.uploadsummary]` on Azure DevOps.
- A `auth-report` artifact (XML + `subscriptions.json` + `subscriptions.csv`) for ITSM / dashboard ingest.

Drift in the subscription scope visible to the pipeline identity is the earliest signal that downstream fleet reports are about to silently under- or over-count clusters, which is why the cadence is recurring rather than one-shot.

### Step.6 Fleet Update Status pipeline - new "Update Run History and Error Details" section

A new `<testsuite name="Update Run History and Error Details">` testsuite in the Step.6 JUnit XML and a matching `### Update Run History and Error Details` markdown table in the run summary surface up to 25 of the most recent unresolved Failed update runs across the fleet (last 30 days). Each row links to the Azure portal `SingleInstanceHistoryDetails` deep-link and includes Status / CurrentStep / Duration / LastUpdated / DeepestErrMsg for at-a-glance triage. Sourced from `Get-AzLocalUpdateRunFailures -State Failed -OnlyUnresolved` (ARG-first, fleet-scale).

### Step.6 Fleet Update Status pipeline - new "Overall Fleet Update Status (Version Distribution)" section with manifest-anchored rolling support window

A new `<testsuite name="Fleet Version Distribution">` testsuite is emitted as the **first** child of `<testsuites>` (before `AzureLocalFleetUpdateStatus`) and a matching `### Overall Fleet Update Status (Version Distribution)` markdown section is prepended to the run summary (above `### Critical Health Status`). One row per distinct `CurrentVersion` reported by `Get-AzLocalClusterUpdateReadiness`, sorted by cluster count descending, with columns: Version / YYMM / SupportStatus / Cluster Count / Percentage / Clusters.

`SupportStatus` uses a **rolling 6-month YYMM window anchored on the Microsoft public catalog** when reachable. The Step.6 step calls the new `Get-AzLocalLatestSolutionVersion` cmdlet (see below) to fetch the latest released solution version's YYMM from `https://aka.ms/AzureEdgeUpdates` and seeds a calendar-stepped 6-month window from it (e.g. latest YYMM `2604` -> `2604,2603,2602,2601,2512,2511`). As soon as Microsoft publishes any release with a newer YYMM, the window slides forward and the oldest in-window YYMM falls out automatically - independent of what is installed in the fleet. The JUnit testsuite carries `supportSource` / `latestReleasedYymm` / `latestReleasedVersion` / `manifestUrl` / `manifestFetchedAt` properties; the markdown summary annotates which anchor source was used and (on success) prints the latest released YYMM + version.

When the manifest is unreachable from the runner the pipeline emits a non-fatal warning (`::warning::` on GitHub Actions, `##vso[task.logissue type=warning]` on Azure DevOps) and falls back to a **fleet-observed top-6 YYMM heuristic** so Step.6 still reports (`supportSource='fleet-observed'`). **Supported** = cluster's YYMM is inside the anchor window; **Unsupported** = older parseable YYMM; **Unknown** = empty / malformed `CurrentVersion`. The markdown section includes inline links to the Microsoft Azure Local [lifecycle cadence](https://learn.microsoft.com/azure/azure-local/update/about-updates-23h2#lifecycle-cadence) and [release information](https://learn.microsoft.com/azure/azure-local/release-information-23h2#about-azure-local-releases) docs as the operator cross-check. No `<failure>` tags - the testsuite is informational and never breaks the build.

### New cmdlet: `Get-AzLocalLatestSolutionVersion`

Unauthenticated probe of the Microsoft Azure Local public solution-update catalog at `https://aka.ms/AzureEdgeUpdates`. Returns the latest released solution version plus the rolling YYMM support window calendar-stepped from it (year-rollover honoured). Used by Step.6 to anchor the SupportStatus column on the upstream catalog instead of fleet-observed values, so older releases drop out of support automatically as soon as Microsoft publishes a newer YYMM.

Output PSCustomObject: `LatestYYMM`, `LatestVersion`, `SupportedYYMMs[]` (length = `-SupportWindowMonths`, default 6, configurable 1-24), `AllReleases[]`, `ManifestUrl`, `ManifestFetchedAt` (UTC), `SupportWindowMonths`, `Source = 'aka.ms/AzureEdgeUpdates'`. Tolerant of both XML shapes the manifest exposes (`ApplicableUpdate/UpdateInfo` and `PackageMetadata/ServicesUpdates/Update/UpdateInfo`).

```powershell
# Default - latest released YYMM + 6-month rolling window
Get-AzLocalLatestSolutionVersion | Format-List LatestYYMM, LatestVersion, SupportedYYMMs

# 12-month rolling window (e.g. for slower-moving regulated fleets)
Get-AzLocalLatestSolutionVersion -SupportWindowMonths 12

# Pin to a private mirror of the manifest (must be http(s))
Get-AzLocalLatestSolutionVersion -ManifestUrl 'https://internal.example.com/AzureEdgeUpdates.xml' -TimeoutSeconds 60
```

### New cmdlet: `Get-AzLocalFleetHealthOverview`

ARG-first fleet health summary. One row per cluster, joining `microsoft.azurestackhci/clusters` with the cluster's `updateSummaries` extensibility resource via a single Azure Resource Graph batch read. 12 columns in fixed order: `ClusterName`, `ClusterPortalUrl`, `HealthStatus`, `UpdateStatus`, `CurrentVersion`, `SbeVersion`, `AzureConnection`, `LastChecked`, `HealthResultsAgeDays` (computed as `datetime_diff('day', now(), LastChecked)`), `ResourceGroup`, `NodeCount`, `SubscriptionId`. Sort: `HealthResultsAgeDays desc, ClusterName asc` so the most-stale clusters surface first.

```powershell
# Whole-fleet rollup
Get-AzLocalFleetHealthOverview -SubscriptionId <subId> | Format-Table

# Filter to a ring (wildcard '***' = every cluster carrying ANY UpdateRing tag)
Get-AzLocalFleetHealthOverview -UpdateRingTag '***' -SubscriptionId <subId>

# Export to CSV for ITSM / dashboard ingest
Get-AzLocalFleetHealthOverview -SubscriptionId <subId> -ExportPath .\fleet-health-overview.csv -PassThru
```

### Step.3 audit pipeline - dual-section UX

The `Test-AzLocalApplyUpdatesScheduleCoverage` cmdlet's Audit rows now carry a `Section` discriminator that splits the audit into two conceptually distinct concerns:

| `Section` | Status values | Unit of work |
|---|---|---|
| `Schedule` | `RingMissingFromSchedule`, `RingOrphanedInSchedule` | The ring (`UpdateWindow` / `RequiredCronUTC` deliberately empty - these are about ring mapping, not window mapping) |
| `Cron` | `Covered`, `PartiallyCovered`, `Uncovered`, `MalformedTag`, `UnparseableCron` | The `(ring, UpdateWindow)` pair vs the Step.5 cron entries |

Audit rows now sort `Schedule`-first, then `Cron`. `-View Recommend` is now a multi-section markdown report: an "Action required - add these rings to apply-updates-schedule.yml" block when `RingMissingFromSchedule` rows exist (emitted FIRST), followed by an "Action required - cron coverage (paste into Step.5_apply-updates.yml)" block. When `-SchedulePath` is omitted, only the cron section is emitted (back-compat for v0.7.68 callers).

The `Step.3_apply-updates-schedule-audit.yml` pipeline YAMLs (GH + ADO) mirror this in their summary:
- Two JUnit `<testsuite>` blocks (`ScheduleCoverage` + `CronCoverage`) so the Tests tab shows per-section pass/fail counts.
- Two Audit Detail markdown tables (one per section) with conditional headings - empty sections still emit a placeholder row so the operator can see the section was evaluated.
- When `$hasIssues -and $reco`, the `-View Recommend` cmdlet output is prepended above the detail tables so operators see the fix before scrolling.
- The zero-row JUnit placeholder text is centralised via a new `Write-Suite -EmptyPlaceholderName 'No tagged clusters found - nothing to audit'` helper (GH-vs-ADO parity preserved since v0.7.67).

### Step.7 fleet-health pipeline - cluster portal hyperlinks + 3 new detailed columns + new Fleet Health Overview section

`Get-AzLocalFleetHealthFailures` (the v0.7.65 cmdlet) gains three deep-link / target-resource properties on Detail rows - `TargetResourceName` (the sub-resource that emitted the check failure, e.g. the NIC name), `TargetResourceType` (e.g. `Microsoft.Compute/virtualMachines/networkInterfaces`), and `ClusterPortalUrl` (`https://portal.azure.com/#@/resource{ClusterResourceId}` deep-link). Summary rows gain `AffectedClusterPortalUrls` aligned with `AffectedClusters` (same element count, same order, joined with `'; '`). The Summary now sorts **Critical-first**: Severity (Critical, then Warning, then everything else), then `ClusterCount` desc, then `FailureCount` desc - a Critical failure on 1 cluster ranks above a Warning affecting many clusters.

The `Step.7_fleet-health-status.yml` pipeline YAMLs (GH + ADO) consume these in three places:
- **Summary and Detailed Results cluster cells** render as `[ClusterName](portalUrl)` markdown links. The Summary caps at the first 10 then renders `... (+N more)`; the Detail tables link every cell.
- **Three new Detailed Results columns**: Failure Remediation (auto-renders as `[link](url)` when the value starts with `https://`, otherwise plain text), Target Resource Name, Target Resource Type.
- **New `### Fleet Health Overview (fleet rollup)` section** calls the new `Get-AzLocalFleetHealthOverview` cmdlet and surfaces the per-cluster 9-column rollup alongside the failures table. The mapping `OK` / `Critical` / `Warning` / `In progress` / `Failed` is rendered with bracketed labels (`[OK]`, `[Critical]`, etc.) so the at-a-glance summary is greppable. New report artifacts: `fleet-health-overview.csv` and `fleet-health-overview.json`.

### Pipeline pin bumps + migration

All 14 `Step.*.yml` files (7 GitHub Actions + 7 Azure DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.69'` to `'0.7.70'`. The recommended upgrade path is the marker-aware merge (preserves operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs):

```powershell
Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps
```

### Compatibility

All v0.7.70 changes are backward compatible. The `Section` column defaults to `Cron` for downstream filters that don't know about the discriminator; new `TargetResource*` / `ClusterPortalUrl` / `AffectedClusterPortalUrls` properties are additive (existing pipeline summaries that read only the v0.7.69 schema keep working).

### Pester baseline

**585 passed / 0 failed / 0 skipped (unit) + 16 passed / 0 failed / 0 skipped (Live-Integration, opt-in)** - the unit suite stays hermetic and now includes a parallel, tag-gated `Tests/Live-Integration.Tests.ps1` durable suite that asserts the three v0.7.70 ARG-first cmdlets (`Get-AzLocalFleetHealthOverview`, `Get-AzLocalFleetHealthFailures`, `Get-AzLocalUpdateRunFailures`) against a real Azure Local fleet. The Live suite is **excluded by default** and safe to leave in the repo: each Describe self-skips when `az` is not installed, not logged in, or pointed at a non-target subscription. Opt in with `.\Tests\Invoke-Tests.ps1 -IncludeLive` or `-LiveOnly`. Validated end-to-end against a 20-cluster fleet (49 unresolved health failures, 9 unresolved Failed update runs) in 1m26s.

### What's New in v0.7.69

v0.7.69 introduces the **ring-aware apply-updates schedule** - a single human-readable YAML file (`apply-updates-schedule.yml`, `schemaVersion: 1`) that controls which `UpdateRing` tag value the apply-updates pipeline targets on any given UTC date. The schedule is decoupled from cron entirely: Step.5's cron only controls **how often** the pipeline wakes up, the per-cluster `UpdateWindow` tag controls **when** during an eligible day the update actually runs, and this new file controls **which ring** is eligible TODAY. Five new cmdlets (one generator + one reader + one resolver + one previewer + one migrator) plus a two-way ring diff on `Test-AzLocalApplyUpdatesScheduleCoverage` round out the feature.

### Strawman workflow (the safety gate is the whole point)

```powershell
# 1. Generate a STRAWMAN from your live fleet's UpdateRing tag values.
#    Every schedule row is emitted commented-out by design.
New-AzLocalApplyUpdatesScheduleConfig -OutputPath .\.github\apply-updates-schedule.yml

# 2. Open the file. REVIEW each strawman row, then UNCOMMENT the rows
#    that match your change-control policy.

# 3. Preview the next ~cycle of firings BEFORE committing.
Get-AzLocalApplyUpdatesScheduleNextFirings `
  -Schedule (Get-AzLocalApplyUpdatesScheduleConfig -Path .\.github\apply-updates-schedule.yml)

# 4. Refresh the Step.5 pipeline YAMLs so they pick up the v0.7.69 resolver wiring.
Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub

# 5. Audit the fleet against the schedule (two-way ring diff).
Test-AzLocalApplyUpdatesScheduleCoverage `
  -PipelineYamlPath .\.github\workflows\Step.5_apply-updates.yml `
  -SchedulePath     .\.github\apply-updates-schedule.yml `
  -View Audit
```

> Without an active (uncommented) row, the apply-updates pipeline **hard-fails** at the reader step with `'schedule:' list is empty - at least one row is required`. This is the v0.7.69 safety gate, not a bug. It guarantees that a fresh strawman cannot accidentally start applying updates fleet-wide.

### Three independent layers - one file per layer

| Layer | File / Setting | Grain | Controls |
|---|---|---|---|
| 1 | `Step.5_apply-updates.yml` `schedule:` cron | intra-day | **HOW OFTEN** the pipeline wakes up |
| 2 | `apply-updates-schedule.yml` (NEW in v0.7.69) | day | **WHICH** `UpdateRing` is eligible on a given UTC date |
| 3 | Per-cluster `UpdateWindow` tag | minute | **WHEN** during an eligible day the update is allowed to start |

The Step.5 cron firing on a non-matching day exits 0 with the explanatory `Reason` and **does not** start an update. The cron firing on a matching day passes the resolved `UpdateRing` value to `Start-AzLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue <resolved>`.

### Five new cmdlets

| Cmdlet | Role |
|---|---|
| `New-AzLocalApplyUpdatesScheduleConfig` | Generates a **strawman** schedule from the live fleet's `UpdateRing` tag values (or from `-Rings` for offline use). Every emitted schedule row is commented out by design. |
| `Get-AzLocalApplyUpdatesScheduleConfig` | Parses + validates a schedule file. Hard-fails with `'schedule:' list is empty` when no active rows are present (the safety gate). |
| `Resolve-AzLocalCurrentUpdateRing` | Maps a UTC date to the matching `UpdateRing(s)` using cycle-week math anchored at `cycleAnchorISOWeek` / `cycleAnchorYear`. Union semantics: overlapping rows merge `rings` with `;`. |
| `Get-AzLocalApplyUpdatesScheduleNextFirings` | Previews the next N days of resolved firings so operators can sanity-check the rotation BEFORE committing. |
| `Update-AzLocalApplyUpdatesScheduleConfig` | Idempotent schema-version migrator. Renames the original to `<basename>.v<oldVersion>.old.yml` on disk and writes the migrated content to the canonical path. The recipes table is intentionally empty in v0.7.69; the framework is in place for future schema bumps. |

### Two-way ring diff on `Test-AzLocalApplyUpdatesScheduleCoverage`

The existing schedule-audit cmdlet gained an optional `-SchedulePath` parameter. When supplied, the audit emits two new status rows beyond the existing cron-vs-tags audit:

| Status | Meaning |
|---|---|
| `RingMissingFromSchedule` | A fleet ring (live `UpdateRing` tag value on a cluster) has **no** matching row in the schedule file - clusters in that ring will never be updated. |
| `RingOrphanedInSchedule` | A schedule ring (a `rings:` token in the schedule file) has **no** cluster carrying that tag value - the schedule row will never fire. |

Both rows are surfaced in the Step.3 summary table, the JUnit XML failure list, and the Markdown summary at the top of the Step.3 run page.

### Step.5 / Step.3 pipeline wiring

- **Step.5 (apply-updates)** now resolves the `UpdateRing` from the schedule file on every **scheduled** firing. Manual `workflow_dispatch` (GitHub Actions) / non-`Schedule` `Build.Reason` (Azure DevOps) runs still honour the operator-supplied `-UpdateRingValue` input verbatim. A workflow-level `concurrency:` block (GitHub Actions only - Azure DevOps documents the equivalent **Settings -> Triggers -> Limit concurrent runs** option) prevents overlapping cron firings.
- **Step.3 (schedule audit)** gained a `schedule_path` / `schedulePath` input (defaulted to the standard layout), a `debug` toggle for self-service triage, and surfaces the new `RingMissingFromSchedule` / `RingOrphanedInSchedule` counts.

### What v0.7.69 does NOT touch

- `apply-updates-schedule.example.yml` ships as **documentation only**. `Copy-AzLocalPipelineExample` and `Update-AzLocalPipelineExample` do **not** copy or refresh it. Operators run `New-AzLocalApplyUpdatesScheduleConfig` to generate a strawman starting from their live fleet.
- The per-cluster `UpdateWindow` tag, the `UpdateSideloaded` workflow, and all existing cron schedules in the bundled pipeline YAMLs are unchanged.

### Breaking

- Schema `schemaVersion: 1` is a hard break vs any pre-v0.7.69 experimental schedule format. There are no v0 -> v1 migration recipes shipped (the recipes table is intentionally empty in `Update-AzLocalApplyUpdatesScheduleConfig`); if you were running an experimental schedule from earlier development builds, regenerate via `New-AzLocalApplyUpdatesScheduleConfig`.

### What's New in v0.7.68

v0.7.68 is the **ARG-first refactor** and **pipeline-rename** release. Seven fleet-scale read cmdlets were collapsed onto a single Azure Resource Graph batch read each (removing the silent `-ThrottleLimit` no-op), all 16 bundled pipeline YAMLs were renamed with a `Step.X_` ordering prefix so an alphabetic listing tells the story end-to-end, and a new `Get-AzLocalUpdateRunFailures` cmdlet exposes the deep-error breadcrumb path from update-run telemetry without per-cluster shell-outs. **Backwards-compatible** for already-deployed consumers: `Read-AzLocalApplyUpdatesYamlCrons` matches both new (`Step.X_*.yml`) and legacy filenames.

### ARG-first refactor

- **Seven cmdlets are now single-batch ARG reads with `-ThrottleLimit` removed.** `-ThrottleLimit` was a meaningless flag against the ARG batched read path; carrying it implied (incorrectly) that the cmdlet was doing a per-cluster fan-out and could be tuned for throttle. The new shape removes the parameter and collapses the call onto one ARG query, which (a) cuts subscription-level ARM call volume 5-10x on the common fleet-status pipelines and (b) lets the helper apply uniform 429/`Retry-After` retry logic in one place. Affected cmdlets: `Get-AzLocalUpdateSummary`, `Get-AzLocalAvailableUpdates`, `Get-AzLocalClusterUpdateReadiness`, `Test-AzLocalClusterHealth`, `Get-AzLocalFleetProgress`, `Get-AzLocalFleetStatusData`, `New-AzLocalFleetStatusHtmlReport`. All bundled pipeline YAMLs were updated to stop passing `-ThrottleLimit`.

- **`Invoke-AzResourceGraphQuery` now retries on HTTP 429 (throttle).** Inspects the `Retry-After` response header when present and otherwise applies bounded exponential backoff (capped at the documented Azure Resource Graph throttling envelope). Large fleet sweeps no longer fall over at the throttling boundary; happy-path latency is unchanged.

- **`Invoke-AzResourceGraphQuery` hardened against `az.cmd` CR/LF stdout truncation.** A latent bug in `az.cmd` (Windows runners) could chop the JSON payload at the first chunked-write boundary when stdout was piped through PowerShell, producing the N-row collapse where a 27-cluster fleet would surface as 24 rows. The helper now decodes the full UTF-8 payload explicitly; existing Pester tests pin the regression.

- **`Get-AzLocalFleetProgress` no longer silently returns stale state when ARG returns zero rows.** The previous code-path treated an empty ARG response as "no change" and returned the last cached state; consumers (including the `Step.6_fleet-update-status.yml` JUnit emitter) therefore reported "everything green" on fleets that had been completely de-tagged or that hit a transient ARG error. The cmdlet now surfaces the empty-fleet condition explicitly so the operator can act on it.

### New: `Get-AzLocalUpdateRunFailures`

- **ARG-only deep-error extraction** (9 levels deep into the `properties.state.progress` tree of `microsoft.azurestackhci/clusters/updates/updateRuns`) returns verbose error information at fleet scale without per-cluster Az SDK or REST shell-outs. Two views: `-View Summary` (one row per failed update run) and `-View Detail` (one row per leaf failure with the full breadcrumb to the failed step). Useful in `Step.5_apply-updates.yml` post-mortem reports and as a follow-up call after `Get-AzLocalFleetProgress` reports failures.

### New: `Update-AzLocalPipelineExample` (marker-aware upgrade tool)

- **Marker-aware merge tool** that refreshes a customer's copy of any bundled pipeline YAML to the version shipped with the current module **while preserving operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs**. Customer-side cron schedules in `schedule-triggers` and ITSM secret bindings in `itsm-secrets` (Step.5 only) survive a module upgrade; everything outside the markers is replaced with the new bundled content. Supports `-WhatIf`, `-DryRun`, multi-file batch mode, and emits a per-file change manifest so the operator can review the merge before committing. This is the operator-friendly upgrade path that `Copy-AzLocalPipelineExample` (clean overwrite) does not provide.

### Pipeline samples - `Step.X_` rename

- **All 16 bundled pipeline YAMLs renamed with a `Step.X_` ordering prefix** so they sort by execution order in a customer's repo (`Step.0_authentication-test.yml`, `Step.1_inventory-clusters.yml`, `Step.2_manage-updatering-tags.yml`, `Step.3_apply-updates-schedule-audit.yml`, `Step.4_assess-update-readiness.yml`, `Step.5_apply-updates.yml`, `Step.6_fleet-update-status.yml`, `Step.7_fleet-health-status.yml`). Both platforms (GitHub Actions + Azure DevOps). The rename matches the documented operator runbook order so an alphabetic listing in the consumer's IDE / repo browser tells the story end-to-end.

- **Backwards compatibility for already-deployed consumers:** `Read-AzLocalApplyUpdatesYamlCrons` (the schedule-audit scanner) glob list expanded to match both new (`Step.5_apply-updates*.yml`) and legacy (`apply-updates*.yml`) names. A customer who upgrades the module but has not yet re-run `Copy-AzLocalPipelineExample` will still see correct schedule-coverage audits.

- **Each YAML's workflow display name now also carries the `Step.N - ` prefix.** GitHub Actions sidebar sorts workflows alphabetically by the YAML's top-level `name:` field, so the 8 workflows now read `Step.0 - Authentication Validation and Subscription Scope Report` ... `Step.7 - Fleet Health Status` and list in execution order. For Azure DevOps the leading title comment in each YAML carries the same prefix so the import wizard prefills the suggested pipeline definition name correctly. See [`Automation-Pipeline-Examples/README.md` section 1.1](./Automation-Pipeline-Examples/README.md#11-why-the-pipelines-are-named-stepn---description) for the full convention.

### Pipeline samples - Layer 1 customisation markers (scaffolding)

- **Seven YAMLs now carry named `AZLOCAL-CUSTOMIZE` marker pairs** (6 main pipelines x `schedule-triggers`, plus `Step.5_apply-updates.yml` x `itsm-secrets`) wrapping the YAML regions operators commonly customise. Markers are pure YAML comments and have no runtime effect; they back the new `Update-AzLocalPipelineExample` cmdlet (also new in v0.7.68) that performs a marker-aware merge so operator edits inside the marker pairs survive a module upgrade. `Copy-AzLocalPipelineExample` remains the clean-overwrite tool for first-time install / forced refresh.

### Pipeline migration

If you have copied any of the bundled workflows into your repo, the recommended upgrade path is the new marker-aware merge:

```powershell
Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps
```

(Add `-WhatIf` first to preview the merge before writing files; add `-Force` to skip the per-file confirm prompt for non-interactive runs.)

This brings in the new file names *and* the Layer 1 marker scaffolding **while preserving** operator-customised cron schedules and ITSM secret bindings inside `BEGIN-AZLOCAL-CUSTOMIZE` / `END-AZLOCAL-CUSTOMIZE` marker pairs in your already-deployed YAMLs.

For a clean overwrite (first-time install or forced refresh that discards local edits), keep using `Copy-AzLocalPipelineExample`:

```powershell
Copy-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub      -Update
Copy-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps -Update
```

### Inventory & design doc

- **New `docs/Cmdlet-Inventory-And-Design.md`** documents which cmdlets read vs write, which back-end they use (ARG vs Az SDK vs az CLI), and the design rules that keep read paths ARG-first (no `-ThrottleLimit`, no per-cluster Get-AzResource fan-out). Removes ambiguity about which back-end a new cmdlet should take.

### What's New in v0.7.67

v0.7.67 lands a Phase 3/4 CI/CD-parity refresh, a new maintainer-facing release-process document, and a six-item batch of in-depth-review fixes. **No public surface change** - every pre-existing pipeline and cmdlet keeps the same contract.

#### CI/CD parity + UX

- **GitHub Actions schedule-audit pipeline now emits a passing testcase when the fleet has no tagged clusters.** Previously the GH variant of `Step.3_apply-updates-schedule-audit.yml` wrote an empty `<testsuite>` whenever there were no `(UpdateRing, UpdateWindow)` rows to evaluate; `dorny/test-reporter` then reported "no tests found", indistinguishable from a misconfigured reporter step. The pipeline now writes `<testcase classname="ScheduleCoverage" name="No tagged clusters found - nothing to audit" />` for the zero-row case, matching the long-standing Azure DevOps behaviour. The Tests tab reads cleanly as "passed (1/1)" regardless of whether the fleet has any tagged clusters yet, removing the daily false-alarm during onboarding and after fleet-wide tag clean-ups.

- **Schedule-audit summary now surfaces the cron recommendation block at the TOP when coverage drift exists.** Both `Step.3_apply-updates-schedule-audit.yml` files (GitHub Actions and Azure DevOps) previously emitted the recommended cron block at the bottom of the run summary, after the audit detail table. When the audit reported any `Uncovered` / `PartiallyCovered` / `MalformedTag` / `UnparseableCron` rows, operators had to scroll past the detail table to find the actionable fix. The pipelines now render an `### Action required - paste these cron entries into Step.5_apply-updates.yml` section immediately below the counts table when issues exist; when the fleet is fully covered, the recommendation block stays at the bottom as a reference. A new Pester guard asserts both YAMLs carry the conditional structure and the ordering.

- **Pipeline README now includes an artifact-handoff data-flow diagram.** Section 6 of [`Automation-Pipeline-Examples/README.md`](Automation-Pipeline-Examples/README.md) already carried a phase-oriented flow diagram (Inventory -> Tag -> Rollout -> Steady-state); the new "Artifact handoffs at a glance" subsection makes the data flow explicit, showing which artifact each pipeline emits and which downstream pipeline consumes it (e.g. `cluster-inventory.csv` -> manual tagging edit + manage-tags pipeline; `cluster-readiness.csv` -> apply-updates; `schedule-coverage-recommend.md` -> manual paste into `Step.5_apply-updates.yml`). Calls out the four artifacts operators most commonly trip on.

- **Pipeline README section 11 (Security model) now documents per-job `permissions:` blocks as an intentional security feature.** Every shipped GitHub Actions workflow declares its own job-level `permissions:` block (`id-token: write`, `contents: read`, `checks: write` only where needed). The new bullet calls out that consumers should not lift these blocks to a top-level `permissions:` block when copying samples, explains how the per-job shape (a) limits token scope to exactly the job that needs the write and (b) lets you keep `id-token: write` off read-only summary jobs, and documents that the samples are compatible with the recommended *Settings -> Actions -> General -> Workflow permissions = Read repository contents and packages permissions* hardening.

- **All Azure DevOps sample pipelines now share the same `azureSubscription:` placeholder.** Four files (`Step.4_assess-update-readiness.yml`, `Step.7_fleet-health-status.yml`, `Step.6_fleet-update-status.yml`, `Step.3_apply-updates-schedule-audit.yml`) previously used `'YOUR-SERVICE-CONNECTION-NAME'` while the other four ADO YAMLs used `'AzureLocal-ServiceConnection'`. All eight ADO pipelines now use `'AzureLocal-ServiceConnection'` plus a `# Update with your service connection name` comment, matching the value documented in section 3.2 of the pipeline README. An operator who follows the auth setup verbatim no longer has to find-and-replace anything in the YAMLs.

#### New maintainer doc: `docs/RELEASE-PROCESS.md`

- **Documents the staged unlisted-release flow** the module uses (publish -> immediately unlist -> validate against a test repo with `REQUIRED_MODULE_VERSION` exact-pinned to the candidate -> list after validation passes), the verification commands for each stage, and the Pester guardrails the release flow relies on. This puts the release rules in the repo rather than in tribal knowledge / chat history. Pipeline consumers do not need this doc; module maintainers do.

#### Fixed (in-depth module review - batch 3)

Six defence-in-depth fixes following the post-PR-#36 module review. **None are user-visible behaviour changes for the happy path** - every fix closes a class of silent-drift or silent-drop bug.

- **`$script:ModuleVersion` constant in `AzLocal.UpdateManagement.psm1` was stuck at `0.7.66` while the manifest moved to `0.7.67`.** The script-scope constant is the value `Start-AzLocalClusterUpdate` writes into its run-log header and the value `Get-AzLocalFleetStatusData` stamps into the `ModuleVersion` field of the exported fleet-state JSON, so every v0.7.67 run-log and every v0.7.67 fleet-state file was misreporting the producing module version - which is the exact field operators use to triage CI vs local-runner discrepancies. Bumped to `0.7.67`; a new Pester guard `Module version constants are in sync between .psm1 and .psd1` compares `(Import-PowerShellDataFile).ModuleVersion` against `InModuleScope { $script:ModuleVersion }` and fails any future drift at build time.

- **cp1252 stderr-warning regression that v0.7.66 fixed in `Invoke-AzResourceGraphQuery` had three remaining ambush sites.** The unsafe `az ... 2>&1 | ConvertFrom-Json` pattern was still live in `Get-AzLocalClusterInventory` resolving subscription display names via `az account show`, `Invoke-AzLocalSideloadedAutoResetForCluster` reading the cluster tags via `az rest`, and `Set-AzLocalClusterTagsMerge` reading the tags-subresource via `az rest`. The two `az rest` callers now route through the existing `Invoke-AzRestJson`. The `az account show` caller goes through a new private helper `Invoke-AzCliJson`, which applies the same stream-split-by-element-type pattern, auto-appends `--only-show-errors`, sets `PYTHONIOENCODING=utf-8` as defence-in-depth (restored in `finally`), and returns `[PSCustomObject]@{ Ok; Data; Error }` so callers no longer have to inspect `$LASTEXITCODE` manually. Seven new Pester tests cover the helper.

- **`ConvertFrom-AzLocalCronExpression` now accepts cron step syntax (`*/N`, `<a>-<b>/N`, `<a>/N`).** The schedule advisor was falsely flagging crons such as `*/15 * * * *` (every 15 min), `0 */6 * * 1` (every 6 hr on Mondays), and `0 9-17/2 * * 1-5` (every 2 hr between 09:00 and 17:00 on weekdays) as `UnparseableCron` - even though both GitHub Actions and Azure DevOps schedule them correctly. The parser now expands `*/N` over the field's full range, `<a>-<b>/N` over the explicit `[a,b]` range, and `<a>/N` over `[a, max]`. Step values must be positive integers; out-of-bounds bases still throw with the existing bounds messages. Four new Pester tests (3 positive + `*/0` negative); the pre-existing test asserting `*/15` was *rejected* has been flipped to assert the 672-fires-per-week expansion is correct.

- **`Reset-AzLocalSideloadedTag` now warns when a `-ClusterResourceIds` entry does not match `/clusters/<name>$`.** The `ByResourceId` resolver previously dropped malformed entries (typos, trailing slash, wrong provider, truncated string) silently - the operator would see "no matching clusters" without any indication that an input had been excluded. The resolver now emits `Write-Log -Level Warning` naming the exact `ResourceId` it skipped. This brings parity with the `ByName` / `ByTag` resolvers, which already warned on lookup failure. New regression test.

- **`Tests/Invoke-Tests.ps1` HTML footer no longer prints `Module Version: System.Object[]`.** When nested modules are loaded (the default for this module - every Private/*.ps1 is a nested module), `Get-Module AzLocal.UpdateManagement` returns one entry per loaded version, and `.Version` on that array surfaces as `Object[]`. The HTML test report footer was therefore intermittently printing `Module Version: System.Object[]`. The test runner now selects the newest loaded version via `Sort-Object Version -Descending | Select-Object -First 1` before reading `.Version`.

- **`Import-AzLocalFleetState` now caps input at 50 MB before reading.** The helper previously called `Get-Content -Raw | ConvertFrom-Json` with no size check; pointing it at a multi-GB file (typo, mis-glob, malicious symlink) would have OOMed the runner. Real fleet-state files (`Export-AzLocalFleetState` output) are tens of KB at most, so a 50 MB ceiling is ~3 orders of magnitude above any plausible legitimate input. The cap message names the actual file size in MB and explains what valid input looks like. Two new Pester tests (mocked-oversize trip + happy path).

#### Pester baseline

**485 passed / 0 failed / 0 skipped** (was 471 at v0.7.66) - the +14 new tests cover the drift guard, `Invoke-AzCliJson` (7), cron `*/N` (4), `Reset-AzLocalSideloadedTag` warning (1), and `Import-AzLocalFleetState` size guard (2).

#### Pipeline migration

If you have copied any of the bundled workflows into your repo, refresh them via:

```powershell
Copy-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub      -Update
Copy-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps -Update
```
### What's New in v0.7.66

v0.7.66 is a CI/CD hotfix release. Two errors were observed on production runs of the `fleet-health-status` and `apply-updates-schedule-audit` pipelines on `windows-latest` GitHub Actions runners; both have a clean root cause and a minimal patch. No public surface change.

- **Fixed (critical) - `Get-AzLocalFleetHealthFailures` failed JSON parsing when the Azure CLI emitted a cp1252 encoding warning to stderr.** On `windows-latest` runners (or any ADO Windows agent whose console code page is `cp1252`), the Azure CLI's underlying Python layer can surface this stderr line:

  ```
  WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.
  ```

  The shared `Invoke-AzResourceGraphQuery` helper was capturing `& az graph query ... 2>&1` as a single merged stream and feeding the entire thing to `ConvertFrom-Json`. The WARNING line therefore got prepended to the JSON body and the cmdlet threw `Conversion from JSON failed with error: Unexpected character encountered while parsing value: W. Path '', line 0, position 0.` This is the same class of bug that the v0.7.2 hardening of `Invoke-AzRestJson` already handled - the fix never made it into `Invoke-AzResourceGraphQuery` when that helper was split out. **The actual fix in v0.7.66** is the post-capture stream split: the helper splits the merged `2>&1` stream by element type, surfacing stderr lines as `[System.Management.Automation.ErrorRecord]` objects (which `2>&1` boxes them as) and stdout lines as strings; only the string stream is fed to `ConvertFrom-Json`. (The helper already passed `--only-show-errors` since v0.7.2, but the cp1252 encode warning can still leak through on some character paths, hence the belt-and-braces split.) The helper also sets `$env:PYTHONIOENCODING = 'utf-8'` for the duration of the call as **cosmetic defence-in-depth only** - this is a structural no-op for stock `az.cmd` because `az.cmd` launches Python with the `-I` (isolated) flag, which implies `-E` and causes Python to ignore every `PYTHON*` env var (confirmed in [Azure/azure-cli#28497](https://github.com/Azure/azure-cli/issues/28497) and the v0.7.2 root-cause analysis). The assignment only takes effect on hosts that have manually patched `az.cmd` to remove `-I`. The previous value is restored in a `finally` block. Every fleet-health-status pipeline run on a Windows runner is now resilient to this stderr warning.

- **Fixed (critical) - `Step.3_apply-updates-schedule-audit.yml` (both GitHub Actions and Azure DevOps) shipped with a default `pipeline_path` that only exists in *this* module's source repo.** The shipped default was `AzLocal.UpdateManagement/Automation-Pipeline-Examples`. In a consumer repo - where `Step.5_apply-updates.yml` lives under `.github/workflows/` (GH) or `.azure-pipelines/` (ADO) - that path does not exist and every default-trigger run failed with `PipelineYamlPath '...' does not exist on the runner` before the schedule advisor could write its JUnit XML, which then crashed `dorny/test-reporter` with `No test report files were found`. The defaults now match the standard consumer layout: `.github/workflows` on GitHub Actions, `.azure-pipelines` on Azure DevOps. When the resolved path is still missing on the runner, the audit step now lists which common pipeline folders **do** exist in the checked-out repo (`.github/workflows`, `.azure-pipelines`, `pipelines`, repo root) so the operator immediately knows what value to pass via `workflow_dispatch` / queue-time override.

#### v0.7.66 UX + capability refresh

In addition to the two hotfixes above, v0.7.66 ships a focused UX refresh of the `fleet-update-status` summary, timestamped artifact downloads across every pipeline, and multi-value / wildcard `UpdateRing` inputs on every exposed pipeline parameter and cmdlet.

- **Status emojis in the Fleet Update Status summary.** `Step.6_fleet-update-status.yml` (GitHub Actions and Azure DevOps) now renders the `Critical Health` and `Primary Status` summary tables with a green tick / red cross / refresh / yellow circle / info glyph - the same visual language operators already use to read JUnit dashboards. The legacy `[ok] / [fail] / [ready] / [running] / [blocked] / [info]` bracket markers are gone. Plain markdown, so it renders identically on the GH Actions step summary, the ADO pipeline run extension, and any markdown viewer (no JS, no images).
- **Generation timestamp in the Fleet Update Status H2 heading.** Both `Step.6_fleet-update-status.yml` files now render the H2 heading as `## Fleet Update Status Summary  _(generated YYYY-MM-DD HH:MM:SS UTC)_`. Operators no longer have to cross-reference the pipeline run start time to know when the data was collected.
- **Failed clusters appear before passing clusters in the JUnit per-cluster block.** The per-cluster `<testcase>` ordering in `Step.6_fleet-update-status.yml` (both platforms) is now bucketed: failed first (sorted alphabetically by `ClusterName`), then passed (sorted alphabetically). Failing clusters lead the dorny/test-reporter view (GitHub) and the Tests tab (Azure DevOps).
- **Every downloadable pipeline artifact now carries a UTC timestamp suffix.** All `actions/upload-artifact` steps (GH) and `PublishBuildArtifacts@1` / `PublishPipelineArtifact@1` tasks (ADO) now declare `name:` / `ArtifactName:` of the form `azlocal-<purpose>_yyyyMMdd_HHmmss`. Each job computes the timestamp once in a dedicated `Compute Artifact Timestamp` step. Two runs of the same pipeline on the same day now produce distinct zip downloads (`azlocal-fleet-update-status-report_20260518_140000.zip` vs `azlocal-fleet-update-status-report_20260518_180000.zip`) instead of clobbering each other in the operator's downloads folder.
- **Pipeline `UpdateRing` inputs accept multi-value lists and the literal `***` wildcard.** Every pipeline that exposes `update_ring:` (GH `workflow_dispatch`) or `updateRing:` (ADO `parameters:`) now accepts:
  - A single ring (unchanged): `Wave1`
  - A semicolon-delimited list: `Prod;Ring2` (whitespace around each ring is trimmed)
  - The wildcard `***` (three stars, deliberate gesture) to match every cluster that **has** a non-empty `UpdateRing` tag. **Untagged clusters are excluded**, preserving the existing opt-in gate. A single `*`, double `**`, or quadruple `****` are all REJECTED by the cmdlet's `[ValidatePattern]` so a one-character typo can no longer accidentally scope a fleet-wide write.

  The ADO `Step.5_apply-updates.yml` lost its closed `values:` enum (kept `type: string` so users still get a free-text editor in the ADO run dialog).
- **`[ValidatePattern]` tightened on 15 cmdlets** to match: `^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$`. Each individual ring segment keeps the same 1-64 character `[A-Za-z0-9_-]` policy as v0.7.65; the changes are (a) `;`-delimited lists are now accepted, and (b) **only the exact three-character `***` token is accepted as a wildcard** (single/double/quad stars are rejected). Hostile/malformed inputs (spaces, embedded quotes, `<script>`, leading/trailing `;`) are still rejected at the parameter binder before any Azure call is made.
- **New private helper `ConvertTo-AzLocalUpdateRingKqlFilter`** centralises the KQL clause construction for the three input forms above. Returns `| where isnotempty(tags['UpdateRing'])` for `***` (matches only tagged clusters), a `| where tags['UpdateRing'] =~ 'single'` clause for a single value, and a `| where tags['UpdateRing'] in~ ('a','b')` clause for a list. Embedded single quotes are doubled (KQL string-literal escape). All 12 ARG-query call sites in the public cmdlets now go through this helper.
- **Pester regression coverage** for every v0.7.66 feature: a `Describe 'v0.7.66 UpdateRing ValidatePattern accepts list & wildcard forms'` that reflects on every cmdlet's `ValidatePatternAttribute` and asserts both the acceptance set (`Wave1`, `Prod;Ring2`, `***`, ...) **and the rejection set including the easy-to-mistype `*` / `**` / `****` / `*Wave1` variants**, plus the existing hostile inputs (`Foo bar`, `abc'def`, `<script>`, empty, leading/trailing `;`); a `Describe 'v0.7.66 ConvertTo-AzLocalUpdateRingKqlFilter helper'` exercising every branch including the new `***` -> `isnotempty(...)` path (both default `tags['UpdateRing']` and `tostring(tags['UpdateRing'])` accessors); a `Describe 'v0.7.66 Artifact download names carry a UTC timestamp suffix'` that scans every `Automation-Pipeline-Examples/**/*.yml` and fails if any upload step is missing the `azlocal-` prefix or the `<timestamp>` token (plus four guards against the legacy non-stamped names regressing); a `Describe 'v0.7.66 Fleet Update Status summary uses status emojis and groups failures first'` that asserts the U+2705 and U+274C glyphs are present and that the legacy `[ok]/[fail]` markers are gone, that the `_(generated $generatedUtc)_` heading is present, and that the `$failedClusters` / `$passedClusters` / `$orderedClusters` bucketing tokens all appear; and a `Describe 'v0.7.66 Pipeline update_ring inputs document multi-value and wildcard support'` that asserts every input description mentions both `Prod;Ring2` and `'***'`.

#### v0.7.66 Pipeline migration

If you have copied any of the bundled workflows into your repo, refresh them via:

```powershell
Copy-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub      -Update
Copy-AzLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps -Update
```

### What's New in v0.7.65

- **New - `Get-AzLocalFleetHealthFailures` cmdlet.** Surfaces the in-flight **24-hour system health-check failures** across every Azure Local cluster the caller can read, via a single Azure Resource Graph query. The 24-hour health checks run on Azure Local clusters **independently of update activity** - which means clusters that are already "up to date" can still surface Critical or Warning issues that need triage. This cmdlet (and the new pipeline below) are the dedicated entry point for that workflow. Two views: `-View Detail` (one row per (cluster, failing check)) and `-View Summary` (aggregated by `FailureReason` + `Severity`, ordered "most widespread first" so administrators can target the highest-impact fixes). `-Severity Critical|Warning|All` filters at the ARG side; Informational entries are always excluded. `-UpdateRingTag` narrows to a specific wave. The function reuses the existing `Invoke-AzResourceGraphQuery` helper for paginated CLI shell-out, so it inherits the same skip-token / error-scrubbing behaviour as every other fleet-wide query in the module.

- **New - "Fleet Health Status" CI/CD pipeline samples** in `Automation-Pipeline-Examples/github-actions/Step.7_fleet-health-status.yml` and `Automation-Pipeline-Examples/azure-devops/Step.7_fleet-health-status.yml`. Daily 07:00 UTC schedule (offset from `fleet-update-status` at 06:00). Each run produces:
  - **Pipeline run summary**: pivoted by `FailureReason` (top failures by cluster impact), with a per-cluster "Detailed Results" table mirroring the standard "24-Hour System Health Checks - Detailed Results" view.
  - **JUnit XML**: one `<testcase>` per (cluster, failing health check), grouped under `Critical Health Failures` / `Warning Health Failures` testsuites for two-level drill-down in dorny/test-reporter (GitHub) and PublishTestResults@2 (Azure DevOps). dorny is configured `list-suites: failed` + `list-tests: failed` so the Test Reporter block is collapsed by default and only expands the failures.
  - **CSV exports**: `fleet-health-detail.csv` (per-cluster, per-failure) and `fleet-health-summary.csv` (one row per failure reason, ordered by cluster impact). Both are uploaded as build artifacts and are ready-made payloads for ITSM hand-off.
  Together with `Step.6_fleet-update-status.yml`, administrators now have **two dedicated pipelines**: one for "is each cluster up-to-date?" (Update Status) and one for "do clusters have actionable health issues even when up-to-date?" (Health Status).

- **New - Pester guardrail prevents pipeline-YAML version drift.** A new Pester `Context 'Pipeline YAML version pin (v0.7.65)'` test discovers every `*.yml` file under `Automation-Pipeline-Examples/` that installs the module from PSGallery and asserts that the `GENERATED_AGAINST_MODULE_VERSION` constant in that YAML matches the module manifest version. Supports both the inline GitHub Actions shape and the two-line Azure DevOps shape. The test fails the build if any sample YAML is forgotten when the manifest is bumped.

- **Fixed - `Set-AzLocalClusterUpdateRingTag` now uses the dedicated `Microsoft.Resources/tags/default` PATCH endpoint instead of `PATCH`-ing the cluster resource.** The previous code issued `PATCH https://management.azure.com/<clusterId>?api-version=2025-10-01` with `{ "tags": {...} }`, which Azure RBAC routes through the `microsoft.azurestackhci/clusters/write` action - i.e. full cluster Contributor. CI/CD service principals scoped to **Tag Contributor** (only `Microsoft.Resources/tags/*` actions) therefore failed with `AuthorizationFailed: action 'microsoft.azurestackhci/clusters/write'` even though they should have been able to write tags. The function now `PATCH`es `https://management.azure.com/<clusterId>/providers/Microsoft.Resources/tags/default?api-version=2021-04-01` with `{ "operation": "Merge", "properties": { "tags": { "UpdateRing": "..." } } }`, which Azure routes through `Microsoft.Resources/tags/write` only. The "Merge" operation preserves all other existing tags on the cluster without us having to re-send them. **Action**: if you scoped your tag-management SP to "Contributor" purely to work around the old behaviour, you can now safely scope it to the built-in **Tag Contributor** role on the cluster (or the resource group).

- **Fixed - "Fleet Update Status" pipeline summary now reconciles with the JUnit pass/fail counts.** Two related bugs were producing summary tables that did not add up to **Total Clusters**:
  1. `Up to Date` only counted `UpdateState -eq "UpToDate"` and missed clusters reporting the (equally healthy) `AppliedSuccessfully` state. Both states now count as "Up to Date".
  2. The bucket counters were not mutually exclusive and there was no catch-all, so a fleet of 20 healthy + 8 failed clusters could render as `Up to Date: 0`, `Health Failures: 8`, with the remaining 12 unaccounted for. Each cluster is now assigned to **exactly one** primary status using a priority cascade (`Update Failed` -> `Health Failure` -> `SBE Prerequisite Blocked` -> `Update In Progress` -> `Ready for Update` -> `Up to Date` -> `Needs Investigation`), so the rows always sum to `Total Clusters`.

- **Changed - JUnit / step-summary ordering is now: Summary FIRST, Test Results SECOND** in both `Step.6_fleet-update-status.yml` and `Step.7_fleet-health-status.yml` (GitHub + Azure DevOps). The markdown step summary is created before the JUnit XML is published, so the run-extensions / job-summary view leads with the operator-facing numbers rather than the raw test list.

- **Changed - "Fleet Update Status" failure message now reads `UpdateState: ..., Health: ...`** (was `Health: ..., UpdateState: ...`) so the Update Status leads in both the JUnit `<failure>` message and the markdown summary. The Update Status is the primary signal for that pipeline.

- **Documentation - `Set-AzLocalClusterUpdateRingTag` help and the Automation-Pipeline-Examples RBAC guidance now both recommend the built-in `Tag Contributor` role for tag-management automation.**

- **New - `Test-AzLocalApplyUpdatesScheduleCoverage` cmdlet + matching CI/CD pipeline samples.** Read-only schedule-coverage advisor that compares the cron schedule(s) in your `Step.5_apply-updates.yml` pipeline to the `UpdateWindow` tag values present on your clusters and flags any `(UpdateRing, UpdateWindow)` pair that no cron will ever reach. Three views: `-View Audit` (one row per `(Ring, Window)` pair with `Covered` / `Uncovered` / `PartiallyCovered` / `MalformedTag` / `UnparseableCron` plus a `Recommendation` column), `-View Matrix` (every distinct `(Ring, Window)` pair with the cron expression the advisor would generate for it), `-View Recommend` (ready-to-paste GH Actions and Azure DevOps cron blocks that cover every distinct `UpdateWindow` in the fleet). Per-segment cron generation handles multi-window tag values (`Sat-Sun_02:00-06:00;Mon-Fri_22:00-04:00`), day ranges (`Fri-Mon`), and configurable lead-time via `-LeadTimeMinutes` (default 5, 0-60). Pipeline samples ship at `Automation-Pipeline-Examples/github-actions/Step.3_apply-updates-schedule-audit.yml` and `Automation-Pipeline-Examples/azure-devops/Step.3_apply-updates-schedule-audit.yml`, scheduled weekly Mondays at 05:00 UTC (before the daily fleet pipelines) so drift annotations land at the top of the Monday-morning operator queue. Each run produces a JUnit XML (one `<testcase>` per `(Ring, Window)` pair), three CSV/MD exports (`schedule-coverage-audit.csv`, `schedule-coverage-matrix.csv`, `schedule-coverage-recommend.md`), and a markdown step summary. Full end-to-end runbook (tag a ring -> see drift -> copy recommended cron -> verify) in [`Automation-Pipeline-Examples/README.md` section 8.3](Automation-Pipeline-Examples/README.md#83-end-to-end-runbook-apply-updates-schedule-coverage-audit).

- **Module version pin bumped to 0.7.65 in all 13 sample workflow YAMLs** (11 pre-existing + the two new `Step.3_apply-updates-schedule-audit.yml` files). Run `Copy-AzLocalPipelineExample -Update` after upgrading to refresh the samples in your repo.

### What's New in v0.7.64

- **Fixed (critical) - pipeline-sample YAMLs (10 files across GitHub Actions and Azure DevOps) had accumulated cp1252 mojibake from previous emoji-edit round-trips.** One of the multi-byte sequences in `Step.2_manage-updatering-tags.yml` contained a YAML 1.2 forbidden C1 control character (U+008F), which caused GitHub Actions to reject the workflow at recent commits with `Invalid workflow file` / generic YAML syntax error and the affected step never ran. The root cause was UTF-8 emoji bytes (e.g. `F0 9F 93 84` = `[document]`) being misread as cp1252 by a previous editor session, then re-saved as UTF-8 - producing `C3 B0 C2 9F C2 93 C2 84`, which contains `C2 8F` -> U+008F. YAML 1.2 disallows raw C1 control characters U+0080-U+009F (except U+0085 NEL) in scalar content. **All non-ASCII bytes have been stripped from every sample workflow** (`[^\x09\x0A\x0D\x20-\x7E]`), the affected Markdown step-summary sections restored with plain-ASCII status labels (`[info]`, `[ok]`, `[running]`, `[ready]`, `[blocked]`, `[fail]`), and the YAMLs verified to round-trip cleanly through the GitHub Actions and Azure DevOps validators. No module code paths are affected; only the sample YAMLs.

- **Security hardening (Medium) - `Connect-AzLocalServicePrincipal` and six additional direct `az rest` callers now scrub raw CLI output through `ConvertTo-ScrubbedCliOutput` before logging or throwing.** A stray `refresh_token` / `access_token` / cookie that the `az` CLI might emit on a failure can no longer reach the host logs verbatim. Sites: `Set-AzLocalClusterTagsMerge` (3 throw paths), `Invoke-AzLocalSideloadedAutoResetForCluster`, `Invoke-AzLocalUpdateApply` (verbose), `Set-AzLocalClusterUpdateRingTag` (failure path), `Start-AzLocalClusterUpdate` (subscription-set and validate paths), and `Connect-AzLocalServicePrincipal`. This closes the same Bearer-token leak class that was already handled inside `Invoke-AzRestJson` / `Invoke-AzResourceGraphQuery` but missed by the seven sites that call `az rest` / `az account set` directly.

- **Documentation: `README.md` and [`ITSM/README.md`](ITSM/README.md) now carry explicit security notes about** (a) the `az login --service-principal --password <secret>` command-line exposure on the SP+secret authentication path (visible to `Win32_Process.CommandLine` and EDR for the duration of the call - prefer OIDC or Managed Identity), and (b) the unavoidable plaintext `[string]` residency of ITSM secrets in memory during ServiceNow OAuth `client_credentials` grants (the ServiceNow REST surface requires plaintext POST bodies, so `[SecureString]` round-tripping is impossible at this layer; mitigations baked in: scrubbing, URI redaction, finally-block temp-file cleanup).

- **Fixed (Low) - `Invoke-AzLocalUpdateApply` `$result -match "202"` was running against the `string[]` returned by `az rest`** which is array-filter semantics, not regex-match. The comparison is now done against `($result | Out-String).Trim()` against the single regex `'202|Accepted'`; `Write-Verbose` path also scrubbed.

- **Fixed (Low) - `Invoke-AzLocalItsmHttp` `throw` on non-retryable HTTP failure now uses `$redactedUri` instead of `$Uri`.** The redaction (`(client_secret|access_token|password)=[^&]+` -> `$1=***`) was already applied to the `Write-Verbose` log line; the `throw` message bypassed it.

- **Fixed (Low) - two Pester tests (`ScheduleBlocked` and `SideloadedBlocked` JUnit XML coverage) wrote to fixed temp filenames** that would collide if the test suite is run in parallel or back-to-back. Filenames now append a per-invocation `[Guid]::NewGuid()`.

- **Module version pin bumped to 0.7.64 in all 10 sample workflow YAMLs.** Run `Copy-AzLocalPipelineExample -Update` after upgrading to refresh the samples in your repo.

### What's New in v0.7.62

- **Fixed (critical) - `Start-AzLocalClusterUpdate` Step 3b critical-health gate was being silently bypassed.** The caller invoked [`Test-AzLocalClusterHealth`](Public/Test-AzLocalClusterHealth.ps1) without `-PassThru`; the function logs to the host stream and returns `$null` without `-PassThru`, so the predicate `$healthResults[0].CriticalCount -gt 0` always evaluated false even when the function had just logged `BLOCKED (N critical)`. Apply would then write *"No critical health issues found - cluster is eligible for update"* and proceed to PATCH the update despite critical health failures. Two more call sites in [`Get-AzLocalUpdateRuns`](Public/Get-AzLocalUpdateRuns.ps1) had the same omission. All three fixed.

- **Fixed (critical) - Tag writes now use the ARM tags subresource (`Tag Contributor` RBAC, not `clusters/write`).** [`Set-AzLocalClusterTagsMerge`](Private/Set-AzLocalClusterTagsMerge.ps1) - used by `Start-AzLocalClusterUpdate` to stamp `UpdateVersionInProgress`, by `Reset-AzLocalSideloadedTag`, and by the sideloaded auto-reset path - now `PATCH`es `.../providers/Microsoft.Resources/tags/default?api-version=2021-04-01` instead of the full cluster resource. This narrows the required RBAC from `microsoft.azurestackhci/clusters/write` to `Microsoft.Resources/tags/write` (built-in **Tag Contributor**). Up to 2 PATCHes per call: one `operation=Merge` for keys being set, one `operation=Delete` for keys whose input value is `$null`. Idempotent: skips keys whose value already matches.

- **Fixed (critical) - JUnit XML `Status` mapping no longer reports skipped clusters as passed.** `Export-ResultsToJUnitXml` previously rendered `NotReady`, `NotConnected`, `NoUpdatesAvailable`, and `NoReadyUpdates` as `<system-out>` (passed in `dorny/test-reporter`), producing misleading *all green* CI summaries when apply had actually skipped clusters. They now render as `<skipped>`. `UpdateNotFound` now renders as `<error type="UpdateNotFound">` instead of `<system-out>`.

- **Changed - `apply-updates` pipeline samples now consume the readiness CSV.** Both [`Automation-Pipeline-Examples/github-actions/Step.5_apply-updates.yml`](Automation-Pipeline-Examples/github-actions/Step.5_apply-updates.yml) and [`Automation-Pipeline-Examples/azure-devops/Step.5_apply-updates.yml`](Automation-Pipeline-Examples/azure-devops/Step.5_apply-updates.yml) now download the `readiness-report` artifact from the `check-readiness` job, filter rows where `ReadyForUpdate=True`, and pass `-ClusterResourceIds @(...)` to `Start-AzLocalClusterUpdate` instead of re-discovering clusters by `UpdateRing` tag. This guarantees the readiness gate's decision is **enforced** rather than advisory: a cluster flagged Blocked in readiness will not be touched by apply even if its tag still matches the ring. Apply still re-validates each cluster (Step 1b connectivity, Step 3b health, Step 3c schedule, Step 3b1 sideloaded) as defence in depth.

- **Changed - Readiness output gains a `ClusterResourceId` column.** [`Get-AzLocalClusterUpdateReadiness`](Public/Get-AzLocalClusterUpdateReadiness.ps1) emits the full ARM resource ID on every row (including `NotFound`/`Error` rows) so the apply step can pass it straight to `Start-AzLocalClusterUpdate -ClusterResourceIds` without a second Resource Graph query. **The CSV column is additive** - existing consumers that parse by header name keep working.

- **Module version pin bumped to 0.7.62 in all 10 sample workflow YAMLs.** Run `Copy-AzLocalPipelineExample -Update` after upgrading.

**What a successful `Step.5_apply-updates.yml` run looks like** (dry-run against the Prod ring on a 9-cluster sandbox - 4 ready, 5 skipped, zero failures):

![Step.5_apply-updates.yml run Summary tab: target UpdateRing Prod, dry-run, Readiness section showing Total Clusters 9 / Ready for Update 4, Results section showing Updates Started 0 / Skipped 5 / Failed 0 / Health Blocked 0 / Schedule Blocked 0 / Sideloaded Blocked 0](docs/images/apply-updates-summary.png)

### What's New in v0.7.63

- **Fixed (critical) - `Step.6_fleet-update-status.yml` pipeline samples failed with `ParserError` under PowerShell 7.** Inside the PS double-quoted here-string that builds the Markdown step summary, Markdown code-span backticks before file names like `` `update-summaries.csv` `` were interpreted by the PS 7 parser as the new `` `u{xxxx} `` Unicode escape (which expects `{` immediately after `` `u ``). PS 5.1 had silently consumed the backtick; PS 7 hard-errors. Latent corruption also affected `` `readiness-status.csv` `` (`` `r `` -> CR), `` `available-updates.csv` `` (`` `a `` -> BEL), and `` `cluster-inventory.csv` `` (`` `c `` -> backtick dropped) - producing rendered job summaries with stray control characters and missing code-span formatting even on PS 5.1. All Markdown code-span backticks in the affected here-strings have been doubled; under both PS 5.1 and PS 7 two consecutive backticks in a double-quoted string produce exactly one literal backtick. No module code paths affected; only the pipeline-sample YAMLs.

- **Module version pin bumped to 0.7.63 in all 10 sample workflow YAMLs.**

### What's New in v0.7.61

- **Readiness now blocks `ReadyForUpdate` when the cluster is not reachable or has Critical-severity health checks.** Both [`Get-AzLocalClusterUpdateReadiness`](Public/Get-AzLocalClusterUpdateReadiness.ps1) and [`Get-AzLocalFleetStatusData`](Public/Get-AzLocalFleetStatusData.ps1) (driving the fleet HTML report) downgrade `ReadyForUpdate` to `False` and record the reason on a new **`BlockingReasons`** CSV column whenever either of these is true:
  - **Connectivity gate** - `ClusterState` is not `'ConnectedRecently'` (e.g. `NotConnectedRecently`, `Disconnected`). ARM cannot reliably push an update to a cluster that has missed its heartbeat.
  - **Critical health gate** - `HealthCheckFailures` contains at least one `[Critical]` severity entry. These must be cleared before any solution upgrade is started.

  Values on `BlockingReasons` are semicolon-joined (e.g. `CriticalHealthCheck`, `CriticalHealthCheck; NotConnectedRecently`). The per-cluster console output now shows `Blocked (<reasons>)` in red, and the summary footer reports `Blocked by Readiness Gate: N` alongside the existing `Blocked by SBE Prereq` count. **The CSV column is additive** - existing consumers that parse by header name keep working.

- **`Start-AzLocalClusterUpdate` defence-in-depth: new `Step 1b` connectivity gate.** Immediately after cluster lookup, any cluster whose `properties.status` is not `'ConnectedRecently'` is skipped before any update is attempted. A row is recorded in `Update_Skipped.csv` with the message *"Update not started - cluster status is '<status>' (ARM cannot reach the cluster)"*, and the in-process `$results` list gets a `Status='NotConnected'` row. Complements the existing `Step 3b` critical-health gate. No new flags - the gate is always on.

- **Fixed - JUnit XML `Status` column from `Get-AzLocalClusterUpdateReadiness` was always `Skipped`** for Ready clusters (long-standing bool/string comparison bug `$_.ReadyForUpdate -eq 'Yes'` against `[bool]$true`). JUnit `Status` now correctly emits `Ready`, `Blocked`, `Failed`, or `Skipped`. The CSV `ReadyForUpdate` column (a real `[bool]`) was unaffected; only JUnit XML readability in CI/CD test summaries was wrong.

- **Module version pin bumped to 0.7.61 in all 10 sample workflow YAMLs.** Run `Copy-AzLocalPipelineExample -Update` after upgrading.

### What's New in v0.7.60

- **GitHub Actions sample workflows refreshed for Node 24.** All five workflow YAMLs under [`Automation-Pipeline-Examples/github-actions/`](Automation-Pipeline-Examples/github-actions/) now pin Node 24-compatible major versions of the third-party actions they use. This removes the *"Node.js 20 actions are deprecated"* warning banner that GitHub Actions started surfacing ahead of the **Sept 16 2026 Node.js 20 hard-removal**. No input/output surface changes for any of the bumped actions - refreshed pipelines work without any other edits:
  - `actions/checkout`        `@v4` -> `@v5`  (Node 24 default since v5.0.0)
  - `actions/upload-artifact` `@v4` -> `@v6`  (v6 = Node 24 default; v5 still defaulted to Node 20)
  - `azure/login`             `@v2` -> `@v3`  (v3.0.0 = Node 24)
  - `dorny/test-reporter`     `@v1` -> `@v3`  (v3 = Node 24)

  Already-deployed pipelines continue working on the older majors until Sept 16 2026. To pull the refreshed YAMLs into your existing `.github\workflows\` folder after upgrading the module, run `Copy-AzLocalPipelineExample -Update -Platform GitHub -Destination .\.github\workflows`.

- **Fixed - `dorny/test-reporter` 403 on `Step.5_apply-updates.yml` (GitHub Actions sample).** Both jobs (`check-readiness` and `apply-updates`) only granted `id-token: write` + `contents: read` in their `permissions:` block, missing the `checks: write` permission that `dorny/test-reporter` needs to create the Check Run that publishes JUnit results. Symptom: the test-reporter step failed with `HttpError: Resource not accessible by integration` (HTTP 403) on every `workflow_dispatch` run, because `workflow_dispatch` contexts have no PR check-run context to write back to by default. The run itself was unaffected - readiness assessment and the subsequent apply still completed - this only restored the Check Run summary surface so the JUnit XML actually shows up in the GitHub UI. Sibling workflows (`Step.4_assess-update-readiness.yml`, `Step.6_fleet-update-status.yml`) already declared `checks: write` from v0.7.50; only `Step.5_apply-updates.yml` was missing it.

- **Module version pin bumped to 0.7.60 in all 10 sample workflow YAMLs.** `GENERATED_AGAINST_MODULE_VERSION` is the value the in-pipeline install step compares the actually-installed module version against, then warns if your local copy of the YAML is stale (see [Automation-Pipeline-Examples/README.md section 5.3](Automation-Pipeline-Examples/README.md#53-version-pinning--staleness-warnings)). All five GitHub Actions YAMLs and all five Azure DevOps YAMLs have been bumped in lock-step.

### What's New in v0.7.50

- **`Copy-AzLocalItsmSample` (new convenience function)**: copies the bundled ITSM connector sample (`azurelocal-itsm.yml` + `templates/incident-body.md`) out of the module install location into a user-chosen destination. Default `-Destination` is `.\.itsm` - the exact relative path that both `Step.5_apply-updates.yml` workflows default `itsm_config_path` / `itsmConfigPath` to (resolved relative to the repo root at job runtime). Same overwrite semantics as `Copy-AzLocalPipelineExample`: refuses by default, `-Update` opts into per-file `ShouldContinue` prompts (with `Yes-to-All` / `No-to-All` that survive across iterations), `-Confirm:$false` bypasses the prompts for unattended use, `-WhatIf` previews without changing anything, `-PassThru` returns the destination `[DirectoryInfo]`. Closes the gap where running `Copy-AzLocalPipelineExample -Platform GitHub` (or `-Platform AzureDevOps`) deliberately did not bring the `.itsm/` sample along - the two functions now compose for a one-paragraph setup. The ITSM YAML itself is CI-platform-agnostic; both GitHub Actions and Azure DevOps consume it identically, only the secret source differs (repo / environment secrets vs. variable group).
- **`Copy-AzLocalPipelineExample` - simpler, safer copy semantics.** First real-world run of the v0.7.4 surface exposed two issues with the GitHub Actions path: (1) `-Platform GitHub -Flatten` left an intermediate `github-actions\` subfolder, so workflows landed at `.github\workflows\github-actions\*.yml` where the GitHub Actions runner cannot see them (the runner only scans `.github/workflows/*.yml`, non-recursively); (2) the `-Force` flag's directory-level pre-flight refused to copy whenever `.github\workflows\` contained any unrelated user workflow, making `-Force` effectively mandatory and meaningless. Both flags have been removed and the function has been reshaped around the user's actual intent:
  - `-Platform GitHub` now copies ONLY the `*.yml` workflow files from the source `github-actions/` folder directly into `-Destination` (flat - no wrapper folder, no README, no `.itsm/`). Canonical call: `Copy-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub`.
  - `-Platform AzureDevOps` behaves the same way against the source `azure-devops/` folder.
  - `-Platform All` (the default) is unchanged - copies the full source tree under a `.\Automation-Pipeline-Examples\` child folder for browsing.
  - **Controlled refresh via `-Update`** (new in v0.7.50): the function still refuses to overwrite by default and lists every conflict in the error message - but the error now points at the `-Update` switch instead of asking the user to `Remove-Item` first. With `-Update` the function emits a per-file `ShouldContinue` prompt (`Y` / `A` / `N` / `L` / `S` / `?`) before each overwrite. Pair with `-Confirm:$false` to suppress the prompts entirely (the documented automation / CI bypass), or use `-WhatIf` to preview without changing anything. Pipeline files are expected to live under git source control so `git diff` is the second safety net after `ShouldContinue`. There is **deliberately no `-Force`**: `-Update` is the narrower, more explicit replacement.
  - Pre-existing unrelated files in `-Destination` (e.g. your repo's own `build.yml`, `codeql.yml`) are now left untouched; the function only writes the files it is bringing over from the source tree.
  - **Next-steps output** is now platform-aware and detects when `-Destination` is already `.github\workflows\` ("you're done, commit and push") vs. somewhere else ("move the YAMLs into `.github\workflows\`"). For both platform-specific values the output points at `Step.0_authentication-test.yml` as the recommended first run (see sections 5.1 and 5.2 of the [Automation-Pipeline-Examples README](Automation-Pipeline-Examples/README.md)) so the user validates the auth chain before wiring the other five workflows.
  - Note: this is **not** marked as a breaking change because the v0.7.4 surface had not been adopted by any consumer at the time of removal (the feature shipped on 2026-05-13 and was found broken on first real-world use).

### What's New in v0.7.41

- **Hotfix - parallel fleet reads broken by the v0.7.3 NestedModules refactor**: v0.7.41 fixes two related regressions that surfaced on the PSGallery-installed v0.7.4 build whenever **`-ThrottleLimit > 1`** was used.
  - **Bug 1**: every fleet read dispatched through `Invoke-FleetJobsInParallel` (`Get-AzLocalUpdateRuns`, `Get-AzLocalUpdateSummary`, `Get-AzLocalClusterUpdateReadiness`, `Get-AzLocalAvailableUpdates`, `Get-AzLocalFleetProgress`, `Invoke-AzLocalFleetOperation`, `Test-AzLocalClusterHealth`, and `Start-AzLocalClusterUpdate`'s parallel path) returned `State = Error` for every cluster with the message *"Cannot use '&' to invoke in the context of module 'Invoke-FleetJobsInParallel' because it is not imported."* Inline (`-ThrottleLimit 1`) execution was unaffected. Root cause: the v0.7.3 refactor that split the monolithic `.psm1` into `NestedModules` changed the meaning of `$PSCommandPath` inside `Invoke-FleetJobsInParallel.ps1` - it now resolves to that helper's own `.ps1`, **not** to the root `AzLocal.UpdateManagement.psd1`. Each per-batch `Start-Job` scriptblock then imported only that single `.ps1` in the child runspace as a transient module, so subsequent `& $module { Get-AzLocalClusterUpdateRuns ... }` calls resolved against a session state that contained none of the private helpers.
  - **Bug 2**: `New-AzLocalFleetStatusHtmlReport -ThrottleLimit > 1` (via `Get-AzLocalFleetStatusData`) threw at start-up: *"Parallel collection requires module path '...\\Public\\AzLocal.UpdateManagement.psm1' to be reachable by background jobs, but it does not exist."* Same class of regression but a separate code path: `Get-AzLocalFleetStatusData` computed its own module path using `Join-Path $PSScriptRoot 'AzLocal.UpdateManagement.psm1'`, which under the post-v0.7.3 layout resolves to the `Public/` subfolder - one level too deep. `New-AzLocalFleetStatusHtmlReport`'s footer manifest-fallback had the same flaw.
- **Centralised module-root resolution**: introduced a new private helper [`Get-AzLocalModuleRootManifestPath`](Private/Get-AzLocalModuleRootManifestPath.ps1) used by all three sites. It prefers the loaded module's `.Path` (`.psd1` over `.psm1`) and falls back to walking up from the caller's `$PSCommandPath`, so it returns the correct root manifest path from any file under `Public/` or `Private/`. Future helpers won't reintroduce the same "`$PSScriptRoot` is module root" assumption.
- **Regression coverage**: existing parallelisation tests only exercised the inline `-ThrottleLimit 1` fast-path, which reuses the parent runspace and so could not reproduce either bug. v0.7.41 adds Pester tests that (a) assert `Invoke-FleetJobsInParallel` passes the **root manifest path** (`.psd1`/`.psm1`) as the trailing `ModulePath` argument and **not** the helper's own `.ps1`, and (b) directly exercise `Get-AzLocalModuleRootManifestPath` with synthetic caller paths under `Public/` and `Private/`. Full suite: **354/354 green**.

### What's New in v0.7.4

- **ITSM Connector - Phase 1 (ServiceNow)**: new opt-in capability for opening ServiceNow incidents directly from update / fleet pipeline output. Three new exported functions - `New-AzLocalIncident`, `Get-AzLocalItsmConfig`, `Test-AzLocalItsmConnection` - plus supporting private helpers (`Resolve-AzLocalItsmSecret`, `Get-AzLocalItsmDedupeKey`, `Get-AzLocalItsmTriggerDecision`, `Format-AzLocalIncidentBody`, `Invoke-AzLocalItsmHttp`, `Invoke-AzLocalServiceNowAdapter`). `New-AzLocalIncident` reads a JUnit results artifact (and an optional readiness CSV), applies the trigger matrix from the user's [`azurelocal-itsm.yml`](Automation-Pipeline-Examples/.itsm/azurelocal-itsm.yml) config, computes a deterministic SHA256 dedupe key per `{ClusterResourceId, UpdateName, TriggerCategory}` tuple, queries ServiceNow for an existing open ticket (`u_azlocal_dedupe_key`, `stateIN1,2,3`), and either creates a new incident or returns the existing ticket - so re-running the same pipeline is idempotent. Auth is OAuth 2.0 `client_credentials` only in Phase 1; secrets resolve from Azure Key Vault (`kv://<vault>/<secret>`), environment variables (`env://NAME`), or explicit literals (`literal://...` with `-AllowLiteral`). HTTP path is TLS 1.2+, default 30s timeout, exponential backoff on 429/5xx, `Retry-After` honoured. The CSV export from `-ExportPath` is sanitised by `ConvertTo-SafeCsvCollection`, neutralising the same formula-injection class already handled elsewhere in the module. `Test-AzLocalItsmConnection` validates the config, resolves secrets, performs the OAuth token grant, and probes a one-row read against `/api/now/table/incident` (matching the least-privilege scope used by ticket creation). Full documentation under [`ITSM/`](ITSM/): [README](ITSM/README.md), [ITSM-Connector-Plan.md](ITSM/ITSM-Connector-Plan.md), [ITSM-Config-Reference.md](ITSM/ITSM-Config-Reference.md). A ready-to-copy sample config plus the Mustache ticket-body template live under [`Automation-Pipeline-Examples/.itsm/`](Automation-Pipeline-Examples/.itsm/). 33 new ITSM Pester tests; full suite green at 337/337.
- **Phase 2 and Phase 3 are not in this release.** Phase 2 (`Sync-AzLocalIncident` - close-out / work-note sweep when the underlying cluster recovers) and Phase 3 (Microsoft Teams + Slack mirror adapters) are designed in [`ITSM/ITSM-Connector-Plan.md`](ITSM/ITSM-Connector-Plan.md) and tracked for a later release. The `lifecycle` and `notifications` config sections are parsed and stored in Phase 1 but not yet acted on. A small set of Phase 1.5 follow-ups is also tracked: cmdbCi token expansion, custom-field presence check, rate-limit-headroom probe, in-module token caching, `Invoke-AzLocalItsmHttp -AllowedThumbprints` cert pinning, and `raiseAfterConsecutiveOccurrences` enforcement (requires the run-history store).
- **Code hygiene**: removed the unused username/password OAuth grant path from the ServiceNow adapter (Phase 1 is `client_credentials` only) - silences the PSScriptAnalyzer `PSAvoidUsingUsernameAndPasswordParams` Error and `PSAvoidUsingPlainTextForPassword` Warning. Tightened the ITSM config validator so `secrets.source: mixed` now requires `secrets.keyvaultName`, matching the documented behaviour. Cleaned up legacy non-ASCII characters in [`Private/Format-AzLocalUpdateRun.ps1`](Private/Format-AzLocalUpdateRun.ps1) and [`Publish-Module.ps1`](Publish-Module.ps1) divider comments. Flattened `ITSM/Docs/` into [`ITSM/`](ITSM/) (removed the stale duplicate `ITSM/Docs/ITSM-Connector-Plan.md`).
- **`Copy-AzLocalPipelineExample` (convenience)**: new exported function that copies the bundled [`Automation-Pipeline-Examples/`](Automation-Pipeline-Examples/) folder out of the module install location into a destination folder you control (default: current directory). Supports `-Platform GitHub | AzureDevOps | All`, `-Flatten` (drop contents directly into the destination), `-Force` (overwrite), `-PassThru`, `-WhatIf` and `-Confirm`. After copying, prints a short "next steps" summary pointing at the README and the platform-specific destination paths so you don't have to hunt through `$module.ModuleBase` to find the YAML samples.

### What's New in v0.7.3

- **Module renamed** from `AzStackHci.ManageUpdates` to `AzLocal.UpdateManagement`. The module GUID is preserved across the rename so PowerShell tooling sees this as the same module identity. All previously-published `AzStackHci.ManageUpdates` versions have been unlisted from PSGallery; a transitional v0.7.3 stub is published once to point legacy automation at the new name. Migration: `Uninstall-Module AzStackHci.ManageUpdates -AllVersions; Install-Module AzLocal.UpdateManagement`. Default log folder default also moved from `C:\ProgramData\AzStackHci.ManageUpdates\` to `C:\ProgramData\AzLocal.UpdateManagement\`.
- **Internal refactor**: the monolithic 11,679-line `.psm1` has been split into Public/Private dot-sourced files matching the layout of `AzLocal.DeploymentAutomation`. 20 exported functions live under `Public/`, 40 internal helpers under `Private/`. The manifest's `NestedModules` list enumerates every file. No functional change; the full Pester suite (299 tests) remains green.

### What's New in v0.7.2

- **Bug fix - fleet read paths under `-ThrottleLimit > 1`**: `Get-AzLocalUpdateRuns`, `Get-AzLocalUpdateSummary`, and `Get-AzLocalClusterUpdateReadiness` previously failed for every cluster when invoked with `-ThrottleLimit` greater than 1, reporting `The term 'Get-AzLocalClusterUpdateRuns' is not recognized...` (or the equivalent for other private helpers). The per-cluster scriptblock dispatched via `Start-Job` called module-private helpers (`Invoke-AzRestJson`, `Get-AzLocalClusterUpdateRuns`, `Format-AzLocalUpdateRun`, `Get-LatestUpdateByYYMM`, `ConvertTo-AzLocalAdditionalProperties`, `Get-HealthCheckFailureSummary`, `Get-TagValue`) by name; because those helpers are filtered out by `Export-ModuleMember`, after `Import-Module` in the child runspace they were not visible at script command-resolution scope. Inline (`-ThrottleLimit 1`) execution was unaffected. Each affected scriptblock now captures a reference to the loaded module and either invokes the helper via `& $module { ... }` or rebinds the helper's bound scriptblock into the local function scope, so calls execute against the module's own session state and resolve all transitive private references. Reported against a 9-cluster Prod fleet.
- **Bug fix - cp1252 encoding warnings leaking into JSON parsing**: On Windows hosts where the console code page is `cp1252` (the English-US default), the Azure CLI (`az rest`, `az graph query`) emitted `WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.` whenever ARM responses contained non-cp1252 characters (smart quotes, accented characters in cluster tags, localised health-check messages, etc.). Captured via `2>&1`, that warning was prepended to the JSON body and broke `ConvertFrom-Json`, which silently dropped update runs and available updates for affected clusters. Earlier attempts to fix this via `$env:PYTHONIOENCODING = 'utf-8'` are structurally ineffective: `az.cmd` launches Python with the `-I` (isolated) flag, which implies `-E` and so causes Python to ignore all `PYTHON*` environment variables (including `PYTHONIOENCODING` and `PYTHONUTF8`) - confirmed in [Azure/azure-cli#28497](https://github.com/Azure/azure-cli/issues/28497). The actual fix is to pass `--only-show-errors` to every `az rest` and `az graph query` invocation (Azure CLI maintainer's recommended workaround per [Azure/azure-cli#14426](https://github.com/Azure/azure-cli/issues/14426)). This suppresses the encode warning at source so the captured stderr/stdout streams stay clean. Characters that fail to encode are still replaced silently inside the CLI, but for ARM cluster/update payloads (timestamps, GUIDs, status enums, resource IDs - all ASCII) this is a non-issue. Genuine errors (auth failures, 4xx/5xx ARM responses, invalid args) still surface normally.

### What's New in v0.7.1

- **Sideloaded payload workflow (new)**: opt-in two-tag protocol (`UpdateSideloaded` set by operator, `UpdateVersionInProgress` set by module) for staging out-of-band update payloads. `Start-AzLocalClusterUpdate` blocks with `Status = SideloadedBlocked` while the payload is being staged. `Get-AzLocalUpdateRuns` auto-resets the tags once the matching run succeeds. New public function [`Reset-AzLocalSideloadedTag`](#reset-azlocalsideloadedtag) for explicit / `-Force` recovery. See [section 7a](#7a-sideloaded-payload-workflow-v071) for the full flow. **No new RBAC required** - rides on the existing `Microsoft.Resources/tags/read|write` permissions.
- **EndTime column for update runs**: new `EndTime` column on `Get-AzLocalUpdateRuns` table output, sourced from `properties.progress.endTimeUtc` (most accurate "work finished" timestamp), falling back to `properties.lastUpdatedTime`. Blank for `InProgress` runs. Per-run `Duration` now prefers ARM-reported `properties.duration` (ISO-8601 timespan) over the computed `EndTime - StartTime` delta, so it is immune to clock skew. Fleet HTML report's "Recent Update Run History" gains an `End Time` column; JUnit XML test bodies include `Start Time:` / `End Time:` lines per testcase (the JUnit `time=` attribute is unchanged).
- **Idempotent tag merges**: `Set-AzLocalClusterTagsMerge` (private helper used by both `Set-AzLocalClusterUpdateRingTag` and the sideloaded workflow) now skips the PATCH when the merge produces no actual change against the cluster's current tags. Quieter logs and one less ARM write per no-op.
- **Enterprise-readiness review fixes**:
  - **Security**: `Write-UpdateCsvLog` (the diagnostic CSV path used during apply runs) now sanitises every field through `ConvertTo-SafeCsvField` before quote-escaping, closing the same Excel-formula-injection gap on the interim `Update_Skipped.csv` / `Update_Started.csv` logs that was already covered for the final exported results.
  - **Operational**: parallel `Get-AzLocalFleetStatusData` job dispatch now treats `Stopped` and `Disconnected` job states as failures alongside `Failed`. Previously these terminal states fell through into `Receive-Job` and were misdiagnosed as "no output", obscuring the real cause of `Stop-Job` / Ctrl-C / remoting-disconnect scenarios.
  - **Performance**: `Get-AzLocalUpdateSummary`, `Get-AzLocalClusterUpdateReadiness`, `Start-AzLocalClusterUpdate`, `Get-AzLocalUpdateRuns`, and the private `Get-AzLocalClusterUpdateRuns` helper now accumulate per-cluster results in a `[System.Collections.Generic.List[object]]` (O(1) amortised `.Add()`) instead of an `Object[]` with `+=` (O(n^2) total). Measurable speed-up at fleet scale (1000+ clusters); no API surface change - the functions still return arrays.

### What's New in v0.7.0

The jump from `0.6.5` to `0.7.0` is a large, fleet-scale release focused on correctness at 1500+ clusters, true parallel execution, HTML report performance, and a round of security hardening. No breaking public-surface changes.

#### Fixed - Correctness at scale
- **HIGH**: Azure Resource Graph queries were hardcoded to `az graph query --first 1000`. At 1500 clusters, 500 were silently dropped - no error, no warning. New private `Invoke-AzResourceGraphQuery` helper loops on the `$skipToken` until exhausted.
- **HIGH**: `Invoke-AzLocalFleetOperation -ThrottleLimit` previously only affected retry-backoff math; the per-cluster loop was fully sequential. At 1500 clusters that meant 4+ hour runs. Extracted the parallel `Start-Job` pattern into a shared private helper `Invoke-FleetJobsInParallel` and rerouted all fleet operations through it. `-ThrottleLimit` now controls concurrent API calls (default 4, range 1-16). PowerShell 5.1 compatibility preserved.
- **HIGH**: `Get-AzLocalClusterInventory` threw `The variable cannot be validated because the value '' is not a valid value for the UpdateRingValue variable.` whenever a cluster in the fleet was missing the `UpdateRing` tag. Root cause: the function's `[ValidatePattern]` parameter `$UpdateRingValue` collided with a loop-local `$updateRingValue` (PowerShell variable names are case-insensitive). Locals renamed to `$ringTagValue` / `$windowTagValue` / `$exclusionsTagValue`. `-AllClusters` reports now complete against real-world mixed-tag fleets.

#### Changed - Performance (parallel by default)
- These per-cluster functions now run in parallel batches via the shared helper: `Get-AzLocalClusterUpdateReadiness`, `Test-AzLocalClusterHealth`, `Get-AzLocalUpdateSummary`, `Get-AzLocalAvailableUpdates`, `Set-AzLocalClusterUpdateRingTag`, `Get-AzLocalUpdateRuns`. Expected 5-10x speedup on 1500-cluster runs (readiness check from ~10 min to ~1-2 min).
- `New-AzLocalFleetStatusHtmlReport` renderer rewritten for O(n) scaling: pre-indexed `LatestRuns` and `ClusterDetails` hashtables, HTML encoding moved to collection time, per-cluster portal URLs precomputed once. ~60% faster HTML render at 1500 clusters.
- HTML report output now written as UTF-8 **without BOM** via `[System.IO.File]::WriteAllText` + `UTF8Encoding($false)`.
- New opt-in pass-through parameters (`-UpdateSummary`, `-AvailableUpdates`) so pre-fetched data can be reused across a pipeline, avoiding redundant ARM reads.

#### Changed - `-AllClusters` cap removed
- `New-AzLocalFleetStatusHtmlReport -AllClusters` and `Get-AzLocalFleetStatusData -AllClusters` previously truncated at the first 100 clusters silently. **The default cap is removed - all discovered clusters are now included.** New `-MaxClusters <int>` parameter (default 0 = no cap, range 1-100000) lets callers optionally trim the slice for targeted runs or testing.

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
- `Stop-AzLocalFleetUpdate` and `New-AzLocalFleetStatusHtmlReport` now support `ShouldProcess` (`-WhatIf` / `-Confirm`).

#### Changed - Maintenance window tag format
- **Breaking for pre-release consumers only (no one was using this yet)**: the `UpdateWindow` Azure resource tag now uses `_` as the separator between the day-spec and the time range, instead of `:`. This removes the ambiguity with the `HH:MM` time portion and makes the tag easier to read at a glance.
  - Old: `Mon-Fri:22:00-02:00`
  - **New: `Mon-Fri_22:00-02:00`**
  - Multi-window separator (`;`) and day-range separator (`-`) are unchanged.
  - The parser in `ConvertFrom-AzLocalUpdateWindow` will throw `Invalid window segment syntax` for the old format; combined with the fail-closed schedule-tag evaluation above, any cluster still carrying the old tag value will have its updates blocked until re-tagged. Use `Set-AzLocalClusterUpdateRingTag -UpdateWindowValue 'Mon-Fri_22:00-02:00' -Force` to migrate.

#### Changed - Fleet HTML report Recent Update Run History
- Duration now uses `HH:MM:SS` fixed-width format (was `N.N hours` fractional). Easier to read, no loss of precision, survives multi-day runs (`52:15:30` for 52h 15m).
- **Attempts are now aggregated per update**: when an update runs multiple times on a cluster (a re-run after failure), the report shows **one row** with `Update Attempts = N` and `Duration = <sum of all attempts>` instead of showing just the last attempt's duration. `StartTime` reflects the earliest attempt; `State` / `Progress` / `Current Step` reflect the latest attempt.
- New **Update Attempts** column is shown **only** when at least one cluster has >1 attempt on its current update, keeping single-attempt fleets uncluttered.
- Only the most-recently-started update per cluster is displayed (one row per cluster); historical update versions from prior cycles are no longer duplicated into separate rows.

#### Changed - Cluster Information section (HTML report)
- New **Current SBE Version** column shows the solution-builder-extension version installed on each cluster, alongside the solution update version. Extracted from the `/updates` `additionalProperties.SBEVersion` of the most recent applied SBE update and surfaced through `Get-AzLocalFleetStatusData` and the GitHub Actions / Azure DevOps fleet-status pipelines.

#### Changed - `Start-AzLocalClusterUpdate`
- `-WhatIf` output is no longer polluted by the module's own `Write-Log` / `Write-UpdateCsvLog` side effects, internal `Env:` cleanup, or log-folder creation. Previously every internal housekeeping line produced a `What if:` row. Now only the actual ARM `POST` `apply/action` call appears in the WhatIf preview.
- `-WhatIf` runs (and `ShouldProcess`-declined runs) now count as **WouldUpdate** in the final summary and are surfaced distinctly from `Started` / `Skipped` / `Failed`. Makes dry-runs at fleet scale actually auditable.

#### Added - `Format-AzLocalDurationHuman` helper (private)
- Central helper for duration rendering; accepts `[TimeSpan]`, numeric seconds, or `HH:MM:SS` string. Emits `"1 hour 23 minutes"` style for the per-run `Get-AzLocalUpdateRuns` output. The fleet HTML report uses its own `HH:MM:SS` formatter because it sums across attempts (see above).

#### Notes
- No breaking changes to exported functions or parameter sets. All new helpers are private.
- Az CLI remains the ARM transport for v0.7.0; a native `Invoke-RestMethod` port is deferred.

### What's New in v0.6.5

#### Fixed
- **`Set-AzLocalClusterUpdateRingTag` now correctly applies `UpdateWindow` and `UpdateExclusions` tags from CSV** (HIGH). Inside the processing loop, four references used an undefined variable (`$cluster`) instead of the actual loop variable (`$clusterEntry`). Because `Set-StrictMode` is not enforced at module scope, the typo silently returned `$null`, so:
  - Clusters with an existing `UpdateRing` tag were skipped even when the CSV changed `UpdateWindow`/`UpdateExclusions`.
  - On new/forced writes the PATCH body only contained `UpdateRing`; `UpdateWindow`/`UpdateExclusions` columns from the CSV were never sent to Azure.
  - Round-trip `Get-AzLocalClusterInventory` -> edit CSV -> `Set-AzLocalClusterUpdateRingTag` now correctly preserves all three tag columns.

#### Added
- **New optional parameters `-UpdateWindowValue` and `-UpdateExclusionsValue` on `Set-AzLocalClusterUpdateRingTag -ClusterResourceIds`**. Direct-invocation mode is now symmetrical with CSV mode and can set all three tags (`UpdateRing`, `UpdateWindow`, `UpdateExclusions`) in a single PATCH operation:

  ```powershell
  Set-AzLocalClusterUpdateRingTag `
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
- **New function `Get-AzLocalFleetStatusData`**: Single-pass data collection with parallel `Start-Job` support
- `-ThrottleLimit` parameter (default: 4, max: 8) splits cluster list into parallel batches
- `-ExportPath` exports fleet data as JSON artifact for CI/CD pipeline job passing
- `-StatusData` parameter on `New-AzLocalFleetStatusHtmlReport` accepts pre-collected data to skip API calls
- Stable JSON schema (v1.0) with SchemaVersion, Timestamp, ModuleVersion, Scope, Readiness, ClusterDetails, LatestRuns, HealthResults

#### Update State Alignment
- All per-update state filters now use module-level constants (`$script:ReadyStates`, `$script:PrereqStates`) aligned with current ARM API states
- `ReadyToInstall` state is now recognized alongside `Ready` across all functions: `Start-AzLocalClusterUpdate`, `Get-AzLocalAvailableUpdates`, `Get-AzLocalClusterUpdateReadiness`, `Get-AzLocalFleetStatusData`, `Get-AzLocalUpdateSummary`
- Update summary state checks include `ReadyToInstall` for accurate "Update Available" counting

#### HasPrerequisite & SBE Dependency Awareness
- **`Get-AzLocalAvailableUpdates`**: Now shows HasPrerequisite/AdditionalContentRequired counts alongside Ready counts in console output (both single-cluster and multi-cluster modes)
- **`Get-AzLocalAvailableUpdates`**: Result objects include `PackageType` and `SBEDependency` properties for updates blocked by SBE prerequisites
- **`Get-AzLocalAvailableUpdates`**: Summary section shows clusters blocked by SBE prerequisites with vendor dependency details (Publisher, Family, ReleaseNotes)
- **`Get-AzLocalAvailableUpdates`**: New `-Raw` switch returns unprocessed ARM API objects for programmatic use (internal callers use this automatically)
- **`Start-AzLocalClusterUpdate`**: Provides detailed SBE dependency info when updates are blocked by HasPrerequisite/AdditionalContentRequired state, with guidance to install the SBE from the hardware vendor
- **`Get-AzLocalClusterUpdateReadiness`**: Surfaces `HasPrerequisiteUpdates` and `SBEDependency` in result objects for downstream consumption
- **`Get-AzLocalClusterUpdateReadiness`**: Console output shows "Has Prerequisite (SBE update required)" for clusters with only prerequisite-blocked updates
- **`Get-AzLocalClusterUpdateReadiness`**: Summary section includes count of clusters blocked by SBE prerequisites with vendor-specific guidance
- **`Get-AzLocalFleetStatusData`**: Sequential collection now extracts HasPrerequisite and SBE dependency info into readiness data
- **`Get-AzLocalFleetStatusData`**: Status output shows "Has Prerequisite" for clusters with only prerequisite-blocked updates

#### Maintenance Schedule Tag Support
- **New exported function `Test-AzLocalUpdateScheduleAllowed`**: Master gate that evaluates `UpdateWindow` and `UpdateExclusions` Azure resource tags to determine if an update should proceed
- **New internal function `ConvertFrom-AzLocalUpdateWindow`**: Parses maintenance window tag syntax (`<days>_<HH:MM>-<HH:MM>`) including day ranges, wildcards (`*`/`Daily`), and overnight windows
- **New internal function `ConvertFrom-AzLocalUpdateExclusion`**: Parses exclusion/blackout period tag syntax (`YYYY-MM-DD/YYYY-MM-DD`) with wildcard year support for recurring patterns
- `Start-AzLocalClusterUpdate` now checks schedule tags before applying updates; returns `ScheduleBlocked` status when outside maintenance windows or during exclusion periods
- Exclusion periods take priority over maintenance windows

#### Performance
- `New-AzLocalFleetStatusHtmlReport` now uses single-pass data collection instead of calling 6 separate module functions
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
- `Get-AzLocalClusterInfo`, `Invoke-AzLocalUpdateApply`, and SingleCluster paths in `Get-AzLocalUpdateSummary`, `Get-AzLocalAvailableUpdates`, `Get-AzLocalUpdateRuns` had no `az` CLI availability check - previously threw unhelpful `CommandNotFoundException`
- Existing auth check catch blocks now differentiate 'az not installed' from 'az not logged in' with distinct error messages
- 'Up to Date' counter now recognizes `AppliedSuccessfully` state from ARM API (was showing 0 for completed clusters)
- Recommended Update no longer shows the version a cluster is already on when state is `AppliedSuccessfully`/`UpToDate`

### What's New in v0.6.3

#### Bug Fixes, Security & Code Quality
- Fixed `-PassThru` parameter on `Get-AzLocalUpdateSummary` (was missing from param declaration)
- `-OutputPath` now pre-validated upfront (drive existence, .html extension) to fail fast before API calls
- Portal URLs in HTML report now HTML-encoded to prevent attribute injection
- ARG KQL queries now escape single quotes in `UpdateRingValue` to prevent injection
- All dynamic HTML values consistently HTML-encoded
- `Get-CurrentStepPath` has MaxDepth=20 safety limit
- Cluster name matching uses exact segment comparison instead of suffix pattern

### What's New in v0.6.2

#### 📊 New: Fleet Status HTML Report
- **New function `New-AzLocalFleetStatusHtmlReport`** generates self-contained HTML reports for fleet update status
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
New-AzLocalFleetStatusHtmlReport -ClusterNames Seattle `
    -OutputPath "C:\Reports\seattle.html" -IncludeHealthDetails -IncludeUpdateRuns

# Generate report for all clusters across the subscription (uncapped by default; use -MaxClusters to trim)
New-AzLocalFleetStatusHtmlReport -AllClusters `
    -OutputPath "C:\Reports\fleet-all.html" -IncludeHealthDetails -IncludeUpdateRuns

# Generate report for all Wave1 clusters
New-AzLocalFleetStatusHtmlReport -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -OutputPath "C:\Reports\wave1-status.html" -IncludeHealthDetails -IncludeUpdateRuns
```

#### ⚡ Performance: Resolve-Once Pattern
- All functions that accept `-ClusterNames` now resolve names to resource IDs **once upfront**
- Eliminates redundant API calls when multiple functions are called sequentially
- CI/CD pipelines use `-ClusterResourceIds` consistently (reduces ~800 to ~300 API calls for 100 clusters)
- `Test-AzLocalClusterHealth` accepts `-UpdateSummary` to skip redundant fetch

### What's New in v0.6.1

#### 🏥 New: Pre-Update Health Check Validation
- **New function `Test-AzLocalClusterHealth`** validates cluster health before applying updates
- Queries health check results from ARM (`updateSummaries` resource) to identify Critical, Warning, and Informational failures
- Critical failures block updates from being applied - this function shows you exactly what needs fixing
- Supports `-BlockingOnly` to show only update-blocking issues
- Export results to CSV, JSON, or JUnit XML for CI/CD integration

#### 🔒 Automatic Health Gate in `Start-AzLocalClusterUpdate`
- Before applying an update, the function now automatically checks for Critical health failures (Step 3b)
- If blocking issues are found, the cluster is skipped with detailed failure information and remediation guidance
- No more cryptic "Update is blocked due to health check failure" errors without context

#### 📈 Enhanced Diagnostics in `Get-AzLocalUpdateRuns`
- When the latest update run failed due to health check failures, the function automatically queries and displays the Critical failures
- Shows remediation steps inline so you know exactly what to fix

#### 🔇 Cleaner Console Output with `-PassThru`
- Functions no longer dump object lists to the console by default
- Formatted tables and diagnostics are still displayed — only the raw object output is suppressed
- Use `-PassThru` to return objects for pipeline/variable capture: `$results = Start-AzLocalClusterUpdate ... -PassThru`
- CI/CD pipeline examples updated accordingly

### What's New in v0.5.6 (since v0.5.0)

#### 🚀 Fleet-Scale Operations (NEW)
Six new functions for managing updates across fleets of **1000-3000+ clusters**:

| Function | Description |
|----------|-------------|
| `Invoke-AzLocalFleetOperation` | Orchestrates fleet-wide updates with batching, throttling, and retry logic |
| `Get-AzLocalFleetProgress` | Real-time progress tracking with success/failure percentages |
| `Test-AzLocalFleetHealthGate` | CI/CD health gate to prevent cascading failures between waves |
| `Export-AzLocalFleetState` | Save operation state for resume capability |
| `Resume-AzLocalFleetUpdate` | Resume interrupted operations from checkpoint |
| `Stop-AzLocalFleetUpdate` | Graceful stop with state preservation |

**Enterprise-Scale Features:**
- 📦 **Batch Processing**: Process clusters in configurable batches (default: 50)
- 🔄 **Retry Logic**: Automatic retries with exponential backoff (default: 3 retries)
- 💾 **State Management**: Checkpoint/resume capability for long-running operations
- 🚦 **Health Gates**: Configurable thresholds (default: max 5% failure, min 90% success)
- 📊 **Progress Tracking**: Real-time visibility into fleet-wide operations

**Examples:**
```powershell
# Start fleet-wide update with batching
Invoke-AzLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Production" `
    -BatchSize 100 -ThrottleLimit 20 -Force

# Check progress during operation
Get-AzLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Production" -Detailed

# CI/CD health gate between waves
$gate = Test-AzLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -MaxFailurePercent 2 -WaitForCompletion
if (-not $gate.Passed) { exit 1 }

# Resume after interruption
Resume-AzLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -RetryFailed -Force
```

#### 🏷️ Fleet-Wide Tag Support for All Query Functions
Three functions now support tag-based filtering for fleet-wide operations:

| Function | New Capabilities |
|----------|------------------|
| `Get-AzLocalUpdateSummary` | Query summaries across fleet by tag, name, or resource ID |
| `Get-AzLocalAvailableUpdates` | List available updates across fleet by tag, name, or resource ID |
| `Get-AzLocalUpdateRuns` | Get update run history across fleet by tag, name, or resource ID |

**New Parameters for All Three Functions:**
- `-ClusterNames` / `-ClusterResourceIds` - Query multiple specific clusters
- `-ScopeByUpdateRingTag` + `-UpdateRingValue` - Query clusters by UpdateRing tag
- `-ExportPath` - Export results to CSV, JSON, or JUnit XML (format auto-detected from extension)

**Examples:**
```powershell
# Get update summaries for all Wave1 clusters
Get-AzLocalUpdateSummary -ScopeByUpdateRingTag -UpdateRingValue "Wave1"

# List available updates across Production clusters, export to CSV
Get-AzLocalAvailableUpdates -ScopeByUpdateRingTag -UpdateRingValue "Production" -ExportPath "updates.csv"

# Get latest update run from all Ring2 clusters
Get-AzLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Ring2" -Latest
```

#### 📊 Fleet Update Status Monitoring
- **New CI/CD Pipeline**: Added `Step.6_fleet-update-status.yml` for both GitHub Actions and Azure DevOps
- **JUnit XML Reports**: Each cluster appears as a test case in CI/CD dashboards (passed=healthy, failed=issues)
- **Multiple Output Formats**: CSV, JSON, and JUnit XML exports for different use cases
- **Scheduled Monitoring**: Automated daily checks at 6 AM UTC with configurable scope
- **Dashboard Integration**: Results appear in GitHub Actions Tests tab and Azure DevOps Tests tab with analytics

#### ✅ Consistent Logging & Progress
- **Consistent Logging**: All functions now use `Write-Log` for consistent, timestamped, colored console output
- **Improved Progress Visibility**: `Get-AzLocalUpdateRuns`, `Get-AzLocalClusterUpdateReadiness`, and `Get-AzLocalClusterInventory` now show detailed progress during API operations
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
  2. **Service Principal** - For CI/CD pipelines using `Connect-AzLocalServicePrincipal`
  3. **Managed Identity (MSI)** - For Azure-hosted agents using `Connect-AzLocalServicePrincipal -UseManagedIdentity`

---

### What's New in v0.4.1

#### 🚀 New Features
- **Managed Identity (MSI) Support**: `Connect-AzLocalServicePrincipal` now supports Managed Identity authentication with `-UseManagedIdentity` switch, ideal for Azure-hosted runners, VMs, and containers

#### 🐛 Bug Fixes
- **CRITICAL**: Fixed Azure Resource Graph queries in `Get-AzLocalClusterInventory`, `Start-AzLocalClusterUpdate`, and `Get-AzLocalClusterUpdateReadiness` that were returning incorrect resource types (mixed resources like networkInterfaces, virtualHardDisks instead of clusters only). The issue was caused by HERE-STRING query format causing malformed az CLI commands. Queries now use single-line string format.
- **CRITICAL**: Fixed `Set-AzLocalClusterUpdateRingTag` failing with JSON deserialization errors when applying tags. Two issues were resolved:
  1. PowerShell/cmd.exe mangling JSON quotes when passed to `az rest --body` - now uses temp file with `@file` syntax
  2. PowerShell hashtable internal properties (`Keys`, `Values`, etc.) being included in JSON - now uses `[PSCustomObject]` with filtered `NoteProperty` members only

#### ✅ Improvements
- `Get-AzLocalClusterInventory` no longer dumps objects to console when using `-ExportPath` (cleaner output with summary and next steps)
- Added `-PassThru` switch to `Get-AzLocalClusterInventory` for CI/CD pipelines that need both CSV export AND returned objects

---

### What's New in v0.4.0

#### 🚀 New Features
- **Cluster Inventory Function**: New `Get-AzLocalClusterInventory` function queries all clusters and their UpdateRing tag status
- **CSV-Based Tag Workflow**: Export inventory to CSV, edit UpdateRing values in Excel, then import back to apply tags
- **CSV Input for Tags**: `Set-AzLocalClusterUpdateRingTag` now accepts `-InputCsvPath` for bulk tag operations
- **JUnit XML Export for CI/CD**: Export results to JUnit XML format for visualization in Azure DevOps, GitHub Actions, Jenkins, and other CI/CD tools

#### ✅ Improvements
- Renamed `-ScopeByTagName` to `-ScopeByUpdateRingTag` (now a switch parameter for clarity)
- Renamed `-TagValue` to `-UpdateRingValue` for consistency
- UpdateRing tag queries now use the standardized 'UpdateRing' tag name
- `-ExportResultsPath` and `-ExportPath` now support `.xml` extension for JUnit format
