# Changelog

All notable changes to the AzStackHci.ManageUpdates module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
