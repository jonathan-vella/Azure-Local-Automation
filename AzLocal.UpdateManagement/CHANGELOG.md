# Changelog

All notable changes to the AzLocal.UpdateManagement module (renamed from AzStackHci.ManageUpdates in v0.7.3) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.70] - 2026-05-19

> **Backward compatible.** All v0.7.70 changes are additive over v0.7.69: a new exported cmdlet, a new `Section` column on the Step.3 audit rows (defaults to `Cron`), new `TargetResourceName` / `TargetResourceType` / `ClusterPortalUrl` / `AffectedClusterPortalUrls` properties on `Get-AzureLocalFleetHealthFailures` output, and richer Step.3 + Step.7 pipeline summaries. No behaviour change for callers that don't read the new columns. Pipeline pin bumps to `'0.7.70'`; refresh existing copies with `Update-AzureLocalPipelineExample`.

### Added

- **New cmdlet `Get-AzLocalFleetHealthOverview`** - one row per cluster, mirrors the LENS workbook "System Health Checks Overview" tile. Joins `microsoft.azurestackhci/clusters` with the cluster's `updateSummaries` extensibility resource via a single Resource Graph query. Output columns (12 in order): `ClusterName`, `ClusterPortalUrl`, `HealthStatus`, `UpdateStatus`, `CurrentVersion`, `SbeVersion`, `AzureConnection`, `LastChecked`, `HealthResultsAgeDays` (`datetime_diff('day', now(), LastChecked)`), `ResourceGroup`, `NodeCount`, `SubscriptionId`. Sort: `HealthResultsAgeDays desc, ClusterName asc`. Supports `-SubscriptionId`, `-UpdateRingTag` (incl. wildcard `***` + semicolon-list), `-ExportPath`, `-PassThru`.

### Changed (cmdlets)

- **`Test-AzureLocalApplyUpdatesScheduleCoverage` Audit rows now carry a `Section` discriminator.** `Schedule` is set on `RingMissingFromSchedule` / `RingOrphanedInSchedule` rows (the ring is the unit of work) and the row's `UpdateWindow` / `RequiredCronUTC` columns are intentionally empty for those rows. `Cron` is set on the existing ring/window coverage rows. Default sort is now Schedule-section first, then cron coverage. Callers that don't filter on `Section` see no behavioural change.
- **`Test-AzureLocalApplyUpdatesScheduleCoverage -View Recommend` now emits a multi-section markdown report.** When `RingMissingFromSchedule` rows are present, an "Action required - add these rings to apply-updates-schedule.yml" section is emitted FIRST. An "Action required - cron coverage (paste into Step.5_apply-updates.yml)" section is emitted SECOND with the cron entries. When `-SchedulePath` is omitted only the cron section is emitted (back-compat for v0.7.68 callers).
- **`Get-AzureLocalFleetHealthFailures` Summary now sorts Critical-first.** Sort is Severity (Critical, then Warning, then everything else), then `ClusterCount` desc, then `FailureCount` desc. A Critical failure affecting 1 cluster ranks above a Warning affecting many clusters.
- **`Get-AzureLocalFleetHealthFailures` Detail rows gain three properties.** `TargetResourceName`, `TargetResourceType` (sub-resource that emitted the check failure - e.g. the NIC name and `Microsoft.Compute/virtualMachines/networkInterfaces`), and `ClusterPortalUrl` (`https://portal.azure.com/#@/resource{ClusterResourceId}` deep-link).
- **`Get-AzureLocalFleetHealthFailures` Summary rows gain `AffectedClusterPortalUrls`** aligned with `AffectedClusters`. Same element count, same order, joined with the `'; '` separator (semicolon-space). Step.7 zips the two lists into `[ClusterName](portalUrl)` markdown links in the run summary.

### Changed (pipeline samples)

