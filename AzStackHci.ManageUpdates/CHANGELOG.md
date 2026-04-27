# Changelog

All notable changes to the AzStackHci.ManageUpdates module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.1] - Unreleased

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
- The sideloaded gate in `Start-AzureLocalClusterUpdate` and the auto-reset path now both read tags via the shape-agnostic `Get-TagValue` helper (handles both `[PSCustomObject]` and `[IDictionary]` tag containers consistently).

### CI/CD pipeline examples (v0.7.1)
- `apply-updates.yml` (Azure DevOps + GitHub Actions): summary now reports `SideloadedBlocked` count, and the "Actions Required" section calls out the operator step (stage payload, flip tag) when any cluster is sideloaded-blocked.
- `inventory-clusters.yml` (Azure DevOps + GitHub Actions): file header documents the new `UpdateSideloaded` / `UpdateVersionInProgress` columns and which is operator-set vs module-managed.

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