- **`Step.3_apply-updates-schedule-audit.yml` (GH + ADO) - dual JUnit, dual Audit Detail, inline Recommend when issues exist.** The YAML now emits TWO JUnit `<testsuite>` blocks (`ScheduleCoverage` + `CronCoverage`) and TWO Audit Detail markdown tables (one per section) with conditional headings. When `$hasIssues -and $reco`, the Recommend cmdlet output is prepended above the detail tables so operators see the fix before scrolling. The zero-row JUnit placeholder text is now centralised via the `Write-Suite -EmptyPlaceholderName 'No tagged clusters found - nothing to audit'` helper (GH parity with ADO since v0.7.67 is preserved).
- **`Step.7_fleet-health-status.yml` (GH + ADO) - cluster portal hyperlinks + 3 new detailed columns + new System Health Checks Overview section.** The Summary and Detailed Results tables now render cluster cells as `[ClusterName](portalUrl)` markdown links (capped at first 10 in the Summary, then `... (+N more)`). Detailed Results adds three columns: Failure Remediation (auto-renders as `[link](url)` when the value starts with `https://`), Target Resource Name, and Target Resource Type. A new "### System Health Checks Overview (fleet rollup)" section calls `Get-AzLocalFleetHealthOverview` and publishes `fleet-health-overview.csv` / `.json` to the Reports list alongside the failures table.
- **Pipeline pin bumps.** All 14 `Step.*.yml` files (7 GitHub Actions + 7 Azure DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.69'` to `'0.7.70'`.

## [0.7.69] - 2026-05-18

> **Hard break vs v0.7.68.** Schema `schemaVersion: 1` for the new `apply-updates-schedule.yml` is the first stable version of this file. There are no v0 -> v1 migration recipes shipped (the framework is in place; the recipes table is intentionally empty). If you were running an experimental schedule from earlier development builds, regenerate via `New-AzLocalApplyUpdatesScheduleConfig`.

### Added

- **Ring-aware apply-updates schedule (5 new cmdlets).** Day-grain `apply-updates-schedule.yml` (schema v1) is now the single source of truth for "which `UpdateRing` is eligible on a given UTC date". Three independent layers control "what runs when":
  1. **This file (day-grain)** says WHICH `UpdateRing` tag values are eligible TODAY.
  2. **The Step.5 cron schedule (intra-day-grain)** says HOW OFTEN the apply-updates job wakes up.
  3. **The per-cluster `UpdateWindow` tag (minute-grain)** says WHEN, during an eligible day, the actual update is allowed to start.
- `Get-AzLocalApplyUpdatesScheduleConfig` - parses + validates a schedule file. **Hard-fails with `'schedule:' list is empty - at least one row is required`** when the schedule has no active rows; this is the safety gate the apply-updates pipeline depends on (see the strawman generator below).
- `Resolve-AzLocalApplyUpdatesScheduleRing` - maps a UTC date to the matching `UpdateRing(s)` using cycle-week math anchored at `cycleAnchorISOWeek` / `cycleAnchorYear`. **Union semantics**: when multiple rows match, the resolver concatenates their `rings` columns with `;` and passes the deduplicated result to `-UpdateRingValue`.
- `Get-AzLocalApplyUpdatesScheduleNextFirings` - previews the next N days of resolved firings so operators can sanity-check the rotation before committing.
- `New-AzLocalApplyUpdatesScheduleConfig` - generates a **STRAWMAN** schedule from the live fleet's `UpdateRing` tag values (or from `-Rings` for offline use). Every generated schedule row is emitted **commented out by design**, so the apply-updates pipeline hard-stops at the reader until the operator reviews and uncomments at least one row. Output mirrors the bundled `apply-updates-schedule.example.yml` instructional comments verbatim, including the Wikipedia ISO-week link and the 3-layer key concept; the worked example anchor is computed dynamically (`ISO Week 1 of <year> began on Monday, <date>`) but the actual anchor is the current ISO week so "week 1 of the cycle = the week you ran the generator".
- `Update-AzLocalApplyUpdatesScheduleConfig` - idempotent migrator that walks an existing schedule through registered migration recipes. v0.7.69 ships the recipes table empty (no migrations needed yet); the framework is in place for future schema bumps.
- **`Test-AzureLocalApplyUpdatesScheduleCoverage` gained `-SchedulePath`** (two-way ring diff). When supplied, the audit emits two new status rows: `RingMissingFromSchedule` (fleet ring with no schedule row) and `RingOrphanedInSchedule` (schedule ring no cluster carries). Both are surfaced in the summary table, the JUnit XML failure list, and the Markdown summary at the top of the Step.3 run page.

### Changed (pipeline samples)

- **`Step.5_apply-updates.yml` (GH + ADO)** now resolves the `UpdateRing` value from `apply-updates-schedule.yml` on every **scheduled** firing. Manual `workflow_dispatch` (GH) / non-`Schedule` `Build.Reason` (ADO) runs still honour the operator-supplied `-UpdateRingValue` input verbatim, so back-compat for ad-hoc maintenance is preserved.
- **Concurrency:** Step.5 gained a workflow-level `concurrency:` block on GitHub Actions to prevent overlapping cron firings. Azure DevOps has no first-class YAML concurrency primitive; the ADO version documents the equivalent **Pipeline Settings -> Triggers -> Limit concurrent runs** option in a banner comment.
- **`Step.3_apply-updates-schedule-audit.yml` (GH + ADO)** gained a `schedule_path` / `schedulePath` input (defaulted to the standard layout), a `debug` toggle for self-service triage (`$VerbosePreference=Continue`, `$DebugPreference=Continue`, plus a one-shot environment snapshot), and surfaces the new `RingMissingFromSchedule` / `RingOrphanedInSchedule` counts in the summary table + JUnit failure list. When `pipeline_path` is empty and `schedule_path` is set, the audit runs schedule-file-only (no cron-vs-tags audit).
- **`apply-updates-schedule.example.yml`** ships as documentation only; pipeline-deployment cmdlets (`Copy-AzureLocalPipelineExample` / `Update-AzureLocalPipelineExample`) do **not** touch it. Operators run `New-AzLocalApplyUpdatesScheduleConfig` to generate a strawman starting from their live fleet's `UpdateRing` tag values.

### Migration

For a fleet that has already been tagged via `Set-AzureLocalClusterUpdateRingTag`:

```powershell
# 1. Generate a strawman schedule (all rows commented out by design)
New-AzLocalApplyUpdatesScheduleConfig -OutputPath .\.github\apply-updates-schedule.yml

# 2. Open the file, REVIEW each strawman row, then UNCOMMENT the rows
#    that match your change-control policy. Edit weeksInCycle /
#    daysOfWeek / rings / notes as needed.

# 3. Preview the rotation BEFORE committing
Get-AzLocalApplyUpdatesScheduleNextFirings `
  -Schedule (Get-AzLocalApplyUpdatesScheduleConfig -Path .\.github\apply-updates-schedule.yml)

# 4. Refresh the pipeline YAMLs so they pick up the v0.7.69 resolver wiring
Update-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzureLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps

# 5. Audit the fleet against the schedule (two-way ring diff)
Test-AzureLocalApplyUpdatesScheduleCoverage `
  -PipelineYamlPath .\.github\workflows\Step.5_apply-updates.yml `
  -SchedulePath     .\.github\apply-updates-schedule.yml `
  -View Audit
```

Without an active (uncommented) row the apply-updates pipeline will hard-fail at the reader step with the exact remediation message; this is the v0.7.69 safety gate, not a regression.

## [0.7.68] - 2026-05-18

### Added

- **New cmdlet `Update-AzureLocalPipelineExample`.** Marker-aware merge tool that refreshes a customer's copy of any bundled pipeline YAML to the version shipped with the current module **while preserving operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs**. Customer-side cron schedules in `schedule-triggers` and ITSM secret bindings in `itsm-secrets` (Step.5 only) survive a module upgrade; everything outside the markers is replaced with the new bundled content. Supports `-WhatIf` for preview, `-Force` for non-interactive runs, and `-PassThru` for a per-file change manifest. This is the operator-friendly upgrade path that complements `Copy-AzureLocalPipelineExample` (which remains the clean-overwrite tool).
- **New cmdlet `Get-AzureLocalUpdateRunFailures`.** ARG-only deep-error extraction (9 levels deep into the `properties.state.progress` tree of `microsoft.azurestackhci/clusters/updates/updateRuns`) returns verbose error information at fleet scale without per-cluster Az SDK or REST shell-outs. Two views: `-View Summary` (one row per failed update run) and `-View Detail` (one row per leaf failure with the full breadcrumb to the failed step). Useful in `Step.5_apply-updates.yml` post-mortem reports and as a follow-up call after `Get-AzureLocalFleetProgress` reports failures.
- **`Invoke-AzResourceGraphQuery` now retries on HTTP 429 (throttle).** The helper inspects the `Retry-After` response header when present and otherwise applies bounded exponential backoff (capped at the documented Azure Resource Graph throttling envelope). Large fleet sweeps (Get-AzureLocalFleetProgress, Get-AzureLocalFleetStatusData, the schedule-audit pipeline) no longer fall over at the throttling boundary; the existing happy-path latency is unchanged.
- **Cmdlet inventory and design table (`docs/Cmdlet-Inventory-And-Design.md`).** Documents which cmdlets read vs write, which back-end they use (ARG vs Az SDK vs az CLI), and the design rules that keep read paths ARG-first (no `-ThrottleLimit`, no per-cluster Get-AzResource fan-out). Removes ambiguity about which path a new cmdlet should take.
- **Layer 1 AZLOCAL-CUSTOMIZE marker pairs in 7 pipeline YAMLs.** Two named regions (`schedule-triggers` and, on `Step.5_apply-updates.yml` only, `itsm-secrets`) mark the YAML areas that operators commonly customise: cron schedules, ITSM secret bindings. Markers are pure YAML comments and have no runtime effect; they are scaffolding for the forthcoming `Update-AzureLocalPipelineExample` cmdlet that will preserve operator edits inside these regions across module upgrades. Documented in `Automation-Pipeline-Examples/README.md`.

### Changed (ARG-first refactor)

- **The following cmdlets are now ARG-first single-batch reads.** `-ThrottleLimit` is removed (it was a no-op against ARG and merely signalled "this cmdlet does a fan-out"):
  - `Get-AzureLocalUpdateSummary`
  - `Get-AzureLocalAvailableUpdates`
  - `Get-AzureLocalClusterUpdateReadiness`
  - `Test-AzureLocalClusterHealth`
  - `Get-AzureLocalFleetProgress`
  - `Get-AzureLocalFleetStatusData`
  - `New-AzureLocalFleetStatusHtmlReport`

  All shipped pipeline YAMLs were updated to stop passing `-ThrottleLimit`. The aggregated effect on the cluster API is a 5-10x reduction in subscription-level Azure Resource Manager calls for the common fleet-status pipelines.
- **`Get-AzureLocalFleetProgress` no longer silently returns stale state on empty ARG result rows.** The previous code-path treated an empty ARG response as "no change" and returned the last cached state; consumers (including the `Step.6_fleet-update-status.yml` JUnit emitter) therefore reported "everything green" on fleets that had been completely de-tagged or that hit a transient ARG error. The cmdlet now surfaces the empty-fleet condition explicitly so the operator can act on it.
- **`Invoke-AzResourceGraphQuery` hardened against `az.cmd` CR/LF stdout truncation.** A latent bug in `az.cmd` (Windows runners only) could chop the JSON payload at the first chunked-write boundary when stdout was piped through PowerShell, producing the N-row collapse where a 27-cluster fleet would surface as 24 rows. The helper now reads stdout via `[Console]::OpenStandardOutput()` redirect into a `MemoryStream` (or equivalent: a `2>&1 | Out-String` capture with explicit `[System.Text.Encoding]::UTF8` decoding) so the full payload arrives intact. Existing Pester unit tests pin the regression.

### Changed (pipeline samples - renames and Step.X_ prefix)

- **All 16 bundled pipeline YAMLs renamed with a `Step.X_` ordering prefix** so they sort by execution order in a customer's repo:
  - `Step.0_authentication-test.yml`            (was `auth-smoke-test.yml`)
  - `Step.1_inventory-clusters.yml`
  - `Step.2_manage-updatering-tags.yml`
  - `Step.3_apply-updates-schedule-audit.yml`
  - `Step.4_assess-update-readiness.yml`
  - `Step.5_apply-updates.yml`
  - `Step.6_fleet-update-status.yml`
  - `Step.7_fleet-health-status.yml`

  Both platforms (GitHub Actions and Azure DevOps). The rename plus the `Step.0` -> `Step.7` numbering matches the documented operator runbook order and lets a fresh `Copy-AzureLocalPipelineExample` lay the pipelines out so that an alphabetic listing in the consumer's IDE / repo browser tells the story end-to-end.
- **Backwards compatibility for already-deployed consumers:** `Read-AzLocalApplyUpdatesYamlCrons` (the schedule-audit scanner) glob list expanded to match both new (`Step.5_apply-updates*.yml`) and legacy (`apply-updates*.yml`) names. A customer who upgrades the module but has not yet re-run `Copy-AzureLocalPipelineExample` will still see correct schedule-coverage audits.

### Changed (pipeline display ordering)

- **Each shipped pipeline YAML now carries the `Step.N - ` prefix in the workflow display name, not just the filename.** GitHub Actions: the top-level `name:` field in each of the 8 workflows reads `Step.N - <description>` (e.g. `Step.0 - Auth Smoke Test`, `Step.7 - Fleet Health Status`); the Actions sidebar sorts alphabetically by this field, so the 8 workflows now list in execution order. Azure DevOps: the leading title comment in each of the 8 YAMLs reads `# Step.N - <description>`, which is the value the import wizard prefills as the pipeline's definition name. New section 1.1 in `Automation-Pipeline-Examples/README.md` documents the convention and explains the GH-Actions-vs-ADO behavioural difference.

### Fixed

- **Latent single-element-array unwrap bug in `Get-AzureLocalUpdateRuns` and `Get-AzureLocalClusterUpdateReadiness`.** Both cmdlets group ARG rows into a `Hashtable<string, List[object]>` and then look up the per-cluster bucket with the pattern `$x = if ($h.ContainsKey($key)) { @($h[$key]) } else { @() }`. Under PowerShell 5.1 the `if` block's pipeline return unwraps a single-element `Object[]` to its bare element, and `PSCustomObject.Count` is empty (not 1) under strict mode, so any cluster having **exactly one** update run / one available update would be silently treated as having zero items - `Get-AzureLocalUpdateRuns` would print `No Runs` against that cluster, and `Get-AzureLocalClusterUpdateReadiness` would emit a degraded "no updates available" row. The fix replaces the brittle ternary with an explicit `$x = @(); if (...) { $x = @($h[$key]) }` assignment that preserves Object[] semantics. New Pester guards (`Get-AzureLocalUpdateRuns parallel dispatch` + `Get-AzureLocalClusterUpdateReadiness (ARG-batch dispatch)`) pin the regression with mock data that returns exactly one row per cluster.

### Tests

- **All five `Describe` blocks that were `-Skip`-marked in the v0.7.68 ARG-first refactor have been un-skipped and rewritten against `Invoke-AzResourceGraphQuery` mocks.** 10 tests now pass (FleetProgress: 2, UpdateSummary: 2, ClusterUpdateReadiness multi-cluster: 1, ClusterUpdateReadiness readiness gates: 4, Get-AzureLocalUpdateRuns parallel dispatch: 1). The new mock pattern uses `InModuleScope` + a `function global:az { ... }` shim + `Mock Test-AzCliAvailable` / `Mock Install-AzGraphExtension` / `Mock Invoke-AzResourceGraphQuery` returning rows shaped per each cmdlet's KQL `project` clause (`ClusterResourceId_`, `properties` bag matching the ARM REST shape). Plus +4 new throttle-handling tests against `Invoke-AzResourceGraphQuery` (retry-then-succeed on 429, max-retries-exhausted, no-retry on non-throttle errors, diagnostic flags reset per call) and +3 `Get-AzureLocalFleetStatusData` schema-contract tests (top-level shape + types, `ValidateNotNullOrEmpty` on `-ClusterResourceIds`, `ModuleVersion` field tracks the module-scope constant). Full suite: **Passed=511, Failed=0, Skipped=0**.

If you have copied any of the bundled workflows into your repo, refresh them via:

```powershell
Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub      -Update
Copy-AzureLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps -Update
```

This brings in the new file names *and* the Layer 1 marker scaffolding. Operator-customised cron schedules and ITSM secret bindings between `BEGIN-AZLOCAL-CUSTOMIZE` / `END-AZLOCAL-CUSTOMIZE` markers in your already-deployed YAMLs are intentionally **not** preserved by `Copy-AzureLocalPipelineExample` (it is a clean overwrite tool); the forthcoming `Update-AzureLocalPipelineExample` cmdlet will do the marker-aware merge.

## [0.7.67] - 2026-05-18

### Added (CI/CD parity and documentation)

- **GitHub Actions schedule-audit pipeline now emits a passing testcase when the fleet has no tagged clusters.** `apply-updates-schedule-audit.yml` (GitHub Actions) previously wrote an empty `<testsuite>` to `schedule-coverage-audit.xml` whenever there were no `(UpdateRing, UpdateWindow)` rows to evaluate. `dorny/test-reporter` then surfaced the run as "no tests found", which is indistinguishable from a misconfigured reporter step. The pipeline now writes `<testcase classname="ScheduleCoverage" name="No tagged clusters found - nothing to audit" />` for the zero-row case, matching the existing Azure DevOps behaviour. Operators get a clean "passed (1/1)" reading in the Tests tab regardless of whether the fleet has any tagged clusters yet, which removes the daily false-alarm during onboarding (no clusters tagged) and after fleet-wide tag clean-ups.

- **Schedule-audit summary now surfaces ready-to-paste cron entries at the top when coverage drift exists.** Both `apply-updates-schedule-audit.yml` (GitHub Actions and Azure DevOps) previously emitted the recommended cron block at the bottom of the run summary, after the audit detail table. When the audit reported any `Uncovered`, `PartiallyCovered`, `MalformedTag`, or `UnparseableCron` rows the operator had to scroll past the detail table to find the actionable fix. The pipelines now compute `$hasIssues` from those four counts and, when true, render an `### Action required - paste these cron entries into apply-updates.yml` section immediately below the counts table - before the detail rows. When the fleet is fully covered the recommendation block remains at the bottom as a reference, so the all-green case is visually unchanged. A new Pester guard (`v0.7.67 schedule-audit summary - cron fixes first when issues exist`) asserts that both YAMLs carry the conditional structure and that the "Action required" header appears textually before the "Audit Detail" header in the script body, so any future edit that reverses the ordering will fail in CI.

- **Pipeline README now includes an artifact-handoff map of the end-to-end runbook.** `Automation-Pipeline-Examples/README.md` section 6 carried a phase-oriented flow diagram (Inventory -> Tag -> Rollout -> Steady-state). The new "Artifact handoffs at a glance" subsection adds an explicit data-flow diagram showing which artifact each pipeline emits and which downstream pipeline consumes it (e.g. `cluster-inventory.csv` from Inventory feeds the manual tagging edit and the manage-tags pipeline; `cluster-readiness.csv` from Assess feeds Apply via its `ClusterResourceId` column; `schedule-coverage-recommend.md` from the audit is the only artifact intended to be pasted by hand). The accompanying bullet list calls out the four artifacts operators most commonly trip on (the operator-edited CSV, the readiness handoff that Apply consumes verbatim, the JUnit XML that drives the Tests tab, and the recommendation file that must be pasted into `apply-updates.yml`).

- **New maintainer doc: [`docs/RELEASE-PROCESS.md`](docs/RELEASE-PROCESS.md).** Documents the staged unlisted-release flow the module uses (publish -> immediately unlist -> validate against a test repo with `REQUIRED_MODULE_VERSION` exact-pinned to the candidate -> list after validation passes), the verification commands for each stage, and the Pester guardrails that the release flow relies on. This puts the release rules in the repo rather than in tribal knowledge / chat history. Pipeline consumers do not need this doc; module maintainers do.

- **`Automation-Pipeline-Examples/README.md` section 11 (Security model) now documents per-job `permissions:` blocks as an intentional security feature.** Every shipped GitHub Actions workflow declares its own job-level `permissions:` block (`id-token: write`, `contents: read`, `checks: write` only where needed). The new bullet calls out that consumers should not lift those blocks to a top-level `permissions:` block when copying samples, and explains how the per-job shape (a) limits token scope to exactly the job that needs the write and (b) lets you keep `id-token: write` off read-only summary jobs. Also documents that the samples are compatible with the recommended *Settings -> Actions -> General -> Workflow permissions = Read repository contents and packages permissions* hardening, because every job that needs a write already declares it explicitly.

### Changed (consistency)

- **All Azure DevOps sample pipelines now use the same `azureSubscription:` placeholder.** Four files (`assess-update-readiness.yml`, `fleet-health-status.yml`, `fleet-update-status.yml`, `apply-updates-schedule-audit.yml`) previously used `'YOUR-SERVICE-CONNECTION-NAME'` while the other four ADO YAMLs (`apply-updates.yml`, `manage-updatering-tags.yml`, `inventory-clusters.yml`, `auth-smoke-test.yml`) used `'AzureLocal-ServiceConnection'` with an `# Update with your service connection name` comment. All eight ADO pipelines now use `'AzureLocal-ServiceConnection'` + comment - the placeholder matches the value documented in section 3.2 of the pipeline README (and matches the `New-AzureServiceConnection` example name), so an operator who follows the auth setup verbatim no longer has to find-and-replace anything in the YAMLs. Consumers who keep an existing service connection with a different name override at copy time.

### Fixed (in-depth module review - batch 3)

This batch addresses the six findings from the post-batch-2 module review. None are user-visible behaviour changes for the happy path; all are defence-in-depth.

- **`$script:ModuleVersion` constant in `AzLocal.UpdateManagement.psm1` is now bumped in lock-step with the `.psd1` manifest, and a new Pester guard fails any future drift.** The script-scope constant is what `Start-AzureLocalClusterUpdate` writes into its run-log header and what `Get-AzureLocalFleetStatusData` writes into the `ModuleVersion` field of the fleet-state JSON. It had been stuck at `'0.7.66'` while the manifest moved to `'0.7.67'`, so every v0.7.67 run-log and every v0.7.67 fleet-state file misreported the producing module version - which is the exact field operators use to triage CI vs local-runner discrepancies. New test `Module version constants are in sync between .psm1 and .psd1` asserts `(Import-PowerShellDataFile ...).ModuleVersion -eq InModuleScope { $script:ModuleVersion }` so the next forgotten bump is caught at build time.

- **New private helper `Invoke-AzCliJson` for the `az <subcommand>` calls that need JSON parsing but cannot go through `Invoke-AzRestJson`.** The cp1252 stderr-warning regression that v0.7.66 fixed in `Invoke-AzRestJson` (and v0.7.67 batch-1 backported into `Invoke-AzResourceGraphQuery`) had three remaining ambush sites where the unsafe `az ... 2>&1 | ConvertFrom-Json` pattern was still in use: `Get-AzureLocalClusterInventory` resolving subscription display names via `az account show`, `Invoke-AzLocalSideloadedAutoResetForCluster` reading the cluster tags via `az rest`, and `Set-AzLocalClusterTagsMerge` reading the tags-subresource via `az rest`. The two `az rest` callers now go through the existing `Invoke-AzRestJson`. The third (`az account show`) goes through the new `Invoke-AzCliJson` helper, which applies the same stream-split-by-element-type pattern, auto-appends `--only-show-errors`, sets `PYTHONIOENCODING=utf-8` as defence-in-depth (and restores it in `finally`), and returns `[PSCustomObject]@{ Ok; Data; Error }` so callers no longer have to inspect `$LASTEXITCODE` manually. Seven new Pester tests cover the helper (clean JSON, cp1252 stderr warning ignored, non-zero exit code surfaces a scrubbed error, empty stdout, non-JSON stdout, `--only-show-errors` appended, `PYTHONIOENCODING` restored).

- **`ConvertFrom-AzLocalCronExpression` now accepts cron step syntax (`*/N`, `<a>-<b>/N`, `<a>/N`).** The schedule advisor was falsely flagging crons such as `*/15 * * * *` (every fifteen minutes), `0 */6 * * 1` (every six hours on Mondays), and `0 9-17/2 * * 1-5` (every two hours between 9 and 17 on weekdays) as `UnparseableCron` - even though both GitHub Actions and Azure DevOps schedule them correctly. The parser now expands `*/N` over the field's full range, `<a>-<b>/N` over the explicit `[a,b]` range, and `<a>/N` over `[a, max]` (the standard "anchor and stride" cron semantics). Step values must be positive integers; out-of-bounds bases still throw with the existing bounds messages. Three new positive tests cover `*/15`, `9-17/2`, and `5/15`; the previously-existing test that asserted `*/15` was *rejected* has been flipped to assert the 672-fires-per-week expansion is correct; a new negative test covers `*/0`.

- **`Reset-AzureLocalSideloadedTag` now warns when a `-ClusterResourceIds` entry does not match the expected `/clusters/<name>$` pattern.** The `ByResourceId` resolver previously dropped malformed entries (typos, trailing slash, wrong provider, truncated string) silently - the operator would see "no matching clusters" without any indication that one of their inputs had been excluded. The resolver now emits `Write-Log -Level Warning` for each malformed input naming the exact ResourceId it skipped. The other resolvers (`ByName`, `ByTag`) already warned on lookup failure; this just brings `ByResourceId` to parity. New Pester test asserts the warning fires for `/this/is/not/a/cluster/resource/id`.

- **`Tests/Invoke-Tests.ps1` HTML footer is no longer susceptible to `Get-Module` returning an array.** When nested modules are loaded (which is the default for this module - every Private/*.ps1 is a nested module), `Get-Module AzLocal.UpdateManagement` returns one entry per loaded version, and `.Version` on that array surfaces as `Object[]` whose `ToString()` is the literal string `"System.Object[]"`. The HTML report footer was therefore intermittently printing `Module Version: System.Object[]`. The test runner now selects the newest loaded version via `Sort-Object Version -Descending | Select-Object -First 1` before reading `.Version`.

- **`Import-AzureLocalFleetState` now refuses any input file larger than 50 MB before reading it.** The helper previously called `Get-Content -Raw | ConvertFrom-Json` with no size check; pointing it at a multi-GB file (typo, mis-glob, malicious symlink) would have OOMed the runner. Real fleet-state files (`Export-AzureLocalFleetState` output) are tens of KB at most, so a 50 MB ceiling is ~3 orders of magnitude above any plausible legitimate input. The cap message names the actual file size in MB and explains what valid input looks like, so the operator can either widen the cap deliberately or fix the path. Two new Pester tests cover the cap (Get-Item mocked to report 60 MB throws) and the happy path (normal-sized fleet-state file loads).

### Pipeline migration

If you have copied any of the bundled workflows into your repo, refresh them via:

```powershell
Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub      -Update
Copy-AzureLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps -Update
```

## [0.7.66] - 2026-05-18

### Fixed (critical)

- **`Get-AzureLocalFleetHealthFailures` failed JSON parsing on hosted Windows runners when the Azure CLI emitted a cp1252 encoding warning.** Any call into `Invoke-AzResourceGraphQuery` (currently used by `Get-AzureLocalFleetHealthFailures` and indirectly by every consumer of the `fleet-health-status.yml` pipeline) on a `windows-latest` GitHub Actions runner (or any ADO Windows agent whose console code page is `cp1252`) could surface the following stderr line from the Azure CLI's underlying Python layer:

  ```
  WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.
  ```

  The helper captured `& az graph query ... 2>&1` as a single merged stream and passed the entire thing to `ConvertFrom-Json`, so the WARNING line got prepended to the JSON body and the cmdlet threw:

  ```
  Conversion from JSON failed with error: Unexpected character encountered while parsing value: W. Path '', line 0, position 0.; raw: WARNING: Unable to encode the output with cp1252 encoding. ...
  ```

  This was the same class of bug that the v0.7.2 hardening of `Invoke-AzRestJson` already handled - the fix never made it into `Invoke-AzResourceGraphQuery` when that helper was split out. The helper has now been updated to:
  1. **The actual fix:** split the merged `2>&1` stream by element type after capture. Stderr lines surface as `[System.Management.Automation.ErrorRecord]` objects when captured via `2>&1`; stdout lines surface as strings. Only the string stream is fed to `ConvertFrom-Json`. The error-throwing path likewise renders the stderr stream separately so token-scrubbing still applies. (`--only-show-errors` was already passed by this helper since v0.7.2, but in some non-cp1252 character paths the encode warning still leaks through, hence the belt-and-braces stream split.)
  2. **Cosmetic defence-in-depth:** set `$env:PYTHONIOENCODING = 'utf-8'` for the duration of the call (previous value restored in a `finally` block). **Note: this is a structural no-op for stock `az.cmd`** - it launches Python with the `-I` (isolated) flag which implies `-E` and causes Python to ignore every `PYTHON*` env var, per [Azure/azure-cli#28497](https://github.com/Azure/azure-cli/issues/28497) and the v0.7.2 root-cause analysis. The assignment only takes effect if the host has manually patched `az.cmd` to remove `-I`. It is retained purely so that those (rare) hosts get the same UTF-8 behaviour as the stream-split path.

  No public surface change. Every fleet-health-status pipeline run on a Windows runner is now resilient to this stderr warning regardless of the runner's console code page.

- **`apply-updates-schedule-audit.yml` (both GitHub Actions and Azure DevOps) shipped with a default `pipeline_path` of `AzLocal.UpdateManagement/Automation-Pipeline-Examples` - a path that only exists in *this* module's source repo, never in a consumer repo.** Every default-trigger run of the schedule audit therefore failed with:

  ```
  PipelineYamlPath 'AzLocal.UpdateManagement/Automation-Pipeline-Examples' does not exist on the runner.
  Either commit the folder to the repo or pass a different -pipeline_path via workflow_dispatch.
  ```

  before the schedule advisor could write its JUnit XML. The next step (`dorny/test-reporter` on GH, `PublishTestResults@2` on ADO) then failed with `Error: No test report files were found matching the pattern 'reports/schedule-coverage-audit.xml'`, making the entire job red. Both YAMLs now default to the standard consumer layout:
  - GitHub Actions: `.github/workflows` (the folder where consumers paste the bundled `apply-updates.yml` sample).
  - Azure DevOps: `.azure-pipelines` (the convention recommended by the ADO docs; consumers who keep apply-updates.yml elsewhere can still override via the `pipelinePath` parameter at queue time).

  When the resolved path still does not exist on the runner (operator override pointed at a missing folder, etc.) the audit step now lists which common pipeline folders **do** exist in the checked-out repo (`.github/workflows`, `.azure-pipelines`, `pipelines`, repo root) so the operator immediately knows what value to pass.

### Added (UX + capability)

- **Status emojis in the Fleet Update Status summary.** `fleet-update-status.yml` (GitHub Actions and Azure DevOps) now renders the `Critical Health` and `Primary Status` summary tables with the same visual language operators already use to read JUnit dashboards: a green tick for "no failures / ready / passing", a red cross for "failed / in error", a refresh glyph for "running / in progress", a yellow circle for "blocked / waiting", and an info glyph for everything else. The legacy `[ok] / [fail] / [ready] / [running] / [blocked] / [info]` bracket markers are gone. The summary block is plain markdown so it renders identically on the GH Actions step summary, the ADO pipeline run extension, and any markdown viewer (no JS, no images).

- **Generation timestamp in the Fleet Update Status summary heading.** Both `fleet-update-status.yml` files now render the H2 heading as `## Fleet Update Status Summary  _(generated 2026-MM-DD HH:MM:SS UTC)_` so downstream consumers can tell at a glance when the data was collected. The timestamp is computed with `(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')` to keep GitHub Actions and Azure DevOps in sync.

- **Failed clusters now appear before passing clusters in the JUnit per-cluster block.** The per-cluster `<testcase>` entries emitted by both `fleet-update-status.yml` files used to be emitted in arrival order (i.e. ARG response order). They are now bucketed into a `$failedClusters` collection vs a `$passedClusters` collection, each sorted alphabetically by `ClusterName`, then concatenated with failed-first into `$orderedClusters` and emitted in that order. Failing clusters are therefore the first things operators see in the dorny/test-reporter view (GitHub) and the Tests tab (Azure DevOps).

- **Every downloadable pipeline artifact now carries a UTC timestamp suffix.** All `actions/upload-artifact` steps (GitHub Actions) and all `PublishBuildArtifacts@1` / `PublishPipelineArtifact@1` tasks (Azure DevOps) now declare `name:` / `ArtifactName:` of the form `azlocal-<purpose>_yyyyMMdd_HHmmss`. The timestamp is computed once per job in a dedicated `Compute Artifact Timestamp` step (GH: `id: artifact-stamp` writing `timestamp=...` to `$GITHUB_OUTPUT`; ADO: `name: stamp` writing `##vso[task.setvariable variable=artifactStamp;isOutput=true]...`). Two runs of the same pipeline on the same day now produce distinct zip downloads (`azlocal-fleet-update-status-report_20260518_140000.zip` vs `azlocal-fleet-update-status-report_20260518_180000.zip`) instead of clobbering each other in the operator's downloads folder. Renamed artifacts: `fleet-status-reports` -> `azlocal-fleet-update-status-report`, `fleet-health-reports` -> `azlocal-fleet-health-status-report`, `cluster-inventory` -> `azlocal-cluster-inventory`, `updatering-tag-logs` -> `azlocal-updatering-tag-logs`, `schedule-coverage-reports` / `ScheduleCoverageReports` -> `azlocal-apply-updates-schedule-audit-report`, `readiness-report` -> `azlocal-apply-updates-readiness-report`, `readiness-assessment` -> `azlocal-readiness-assessment-report`, `update-logs` -> `azlocal-apply-updates-logs`, `itsm-results` -> `azlocal-apply-updates-itsm-results`.

- **Pipeline `UpdateRing` inputs now accept a single value, a semicolon-delimited list, or the literal `***` wildcard for ALL tagged clusters.** Every pipeline that exposes `update_ring:` (GH workflow_dispatch) or `updateRing:` (ADO parameters) is updated:
  - Single value (unchanged): `Wave1`
  - Multiple rings: `Prod;Ring2` (semicolon separator; whitespace around each ring is trimmed)
  - Wildcard: `***` (three stars, deliberate gesture) matches every cluster that **has** a non-empty `UpdateRing` tag. Untagged clusters are excluded so the wildcard preserves the existing opt-in gate. **A single `*`, double `**`, or quadruple `****` are all REJECTED by the cmdlet's `[ValidatePattern]`** - a one-character typo can no longer accidentally scope a fleet-wide write.

  The ADO `apply-updates.yml` lost its closed `values:` enum (it kept `type: string` so users still get a free-text editor in the ADO run dialog).

- **`ValidatePattern` tightened on 15 cmdlets.** The 14 cmdlets that take `-UpdateRingValue` and the 1 cmdlet that takes `-UpdateRingTag` (`Get-AzureLocalFleetHealthFailures`) now share the regex `^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$`. Each individual ring segment still has the same 1-64 character `[A-Za-z0-9_-]` policy as v0.7.65; the changes are (a) `;`-separated lists are now accepted, and (b) **only the exact three-character `***` token is accepted as a wildcard** (single/double/quad stars are rejected). Hostile/malformed inputs (spaces, embedded quotes, `<script>`, leading/trailing `;`) are still rejected at the parameter binder before any Azure call is made.

- **New private helper `ConvertTo-AzLocalUpdateRingKqlFilter`.** Centralises the KQL clause construction for the three forms above. Returns `| where isnotempty(tags['UpdateRing'])` for `***` (matches only tagged clusters), a `| where tags['UpdateRing'] =~ 'single'` clause for a single value, and a `| where tags['UpdateRing'] in~ ('a','b')` clause for a list. Embedded single quotes are doubled (KQL string-literal escape). The 10 ARG-query call sites and the 2 here-string KQL call sites (`Get-AzureLocalFleetHealthFailures`, `Reset-AzureLocalSideloadedTag`) all now go through this helper, eliminating 12 copies of nearly-identical interpolation logic.

- **Pester regression coverage** for every v0.7.66 feature: a new `Describe 'v0.7.66 UpdateRing ValidatePattern accepts list & wildcard forms'` that reflects on every cmdlet's `ValidatePatternAttribute` and asserts both the acceptance set (`Wave1`, `Prod;Ring2`, `***`, ...) **and the rejection set including the easy-to-mistype `*` / `**` / `****` / `*Wave1` variants**, plus the existing hostile inputs (`Foo bar`, `abc'def`, `<script>`, empty, leading/trailing `;`); a `Describe 'v0.7.66 ConvertTo-AzLocalUpdateRingKqlFilter helper'` exercising every branch including the new `***` -> `isnotempty(...)` path (both default `tags['UpdateRing']` and `tostring(tags['UpdateRing'])` accessors); a `Describe 'v0.7.66 Artifact download names carry a UTC timestamp suffix'` that scans every `Automation-Pipeline-Examples/**/*.yml` and fails if any upload step is missing the `azlocal-` prefix or the `<timestamp>` token (plus four guards against the legacy non-stamped names regressing); a `Describe 'v0.7.66 Fleet Update Status summary uses status emojis and groups failures first'` that asserts the U+2705 and U+274C glyphs are present and that the legacy `[ok]/[fail]` markers are gone, that the `_(generated $generatedUtc)_` heading is present, and that the `$failedClusters` / `$passedClusters` / `$orderedClusters` bucketing tokens all appear; and a `Describe 'v0.7.66 Pipeline update_ring inputs document multi-value and wildcard support'` that asserts every input description mentions both `Prod;Ring2` and `'***'`.

### Pipeline migration

If you have copied any of the bundled workflows into your repo, refresh them via:

```powershell
Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub      -Update
Copy-AzureLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps -Update
```

## [0.7.65] - 2026-05-17

### Added

- **New function `Get-AzureLocalFleetHealthFailures`** - queries Azure Resource Graph for every cluster the caller can read and surfaces the 24-hour system health-check entries with `status == 'Failed'`. Two views are supported: `-View Detail` returns one row per (cluster, failing check) and `-View Summary` aggregates by failure reason so administrators can see "what should I fix first?" at a fleet-wide level. `-Severity` filters at the ARG side to `Critical`, `Warning`, or `All` (Informational entries are always excluded). `-UpdateRingTag` narrows the report to a specific wave. The function reuses the module's existing `Invoke-AzResourceGraphQuery` helper for paginated CLI shell-out and inherits the same skip-token / error-scrubbing behaviour as every other fleet-wide query in the module. The 24-hour health checks run on Azure Local clusters independently of update activity, which means clusters that are already "up to date" can still surface Critical or Warning issues that need triage - this function is the dedicated entry point for that workflow.

- **New "Fleet Health Status" pipeline samples** (`Automation-Pipeline-Examples/github-actions/fleet-health-status.yml` and `Automation-Pipeline-Examples/azure-devops/fleet-health-status.yml`). The GitHub Actions variant runs daily at 07:00 UTC (offset from `fleet-update-status` at 06:00) and the ADO variant uses the same schedule. Both pipelines call `Get-AzureLocalFleetHealthFailures -View Detail` once, aggregate the summary in-process, and emit:
  - A markdown step summary (top failure reasons pivoted by cluster impact + a per-cluster "Detailed Results" table mirroring the data shown in the "24 Hour System Health Checks - Detailed Results" view).
  - JUnit XML (`fleet-health-status.xml`) with one `<testcase>` per (cluster, failing check) grouped under `Critical Health Failures` / `Warning Health Failures` testsuites for two-level drill-down in dorny/test-reporter (GitHub) and PublishTestResults@2 (Azure DevOps).
  - CSV exports (`fleet-health-detail.csv`, `fleet-health-summary.csv`) for spreadsheet workflows and ITSM hand-off.
  Together with `fleet-update-status.yml`, administrators now have two dedicated pipelines: one for "is each cluster up-to-date" (Update Status) and one for "do clusters have actionable health issues even when up-to-date" (Health Status).

- **New Pester guardrail: pipeline YAML version pin matches the module manifest.** A new `Context 'Pipeline YAML version pin (v0.7.65)'` test in `Tests/AzLocal.UpdateManagement.Tests.ps1` discovers every `*.yml` file under `Automation-Pipeline-Examples/` that installs `AzLocal.UpdateManagement` from PSGallery and asserts that the `GENERATED_AGAINST_MODULE_VERSION` constant in that YAML matches the manifest version. Supports both the inline GitHub Actions shape and the two-line Azure DevOps shape. This prevents the version-drift class of bug where the manifest is bumped but one or more sample YAMLs are forgotten.

- **`Automation-Pipeline-Examples/README.md` now documents the default triggers and schedules for all seven shipped pipelines.** A new "Default triggers and schedules (at a glance)" table at the top of Appendix A lists the GitHub Actions and Azure DevOps trigger / cron for every pipeline (`inventory-clusters`, `manage-updatering-tags`, `assess-update-readiness`, `apply-updates`, `fleet-update-status`, `fleet-health-status`, `apply-updates-schedule-audit`). Each of the per-pipeline appendix entries (A.1 - A.7) now also has a dedicated **Trigger** row. **A.6 (Fleet Health Status)** and **A.7 (Apply-Updates Schedule Coverage Audit)** are added in this release. **Apply Updates (A.4) and section 8 now include a mandatory-customisation callout**: the cluster `UpdateWindow` / `UpdateExclusions` tags only *gate* updates while the pipeline is already running; they do **not** start the pipeline. If `apply-updates.yml` is left with `workflow_dispatch` only (GH) / `trigger: none` (ADO) and you rely on `UpdateWindow` tags, no updates will ever be applied automatically. Section 8 includes worked GH / ADO cron examples for typical `UpdateWindow` values **and a new end-to-end runbook (section 8.3)** that walks operators through tag-a-ring -> see-drift -> copy-recommended-cron -> verify -> let-the-weekly-audit-catch-future-drift.

- **New function `Test-AzureLocalApplyUpdatesScheduleCoverage`** - read-only schedule-coverage advisor. Compares the cron schedule(s) declared in `apply-updates.yml` (GitHub Actions and/or Azure DevOps) to the `UpdateWindow` tag values present on the fleet and flags every `(UpdateRing, UpdateWindow)` pair that no cron will ever reach. Three views: `-View Audit` (one row per `(Ring, Window)` pair with `Covered` / `Uncovered` / `PartiallyCovered` / `MalformedTag` / `UnparseableCron` status + `Recommendation` column), `-View Matrix` (every distinct `(Ring, Window)` pair with its required cron), `-View Recommend` (ready-to-paste GH Actions + Azure DevOps cron blocks that cover every distinct `UpdateWindow` value in the fleet). Per-segment cron generation handles multi-window tag values (`Sat-Sun_02:00-06:00;Mon-Fri_22:00-04:00`), day ranges including wrap-around (`Fri-Mon`), and a configurable `-LeadTimeMinutes` (default 5, range 0-60) buffer so the cron fires before the window opens. Cron parser supports the 5-field standard (`M H DoM Month DoW`), single values, comma lists, day ranges, and `*` wildcards; rejects `/N` step values and complex DoM/Month patterns (returns `IsComplex=true`). Pipeline YAML pre-scan uses a regex (no `powershell-yaml` dependency) and infers `Platform` from the `github-actions/` / `azure-devops/` parent folder. Never edits cluster tags or pipeline YAML. Read-only RBAC: `Reader` on the cluster scope plus `Microsoft.ResourceGraph/resources/read`.

- **New "Apply-Updates Schedule Coverage Audit" pipeline samples** (`Automation-Pipeline-Examples/github-actions/apply-updates-schedule-audit.yml` and `Automation-Pipeline-Examples/azure-devops/apply-updates-schedule-audit.yml`). Both pipelines are scheduled weekly on Mondays at 05:00 UTC (`cron '0 5 * * 1'`) - deliberately before the daily `fleet-update-status` (06:00 UTC) and `fleet-health-status` (07:00 UTC) pipelines so drift annotations land at the top of the Monday-morning operator queue. Each run produces:
  - **JUnit XML** (`schedule-coverage-audit.xml`) with one `<testcase>` per `(UpdateRing, UpdateWindow)` pair - uncovered / partially covered / malformed pairs become `<failure>` so the Tests tab surfaces the regression.
  - **CSV exports** (`schedule-coverage-audit.csv`, `schedule-coverage-matrix.csv`) for spreadsheet / dashboard workflows.
  - **Markdown** (`schedule-coverage-recommend.md`) - ready-to-paste GH Actions + Azure DevOps cron blocks covering every distinct `UpdateWindow` in the fleet.
  - **Markdown step summary** with the headline counts, the audit detail (uncovered first), and the recommended cron block.

### Fixed

- **`Set-AzureLocalClusterUpdateRingTag` now uses the dedicated `Microsoft.Resources/tags/default` PATCH endpoint instead of `PATCH`-ing the cluster resource.** The previous code issued `PATCH https://management.azure.com/<clusterId>?api-version=2025-10-01` with `{ "tags": {...} }`, which Azure RBAC routes through the `microsoft.azurestackhci/clusters/write` action - i.e. full cluster Contributor. CI/CD service principals scoped to **Tag Contributor** (only `Microsoft.Resources/tags/*` actions) therefore failed with `AuthorizationFailed: action 'microsoft.azurestackhci/clusters/write'` even though they should have been able to write tags. The function now `PATCH`es `https://management.azure.com/<clusterId>/providers/Microsoft.Resources/tags/default?api-version=2021-04-01` with `{ "operation": "Merge", "properties": { "tags": { "UpdateRing": "..." } } }`, which Azure routes through `Microsoft.Resources/tags/write` only. The `Merge` operation preserves all other existing tags on the cluster without us having to re-send them. Aligns with the v0.7.62 fix that already moved internal tag writes (`Set-AzLocalClusterTagsMerge`) to the same endpoint.

- **"Fleet Update Status" pipeline summary now reconciles with the JUnit pass/fail counts.** Two related bugs in both `fleet-update-status.yml` samples (GitHub Actions and Azure DevOps) produced summary tables that did not add up to `Total Clusters`:
  1. `Up to Date` only counted `UpdateState -eq "UpToDate"` and missed clusters reporting the (equally healthy) `AppliedSuccessfully` state. Both states now count as "Up to Date".
  2. The bucket counters were not mutually exclusive and there was no catch-all, so a fleet of 12 healthy + 8 failed clusters could render as `Up to Date: 0`, `Health Failures: 8`, with the remaining 12 unaccounted for. Each cluster is now assigned to **exactly one** primary status using a priority cascade (`Update Failed` -> `Health Failure` -> `SBE Prerequisite Blocked` -> `Update In Progress` -> `Ready for Update` -> `Up to Date` -> `Needs Investigation`), so the rows always sum to `Total Clusters`.

### Changed

- **JUnit / step-summary ordering is now: Summary FIRST, Test Results SECOND.** Both `fleet-update-status.yml` and `fleet-health-status.yml` samples for GitHub Actions and Azure DevOps now create the markdown step summary before publishing the JUnit XML, so the run-extensions / job-summary view leads with the operator-facing numbers rather than the raw test list. The GitHub Actions dorny/test-reporter step now uses `list-suites: failed` + `list-tests: failed` so the published Test Reporter section is collapsed by default and only expands the failures.
- **Fleet Update Status failure message now reads "UpdateState: ..., Health: ..." (was "Health: ..., UpdateState: ...").** The Update Status is the primary signal for that pipeline, so it now leads in both the JUnit `<failure>` message and the markdown summary.
- **`Set-AzureLocalClusterUpdateRingTag` help and the Automation-Pipeline-Examples RBAC guidance now both recommend the built-in `Tag Contributor` role for tag-management automation.** If you scoped your tag-management SP to "Contributor" purely to work around the old write-the-whole-cluster behaviour, you can now safely scope it to **Tag Contributor** on the cluster (or the resource group).

### Module-version pin bumped to 0.7.65 in all 13 sample workflow YAMLs (10 pre-existing + 3 new in v0.7.65)

Refresh your copy via:

```powershell
Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub      -Update
Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update
```

## [0.7.64] - 2026-05-17

### Fixed (critical)

- **Pipeline-sample YAMLs (10 files across GitHub Actions and Azure DevOps) had accumulated cp1252 mojibake from previous emoji-edit round-trips.** One of the multi-byte sequences in `manage-updatering-tags.yml` contained a YAML 1.2 forbidden C1 control character (U+008F), which caused GitHub Actions to reject the workflow at recent commits with **`Invalid workflow file`** / generic YAML syntax error and the affected step never ran. The root cause was UTF-8 emoji bytes (e.g. `F0 9F 93 84` = `[document]`) being misread as cp1252 by a previous editor session, then re-saved as UTF-8 - producing `C3 B0 C2 9F C2 93 C2 84`, which contains `C2 8F` -> U+008F. YAML 1.2 disallows raw C1 control characters U+0080-U+009F (except U+0085 NEL) in scalar content. **All non-ASCII bytes have been stripped from every sample workflow** (`[^\x09\x0A\x0D\x20-\x7E]`), the affected Markdown step-summary sections restored with plain-ASCII status labels (`[info]`, `[ok]`, `[running]`, `[ready]`, `[blocked]`, `[fail]`), and the YAMLs verified to round-trip cleanly through the GitHub Actions and Azure DevOps validators. No module code paths are affected; only the sample YAMLs.

### Security hardening (Medium)

- **`Connect-AzureLocalServicePrincipal` now scrubs `$loginResult` through `ConvertTo-ScrubbedCliOutput` before writing the failure message to `Write-Error`.** A stray `refresh_token` / `access_token` / cookie that the `az` CLI might emit on a failed `az login --service-principal` call can no longer reach the host logs verbatim.
- **Six additional direct callers of `az rest` / `az account set` now route raw CLI output through `ConvertTo-ScrubbedCliOutput` before logging/throwing.** Sites: `Set-AzLocalClusterTagsMerge` (3), `Invoke-AzLocalSideloadedAutoResetForCluster`, `Invoke-AzureLocalUpdateApply`, `Set-AzureLocalClusterUpdateRingTag`, `Start-AzureLocalClusterUpdate` (subscription-set and validate). This closes the same Bearer-token leak class that was already handled inside `Invoke-AzRestJson` / `Invoke-AzResourceGraphQuery` but missed by the direct `az rest` call sites.
- **Documentation: `README.md` and [`ITSM/README.md`](ITSM/README.md) now carry explicit security notes about** (a) the `az login --service-principal --password <secret>` command-line exposure on the SP+secret authentication path (visible to `Win32_Process.CommandLine` for the duration of the call), and (b) the unavoidable plaintext `[string]` residency of ITSM secrets in memory during ServiceNow OAuth `client_credentials` grants (the ServiceNow REST surface requires plaintext POST bodies, so `[SecureString]` round-tripping is impossible at this layer).

### Fixed (Low)

- **`Invoke-AzureLocalUpdateApply` previously evaluated `$result -match "202"` against the `string[]` returned by `az rest`**, which is array-filter semantics, not regex-match semantics: the test was returning the matching array elements (truthy) rather than the boolean intended. The comparison is now done against `($result | Out-String).Trim()` and combined into a single regex (`202|Accepted`); the `Write-Verbose` path is also scrubbed.
- **`Invoke-AzLocalItsmHttp` `throw` on non-retryable HTTP failure now uses `$redactedUri` instead of `$Uri`.** The redaction (`(client_secret|access_token|password)=[^&]+` -> `$1=***`) was already applied to the `Write-Verbose` log line; the `throw` message bypassed it. With this fix, a non-retryable 4xx response from ServiceNow can no longer surface a secret-bearing query string into the exception chain.
- **Two Pester tests (`ScheduleBlocked` and `SideloadedBlocked` JUnit XML coverage) wrote to fixed temp filenames** (`pester-junit-schedule-test.xml`, `pester-junit-sideloaded-test.xml`) that would collide if the test suite is run in parallel or back-to-back. Filenames now append a per-invocation `[Guid]::NewGuid()`.

### Module-version pin bumped to 0.7.64 in all 10 sample workflow YAMLs

Refresh your copy via:

```powershell
Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub      -Update
Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update
```

## [0.7.63] - 2026-05-16

### Fixed (critical)

- **`fleet-update-status.yml` (both [GitHub Actions](Automation-Pipeline-Examples/github-actions/fleet-update-status.yml) and [Azure DevOps](Automation-Pipeline-Examples/azure-devops/fleet-update-status.yml) samples) failed on the *Create Status Summary* step under PowerShell 7** with `ParserError: The Unicode escape sequence is not valid. A valid sequence is \`u{ followed by one to six hex digits and a closing '}'`. GitHub-hosted Windows runners default to `pwsh` 7 for `shell:` in `run:` steps, so the YAMLs render on PS 7 even though the module itself targets PS 5.1+. Inside the PS double-quoted here-string that builds the Markdown step summary, Markdown code-span backticks before file names like `` `update-summaries.csv` `` and `` `update-runs.csv` `` were interpreted by the PS 7 parser as the new `` `u{xxxx} `` Unicode escape (added in PS 6.2, which expects `{` immediately after `` `u ``). PS 5.1 had silently consumed the backtick; PS 7 hard-errors. Latent corruption also affected `` `readiness-status.csv` `` (`` `r `` -> carriage return), `` `available-updates.csv` `` (`` `a `` -> BEL `0x07`), and `` `cluster-inventory.csv` `` (`` `c `` -> backtick dropped) - producing rendered job summaries with stray control characters and missing code-span formatting even on PS 5.1. All Markdown code-span backticks in the affected here-strings have been doubled (`` `` `` ); under both PS 5.1 and PS 7, two consecutive backticks in a double-quoted string is documented to produce exactly one literal backtick, and Markdown renders single and doubled-backtick code spans identically. The fix is portable across both shell versions and matches the pre-existing doubled-backtick pattern already in use on the same files (e.g. for `` `available-updates.csv` `` in the GH Actions readiness section). No module code paths are affected; only the pipeline-sample YAMLs.

### Pipeline migration

If you have copied `fleet-update-status.yml` into your repo, refresh both sample files via:

```powershell
Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub      -Update
Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update
```

## [0.7.62] - 2026-05-15

### Fixed (critical)

- **`Start-AzureLocalClusterUpdate` Step 3b critical-health gate was being silently bypassed.** The caller invoked [`Test-AzureLocalClusterHealth`](Public/Test-AzureLocalClusterHealth.ps1) without `-PassThru`; without that switch the function writes all output via `Write-Log` to the host stream and returns `$null`, so the predicate `$healthResults[0].CriticalCount -gt 0` always evaluated false even when the function had just logged `BLOCKED (N critical)`. Apply would then write *"No critical health issues found - cluster is eligible for update"* and proceed to PATCH the update despite critical health failures. Two additional call sites in [`Get-AzureLocalUpdateRuns`](Public/Get-AzureLocalUpdateRuns.ps1) (failed-run health detail and affected-cluster health detail) had the same omission. All three now pass `-PassThru`.
- **[`Set-AzLocalClusterTagsMerge`](Private/Set-AzLocalClusterTagsMerge.ps1) rewritten to use the ARM tags subresource** (`PATCH .../providers/Microsoft.Resources/tags/default?api-version=2021-04-01`) instead of patching the full cluster resource. This narrows the required RBAC from `microsoft.azurestackhci/clusters/write` to `Microsoft.Resources/tags/write` (the built-in **Tag Contributor** role), matching the documented behaviour. The function emits up to 2 PATCHes per call: one with `operation=Merge` for keys being set, one with `operation=Delete` for keys whose input value is `$null`. Idempotent: skips keys whose value already matches and Delete keys that are not present.
- **`Export-ResultsToJUnitXml` Status mapping fixed.** Status values `NotReady`, `NotConnected`, `NoUpdatesAvailable`, and `NoReadyUpdates` previously fell through to `<system-out>` (rendered as passed in `dorny/test-reporter`), producing misleading "all green" CI summaries when apply had actually skipped clusters. They now render as `<skipped>`. `UpdateNotFound` now renders as `<error type="UpdateNotFound">` instead of `<system-out>`. The summary `<testsuite tests/failures/errors/skipped/>` counts and the per-testcase element now agree.
- **[`Get-HealthCheckFailureSummary`](Private/Get-HealthCheckFailureSummary.ps1) now sorts `Critical`-severity entries ahead of `Warning` before applying the top-5 truncation.** This private helper feeds both the `HealthCheckFailures` column of the readiness CSV and the readiness gate's `-match '\[Critical\]'` check inside [`Get-AzureLocalClusterUpdateReadiness`](Public/Get-AzureLocalClusterUpdateReadiness.ps1) and [`Get-AzureLocalFleetStatusData`](Public/Get-AzureLocalFleetStatusData.ps1). Prior to this fix the function appended failures in the order ARM returned them and then truncated to the first 5; a cluster that returned 5 or more `Warning`-severity failures before a `Critical` one would have its `Critical` entry dropped during truncation, and the readiness gate would silently fail to downgrade `ReadyForUpdate`. The function now buckets by severity and concatenates `Critical`-first then `Warning`, preserving insertion order within each bucket. `Informational` entries continue to be excluded entirely (they never block updates - only `Critical` does, and `Warning` is included in the summary for operator visibility). Net effect: the readiness gate is reliable regardless of ARM's ordering, and the `HealthCheckFailures` column always shows the highest-priority entries first.

### Changed

- **`apply-updates` pipeline samples (GitHub Actions + Azure DevOps) now consume the readiness CSV** from the `check-readiness` job instead of re-discovering clusters by `UpdateRing` tag. The apply step downloads the `readiness-report` artifact, filters rows where `ReadyForUpdate=True`, and invokes `Start-AzureLocalClusterUpdate -ClusterResourceIds @(...)` against that exact list. Apply still re-validates each cluster (Step 1b connectivity, Step 3b health, Step 3c schedule, Step 3b1 sideloaded) as defence in depth. This guarantees the readiness gate's decision is **enforced** rather than advisory: a cluster flagged Blocked in readiness will not be touched by apply even if its tag still matches the ring.
- **`Get-AzureLocalClusterUpdateReadiness` output (and the readiness CSV) gains a `ClusterResourceId` column** containing the full ARM resource ID, so the apply step can pass it straight to `Start-AzureLocalClusterUpdate -ClusterResourceIds` without a second Resource Graph query. Populated on every row, including `NotFound`/`Error` rows (set from the input cluster's `ResourceId` where known).

### Pipeline migration

If you have copied `apply-updates.yml` into your repo, refresh both sample files via:

```powershell
Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub     -Update
Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update
```

The pipeline install step's drift detector will also emit a `::notice`/warning log pointing at this once you bump `REQUIRED_MODULE_VERSION` to `0.7.62`.

## [0.7.61] - 2026-05-15

### Changed

- **Readiness assessment now applies two new gates that downgrade `ReadyForUpdate` to `False` even when Azure Resource Manager (ARM) reports a Ready update for the cluster.** Both [`Get-AzureLocalClusterUpdateReadiness`](Public/Get-AzureLocalClusterUpdateReadiness.ps1) and [`Get-AzureLocalFleetStatusData`](Public/Get-AzureLocalFleetStatusData.ps1) (used by `New-AzureLocalFleetStatusHtmlReport`) now block readiness when either of these is true:
  - **Connectivity:** `ClusterState` is not `'ConnectedRecently'` (e.g. `NotConnectedRecently`, `Disconnected`). ARM cannot reliably push an update to a cluster it has not heard from recently.
  - **Critical health:** `HealthCheckFailures` contains at least one `[Critical]` severity entry. Critical-severity health checks must be cleared before any solution upgrade is started.

  A new **`BlockingReasons`** column on the readiness CSV lists the gate(s) that triggered the downgrade. Values are semicolon-joined - for example `CriticalHealthCheck` or `CriticalHealthCheck; NotConnectedRecently`. Clusters that pass both gates have an empty `BlockingReasons` value, exactly as in v0.7.60.

  The per-cluster console output now shows **`Blocked (<reasons>)`** in red for any cluster held back by these gates, and the summary footer now reports **`Blocked by Readiness Gate: N`** alongside the existing `Blocked by SBE Prereq` count.

- **`Start-AzureLocalClusterUpdate` gains a defence-in-depth connectivity gate (`Step 1b`).** Immediately after cluster lookup, clusters whose `properties.status` is not `'ConnectedRecently'` are skipped before any update is attempted. The cluster is recorded in `Update_Skipped.csv` with the message *"Update not started - cluster status is '\<status\>' (ARM cannot reach the cluster)"*, and the in-process `$results` collection gets a `Status='NotConnected'` row. Complements the existing `Step 3b` critical-health gate.

### Fixed

- **JUnit XML export from `Get-AzureLocalClusterUpdateReadiness` was emitting `Status='Skipped'` for every Ready cluster** due to a long-standing boolean-vs-string comparison bug at the JUnit transform step: `$_.ReadyForUpdate -eq 'Yes'` was tested against the `[bool]` value `$true`, which is always `$false`. JUnit `Status` now correctly reports `'Ready'`, `'Blocked'`, `'Failed'`, or `'Skipped'`. The CSV `ReadyForUpdate` column (a real `[bool]`) was unaffected; only the JUnit XML readability of CI/CD test summaries was wrong.

## [0.7.60] - 2026-05-15

### Changed

- **GitHub Actions sample workflows refreshed for Node 24.** All five workflow YAMLs under [`Automation-Pipeline-Examples/github-actions/`](Automation-Pipeline-Examples/github-actions) now pin Node 24-compatible major versions of the third-party actions they use. This removes the "Node.js 20 actions are deprecated" warning banner that started appearing on `workflow_dispatch` runs after the GitHub Actions runner began surfacing the upcoming September 16 2026 Node.js 20 hard-removal. No input/output surface changes for any of the bumped actions, so refreshed pipelines continue to work without any other edits:
  - `actions/checkout` &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`@v4` -> `@v5` &nbsp;(Node 24 default since v5.0.0, released Aug 2025)
  - `actions/upload-artifact` &nbsp;`@v4` -> `@v6` &nbsp;(v6 = Node 24 default; v5 still defaulted to Node 20)
  - `azure/login` &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`@v2` -> `@v3` &nbsp;(v3.0.0 = Node 24)
  - `dorny/test-reporter` &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`@v1` -> `@v3` &nbsp;(v3 = Node 24)

  Already-deployed pipelines will continue working on the older majors until the Sept 16 2026 hard-removal date. Running `Copy-AzureLocalPipelineExample -Update` after upgrading to v0.7.60 pulls the refreshed YAMLs into your existing `.github\workflows\` folder.

### Fixed

- **`apply-updates.yml` (GitHub Actions sample): `dorny/test-reporter` could not publish Check Run results on `workflow_dispatch` runs.** Both jobs (`check-readiness` and `apply-updates`) only granted `id-token: write` + `contents: read` in their `permissions:` block, missing the `checks: write` permission that `dorny/test-reporter@v3` (and earlier) needs to create the Check Run that publishes JUnit results. Symptom: the test-reporter step failed with `HttpError: Resource not accessible by integration` (HTTP 403) on every run triggered by `workflow_dispatch`, because `workflow_dispatch` contexts have no PR check-run context to write back to by default. The run itself was unaffected - the readiness assessment and any subsequent apply still completed - this only restored the Check Run summary surface so the JUnit XML actually shows up in the GitHub UI. Sibling workflows (`assess-update-readiness.yml`, `fleet-update-status.yml`) already declared `checks: write` from v0.7.50; only `apply-updates.yml` was missing the permission. Refresh via `Copy-AzureLocalPipelineExample -Update -Platform GitHub` after upgrading.

## [0.7.50] - 2026-05-15

### Added

- **`Copy-AzureLocalItsmSample` (new convenience function)**: copies the bundled ITSM connector sample (`azurelocal-itsm.yml` + `templates/incident-body.md`) out of the module install location into a user-chosen destination. Default `-Destination` is `.\.itsm` - the exact relative path that both `apply-updates.yml` workflows default `itsm_config_path` / `itsmConfigPath` to (resolved relative to the repo root at job runtime). Same overwrite semantics as `Copy-AzureLocalPipelineExample`: refuses to overwrite by default, `-Update` opts into per-file `ShouldContinue` prompts (`Y` / `A` / `N` / `L` / `S` / `?`) with `Yes-to-All` / `No-to-All` flags that survive across iterations, `-Confirm:$false` bypasses the prompts for unattended use, `-WhatIf` overrides everything and only prints what would change, `-PassThru` returns the destination `[DirectoryInfo]`. Closes the gap where running `Copy-AzureLocalPipelineExample -Platform GitHub` (or `-Platform AzureDevOps`) deliberately did not bring the `.itsm/` sample along - the two functions now compose for a one-paragraph setup: pipelines into `.github\workflows\` (or your `pipelines/` folder), ITSM sample into `.itsm\`. The ITSM YAML itself is CI-platform-agnostic; both GitHub Actions and Azure DevOps consume it identically, only the secret source differs (repo / environment secrets vs. variable group).

### Changed

- **`Copy-AzureLocalPipelineExample` - simpler, safer copy semantics.** First real-world run of the v0.7.4 surface revealed two issues with the GitHub Actions path: (1) `-Platform GitHub -Flatten` left an intermediate `github-actions\` subfolder, so workflows landed at `.github\workflows\github-actions\*.yml` where the GitHub Actions runner cannot see them (the runner only scans `.github/workflows/*.yml`, non-recursively); (2) the `-Force` flag's directory-level pre-flight refused to copy whenever `.github\workflows\` contained any unrelated user workflow, effectively making `-Force` mandatory and meaningless. Both flags have been removed and the function reshaped around the user's actual intent:
  - `-Platform GitHub` now copies ONLY the `*.yml` workflow files from the source `github-actions/` folder directly into `-Destination` (flat - no wrapper folder, no README, no `.itsm/`). The canonical call is `Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub`.
  - `-Platform AzureDevOps` behaves the same way against the source `azure-devops/` folder (flat into `-Destination`, no README, no `.itsm/`).
  - `-Platform All` (the default) is unchanged - copies the full source tree under a `.\Automation-Pipeline-Examples\` child folder for browsing.
  - **Controlled refresh via `-Update`** (new in v0.7.50): the function still refuses to overwrite by default and lists every conflict in the error message - but the error now points at the `-Update` switch instead of asking the user to `Remove-Item` first. With `-Update` the function emits a per-file `ShouldContinue` prompt (`Y` / `A` / `N` / `L` / `S` / `?`) before each overwrite; `Yes-to-All` and `No-to-All` survive across iterations. Pair with `-Confirm:$false` to suppress the prompts entirely (the documented automation / CI bypass). `-WhatIf` overrides everything and only prints what would change. Pipeline files are expected to live under git source control so `git diff` is the second safety net after `ShouldContinue`. There is **deliberately no `-Force`**: that flag's previous semantics were too broad and it had been removed mid-v0.7.50 development - `-Update` is the narrower, more explicit replacement.
  - Pre-existing unrelated files in `-Destination` (e.g. your repo's own `build.yml`, `codeql.yml`) are now left untouched; the function only writes the files it is bringing over from the source tree.
  - **Next-steps output** is now platform-aware and detects when `-Destination` is already `.github\workflows\` ("you're done, commit and push") vs. somewhere else ("move the YAMLs into `.github\workflows\`"). For both platform-specific values the output now points at `auth-smoke-test.yml` as the recommended first run (see sections 5.1 and 5.2 of the Automation-Pipeline-Examples README) so the user validates the auth chain before wiring the other five workflows.

  Note: this is **not** marked as a breaking change because the v0.7.4 surface had not been adopted by any consumer at the time of removal (the feature shipped on 2026-05-13 and was found broken on first real-world use).

## [0.7.41] - 2026-05-13

### Fixed

- **HIGH**: every fleet read function dispatched through `Invoke-FleetJobsInParallel` (`Get-AzureLocalUpdateRuns`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalClusterUpdateReadiness`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalFleetProgress`, `Invoke-AzureLocalFleetOperation`, `Test-AzureLocalClusterHealth`, `Start-AzureLocalClusterUpdate`'s parallel path) failed for every cluster when invoked with `-ThrottleLimit` greater than 1 against the PSGallery-installed module, returning `State = Error` with the message: *"Cannot use '&' to invoke in the context of module 'Invoke-FleetJobsInParallel' because it is not imported. Import the module 'Invoke-FleetJobsInParallel' and try the operation again."* Inline (`-ThrottleLimit 1`) execution was unaffected. Root cause: the v0.7.3 refactor that split the monolithic `.psm1` into `NestedModules` changed the meaning of `$PSCommandPath` inside `Invoke-FleetJobsInParallel.ps1`. It now resolves to the helper's own `.ps1` file (because it is loaded as a nested module), not to the root `AzLocal.UpdateManagement.psd1`. The helper was passing that nested-helper path to each per-batch `Start-Job` scriptblock as `$ModulePath`; the scriptblocks then ran `Import-Module $ModulePath -Force -PassThru` in the fresh child runspace, which loaded only the single `.ps1` file as a transient module named `Invoke-FleetJobsInParallel`. Every subsequent `& $mod { Get-AzLocalClusterUpdateRuns ... }` resolved against that transient module's session state, which contained none of the private helpers. Reported against a 9-cluster Prod fleet immediately after installing v0.7.4 from PSGallery; reproduces 100% on `-ThrottleLimit 10` and on the default `-ThrottleLimit 4` once the cluster count exceeds the throttle.
- **HIGH**: `New-AzureLocalFleetStatusHtmlReport -ThrottleLimit` greater than 1 (which routes through `Get-AzureLocalFleetStatusData`) threw at start-up: *"Parallel collection requires module path 'C:\Program Files\WindowsPowerShell\Modules\AzLocal.UpdateManagement\\<ver\>\Public\AzLocal.UpdateManagement.psm1' to be reachable by background jobs, but it does not exist."* Same regression class as the `Invoke-FleetJobsInParallel` bug but a separate code path: `Get-AzureLocalFleetStatusData` computes the module path itself for its inline `Start-Job` dispatcher and was using `Join-Path -Path $PSScriptRoot -ChildPath 'AzLocal.UpdateManagement.psm1'`. After v0.7.3, `$PSScriptRoot` resolves to the `Public/` subfolder, not the module root, so the computed path was one level too deep on PSGallery-installed layouts. `New-AzureLocalFleetStatusHtmlReport`'s manifest-fallback footer had the same flaw.
- **Centralised** module-root manifest resolution in a new private helper [`Private/Get-AzLocalModuleRootManifestPath.ps1`](AzLocal.UpdateManagement/Private/Get-AzLocalModuleRootManifestPath.ps1) so we have ONE place that knows the post-v0.7.3 layout. The helper prefers the loaded module's `.Path` (preferring `.psd1` over `.psm1`) and falls back to walking up from the caller's `$PSCommandPath`, so it is correct from any `Public/` or `Private/` file. `Invoke-FleetJobsInParallel`, `Get-AzureLocalFleetStatusData`, and `New-AzureLocalFleetStatusHtmlReport` all delegate to it. Future `Public/`/`Private/` additions won't reintroduce the same "`$PSScriptRoot` is module root" assumption.
- Added a Pester regression test (`Should pass the root module manifest path (not the helper .ps1) as the trailing ModulePath argument`) under `Internal Helper: Invoke-FleetJobsInParallel`. Existing tests only exercised the inline `-ThrottleLimit 1` fast-path, which never touched the broken Start-Job code path and so silently masked the regression in v0.7.4.

## [0.7.4] - 2026-05-13

### Added

- **ITSM Connector - Phase 1 (ServiceNow).** New optional ticketing surface that lets `apply-updates` and `fleet-update-status` pipelines open ServiceNow incidents when a cluster needs operator action that the module's own retries cannot resolve. Disabled by default; opt-in via the pipeline input `raise_itsm_ticket=true` plus a `./.itsm/azurelocal-itsm.yml` config file. Setup walkthrough in `ITSM/README.md`; full design captured in `ITSM/ITSM-Connector-Plan.md`.
- **New public functions** (Phase 1):
  - `Get-AzureLocalItsmConfig` - loads and validates the YAML/JSON trigger matrix; returns a strongly typed config object so pipelines can fail-fast on misconfiguration before any HTTP call.
  - `Test-AzureLocalItsmConnection` - dry-run probe of the configured ITSM endpoint and any enabled notification adapters; verifies auth, custom-field presence, and rate-limit headroom.
  - `New-AzureLocalIncident` - consumes a JUnit results file (and optional readiness CSV), evaluates each cluster row against the trigger matrix, opens or de-duplicates ServiceNow incidents via SHA256 of `{ClusterResourceId}|{UpdateName}|{TriggerCategory}`, and returns one row per cluster considered with `Action`, `TicketId`, `TicketUrl`, `Severity`.
- **New internal helpers**: `Resolve-AzLocalItsmSecret` (Key Vault first, `env://` fallback), `Get-AzLocalItsmDedupeKey`, `Get-AzLocalItsmTriggerDecision`, `Format-AzLocalIncidentBody` (Mustache-style template rendering with HTML-escape), `Invoke-AzLocalItsmHttp` (TLS 1.2+, `Retry-After` honour, exponential backoff capped at 3 attempts), `Invoke-AzLocalServiceNowAdapter` (OAuth 2.0 client credentials, token cache, dedupe GET, POST incident, attach file).
- **New documentation**: top-level `ITSM/` folder with a setup-and-configure `README.md` landing page (Key Vault prep, ServiceNow OAuth app, custom fields, secret references, dry-run, troubleshooting), `ITSM/ITSM-Config-Reference.md` (full schema reference with every field documented), and `Automation-Pipeline-Examples/.itsm/azurelocal-itsm.yml` working example config plus `templates/incident-body.md` ticket-body template.
- Phase 2 (`Sync-AzureLocalIncident` lifecycle close-out) and Phase 3 (Teams / Slack mirror adapters) are **deferred to a future release**; the Phase 1 surface is feature-complete on its own and ships ServiceNow-only as planned. The full three-phase design remains documented in `ITSM/ITSM-Connector-Plan.md` for forward reference.
- **`Copy-AzureLocalPipelineExample` (convenience function)**: copies the bundled `Automation-Pipeline-Examples/` folder out of the module install location into a user-chosen destination (default: `$PWD`). Supports `-Platform GitHub | AzureDevOps | All`, `-Flatten` (drop contents into the destination directly, no parent folder), `-Force` (overwrite existing files), `-PassThru` (return the destination `[DirectoryInfo]`), `-WhatIf` and `-Confirm`. Always prints a short "next steps" summary pointing at the copied README and the platform-specific YAML location. Saves users from hunting through `$module.ModuleBase` for the YAML samples after `Install-Module`.

### Security

- All ITSM credentials referenced through Azure Key Vault (`kv://<vault>/<secret>`, recommended) or native CI secrets (`env://<NAME>`, fallback). No raw secret is ever written to YAML or to disk. Pipeline service principal needs `Key Vault Secrets User` on the configured vault; no other new RBAC.
- All free-text fields (cluster names, tag values, error summaries) are HTML-escaped when rendered into ticket descriptions to defend against ITSM-side HTML injection. CSV-injection sanitisation on inputs is unchanged (already present from v0.7.0).

## [0.7.3] - 2026-05-13

### Renamed

- **Module renamed from `AzStackHci.ManageUpdates` to `AzLocal.UpdateManagement`** to align with the Azure Local product name (Microsoft retired the `Azure Stack HCI` brand in late 2024). The module **GUID is preserved** across the rename so PowerShell tooling still sees this as the same module identity.
  - **Migration command for existing users**:
    ```powershell
    Uninstall-Module AzStackHci.ManageUpdates -AllVersions
    Install-Module AzLocal.UpdateManagement
    ```
  - **PSGallery**: all `AzStackHci.ManageUpdates` versions (≤ 0.7.2) have been **unlisted**. A transitional `AzStackHci.ManageUpdates` v0.7.3 stub is published once for users who have automation that runs `Install-Module AzStackHci.ManageUpdates`; importing it emits a `Write-Warning` pointing to the new name and exports no functions.
  - **Default log folder**: `C:\ProgramData\AzStackHci.ManageUpdates\` -> `C:\ProgramData\AzLocal.UpdateManagement\`. The old folder is not migrated; remove it manually after upgrading if desired.
  - **Repository folder**: `AzStackHci.ManageUpdates/` -> `AzLocal.UpdateManagement/`. Pipeline YAML examples (`apply-updates.yml`, `assess-update-readiness.yml`, `fleet-update-status.yml`, `inventory-clusters.yml`, `manage-updatering-tags.yml`) and all `Import-Module` paths updated.
  - **Tests / `InModuleScope`**: every `InModuleScope AzStackHci.ManageUpdates { ... }` and `Get-Module AzStackHci.ManageUpdates` reference updated to the new name.
  - **`u_azlocal_source` ITSM custom field default**: changed from `AzStackHci.ManageUpdates` to `AzLocal.UpdateManagement` in the ITSM Connector design doc (no runtime effect yet; ITSM connector lands in v0.7.4).

### Refactored (carried forward from the in-development branch, included here)

- The monolithic 11,679-line `.psm1` is split into Public/Private dot-sourced files, matching the layout of `AzLocal.DeploymentAutomation` in this repo. 20 exported functions live under `Public/`, 40 internal helpers under `Private/`. The manifest enumerates every file in `NestedModules` (Private first, then Public, alphabetical within each). No functional change; the full Pester suite (299 tests) remains green.
- 22 inter-function `$script:*` declarations that were declared between function definitions in the monolithic file (`UpdateWindowTagName`, `UpdateExclusionsTagName`, `UpdateSideloadedTagName`, `UpdateVersionInProgressTagName`, `DayMap`, `DayAbbreviations`, `FleetOperationState`) are now hoisted into the `.psm1` prologue with a banner comment. They must initialise before any function body that references them; this is enforced by the manifest's `NestedModules` load order.
- `Tools/Split-AzStackHciModule.ps1` is retained verbatim as a historical audit artefact of the refactor. The script is not runnable against the renamed layout and is kept only for reference.

## [0.7.2] - 2026-05-05

### Fixed

- **`Get-AzureLocalUpdateRuns` / `Get-AzureLocalUpdateSummary` / `Get-AzureLocalClusterUpdateReadiness` failed for every cluster when run with `-ThrottleLimit` greater than 1.** The per-cluster scriptblock dispatched via `Start-Job` called module-private helpers (`Invoke-AzRestJson`, `Get-AzLocalClusterUpdateRuns`, `Format-AzLocalUpdateRun`, `Get-LatestUpdateByYYMM`, `ConvertTo-AzLocalAdditionalProperties`, `Get-HealthCheckFailureSummary`, `Get-TagValue`) by name. Because those helpers are filtered out by `Export-ModuleMember`, after `Import-Module` in the child runspace they were not visible at script command-resolution scope, so every cluster reported `The term 'Get-AzLocalClusterUpdateRuns' is not recognized...` (or the equivalent for the other helpers). Inline (`-ThrottleLimit 1`) execution was unaffected because that path runs inside the parent module's session state. Fix: each affected scriptblock now captures a reference to the loaded module (using `Import-Module -PassThru` when not already loaded) and either invokes the helper via `& $module { ... }` or rebinds the helper's bound scriptblock into the local function scope, so calls execute against the module's own session state and resolve all transitive private references. Reported against a 9-cluster Prod fleet.
- **cp1252 encoding warnings leaking into JSON parsing on inline (`-ThrottleLimit 1`) path.** On Windows hosts where the console code page is `cp1252` (the English-US default), `az rest` and `az graph query` emitted `WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.` whenever ARM responses contained non-cp1252 characters (smart quotes, accented cluster tags, localised health-check messages, etc.). Captured via `2>&1`, that warning was being prepended to the JSON body and breaking `ConvertFrom-Json`, silently dropping update runs and available updates for affected clusters. `Invoke-AzRestJson` set `$env:PYTHONIOENCODING = 'utf-8'` transiently per-call (v0.7.0+), but this is structurally ineffective: `az.cmd` launches Python with the `-I` (isolated) flag, which implies `-E` and so causes Python to ignore all `PYTHON*` environment variables - confirmed in [Azure/azure-cli#28497](https://github.com/Azure/azure-cli/issues/28497). The actual fix is to pass `--only-show-errors` to every `az rest` and `az graph query` invocation (Azure CLI maintainer's recommended workaround per [Azure/azure-cli#14426](https://github.com/Azure/azure-cli/issues/14426)); this suppresses the encode warning at source. Applied to: `Invoke-AzRestJson`, `Invoke-AzResourceGraphQuery`, the resource-validation `az rest GET` call in cluster-resolution, the apply `az rest POST` call in `Start-AzureLocalClusterUpdate`, and all four direct `az rest` calls in `Set-AzLocalClusterTagsMerge` / sideloaded-tag reset paths. The module-load `PYTHONIOENCODING` assignment is retained as harmless defence-in-depth for environments that have manually patched `az.cmd` to remove `-I`.

## [0.7.1] - 2026-05-04

### Added
- **Sideloaded payload workflow.** Two cluster tags now coordinate human-driven sideloaded update payloads with the module:
  - **`UpdateSideloaded`** (operator-set, accepts `True`/`False`/`1`/`0`, case-insensitive). When `False`/`0`, `Start-AzureLocalClusterUpdate` skips the cluster with `Status = "SideloadedBlocked"` (CSV/JUnit/HTML reports surface this as a new skipped reason). Empty/missing tag means "no sideloaded gate" and updates proceed normally. Malformed values throw - use `-Force` to bypass at your own risk.
  - **`UpdateVersionInProgress`** (module-set, **never** set by operators). Written automatically when an update kicks off, holds the update name (e.g. `Solution12.2604.1003.209`).
- **New public function `Reset-AzureLocalSideloadedTag`** with parameter sets `ByName` / `ByResourceId` / `ByTag`. Explicit scope is required (no implicit `-AllClusters`). Default behaviour reads the latest run for each cluster, and only resets `UpdateSideloaded` -> `False` and clears `UpdateVersionInProgress` when the latest run is `Succeeded` **and** its update name matches `UpdateVersionInProgress`. Use `-Force` to bypass the match check (escape hatch for stuck tags).
- **Auto-reset in `Get-AzureLocalUpdateRuns`** (default ON; opt out with `-SkipSideloadedReset`). After fetching runs, the latest run per cluster is inspected; if `Succeeded` and the update name matches `UpdateVersionInProgress`, both tags are flipped to `False` / cleared in a single PATCH. Failures are logged as `Warning` and never abort the read path.
- New status enum value `SideloadedBlocked` in CSV log, JUnit XML, and HTML report skipped tallies.
- New `UpdateSideloaded` and `UpdateVersionInProgress` columns on `Get-AzureLocalClusterInventory` CSV/JSON exports (appended after `UpdateExclusions`, before `ResourceId`).
- No new RBAC permissions required - the existing `Microsoft.Resources/tags/read` and `/write` rights already documented for the v0.6.5 schedule-tag workflow are sufficient.

### Changed
- `Set-AzLocalClusterTagsMerge` is now idempotent: when the requested tag merge produces no actual change against the cluster's current tags, the PATCH is skipped entirely. Avoids redundant ARM writes from overlapping fleet-pipeline runs and from auto-reset against already-clean clusters.
- `Invoke-AzLocalSideloadedAutoResetForCluster` now distinguishes `Action = NoRuns` (cluster has no update history) from `RunNotSucceeded` (latest run is InProgress / Failed). Operators can tell "never updated" apart from "current run still running" in the auto-reset summary.
- `Invoke-AzLocalSideloadedAutoResetForCluster` now also surfaces `Action = OrphanCleared`. If a cluster has no `UpdateSideloaded` tag (opted out of the workflow) but a leftover `UpdateVersionInProgress` tag exists from an earlier in-module update, **and** the latest run is `Succeeded` and its name matches that tag, the orphan tag is cleared on a best-effort basis. `UpdateSideloaded` is **never** written in this path - the cluster has explicitly opted out, we only clean up our own breadcrumb.
- The sideloaded gate in `Start-AzureLocalClusterUpdate` and the auto-reset path now both read tags via the shape-agnostic `Get-TagValue` helper (handles both `[PSCustomObject]` and `[IDictionary]` tag containers consistently).

### CI/CD pipeline examples (v0.7.1)
- `apply-updates.yml` (Azure DevOps + GitHub Actions): summary now reports `SideloadedBlocked` count, and the "Actions Required" section calls out the operator step (stage payload, flip tag) when any cluster is sideloaded-blocked.
- `inventory-clusters.yml` (Azure DevOps + GitHub Actions): file header documents the new `UpdateSideloaded` / `UpdateVersionInProgress` columns and which is operator-set vs module-managed.

### Enterprise-readiness review fixes (v0.7.1)
- **Security**: `Write-UpdateCsvLog` (the diagnostic CSV path used during apply runs) now sanitises every field through `ConvertTo-SafeCsvField` before quote-escaping. Aligns the interim `Update_Skipped.csv` / `Update_Started.csv` log path with the OWASP CSV-injection protection already applied to the final exported results path. Hostile cluster names / ARM error messages starting with `=`, `+`, `-`, `@`, or containing CR/LF can no longer trigger formula evaluation when an operator opens these logs in Excel.
- **Operational**: parallel `Get-AzureLocalFleetStatusData` job dispatch now treats `Stopped` and `Disconnected` job states as failures alongside `Failed`. Previously these terminal states fell through into `Receive-Job` and were misdiagnosed as "no output" rather than "job crashed", obscuring root cause for `Stop-Job` / `Ctrl-C` and remoting-disconnect scenarios.
- **Performance**: `Get-AzureLocalUpdateSummary`, `Get-AzureLocalClusterUpdateReadiness`, `Start-AzureLocalClusterUpdate`, `Get-AzureLocalUpdateRuns`, and the private `Get-AzLocalClusterUpdateRuns` helper now accumulate per-cluster results in a `[System.Collections.Generic.List[object]]` (O(1) amortised `.Add()`) instead of an `Object[]` with `+=` (O(n) per append, O(n^2) total). Inner accumulators (`$results`, `$formattedRuns`, `$allFormattedRuns`, `$allRuns`) all converted. Measurable speed-up at fleet scale (1000+ clusters) for both the post-shard merge step and the per-cluster apply loop in `Start-AzureLocalClusterUpdate`; no API surface change - the functions still return arrays.

### Added (EndTime feature)
- New `EndTime` column on `Get-AzureLocalUpdateRuns` table output. For each per-attempt row, EndTime is sourced from `properties.progress.endTimeUtc` (the most accurate "work finished" timestamp), falling back to `properties.lastUpdatedTime` for older runs that pre-date the `progress.endTimeUtc` field. Blank for `InProgress` runs.
- New `End Time` column in the HTML fleet report's `Recent Update Run History` section. For the aggregated multi-attempt row, EndTime reflects the **latest attempt's** end time (StartTime continues to reflect the earliest attempt's start, so the row still reads "first started X, finally ended Y, total active duration Z").
- JUnit XML test bodies (success `<system-out>` and `<failure>`) now include `Start Time:` and `End Time:` lines for each cluster testcase. The JUnit `time=` attribute is unchanged - still numeric seconds, as required by CI tooling.
- New private helper `Get-AzLocalRunEndTime` centralises the EndTime resolution rule (priority: `progress.endTimeUtc` -> `lastUpdatedTime` -> `$null`) so the per-run formatter and the fleet aggregator never drift.

### Changed
- `Format-AzLocalUpdateRun` now prefers `properties.duration` (ARM-reported ISO-8601 timespan, e.g. `PT8H37M58S`) for per-run duration when present, falling back to `EndTime - StartTime`. Authoritative and immune to clock skew.

## [0.7.0] - 2026-04-24

The jump from `0.6.5` to `0.7.0` reflects the scope of this release: correctness fixes for large fleets (1500+ clusters), a shift to true parallel execution across all per-cluster read/write paths, HTML report performance improvements, and a round of bug and security hardening driven by a deep review of the module. No breaking public-surface changes; all new helpers are private. Az CLI is retained as the ARM transport; a native `Invoke-RestMethod` port is deliberately deferred to a future major release.

### Fixed (Phase 1 - Critical correctness at scale)
- **HIGH**: Azure Resource Graph queries used by `Get-AzureLocalClusterInventory` (and sibling functions that scope clusters by `-AllClusters` or `-ScopeByUpdateRingTag`) were hardcoded to `az graph query --first 1000`. At 1500 clusters, 500 clusters were silently dropped from the result set - no error, no warning. Introduced a private `Invoke-AzResourceGraphQuery` helper that loops on the ARG continuation `$skipToken` until exhausted, emitting a verbose line per page and an `Info` log whenever the total exceeds 1000.
- **HIGH**: `Invoke-AzureLocalFleetOperation -ThrottleLimit` previously only affected retry-backoff math; the per-cluster loop was fully sequential. At 1500 clusters that meant 4+ hour runs and CI/CD pipeline timeouts. Extracted the parallel `Start-Job` batch pattern already proven in `Get-AzureLocalFleetStatusData` into a shared private helper `Invoke-FleetJobsInParallel` and rerouted `Invoke-AzureLocalFleetOperation`, `Get-AzureLocalFleetProgress`, and `Test-AzureLocalFleetHealthGate -WaitForCompletion` through it. `-ThrottleLimit` now controls concurrent API calls (default 4, range 1-16). PowerShell 5.1 compatibility preserved - `ForEach-Object -Parallel` is deliberately not used.

### Changed (Phase 2 - Performance)
- Per-cluster read and write functions now run in parallel batches via the shared helper: `Get-AzureLocalClusterUpdateReadiness`, `Test-AzureLocalClusterHealth`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Set-AzureLocalClusterUpdateRingTag`. Expected 5-10x speedup for 1500-cluster runs (e.g. readiness check from 10 min to 1-2 min).
- `New-AzureLocalFleetStatusHtmlReport` renderer rewritten for O(n) scaling:
  - Pre-indexed `$latestRuns` and `$clusterDetails` hashtables replace two `Where-Object` filters inside the main cluster-row loop (was O(n^2): 2.25M scalar compares at 1500 clusters).
  - HTML encoding moved to collection time in `Get-AzureLocalFleetStatusData`, eliminating ~20,000 `HttpUtility::HtmlEncode` calls at render time.
  - Per-cluster Azure portal URLs precomputed once and reused across the status table and update-run table.
  - Roughly 60% faster HTML render at 1500 clusters.
- HTML report output now written with UTF-8 **without BOM** via `[System.IO.File]::WriteAllText` + `UTF8Encoding($false)`. Was previously writing with BOM via `Out-File -Encoding UTF8` on Windows PowerShell 5.1.
- New opt-in pass-through parameters on state-changing functions (`-UpdateSummary`, `-AvailableUpdates`) so pre-fetched data can be reused across a pipeline, avoiding redundant ARM reads.

### Fixed (Phase 3 - Bugs and strict-mode hardening)
- All remaining `| ConvertFrom-Json` call sites outside `Invoke-AzRestJson` were audited and either rerouted through the helper or explicitly null-guarded. Previously, any ARM response that was not valid JSON (e.g. HTTP 204, error HTML, stray `az` CLI warning text on stdout) would throw uncaught under strict mode.
- Empty-pipeline guards added to the health failures and latest-run aggregation paths to prevent silent `$null` results.
- Update-name sort is now deterministic: secondary sort key on `$_.name` with a `Warning` logged whenever an update has an unparseable YYMM component, instead of silently grouping all unparseables at position 0.
- Parallel CSV log writes: each `Start-Job` worker now writes to a per-job CSV; the coordinator merges fragments at the end of the run. Eliminates line interleaving and header corruption that `Add-Content` cannot protect against.
- Tag property access is now robust to both `Hashtable` and `PSCustomObject` tag shapes returned by different ARM endpoints, replacing the fragile dynamic-property lookup `$tags.$TagName`.
- `UpdateWindow` and `UpdateExclusions` tag values that fail to parse are now treated as blocking (update skipped with an `Error`-level log) unless `-Force` is specified. Was previously logged as a warning and the update proceeded.

### Security (Phase 4)
- `-UpdateRingValue` is whitelist-validated against `^[a-zA-Z0-9._-]+$` before KQL interpolation in Azure Resource Graph queries. The prior `-replace "'", "''"` escaping was fragile against KQL regex semantics.
- New private helper `ConvertTo-SafeCsvField` prefixes formula-leader characters (`=`, `+`, `-`, `@`, tab) with a single quote and strips embedded CR/LF. Applied uniformly to every field written by the CSV loggers. Prevents formula injection when a CSV (e.g. containing an attacker-controlled cluster name or error message) is opened in Excel.
- User-supplied output paths (`-OutputPath`, `-ExportResultsPath`, `-LogFolderPath`, `-StateFilePath`) are now resolved to absolute form via `[IO.Path]::GetFullPath()`, length-capped at 248 chars, and rejected if they contain `..\` traversal sequences when a relative root was expected.
- Az CLI error output is scrubbed before being written to error logs: any accidental `--password <value>` or `--secret <value>` echo is masked, as are token-shaped substrings (36-char patterns, `accessToken:` prefixes).
- `Invoke-AzRestJson` now handles mid-run token expiry: on HTTP 401 it runs `az account get-access-token` once, refreshes, and retries the original request. Logs an `Info` when a refresh happens. Previously, long fleet operations crossing the 1-hour token boundary would fail partway through.
- `Stop-AzureLocalFleetUpdate` now supports `ShouldProcess`: `-WhatIf` and `-Confirm` are honored before the operation is marked for stop and before any state file is written. `ConfirmImpact = Medium`.
- `New-AzureLocalFleetStatusHtmlReport` now supports `ShouldProcess`: `-WhatIf` and `-Confirm` are honored before the HTML report is written to disk. Under `-WhatIf`, the composed HTML string is still returned to the pipeline so it can be inspected or piped to email/log without touching the filesystem. `ConfirmImpact = Low`.

### Changed (Phase 5 - UX & schema refinements)
- **Maintenance window tag separator changed from `:` to `_`** between the day-spec and the time range (e.g. `Mon-Fri_22:00-02:00` replaces `Mon-Fri:22:00-02:00`). Makes the tag readable at a glance without ambiguity against the `HH:MM` components. Multi-window `;` and day-range `-` are unchanged. Breaking for pre-release consumers only; `ConvertFrom-AzLocalUpdateWindow` now throws on the old format and, combined with fail-closed schedule evaluation, any cluster still on the old tag value has its updates blocked until re-tagged.
- **Schedule tag evaluation is now genuinely fail-closed.** `Test-AzureLocalUpdateScheduleAllowed` previously swallowed parser errors and returned `Allowed=$true`, which defeated the "block on malformed tag" intent added earlier in this release. Parser errors now re-throw so the caller (`Start-AzureLocalClusterUpdate`) reaches its existing `try/catch` that blocks the update unless `-Force` is specified.
- **Fleet HTML report "Recent Update Run History"** now shows **one row per cluster** (the most-recently-started update) and aggregates attempts within that update:
  - `Duration` uses fixed-width `HH:MM:SS` format (survives multi-day and summed totals), replacing the fractional `N.N hours`.
  - New **Update Attempts** column (shown only when at least one cluster has >1 attempt) gives the retry count.
  - `StartTime` reflects the earliest attempt; `State`, `Progress`, `Current Step` reflect the latest attempt. Re-runs after failure no longer hide earlier time spent.
- **Fleet HTML report "Cluster Information"** now includes a **Current SBE Version** column. Extracted from `additionalProperties.SBEVersion` on the most recent applied SBE update. Propagated through `Get-AzureLocalFleetStatusData` and both GitHub Actions and Azure DevOps fleet-status pipeline YAMLs.
- **`Start-AzureLocalClusterUpdate -WhatIf`** output is no longer polluted by internal `Write-Log` / `Write-UpdateCsvLog` / `Env:` cleanup / log-folder creation side effects. Previously each internal housekeeping line produced a `What if:` row. Now only the ARM `POST apply/action` call appears in the `-WhatIf` preview.
- **`Start-AzureLocalClusterUpdate` final summary** now distinguishes **WouldUpdate** (dry-run or `ShouldProcess`-declined) from `Started` / `Skipped` / `Failed`, making fleet-scale `-WhatIf` runs auditable.

### Added (Phase 5)
- Private helper `Format-AzLocalDurationHuman` — central duration renderer; accepts `[TimeSpan]`, numeric seconds, or `HH:MM:SS` string and emits `"1 hour 23 minutes"` style. Used by `Get-AzureLocalUpdateRuns` per-run output. The fleet HTML report uses its own `HH:MM:SS` formatter because it sums across attempts.

### Notes
- No breaking changes to exported functions or parameter sets. All new helpers are private.
- Pester test suite target: >= 239 passing (the 0.6.5 baseline), plus new coverage for ARG pagination, parallel speedup ratios, CSV sanitization, and path validation.
- Az CLI is retained as the ARM transport for v0.7.0. A native `Invoke-RestMethod` port (with its own token cache, MSAL/device-flow handling, and proxy/TLS surface) is deferred to a future major release where it can get dedicated test coverage.
- Deliberate version jump: the volume of fixes and the behavior change from "sequential, silently truncated" to "parallel, paginated" warrants a minor-version bump rather than a patch.

## [0.6.5] - 2026-04-23

### Fixed
- **HIGH**: `Set-AzureLocalClusterUpdateRingTag` silently ignored the `UpdateWindow` and `UpdateExclusions` columns from a CSV produced by `Get-AzureLocalClusterInventory`. Inside the `foreach ($clusterEntry in $clustersToTag)` processing loop, four references used an undefined variable `$cluster` instead of the actual loop variable `$clusterEntry`. Because `Set-StrictMode` was not enforced at module scope, the typo silently returned `$null`, with two user-visible effects:
  - Clusters with an existing `UpdateRing` tag were skipped even when the CSV changed `UpdateWindow`/`UpdateExclusions` (the "has new schedule tags" detection always evaluated to `$false`).
  - On new or `-Force`d writes, the PATCH body contained only `UpdateRing`; `UpdateWindow`/`UpdateExclusions` columns from the CSV were never sent to Azure.
- Round-trip `Get-AzureLocalClusterInventory -ExportPath <csv>` -> edit CSV -> `Set-AzureLocalClusterUpdateRingTag -InputCsvPath <csv>` now correctly preserves all three tag columns.

### Added
- `Set-AzureLocalClusterUpdateRingTag -ClusterResourceIds` now accepts optional `-UpdateWindowValue` and `-UpdateExclusionsValue` parameters. Direct-invocation mode is now symmetrical with CSV mode and can set all three schedule tags in a single PATCH. Both values are echoed into the operations log.
- `Set-StrictMode -Version 1.0` is now enforced at module scope. This catches references to uninitialized variables (the class of bug above) at runtime instead of silently returning `$null`. All 239 Pester tests pass unchanged. `-Version Latest` was deliberately not selected: ARM REST responses legitimately omit optional properties (e.g. `additionalProperties.SBEPublisher`, `tags.UpdateRing`) and Latest would throw on every such dot-notation access.

### Changed
- No breaking changes. No API, JSON schema, or exported-function-count changes.

## [0.6.4] - 2026-04-16

### Security & Code Quality (2026-04-17 revision)
- **SECURITY**: `Connect-AzureLocalServicePrincipal` now accepts `-ServicePrincipalSecret` as either `[string]` or `[SecureString]`. When a plaintext `[string]` is passed, a warning is emitted because the secret can be visible in the process command line to other users on the host. SecureString or the `AZURE_CLIENT_SECRET` environment variable are preferred. The plaintext copy is zeroed in memory via `Marshal.ZeroFreeBSTR` in a `finally` block immediately after `az login` returns.
- **NEW internal helper `Invoke-AzRestJson`**: centralises `az rest` invocation, stderr capture (`2>&1`), `$LASTEXITCODE` handling, and safe `ConvertFrom-Json` parsing. Returns a uniform `{Ok, Data, Error}` object so callers no longer have to duplicate guard logic and a malformed JSON response cannot throw an uncaught exception under Strict Mode. Body is written to a temp file and cleaned up in `finally`.
- **NEW internal helper `ConvertTo-AzLocalAdditionalProperties`**: safely normalises the ARM `additionalProperties` field (which may be a JSON string or a deserialised object). All 5 previous call sites now route through this helper, so a single cluster returning malformed SBE metadata no longer silently loses its HasPrerequisite/SBE dependency info and instead logs a `-Verbose` parse warning.
- **FIXED**: `Get-AzureLocalFleetStatusData` parallel `Start-Job` path:
  - Module path (`$PSScriptRoot\AzStackHci.ManageUpdates.psm1`) is now validated with `Test-Path` before dispatching jobs; if it is not reachable, the function throws a clear error instead of every job failing silently with an `Import-Module` error.
  - Result accumulators (`Readiness`, `ClusterDetails`, `LatestRuns`, `HealthResults`, `$jobs`) switched from `@() + $item` (O(n²), pipeline-fragile) to `System.Collections.Generic.List[object]` with explicit `.Add()` calls.
  - Failed jobs, empty job output, and `ConvertFrom-Json` parse failures now surface each affected cluster (resource ID + reason) in a new `FailedClusters` property of the return object so no cluster is silently dropped from fleet reports.
- **IMPROVED**: `Connect-AzureLocalServicePrincipal`, `Test-AzCliAvailable`, and the MSI installer path now use `Write-Log` instead of `Write-Host` for durable, timestamped, CI-friendly output. Aligns with repository conventions in `.github/copilot-instructions.md`.
- **IMPROVED**: `Test-AzCliAvailable` MSI install no longer blocks indefinitely. `Start-Process msiexec.exe -Wait` was replaced with `Start-Process ... -PassThru` plus `WaitForExit(1800000)` (30 minute cap) with a kill-and-throw on timeout to prevent indefinite hangs in automation environments.
- **FIXED**: Confusing ternary in `Test-AzureLocalUpdateScheduleAllowed` final return: `ExclusionActive = if ($null -eq $exclusionActive) { $null } else { $false }` (which looked like it could never return `$true`) simplified to `ExclusionActive = $exclusionActive`. Behaviour is identical because the `$true` branch already returns early.
- **DOCS**: Azure REST API calls that parse response bodies are now safer under `Set-StrictMode -Version Latest`; `Invoke-AzRestJson` is available for future migrations of the remaining `az rest ... | ConvertFrom-Json` call sites.

### Inter-Function & Fleet-Scale Fixes (2026-04-17 revision)
- **FIXED**: `Test-AzureLocalUpdateScheduleAllowed` and `Test-AzLocalUpdateWindow` now normalise a non-UTC `-TestTime` (Local/Unspecified `DateTimeKind`) to UTC with a `Write-Verbose` note. Previously a caller passing `Get-Date` (local time) could silently evaluate the wrong maintenance-window hour/day, causing fleet updates to run outside their intended windows.
- **FIXED**: `Get-LatestUpdateByYYMM` emits a `Write-Verbose` warning when no input update name matches the expected `Solution<XX>.<YYMM>.<build>.<rev>` pattern. Previously, when every input failed to parse, all entries mapped to YYMM=0 and the first element of a stable sort was returned as the "latest" — technically arbitrary. Callers under `-Verbose` now see the mismatch.
- **IMPROVED**: `Get-AzureLocalAvailableUpdates -ClusterResourceId` (SingleCluster mode) now prints the same banner/Summary/Format-Table UX as the multi-cluster paths when `-Raw` is not specified. `-Raw` preserves the legacy silent behaviour for internal callers (`Start-AzureLocalClusterUpdate`, `Get-AzureLocalUpdateRuns`, `Get-AzureLocalClusterUpdateReadiness`).
- **KNOWN (not changed)**: `$script:LogFilePath` and `$script:FleetOperationState` are module-scope script variables. Sequential calls to multiple logging functions in the same session will overwrite the log path. Concurrent fleet operations in the same PowerShell session are not supported (use separate runspaces/processes). This is a logging-infrastructure design decision deferred to a future refactor.

### Added - Azure CLI Availability Check & Auto-Install
- **New internal function `Test-AzCliAvailable`**: Checks if Azure CLI (az) is installed before any az invocation
- When az CLI is not found in interactive sessions, prompts the user to download and install from `https://aka.ms/installazurecliwindowsx64`
- In non-interactive environments (CI/CD pipelines), throws immediately with clear installation instructions
- All exported functions and SingleCluster code paths now call `Test-AzCliAvailable` before first az CLI usage

### Added - Fleet Status Data Collection
- **New function `Get-AzureLocalFleetStatusData`**: Single-pass data collection with parallel `Start-Job` support
- `-ThrottleLimit` parameter (default: 4, max: 8) splits cluster list into parallel batches
- `-ExportPath` exports fleet data as JSON artifact for CI/CD pipeline job passing
- `-StatusData` parameter on `New-AzureLocalFleetStatusHtmlReport` accepts pre-collected data to skip API calls
- Stable JSON schema (v1.0) with SchemaVersion, Timestamp, ModuleVersion, Scope, Readiness, ClusterDetails, LatestRuns, HealthResults

### Improved - Update State Alignment
- All per-update state filters now use module-level constants (`$script:ReadyStates`, `$script:PrereqStates`) aligned with current ARM API states
- `ReadyToInstall` state is now recognized alongside `Ready` across all functions: `Start-AzureLocalClusterUpdate`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalClusterUpdateReadiness`, `Get-AzureLocalFleetStatusData`, `Get-AzureLocalUpdateSummary`
- Update summary state checks include `ReadyToInstall` for accurate "Update Available" counting

### Improved - HasPrerequisite & SBE Dependency Awareness
- **`Get-AzureLocalAvailableUpdates`**: Multi-cluster mode now shows HasPrerequisite/AdditionalContentRequired counts alongside Ready counts in console output
- **`Get-AzureLocalAvailableUpdates`**: Result objects include new `PackageType` and `SBEDependency` properties for updates blocked by SBE prerequisites
- **`Get-AzureLocalAvailableUpdates`**: Summary section shows clusters blocked by SBE prerequisites with vendor dependency details (Publisher, Family, ReleaseNotes)
- **`Start-AzureLocalClusterUpdate`**: Provides detailed SBE dependency info when updates are blocked by HasPrerequisite/AdditionalContentRequired state, with guidance to install the SBE from the hardware vendor
- **`Get-AzureLocalClusterUpdateReadiness`**: Surfaces `HasPrerequisiteUpdates` and `SBEDependency` in result objects for downstream consumption
- **`Get-AzureLocalClusterUpdateReadiness`**: Console output shows "Has Prerequisite (SBE update required)" for clusters with only prerequisite-blocked updates
- **`Get-AzureLocalClusterUpdateReadiness`**: Summary section includes count of clusters blocked by SBE prerequisites with vendor-specific guidance
- **`Get-AzureLocalFleetStatusData`**: Sequential collection now extracts HasPrerequisite and SBE dependency info into readiness data
- **`Get-AzureLocalFleetStatusData`**: Status output shows "Has Prerequisite" for clusters with only prerequisite-blocked updates
- Aligned with current ARM API update state handling: Ready, ReadyToInstall, AdditionalContentRequired, HasPrerequisite, HealthCheckFailed, Downloading, Preparing, HealthChecking

### Added - Maintenance Schedule Tag Support
- **New exported function `Test-AzureLocalUpdateScheduleAllowed`**: Master gate evaluating `UpdateWindow` and `UpdateExclusions` Azure resource tags
- **New internal function `ConvertFrom-AzLocalUpdateWindow`**: Parses maintenance window tag syntax (`<days>_<HH:MM>-<HH:MM>`) with day ranges, wildcards, and overnight windows
- **New internal function `ConvertFrom-AzLocalUpdateExclusion`**: Parses exclusion/blackout period tag syntax (`YYYY-MM-DD/YYYY-MM-DD`) with wildcard year support
- `Start-AzureLocalClusterUpdate` checks schedule tags before applying updates; returns `ScheduleBlocked` status when outside maintenance windows or during exclusion periods
- Exclusion periods take priority over maintenance windows

### Performance
- `New-AzureLocalFleetStatusHtmlReport` now uses single-pass data collection instead of calling 6 separate module functions
- Reduced Azure REST API calls from ~230 to ~85 for 21 clusters (~63% reduction)
- ByTag scope resolves resource IDs upfront via single ARG query instead of each downstream function querying independently
- Update summary, available updates, and health check data fetched once per cluster and reused
- Update run queries reuse already-fetched update list instead of re-fetching via `Get-AzureLocalAvailableUpdates`
- Progress counter shows `[N/M]` per cluster during data collection for better visibility

### Fixed
- `Get-AzureLocalClusterInfo`, `Invoke-AzureLocalUpdateApply`, and SingleCluster paths in `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalUpdateRuns` had no az CLI availability check - previously threw unhelpful `CommandNotFoundException`
- Existing auth check catch blocks now differentiate 'az not installed' from 'az not logged in' with distinct error messages
- 'Up to Date' counter now recognizes `AppliedSuccessfully` state from ARM API (was showing 0 for completed clusters)
- Recommended Update no longer shows the version a cluster is already on when state is `AppliedSuccessfully`/`UpToDate`

### Improved - CI/CD Pipeline Reporting
- Apply Updates pipeline summaries now include `ScheduleBlocked` count and "Actions Required" section with remediation guidance
- Fleet Update Status JUnit XML now marks HasPrerequisite clusters as `Failed (HasPrerequisite)` instead of passing silently
- Fleet Status JSON summary includes `HasPrerequisite` as a distinct count (previously lumped into `NotReady`)
- Fleet Status dashboard summaries show `SBE Prerequisite Blocked` row and "Actions Required" section
- `Get-AzureLocalClusterUpdateReadiness` and `Get-AzureLocalFleetStatusData` result objects now include `UpdateWindow` and `UpdateExclusions` tag values

### Improved - Tag Management Workflow
- `Get-AzureLocalClusterInventory` now includes `UpdateWindow` and `UpdateExclusions` columns in CSV/JSON output
- `Set-AzureLocalClusterUpdateRingTag` now reads optional `UpdateWindow` and `UpdateExclusions` columns from CSV and sets them alongside `UpdateRing` in a single PATCH operation

## [0.6.3] - 2026-04-15

### Fixed
- `-PassThru` parameter correctly added to `Get-AzureLocalUpdateSummary` param block (was in function body but missing from declaration)
- `-OutputPath` now pre-validated upfront (drive existence, `.html` extension) to fail fast before API calls

### Security
- Portal URLs in HTML report `href` attributes now HTML-encoded to prevent attribute injection
- `UpdateRingValue` in ARG KQL queries now escapes single quotes to prevent KQL injection (all 6 query locations)
- All dynamic HTML values consistently HTML-encoded: summary card numbers, timestamps, severity labels, readyText, collapse headers

### Improved
- `Get-CurrentStepPath` now has `MaxDepth=20` safety limit to prevent stack overflow on malformed step data
- `Get-LatestUpdateByYYMM` now guards against empty/null input array
- Cluster name matching uses exact last-segment comparison (`-split '/'`)[-1]`) instead of `-like` suffix pattern
- `$otherCount` in progress bar clamped to 0 minimum to prevent negative values
- Module version fallback reads from `.psd1` manifest via `Import-PowerShellDataFile` instead of hardcoded string
- `Resolve-Path` for file URI wrapped in `try/catch` for robustness when file write fails

## [0.6.2] - 2026-04-15

### Added - Fleet Status HTML Report
- **New function `New-AzureLocalFleetStatusHtmlReport`**: Generates self-contained HTML reports for fleet update status
  - Collects data from `Get-AzureLocalClusterUpdateReadiness`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalUpdateRuns`, and `Test-AzureLocalClusterHealth`
  - Executive summary cards: Total Clusters, Up to Date, In Progress, Ready for Update, Health Failures
  - Stacked progress bar showing fleet-wide update adoption percentages
  - Cluster Information section: cluster name, current version, node count, resource group, resource ID (top for <=10 clusters, appendix for >10)
  - Cluster Status Details with Active Update column (in-progress/failed update with badge) and Recommended Update (shows N/A when active update exists)
  - Recent Update Run History with recursive Current Step traversal (up to 8+ levels) including error messages for health-check-blocked updates
  - Health Check Failures with severity filter checkboxes (Critical/Warning checked, Informational unchecked by default)
  - Collapsible per-cluster health check groups for multi-cluster reports (2+ clusters) with severity summary and top issue in collapsed view
  - `-AllClusters` switch discovers all clusters via Azure Resource Graph (limited to 100)
  - Auto-generated title: single cluster = `"<ClusterName> - Update Status Report"`, multiple = `"Azure Local Fleet Update Status Report"`
  - Azure Local purple gradient header with embedded Azure Local instance SVG logo
  - Supports all input methods: `-ClusterResourceIds`, `-ClusterNames`, `-ScopeByUpdateRingTag`, `-AllClusters`
  - `-PassThru` returns HTML string for use as email body or further processing
  - Self-contained inline CSS and minimal JavaScript (severity filter), no external dependencies
  - XSS-safe via `System.Web.HttpUtility::HtmlEncode` on all dynamic values

### Fixed - RecommendedUpdate YYMM Sort
- `Get-AzureLocalClusterUpdateReadiness` now correctly selects the latest update by YYMM version (was using `Select-Object -First 1` without sorting, could select older update)
- Extracted shared `Get-LatestUpdateByYYMM` private helper used by both `Get-AzureLocalClusterUpdateReadiness` and `Start-AzureLocalClusterUpdate`

### Added - Recursive Update Step Traversal
- New `Get-CurrentStepPath` private helper recursively walks update run step hierarchy (up to 8+ levels deep) to find the deepest InProgress or Failed step
- `Get-AzureLocalUpdateRuns` now returns `CurrentStepDetail` property with full step path (e.g., "PreUpdate > ScanForUpdates > DownloadUpdates")
- HTML report shows Current Step column in Update Run History table

### Improved - Performance: Resolve-Once Pattern for `-ClusterNames`
- All functions that accept `-ClusterNames` now resolve names to resource IDs **once upfront** instead of deferring to per-cluster loops
- Eliminates redundant `Get-AzureLocalClusterInfo` API calls when multiple functions are called sequentially with the same cluster names
- Functions affected: `Start-AzureLocalClusterUpdate`, `Get-AzureLocalClusterUpdateReadiness`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalUpdateRuns`, `Test-AzureLocalClusterHealth`
- `New-AzureLocalFleetStatusHtmlReport` resolves names once and passes `-ClusterResourceIds` to all 6 downstream calls (reduces API calls from 6N to N for N clusters)
- `Test-AzureLocalClusterHealth` now accepts `-UpdateSummary` parameter to skip redundant summary fetch when called from `Start-AzureLocalClusterUpdate`

### Improved - CI/CD Pipeline Performance
- `fleet-update-status.yml` (GitHub Actions and Azure DevOps): Steps 4a/4b/4c now use `-ClusterResourceIds` from inventory instead of `-ClusterNames` or tag-based re-queries
- Eliminates redundant name-to-ID resolution and duplicate scope queries in pipeline data collection steps
- For a 100-cluster fleet: reduces API calls from ~800-900 to ~300

### Fixed - Missing `-PassThru` Parameter
- Added `-PassThru` parameter to `Get-AzureLocalUpdateSummary` and `Get-AzureLocalAvailableUpdates` (parameter was used in function body but missing from declaration)

### Fixed - `CurrentStepDetail` Not Propagated
- `CurrentStepDetail` property now correctly included in multi-cluster update run output (was missing from PSCustomObject re-mapping)
- Added `CurrentStepDetail` to all 3 fallback PSCustomObject blocks (Cluster Not Found, No Runs, Error)

## [0.6.1] - 2026-04-10

### Added - Pre-Update Health Check Validation
- **New function `Test-AzureLocalClusterHealth`**: Queries cluster health check results from ARM to identify Critical, Warning, and Informational failures before applying updates
  - Supports all input methods: `-ClusterResourceIds`, `-ClusterNames`, `-ScopeByUpdateRingTag`
  - `-BlockingOnly` switch to show only Critical severity failures (the ones that block updates)
  - Export results to CSV, JSON, or JUnit XML
  - Returns pass/fail result per cluster (pass = no Critical failures)

### Improved - Pre-Update Health Gate in `Start-AzureLocalClusterUpdate`
- Added automatic Step 3b health validation before attempting to apply an update
- If Critical health check failures are detected, the cluster is skipped with detailed failure information
- Failure details include check name, description, and remediation guidance
- Skipped clusters are logged to the Update_Skipped CSV with health check failure details

### Improved - Health Check Diagnostics in `Get-AzureLocalUpdateRuns`
- When the latest update run failed with "health check failure" in the CurrentStep, the function now automatically queries and displays the Critical health failures blocking the update
- Shows remediation steps for each blocking failure

### Changed - `-PassThru` Required for Object Output
- Functions now suppress object output by default to avoid console noise (e.g., list-format dump of all update runs)
- Use `-PassThru` to return objects for pipeline/variable capture: `$results = Get-AzureLocalUpdateRuns ... -PassThru`
- Functions affected: `Start-AzureLocalClusterUpdate`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalUpdateRuns`, `Get-AzureLocalClusterUpdateReadiness`, `Set-AzureLocalClusterUpdateRingTag`, `Test-AzureLocalClusterHealth`
- CI/CD pipeline examples updated to use `-PassThru` where return values are captured
- `HealthCheckBlocked` status added to JUnit XML failure mapping and CI/CD result counting

### Improved - Node-Level Health Failure Reporting
- Health check failures now display the physical node name (`TargetResourceName`) where the failure occurred
- Node name shown in console output, CSV skip logs, JUnit XML exports, and JSON exports
- Example: `[Critical] Test PowerShell Module Version (Node: SEA-NODE1): ...`

### Improved - Console Output Formatting
- `Get-AzureLocalUpdateRuns` latest run detail view now uses tab-indented `Format-List` with spacing for readability
- Removed non-ASCII Unicode characters (checkmark/cross) from fleet operation output for cross-system encoding compatibility

## [0.6.0] - 2026-04-09

### Fixed - Cumulative Update Auto-Selection
- **Fixed YYMM sort bug**: The auto-selection of the latest cumulative update was incorrectly picking an older update due to a PowerShell 5.1 `$Matches` variable scope issue inside `Sort-Object` scriptblocks. The `$Matches` state leaked between iterations, causing unpredictable sort order.
- **Fix**: Replaced `$Matches`-based extraction with `-split '.'` to extract the YYMM portion, which is self-contained per iteration with no shared state.
- Example: With updates `Solution12.2602.1002.501` and `Solution12.2603.1002.500` both in Ready state, the module now correctly selects `2603` (March 2026) instead of `2602` (February 2026).

## [0.5.9] - 2026-04-08

### Improved - Subscription & Resource Validation for `-ClusterResourceIds`
- **Subscription pre-validation**: When using `-ClusterResourceIds`, the module now extracts the subscription ID from the resource ID and runs `az account set --subscription` before making REST calls. This catches inaccessible subscriptions early with a clear error message instead of a cryptic `az rest` failure.
- **Specific error messages**: Validation errors are now split into distinct, actionable messages:
  - **Subscription not found**: Advises the user to verify they are logged into the correct Azure tenant (`az login --tenant <tenantId>`)
  - **Resource group not found**: Names the specific resource group and subscription, suggests the resource may have been deleted
  - **Cluster not found**: Names the specific cluster and resource group, suggests the cluster may have been deleted or the name is incorrect

### Improved - Auto-Selection of Latest Cumulative Update
- When `-UpdateName` is not specified, the module now **selects the latest update by YYMM version** from the update name (e.g., `Solution12.2603.1002.15` = March 2026) instead of taking the first item from the API response
- This ensures cumulative updates are handled correctly - earlier months are safely skipped when a newer cumulative update is available
- Update names follow the format `SolutionXX.YYMM.XXXX.XX`, where YYMM represents the year and month

## [0.5.7] - 2026-01-29

### Added
- **JSON Export for `Get-AzureLocalClusterInventory`**: The function now supports exporting inventory to JSON format in addition to CSV
  - Format is auto-detected from file extension (`.json` or `.csv`)
  - JSON export is ideal for CI/CD pipelines, API integrations, and CMDB systems
  - CSV remains the default for Excel-based tag management workflows

### Example
```powershell
# Export to JSON for CI/CD pipelines
Get-AzureLocalClusterInventory -ExportPath "C:\Reports\inventory.json"

# Export to CSV for Excel editing (unchanged)
Get-AzureLocalClusterInventory -ExportPath "C:\Reports\inventory.csv"
```

## [0.5.6] - 2026-01-29

### Added - Fleet-Scale Operations
New functions for managing updates across fleets of 1000-3000+ clusters:

- **`Invoke-AzureLocalFleetOperation`** - Orchestrates fleet-wide operations with:
  - Configurable batch processing (default: 50 clusters per batch)
  - Throttling and rate limiting (default: 10 parallel operations)
  - Automatic retry with exponential backoff (default: 3 retries)
  - State checkpointing for resume capability
  - Operations: ApplyUpdate, CheckReadiness, GetStatus

- **`Get-AzureLocalFleetProgress`** - Real-time progress tracking:
  - Total, completed, in-progress, failed, pending counts
  - Success/failure percentages
  - Per-cluster status details (with -Detailed switch)

- **`Test-AzureLocalFleetHealthGate`** - CI/CD health gate for safe wave deployments:
  - Maximum failure percentage threshold (default: 5%)
  - Minimum success percentage threshold (default: 90%)
  - Wait for completion option with timeout
  - Returns Pass/Fail for pipeline decisions

- **`Export-AzureLocalFleetState`** - Save operation state for resume:
  - JSON format with full cluster tracking
  - Includes run ID, timestamps, and per-cluster status

- **`Resume-AzureLocalFleetUpdate`** - Resume interrupted operations:
  - Load state from file or object
  - Option to retry failed clusters
  - Continues from last checkpoint

- **`Stop-AzureLocalFleetUpdate`** - Graceful stop with state save:
  - Saves current progress
  - Does not cancel in-progress cluster updates

### Use Cases
- **Enterprise Scale**: Process 1000-3000+ clusters with batching
- **CI/CD Safety**: Health gates prevent cascading failures
- **Resilience**: Resume capability after pipeline timeouts or interruptions
- **Visibility**: Real-time progress tracking during long operations

## [0.5.5] - 2026-01-29

### Added
- **Fleet-Wide Tag Support for All Query Functions**: Three functions now support multi-cluster queries:
  - `Get-AzureLocalUpdateSummary` - Query update summaries across fleet
  - `Get-AzureLocalAvailableUpdates` - List available updates across fleet
  - `Get-AzureLocalUpdateRuns` - Get update run history across fleet
- **New Parameters for Multi-Cluster Queries**:
  - `-ClusterNames` - Query multiple clusters by name
  - `-ClusterResourceIds` - Query multiple clusters by resource ID
  - `-ScopeByUpdateRingTag` + `-UpdateRingValue` - Query clusters by UpdateRing tag
  - `-ExportPath` - Export results to CSV, JSON, or JUnit XML format
- **Fleet Update Status Pipeline**: New `fleet-update-status.yml` CI/CD pipeline for monitoring update status across entire cluster fleet
  - Available for both GitHub Actions and Azure DevOps
  - Generates JUnit XML reports for CI/CD dashboard integration
  - Each cluster appears as a test case (passed=healthy, failed=issues)
  - Multiple output formats: CSV, JSON, and JUnit XML
  - Scheduled daily checks at 6 AM UTC (configurable)
  - Flexible scope: all clusters or filter by UpdateRing tag
- **Dashboard Integration**: JUnit XML results display in GitHub Actions Tests tab and Azure DevOps Tests tab with trend analytics

### Improved
- **Consistent Logging**: All functions now use `Write-Log` for consistent, timestamped, colored console output
- **File Logging Support**: When `$script:LogFilePath` is configured, all functions write to log files
- **Better Progress Visibility**: Users can see exactly what API operations are happening during function execution
- **Severity-Based Coloring**: Messages use appropriate levels (Info=White, Warning=Yellow, Error=Red, Success=Green, Header=Cyan)
- All fleet query functions provide consistent fleet-wide reporting with summaries
- Export support includes CSV, JSON, and JUnit XML for CI/CD integration
- **Backward Compatibility**: Single-cluster parameter sets remain unchanged for existing scripts

## [0.5.0] - 2026-01-29

### Security
- Added comprehensive OpenID Connect (OIDC) documentation for secretless CI/CD authentication
- Documented authentication methods ranked by security: OIDC (recommended) > Managed Identity > Client Secret
- GitHub Actions workflows now default to OIDC authentication with `id-token: write` permission
- Added Azure DevOps Workload Identity Federation setup instructions

### Documentation
- Added authentication method comparison table with security ratings
- Updated Quick Start guide with OIDC examples for GitHub Actions
- Added links to Microsoft documentation for federated credentials setup
- Documented subject claim patterns for GitHub Actions (branch, PR, environment, tag)
- Added warning that client secrets are legacy/not recommended

## [0.4.2] - 2026-01-29

### Documentation
- Verified and documented that all functions work with three authentication methods:
  1. **Interactive** - Standard user login via `az login`
  2. **Service Principal** - CI/CD automation using `Connect-AzureLocalServicePrincipal`
  3. **Managed Identity (MSI)** - Azure-hosted agents using `Connect-AzureLocalServicePrincipal -UseManagedIdentity`

## [0.4.1] - 2026-01-29

### Added
- Managed Identity (MSI) authentication support in `Connect-AzureLocalServicePrincipal` with `-UseManagedIdentity` switch
- `-ManagedIdentityClientId` parameter for user-assigned managed identities
- `-PassThru` switch for `Get-AzureLocalClusterInventory` to return objects even when exporting to CSV (useful for CI/CD pipelines)

### Fixed
- **CRITICAL**: Azure Resource Graph queries in `Get-AzureLocalClusterInventory`, `Start-AzureLocalClusterUpdate`, and `Get-AzureLocalClusterUpdateReadiness` were returning incorrect resource types (mixed resources like networkInterfaces, virtualHardDisks, extensions instead of clusters only). The root cause was HERE-STRING query format (`@"..."@`) causing malformed az CLI commands. Changed all ARG queries to single-line string format.
- **CRITICAL**: `Set-AzureLocalClusterUpdateRingTag` failing with JSON deserialization errors when applying tags. PowerShell/cmd.exe was mangling JSON quotes when passed to `az rest --body`. Now uses temp file with `@file` syntax to avoid escaping issues.
- **CRITICAL**: `Set-AzureLocalClusterUpdateRingTag` including PowerShell hashtable internal properties (`Keys`, `Values`) in JSON body. Now uses `[PSCustomObject]` with filtered `NoteProperty` members only.

### Changed
- `Get-AzureLocalClusterInventory` no longer dumps objects to console when using `-ExportPath` (cleaner output)

## [0.4.0] - 2026-01-29

### Added
- `Get-AzureLocalClusterInventory` function to query all clusters and their UpdateRing tag status
- CSV-based workflow for managing UpdateRing tags (export inventory, edit in Excel, import back)
- `Set-AzureLocalClusterUpdateRingTag` now accepts `-InputCsvPath` parameter for bulk tag operations
- JUnit XML export for CI/CD pipeline integration (Azure DevOps, GitHub Actions, Jenkins, GitLab CI)
- CI/CD automation pipeline examples for GitHub Actions and Azure DevOps

### Changed
- Renamed `-ScopeByTagName` to `-ScopeByUpdateRingTag` for clarity (now a switch parameter)
- Renamed `-TagValue` to `-UpdateRingValue` for consistency
- UpdateRing tag queries now use hardcoded 'UpdateRing' tag name for consistency
- `-ExportResultsPath` and `-ExportPath` now support `.xml` extension for JUnit format

### Fixed
- PSScriptAnalyzer warnings (empty catch blocks, unused variables)

## [0.3.0] - 2026-01-28

### Added
- `Connect-AzureLocalServicePrincipal` function for CI/CD automation (GitHub Actions, Azure DevOps)
- Service Principal authentication via parameters or environment variables (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`)

### Changed
- All functions now have `[OutputType()]` attributes for better IntelliSense
- Centralized API version constant for consistency
- Renamed internal function to use approved verb (`Install-AzGraphExtension`)
- `Write-Log` is now internal only (not exported)
- Added `#Requires -Version 5.1` statement
- Added LicenseUri to manifest for PowerShell Gallery compliance
- Added 'Automation' and 'CICD' tags for discoverability

## [0.2.0] - 2026-01-27

### Added
- `Set-AzureLocalClusterUpdateRingTag` function to manage UpdateRing tags on clusters
- Auto-install Azure CLI resource-graph extension for pipeline/automation scenarios
- Tag-based cluster filtering using `-ScopeByUpdateRingTag` and `-UpdateRingValue` parameters
- `-Force` parameter support for tag operations to overwrite existing tags
- Comprehensive logging for all tag operations with CSV output

### Changed
- Health check filtering now shows only Critical and Warning severities (not Informational)
- Enhanced CSV diagnostics with health check failures and update run error details
- `Get-AzureLocalClusterUpdateReadiness` now supports tag-based scoping

### Fixed
- Corrected API path for querying update run errors

## [0.1.0] - 2026-01-26

### Added
- Initial release
- `Start-AzureLocalClusterUpdate`: Start updates on one or more Azure Local clusters
- `Get-AzureLocalClusterUpdateReadiness`: Assess update readiness with diagnostics
- `Get-AzureLocalClusterInfo`: Retrieve cluster information
- `Get-AzureLocalUpdateSummary`: Get update summary for a cluster
- `Get-AzureLocalAvailableUpdates`: List available updates for a cluster
- `Get-AzureLocalUpdateRuns`: Monitor update progress
- Comprehensive logging with transcript support
- Export results to JSON/CSV
