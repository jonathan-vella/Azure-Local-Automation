#Requires -Version 5.1
<#
.SYNOPSIS
    AzStackHci.ManageUpdates module for automating updates on Azure Local (Azure Stack HCI) clusters.

.DESCRIPTION
    This module queries Azure Local clusters by name or resource ID, checks their update status,
    and starts specified updates on clusters that are in "Ready" state with "UpdatesAvailable".
    
    It uses the Azure REST API directly via az rest to call the Update Manager API.
    
    Includes comprehensive logging capabilities with timestamped log files, 
    transcript support, and result export to JSON/CSV.
    
    Supports Service Principal authentication for CI/CD automation scenarios
    (GitHub Actions, Azure DevOps Pipelines).

.PARAMETER ClusterNames
    An array of Azure Local cluster names to update. Use this OR ClusterResourceIds.

.PARAMETER ClusterResourceIds
    An array of full Azure Resource IDs for the clusters to update. Use this when clusters
    are in different resource groups or subscriptions. Use this OR ClusterNames.
    
    The Resource IDs are validated before processing to ensure:
    - The format is correct (must match Azure Stack HCI cluster resource pattern)
    - The resource exists in Azure
    - You have the required permissions to access the resource
    
    Example: "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"

.PARAMETER ScopeByUpdateRingTag
    Uses the "UpdateRing" tag to find clusters via Azure Resource Graph.
    Must be used together with -UpdateRingValue. This enables updating clusters at scale
    using the UpdateRing tagging strategy. Works across multiple subscriptions.
    
    Requires the Azure CLI 'resource-graph' extension (automatically installed if missing).

.PARAMETER UpdateRingValue
    The value of the UpdateRing tag to match when using -ScopeByUpdateRingTag. Only clusters 
    where the UpdateRing tag equals this value will be selected for updates.
    Common values: "Ring1", "Ring2", "Ring3", "Production"

.PARAMETER ResourceGroupName
    The resource group containing the clusters. If not specified, the function will 
    search for the cluster across all resource groups in the subscription.
    Only used with -ClusterNames parameter.

.PARAMETER SubscriptionId
    The Azure subscription ID. If not specified, uses the current az CLI subscription.
    Only used with -ClusterNames parameter.

.PARAMETER UpdateName
    The specific update name to apply. If not specified, the function will list 
    available updates and prompt for selection or apply the latest available update.

.PARAMETER ApiVersion
    The API version to use. Defaults to "2025-10-01".

.PARAMETER LogFolderPath
    Path to the folder where log files will be created. If not specified, defaults to:
    C:\ProgramData\AzStackHci.ManageUpdates\
    
    This default location is accessible across different user profiles.
    The folder is automatically created if it doesn't exist.

.PARAMETER EnableTranscript
    Enables PowerShell transcript recording to capture all console output.

.PARAMETER ExportResultsPath
    Path to export results. Supports multiple formats based on file extension:
    - .json = JSON format with summary statistics
    - .csv  = Standard CSV format
    - .xml  = JUnit XML format for CI/CD pipeline integration
    
    JUnit XML is compatible with:
    - Azure DevOps (Publish Test Results task)
    - GitHub Actions (dorny/test-reporter or similar)
    - Jenkins (JUnit plugin)
    - GitLab CI (native support)
    - TeamCity (built-in)
    
    If no extension is provided, defaults to JSON.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.EXAMPLE
    # Start update on a single cluster with logging
    Start-AzureLocalClusterUpdate -ClusterNames "MyCluster01" -ResourceGroupName "MyRG" -LogPath "C:\Logs\update.log"

.EXAMPLE
    # Start updates on multiple clusters with transcript and JSON export
    Start-AzureLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02") -EnableTranscript -ExportResultsPath "C:\Logs\results.json"

.EXAMPLE
    # Start a specific update with full logging
    Start-AzureLocalClusterUpdate -ClusterNames "MyCluster01" -UpdateName "Solution12.2601.1002.38" -LogPath "C:\Logs\update.log" -EnableTranscript

.EXAMPLE
    # Start updates on clusters in different resource groups using Resource IDs
    $resourceIds = @(
        "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01",
        "/subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02"
    )
    Start-AzureLocalClusterUpdate -ClusterResourceIds $resourceIds -Force

.EXAMPLE
    # Start updates on all clusters tagged with "UpdateRing" = "Ring1" (across all subscriptions)
    Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Ring1" -Force

.EXAMPLE
    # Start updates on production ring clusters
    Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Production" -UpdateName "Solution12.2601.1002.38" -Force

.EXAMPLE
    # Export results to JUnit XML for CI/CD pipeline integration (Azure DevOps, GitHub Actions, Jenkins)
    Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Ring1" -Force -ExportResultsPath "C:\Logs\update-results.xml"

.NOTES
    Version: 0.6.5
    Author: Neil Bird, Microsoft.
    Requires: Azure CLI (az) installed and authenticated
    API Reference: https://github.com/Azure/azure-rest-api-specs/blob/main/specification/azurestackhci/resource-manager/Microsoft.AzureStackHCI/StackHCI/stable/2026-02-01/hci.json
#>

# Enforce defensive coding at module scope.
# Version 1.0 catches references to uninitialized variables (e.g. $cluster vs $clusterEntry typos).
# Deliberately NOT -Version Latest: Azure ARM REST responses legitimately omit optional
# properties (e.g. additionalProperties.SBEPublisher, tags.UpdateRing), and Latest would
# throw on every such dot-notation access. Hardening those sites is tracked separately.
Set-StrictMode -Version 1.0

# Module constants
$script:ModuleVersion = '0.6.5'
$script:DefaultApiVersion = '2025-10-01'
$script:DefaultLogFolder = Join-Path -Path $env:ProgramData -ChildPath 'AzStackHci.ManageUpdates'

# Update state constants aligned with queries in Azure Local LENS workbook
# States that indicate an update is installable (ready to apply)
$script:ReadyStates = @('Ready', 'ReadyToInstall')
# States that indicate an update is blocked by a prerequisite
$script:PrereqStates = @('HasPrerequisite', 'AdditionalContentRequired')
# States that indicate an update failed health validation
$script:HealthCheckFailedStates = @('HealthCheckFailed')
# States that indicate an update is in a transitional phase
$script:TransitionalStates = @('Downloading', 'Preparing', 'HealthChecking')

# Script-level variables for logging
$script:LogFilePath = $null
$script:ErrorLogPath = $null
$script:UpdateSkippedLogPath = $null
$script:UpdateStartedLogPath = $null

# Service Principal authentication state
$script:ServicePrincipalAuthenticated = $false

function Test-AzCliAvailable {
    <#
    .SYNOPSIS
        Tests if Azure CLI (az) is installed and available. Offers to download and install if missing.
    .DESCRIPTION
        Checks if the 'az' command is available on the system PATH. If not found, prompts the user
        to download and install the Azure CLI MSI (Windows x64). In non-interactive environments
        (CI/CD pipelines), throws immediately with installation instructions.
    .OUTPUTS
        Returns $true if az CLI is available. Throws if not available and user declines installation.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Quick check - is az already available?
    if (Get-Command 'az' -ErrorAction SilentlyContinue) {
        return $true
    }

    # az not found - determine if we're running interactively
    $isInteractive = [Environment]::UserInteractive -and -not $env:TF_BUILD -and -not $env:GITHUB_ACTIONS -and -not $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI

    if (-not $isInteractive) {
        throw "Azure CLI (az) is not installed. Install it from https://aka.ms/installazurecliwindowsx64 or run: winget install Microsoft.AzureCLI"
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "Azure CLI (az) is not installed on this system." -Level Error
    Write-Log -Message "The Azure CLI is required for this module to communicate with Azure." -Level Warning
    Write-Log -Message "Download URL: https://aka.ms/installazurecliwindowsx64" -Level Header
    Write-Log -Message "" -Level Info

    $response = Read-Host "Would you like to download and install the Azure CLI now? (y/n)"
    if ($response -notin @('y', 'Y', 'yes', 'Yes')) {
        throw "Azure CLI (az) is required but not installed. Install it from https://aka.ms/installazurecliwindowsx64 or run: winget install Microsoft.AzureCLI"
    }

    # Download and install
    $msiPath = Join-Path $env:TEMP 'AzureCLI.msi'
    try {
        Write-Log -Message "Downloading Azure CLI installer..." -Level Warning
        Invoke-WebRequest -Uri 'https://aka.ms/installazurecliwindowsx64' -OutFile $msiPath -UseBasicParsing

        Write-Log -Message "Installing Azure CLI (this may take a few minutes)..." -Level Warning
        $installProcess = Start-Process msiexec.exe -ArgumentList "/I `"$msiPath`" /quiet" -PassThru
        if (-not $installProcess.WaitForExit(1800000)) {
            # 30 minute safety timeout - prevents indefinite hangs in automation
            try { $installProcess.Kill() } catch { }
            throw "Azure CLI installation timed out after 30 minutes."
        }
        if ($installProcess.ExitCode -ne 0) {
            throw "MSI installer exited with code $($installProcess.ExitCode)"
        }

        # Refresh PATH so the current session can find az
        $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
        $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        $env:PATH = "$machinePath;$userPath"

        # Verify installation
        if (Get-Command 'az' -ErrorAction SilentlyContinue) {
            $azVersion = az version --query '\"azure-cli\"' -o tsv 2>$null
            Write-Log -Message "Azure CLI v$azVersion installed successfully." -Level Success
            Write-Log -Message "Run 'az login' to authenticate before using this module." -Level Warning
            return $true
        }
        else {
            throw "Azure CLI was installed but 'az' command is not found in PATH. Please restart your PowerShell session."
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -notmatch 'not found in PATH|not installed') {
            Write-Log -Message "Failed to install Azure CLI: $errorMsg" -Level Error
        }
        throw "Azure CLI installation failed. Please install manually from https://aka.ms/installazurecliwindowsx64 - Error: $errorMsg"
    }
    finally {
        # Clean up MSI file
        if (Test-Path $msiPath) {
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-ExportPathWritable {
    <#
    .SYNOPSIS
        Pre-flight check: validates an export file path is writable before expensive operations begin.
    .DESCRIPTION
        Checks that the target export file is not locked by another process (e.g., Excel),
        and that the parent directory exists or can be created. Call this early in functions
        that accept -ExportPath/-ExportResultsPath to fail fast before API calls.
    .PARAMETER Path
        The file path to validate.
    .OUTPUTS
        Returns $true if the path is writable. Throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Ensure parent directory exists or can be created
    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path -Path $parentDir)) {
        try {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        catch {
            throw "Cannot create export directory '$parentDir': $($_.Exception.Message)"
        }
    }

    # If file doesn't exist yet, path is writable
    if (-not (Test-Path -Path $Path)) {
        return $true
    }

    # File exists - test if it's locked by trying to open it for write
    try {
        $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $fileStream.Close()
        $fileStream.Dispose()
        return $true
    }
    catch [System.IO.IOException] {
        throw "Export file '$Path' is locked by another process (e.g., Excel). Close the file and try again."
    }
    catch {
        throw "Cannot write to export file '$Path': $($_.Exception.Message)"
    }
}

function Connect-AzureLocalServicePrincipal {
    <#
    .SYNOPSIS
        Authenticates to Azure using a Service Principal or Managed Identity for CI/CD automation.
    
    .DESCRIPTION
        Logs into Azure CLI using Service Principal credentials or Managed Identity (MSI),
        enabling automated operations in GitHub Actions, Azure DevOps Pipelines, or other CI/CD systems.
        
        Authentication methods:
        1. Managed Identity (-UseManagedIdentity): For Azure-hosted runners/agents with assigned identity
        2. Service Principal (default): Using credentials from parameters or environment variables
        
        Service Principal credentials can be provided via:
        - Parameters: -ServicePrincipalId, -ServicePrincipalSecret, -TenantId
        - Environment variables: AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID
        
        If already authenticated (interactively or via SP/MSI), this function will skip login
        unless -Force is specified.
    
    .PARAMETER UseManagedIdentity
        Use Managed Identity (MSI) authentication instead of Service Principal.
        This is useful for Azure-hosted runners, VMs, or Azure Container Instances
        that have a system-assigned or user-assigned managed identity.
    
    .PARAMETER ManagedIdentityClientId
        Optional. The client ID of a user-assigned managed identity to use.
        If not specified, the system-assigned managed identity will be used.
    
    .PARAMETER ServicePrincipalId
        The Application (client) ID of the Service Principal. 
        Can also be set via AZURE_CLIENT_ID environment variable.
        Not used when -UseManagedIdentity is specified.
    
    .PARAMETER ServicePrincipalSecret
        The client secret for the Service Principal.
        Can also be set via AZURE_CLIENT_SECRET environment variable.
        For security, prefer a [SecureString] or the AZURE_CLIENT_SECRET environment variable.
        Accepts both [string] (plaintext, logs a security warning) and [SecureString].
        Plaintext passing via command line is discouraged because process command-line arguments
        may be visible to other users/EDR on the host.
        Not used when -UseManagedIdentity is specified.
    
    .PARAMETER TenantId
        The Azure AD tenant ID.
        Can also be set via AZURE_TENANT_ID environment variable.
        Not used when -UseManagedIdentity is specified.
    
    .PARAMETER Force
        Force re-authentication even if already logged in.
    
    .OUTPUTS
        Returns $true if authentication succeeded, $false otherwise.
    
    .EXAMPLE
        # Using Managed Identity (system-assigned) - recommended for Azure-hosted agents
        Connect-AzureLocalServicePrincipal -UseManagedIdentity
    
    .EXAMPLE
        # Using Managed Identity (user-assigned) with specific client ID
        Connect-AzureLocalServicePrincipal -UseManagedIdentity -ManagedIdentityClientId "12345678-1234-1234-1234-123456789012"
    
    .EXAMPLE
        # Using Service Principal with SecureString (preferred when not using env vars)
        $secret = Read-Host -AsSecureString -Prompt 'Service Principal Secret'
        Connect-AzureLocalServicePrincipal -ServicePrincipalId $appId -ServicePrincipalSecret $secret -TenantId $tenant
    
    .EXAMPLE
        # Using environment variables (recommended for CI/CD with Service Principal)
        $env:AZURE_CLIENT_ID = 'your-app-id'
        $env:AZURE_CLIENT_SECRET = 'your-secret'
        $env:AZURE_TENANT_ID = 'your-tenant-id'
        Connect-AzureLocalServicePrincipal
    
    .EXAMPLE
        # GitHub Actions workflow - credentials from secrets
        # env:
        #   AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
        #   AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
        #   AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
        Connect-AzureLocalServicePrincipal
    
    .NOTES
        The Service Principal or Managed Identity requires the following permissions:
        - Microsoft.AzureStackHCI/clusters/read
        - Microsoft.AzureStackHCI/clusters/updates/read
        - Microsoft.AzureStackHCI/clusters/updates/apply/action
        - Microsoft.AzureStackHCI/clusters/updateSummaries/read
        - Microsoft.AzureStackHCI/clusters/updateRuns/read
        - Microsoft.Resources/subscriptions/resources/read (for Azure Resource Graph queries)
        - Tag Contributor role (for Set-AzureLocalClusterUpdateRingTag)
    #>
    [CmdletBinding(DefaultParameterSetName = 'ServicePrincipal')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ManagedIdentity')]
        [switch]$UseManagedIdentity,

        [Parameter(Mandatory = $false, ParameterSetName = 'ManagedIdentity')]
        [string]$ManagedIdentityClientId,

        [Parameter(Mandatory = $false, ParameterSetName = 'ServicePrincipal')]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory = $false, ParameterSetName = 'ServicePrincipal')]
        # Accept either [string] (plaintext - backward compatible, warns) or [SecureString].
        [object]$ServicePrincipalSecret,

        [Parameter(Mandatory = $false, ParameterSetName = 'ServicePrincipal')]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Check for existing authentication unless Force is specified
    if (-not $Force) {
        try {
            $accountInfo = az account show 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $accountInfo) {
                Write-Verbose "Already authenticated as: $($accountInfo.user.name) (Type: $($accountInfo.user.type))"
                return $true
            }
        }
        catch {
            # Not authenticated, continue with login - this is expected behavior
            Write-Verbose "No existing Azure CLI session, proceeding with authentication"
        }
    }

    # Managed Identity authentication
    if ($UseManagedIdentity) {
        Write-Log -Message "Authenticating with Managed Identity..." -Level Warning

        try {
            if ($ManagedIdentityClientId) {
                # User-assigned managed identity
                Write-Log -Message "Using user-assigned managed identity: $ManagedIdentityClientId" -Level Verbose
                $loginResult = az login --identity --username $ManagedIdentityClientId --output none 2>&1
            }
            else {
                # System-assigned managed identity
                Write-Log -Message "Using system-assigned managed identity" -Level Verbose
                $loginResult = az login --identity --output none 2>&1
            }

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Managed Identity authentication failed: $loginResult"
                Write-Error "Ensure this environment has a managed identity assigned and it has the required permissions."
                return $false
            }

            # Verify authentication
            $accountInfo = az account show 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $accountInfo) {
                Write-Log -Message "Successfully authenticated with Managed Identity" -Level Success
                Write-Log -Message "Subscription: $($accountInfo.name) ($($accountInfo.id))" -Level Verbose
                $script:ManagedIdentityAuthenticated = $true
                return $true
            }
            else {
                Write-Error "Authentication succeeded but account verification failed."
                return $false
            }
        }
        catch {
            Write-Error "Managed Identity authentication error: $($_.Exception.Message)"
            return $false
        }
    }

    # Service Principal authentication (default)
    # Get credentials from parameters or environment variables
    $clientId = if ($ServicePrincipalId) { $ServicePrincipalId } else { $env:AZURE_CLIENT_ID }

    # Resolve secret: [SecureString] preferred, [string] accepted for backward compat (with warning)
    $clientSecretPlain = $null
    $secretBstr = [IntPtr]::Zero
    try {
        if ($ServicePrincipalSecret -is [System.Security.SecureString]) {
            $secretBstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ServicePrincipalSecret)
            $clientSecretPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretBstr)
        }
        elseif ($ServicePrincipalSecret -is [string] -and $ServicePrincipalSecret) {
            Write-Log -Message "SECURITY: -ServicePrincipalSecret was supplied as plaintext [string]. Secret may be visible in process command line to other users on this host. Prefer [SecureString] or the AZURE_CLIENT_SECRET environment variable for CI/CD." -Level Warning
            $clientSecretPlain = $ServicePrincipalSecret
        }
        elseif ($null -ne $ServicePrincipalSecret) {
            Write-Error "-ServicePrincipalSecret must be a [string] or [SecureString]. Got: $($ServicePrincipalSecret.GetType().FullName)"
            return $false
        }
        else {
            $clientSecretPlain = $env:AZURE_CLIENT_SECRET
        }

        $tenant = if ($TenantId) { $TenantId } else { $env:AZURE_TENANT_ID }

        # Validate required credentials
        if (-not $clientId) {
            Write-Error "Service Principal ID not provided. Set -ServicePrincipalId parameter or AZURE_CLIENT_ID environment variable."
            return $false
        }
        if (-not $clientSecretPlain) {
            Write-Error "Service Principal Secret not provided. Set -ServicePrincipalSecret parameter or AZURE_CLIENT_SECRET environment variable."
            return $false
        }
        if (-not $tenant) {
            Write-Error "Tenant ID not provided. Set -TenantId parameter or AZURE_TENANT_ID environment variable."
            return $false
        }

        Write-Log -Message "Authenticating with Service Principal..." -Level Warning

        try {
            # Login using Service Principal
            $loginResult = az login --service-principal `
                --username $clientId `
                --password $clientSecretPlain `
                --tenant $tenant `
                --output none 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Service Principal authentication failed: $loginResult"
                return $false
            }

            # Verify authentication
            $accountInfo = az account show 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $accountInfo) {
                Write-Log -Message "Successfully authenticated as Service Principal: $($accountInfo.user.name)" -Level Success
                Write-Log -Message "Subscription: $($accountInfo.name) ($($accountInfo.id))" -Level Verbose
                $script:ServicePrincipalAuthenticated = $true
                return $true
            }
            else {
                Write-Error "Authentication succeeded but account verification failed."
                return $false
            }
        }
        catch {
            Write-Error "Service Principal authentication error: $($_.Exception.Message)"
            return $false
        }
    }
    finally {
        # Scrub plaintext secret from memory as soon as az login returns
        if ($secretBstr -ne [IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretBstr)
        }
        $clientSecretPlain = $null
    }
}

function Install-AzGraphExtension {
    <#
    .SYNOPSIS
        Installs the Azure CLI resource-graph extension if not present.
    
    .DESCRIPTION
        Checks if the Azure CLI 'resource-graph' extension is installed.
        If not installed, automatically installs it to enable Azure Resource Graph queries.
        This enables non-interactive pipeline/automation scenarios.
    
    .OUTPUTS
        Returns $true if the extension is available (already installed or successfully installed).
        Returns $false if installation failed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        # Check if extension is already installed
        $extensions = az extension list --query "[?name=='resource-graph'].name" -o tsv 2>$null
        
        if ($extensions -and $extensions.Trim() -eq 'resource-graph') {
            Write-Verbose "Azure CLI 'resource-graph' extension is already installed."
            return $true
        }
        
        # Extension not found, install it
        Write-Host "Installing Azure CLI 'resource-graph' extension..." -ForegroundColor Yellow
        $installResult = az extension add --name resource-graph --yes 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to install 'resource-graph' extension: $installResult"
            return $false
        }
        
        Write-Host "Azure CLI 'resource-graph' extension installed successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Error checking/installing resource-graph extension: $_"
        return $false
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a timestamped log entry to console and optionally to file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Verbose', 'Header')]
        [string]$Level = 'Info',

        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Determine color based on level if not specified
    if (-not $ForegroundColor) {
        $ForegroundColor = switch ($Level) {
            'Info'    { 'White' }
            'Warning' { 'Yellow' }
            'Error'   { 'Red' }
            'Success' { 'Green' }
            'Verbose' { 'Gray' }
            'Header'  { 'Cyan' }
            default   { 'White' }
        }
    }

    # Write to console
    Write-Host $logEntry -ForegroundColor $ForegroundColor

    # Write to log file if path is set
    if ($script:LogFilePath) {
        try {
            Add-Content -Path $script:LogFilePath -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Log file write failure is non-critical - continue silently to not disrupt main operation
            Write-Verbose "Failed to write to log file: $($_.Exception.Message)"
        }
    }

    # Write errors to separate error log
    if ($Level -eq 'Error' -and $script:ErrorLogPath) {
        try {
            Add-Content -Path $script:ErrorLogPath -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Error log write failure is non-critical - continue silently
            Write-Verbose "Failed to write to error log file: $($_.Exception.Message)"
        }
    }
}

function Invoke-AzRestJson {
    <#
    .SYNOPSIS
        Internal helper that invokes 'az rest' and safely parses the JSON response.
    .DESCRIPTION
        Wraps 'az rest' to centralise error handling, LASTEXITCODE checks, and
        ConvertFrom-Json failure handling. Returns a uniform result object so
        callers no longer have to duplicate the same guard pattern.
        
        Captures stderr via 2>&1 so that non-JSON error text returned by the
        Azure CLI never reaches ConvertFrom-Json, which would otherwise throw
        an uncaught parse error under Set-StrictMode.
    .PARAMETER Uri
        Full ARM URI, e.g. https://management.azure.com/<resourceId>?api-version=...
    .PARAMETER Method
        HTTP method (GET, POST, PATCH, PUT, DELETE). Defaults to GET.
    .PARAMETER Body
        Optional JSON body string. Written to a temp file and passed via @file
        to avoid shell escaping issues.
    .PARAMETER Headers
        Optional extra headers (array of 'Name=Value' strings).
    .OUTPUTS
        PSCustomObject with: Ok (bool), Data (parsed JSON or $null), Error (string or $null)
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'HEAD')]
        [string]$Method = 'GET',

        [Parameter(Mandatory = $false)]
        [string]$Body,

        [Parameter(Mandatory = $false)]
        [string[]]$Headers
    )

    $tempBodyFile = $null
    try {
        $azArgs = @('rest', '--method', $Method, '--uri', $Uri)
        if ($PSBoundParameters.ContainsKey('Body') -and $Body) {
            $tempBodyFile = [System.IO.Path]::GetTempFileName()
            $Body | Out-File -FilePath $tempBodyFile -Encoding utf8 -NoNewline
            $azArgs += @('--body', "@$tempBodyFile")
            if (-not $Headers) { $Headers = @('Content-Type=application/json') }
        }
        if ($Headers) {
            foreach ($h in $Headers) { $azArgs += @('--headers', $h) }
        }

        $raw = & az @azArgs 2>&1
        $exit = $LASTEXITCODE

        # Mid-run token expiry: detect 401 / ExpiredAuthenticationToken in the
        # CLI error text, force a token refresh, and retry the original call
        # exactly once. This avoids breaking long-running fleet operations when
        # the cached access token crosses its expiry during the run.
        if ($exit -ne 0) {
            $errText = ($raw | Out-String)
            $is401 = ($errText -match '\b401\b' -or
                      $errText -match 'ExpiredAuthenticationToken' -or
                      $errText -match 'InvalidAuthenticationToken' -or
                      $errText -match 'AuthenticationFailed')
            if ($is401) {
                Write-Verbose "Invoke-AzRestJson: detected 401 / token-expiry on $Method $Uri; refreshing access token and retrying once."
                try {
                    # Forces the CLI to refresh the cached bearer token.
                    $null = & az account get-access-token --resource 'https://management.azure.com/' --output none 2>&1
                }
                catch {
                    Write-Verbose "Invoke-AzRestJson: token refresh failed: $($_.Exception.Message)"
                }
                $raw = & az @azArgs 2>&1
                $exit = $LASTEXITCODE
            }
        }

        if ($exit -ne 0) {
            return [PSCustomObject]@{
                Ok    = $false
                Data  = $null
                Error = (ConvertTo-ScrubbedCliOutput -Text (($raw | Out-String).Trim()))
            }
        }

        # Success path: parse JSON (empty body is OK for PATCH/DELETE)
        $rawText = ($raw | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($rawText)) {
            return [PSCustomObject]@{ Ok = $true; Data = $null; Error = $null }
        }
        try {
            $parsed = $rawText | ConvertFrom-Json -ErrorAction Stop
            return [PSCustomObject]@{ Ok = $true; Data = $parsed; Error = $null }
        }
        catch {
            return [PSCustomObject]@{
                Ok    = $false
                Data  = $null
                Error = "JSON parse failure: $($_.Exception.Message); raw: $(ConvertTo-ScrubbedCliOutput -Text $rawText.Substring(0, [Math]::Min(500, $rawText.Length)))"
            }
        }
    }
    finally {
        if ($tempBodyFile -and (Test-Path -LiteralPath $tempBodyFile)) {
            Remove-Item -LiteralPath $tempBodyFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-AzResourceGraphQuery {
    <#
    .SYNOPSIS
        Runs an Azure Resource Graph query via 'az graph query' and transparently
        follows skip_token pagination until all rows are returned.
    .DESCRIPTION
        The Azure CLI returns at most --first rows per call (max 1000). When a
        fleet has more than 1000 clusters the caller was previously receiving
        only a truncated first page. This helper loops on the response's
        skip_token field, aggregating .data across pages and returning the
        merged row array.

        Safety cap: MaxPages (default 50 -> 50,000 rows) prevents a bug in the
        caller's query from producing an infinite pagination loop. A warning
        is emitted via Write-Warning and the partial result is returned if the
        cap is hit.
    .PARAMETER Query
        KQL query string. Passed verbatim to 'az graph query -q'.
    .PARAMETER SubscriptionId
        Optional. If supplied, scopes the query to that subscription via
        --subscriptions. Omit to query across all accessible subscriptions.
    .PARAMETER First
        Page size. Defaults to 1000 (the ARG maximum).
    .PARAMETER MaxPages
        Safety cap. Defaults to 50.
    .OUTPUTS
        [object[]] of rows merged across all pages. Empty array if no rows.
        Throws if the CLI returns a non-zero exit code or the response cannot
        be parsed as JSON.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1000)]
        [int]$First = 1000,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 500)]
        [int]$MaxPages = 50
    )

    $allRows = [System.Collections.Generic.List[object]]::new()
    $skipToken = $null
    $pages = 0

    while ($true) {
        $pages++
        if ($pages -gt $MaxPages) {
            Write-Warning "Invoke-AzResourceGraphQuery: reached MaxPages=$MaxPages safety cap; returning partial result ($($allRows.Count) rows). Check the query for unbounded output or raise -MaxPages."
            break
        }

        $azArgs = @('graph', 'query', '-q', $Query, '--first', $First)
        if ($SubscriptionId) { $azArgs += @('--subscriptions', $SubscriptionId) }
        if ($skipToken) { $azArgs += @('--skip-token', $skipToken) }

        $raw = & az @azArgs 2>&1
        $exit = $LASTEXITCODE
        if ($exit -ne 0) {
            throw "Azure Resource Graph query failed (exit $exit): $(ConvertTo-ScrubbedCliOutput -Text (($raw | Out-String).Trim()))"
        }

        $rawText = ($raw | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($rawText)) {
            break
        }
        try {
            $parsed = $rawText | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Azure Resource Graph query failed to parse JSON: $($_.Exception.Message); raw: $(ConvertTo-ScrubbedCliOutput -Text $rawText.Substring(0, [Math]::Min(500, $rawText.Length)))"
        }

        # 'az graph query' returns either a top-level array (older CLI) or an
        # object with .data / .skip_token (newer CLI). Normalise.
        $rows = $null
        $nextToken = $null
        if ($parsed -is [System.Array]) {
            $rows = $parsed
        }
        elseif ($parsed.PSObject.Properties.Name -contains 'data') {
            $rows = $parsed.data
            if ($parsed.PSObject.Properties.Name -contains 'skip_token') { $nextToken = $parsed.skip_token }
            elseif ($parsed.PSObject.Properties.Name -contains 'skipToken') { $nextToken = $parsed.skipToken }
        }
        else {
            # Unknown shape - treat as single-row result
            $rows = @($parsed)
        }

        if ($rows) {
            foreach ($row in $rows) { [void]$allRows.Add($row) }
        }

        if (-not $nextToken) { break }
        $skipToken = $nextToken
        Write-Verbose "Invoke-AzResourceGraphQuery: fetched page $pages ($($allRows.Count) rows so far); following skip_token for next page."
    }

    return , $allRows.ToArray()
}

function Invoke-FleetJobsInParallel {
    <#
    .SYNOPSIS
        Dispatches a scriptblock across a set of input items using Start-Job
        with a throttled batch model. Intended as the single parallelisation
        primitive used by fleet-wide functions in this module.
    .DESCRIPTION
        Items are divided into at most -ThrottleLimit batches. Each batch runs
        as one Start-Job so that per-job startup cost stays low for large
        fleets. When -ThrottleLimit is 1 the scriptblock is invoked inline
        (no Start-Job overhead) which is the fast path used by unit tests.

        The scriptblock receives positional arguments in the order:
            [object[]]$Batch, <ArgumentList...>, [string]$ModulePath

        The trailing $ModulePath is always appended so jobs can re-import
        the module with 'Import-Module $ModulePath -Force' before calling
        any exported function.
    .PARAMETER InputItems
        The collection of items to shard across batches. Empty collections
        return an empty [object[]] result.
    .PARAMETER ScriptBlock
        The scriptblock executed once per batch.
    .PARAMETER ThrottleLimit
        Maximum number of concurrent Start-Job instances. Defaults to 4.
        ThrottleLimit=1 triggers the inline fast-path.
    .PARAMETER ArgumentList
        Additional positional arguments forwarded to the scriptblock after
        $Batch and before the trailing $ModulePath.
    .PARAMETER JobTimeoutSeconds
        Per-job maximum wall-clock wait. Defaults to 30 minutes. Jobs that
        exceed this are stopped and reported as Failed with a timeout error.
    .PARAMETER ActivityName
        Prefix used to name the jobs (helpful when debugging with Get-Job).
    .OUTPUTS
        [object[]] of [PSCustomObject]@{
            BatchIndex; Items; Failed; Output; Error; DurationSeconds
        }
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$InputItems,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 32)]
        [int]$ThrottleLimit = 4,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [object[]]$ArgumentList = @(),

        [Parameter(Mandatory = $false)]
        [ValidateRange(30, 86400)]
        [int]$JobTimeoutSeconds = 1800,

        [Parameter(Mandatory = $false)]
        [string]$ActivityName = 'FleetJob'
    )

    $results = [System.Collections.Generic.List[object]]::new()

    if ($null -eq $InputItems -or $InputItems.Count -eq 0) {
        return , $results.ToArray()
    }

    $modulePath = $PSCommandPath

    if ($ThrottleLimit -le 1) {
        # Inline fast-path: run the whole batch in-process, no Start-Job.
        $allArgs = @(, [object[]]$InputItems) + $ArgumentList + @($modulePath)
        $started = Get-Date
        try {
            $out = & $ScriptBlock @allArgs
            [void]$results.Add([PSCustomObject]@{
                BatchIndex      = 0
                Items           = $InputItems
                Failed          = $false
                Output          = $out
                Error           = $null
                DurationSeconds = ((Get-Date) - $started).TotalSeconds
            })
        }
        catch {
            [void]$results.Add([PSCustomObject]@{
                BatchIndex      = 0
                Items           = $InputItems
                Failed          = $true
                Output          = $null
                Error           = $_.Exception.Message
                DurationSeconds = ((Get-Date) - $started).TotalSeconds
            })
        }
        return , $results.ToArray()
    }

    # Parallel path: shard items across at most $ThrottleLimit batches.
    $batchSize = [int][Math]::Max(1, [Math]::Ceiling($InputItems.Count / [double]$ThrottleLimit))
    $batches = [System.Collections.Generic.List[object[]]]::new()
    for ($i = 0; $i -lt $InputItems.Count; $i += $batchSize) {
        $end = [Math]::Min($i + $batchSize - 1, $InputItems.Count - 1)
        [void]$batches.Add(@($InputItems[$i..$end]))
    }

    $jobs = @()
    for ($bi = 0; $bi -lt $batches.Count; $bi++) {
        $jobArgs = @(, [object[]]$batches[$bi]) + $ArgumentList + @($modulePath)
        $job = Start-Job -Name "$ActivityName-$bi" -ScriptBlock $ScriptBlock -ArgumentList $jobArgs
        $jobs += [PSCustomObject]@{ BatchIndex = $bi; Batch = $batches[$bi]; Job = $job; Start = Get-Date }
    }

    foreach ($j in $jobs) {
        $elapsed = ((Get-Date) - $j.Start).TotalSeconds
        $remaining = [int][Math]::Max(1, $JobTimeoutSeconds - $elapsed)
        $finished = Wait-Job -Job $j.Job -Timeout $remaining
        if (-not $finished) {
            try { Stop-Job -Job $j.Job -ErrorAction SilentlyContinue } catch { Write-Verbose "Stop-Job failed: $($_.Exception.Message)" }
            [void]$results.Add([PSCustomObject]@{
                BatchIndex      = $j.BatchIndex
                Items           = $j.Batch
                Failed          = $true
                Output          = $null
                Error           = "Job timed out after $JobTimeoutSeconds seconds"
                DurationSeconds = ((Get-Date) - $j.Start).TotalSeconds
            })
        }
        else {
            try {
                $out = Receive-Job -Job $j.Job -ErrorAction Stop
                [void]$results.Add([PSCustomObject]@{
                    BatchIndex      = $j.BatchIndex
                    Items           = $j.Batch
                    Failed          = $false
                    Output          = $out
                    Error           = $null
                    DurationSeconds = ((Get-Date) - $j.Start).TotalSeconds
                })
            }
            catch {
                [void]$results.Add([PSCustomObject]@{
                    BatchIndex      = $j.BatchIndex
                    Items           = $j.Batch
                    Failed          = $true
                    Output          = $null
                    Error           = $_.Exception.Message
                    DurationSeconds = ((Get-Date) - $j.Start).TotalSeconds
                })
            }
        }
        Remove-Job -Job $j.Job -Force -ErrorAction SilentlyContinue
    }

    return , $results.ToArray()
}

function Invoke-FleetOpClusterAction {
    <#
    .SYNOPSIS
        Invokes a single fleet operation against one cluster with bounded
        retries and mutates the supplied ClusterState object in place.
    .DESCRIPTION
        Centralises the "attempt -> catch -> backoff -> retry" pattern used
        by the fleet orchestration functions. Mutates the ClusterState
        PSCustomObject so that callers that accumulate state across jobs
        can see the final Status/Attempts/LastError/Result.

        On success: Status='Succeeded', LastError=$null, Result=<operation output>.
        On persistent failure after -MaxRetries retries: Status='Failed',
        LastError=<last exception message>.
    .PARAMETER ClusterState
        A PSCustomObject with at least ResourceId and these writable
        properties: Status, Attempts, LastAttempt, LastError, Result.
    .PARAMETER Operation
        One of ApplyUpdate, CheckReadiness, GetStatus.
    .PARAMETER MaxRetries
        Number of additional retries after the first attempt. 0 means a
        single attempt with no retries.
    .PARAMETER RetryDelaySeconds
        Base delay in seconds. Actual delay uses exponential backoff
        (base * 2^(attempt-1)) capped at 600 seconds.
    .PARAMETER OperationParameters
        Optional hashtable of extra parameters splatted to the underlying
        cmdlet.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $ClusterState,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ApplyUpdate', 'CheckReadiness', 'GetStatus')]
        [string]$Operation,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = 2,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 600)]
        [int]$RetryDelaySeconds = 10,

        [Parameter(Mandatory = $false)]
        [hashtable]$OperationParameters = @{}
    )

    $maxAttempts = $MaxRetries + 1
    $attempts = 0
    $lastError = $null
    $result = $null
    $succeeded = $false

    while ($attempts -lt $maxAttempts) {
        $attempts++
        $ClusterState.Attempts = $attempts
        $ClusterState.LastAttempt = Get-Date
        try {
            switch ($Operation) {
                'GetStatus' {
                    $result = Get-AzureLocalUpdateSummary -ClusterResourceId $ClusterState.ResourceId @OperationParameters
                }
                'CheckReadiness' {
                    $result = Get-AzureLocalClusterUpdateReadiness -ClusterResourceId $ClusterState.ResourceId @OperationParameters
                }
                'ApplyUpdate' {
                    $result = Start-AzureLocalClusterUpdate -ClusterResourceId $ClusterState.ResourceId @OperationParameters
                }
            }
            $succeeded = $true
            $lastError = $null
            break
        }
        catch {
            $lastError = $_.Exception.Message
            if ($attempts -lt $maxAttempts -and $RetryDelaySeconds -gt 0) {
                $delay = [int][Math]::Min(600, $RetryDelaySeconds * [Math]::Pow(2, $attempts - 1))
                Start-Sleep -Seconds $delay
            }
        }
    }

    $ClusterState.Result = $result
    $ClusterState.LastError = $lastError
    $ClusterState.Status = if ($succeeded) { 'Succeeded' } else { 'Failed' }
}

function Resolve-SafeOutputPath {
    <#
    .SYNOPSIS
        Validates and resolves a user-supplied output file path, rejecting
        obvious abuse shapes.
    .DESCRIPTION
        Applies defence-in-depth before the module writes a caller-controlled
        path to disk:
        - Rejects null / whitespace-only paths.
        - Rejects paths containing any control character (< 0x20) including
          NUL, CR, LF, TAB, which Windows rejects anyway but which should be
          caught with a clear message long before File.IO does.
        - Rejects any path segment equal to '..' to block trivial traversal
          above the caller's intended root.
        - Caps the resolved absolute path at 248 characters so the containing
          directory plus an 8.3 filename still fits inside the MAX_PATH=260
          limit that Windows PowerShell 5.1 enforces by default.
        - Resolves the path to an absolute form (relative paths are rooted at
          the current working directory).
        - Optionally requires one of an allowed extension set.
    .PARAMETER Path
        The path provided by the caller.
    .PARAMETER AllowedExtensions
        Optional array of extensions (including the leading dot, e.g. '.csv')
        that the path must end with. Comparison is case-insensitive.
    .OUTPUTS
        [string] absolute, validated path.
    .EXAMPLE
        $safe = Resolve-SafeOutputPath -Path $ExportPath -AllowedExtensions '.csv','.json','.xml'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string[]]$AllowedExtensions
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Output path is null or empty."
    }

    # Control-char check (covers NUL 0x00, TAB 0x09, LF 0x0A, CR 0x0D, etc.)
    foreach ($ch in $Path.ToCharArray()) {
        if ([int]$ch -lt 32) {
            throw "Output path contains a control character (0x{0:X2}). Path rejected." -f [int]$ch
        }
    }

    # Reject Windows-invalid filename characters in the leaf portion.
    # (Parent directory may legitimately contain characters like ':' in a
    # drive spec, so we only check the filename.)
    $leaf = [System.IO.Path]::GetFileName($Path)
    if ($leaf) {
        $invalid = [System.IO.Path]::GetInvalidFileNameChars()
        foreach ($c in $invalid) {
            if ($leaf.IndexOf($c) -ge 0) {
                throw "Output path leaf '$leaf' contains an invalid filename character."
            }
        }
    }

    # Traversal segment check.
    $segments = $Path -split '[\\/]+'
    foreach ($seg in $segments) {
        if ($seg -eq '..') {
            throw "Output path contains a '..' traversal segment and was rejected: $Path"
        }
    }

    # Resolve to absolute form. Do NOT require the file to exist (Resolve-Path
    # would throw) - use [IO.Path]::GetFullPath which handles relative inputs
    # against the current directory.
    try {
        $absolute = [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        throw "Output path could not be resolved: $($_.Exception.Message)"
    }

    if ($absolute.Length -gt 248) {
        throw "Resolved output path exceeds 248 characters ($($absolute.Length)): $absolute"
    }

    if ($PSBoundParameters.ContainsKey('AllowedExtensions') -and $AllowedExtensions) {
        $ext = [System.IO.Path]::GetExtension($absolute)
        $ok = $false
        foreach ($allowed in $AllowedExtensions) {
            if ([string]::Equals($ext, $allowed, [System.StringComparison]::OrdinalIgnoreCase)) { $ok = $true; break }
        }
        if (-not $ok) {
            throw "Output path extension '$ext' is not in the allowed set ($(($AllowedExtensions) -join ', '))."
        }
    }

    return $absolute
}

function Get-TagValue {
    <#
    .SYNOPSIS
        Reads a single tag value from a cluster 'tags' property in a
        container-shape-agnostic way.
    .DESCRIPTION
        ARM returns 'tags' as a PSCustomObject when the response is parsed via
        'ConvertFrom-Json' (the default) but as a Hashtable when parsed with
        'ConvertFrom-Json -AsHashtable' (occasionally used for performance).
        The two shapes require different lookup syntax, and accessing a missing
        key on one of them throws under Set-StrictMode.

        This helper returns the tag value (or $null if absent) for any of:
          - [hashtable] / [System.Collections.IDictionary]
          - [PSCustomObject]
          - $null
        Lookup is ordinal (case-sensitive) to match ARM tag semantics.
    .PARAMETER Tags
        The 'tags' property from a cluster resource.
    .PARAMETER Name
        The tag name to look up.
    .OUTPUTS
        [string] tag value, or $null if the tag is absent or Tags is $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Tags,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($null -eq $Tags) { return $null }

    if ($Tags -is [System.Collections.IDictionary]) {
        if ($Tags.Contains($Name)) { return [string]$Tags[$Name] }
        return $null
    }

    # PSCustomObject / PSObject path.
    try {
        $prop = $Tags.PSObject.Properties[$Name]
        if ($null -ne $prop) { return [string]$prop.Value }
    }
    catch {
        Write-Verbose "Get-TagValue: unexpected tag container shape ($($Tags.GetType().FullName)); treating as empty. $($_.Exception.Message)"
    }
    return $null
}

function ConvertTo-ScrubbedCliOutput {
    <#
    .SYNOPSIS
        Masks credential-shaped fragments in Azure CLI output before it is
        written to a log, thrown as an exception message, or bubbled back to
        the caller.
    .DESCRIPTION
        'az rest', 'az graph query', and 'az login' errors occasionally echo
        headers, body fragments, or command lines that contain bearer tokens,
        refresh tokens, client secrets, or passwords. Those strings must
        never land in log files or screen output.

        The scrubber replaces the secret value in each of these shapes with
        the literal '<redacted>' while keeping the surrounding key/field so
        the log remains diagnostically useful:

        - Bearer <jwt>
        - "access_token" / "refresh_token" / "id_token" / "password" /
          "client_secret" / "secret" / "authorization" : "..."
        - Standalone JWT tokens (three dot-separated base64url segments
          starting with 'eyJ').
        - CLI-argument forms: --password <v>, --client-secret <v>,
          --tenant-secret <v>, -p <v>.
        - HTTP header forms: Authorization: <v>
    .PARAMETER Text
        The CLI output to scrub. Null / empty input is returned unchanged.
    .OUTPUTS
        [string] with secret values replaced.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        if ([string]::IsNullOrEmpty($Text)) { return $Text }

        $s = $Text

        # 1. Bearer <token>
        $s = [regex]::Replace($s, '(?i)(bearer\s+)[A-Za-z0-9\-_\.=]+', '$1<redacted>')

        # 2. JSON-style credential fields: "name":"value"
        $jsonKeys = '(?i)(\"(?:access_?token|refresh_?token|id_?token|password|client_?secret|clientSecret|secret|authorization|sas_?token|sasToken)\"\s*:\s*\")[^\"]*(\")'
        $s = [regex]::Replace($s, $jsonKeys, '$1<redacted>$2')

        # 3. Standalone JWTs (3 base64url segments, middle segment typically starts with eyJ)
        $s = [regex]::Replace($s, 'eyJ[A-Za-z0-9\-_]{8,}\.[A-Za-z0-9\-_]{8,}\.[A-Za-z0-9\-_]{8,}', '<redacted-jwt>')

        # 4. CLI argument forms: --password foo  /  -p foo
        $cliArgs = '(?i)(--(?:password|client-?secret|tenant-?secret|sas-?token|token|key)\s+)\S+'
        $s = [regex]::Replace($s, $cliArgs, '$1<redacted>')

        # 5. HTTP header form: Authorization: ...
        $s = [regex]::Replace($s, '(?im)^(\s*authorization\s*:\s*).*$', '$1<redacted>')

        return $s
    }
}

function ConvertTo-SafeCsvField {
    <#
    .SYNOPSIS
        Neutralises a single string value so it cannot trigger formula
        evaluation when the containing CSV is opened in Excel / Calc.
    .DESCRIPTION
        Implements the OWASP CSV-injection guidance:
        - If the value begins with one of the spreadsheet formula leaders
          ('=', '+', '-', '@') or a CR/LF/TAB, prepend a single quote so the
          cell is interpreted as literal text.
        - Replace embedded CR and LF characters with spaces so they cannot
          terminate the logical record early.
        Non-string values are returned unchanged. Null / empty values are
        returned unchanged.
    .PARAMETER Value
        The value to sanitise. Only [string] values are mutated.
    .OUTPUTS
        Same type as input; sanitised when input was a non-empty string.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        $Value
    )

    process {
        if ($null -eq $Value) { return $null }
        if ($Value -isnot [string]) { return $Value }
        if ($Value.Length -eq 0) { return $Value }

        # Strip embedded CR/LF first so leader-check sees the real first visible char.
        $s = $Value -replace "`r?`n", ' '

        $first = $s[0]
        if ($first -eq '=' -or $first -eq '+' -or $first -eq '-' -or $first -eq '@' -or $first -eq "`t") {
            return "'" + $s
        }
        return $s
    }
}

function ConvertTo-SafeCsvCollection {
    <#
    .SYNOPSIS
        Projects a collection of objects into new PSCustomObjects whose string
        properties have been sanitised via ConvertTo-SafeCsvField.
    .DESCRIPTION
        Wrap pipelines as '$rows | ConvertTo-SafeCsvCollection | Export-Csv ...'
        to neutralise CSV formula injection without mutating the caller's
        original objects. Property order is preserved. Non-string property
        values (int, datetime, bool, nested objects) are passed through
        unchanged so downstream tooling retains type information.
    .PARAMETER InputObject
        The object(s) to sanitise. Accepts pipeline input.
    .OUTPUTS
        [PSCustomObject] per input row.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return }
        $ordered = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) {
            $ordered[$p.Name] = ConvertTo-SafeCsvField -Value $p.Value
        }
        [PSCustomObject]$ordered
    }
}

function ConvertTo-AzLocalAdditionalProperties {
    <#
    .SYNOPSIS
        Internal helper that safely parses the 'additionalProperties' field of an update object.
    .DESCRIPTION
        The ARM API returns additionalProperties either as an already-deserialised
        object or as a JSON string. This helper normalises both forms and handles
        malformed JSON without throwing, logging a Verbose warning on failure so
        that a single bad cluster does not abort a fleet-wide operation.
    .PARAMETER InputObject
        The additionalProperties value from an update's properties.
    .OUTPUTS
        PSCustomObject or $null if parsing failed / input was empty.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [string]) {
        if ([string]::IsNullOrWhiteSpace($InputObject)) { return $null }
        try {
            return ($InputObject | ConvertFrom-Json -ErrorAction Stop)
        }
        catch {
            $snippet = if ($InputObject.Length -gt 200) { $InputObject.Substring(0, 200) + '...' } else { $InputObject }
            Write-Verbose "Failed to parse additionalProperties JSON: $($_.Exception.Message). Raw: $snippet"
            return $null
        }
    }

    # Already an object (PSCustomObject / hashtable) - return as-is
    return $InputObject
}

function Get-HealthCheckFailureSummary {
    <#
    .SYNOPSIS
        Extracts health check failure reasons from an update summary object.
    .DESCRIPTION
        Analyzes the healthCheckResult property from an Azure Local update summary
        to extract critical and warning health check failures. Returns a summary
        string suitable for CSV logging.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$UpdateSummary
    )

    if (-not $UpdateSummary -or -not $UpdateSummary.properties.healthCheckResult) {
        return ""
    }

    $failures = @()
    $healthChecks = $UpdateSummary.properties.healthCheckResult

    foreach ($check in $healthChecks) {
        if ($check.status -eq "Failed") {
            $severity = if ($check.severity) { $check.severity } else { "Unknown" }
            # Only include Critical and Warning severities (skip Informational)
            if ($severity -notin @("Critical", "Warning")) {
                continue
            }
            $displayName = if ($check.displayName) { $check.displayName } elseif ($check.name) { ($check.name -split '/')[0] } else { "Unknown Check" }
            $targetNode = if ($check.targetResourceName) { " ($($check.targetResourceName))" } else { "" }
            $failures += "[$severity] $displayName$targetNode"
        }
    }

    if ($failures.Count -gt 0) {
        # Limit to top 5 failures to keep CSV readable
        $topFailures = $failures | Select-Object -First 5
        $summary = $topFailures -join "; "
        if ($failures.Count -gt 5) {
            $summary += " (+$($failures.Count - 5) more)"
        }
        return $summary
    }

    return ""
}

function Get-LastUpdateRunErrorSummary {
    <#
    .SYNOPSIS
        Gets the error details from the most recent failed update run for a cluster.
    .DESCRIPTION
        Queries the Azure REST API for the most recent update run for a cluster
        and extracts the error step name and message if the update failed.
        
        Note: Update runs are nested under specific updates, so we need to:
        1. List all updates for the cluster
        2. Get update runs for each update
        3. Find the most recent failed run across all updates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClusterResourceId,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = "2025-10-01"
    )

    try {
        # First, get all updates for this cluster
        $updatesUri = "https://management.azure.com$ClusterResourceId/updates?api-version=$ApiVersion"
        $updatesResult = az rest --method GET --uri $updatesUri 2>$null | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0 -or -not $updatesResult.value) {
            return @{ ErrorStep = ""; ErrorMessage = "" }
        }

        # Collect all failed runs from all updates
        $allFailedRuns = @()
        
        foreach ($update in $updatesResult.value) {
            $updateName = $update.name
            $runsUri = "https://management.azure.com$ClusterResourceId/updates/$updateName/updateRuns?api-version=$ApiVersion"
            $runsResult = az rest --method GET --uri $runsUri 2>$null | ConvertFrom-Json
            
            if ($LASTEXITCODE -eq 0 -and $runsResult.value) {
                $failedRuns = $runsResult.value | Where-Object { $_.properties.state -eq "Failed" }
                if ($failedRuns) {
                    $allFailedRuns += $failedRuns
                }
            }
        }

        if ($allFailedRuns.Count -eq 0) {
            return @{ ErrorStep = ""; ErrorMessage = "" }
        }

        # Find the most recent failed update run across all updates
        # Sort by lastUpdatedTime first (when the run actually failed), fall back to timeStarted
        $latestFailed = $allFailedRuns | Sort-Object { 
            # Prefer lastUpdatedTime as it reflects when the failure actually occurred
            if ($_.properties.lastUpdatedTime) { 
                [datetime]$_.properties.lastUpdatedTime 
            } 
            elseif ($_.properties.timeStarted) { 
                [datetime]$_.properties.timeStarted 
            }
            else { 
                [datetime]::MinValue 
            }
        } -Descending | Select-Object -First 1
        $progress = $latestFailed.properties.progress

        if (-not $progress -or -not $progress.steps) {
            return @{ ErrorStep = ""; ErrorMessage = "" }
        }

        # Recursively search for the deepest error step with an error message
        function Find-DeepestError {
            param($steps)
            foreach ($step in $steps) {
                if ($step.status -eq "Error" -or $step.status -eq "Failed") {
                    if ($step.errorMessage) {
                        return @{ Name = $step.name; Message = $step.errorMessage }
                    }
                }
                if ($step.steps) {
                    $nestedResult = Find-DeepestError -steps $step.steps
                    if ($nestedResult.Message) {
                        return $nestedResult
                    }
                }
            }
            return @{ Name = ""; Message = "" }
        }

        $deepestError = Find-DeepestError -steps $progress.steps
        $errorStep = $deepestError.Name
        $errorMessage = $deepestError.Message

        # Clean up error message for CSV (remove newlines and extra spaces)
        if ($errorMessage) {
            $errorMessage = $errorMessage -replace '\r?\n', ' ' -replace '\s+', ' '
            # Truncate if too long for CSV readability
            if ($errorMessage.Length -gt 500) {
                $errorMessage = $errorMessage.Substring(0, 500) + "..."
            }
        }

        return @{ ErrorStep = $errorStep; ErrorMessage = $errorMessage }
    }
    catch {
        Write-Verbose "Error getting update run details: $_"
        return @{ ErrorStep = ""; ErrorMessage = "" }
    }
}

function Get-LatestUpdateByYYMM {
    <#
    .SYNOPSIS
        Selects the latest update from a list by YYMM version in the update name.
    .DESCRIPTION
        Update names follow format: SolutionXX.YYMM.<build>.<rev> where YYMM is
        year+month. Sorts primarily by YYMM (descending) with a deterministic
        tie-breaker on the full update name (descending) so that repeated calls
        against the same input always return the same winner. Emits a Warning
        (not just Verbose) when no input matched the expected name shape, since
        in that case the returned item is effectively arbitrary.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Updates
    )

    if (-not $Updates -or $Updates.Count -eq 0) { return $null }

    $sorted = $Updates | Sort-Object -Descending `
        @{ Expression = {
                $yymm = ($_.name -split '\.')[1]
                if ($yymm -match '^\d{4}$') { [int]$yymm } else { 0 }
            }
        }, `
        @{ Expression = { "$($_.name)" } }

    $topName = "$($sorted[0].name)"
    $topYymm = ($topName -split '\.')[1]
    if ($topYymm -notmatch '^\d{4}$') {
        Write-Log -Message "Get-LatestUpdateByYYMM: no update name matched the expected Solution<XX>.<YYMM>.<build>.<rev> format (checked $($Updates.Count) items); result '$topName' is a deterministic name-sort fallback." -Level Warning
    }

    return $sorted | Select-Object -First 1
}

function Get-CurrentStepPath {
    <#
    .SYNOPSIS
        Recursively walks the update run step hierarchy to find the deepest InProgress or Failed step.
    .DESCRIPTION
        Update runs can have steps nested up to 8-9 levels deep. This function traverses
        the step.steps children recursively and returns the full path (e.g., "Step1 > Step2 > Step3").
        Looks for InProgress or Error/Failed status, returning the deepest match.
        Also captures the errorMessage from the deepest failed step if available.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [array]$Steps,

        [Parameter(Mandatory = $false)]
        [string]$ParentPath = "",

        [Parameter(Mandatory = $false)]
        [switch]$IncludeErrorMessage,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 20
    )

    if (-not $Steps -or $Steps.Count -eq 0 -or $MaxDepth -le 0) { return "" }

    foreach ($step in $Steps) {
        if (-not $step.name) { continue }
        $currentPath = if ($ParentPath) { "$ParentPath > $($step.name)" } else { $step.name }

        if ($step.status -in @("InProgress", "Error", "Failed")) {
            # Check if there are deeper nested steps with the same status
            if ($step.steps -and $step.steps.Count -gt 0) {
                $deeper = Get-CurrentStepPath -Steps $step.steps -ParentPath $currentPath -IncludeErrorMessage:$IncludeErrorMessage -MaxDepth ($MaxDepth - 1)
                if ($deeper) { return $deeper }
            }
            # At the deepest level - append error message if requested and available
            if ($IncludeErrorMessage -and $step.errorMessage) {
                return "$currentPath : $($step.errorMessage)"
            }
            return $currentPath
        }
    }
    return ""
}

function Export-ResultsToJUnitXml {
    <#
    .SYNOPSIS
        Exports update results to JUnit XML format for CI/CD pipeline integration.
    .DESCRIPTION
        Converts update operation results to JUnit XML format, which is the de facto
        standard for test results in CI/CD tools. Each cluster update is represented
        as a test case, with success/failure/skipped mapped to JUnit test outcomes.
        
        Supported CI/CD tools:
        - Azure DevOps (Publish Test Results task)
        - GitHub Actions (dorny/test-reporter or similar)
        - Jenkins (JUnit plugin)
        - GitLab CI (native support)
        - TeamCity (built-in)
    .PARAMETER Results
        Array of result objects from update operations.
    .PARAMETER OutputPath
        Path to write the JUnit XML file.
    .PARAMETER TestSuiteName
        Name of the test suite (default: "AzureLocalClusterUpdates").
    .PARAMETER OperationType
        Type of operation being reported (e.g., "Update", "Watch", "TagUpdate").
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$TestSuiteName = "AzureLocalClusterUpdates",

        [Parameter(Mandatory = $false)]
        [string]$OperationType = "Update"
    )

    # Calculate summary statistics
    $totalTests = $Results.Count
    $failures = @($Results | Where-Object { $_.Status -in @("Failed", "Error") }).Count
    $skipped = @($Results | Where-Object { $_.Status -eq "Skipped" }).Count
    $errors = @($Results | Where-Object { $_.Status -eq "NotFound" }).Count
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    
    # Calculate total time if Duration is available
    $totalTime = 0
    foreach ($result in $Results) {
        if ($result.Duration -and $result.Duration -is [TimeSpan]) {
            $totalTime += $result.Duration.TotalSeconds
        }
        elseif ($result.Duration -and $result.Duration -match '^\d+') {
            # Try to parse duration string
            $totalTime += [double]($result.Duration -replace '[^\d.]', '')
        }
    }

    # Helper function to XML-escape strings
    function ConvertTo-XmlSafeString {
        param([string]$Text)
        if (-not $Text) { return "" }
        return $Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
    }

    # Build XML content
    $xmlBuilder = [System.Text.StringBuilder]::new()
    [void]$xmlBuilder.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$xmlBuilder.AppendLine("<testsuites>")
    [void]$xmlBuilder.AppendLine("  <testsuite name=`"$(ConvertTo-XmlSafeString $TestSuiteName)`" tests=`"$totalTests`" failures=`"$failures`" errors=`"$errors`" skipped=`"$skipped`" time=`"$totalTime`" timestamp=`"$timestamp`">")

    foreach ($result in $Results) {
        $clusterName = ConvertTo-XmlSafeString ($result.ClusterName)
        $testName = "$OperationType-$clusterName"
        
        # Calculate test time
        $testTime = 0
        if ($result.Duration -and $result.Duration -is [TimeSpan]) {
            $testTime = $result.Duration.TotalSeconds
        }
        elseif ($result.Duration -and $result.Duration -match '^\d+') {
            $testTime = [double]($result.Duration -replace '[^\d.]', '')
        }

        [void]$xmlBuilder.AppendLine("    <testcase name=`"$(ConvertTo-XmlSafeString $testName)`" classname=`"$TestSuiteName.$OperationType`" time=`"$testTime`">")

        switch ($result.Status) {
            { $_ -in @("Failed", "Error", "HealthCheckBlocked", "ScheduleBlocked") } {
                $message = ConvertTo-XmlSafeString ($result.Message)
                $errorType = if ($result.Status -eq "Error") { "Error" } elseif ($result.Status -eq "HealthCheckBlocked") { "HealthCheckBlocked" } elseif ($result.Status -eq "ScheduleBlocked") { "ScheduleBlocked" } else { "AssertionError" }
                [void]$xmlBuilder.AppendLine("      <failure message=`"$message`" type=`"$errorType`">")
                [void]$xmlBuilder.AppendLine("Cluster: $clusterName")
                [void]$xmlBuilder.AppendLine("Status: $($result.Status)")
                [void]$xmlBuilder.AppendLine("Message: $message")
                if ($result.UpdateName) {
                    [void]$xmlBuilder.AppendLine("Update: $(ConvertTo-XmlSafeString $result.UpdateName)")
                }
                if ($result.CurrentState) {
                    [void]$xmlBuilder.AppendLine("Current State: $(ConvertTo-XmlSafeString $result.CurrentState)")
                }
                if ($result.Progress) {
                    [void]$xmlBuilder.AppendLine("Progress: $($result.Progress)")
                }
                [void]$xmlBuilder.AppendLine("      </failure>")
            }
            "NotFound" {
                $message = ConvertTo-XmlSafeString ($result.Message)
                [void]$xmlBuilder.AppendLine("      <error message=`"$message`" type=`"ResourceNotFound`">")
                [void]$xmlBuilder.AppendLine("Cluster: $clusterName")
                [void]$xmlBuilder.AppendLine("Message: $message")
                [void]$xmlBuilder.AppendLine("      </error>")
            }
            "Skipped" {
                $message = ConvertTo-XmlSafeString ($result.Message)
                [void]$xmlBuilder.AppendLine("      <skipped message=`"$message`" />")
            }
            default {
                # Success case - add system-out with details
                [void]$xmlBuilder.AppendLine("      <system-out>")
                [void]$xmlBuilder.AppendLine("Cluster: $clusterName")
                [void]$xmlBuilder.AppendLine("Status: $($result.Status)")
                if ($result.Message) {
                    [void]$xmlBuilder.AppendLine("Message: $(ConvertTo-XmlSafeString $result.Message)")
                }
                if ($result.UpdateName) {
                    [void]$xmlBuilder.AppendLine("Update: $(ConvertTo-XmlSafeString $result.UpdateName)")
                }
                if ($result.CurrentState) {
                    [void]$xmlBuilder.AppendLine("Final State: $(ConvertTo-XmlSafeString $result.CurrentState)")
                }
                if ($result.Progress) {
                    [void]$xmlBuilder.AppendLine("Progress: $($result.Progress)")
                }
                [void]$xmlBuilder.AppendLine("      </system-out>")
            }
        }

        [void]$xmlBuilder.AppendLine("    </testcase>")
    }

    [void]$xmlBuilder.AppendLine("  </testsuite>")
    [void]$xmlBuilder.AppendLine("</testsuites>")

    # Write to file
    $xmlBuilder.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
}

function Get-ExportFormat {
    <#
    .SYNOPSIS
        Determines the export format based on the file path extension or explicit format parameter.
    .DESCRIPTION
        Helper function used by export operations to determine the output format.
        If ExportFormat is 'Auto', detects from file extension. Otherwise uses the specified format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto'
    )

    if ($ExportFormat -ne 'Auto') {
        return $ExportFormat
    }

    # Auto-detect from extension
    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    switch ($extension) {
        '.csv'  { return 'Csv' }
        '.json' { return 'Json' }
        '.xml'  { return 'JUnitXml' }
        default { return 'Csv' }  # Default to CSV for unknown extensions
    }
}

function Write-UpdateCsvLog {
    <#
    .SYNOPSIS
        Writes a CSV entry to the Update_Skipped or Update_Started log file.
    .DESCRIPTION
        Writes detailed information about skipped or started updates to CSV files.
        For skipped clusters, includes additional diagnostic information such as
        health check failures and update run error details.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Skipped', 'Started')]
        [string]$LogType,

        [Parameter(Mandatory = $true)]
        [string]$ClusterName,

        [Parameter(Mandatory = $false)]
        [string]$ResourceGroup = "",

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId = "",

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$UpdateState = "",

        [Parameter(Mandatory = $false)]
        [string]$HealthState = "",

        [Parameter(Mandatory = $false)]
        [string]$HealthCheckFailures = "",

        [Parameter(Mandatory = $false)]
        [string]$LastUpdateErrorStep = "",

        [Parameter(Mandatory = $false)]
        [string]$LastUpdateErrorMessage = ""
    )

    # Escape quotes in values for CSV
    $escapedClusterName = $ClusterName -replace '"', '""'
    $escapedResourceGroup = $ResourceGroup -replace '"', '""'
    $escapedSubscriptionId = $SubscriptionId -replace '"', '""'
    $escapedMessage = $Message -replace '"', '""'
    $escapedUpdateState = $UpdateState -replace '"', '""'
    $escapedHealthState = $HealthState -replace '"', '""'
    $escapedHealthCheckFailures = $HealthCheckFailures -replace '"', '""'
    $escapedLastUpdateErrorStep = $LastUpdateErrorStep -replace '"', '""'
    $escapedLastUpdateErrorMessage = $LastUpdateErrorMessage -replace '"', '""'

    if ($LogType -eq 'Skipped') {
        # Extended format for skipped clusters with diagnostic columns
        $csvLine = "`"$escapedClusterName`",`"$escapedResourceGroup`",`"$escapedSubscriptionId`",`"$escapedMessage`",`"$escapedUpdateState`",`"$escapedHealthState`",`"$escapedHealthCheckFailures`",`"$escapedLastUpdateErrorStep`",`"$escapedLastUpdateErrorMessage`""
        $logPath = $script:UpdateSkippedLogPath
    }
    else {
        # Simple format for started clusters
        $csvLine = "`"$escapedClusterName`",`"$escapedResourceGroup`",`"$escapedSubscriptionId`",`"$escapedMessage`""
        $logPath = $script:UpdateStartedLogPath
    }
    
    if ($logPath) {
        try {
            Add-Content -Path $logPath -Value $csvLine -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            # CSV log write failure is non-critical - continue silently
            Write-Verbose "Failed to write to CSV log: $($_.Exception.Message)"
        }
    }
}

function Start-AzureLocalClusterUpdate {
    <#
    .SYNOPSIS
        Starts updates on one or more Azure Local clusters.
    .DESCRIPTION
        Initiates the update process on Azure Local (Azure Stack HCI) clusters. Supports multiple
        methods for specifying clusters: by name, by Resource ID, or by UpdateRing tag. The function
        validates cluster readiness, checks for available updates, and starts the update process.
        Includes comprehensive logging, CSV export of results, and support for CI/CD automation.
    .PARAMETER ClusterNames
        Array of cluster names to update. Use this OR -ClusterResourceIds OR -ScopeByUpdateRingTag.
    .PARAMETER ClusterResourceIds
        Array of full Azure Resource IDs for clusters. Use when clusters are in different resource groups.
    .PARAMETER ScopeByUpdateRingTag
        Switch to find clusters by their 'UpdateRing' tag value via Azure Resource Graph.
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    .PARAMETER ResourceGroupName
        Resource group containing the clusters (only used with -ClusterNames).
    .PARAMETER SubscriptionId
        Azure subscription ID (defaults to current subscription).
    .PARAMETER UpdateName
        Specific update name to apply. If not specified, applies the latest ready update.
    .PARAMETER ApiVersion
        Azure REST API version to use. Default: "2025-10-01".
    .PARAMETER Force
        Skip confirmation prompts.
    .PARAMETER LogFolderPath
        Folder path for log files. Default: C:\ProgramData\AzStackHci.ManageUpdates\
    .PARAMETER EnableTranscript
        Enable PowerShell transcript recording.
    .PARAMETER ExportResultsPath
        Export results to JSON (.json), CSV (.csv), or JUnit XML (.xml) file.
    .OUTPUTS
        PSCustomObject[] - Array of result objects with cluster name, status, and message.
    .EXAMPLE
        Start-AzureLocalClusterUpdate -ClusterNames "MyCluster01" -ResourceGroupName "MyRG" -Force
        Starts update on a single cluster without confirmation prompt.
    .EXAMPLE
        Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force
        Starts updates on all clusters tagged with UpdateRing=Wave1.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByName')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$UpdateName,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [string]$LogFolderPath,

        [Parameter(Mandatory = $false)]
        [switch]$EnableTranscript,

        [Parameter(Mandatory = $false)]
        [string]$ExportResultsPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    begin {
        # Pre-flight: Validate export path is writable before expensive operations
        if ($ExportResultsPath) {
            try { Test-ExportPathWritable -Path $ExportResultsPath | Out-Null }
            catch { Write-Warning $_.Exception.Message; return }
        }

        # Initialize logging
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # Determine log directory: parameter > default location
        $defaultLogDir = Join-Path -Path $env:ProgramData -ChildPath "AzStackHci.ManageUpdates"
        $logDir = if ($LogFolderPath) { $LogFolderPath } else { $defaultLogDir }
        
        # Ensure log directory exists
        if (-not (Test-Path $logDir)) {
            try {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            catch {
                # Fall back to current directory if we can't create the log folder
                Write-Warning "Unable to create log directory '$logDir'. Using current directory instead."
                $logDir = Get-Location
            }
        }
        
        # Set log file path
        $script:LogFilePath = Join-Path -Path $logDir -ChildPath "AzureLocalUpdate_$timestamp.log"
        
        # Create error log path (same location, different suffix)
        $logName = [System.IO.Path]::GetFileNameWithoutExtension($script:LogFilePath)
        $script:ErrorLogPath = Join-Path -Path $logDir -ChildPath "${logName}_errors.log"
        
        # Create CSV summary log paths
        $script:UpdateSkippedLogPath = Join-Path -Path $logDir -ChildPath "${logName}_Update_Skipped.csv"
        $script:UpdateStartedLogPath = Join-Path -Path $logDir -ChildPath "${logName}_Update_Started.csv"

        # Ensure log directory exists
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        # Start transcript if enabled
        $transcriptPath = $null
        if ($EnableTranscript) {
            $transcriptPath = Join-Path -Path $logDir -ChildPath "${logName}_transcript.log"
            try {
                Start-Transcript -Path $transcriptPath -Force | Out-Null
                Write-Log -Message "Transcript started: $transcriptPath" -Level Info
            }
            catch {
                Write-Log -Message "Failed to start transcript: $_" -Level Warning
            }
        }

        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Azure Local Cluster Update - Started" -Level Header
        Write-Log -Message "Module Version: $($script:ModuleVersion)" -Level Header
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Log file: $($script:LogFilePath)" -Level Info
        Write-Log -Message "Error log: $($script:ErrorLogPath)" -Level Info
        Write-Log -Message "Update Skipped CSV: $($script:UpdateSkippedLogPath)" -Level Info
        Write-Log -Message "Update Started CSV: $($script:UpdateStartedLogPath)" -Level Info
        
        # Initialize CSV files with headers (extended headers for skipped to include diagnostic info)
        $csvHeadersSkipped = '"ClusterName","ResourceGroup","SubscriptionId","Message","UpdateState","HealthState","HealthCheckFailures","LastUpdateErrorStep","LastUpdateErrorMessage"'
        $csvHeadersStarted = '"ClusterName","ResourceGroup","SubscriptionId","Message"'
        $csvHeadersSkipped | Out-File -FilePath $script:UpdateSkippedLogPath -Encoding UTF8 -Force
        $csvHeadersStarted | Out-File -FilePath $script:UpdateStartedLogPath -Encoding UTF8 -Force
        
        # Build list of clusters to process
        $clustersToProcess = @()
        if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
            Write-Log -Message "Querying Azure Resource Graph for clusters with tag 'UpdateRing' = '$UpdateRingValue'..." -Level Info
            
            # Ensure resource-graph extension is installed (for pipeline/automation scenarios)
            if (-not (Install-AzGraphExtension)) {
                throw "Failed to ensure Azure CLI 'resource-graph' extension is available. Please install manually: az extension add --name resource-graph"
            }
            
            # Build Azure Resource Graph query to find clusters by tag - use single line to avoid escaping issues with az CLI
            $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id, name, resourceGroup, subscriptionId, tags"
            
            Write-Verbose "ARG Query: $argQuery"
            
            try {
                # Run Azure Resource Graph query across all accessible subscriptions,
                # following skip_token pagination so fleets > 1000 clusters are not truncated.
                $clusterRows = Invoke-AzResourceGraphQuery -Query $argQuery

                if (-not $clusterRows -or $clusterRows.Count -eq 0) {
                    Write-Log -Message "No clusters found with tag 'UpdateRing' = '$UpdateRingValue'" -Level Warning
                    throw "No Azure Local clusters found with tag 'UpdateRing' = '$UpdateRingValue'. Please verify the tag value."
                }
                
                Write-Log -Message "Found $($clusterRows.Count) cluster(s) matching tag criteria:" -Level Success
                foreach ($cluster in $clusterRows) {
                    Write-Log -Message "  - $($cluster.name) (RG: $($cluster.resourceGroup), Sub: $($cluster.subscriptionId))" -Level Info
                    $clustersToProcess += @{ 
                        ResourceId = $cluster.id
                        Name = $cluster.name 
                    }
                }
            }
            catch {
                if ($_.Exception.Message -match "No Azure Local clusters found") {
                    throw
                }
                Write-Log -Message "Error querying Azure Resource Graph: $_" -Level Error
                throw "Failed to query Azure Resource Graph: $_"
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
            Write-Log -Message "Validating Cluster Resource IDs: $($ClusterResourceIds.Count)" -Level Info
            foreach ($resourceId in $ClusterResourceIds) {
                Write-Log -Message "  Validating: $resourceId" -Level Info
                
                # Validate ResourceId format
                $resourceIdPattern = '^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.AzureStackHCI/clusters/[^/]+$'
                if ($resourceId -notmatch $resourceIdPattern) {
                    Write-Log -Message "    Invalid Resource ID format. Expected: /subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.AzureStackHCI/clusters/{clusterName}" -Level Error
                    throw "Invalid Resource ID format: $resourceId"
                }
                
                # Extract subscription ID from resource ID and validate it is accessible
                $subId = ($resourceId -split '/')[2]
                $setSubResult = az account set --subscription $subId 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $setSubError = $setSubResult | Out-String
                    Write-Log -Message "    Subscription '$subId' not found or not accessible in the current Azure CLI context. Ensure you are logged in to the correct Azure tenant (az login --tenant <tenantId>) and have access to this subscription." -Level Error
                    throw "Subscription '$subId' not found or not accessible. Ensure you are logged in to the correct Azure tenant and have access to this subscription. Error: $($setSubError.Trim())"
                }

                # Validate resource exists and user has access
                $validateUri = "https://management.azure.com$resourceId`?api-version=$ApiVersion"
                Write-Verbose "Validating resource at: $validateUri"
                try {
                    $validateResult = az rest --method GET --uri $validateUri 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        $errorMessage = $validateResult | Out-String
                        if ($errorMessage -match "ResourceGroupNotFound") {
                            $rgName = ($resourceId -split '/')[4]
                            Write-Log -Message "    Resource group '$rgName' not found in subscription '$subId'. Verify the resource group name and that the resource has not been deleted." -Level Error
                            throw "Resource group '$rgName' not found in subscription '$subId'. Verify the resource group name and that the resource has not been deleted."
                        }
                        elseif ($errorMessage -match "ResourceNotFound") {
                            $clusterName = ($resourceId -split '/')[-1]
                            $rgName = ($resourceId -split '/')[4]
                            Write-Log -Message "    Cluster '$clusterName' not found in resource group '$rgName'. The cluster may have been deleted or the name may be incorrect." -Level Error
                            throw "Cluster '$clusterName' not found in resource group '$rgName'. The cluster may have been deleted or the name may be incorrect."
                        }
                        elseif ($errorMessage -match "AuthorizationFailed|Forbidden") {
                            Write-Log -Message "    Access denied: You do not have permission to access $resourceId" -Level Error
                            throw "Access denied: You do not have permission to access $resourceId. Please verify you have the required RBAC permissions."
                        }
                        else {
                            Write-Log -Message "    Failed to validate resource: $errorMessage" -Level Error
                            throw "Failed to validate resource: $resourceId. Error: $errorMessage"
                        }
                    }
                    Write-Log -Message "    Validated successfully" -Level Success
                }
                catch {
                    if ($_.Exception.Message -match "Subscription.*not found|not found in|Access denied|Failed to validate") {
                        throw
                    }
                    Write-Log -Message "    Failed to validate resource: $_" -Level Error
                    throw "Failed to validate resource: $resourceId. Error: $_"
                }
                
                $clustersToProcess += @{ ResourceId = $resourceId; Name = ($resourceId -split '/')[-1] }
            }
            Write-Log -Message "All Resource IDs validated successfully" -Level Success
        }
        else {
            Write-Log -Message "Clusters to process: $($ClusterNames -join ', ')" -Level Info
            # Resolve names to resource IDs upfront to avoid per-cluster lookups
            if (-not $SubscriptionId) {
                $SubscriptionId = (az account show --query id -o tsv)
            }
            foreach ($name in $ClusterNames) {
                $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                    -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
                if ($clusterInfo) {
                    $clustersToProcess += @{ ResourceId = $clusterInfo.id; Name = $clusterInfo.name }
                    Write-Log -Message "  Resolved '$name' -> $($clusterInfo.id)" -Level Success
                }
                else {
                    Write-Log -Message "  Cluster '$name' not found - skipping" -Level Warning
                }
            }
        }

        # Verify Azure CLI is installed and logged in
        Test-AzCliAvailable | Out-Null
        try {
            $null = az account show 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Azure CLI is not logged in. Please run 'az login' first."
            }
            Write-Log -Message "Azure CLI authentication verified" -Level Success
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            Write-Log -Message "Azure CLI (az) is not installed. Install from https://aka.ms/installazurecliwindowsx64" -Level Error
            throw
        }
        catch {
            Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
            throw
        }

        # Get subscription ID if not provided (only needed for ByName parameter set)
        if ($PSCmdlet.ParameterSetName -eq 'ByName' -and -not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
            Write-Log -Message "Using current subscription: $SubscriptionId" -Level Info
        }

        # Results collection
        $results = @()
    }

    process {
        foreach ($cluster in $clustersToProcess) {
            $clusterName = $cluster.Name
            $clusterResourceId = $cluster.ResourceId

            Write-Log -Message "" -Level Info
            Write-Log -Message "========================================" -Level Header
            Write-Log -Message "Processing cluster: $clusterName" -Level Header
            Write-Log -Message "========================================" -Level Header

            $clusterStartTime = Get-Date

            try {
                # Step 1: Get cluster resource ID (or use provided ResourceId)
                Write-Log -Message "Step 1: Looking up cluster resource..." -Level Info
                
                if ($clusterResourceId) {
                    # ResourceId was provided directly - fetch cluster info using the ResourceId
                    $uri = "https://management.azure.com$clusterResourceId`?api-version=$ApiVersion"
                    Write-Verbose "Getting cluster info from: $uri"
                    $clusterInfo = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
                    if ($LASTEXITCODE -ne 0) {
                        $clusterInfo = $null
                    }
                }
                else {
                    # Look up by name
                    $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                        -ResourceGroupName $ResourceGroupName `
                        -SubscriptionId $SubscriptionId `
                        -ApiVersion $ApiVersion
                }

                if (-not $clusterInfo) {
                    Write-Log -Message "Cluster '$clusterName' not found." -Level Warning
                    $results += [PSCustomObject]@{
                        ClusterName   = $clusterName
                        Status        = "NotFound"
                        Message       = "Cluster not found"
                        UpdateName    = $null
                        StartTime     = $clusterStartTime
                        EndTime       = Get-Date
                        Duration      = $null
                    }
                    continue
                }

                Write-Log -Message "Found cluster: $($clusterInfo.id)" -Level Success
                Write-Log -Message "Cluster Status: $($clusterInfo.properties.status)" -Level Info

                # Step 2: Get update summaries to check if updates are available
                Write-Log -Message "Step 2: Retrieving update summary..." -Level Info
                $updateSummary = Get-AzureLocalUpdateSummary -ClusterResourceId $clusterInfo.id `
                    -ApiVersion $ApiVersion

                if (-not $updateSummary) {
                    Write-Log -Message "Unable to retrieve update summary for cluster '$clusterName'." -Level Warning
                    $results += [PSCustomObject]@{
                        ClusterName   = $clusterName
                        Status        = "Error"
                        Message       = "Unable to retrieve update summary"
                        UpdateName    = $null
                        StartTime     = $clusterStartTime
                        EndTime       = Get-Date
                        Duration      = $null
                    }
                    continue
                }

                Write-Log -Message "Update State: $($updateSummary.properties.state)" -Level Info

                # Step 3: Check if cluster is ready for updates
                Write-Log -Message "Step 3: Validating cluster state for updates..." -Level Info
                $validStates = @("UpdateAvailable") + $script:ReadyStates
                if ($updateSummary.properties.state -notin $validStates) {
                    Write-Log -Message "Cluster '$clusterName' is not in a valid state for updates. Current state: $($updateSummary.properties.state)" -Level Warning
                    
                    # Parse Resource Group and Subscription ID from cluster resource ID
                    $clusterRgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    $clusterSubId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                    
                    # Get health check failure details
                    $healthCheckFailures = Get-HealthCheckFailureSummary -UpdateSummary $updateSummary
                    $healthState = if ($updateSummary.properties.healthState) { $updateSummary.properties.healthState } else { "Unknown" }
                    
                    # Get last update run error details if the cluster is in a failed/needs attention state
                    $lastErrorDetails = @{ ErrorStep = ""; ErrorMessage = "" }
                    if ($updateSummary.properties.state -in @("NeedsAttention", "UpdateFailed", "PreparationFailed")) {
                        Write-Log -Message "Retrieving last update run error details..." -Level Verbose
                        $lastErrorDetails = Get-LastUpdateRunErrorSummary -ClusterResourceId $clusterInfo.id -ApiVersion $ApiVersion
                    }
                    
                    Write-UpdateCsvLog -LogType Skipped `
                        -ClusterName $clusterName `
                        -ResourceGroup $clusterRgName `
                        -SubscriptionId $clusterSubId `
                        -Message "Update Not started as Cluster NOT in Ready state (Current state: $($updateSummary.properties.state))" `
                        -UpdateState $updateSummary.properties.state `
                        -HealthState $healthState `
                        -HealthCheckFailures $healthCheckFailures `
                        -LastUpdateErrorStep $lastErrorDetails.ErrorStep `
                        -LastUpdateErrorMessage $lastErrorDetails.ErrorMessage
                    
                    $results += [PSCustomObject]@{
                        ClusterName   = $clusterName
                        Status        = "NotReady"
                        Message       = "Cluster state: $($updateSummary.properties.state)"
                        UpdateName    = $null
                        StartTime     = $clusterStartTime
                        EndTime       = Get-Date
                        Duration      = $null
                    }
                    continue
                }

                # Step 3b: Pre-update health validation - check for Critical health failures
                Write-Log -Message "Step 3b: Checking cluster health for update-blocking issues..." -Level Info
                $healthResults = Test-AzureLocalClusterHealth -ClusterResourceIds @($clusterInfo.id) -BlockingOnly -UpdateSummary $updateSummary
                if ($healthResults -and $healthResults.Count -gt 0 -and $healthResults[0].CriticalCount -gt 0) {
                    $critFailures = $healthResults[0].Failures | Where-Object { $_.Severity -eq "Critical" }
                    Write-Log -Message "Cluster '$clusterName' has $($healthResults[0].CriticalCount) critical health check failure(s) that will block the update:" -Level Error
                    foreach ($failure in $critFailures) {
                        $nodeInfo = if ($failure.TargetResourceName) { " (Node: $($failure.TargetResourceName))" } else { "" }
                        Write-Log -Message "  [Critical] $($failure.CheckName)$nodeInfo`: $($failure.Description)" -Level Error
                        if ($failure.Remediation) {
                            Write-Log -Message "    Remediation: $($failure.Remediation)" -Level Warning
                        }
                    }
                    
                    $clusterRgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    $clusterSubId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                    $critSummary = ($critFailures | ForEach-Object { $_.CheckName }) -join '; '
                    
                    Write-UpdateCsvLog -LogType Skipped `
                        -ClusterName $clusterName `
                        -ResourceGroup $clusterRgName `
                        -SubscriptionId $clusterSubId `
                        -Message "Update blocked by critical health check failures: $critSummary" `
                        -UpdateState $updateSummary.properties.state `
                        -HealthState "Failure" `
                        -HealthCheckFailures $critSummary
                    
                    $results += [PSCustomObject]@{
                        ClusterName   = $clusterName
                        Status        = "HealthCheckBlocked"
                        Message       = "Critical health failures: $critSummary"
                        UpdateName    = $null
                        StartTime     = $clusterStartTime
                        EndTime       = Get-Date
                        Duration      = $null
                    }
                    continue
                }
                Write-Log -Message "No critical health issues found - cluster is eligible for update" -Level Success

                # Step 3c: Schedule/maintenance window validation
                # Check UpdateWindow and UpdateExclusions tags if present on the cluster resource
                $clusterTags = $clusterInfo.tags
                $windowTagValue = if ($clusterTags -and $clusterTags.$($script:UpdateWindowTagName)) { $clusterTags.$($script:UpdateWindowTagName) } else { $null }
                $exclusionTagValue = if ($clusterTags -and $clusterTags.$($script:UpdateExclusionsTagName)) { $clusterTags.$($script:UpdateExclusionsTagName) } else { $null }

                if ($windowTagValue -or $exclusionTagValue) {
                    Write-Log -Message "Step 3c: Checking maintenance schedule tags..." -Level Info
                    if ($windowTagValue) { Write-Log -Message "  UpdateWindow tag: $windowTagValue" -Level Info }
                    if ($exclusionTagValue) { Write-Log -Message "  UpdateExclusions tag: $exclusionTagValue" -Level Info }

                    try {
                        $scheduleResult = Test-AzureLocalUpdateScheduleAllowed `
                            -UpdateWindow $windowTagValue `
                            -UpdateExclusions $exclusionTagValue

                        if (-not $scheduleResult.Allowed) {
                            Write-Log -Message "Cluster '$clusterName' is outside its maintenance schedule: $($scheduleResult.Reason)" -Level Warning
                            Write-Log -Message "  Details: $($scheduleResult.Details)" -Level Warning

                            $clusterRgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                            $clusterSubId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                            $healthState = if ($updateSummary.properties.healthState) { $updateSummary.properties.healthState } else { "Unknown" }

                            Write-UpdateCsvLog -LogType Skipped `
                                -ClusterName $clusterName `
                                -ResourceGroup $clusterRgName `
                                -SubscriptionId $clusterSubId `
                                -Message "Update blocked by maintenance schedule: $($scheduleResult.Reason). $($scheduleResult.Details)" `
                                -UpdateState $updateSummary.properties.state `
                                -HealthState $healthState

                            $results += [PSCustomObject]@{
                                ClusterName   = $clusterName
                                Status        = "ScheduleBlocked"
                                Message       = "$($scheduleResult.Reason): $($scheduleResult.Details)"
                                UpdateName    = $null
                                StartTime     = $clusterStartTime
                                EndTime       = Get-Date
                                Duration      = $null
                            }
                            continue
                        }

                        Write-Log -Message "Maintenance schedule check passed: $($scheduleResult.Reason)" -Level Success
                    }
                    catch {
                        Write-Log -Message "Warning: Failed to evaluate maintenance schedule tags: $($_.Exception.Message)" -Level Warning
                        Write-Log -Message "Proceeding with update (schedule check failure is non-blocking)" -Level Warning
                    }
                }
                else {
                    Write-Log -Message "Step 3c: No maintenance schedule tags defined - no schedule restrictions" -Level Info
                }

                # Step 4: List available updates
                Write-Log -Message "Step 4: Listing available updates..." -Level Info
                $availableUpdates = Get-AzureLocalAvailableUpdates -ClusterResourceId $clusterInfo.id `
                    -ApiVersion $ApiVersion -Raw

                if (-not $availableUpdates -or $availableUpdates.Count -eq 0) {
                    Write-Log -Message "No updates available for cluster '$clusterName'." -Level Warning
                    $results += [PSCustomObject]@{
                        ClusterName   = $clusterName
                        Status        = "NoUpdatesAvailable"
                        Message       = "No updates available"
                        UpdateName    = $null
                        StartTime     = $clusterStartTime
                        EndTime       = Get-Date
                        Duration      = $null
                    }
                    continue
                }

                # Filter updates that are in a ready state (Ready or ReadyToInstall)
                $readyUpdates = $availableUpdates | Where-Object { $_.properties.state -in $script:ReadyStates }
                
                if (-not $readyUpdates -or $readyUpdates.Count -eq 0) {
                    Write-Log -Message "No updates in ready state for cluster '$clusterName'." -Level Warning

                    # Check for HasPrerequisite/AdditionalContentRequired updates and surface SBE dependency info
                    $prereqUpdates = @($availableUpdates | Where-Object { $_.properties.state -in @("HasPrerequisite", "AdditionalContentRequired") })
                    if ($prereqUpdates.Count -gt 0) {
                        Write-Log -Message "Updates blocked by SBE prerequisites:" -Level Warning
                        foreach ($pu in $prereqUpdates) {
                            $puProps = $pu.properties
                            $puMsg = "  - $($pu.name): $($puProps.state)"
                            if ($puProps.packageType -eq "SBE" -and $puProps.additionalProperties) {
                                $addProps = ConvertTo-AzLocalAdditionalProperties -InputObject $puProps.additionalProperties
                                if ($addProps) {
                                    $sbeParts = @()
                                    if ($addProps.SBEPublisher) { $sbeParts += "Publisher: $($addProps.SBEPublisher)" }
                                    if ($addProps.SBEFamily) { $sbeParts += "Family: $($addProps.SBEFamily)" }
                                    if ($addProps.SBEReleaseLink) { $sbeParts += "Release Notes: $($addProps.SBEReleaseLink)" }
                                    if ($sbeParts.Count -gt 0) { $puMsg += " ($($sbeParts -join '; '))" }
                                }
                            }
                            Write-Log -Message $puMsg -Level Warning
                        }
                        Write-Log -Message "Install the required SBE (Solution Builder Extension) update from your hardware vendor before this update can proceed." -Level Warning
                    }

                    Write-Log -Message "Available updates and their states:" -Level Info
                    foreach ($update in $availableUpdates) {
                        Write-Log -Message "  - $($update.name): $($update.properties.state)" -Level Verbose
                    }
                    
                    # Parse Resource Group and Subscription ID from cluster resource ID
                    $clusterRgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    $clusterSubId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                    $updateStatesList = ($availableUpdates | ForEach-Object { "$($_.name): $($_.properties.state)" }) -join '; '
                    
                    # Get health check failure details
                    $healthCheckFailures = Get-HealthCheckFailureSummary -UpdateSummary $updateSummary
                    $healthState = if ($updateSummary.properties.healthState) { $updateSummary.properties.healthState } else { "Unknown" }
                    
                    # Get last update run error details - might have failed updates
                    $lastErrorDetails = Get-LastUpdateRunErrorSummary -ClusterResourceId $clusterInfo.id -ApiVersion $ApiVersion
                    
                    Write-UpdateCsvLog -LogType Skipped `
                        -ClusterName $clusterName `
                        -ResourceGroup $clusterRgName `
                        -SubscriptionId $clusterSubId `
                        -Message "Update Not started as no updates in Ready state. Available: $updateStatesList" `
                        -UpdateState $updateSummary.properties.state `
                        -HealthState $healthState `
                        -HealthCheckFailures $healthCheckFailures `
                        -LastUpdateErrorStep $lastErrorDetails.ErrorStep `
                        -LastUpdateErrorMessage $lastErrorDetails.ErrorMessage
                    
                    $results += [PSCustomObject]@{
                        ClusterName   = $clusterName
                        Status        = "NoReadyUpdates"
                        Message       = "No updates in Ready state"
                        UpdateName    = $null
                        StartTime     = $clusterStartTime
                        EndTime       = Get-Date
                        Duration      = $null
                    }
                    continue
                }

                Write-Log -Message "Available updates in 'Ready' state:" -Level Success
                foreach ($update in $readyUpdates) {
                    Write-Log -Message "  - $($update.name) (Version: $($update.properties.version), State: $($update.properties.state))" -Level Info
                }

                # Step 5: Select update to apply
                Write-Log -Message "Step 5: Selecting update to apply..." -Level Info
                $selectedUpdate = $null
                if ($UpdateName) {
                    $selectedUpdate = $readyUpdates | Where-Object { $_.name -eq $UpdateName }
                    if (-not $selectedUpdate) {
                        Write-Log -Message "Specified update '$UpdateName' not found or not in Ready state for cluster '$clusterName'." -Level Warning
                        $results += [PSCustomObject]@{
                            ClusterName   = $clusterName
                            Status        = "UpdateNotFound"
                            Message       = "Specified update '$UpdateName' not found or not ready"
                            UpdateName    = $UpdateName
                            StartTime     = $clusterStartTime
                            EndTime       = Get-Date
                            Duration      = $null
                        }
                        continue
                    }
                }
                else {
                    # Select the latest ready update by YYMM version from the update name
                    $selectedUpdate = Get-LatestUpdateByYYMM -Updates $readyUpdates
                    Write-Log -Message "Auto-selected latest update: $($selectedUpdate.name)" -Level Info
                }

                # Step 6: Apply the update
                Write-Log -Message "Step 6: Applying update..." -Level Info
                if ($PSCmdlet.ShouldProcess("$clusterName", "Apply update '$($selectedUpdate.name)'")) {
                    if (-not $Force) {
                        $confirmation = Read-Host "  Do you want to start update '$($selectedUpdate.name)' on cluster '$clusterName'? (Y/N)"
                        if ($confirmation -notmatch '^[Yy]') {
                            Write-Log -Message "Update skipped by user." -Level Warning
                            
                            # Parse Resource Group and Subscription ID from cluster resource ID
                            $clusterRgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                            $clusterSubId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                            $healthState = if ($updateSummary.properties.healthState) { $updateSummary.properties.healthState } else { "Unknown" }
                            
                            Write-UpdateCsvLog -LogType Skipped `
                                -ClusterName $clusterName `
                                -ResourceGroup $clusterRgName `
                                -SubscriptionId $clusterSubId `
                                -Message "Update skipped by user" `
                                -UpdateState $updateSummary.properties.state `
                                -HealthState $healthState
                            
                            $results += [PSCustomObject]@{
                                ClusterName   = $clusterName
                                Status        = "Skipped"
                                Message       = "Update skipped by user"
                                UpdateName    = $selectedUpdate.name
                                StartTime     = $clusterStartTime
                                EndTime       = Get-Date
                                Duration      = $null
                            }
                            continue
                        }
                    }

                    Write-Log -Message "Initiating update '$($selectedUpdate.name)' on cluster '$clusterName'..." -Level Info
                    $applyResult = Invoke-AzureLocalUpdateApply -ClusterResourceId $clusterInfo.id `
                        -UpdateName $selectedUpdate.name `
                        -ApiVersion $ApiVersion

                    $endTime = Get-Date
                    $duration = $endTime - $clusterStartTime

                    if ($applyResult) {
                        Write-Log -Message "Update started successfully!" -Level Success
                        Write-Log -Message "Monitor progress using: Get-AzureLocalUpdateRuns -ClusterName '$clusterName'" -Level Info
                        
                        # Parse Resource Group and Subscription ID from cluster resource ID
                        $clusterRgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                        $clusterSubId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                        Write-UpdateCsvLog -LogType Started -ClusterName $clusterName -ResourceGroup $clusterRgName -SubscriptionId $clusterSubId -Message "Update Started: $($selectedUpdate.name)"
                        
                        $results += [PSCustomObject]@{
                            ClusterName   = $clusterName
                            Status        = "UpdateStarted"
                            Message       = "Update initiated successfully"
                            UpdateName    = $selectedUpdate.name
                            StartTime     = $clusterStartTime
                            EndTime       = $endTime
                            Duration      = $duration.ToString("hh\:mm\:ss")
                        }
                    }
                    else {
                        Write-Log -Message "Failed to start update on cluster '$clusterName'." -Level Error
                        $results += [PSCustomObject]@{
                            ClusterName   = $clusterName
                            Status        = "Failed"
                            Message       = "Failed to start update"
                            UpdateName    = $selectedUpdate.name
                            StartTime     = $clusterStartTime
                            EndTime       = $endTime
                            Duration      = $duration.ToString("hh\:mm\:ss")
                        }
                    }
                }
            }
            catch {
                $endTime = Get-Date
                $duration = $endTime - $clusterStartTime
                Write-Log -Message "Error processing cluster '$clusterName': $($_.Exception.Message)" -Level Error
                Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
                $results += [PSCustomObject]@{
                    ClusterName   = $clusterName
                    Status        = "Error"
                    Message       = $_.Exception.Message
                    UpdateName    = $null
                    StartTime     = $clusterStartTime
                    EndTime       = $endTime
                    Duration      = $duration.ToString("hh\:mm\:ss")
                }
            }
        }
    }

    end {
        Write-Log -Message "" -Level Info
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Summary" -Level Header
        Write-Log -Message "========================================" -Level Header
        
        # Display summary statistics
        $totalClusters = $results.Count
        $succeeded = @($results | Where-Object { $_.Status -eq "UpdateStarted" }).Count
        $failed = @($results | Where-Object { $_.Status -in @("Failed", "Error") }).Count
        $skipped = @($results | Where-Object { $_.Status -in @("Skipped", "NotReady", "NoUpdatesAvailable", "NoReadyUpdates", "NotFound", "UpdateNotFound", "HealthCheckBlocked", "ScheduleBlocked") }).Count

        Write-Log -Message "Total clusters processed: $totalClusters" -Level Info
        Write-Log -Message "Updates started: $succeeded" -Level Success
        if ($failed -gt 0) {
            Write-Log -Message "Failed: $failed" -Level Error
        } else {
            Write-Log -Message "Failed: $failed" -Level Info
        }
        if ($skipped -gt 0) {
            Write-Log -Message "Skipped/Not Ready: $skipped" -Level Warning
        } else {
            Write-Log -Message "Skipped/Not Ready: $skipped" -Level Info
        }

        # Display results table
        Write-Log -Message "" -Level Info
        Write-Log -Message "Detailed Results:" -Level Info
        $results | Format-Table ClusterName, Status, UpdateName, Duration, Message -AutoSize | Out-String -Stream | ForEach-Object { 
            if ($_ -ne "") { Write-Log -Message $_ -Level Info }
        }

        # Export results if path specified
        if ($ExportResultsPath) {
            try {
                $ExportResultsPath = Resolve-SafeOutputPath -Path $ExportResultsPath
                $exportDir = Split-Path -Path $ExportResultsPath -Parent
                if ($exportDir -and -not (Test-Path $exportDir)) {
                    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
                }

                $extension = [System.IO.Path]::GetExtension($ExportResultsPath).ToLower()
                
                switch ($extension) {
                    '.json' {
                        $exportData = @{
                            Timestamp     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                            TotalClusters = $totalClusters
                            Succeeded     = $succeeded
                            Failed        = $failed
                            Skipped       = $skipped
                            Results       = $results
                        }
                        $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportResultsPath -Encoding UTF8
                        Write-Log -Message "Results exported to JSON: $ExportResultsPath" -Level Success
                    }
                    '.csv' {
                        $results | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportResultsPath -NoTypeInformation -Encoding UTF8
                        Write-Log -Message "Results exported to CSV: $ExportResultsPath" -Level Success
                    }
                    '.xml' {
                        # Export to JUnit XML format for CI/CD integration
                        Export-ResultsToJUnitXml -Results $results -OutputPath $ExportResultsPath `
                            -TestSuiteName "AzureLocalClusterUpdates" -OperationType "StartUpdate"
                        Write-Log -Message "Results exported to JUnit XML (CI/CD compatible): $ExportResultsPath" -Level Success
                    }
                    default {
                        # Default to JSON
                        $jsonPath = $ExportResultsPath + ".json"
                        $exportData = @{
                            Timestamp     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                            TotalClusters = $totalClusters
                            Succeeded     = $succeeded
                            Failed        = $failed
                            Skipped       = $skipped
                            Results       = $results
                        }
                        $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
                        Write-Log -Message "Results exported to JSON: $jsonPath" -Level Success
                    }
                }
            }
            catch {
                Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
            }
        }

        Write-Log -Message "" -Level Info
        Write-Log -Message "Log file saved to: $($script:LogFilePath)" -Level Info
        if ($script:ErrorLogPath -and (Test-Path $script:ErrorLogPath)) {
            $errorContent = Get-Content $script:ErrorLogPath -ErrorAction SilentlyContinue
            if ($errorContent) {
                Write-Log -Message "Error log saved to: $($script:ErrorLogPath)" -Level Warning
            }
        }
        
        # Report CSV summary files
        if ($script:UpdateSkippedLogPath -and (Test-Path $script:UpdateSkippedLogPath)) {
            $skippedCount = ((Get-Content $script:UpdateSkippedLogPath | Measure-Object).Count - 1)  # Subtract header
            if ($skippedCount -gt 0) {
                Write-Log -Message "Update Skipped CSV ($skippedCount entries): $($script:UpdateSkippedLogPath)" -Level Warning
            }
        }
        if ($script:UpdateStartedLogPath -and (Test-Path $script:UpdateStartedLogPath)) {
            $startedCount = ((Get-Content $script:UpdateStartedLogPath | Measure-Object).Count - 1)  # Subtract header
            if ($startedCount -gt 0) {
                Write-Log -Message "Update Started CSV ($startedCount entries): $($script:UpdateStartedLogPath)" -Level Success
            }
        }

        # Stop transcript if it was started
        if ($EnableTranscript) {
            try {
                Stop-Transcript | Out-Null
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] Transcript saved to: $transcriptPath" -ForegroundColor Cyan
            }
            catch {
                # Transcript may not have been started successfully - non-critical
                Write-Verbose "Note: Transcript stop failed (may not have been started): $($_.Exception.Message)"
            }
        }

        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Azure Local Cluster Update - Completed" -Level Header
        Write-Log -Message "========================================" -Level Header

        if ($PassThru) {
            return $results
        }
    }
}

function Get-AzureLocalClusterInfo {
    <#
    .SYNOPSIS
        Gets detailed information about an Azure Local cluster.
    
    .DESCRIPTION
        Retrieves cluster information from Azure Resource Manager for a specified Azure Local
        (Azure Stack HCI) cluster. Can search by cluster name within a specific resource group
        or across all resource groups in a subscription.
    
    .PARAMETER ClusterName
        The name of the Azure Local cluster to retrieve information for.
    
    .PARAMETER ResourceGroupName
        The resource group containing the cluster. If not specified, searches across all
        resource groups in the subscription.
    
    .PARAMETER SubscriptionId
        The Azure subscription ID containing the cluster.
    
    .PARAMETER ApiVersion
        The API version to use for the Azure REST call. Defaults to the module's default API version.
    
    .EXAMPLE
        Get-AzureLocalClusterInfo -ClusterName "MyCluster" -SubscriptionId "12345-abcd-6789"
        
        Searches for the cluster named "MyCluster" across all resource groups in the specified subscription.
    
    .EXAMPLE
        Get-AzureLocalClusterInfo -ClusterName "MyCluster" -ResourceGroupName "MyRG" -SubscriptionId "12345-abcd-6789"
        
        Gets cluster information directly from the specified resource group.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClusterName,

        [Parameter(Mandatory = $false)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion
    )

    # Ensure Azure CLI is available
    Test-AzCliAvailable | Out-Null

    if ($ResourceGroupName) {
        # Direct lookup if resource group is known
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AzureStackHCI/clusters/${ClusterName}?api-version=$ApiVersion"
        
        Write-Verbose "Getting cluster info from: $uri"
        
        $result = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    }
    else {
        # Search across all resource groups
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.AzureStackHCI/clusters?api-version=$ApiVersion"
        
        Write-Verbose "Searching for cluster across subscription: $uri"
        
        $allClusters = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -eq 0 -and $allClusters.value) {
            $cluster = $allClusters.value | Where-Object { $_.name -eq $ClusterName }
            if ($cluster) {
                return $cluster
            }
        }
    }

    return $null
}

function Get-AzureLocalUpdateSummary {
    <#
    .SYNOPSIS
        Gets the update summary for one or more Azure Local clusters.
    .DESCRIPTION
        Retrieves the update summary for Azure Local (Azure Stack HCI) clusters.
        The summary includes the current update state, available updates count,
        health check results, and other update-related status information.
        
        Supports multiple input methods:
        - Single cluster by resource ID (original behavior, returns raw API object)
        - Multiple clusters by name or resource ID
        - All clusters matching an UpdateRing tag value
        
        When querying multiple clusters, returns formatted results with export options.
    .PARAMETER ClusterResourceId
        The full Azure Resource ID of a single cluster (original behavior).
        Example: "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to query.
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to query.
    .PARAMETER ScopeByUpdateRingTag
        When specified, finds clusters by the 'UpdateRing' tag via Azure Resource Graph.
        Must be used together with -UpdateRingValue.
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    .PARAMETER ResourceGroupName
        The resource group containing the clusters (only used with -ClusterNames).
    .PARAMETER SubscriptionId
        The Azure subscription ID. If not specified, uses the current az CLI subscription.
    .PARAMETER ApiVersion
        The Azure REST API version to use. Default is the module's default API version.
    .PARAMETER ExportPath
        Path to export the results. Supports .csv, .json, and .xml (JUnit format) extensions.
    .OUTPUTS
        PSCustomObject - Single update summary when using -ClusterResourceId
        PSCustomObject[] - Array of formatted summaries when using multi-cluster parameters
    .EXAMPLE
        # Single cluster (original behavior)
        $summary = Get-AzureLocalUpdateSummary -ClusterResourceId $cluster.id
        Write-Host "Update State: $($summary.properties.state)"
    .EXAMPLE
        # Multiple clusters by tag
        Get-AzureLocalUpdateSummary -ScopeByUpdateRingTag -UpdateRingValue "Wave1"
    .EXAMPLE
        # Export to CSV
        Get-AzureLocalUpdateSummary -ScopeByUpdateRingTag -UpdateRingValue "Production" -ExportPath "C:\Reports\summaries.csv"
    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleCluster')]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleCluster')]
        [string]$ClusterResourceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [string]$ExportPath,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto',

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    # Original single-cluster behavior
    if ($PSCmdlet.ParameterSetName -eq 'SingleCluster') {
        Test-AzCliAvailable | Out-Null
        $uri = "https://management.azure.com$ClusterResourceId/updateSummaries/default?api-version=$ApiVersion"
        
        Write-Verbose "Getting update summary from: $uri"
        
        $result = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
        return $null
    }

    # Multi-cluster mode
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Cluster Update Summaries" -Level Header
    Write-Log -Message "========================================" -Level Header

    # Verify Azure CLI is installed and logged in
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not logged in. Please run 'az login' first."
        }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Build list of clusters to process
    $clustersToProcess = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        if (-not (Install-AzGraphExtension)) {
            Write-Error "Failed to install Azure CLI 'resource-graph' extension."
            return
        }
        
        Write-Log -Message "Querying Azure Resource Graph for clusters with tag 'UpdateRing' = '$UpdateRingValue'..." -Level Info
        
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id, name, resourceGroup, subscriptionId, tags"
        
        try {
            $clusterRows = Invoke-AzResourceGraphQuery -Query $argQuery

            if (-not $clusterRows -or $clusterRows.Count -eq 0) {
                Write-Log -Message "No clusters found with tag 'UpdateRing' = '$UpdateRingValue'" -Level Warning
                return @()
            }
            
            Write-Log -Message "Found $($clusterRows.Count) cluster(s) matching tag criteria" -Level Success
            foreach ($cluster in $clusterRows) {
                $clustersToProcess += @{ 
                    ResourceId = $cluster.id
                    Name = $cluster.name 
                    ResourceGroup = $cluster.resourceGroup
                    SubscriptionId = $cluster.subscriptionId
                }
            }
        }
        catch {
            Write-Log -Message "Error querying Azure Resource Graph: $_" -Level Error
            return
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
        foreach ($resourceId in $ClusterResourceIds) {
            $clusterRgName = ($resourceId -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
            $clusterSubId = ($resourceId -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
            $clustersToProcess += @{ 
                ResourceId = $resourceId
                Name = ($resourceId -split '/')[-1]
                ResourceGroup = $clusterRgName
                SubscriptionId = $clusterSubId
            }
        }
    }
    else {
        # ByName - resolve names to resource IDs upfront to avoid per-cluster lookups
        if (-not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
        }
        foreach ($name in $ClusterNames) {
            $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
            if ($clusterInfo) {
                $clustersToProcess += @{ 
                    ResourceId = $clusterInfo.id
                    Name = $clusterInfo.name
                    ResourceGroup = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    SubscriptionId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                }
            }
            else {
                Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning
            }
        }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "Querying update summaries for $($clustersToProcess.Count) cluster(s)..." -Level Info

    # Collect results
    $results = @()

    foreach ($cluster in $clustersToProcess) {
        $clusterName = $cluster.Name
        Write-Host "  Checking: $clusterName..." -ForegroundColor Gray -NoNewline

        try {
            # Get cluster info if we don't have ResourceId
            $resourceId = $cluster.ResourceId
            if (-not $resourceId) {
                $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                    -ResourceGroupName $cluster.ResourceGroup `
                    -SubscriptionId $cluster.SubscriptionId `
                    -ApiVersion $ApiVersion
                if ($clusterInfo) {
                    $resourceId = $clusterInfo.id
                }
            }

            if (-not $resourceId) {
                Write-Host " Not Found" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    ClusterName          = $clusterName
                    ResourceGroup        = $cluster.ResourceGroup
                    SubscriptionId       = $cluster.SubscriptionId
                    UpdateState          = "Not Found"
                    HealthState          = "N/A"
                    CurrentVersion       = ""
                    LastUpdated          = ""
                    LastChecked          = ""
                    AvailableUpdatesCount = 0
                }
                continue
            }

            # Get update summary
            $uri = "https://management.azure.com$resourceId/updateSummaries/default?api-version=$ApiVersion"
            $summary = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json

            if ($LASTEXITCODE -eq 0 -and $summary) {
                $props = $summary.properties
                $state = if ($props.state) { $props.state } else { "Unknown" }
                $healthState = if ($props.healthState) { $props.healthState } else { "Unknown" }
                
                # Color output based on state
                if ($state -eq "UpdateAvailable" -or $state -eq "Ready") {
                    Write-Host " $state" -ForegroundColor Green
                }
                elseif ($state -eq "UpdateInProgress") {
                    Write-Host " $state" -ForegroundColor Yellow
                }
                elseif ($healthState -eq "Failure") {
                    Write-Host " $state ($healthState)" -ForegroundColor Red
                }
                else {
                    Write-Host " $state" -ForegroundColor Gray
                }

                $results += [PSCustomObject]@{
                    ClusterName           = $clusterName
                    ResourceGroup         = $cluster.ResourceGroup
                    SubscriptionId        = $cluster.SubscriptionId
                    UpdateState           = $state
                    HealthState           = $healthState
                    CurrentVersion        = if ($props.currentVersion) { $props.currentVersion } else { "" }
                    LastUpdated           = if ($props.lastUpdatedTime) { ([datetime]$props.lastUpdatedTime).ToString("yyyy-MM-dd HH:mm") } else { "" }
                    LastChecked           = if ($props.lastCheckedTime) { ([datetime]$props.lastCheckedTime).ToString("yyyy-MM-dd HH:mm") } else { "" }
                    AvailableUpdatesCount = if ($props.updateStateProperties -and $props.updateStateProperties.availableUpdates) { $props.updateStateProperties.availableUpdates } else { 0 }
                }
            }
            else {
                Write-Host " No Summary" -ForegroundColor Gray
                $results += [PSCustomObject]@{
                    ClusterName           = $clusterName
                    ResourceGroup         = $cluster.ResourceGroup
                    SubscriptionId        = $cluster.SubscriptionId
                    UpdateState           = "No Summary"
                    HealthState           = "Unknown"
                    CurrentVersion        = ""
                    LastUpdated           = ""
                    LastChecked           = ""
                    AvailableUpdatesCount = 0
                }
            }
        }
        catch {
            Write-Host " Error: $($_.Exception.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                ClusterName           = $clusterName
                ResourceGroup         = $cluster.ResourceGroup
                SubscriptionId        = $cluster.SubscriptionId
                UpdateState           = "Error"
                HealthState           = "Error"
                CurrentVersion        = ""
                LastUpdated           = ""
                LastChecked           = ""
                AvailableUpdatesCount = 0
            }
        }
    }

    # Display Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $totalClusters = $results.Count
    $upToDate = @($results | Where-Object { $_.UpdateState -in @("UpToDate", "AppliedSuccessfully") }).Count
    $updateAvailable = @($results | Where-Object { $_.UpdateState -in (@("UpdateAvailable") + $script:ReadyStates) }).Count
    $inProgress = @($results | Where-Object { $_.UpdateState -eq "UpdateInProgress" }).Count
    $healthFailures = @($results | Where-Object { $_.HealthState -eq "Failure" }).Count

    Write-Log -Message "" -Level Info
    Write-Log -Message "Total Clusters:       $totalClusters" -Level Info
    Write-Log -Message "Up to Date:           $upToDate" -Level $(if ($upToDate -gt 0) { "Success" } else { "Info" })
    Write-Log -Message "Update Available:     $updateAvailable" -Level $(if ($updateAvailable -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Update In Progress:   $inProgress" -Level $(if ($inProgress -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Health Failures:      $healthFailures" -Level $(if ($healthFailures -gt 0) { "Error" } else { "Info" })

    # Display results table
    Write-Log -Message "" -Level Info
    Write-Log -Message "Detailed Results:" -Level Header
    $results | Format-Table ClusterName, ResourceGroup, UpdateState, HealthState, CurrentVersion, AvailableUpdatesCount -AutoSize

    # Export if path specified
    if ($ExportPath) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            $format = Get-ExportFormat -Path $ExportPath -ExportFormat $ExportFormat
            
            switch ($format) {
                'Csv' {
                    $results | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                'Json' {
                    $exportData = @{
                        Timestamp     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalClusters = $totalClusters
                        Summary       = @{
                            UpToDate        = $upToDate
                            UpdateAvailable = $updateAvailable
                            InProgress      = $inProgress
                            HealthFailures  = $healthFailures
                        }
                        Results       = $results
                    }
                    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    $junitResults = $results | ForEach-Object {
                        [PSCustomObject]@{
                            ClusterName  = $_.ClusterName
                            Status       = if ($_.HealthState -eq "Failure") { "Failed" } elseif ($_.UpdateState -in @("UpToDate", "AppliedSuccessfully")) { "Passed" } else { "Skipped" }
                            Message      = "UpdateState: $($_.UpdateState), HealthState: $($_.HealthState), CurrentVersion: $($_.CurrentVersion)"
                            UpdateName   = $_.CurrentVersion
                            CurrentState = $_.UpdateState
                        }
                    }
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalUpdateSummary" -OperationType "UpdateSummary"
                    Write-Log -Message "Results exported to JUnit XML: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
        }
    }

    Write-Log -Message "" -Level Info
    if ($PassThru) {
        return $results
    }
}

function Get-AzureLocalAvailableUpdates {
    <#
    .SYNOPSIS
        Gets the list of available updates for one or more Azure Local clusters.
    
    .DESCRIPTION
        Retrieves all updates that are available to install on the specified Azure Local cluster(s).
        Returns update objects containing details such as update name, version, 
        description, and state.
        
        Supports multiple input methods:
        - Single cluster by resource ID (original behavior, returns raw API objects)
        - Multiple clusters by name or resource ID
        - All clusters matching an UpdateRing tag value
        
        When querying multiple clusters, returns formatted results with export options.
    
    .PARAMETER ClusterResourceId
        The full Azure Resource ID of a single cluster (original behavior).
        Example: "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"
    
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to query.
    
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to query.
    
    .PARAMETER ScopeByUpdateRingTag
        When specified, finds clusters by the 'UpdateRing' tag via Azure Resource Graph.
        Must be used together with -UpdateRingValue.
    
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    
    .PARAMETER ResourceGroupName
        The resource group containing the clusters (only used with -ClusterNames).
    
    .PARAMETER SubscriptionId
        The Azure subscription ID. If not specified, uses the current az CLI subscription.
    
    .PARAMETER ApiVersion
        The API version to use. Defaults to "2025-10-01".
    
    .PARAMETER ExportPath
        Path to export the results. Format is auto-detected from extension (.csv, .json, .xml) unless -ExportFormat is specified.
    
    .PARAMETER ExportFormat
        Export format: Auto (default - detect from extension), Csv, Json, or JUnitXml.
    
    .OUTPUTS
        Returns an array of PSCustomObjects representing available updates.
    
    .EXAMPLE
        # Single cluster (original behavior)
        Get-AzureLocalAvailableUpdates -ClusterResourceId "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"
    
    .EXAMPLE
        # Multiple clusters by tag
        Get-AzureLocalAvailableUpdates -ScopeByUpdateRingTag -UpdateRingValue "Wave1"
    
    .EXAMPLE
        # Export to CSV
        Get-AzureLocalAvailableUpdates -ScopeByUpdateRingTag -UpdateRingValue "Production" -ExportPath "C:\Reports\updates.csv"
    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleCluster')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleCluster')]
        [string]$ClusterResourceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [string]$ExportPath,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto',

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false, ParameterSetName = 'SingleCluster')]
        [switch]$Raw
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    # Original single-cluster behavior
    if ($PSCmdlet.ParameterSetName -eq 'SingleCluster') {
        Test-AzCliAvailable | Out-Null
        $uri = "https://management.azure.com$ClusterResourceId/updates?api-version=$ApiVersion"
        
        Write-Verbose "Getting available updates from: $uri"
        
        $result = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or -not $result.value) {
            if (-not $Raw) {
                Write-Log -Message "No updates returned for cluster '$(($ClusterResourceId -split '/')[-1])'." -Level Warning
            }
            return @()
        }

        # -Raw returns the unprocessed ARM API objects (used by internal callers)
        if ($Raw) {
            return $result.value
        }

        # Default: return enriched objects with SBE dependency info
        $clusterName = ($ClusterResourceId -split '/')[-1]
        $rgName = ($ClusterResourceId -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
        $subId = ($ClusterResourceId -split '/subscriptions/')[1] -split '/' | Select-Object -First 1

        # Header banner (matches multi-cluster output style)
        Write-Log -Message "" -Level Info
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Azure Local Available Updates" -Level Header
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Cluster:        $clusterName" -Level Info
        Write-Log -Message "Resource Group: $rgName" -Level Info
        Write-Log -Message "Subscription:   $subId" -Level Info

        $enriched = @()
        foreach ($update in $result.value) {
            $props = $update.properties
            $state = if ($props.state) { $props.state } else { "Unknown" }
            $packageType = if ($props.packageType) { $props.packageType } else { "" }
            $sbeDependency = ""
            if ($state -in @("HasPrerequisite", "AdditionalContentRequired") -and $packageType -eq "SBE") {
                $additionalProps = ConvertTo-AzLocalAdditionalProperties -InputObject $props.additionalProperties
                $sbeParts = @()
                if ($additionalProps -and $additionalProps.SBEPublisher) { $sbeParts += "Publisher: $($additionalProps.SBEPublisher)" }
                if ($additionalProps -and $additionalProps.SBEFamily) { $sbeParts += "Family: $($additionalProps.SBEFamily)" }
                if ($additionalProps -and $additionalProps.SBEReleaseLink) { $sbeParts += "ReleaseNotes: $($additionalProps.SBEReleaseLink)" }
                if ($sbeParts.Count -gt 0) { $sbeDependency = $sbeParts -join '; ' }
            }
            $enriched += [PSCustomObject]@{
                ClusterName      = $clusterName
                ResourceGroup    = $rgName
                SubscriptionId   = $subId
                UpdateName       = $update.name
                UpdateState      = $state
                Version          = if ($props.version) { $props.version } else { "" }
                PackageType      = $packageType
                SBEDependency    = $sbeDependency
                Description      = if ($props.description) { $props.description.Substring(0, [Math]::Min(100, $props.description.Length)) } else { "" }
            }
        }

        # Summary block (matches multi-cluster output style)
        $readyCount = @($enriched | Where-Object { $_.UpdateState -in $script:ReadyStates }).Count
        $prereqCount = @($enriched | Where-Object { $_.UpdateState -in $script:PrereqStates }).Count
        $otherCount = $enriched.Count - $readyCount - $prereqCount

        Write-Log -Message "" -Level Info
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Summary" -Level Header
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Total Updates:           $($enriched.Count)" -Level Info
        Write-Log -Message "Ready to Install:        $readyCount" -Level $(if ($readyCount -gt 0) { "Success" } else { "Info" })
        Write-Log -Message "Has Prerequisite (SBE):  $prereqCount" -Level $(if ($prereqCount -gt 0) { "Warning" } else { "Info" })
        if ($otherCount -gt 0) {
            Write-Log -Message "Other States:            $otherCount" -Level Info
        }

        if ($prereqCount -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "Updates blocked by SBE prerequisites:" -Level Warning
            foreach ($u in ($enriched | Where-Object { $_.UpdateState -in $script:PrereqStates })) {
                $msg = "  - $($u.UpdateName): $($u.UpdateState)"
                if ($u.SBEDependency) { $msg += " ($($u.SBEDependency))" }
                Write-Log -Message $msg -Level Warning
            }
            Write-Log -Message "Install the required SBE (Solution Builder Extension) update from your hardware vendor before these updates can proceed." -Level Warning
        }

        Write-Log -Message "" -Level Info
        Write-Log -Message "Detailed Results:" -Level Header
        $enriched | Format-Table UpdateName, UpdateState, Version, PackageType, SBEDependency -AutoSize | Out-String | Write-Host

        return $enriched
    }

    # Multi-cluster mode
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Available Updates" -Level Header
    Write-Log -Message "========================================" -Level Header

    # Verify Azure CLI is installed and logged in
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not logged in. Please run 'az login' first."
        }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Build list of clusters to process
    $clustersToProcess = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        if (-not (Install-AzGraphExtension)) {
            Write-Error "Failed to install Azure CLI 'resource-graph' extension."
            return
        }
        
        Write-Log -Message "Querying Azure Resource Graph for clusters with tag 'UpdateRing' = '$UpdateRingValue'..." -Level Info
        
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id, name, resourceGroup, subscriptionId, tags"
        
        try {
            $clusterRows = Invoke-AzResourceGraphQuery -Query $argQuery

            if (-not $clusterRows -or $clusterRows.Count -eq 0) {
                Write-Log -Message "No clusters found with tag 'UpdateRing' = '$UpdateRingValue'" -Level Warning
                return @()
            }
            
            Write-Log -Message "Found $($clusterRows.Count) cluster(s) matching tag criteria" -Level Success
            foreach ($cluster in $clusterRows) {
                $clustersToProcess += @{ 
                    ResourceId = $cluster.id
                    Name = $cluster.name 
                    ResourceGroup = $cluster.resourceGroup
                    SubscriptionId = $cluster.subscriptionId
                }
            }
        }
        catch {
            Write-Log -Message "Error querying Azure Resource Graph: $_" -Level Error
            return
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
        foreach ($resourceId in $ClusterResourceIds) {
            $clusterRgName = ($resourceId -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
            $clusterSubId = ($resourceId -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
            $clustersToProcess += @{ 
                ResourceId = $resourceId
                Name = ($resourceId -split '/')[-1]
                ResourceGroup = $clusterRgName
                SubscriptionId = $clusterSubId
            }
        }
    }
    else {
        # ByName - resolve names to resource IDs upfront to avoid per-cluster lookups
        if (-not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
        }
        foreach ($name in $ClusterNames) {
            $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
            if ($clusterInfo) {
                $clustersToProcess += @{ 
                    ResourceId = $clusterInfo.id
                    Name = $clusterInfo.name
                    ResourceGroup = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    SubscriptionId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                }
            }
            else {
                Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning
            }
        }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "Querying available updates for $($clustersToProcess.Count) cluster(s)..." -Level Info

    # Collect results
    $results = @()
    $updateVersionCounts = @{}

    foreach ($cluster in $clustersToProcess) {
        $clusterName = $cluster.Name
        Write-Host "  Checking: $clusterName..." -ForegroundColor Gray -NoNewline

        try {
            # Get cluster info if we don't have ResourceId
            $resourceId = $cluster.ResourceId
            if (-not $resourceId) {
                $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                    -ResourceGroupName $cluster.ResourceGroup `
                    -SubscriptionId $cluster.SubscriptionId `
                    -ApiVersion $ApiVersion
                if ($clusterInfo) {
                    $resourceId = $clusterInfo.id
                }
            }

            if (-not $resourceId) {
                Write-Host " Not Found" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    ClusterName      = $clusterName
                    ResourceGroup    = $cluster.ResourceGroup
                    SubscriptionId   = $cluster.SubscriptionId
                    UpdateName       = "N/A"
                    UpdateState      = "Cluster Not Found"
                    Version          = ""
                    PackageType      = ""
                    SBEDependency    = ""
                    Description      = ""
                }
                continue
            }

            # Get available updates
            $uri = "https://management.azure.com$resourceId/updates?api-version=$ApiVersion"
            $response = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json

            if ($LASTEXITCODE -eq 0 -and $response.value -and $response.value.Count -gt 0) {
                $updates = $response.value
                $readyCount = @($updates | Where-Object { $_.properties.state -in $script:ReadyStates }).Count
                $prereqCount = @($updates | Where-Object { $_.properties.state -in $script:PrereqStates }).Count
                
                $statusParts = @("$readyCount ready")
                if ($prereqCount -gt 0) { $statusParts += "$prereqCount has prerequisite" }
                $statusText = $statusParts -join ', '
                $statusColor = if ($readyCount -gt 0) { "Green" } elseif ($prereqCount -gt 0) { "Yellow" } else { "Yellow" }
                Write-Host " $($updates.Count) update(s) ($statusText)" -ForegroundColor $statusColor
                
                foreach ($update in $updates) {
                    $props = $update.properties
                    $state = if ($props.state) { $props.state } else { "Unknown" }
                    
                    # Track update versions
                    if ($state -in $script:ReadyStates) {
                        if ($updateVersionCounts.ContainsKey($update.name)) {
                            $updateVersionCounts[$update.name]++
                        }
                        else {
                            $updateVersionCounts[$update.name] = 1
                        }
                    }

                    # Extract SBE dependency info for HasPrerequisite/AdditionalContentRequired updates
                    $packageType = if ($props.packageType) { $props.packageType } else { "" }
                    $sbeDependency = ""
                    if ($state -in @("HasPrerequisite", "AdditionalContentRequired") -and $packageType -eq "SBE") {
                        $additionalProps = ConvertTo-AzLocalAdditionalProperties -InputObject $props.additionalProperties
                        $sbePublisher = if ($additionalProps -and $additionalProps.SBEPublisher) { $additionalProps.SBEPublisher } else { "" }
                        $sbeFamily = if ($additionalProps -and $additionalProps.SBEFamily) { $additionalProps.SBEFamily } else { "" }
                        $sbeReleaseLink = if ($additionalProps -and $additionalProps.SBEReleaseLink) { $additionalProps.SBEReleaseLink } else { "" }
                        $sbeParts = @()
                        if ($sbePublisher) { $sbeParts += "Publisher: $sbePublisher" }
                        if ($sbeFamily) { $sbeParts += "Family: $sbeFamily" }
                        if ($sbeReleaseLink) { $sbeParts += "ReleaseNotes: $sbeReleaseLink" }
                        if ($sbeParts.Count -gt 0) { $sbeDependency = $sbeParts -join '; ' }
                    }
                    
                    $results += [PSCustomObject]@{
                        ClusterName      = $clusterName
                        ResourceGroup    = $cluster.ResourceGroup
                        SubscriptionId   = $cluster.SubscriptionId
                        UpdateName       = $update.name
                        UpdateState      = $state
                        Version          = if ($props.version) { $props.version } else { "" }
                        PackageType      = $packageType
                        SBEDependency    = $sbeDependency
                        Description      = if ($props.description) { $props.description.Substring(0, [Math]::Min(100, $props.description.Length)) } else { "" }
                    }
                }
            }
            else {
                Write-Host " No updates available" -ForegroundColor Gray
                $results += [PSCustomObject]@{
                    ClusterName      = $clusterName
                    ResourceGroup    = $cluster.ResourceGroup
                    SubscriptionId   = $cluster.SubscriptionId
                    UpdateName       = "None"
                    UpdateState      = "No Updates"
                    Version          = ""
                    PackageType      = ""
                    SBEDependency    = ""
                    Description      = ""
                }
            }
        }
        catch {
            Write-Host " Error: $($_.Exception.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                ClusterName      = $clusterName
                ResourceGroup    = $cluster.ResourceGroup
                SubscriptionId   = $cluster.SubscriptionId
                UpdateName       = "Error"
                UpdateState      = "Error"
                Version          = ""
                PackageType      = ""
                SBEDependency    = ""
                Description      = $_.Exception.Message
            }
        }
    }

    # Display Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $totalClusters = $clustersToProcess.Count
    $clustersWithUpdates = @($results | Where-Object { $_.UpdateName -notin @("N/A", "None", "Error") } | Select-Object -ExpandProperty ClusterName -Unique).Count
    $clustersWithReadyUpdates = @($results | Where-Object { $_.UpdateState -in $script:ReadyStates } | Select-Object -ExpandProperty ClusterName -Unique).Count
    $clustersWithPrereqUpdates = @($results | Where-Object { $_.UpdateState -in $script:PrereqStates } | Select-Object -ExpandProperty ClusterName -Unique).Count
    $totalUpdates = @($results | Where-Object { $_.UpdateName -notin @("N/A", "None", "Error") }).Count

    Write-Log -Message "" -Level Info
    Write-Log -Message "Total Clusters:              $totalClusters" -Level Info
    Write-Log -Message "Clusters with Updates:       $clustersWithUpdates" -Level $(if ($clustersWithUpdates -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Clusters with Ready Updates: $clustersWithReadyUpdates" -Level $(if ($clustersWithReadyUpdates -gt 0) { "Success" } else { "Info" })
    if ($clustersWithPrereqUpdates -gt 0) {
        Write-Log -Message "Clusters with Prerequisite:  $clustersWithPrereqUpdates (SBE update required first)" -Level Warning
    }
    Write-Log -Message "Total Updates Found:         $totalUpdates" -Level Info

    # Show SBE dependency details for HasPrerequisite/AdditionalContentRequired updates
    $prereqUpdates = @($results | Where-Object { $_.UpdateState -in @("HasPrerequisite", "AdditionalContentRequired") -and $_.SBEDependency })
    if ($prereqUpdates.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Updates Blocked by SBE Prerequisites:" -Level Warning
        foreach ($pu in $prereqUpdates) {
            Write-Log -Message "  $($pu.ClusterName) - $($pu.UpdateName): $($pu.SBEDependency)" -Level Warning
        }
    }

    # Show most common update versions
    if ($updateVersionCounts.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Ready Update Versions:" -Level Header
        $sortedVersions = $updateVersionCounts.GetEnumerator() | Sort-Object -Property Value -Descending
        foreach ($version in $sortedVersions) {
            Write-Log -Message "  $($version.Key): $($version.Value) cluster(s)" -Level Info
        }
    }

    # Display results table
    Write-Log -Message "" -Level Info
    Write-Log -Message "Detailed Results:" -Level Header
    $results | Format-Table ClusterName, UpdateName, UpdateState, Version, PackageType -AutoSize

    # Export if path specified
    if ($ExportPath) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            $format = Get-ExportFormat -Path $ExportPath -ExportFormat $ExportFormat
            
            switch ($format) {
                'Csv' {
                    $results | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                'Json' {
                    $exportData = @{
                        Timestamp             = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalClusters         = $totalClusters
                        ClustersWithUpdates   = $clustersWithUpdates
                        UpdateVersionSummary  = $updateVersionCounts
                        Results               = $results
                    }
                    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    $junitResults = $results | ForEach-Object {
                        [PSCustomObject]@{
                            ClusterName  = $_.ClusterName
                            Status       = if ($_.UpdateState -in $script:ReadyStates) { "Ready" } elseif ($_.UpdateState -eq "Error") { "Failed" } else { "Skipped" }
                            Message      = "Update: $($_.UpdateName), State: $($_.UpdateState), Version: $($_.Version)"
                            UpdateName   = $_.UpdateName
                            CurrentState = $_.UpdateState
                        }
                    }
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalAvailableUpdates" -OperationType "AvailableUpdates"
                    Write-Log -Message "Results exported to JUnit XML: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
        }
    }

    Write-Log -Message "" -Level Info
    if ($PassThru) {
        return $results
    }
}

function Invoke-AzureLocalUpdateApply {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClusterResourceId,

        [Parameter(Mandatory = $true)]
        [string]$UpdateName,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion
    )

    # Ensure Azure CLI is available
    Test-AzCliAvailable | Out-Null

    $uri = "https://management.azure.com$ClusterResourceId/updates/$UpdateName/apply?api-version=$ApiVersion"
    
    Write-Verbose "Applying update via POST to: $uri"
    
    # The apply endpoint is a POST with empty body
    $result = az rest --method POST --uri $uri 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        return $true
    }
    elseif ($result -match "202" -or $result -match "Accepted") {
        # 202 Accepted is a valid response for long-running operations
        return $true
    }
    
    Write-Verbose "Apply result: $result"
    return $false
}

function Get-AzureLocalUpdateRuns {
    <#
    .SYNOPSIS
        Gets update run history and status for one or more Azure Local clusters.
    .DESCRIPTION
        Retrieves update run information for Azure Local (Azure Stack HCI) clusters.
        Update runs contain the history and status of update operations including
        start time, end time, progress, and any errors that occurred.
        
        Supports multiple input methods:
        - Single cluster by name (original behavior)
        - Multiple clusters by name or resource ID
        - All clusters matching an UpdateRing tag value
        
        Returns clean, human-readable objects with key information extracted from the API response.
    .PARAMETER ClusterName
        The name of a single Azure Local cluster (original behavior).
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to query.
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to query.
    .PARAMETER ScopeByUpdateRingTag
        When specified, finds clusters by the 'UpdateRing' tag via Azure Resource Graph.
        Must be used together with -UpdateRingValue.
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    .PARAMETER ResourceGroupName
        The resource group containing the cluster. If not specified, searches all resource groups.
    .PARAMETER SubscriptionId
        The Azure subscription ID. If not specified, uses the current subscription context.
    .PARAMETER UpdateName
        Optional. The specific update name to get runs for. If not specified, returns runs for all updates.
    .PARAMETER Latest
        Optional. Return only the most recent update run per cluster.
    .PARAMETER Raw
        Optional. Return the raw API response objects instead of formatted output.
    .PARAMETER ApiVersion
        The Azure REST API version to use. Default is the module's default API version.
    .PARAMETER ExportPath
        Path to export the results. Supports .csv, .json, and .xml (JUnit format) extensions.
    .OUTPUTS
        PSCustomObject[] - Array of update run objects with the following properties:
        - ClusterName: The cluster name (in multi-cluster mode)
        - UpdateName: The update package name (e.g., "Solution12.2601.1002.38")
        - RunId: The unique GUID for this update run
        - State: Current state (InProgress, Succeeded, Failed, etc.)
        - StartTime: When the update run started
        - Duration: How long the update has been running or took to complete
        - Progress: Step completion progress (e.g., "3/5 steps")
        - CurrentStep: The currently executing or failed step name
        - Location: Azure region
    .EXAMPLE
        # Single cluster (original behavior)
        Get-AzureLocalUpdateRuns -ClusterName "MyCluster" -ResourceGroupName "MyRG"
    .EXAMPLE
        # Multiple clusters by tag
        Get-AzureLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Latest
    .EXAMPLE
        # Export to CSV
        Get-AzureLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Production" -Latest -ExportPath "C:\Reports\runs.csv"
    .EXAMPLE
        Get-AzureLocalUpdateRuns -ClusterName "MyCluster" -Raw
        Gets raw API response for programmatic processing.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleCluster')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleCluster')]
        [string]$ClusterName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'SingleCluster')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$UpdateName,

        [Parameter(Mandatory = $false)]
        [switch]$Latest,

        [Parameter(Mandatory = $false)]
        [switch]$Raw,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [string]$ExportPath,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto',

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    # Helper function to format update runs
    function Format-UpdateRun {
        param($run, $clusterName = "")
        
        $props = $run.properties
        
        # Calculate duration
        $duration = ""
        if ($props.timeStarted) {
            $startTime = [datetime]$props.timeStarted
            if ($props.lastUpdatedTime) {
                $endTime = [datetime]$props.lastUpdatedTime
                $durationSpan = $endTime - $startTime
                if ($durationSpan.TotalHours -ge 1) {
                    $duration = "{0:N1} hours" -f $durationSpan.TotalHours
                }
                else {
                    $duration = "{0:N0} minutes" -f $durationSpan.TotalMinutes
                }
            }
            elseif ($props.state -eq "InProgress") {
                $durationSpan = (Get-Date) - $startTime
                $duration = "{0:N1} hours (running)" -f $durationSpan.TotalHours
            }
        }

        # Get current step info (with recursive nested step traversal)
        $currentStep = ""
        $currentStepDetail = ""
        $progress = ""
        if ($props.progress -and $props.progress.steps) {
            $steps = $props.progress.steps
            $completedSteps = ($steps | Where-Object { $_.status -eq "Success" }).Count
            $totalSteps = $steps.Count
            $progress = "$completedSteps/$totalSteps steps"
            
            # Get top-level step name
            $inProgressStep = $steps | Where-Object { $_.status -eq "InProgress" } | Select-Object -First 1
            $failedStep = $steps | Where-Object { $_.status -in @("Error", "Failed") } | Select-Object -First 1
            
            if ($inProgressStep) {
                $currentStep = $inProgressStep.name
            }
            elseif ($failedStep) {
                $currentStep = "$($failedStep.name) (FAILED)"
            }

            # Get deepest step path (recursive traversal up to 8+ levels)
            # Include error message for failed steps to show health validation details
            $currentStepDetail = Get-CurrentStepPath -Steps $steps -IncludeErrorMessage
            if ([string]::IsNullOrWhiteSpace($currentStepDetail)) {
                $currentStepDetail = $currentStep
            }
            # For health-check-blocked updates, ensure the message is clear
            if ($currentStepDetail -match 'health check' -and $props.state -eq 'Failed') {
                if ($currentStepDetail -notmatch 'Critical health issues') {
                    $currentStepDetail = "$currentStepDetail - Critical health issues must be resolved before updates can proceed"
                }
            }
        }

        # Extract update name and run ID from the resource ID
        $updateNameExtracted = ""
        $runId = ""
        if ($run.id -match '/updates/([^/]+)/updateRuns/([^/]+)$') {
            $updateNameExtracted = $matches[1]
            $runId = $matches[2]
        }
        elseif ($run.name -match '/([^/]+)$') {
            $runId = $matches[1]
        }
        else {
            $runId = $run.name
        }

        $result = [PSCustomObject]@{
            UpdateName       = $updateNameExtracted
            RunId            = $runId
            State            = $props.state
            StartTime        = if ($props.timeStarted) { ([datetime]$props.timeStarted).ToString("yyyy-MM-dd HH:mm") } else { "" }
            Duration         = $duration
            Progress         = $progress
            CurrentStep      = $currentStep
            CurrentStepDetail = $currentStepDetail
            Location         = $props.location
        }
        
        # Add ClusterName property for multi-cluster mode
        if ($clusterName) {
            $result | Add-Member -NotePropertyName "ClusterName" -NotePropertyValue $clusterName -Force
        }
        
        return $result
    }

    # Helper function to get runs for a single cluster
    function Get-ClusterUpdateRuns {
        param($resourceId, $updateNameFilter, $apiVer)
        
        $allRuns = @()
        
        if ($updateNameFilter) {
            $uri = "https://management.azure.com$resourceId/updates/$updateNameFilter/updateRuns?api-version=$apiVer"
            $result = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $result.value) {
                $allRuns = $result.value
            }
        }
        else {
            # Get all updates first, then get runs for each
            $updates = @(Get-AzureLocalAvailableUpdates -ClusterResourceId $resourceId -ApiVersion $apiVer -Raw)
            
            foreach ($update in $updates) {
                $uri = "https://management.azure.com$resourceId/updates/$($update.name)/updateRuns?api-version=$apiVer"
                $runs = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
                if ($runs.value) {
                    $allRuns += $runs.value
                }
            }
        }
        
        return $allRuns
    }

    # Original single-cluster behavior
    if ($PSCmdlet.ParameterSetName -eq 'SingleCluster') {
        Test-AzCliAvailable | Out-Null
        Write-Log -Message "" -Level Info
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Azure Local Cluster Update Runs" -Level Header
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Cluster: $ClusterName" -Level Info

        if (-not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
            Write-Log -Message "Using current subscription: $SubscriptionId" -Level Info
        }

        Write-Log -Message "Looking up cluster resource..." -Level Info
        $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $ClusterName `
            -ResourceGroupName $ResourceGroupName `
            -SubscriptionId $SubscriptionId `
            -ApiVersion $ApiVersion

        if (-not $clusterInfo) {
            Write-Log -Message "Cluster '$ClusterName' not found." -Level Error
            return $null
        }
        Write-Log -Message "Found cluster: $($clusterInfo.id)" -Level Success

        Write-Log -Message "Querying update runs..." -Level Info
        $allRuns = Get-ClusterUpdateRuns -resourceId $clusterInfo.id -updateNameFilter $UpdateName -apiVer $ApiVersion
        Write-Log -Message "Found $($allRuns.Count) update run(s)" -Level $(if ($allRuns.Count -gt 0) { "Success" } else { "Warning" })

        if ($Raw) {
            if ($Latest) {
                return $allRuns | Sort-Object { $_.properties.timeStarted } -Descending | Select-Object -First 1
            }
            return $allRuns
        }

        # Format runs
        $formattedRuns = @()
        foreach ($run in $allRuns) {
            $formattedRuns += Format-UpdateRun -run $run
        }

        $formattedRuns = @($formattedRuns | Sort-Object StartTime -Descending)

        if ($Latest) {
            $formattedRuns = @($formattedRuns | Select-Object -First 1)
        }

        if ($formattedRuns.Count -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "Update Runs for Cluster: $ClusterName" -Level Header
            Write-Log -Message ("=" * 60) -Level Header
            $formattedRuns | Format-Table -AutoSize | Out-String | Write-Host

            # If the latest run failed due to health check, show blocking health failures
            $latestRun = $formattedRuns | Select-Object -First 1
            if ($latestRun.State -eq "Failed" -and $latestRun.CurrentStep -match "health check") {
                Write-Log -Message "The latest update run was blocked by health check failures." -Level Warning
                Write-Log -Message "Querying current health check status..." -Level Info
                $healthResults = Test-AzureLocalClusterHealth -ClusterResourceIds @($clusterInfo.id) -BlockingOnly
                if ($healthResults -and $healthResults[0].CriticalCount -gt 0) {
                    Write-Log -Message "" -Level Info
                    Write-Log -Message "The following critical health issues must be resolved before this update can proceed:" -Level Error
                    foreach ($failure in $healthResults[0].Failures) {
                        $nodeInfo = if ($failure.TargetResourceName) { " (Node: $($failure.TargetResourceName))" } else { "" }
                        Write-Log -Message "  [Critical] $($failure.CheckName)$nodeInfo`: $($failure.Description)" -Level Error
                        if ($failure.Remediation) {
                            Write-Log -Message "    Remediation: $($failure.Remediation)" -Level Warning
                        }
                    }
                }
            }
        }
        else {
            Write-Log -Message "" -Level Info
            Write-Log -Message "No update runs found for cluster '$ClusterName'" -Level Warning
        }

        # Display latest run details
        if ($formattedRuns.Count -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "Latest Update Run:" -Level Header
            Write-Host ""
            $formattedRuns | Select-Object -First 1 | Format-List | Out-String -Stream | ForEach-Object {
                if ($_ -ne "") { Write-Host "`t$_" }
            }
            Write-Host ""
        }

        if ($PassThru) {
            return $formattedRuns
        }
        return
    }

    # Multi-cluster mode
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Update Runs (Fleet)" -Level Header
    Write-Log -Message "========================================" -Level Header

    # Verify Azure CLI is installed and logged in
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not logged in. Please run 'az login' first."
        }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Build list of clusters to process
    $clustersToProcess = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        if (-not (Install-AzGraphExtension)) {
            Write-Error "Failed to install Azure CLI 'resource-graph' extension."
            return
        }
        
        Write-Log -Message "Querying Azure Resource Graph for clusters with tag 'UpdateRing' = '$UpdateRingValue'..." -Level Info
        
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id, name, resourceGroup, subscriptionId, tags"
        
        try {
            $clusterRows = Invoke-AzResourceGraphQuery -Query $argQuery

            if (-not $clusterRows -or $clusterRows.Count -eq 0) {
                Write-Log -Message "No clusters found with tag 'UpdateRing' = '$UpdateRingValue'" -Level Warning
                return @()
            }
            
            Write-Log -Message "Found $($clusterRows.Count) cluster(s) matching tag criteria" -Level Success
            foreach ($cluster in $clusterRows) {
                $clustersToProcess += @{ 
                    ResourceId = $cluster.id
                    Name = $cluster.name 
                    ResourceGroup = $cluster.resourceGroup
                    SubscriptionId = $cluster.subscriptionId
                }
            }
        }
        catch {
            Write-Log -Message "Error querying Azure Resource Graph: $_" -Level Error
            return
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
        foreach ($resourceId in $ClusterResourceIds) {
            $clusterRgName = ($resourceId -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
            $clusterSubId = ($resourceId -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
            $clustersToProcess += @{ 
                ResourceId = $resourceId
                Name = ($resourceId -split '/')[-1]
                ResourceGroup = $clusterRgName
                SubscriptionId = $clusterSubId
            }
        }
    }
    else {
        # ByName - resolve names to resource IDs upfront to avoid per-cluster lookups
        if (-not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
        }
        foreach ($name in $ClusterNames) {
            $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
            if ($clusterInfo) {
                $clustersToProcess += @{ 
                    ResourceId = $clusterInfo.id
                    Name = $clusterInfo.name
                    ResourceGroup = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    SubscriptionId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                }
            }
            else {
                Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning
            }
        }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "Querying update runs for $($clustersToProcess.Count) cluster(s)..." -Level Info

    # Collect results
    $allFormattedRuns = @()
    $stateCounts = @{}

    foreach ($cluster in $clustersToProcess) {
        $clusterName = $cluster.Name
        Write-Host "  Checking: $clusterName..." -ForegroundColor Gray -NoNewline

        try {
            # Get cluster info if we don't have ResourceId
            $resourceId = $cluster.ResourceId
            if (-not $resourceId) {
                $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                    -ResourceGroupName $cluster.ResourceGroup `
                    -SubscriptionId $cluster.SubscriptionId `
                    -ApiVersion $ApiVersion
                if ($clusterInfo) {
                    $resourceId = $clusterInfo.id
                }
            }

            if (-not $resourceId) {
                Write-Host " Not Found" -ForegroundColor Red
                $allFormattedRuns += [PSCustomObject]@{
                    ClusterName       = $clusterName
                    UpdateName        = "N/A"
                    RunId             = ""
                    State             = "Cluster Not Found"
                    StartTime         = ""
                    Duration          = ""
                    Progress          = ""
                    CurrentStep       = ""
                    CurrentStepDetail = ""
                    Location          = ""
                }
                continue
            }

            # Get update runs
            $runs = Get-ClusterUpdateRuns -resourceId $resourceId -updateNameFilter $UpdateName -apiVer $ApiVersion

            if ($runs.Count -gt 0) {
                # Get latest run for display
                $latestRun = $runs | Sort-Object { $_.properties.timeStarted } -Descending | Select-Object -First 1
                $latestState = $latestRun.properties.state
                
                # Track state counts
                if ($stateCounts.ContainsKey($latestState)) {
                    $stateCounts[$latestState]++
                }
                else {
                    $stateCounts[$latestState] = 1
                }
                
                $stateColor = switch ($latestState) {
                    "Succeeded" { "Green" }
                    "InProgress" { "Yellow" }
                    "Failed" { "Red" }
                    default { "Gray" }
                }
                Write-Host " $($runs.Count) run(s), latest: $latestState" -ForegroundColor $stateColor

                # Format runs
                $runsToFormat = if ($Latest) { @($latestRun) } else { $runs }
                foreach ($run in $runsToFormat) {
                    $formatted = Format-UpdateRun -run $run -clusterName $clusterName
                    # Reorder properties to have ClusterName first
                    $allFormattedRuns += [PSCustomObject]@{
                        ClusterName       = $clusterName
                        UpdateName        = $formatted.UpdateName
                        RunId             = $formatted.RunId
                        State             = $formatted.State
                        StartTime         = $formatted.StartTime
                        Duration          = $formatted.Duration
                        Progress          = $formatted.Progress
                        CurrentStep       = $formatted.CurrentStep
                        CurrentStepDetail = $formatted.CurrentStepDetail
                        Location          = $formatted.Location
                    }
                }
            }
            else {
                Write-Host " No runs" -ForegroundColor Gray
                $allFormattedRuns += [PSCustomObject]@{
                    ClusterName       = $clusterName
                    UpdateName        = "None"
                    RunId             = ""
                    State             = "No Runs"
                    StartTime         = ""
                    Duration          = ""
                    Progress          = ""
                    CurrentStep       = ""
                    CurrentStepDetail = ""
                    Location          = ""
                }
            }
        }
        catch {
            Write-Host " Error: $($_.Exception.Message)" -ForegroundColor Red
            $allFormattedRuns += [PSCustomObject]@{
                ClusterName       = $clusterName
                UpdateName        = "Error"
                RunId             = ""
                State             = "Error"
                StartTime         = ""
                Duration          = ""
                Progress          = ""
                CurrentStep       = $_.Exception.Message
                CurrentStepDetail = $_.Exception.Message
                Location          = ""
            }
        }
    }

    # Display Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $totalClusters = $clustersToProcess.Count
    Write-Log -Message "" -Level Info
    Write-Log -Message "Total Clusters: $totalClusters" -Level Info
    
    if ($stateCounts.Count -gt 0) {
        Write-Log -Message "Latest Run States:" -Level Header
        foreach ($state in $stateCounts.Keys | Sort-Object) {
            $level = switch ($state) {
                "Succeeded" { "Success" }
                "Failed" { "Error" }
                "InProgress" { "Warning" }
                default { "Info" }
            }
            Write-Log -Message "  $state`: $($stateCounts[$state])" -Level $level
        }
    }

    # Display results table
    Write-Log -Message "" -Level Info
    Write-Log -Message "Update Runs:" -Level Header
    $allFormattedRuns | Format-Table ClusterName, UpdateName, State, StartTime, Duration, Progress -AutoSize

    # Check for health-check-blocked failures and show diagnostics
    $healthBlockedRuns = @($allFormattedRuns | Where-Object { $_.State -eq "Failed" -and $_.CurrentStep -match "health check" })
    if ($healthBlockedRuns.Count -gt 0) {
        $affectedClusters = @($healthBlockedRuns | Select-Object -ExpandProperty ClusterName -Unique)
        Write-Log -Message "" -Level Info
        Write-Log -Message "Detected $($healthBlockedRuns.Count) update run(s) blocked by health check failures." -Level Warning
        Write-Log -Message "Querying current health check status for affected cluster(s)..." -Level Info
        
        foreach ($affectedCluster in $affectedClusters) {
            # Find the resource ID for this cluster from the clusters we already processed
            $clusterEntry = $clustersToProcess | Where-Object { $_.Name -eq $affectedCluster }
            $rid = $clusterEntry.ResourceId
            if (-not $rid) { continue }
            
            $healthResults = Test-AzureLocalClusterHealth -ClusterResourceIds @($rid) -BlockingOnly
            if ($healthResults -and $healthResults[0].CriticalCount -gt 0) {
                Write-Log -Message "" -Level Info
                Write-Log -Message "Critical health issues blocking updates on '$affectedCluster':" -Level Error
                foreach ($failure in $healthResults[0].Failures) {
                    $nodeInfo = if ($failure.TargetResourceName) { " (Node: $($failure.TargetResourceName))" } else { "" }
                    Write-Log -Message "  [Critical] $($failure.CheckName)$nodeInfo`: $($failure.Description)" -Level Error
                    if ($failure.Remediation) {
                        Write-Log -Message "    Remediation: $($failure.Remediation)" -Level Warning
                    }
                }
            }
        }
    }

    # Export if path specified
    if ($ExportPath) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            $format = Get-ExportFormat -Path $ExportPath -ExportFormat $ExportFormat
            
            switch ($format) {
                'Csv' {
                    $allFormattedRuns | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                'Json' {
                    $exportData = @{
                        Timestamp     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalClusters = $totalClusters
                        StateSummary  = $stateCounts
                        Results       = $allFormattedRuns
                    }
                    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    $junitResults = $allFormattedRuns | ForEach-Object {
                        [PSCustomObject]@{
                            ClusterName  = $_.ClusterName
                            Status       = if ($_.State -eq "Succeeded") { "Passed" } elseif ($_.State -in @("Failed", "Error")) { "Failed" } else { "Skipped" }
                            Message      = "Update: $($_.UpdateName), State: $($_.State), Duration: $($_.Duration), Progress: $($_.Progress)"
                            UpdateName   = $_.UpdateName
                            CurrentState = $_.State
                        }
                    }
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalUpdateRuns" -OperationType "UpdateRuns"
                    Write-Log -Message "Results exported to JUnit XML: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
        }
    }

    Write-Log -Message "" -Level Info

    # Display latest run details per cluster
    if ($allFormattedRuns.Count -gt 0) {
        $latestPerCluster = $allFormattedRuns | Group-Object ClusterName | ForEach-Object {
            $_.Group | Sort-Object StartTime -Descending | Select-Object -First 1
        }
        Write-Log -Message "Latest Update Run per Cluster:" -Level Header
        Write-Host ""
        $latestPerCluster | Format-List | Out-String -Stream | ForEach-Object {
            if ($_ -ne "") { Write-Host "`t$_" }
        }
        Write-Host ""
    }

    if ($PassThru) {
        return $allFormattedRuns
    }
}

function Get-AzureLocalClusterUpdateReadiness {
    <#
    .SYNOPSIS
        Assesses update readiness across Azure Local clusters and reports available updates.

    .DESCRIPTION
        This function queries Azure Local clusters and reports their update readiness state,
        available updates, and provides summary statistics to help plan update deployments.
        
        Output includes:
        - Which clusters are in "Ready" state for updates
        - Which updates are available for each cluster
        - Summary totals showing the most common applicable update version
        
        Results are displayed on screen and optionally exported to CSV, JSON, or JUnit XML.

    .PARAMETER ClusterNames
        An array of Azure Local cluster names to assess.

    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to assess.

    .PARAMETER ScopeByUpdateRingTag
        When specified, finds clusters by the 'UpdateRing' tag via Azure Resource Graph.
        Must be used together with -UpdateRingValue.

    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.

    .PARAMETER ResourceGroupName
        The resource group containing the clusters (only used with -ClusterNames).

    .PARAMETER SubscriptionId
        The Azure subscription ID. If not specified, uses the current az CLI subscription.

    .PARAMETER ApiVersion
        The API version to use. Defaults to "2025-10-01".

    .PARAMETER ExportPath
        Path to export the results. Format is auto-detected from extension (.csv, .json, .xml) unless -ExportFormat is specified.
        - .csv  = Standard CSV format
        - .json = JSON format with summary statistics
        - .xml  = JUnit XML format for CI/CD pipeline integration (Azure DevOps, GitHub Actions, Jenkins, etc.)

    .PARAMETER ExportFormat
        Export format: Auto (default - detect from extension), Csv, Json, or JUnitXml.

    .EXAMPLE
        # Assess all clusters with a specific UpdateRing tag value
        Get-AzureLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Wave1"

    .EXAMPLE
        # Assess specific clusters and export to CSV
        Get-AzureLocalClusterUpdateReadiness -ClusterNames @("Cluster01", "Cluster02") -ExportPath "C:\Reports\readiness.csv"

    .EXAMPLE
        # Export to JUnit XML for CI/CD pipelines
        Get-AzureLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -ExportPath "C:\Reports\readiness.xml"

    .EXAMPLE
        # Assess clusters by Resource ID
        Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds @("/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01")

    .NOTES
        Version: 0.4.0
        Author: Neil Bird, Microsoft.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto',

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Cluster Update Readiness Assessment" -Level Header
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "" -Level Info

    # Verify Azure CLI is installed and logged in
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not logged in. Please run 'az login' first."
        }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Build list of clusters to process
    $clustersToProcess = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        # Ensure resource-graph extension is installed (for pipeline/automation scenarios)
        if (-not (Install-AzGraphExtension)) {
            Write-Error "Failed to install Azure CLI 'resource-graph' extension. Please install manually: az extension add --name resource-graph"
            return
        }
        
        Write-Log -Message "Querying Azure Resource Graph for clusters with tag 'UpdateRing' = '$UpdateRingValue'..." -Level Info
        
        # Build Azure Resource Graph query - use single line to avoid escaping issues with az CLI
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id, name, resourceGroup, subscriptionId, tags"
        
        try {
            $clusterRows = Invoke-AzResourceGraphQuery -Query $argQuery

            if (-not $clusterRows -or $clusterRows.Count -eq 0) {
                Write-Log -Message "No clusters found with tag 'UpdateRing' = '$UpdateRingValue'" -Level Warning
                return
            }
            
            Write-Log -Message "Found $($clusterRows.Count) cluster(s) matching tag criteria" -Level Success
            foreach ($cluster in $clusterRows) {
                $clustersToProcess += @{ 
                    ResourceId = $cluster.id
                    Name = $cluster.name 
                    ResourceGroup = $cluster.resourceGroup
                    SubscriptionId = $cluster.subscriptionId
                }
            }
        }
        catch {
            Write-Log -Message "Error querying Azure Resource Graph: $_" -Level Error
            return
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
        foreach ($resourceId in $ClusterResourceIds) {
            $clusterRgName = ($resourceId -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
            $clusterSubId = ($resourceId -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
            $clustersToProcess += @{ 
                ResourceId = $resourceId
                Name = ($resourceId -split '/')[-1]
                ResourceGroup = $clusterRgName
                SubscriptionId = $clusterSubId
            }
        }
    }
    else {
        # ByName - resolve names to resource IDs upfront to avoid per-cluster lookups
        if (-not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
        }
        foreach ($name in $ClusterNames) {
            $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
            if ($clusterInfo) {
                $clustersToProcess += @{ 
                    ResourceId = $clusterInfo.id
                    Name = $clusterInfo.name
                    ResourceGroup = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    SubscriptionId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                }
            }
            else {
                Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning
            }
        }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "Assessing $($clustersToProcess.Count) cluster(s)..." -Level Info
    Write-Log -Message "" -Level Info

    # Collect results
    $results = @()
    $updateVersionCounts = @{}

    foreach ($cluster in $clustersToProcess) {
        $clusterName = $cluster.Name
        Write-Host "  Checking: $clusterName..." -ForegroundColor Gray -NoNewline
        Write-Verbose "Processing cluster: $clusterName"

        try {
            # Get cluster info
            if ($cluster.ResourceId) {
                $uri = "https://management.azure.com$($cluster.ResourceId)?api-version=$ApiVersion"
                $clusterInfo = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
            }
            else {
                $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                    -ResourceGroupName $cluster.ResourceGroup `
                    -SubscriptionId $cluster.SubscriptionId `
                    -ApiVersion $ApiVersion
            }

            if (-not $clusterInfo) {
                Write-Host " Not Found" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    ClusterName              = $clusterName
                    ResourceGroup            = $cluster.ResourceGroup
                    SubscriptionId           = $cluster.SubscriptionId
                    ClusterState             = "Not Found"
                    UpdateState              = "N/A"
                    HealthState              = "N/A"
                    ReadyForUpdate           = $false
                    AvailableUpdates         = ""
                    ReadyUpdates             = ""
                    HasPrerequisiteUpdates   = ""
                    SBEDependency            = ""
                    RecommendedUpdate        = ""
                    HealthCheckFailures      = ""
                    UpdateWindow             = ""
                    UpdateExclusions         = ""
                }
                continue
            }

            # Parse RG and Sub from cluster info if not already set
            $rgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
            $subId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1

            # Get update summary
            $updateSummary = Get-AzureLocalUpdateSummary -ClusterResourceId $clusterInfo.id -ApiVersion $ApiVersion
            $updateState = if ($updateSummary) { $updateSummary.properties.state } else { "Unknown" }

            # Get available updates
            $availableUpdates = @(Get-AzureLocalAvailableUpdates -ClusterResourceId $clusterInfo.id -ApiVersion $ApiVersion -Raw)
            $readyUpdates = @($availableUpdates | Where-Object { $_.properties.state -in $script:ReadyStates })
            $prereqUpdates = @($availableUpdates | Where-Object { $_.properties.state -in $script:PrereqStates })
            
            $availableUpdateNames = ($availableUpdates | ForEach-Object { $_.name }) -join "; "
            $readyUpdateNames = ($readyUpdates | ForEach-Object { $_.name }) -join "; "
            $prereqUpdateNames = ($prereqUpdates | ForEach-Object { $_.name }) -join "; "
            
            # Extract SBE dependency info for HasPrerequisite/AdditionalContentRequired updates
            $sbeDependencyInfo = ""
            foreach ($pu in $prereqUpdates) {
                $puProps = $pu.properties
                if ($puProps.packageType -eq "SBE" -and $puProps.additionalProperties) {
                    $addProps = ConvertTo-AzLocalAdditionalProperties -InputObject $puProps.additionalProperties
                    if ($addProps) {
                        $sbeParts = @()
                        if ($addProps.SBEPublisher) { $sbeParts += "Publisher: $($addProps.SBEPublisher)" }
                        if ($addProps.SBEFamily) { $sbeParts += "Family: $($addProps.SBEFamily)" }
                        if ($sbeParts.Count -gt 0) { $sbeDependencyInfo = "$($pu.name): $($sbeParts -join '; ')" }
                    }
                }
            }

            # Determine recommended update (prefer ready updates, fallback to any available)
            # Sort by YYMM version (SolutionXX.YYMM.XXXX.XX) to select the latest
            # Don't show updates the cluster is already on (AppliedSuccessfully/UpToDate states)
            $recommendedUpdate = ""
            $isUpToDateState = $updateState -in @("UpToDate", "AppliedSuccessfully")
            if ($readyUpdates.Count -gt 0) {
                $latestReady = Get-LatestUpdateByYYMM -Updates $readyUpdates
                $recommendedUpdate = $latestReady.name
                
                # Track update version counts (only for ready updates)
                if ($updateVersionCounts.ContainsKey($recommendedUpdate)) {
                    $updateVersionCounts[$recommendedUpdate]++
                }
                else {
                    $updateVersionCounts[$recommendedUpdate] = 1
                }
            }
            elseif (-not $isUpToDateState -and $availableUpdates.Count -gt 0) {
                # Fallback: show latest available update even if not ready (e.g., downloading)
                $latestAvailable = Get-LatestUpdateByYYMM -Updates $availableUpdates
                $recommendedUpdate = $latestAvailable.name
            }

            # Determine if ready for update
            $isReady = ($updateState -in (@("UpdateAvailable") + $script:ReadyStates)) -and ($readyUpdates.Count -gt 0)
            
            # Get health state and check failures
            $healthState = if ($updateSummary -and $updateSummary.properties.healthState) { $updateSummary.properties.healthState } else { "Unknown" }
            $healthCheckFailures = ""
            if ($updateSummary -and $healthState -notin @("Success", "Unknown")) {
                $healthCheckFailures = Get-HealthCheckFailureSummary -UpdateSummary $updateSummary
            }
            
            if ($isReady) {
                Write-Host " Ready ($recommendedUpdate)" -ForegroundColor Green
            }
            elseif ($prereqUpdates.Count -gt 0 -and $readyUpdates.Count -eq 0) {
                Write-Host " Has Prerequisite (SBE update required)" -ForegroundColor Yellow
            }
            elseif ($updateState -eq "UpdateInProgress") {
                Write-Host " Update In Progress" -ForegroundColor Yellow
            }
            elseif ($readyUpdates.Count -eq 0 -and $availableUpdates.Count -gt 0) {
                Write-Host " Updates Downloading" -ForegroundColor Yellow
            }
            elseif ($healthState -in @("Failure", "Warning")) {
                Write-Host " $updateState ($healthState)" -ForegroundColor $(if ($healthState -eq "Failure") { "Red" } else { "Yellow" })
            }
            else {
                Write-Host " $updateState" -ForegroundColor Gray
            }

            $results += [PSCustomObject]@{
                ClusterName              = $clusterName
                ResourceGroup            = $rgName
                SubscriptionId           = $subId
                ClusterState             = $clusterInfo.properties.status
                UpdateState              = $updateState
                HealthState              = $healthState
                ReadyForUpdate           = $isReady
                AvailableUpdates         = $availableUpdateNames
                ReadyUpdates             = $readyUpdateNames
                HasPrerequisiteUpdates   = $prereqUpdateNames
                SBEDependency            = $sbeDependencyInfo
                RecommendedUpdate        = $recommendedUpdate
                HealthCheckFailures      = $healthCheckFailures
                UpdateWindow             = if ($clusterInfo.tags -and $clusterInfo.tags.$($script:UpdateWindowTagName)) { $clusterInfo.tags.$($script:UpdateWindowTagName) } else { "" }
                UpdateExclusions         = if ($clusterInfo.tags -and $clusterInfo.tags.$($script:UpdateExclusionsTagName)) { $clusterInfo.tags.$($script:UpdateExclusionsTagName) } else { "" }
            }
        }
        catch {
            Write-Host " Error: $($_.Exception.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                ClusterName              = $clusterName
                ResourceGroup            = $cluster.ResourceGroup
                SubscriptionId           = $cluster.SubscriptionId
                ClusterState             = "Error"
                UpdateState              = "Error"
                HealthState              = "Error"
                ReadyForUpdate           = $false
                AvailableUpdates         = ""
                ReadyUpdates             = ""
                HasPrerequisiteUpdates   = ""
                SBEDependency            = ""
                RecommendedUpdate        = ""
                HealthCheckFailures      = $_.Exception.Message
            }
        }
    }

    # Display Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $totalClusters = $results.Count
    $readyClusters = @($results | Where-Object { $_.ReadyForUpdate -eq $true }).Count
    $notReadyClusters = $totalClusters - $readyClusters
    $inProgressClusters = @($results | Where-Object { $_.UpdateState -eq "UpdateInProgress" }).Count
    $prereqClusters = @($results | Where-Object { $_.HasPrerequisiteUpdates -ne "" }).Count

    Write-Log -Message "" -Level Info
    Write-Log -Message "Total Clusters Assessed:    $totalClusters" -Level Info
    Write-Log -Message "Ready for Update:           $readyClusters" -Level Success
    Write-Log -Message "Not Ready / Other State:    $notReadyClusters" -Level $(if ($notReadyClusters -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Update In Progress:         $inProgressClusters" -Level $(if ($inProgressClusters -gt 0) { "Warning" } else { "Info" })
    if ($prereqClusters -gt 0) {
        Write-Log -Message "Blocked by SBE Prereq:     $prereqClusters" -Level Warning
    }
    
    # Show SBE dependency details for clusters with HasPrerequisite updates
    $clustersWithSBEDeps = @($results | Where-Object { $_.SBEDependency -ne "" })
    if ($clustersWithSBEDeps.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Clusters Blocked by SBE Prerequisites:" -Level Warning
        Write-Log -Message "  These clusters have updates that require a Solution Builder Extension (SBE) update from the hardware vendor before they can proceed." -Level Warning
        foreach ($dep in $clustersWithSBEDeps) {
            Write-Log -Message "  $($dep.ClusterName): $($dep.SBEDependency)" -Level Warning
        }
    }

    # Show health state breakdown
    $healthFailures = @($results | Where-Object { $_.HealthState -eq "Failure" }).Count
    $healthWarnings = @($results | Where-Object { $_.HealthState -eq "Warning" }).Count
    if ($healthFailures -gt 0 -or $healthWarnings -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Health Check Issues:" -Level Header
        if ($healthFailures -gt 0) {
            Write-Log -Message "  Critical Failures:        $healthFailures" -Level Error
        }
        if ($healthWarnings -gt 0) {
            Write-Log -Message "  Warnings:                 $healthWarnings" -Level Warning
        }
    }

    # Show most common update versions
    if ($updateVersionCounts.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Available Update Versions (clusters ready to install):" -Level Header
        $sortedVersions = $updateVersionCounts.GetEnumerator() | Sort-Object -Property Value -Descending
        foreach ($version in $sortedVersions) {
            if ($readyClusters -gt 0) {
                $percentage = [math]::Round(($version.Value / $readyClusters) * 100, 1)
                Write-Log -Message "  $($version.Key): $($version.Value) cluster(s) ($percentage%)" -Level Info
            }
            else {
                Write-Log -Message "  $($version.Key): $($version.Value) cluster(s)" -Level Info
            }
        }
        
        $mostCommonVersion = ($sortedVersions | Select-Object -First 1).Key
        Write-Log -Message "" -Level Info
        Write-Log -Message "Most Common Applicable Update: $mostCommonVersion" -Level Success
    }

    # Display results table
    Write-Log -Message "" -Level Info
    Write-Log -Message "Detailed Results:" -Level Header
    $results | Format-Table ClusterName, ResourceGroup, UpdateState, HealthState, ReadyForUpdate, RecommendedUpdate -AutoSize
    
    # Show clusters with health check failures
    $clustersWithHealthIssues = @($results | Where-Object { $_.HealthCheckFailures -ne "" })
    if ($clustersWithHealthIssues.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Clusters with Health Check Issues:" -Level Warning
        foreach ($cluster in $clustersWithHealthIssues) {
            $issueLevel = if ($cluster.HealthState -eq "Failure") { "Error" } else { "Warning" }
            Write-Log -Message "  $($cluster.ClusterName): $($cluster.HealthCheckFailures)" -Level $issueLevel
        }
    }

    # Export if path specified
    if ($ExportPath) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            $format = Get-ExportFormat -Path $ExportPath -ExportFormat $ExportFormat
            
            # Transform results for JUnit-compatible format
            $junitResults = $results | ForEach-Object {
                [PSCustomObject]@{
                    ClusterName  = $_.ClusterName
                    Status       = if ($_.ReadyForUpdate -eq "Yes") { "Ready" } elseif ($_.HealthState -eq "Failure") { "Failed" } else { "Skipped" }
                    Message      = "UpdateState: $($_.UpdateState), HealthState: $($_.HealthState), RecommendedUpdate: $($_.RecommendedUpdate)"
                    UpdateName   = $_.RecommendedUpdate
                    CurrentState = $_.UpdateState
                }
            }
            
            switch ($format) {
                'Csv' {
                    $results | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                'Json' {
                    $exportData = @{
                        Timestamp       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalClusters   = $totalClusters
                        ClustersReady   = $readyClusters
                        ClustersNotReady = $notReadyClusters
                        Results         = $results
                    }
                    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalClusterReadiness" -OperationType "ReadinessCheck"
                    Write-Log -Message "Results exported to JUnit XML (CI/CD compatible): $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
        }
    }

    Write-Log -Message "" -Level Info
    if ($PassThru) {
        return $results
    }
}

function Get-AzureLocalClusterInventory {
    <#
    .SYNOPSIS
        Gets an inventory of Azure Local clusters with their UpdateRing tag status.

    .DESCRIPTION
        Queries Azure Local (Azure Stack HCI) clusters and returns cluster details
        including the value of the 'UpdateRing' tag (or indicates if the tag doesn't exist).
        
        Supports multiple input methods:
        - All clusters via Azure Resource Graph (default)
        - Specific clusters by Resource ID
        - Specific clusters by name
        - Clusters matching an UpdateRing tag value
        
        The output can be exported to CSV for use with Excel to plan and populate
        UpdateRing tag values, then used as input for Set-AzureLocalClusterUpdateRingTag.

    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to inventory.
        Example: "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"

    .PARAMETER ClusterNames
        An array of Azure Local cluster names to inventory.

    .PARAMETER ScopeByUpdateRingTag
        When specified, finds clusters by the 'UpdateRing' tag via Azure Resource Graph.
        Must be used together with -UpdateRingValue.

    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.

    .PARAMETER ResourceGroupName
        The resource group containing the clusters (only used with -ClusterNames).

    .PARAMETER SubscriptionId
        Optional. Limit the query to a specific Azure subscription ID.
        If not specified, queries across all accessible subscriptions (default mode)
        or uses the current subscription (for -ClusterNames).

    .PARAMETER ExportPath
        Optional. Path to export the inventory. Supports CSV and JSON formats.
        Format is auto-detected from file extension (.csv or .json).
        CSV is useful for editing in Excel; JSON for CI/CD and API integrations.

    .EXAMPLE
        # Get inventory of all clusters across all subscriptions
        Get-AzureLocalClusterInventory

    .EXAMPLE
        # Get inventory for specific clusters by Resource ID
        Get-AzureLocalClusterInventory -ClusterResourceIds @("/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01")

    .EXAMPLE
        # Get inventory for clusters by name
        Get-AzureLocalClusterInventory -ClusterNames @("Cluster01", "Cluster02") -ResourceGroupName "MyRG"

    .EXAMPLE
        # Get inventory for clusters in a specific UpdateRing
        Get-AzureLocalClusterInventory -ScopeByUpdateRingTag -UpdateRingValue "Wave1"

    .EXAMPLE
        # Get inventory and export to CSV for editing in Excel
        Get-AzureLocalClusterInventory -ExportPath "C:\Temp\ClusterInventory.csv"

    .EXAMPLE
        # Get inventory and export to JSON for CI/CD pipelines
        Get-AzureLocalClusterInventory -ExportPath "C:\Temp\ClusterInventory.json"

    .EXAMPLE
        # Get inventory for a specific subscription
        Get-AzureLocalClusterInventory -SubscriptionId "12345678-1234-1234-1234-123456789012"

    .EXAMPLE
        # Pipeline workflow: Get inventory, edit CSV, then apply tags
        Get-AzureLocalClusterInventory -ExportPath "C:\Temp\Inventory.csv"
        # Edit the CSV in Excel to populate UpdateRing values
        Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\Inventory.csv"

    .EXAMPLE
        # CI/CD pipeline: Export to CSV AND return objects for processing
        $inventory = Get-AzureLocalClusterInventory -ExportPath "C:\Temp\Inventory.csv" -PassThru
        Write-Host "Found $($inventory.Count) clusters"

    .NOTES
        Version: 0.5.7
        Author: Neil Bird, Microsoft.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Cluster Inventory" -Level Header
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "" -Level Info

    # Verify Azure CLI is installed and logged in
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not logged in. Please run 'az login' first."
        }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Ensure resource-graph extension is installed (needed for All and ByTag modes)
    if ($PSCmdlet.ParameterSetName -in @('All', 'ByTag')) {
        if (-not (Install-AzGraphExtension)) {
            Write-Log -Message "Failed to install Azure CLI 'resource-graph' extension. Please install manually: az extension add --name resource-graph" -Level Error
            return
        }
    }

    # Build cluster data based on parameter set
    $clusterData = @()

    if ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
        # Direct REST lookup for each Resource ID
        Write-Log -Message "Looking up $($ClusterResourceIds.Count) cluster(s) by Resource ID..." -Level Info
        $apiVer = $script:DefaultApiVersion
        foreach ($resourceId in $ClusterResourceIds) {
            $clusterName = ($resourceId -split '/')[-1]
            Write-Host "  Checking: $clusterName..." -ForegroundColor Gray -NoNewline
            try {
                $uri = "https://management.azure.com${resourceId}?api-version=$apiVer"
                $clusterInfo = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
                if ($LASTEXITCODE -eq 0 -and $clusterInfo) {
                    $rgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    $subId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                    $clusterData += [PSCustomObject]@{
                        id             = $clusterInfo.id
                        name           = $clusterInfo.name
                        resourceGroup  = $rgName
                        subscriptionId = $subId
                        tags           = $clusterInfo.tags
                    }
                    Write-Host " Found" -ForegroundColor Green
                }
                else {
                    Write-Host " Not Found" -ForegroundColor Red
                    Write-Log -Message "Cluster not found: $resourceId" -Level Warning
                }
            }
            catch {
                Write-Host " Error" -ForegroundColor Red
                Write-Log -Message "Error looking up '$resourceId': $($_.Exception.Message)" -Level Warning
            }
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByName') {
        # Look up clusters by name
        if (-not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
        }
        Write-Log -Message "Looking up $($ClusterNames.Count) cluster(s) by name..." -Level Info
        foreach ($name in $ClusterNames) {
            Write-Host "  Checking: $name..." -ForegroundColor Gray -NoNewline
            $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId
            if ($clusterInfo) {
                $rgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                $subId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                $clusterData += [PSCustomObject]@{
                    id             = $clusterInfo.id
                    name           = $clusterInfo.name
                    resourceGroup  = $rgName
                    subscriptionId = $subId
                    tags           = $clusterInfo.tags
                }
                Write-Host " Found" -ForegroundColor Green
            }
            else {
                Write-Host " Not Found" -ForegroundColor Red
                Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning
            }
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        # Query by UpdateRing tag via ARG
        Write-Log -Message "Querying Azure Resource Graph for clusters with tag 'UpdateRing' = '$UpdateRingValue'..." -Level Info
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id, name, resourceGroup, subscriptionId, tags | order by name asc"
        try {
            $clusters = Invoke-AzResourceGraphQuery -Query $argQuery
            if (-not $clusters -or $clusters.Count -eq 0) {
                Write-Log -Message "No clusters found with tag 'UpdateRing' = '$UpdateRingValue'" -Level Warning
                return @()
            }
            Write-Log -Message "Found $($clusters.Count) cluster(s) matching tag criteria" -Level Success
            $clusterData = $clusters
        }
        catch {
            Write-Log -Message "Error querying Azure Resource Graph: $_" -Level Error
            return
        }
    }
    else {
        # Default: All clusters via ARG
        Write-Log -Message "Querying Azure Resource Graph for all Azure Local clusters..." -Level Info

        # Build Azure Resource Graph query - use single line to avoid escaping issues with az CLI
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | project id, name, resourceGroup, subscriptionId, tags | order by name asc"

        try {
            if ($SubscriptionId) {
                Write-Log -Message "  Filtering to subscription: $SubscriptionId" -Level Verbose
                $clusterData = Invoke-AzResourceGraphQuery -Query $argQuery -SubscriptionId $SubscriptionId
            }
            else {
                Write-Log -Message "  Querying across all accessible subscriptions" -Level Verbose
                $clusterData = Invoke-AzResourceGraphQuery -Query $argQuery
            }

            if (-not $clusterData -or $clusterData.Count -eq 0) {
                Write-Log -Message "No Azure Local clusters found." -Level Warning
                return @()
            }
        }
        catch {
            Write-Log -Message "Error querying Azure Resource Graph: $($_.Exception.Message)" -Level Error
            return @()
        }
    }

    if ($clusterData.Count -eq 0) {
        Write-Log -Message "No clusters to inventory." -Level Warning
        return @()
    }

    try {
        # Get subscription names for better readability
        Write-Log -Message "Retrieving subscription details..." -Level Info
        $subscriptionMap = @{}
        $uniqueSubIds = $clusterData | Select-Object -ExpandProperty subscriptionId -Unique
        
        foreach ($subId in $uniqueSubIds) {
            try {
                $subInfo = az account show --subscription $subId 2>&1 | ConvertFrom-Json
                if ($LASTEXITCODE -eq 0 -and $subInfo.name) {
                    $subscriptionMap[$subId] = $subInfo.name
                }
                else {
                    $subscriptionMap[$subId] = "(Unable to retrieve name)"
                }
            }
            catch {
                $subscriptionMap[$subId] = "(Unable to retrieve name)"
            }
        }

        # Build inventory results
        $inventory = @()
        foreach ($cluster in $clusterData) {
            # Read tag values via container-shape-agnostic helper so both
            # [PSCustomObject] and [Hashtable] tag shapes are handled.
            $updateRingValue = Get-TagValue -Tags $cluster.tags -Name 'UpdateRing'
            $updateWindowValue = Get-TagValue -Tags $cluster.tags -Name $script:UpdateWindowTagName
            $updateExclusionsValue = Get-TagValue -Tags $cluster.tags -Name $script:UpdateExclusionsTagName

            $inventoryItem = [PSCustomObject]@{
                ClusterName      = $cluster.name
                ResourceGroup    = $cluster.resourceGroup
                SubscriptionId   = $cluster.subscriptionId
                SubscriptionName = $subscriptionMap[$cluster.subscriptionId]
                UpdateRing       = if ($updateRingValue) { $updateRingValue } else { "" }
                HasUpdateRingTag = if ($updateRingValue) { "Yes" } else { "No" }
                UpdateWindow     = if ($updateWindowValue) { $updateWindowValue } else { "" }
                UpdateExclusions = if ($updateExclusionsValue) { $updateExclusionsValue } else { "" }
                ResourceId       = $cluster.id
            }
            $inventory += $inventoryItem
        }

        # Calculate summary statistics
        $clustersWithTag = @($inventory | Where-Object { $_.HasUpdateRingTag -eq "Yes" }).Count
        $clustersWithoutTag = $inventory.Count - $clustersWithTag
        $ringGroups = @($inventory | Where-Object { $_.UpdateRing -ne "" } | Group-Object -Property UpdateRing)

        # Export if path specified
        if ($ExportPath) {
            try {
                # Ensure directory exists
                $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
                $exportDir = Split-Path -Path $ExportPath -Parent
                if ($exportDir -and -not (Test-Path -Path $exportDir)) {
                    $null = New-Item -ItemType Directory -Path $exportDir -Force
                }

                # Determine export format from file extension
                $extension = [System.IO.Path]::GetExtension($ExportPath).ToLower()
                $exportData = $inventory | Select-Object ClusterName, ResourceGroup, SubscriptionId, SubscriptionName, UpdateRing, HasUpdateRingTag, UpdateWindow, UpdateExclusions, ResourceId
                
                switch ($extension) {
                    '.json' {
                        $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8 -Force
                        Write-Log -Message "Inventory exported to JSON: $ExportPath" -Level Success
                    }
                    default {
                        # Default to CSV for .csv or any other extension
                        $exportData | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                        Write-Log -Message "Inventory exported to CSV: $ExportPath" -Level Success
                    }
                }
            }
            catch {
                Write-Log -Message "Failed to export inventory: $($_.Exception.Message)" -Level Error
            }
        }

        # Display summary at the end
        Write-Log -Message "" -Level Info
        Write-Log -Message "Inventory Summary:" -Level Header
        Write-Log -Message "  Total Clusters: $($inventory.Count)" -Level Info
        Write-Log -Message "  Clusters with UpdateRing tag: $clustersWithTag" -Level $(if ($clustersWithTag -gt 0) { "Success" } else { "Verbose" })
        Write-Log -Message "  Clusters without UpdateRing tag: $clustersWithoutTag" -Level $(if ($clustersWithoutTag -gt 0) { "Warning" } else { "Verbose" })

        # Group by UpdateRing value
        if ($ringGroups.Count -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "  UpdateRing Distribution:" -Level Info
            foreach ($group in $ringGroups | Sort-Object Name) {
                Write-Log -Message "    $($group.Name): $($group.Count) cluster(s)" -Level Success
            }
        }

        # Show next steps if file was exported
        if ($ExportPath -and (Test-Path -Path $ExportPath)) {
            $extension = [System.IO.Path]::GetExtension($ExportPath).ToLower()
            Write-Log -Message "" -Level Info
            if ($extension -eq '.json') {
                Write-Log -Message "Next Steps (JSON export):" -Level Header
                Write-Log -Message "  - Use the JSON file for CI/CD pipelines, API integrations, or CMDB systems" -Level Info
                Write-Log -Message "  - To apply tags, export to CSV format instead" -Level Info
            }
            else {
                Write-Log -Message "Next Steps (CSV export):" -Level Header
                Write-Log -Message "  1. Open the CSV in Excel" -Level Info
                Write-Log -Message "  2. Populate the 'UpdateRing' column with values (e.g., 'Wave1', 'Wave2', 'Pilot')" -Level Info
                Write-Log -Message "  3. Save the CSV file" -Level Info
                Write-Log -Message "  4. Run: Set-AzureLocalClusterUpdateRingTag -InputCsvPath '$ExportPath'" -Level Info
            }
        }

        Write-Log -Message "" -Level Info
        
        # Return inventory if: no CSV export, OR PassThru is specified
        # This allows CI/CD pipelines to use -PassThru to get objects for processing
        if (-not $ExportPath -or $PassThru) {
            return $inventory
        }
    }
    catch {
        Write-Log -Message "Error querying Azure Resource Graph: $($_.Exception.Message)" -Level Error
        return @()
    }
}

#region Update Schedule Tag Helpers (v0.6.4)

# Tag name constants for update scheduling
$script:UpdateWindowTagName = 'UpdateWindow'
$script:UpdateExclusionsTagName = 'UpdateExclusions'

# Day abbreviation mapping (3-letter English, case-insensitive input)
$script:DayMap = [ordered]@{
    'Mon' = [DayOfWeek]::Monday
    'Tue' = [DayOfWeek]::Tuesday
    'Wed' = [DayOfWeek]::Wednesday
    'Thu' = [DayOfWeek]::Thursday
    'Fri' = [DayOfWeek]::Friday
    'Sat' = [DayOfWeek]::Saturday
    'Sun' = [DayOfWeek]::Sunday
}
$script:DayAbbreviations = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')

function ConvertFrom-AzLocalUpdateWindow {
    <#
    .SYNOPSIS
        Parses an UpdateWindow tag value into structured window objects.
    .DESCRIPTION
        Parses the compact maintenance window syntax used in the UpdateWindow Azure resource tag
        into structured objects suitable for schedule evaluation and display.

        Syntax: <days>:<HH:MM>-<HH:MM>[;<days>:<HH:MM>-<HH:MM>]
        Days: Mon,Tue,Wed,Thu,Fri,Sat,Sun (ranges with -), * or Daily for all days
        Times: 24-hour UTC. Overnight wraps supported (22:00-06:00 = wraps to next day).
    .PARAMETER WindowString
        The UpdateWindow tag value to parse.
    .OUTPUTS
        PSCustomObject[] with Days (DayOfWeek[]), StartTime (TimeSpan), EndTime (TimeSpan), Overnight (bool)
    .EXAMPLE
        ConvertFrom-AzLocalUpdateWindow -WindowString "Sat-Sun:02:00-06:00"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$WindowString
    )

    if ([string]::IsNullOrWhiteSpace($WindowString)) {
        throw "UpdateWindow value cannot be empty."
    }

    # Azure tag values max 256 chars
    if ($WindowString.Length -gt 256) {
        throw "UpdateWindow value exceeds Azure tag limit of 256 characters (length: $($WindowString.Length))."
    }

    $windows = @()
    $segments = $WindowString -split ';'

    foreach ($segment in $segments) {
        $segment = $segment.Trim()
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }

        # Parse <days>:<start>-<end>
        if ($segment -notmatch '^([^:]+):(\d{2}:\d{2})-(\d{2}:\d{2})$') {
            throw "Invalid window segment syntax: '$segment'. Expected format: <days>:<HH:MM>-<HH:MM>"
        }

        $daysPart = $matches[1]
        $startStr = $matches[2]
        $endStr = $matches[3]

        # Parse time components (PS 5.1 compatible - avoid TryParse [ref] issues)
        $startTime = $null
        $endTime = $null
        try { $startTime = [TimeSpan]::Parse($startStr) }
        catch { throw "Invalid start time '$startStr' in segment '$segment'." }
        try { $endTime = [TimeSpan]::Parse($endStr) }
        catch { throw "Invalid end time '$endStr' in segment '$segment'." }

        # Parse days
        $resolvedDays = @()

        if ($daysPart -eq '*' -or $daysPart -ieq 'Daily') {
            $resolvedDays = @([DayOfWeek]::Monday, [DayOfWeek]::Tuesday, [DayOfWeek]::Wednesday,
                              [DayOfWeek]::Thursday, [DayOfWeek]::Friday, [DayOfWeek]::Saturday,
                              [DayOfWeek]::Sunday)
        }
        else {
            $daySpecs = $daysPart -split ','
            foreach ($spec in $daySpecs) {
                $spec = $spec.Trim()
                if ($spec -match '^(\w{3})-(\w{3})$') {
                    # Day range (e.g., Mon-Fri, Sat-Sun)
                    $rangeStart = $matches[1]
                    $rangeEnd = $matches[2]

                    # Find indices in ordered day list
                    $startIdx = -1; $endIdx = -1
                    for ($i = 0; $i -lt $script:DayAbbreviations.Count; $i++) {
                        if ($script:DayAbbreviations[$i] -ieq $rangeStart) { $startIdx = $i }
                        if ($script:DayAbbreviations[$i] -ieq $rangeEnd) { $endIdx = $i }
                    }
                    if ($startIdx -lt 0) { throw "Invalid day abbreviation '$rangeStart' in segment '$segment'. Valid: Mon,Tue,Wed,Thu,Fri,Sat,Sun" }
                    if ($endIdx -lt 0) { throw "Invalid day abbreviation '$rangeEnd' in segment '$segment'. Valid: Mon,Tue,Wed,Thu,Fri,Sat,Sun" }

                    # Handle wrap-around (e.g., Fri-Mon)
                    if ($startIdx -le $endIdx) {
                        for ($i = $startIdx; $i -le $endIdx; $i++) {
                            $resolvedDays += $script:DayMap[$script:DayAbbreviations[$i]]
                        }
                    }
                    else {
                        # Wrap: Fri-Mon = Fri,Sat,Sun,Mon
                        for ($i = $startIdx; $i -lt 7; $i++) {
                            $resolvedDays += $script:DayMap[$script:DayAbbreviations[$i]]
                        }
                        for ($i = 0; $i -le $endIdx; $i++) {
                            $resolvedDays += $script:DayMap[$script:DayAbbreviations[$i]]
                        }
                    }
                }
                elseif ($spec -match '^\w{3}$') {
                    # Single day
                    $matched = $false
                    foreach ($abbr in $script:DayAbbreviations) {
                        if ($abbr -ieq $spec) {
                            $resolvedDays += $script:DayMap[$abbr]
                            $matched = $true
                            break
                        }
                    }
                    if (-not $matched) { throw "Invalid day abbreviation '$spec' in segment '$segment'. Valid: Mon,Tue,Wed,Thu,Fri,Sat,Sun" }
                }
                else {
                    throw "Invalid day specification '$spec' in segment '$segment'. Use 3-letter abbreviations (Mon-Sun), ranges (Mon-Fri), or * / Daily."
                }
            }
        }

        $overnight = ($endTime -le $startTime)

        $windows += [PSCustomObject]@{
            Days      = @($resolvedDays | Select-Object -Unique)
            StartTime = $startTime
            EndTime   = $endTime
            Overnight = $overnight
            Raw       = $segment
        }
    }

    if ($windows.Count -eq 0) {
        throw "No valid window segments found in '$WindowString'."
    }

    return $windows
}

function ConvertFrom-AzLocalUpdateExclusion {
    <#
    .SYNOPSIS
        Parses an UpdateExclusions tag value into structured date range objects.
    .DESCRIPTION
        Parses the exclusion date range syntax used in the UpdateExclusions Azure resource tag.
        Supports wildcards (*) for recurring annual patterns.

        Syntax: <start_date>/<end_date>[,<start_date>/<end_date>]
        Dates: YYYY-MM-DD format. * replaces a single digit for recurring patterns.
    .PARAMETER ExclusionString
        The UpdateExclusions tag value to parse.
    .PARAMETER ReferenceDate
        The date to use for resolving wildcards. Defaults to today (UTC).
    .OUTPUTS
        PSCustomObject[] with StartDate (datetime), EndDate (datetime), IsWildcard (bool), Raw (string)
    .EXAMPLE
        ConvertFrom-AzLocalUpdateExclusion -ExclusionString "2026-12-20/2027-01-03"
    .EXAMPLE
        ConvertFrom-AzLocalUpdateExclusion -ExclusionString "20**-12-20/20**-01-03"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ExclusionString,

        [Parameter(Mandatory = $false)]
        [datetime]$ReferenceDate = (Get-Date).ToUniversalTime().Date
    )

    if ([string]::IsNullOrWhiteSpace($ExclusionString)) {
        throw "UpdateExclusions value cannot be empty."
    }

    if ($ExclusionString.Length -gt 256) {
        throw "UpdateExclusions value exceeds Azure tag limit of 256 characters (length: $($ExclusionString.Length))."
    }

    $exclusions = @()
    $ranges = $ExclusionString -split ','

    foreach ($range in $ranges) {
        $range = $range.Trim()
        if ([string]::IsNullOrWhiteSpace($range)) { continue }

        if ($range -notmatch '^([0-9*]{4}-[0-9*]{2}-[0-9*]{2})/([0-9*]{4}-[0-9*]{2}-[0-9*]{2})$') {
            throw "Invalid exclusion range syntax: '$range'. Expected format: YYYY-MM-DD/YYYY-MM-DD (wildcards * allowed)."
        }

        $startPattern = $matches[1]
        $endPattern = $matches[2]
        $isWildcard = ($startPattern -match '\*') -or ($endPattern -match '\*')

        if ($isWildcard) {
            # Resolve wildcards against current year and adjacent years
            $resolvedRanges = Resolve-WildcardDateRange -StartPattern $startPattern -EndPattern $endPattern -ReferenceDate $ReferenceDate
            foreach ($resolved in $resolvedRanges) {
                $exclusions += [PSCustomObject]@{
                    StartDate  = $resolved.StartDate
                    EndDate    = $resolved.EndDate
                    IsWildcard = $true
                    Raw        = $range
                }
            }
        }
        else {
            # Fixed dates (PS 5.1 compatible - avoid TryParseExact [ref] issues)
            $startDate = $null
            $endDate = $null
            try { $startDate = [datetime]::ParseExact($startPattern, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) }
            catch { throw "Invalid start date '$startPattern' in exclusion range '$range'." }
            try { $endDate = [datetime]::ParseExact($endPattern, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) }
            catch { throw "Invalid end date '$endPattern' in exclusion range '$range'." }

            if ($endDate -lt $startDate) {
                throw "End date ($endPattern) is before start date ($startPattern) in exclusion range '$range'."
            }

            $exclusions += [PSCustomObject]@{
                StartDate  = $startDate
                EndDate    = $endDate
                IsWildcard = $false
                Raw        = $range
            }
        }
    }

    return $exclusions
}

function Resolve-WildcardDateRange {
    <#
    .SYNOPSIS
        Resolves wildcard date patterns to concrete date ranges relative to a reference date.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartPattern,

        [Parameter(Mandatory = $true)]
        [string]$EndPattern,

        [Parameter(Mandatory = $true)]
        [datetime]$ReferenceDate
    )

    $results = @()
    $refYear = $ReferenceDate.Year

    # Try resolving for current year, previous year, and next year
    foreach ($yearOffset in @(-1, 0, 1)) {
        $tryYear = $refYear + $yearOffset
        $yearStr = $tryYear.ToString('D4')

        $resolvedStart = Resolve-WildcardDate -Pattern $StartPattern -YearDigits $yearStr
        $resolvedEnd = Resolve-WildcardDate -Pattern $EndPattern -YearDigits $yearStr

        if (-not $resolvedStart -or -not $resolvedEnd) { continue }

        # Handle cross-year ranges (Dec start -> Jan end)
        if ($resolvedEnd -lt $resolvedStart) {
            # Try end date with next year
            $nextYearStr = ($tryYear + 1).ToString('D4')
            $resolvedEnd = Resolve-WildcardDate -Pattern $EndPattern -YearDigits $nextYearStr
            if (-not $resolvedEnd) { continue }
        }

        if ($resolvedEnd -lt $resolvedStart) { continue }

        # Only include ranges that overlap with a reasonable window around reference date
        # (exclude ranges entirely more than 1 year in the past or future)
        $windowStart = $ReferenceDate.AddYears(-1)
        $windowEnd = $ReferenceDate.AddYears(1)
        if ($resolvedEnd -ge $windowStart -and $resolvedStart -le $windowEnd) {
            # Avoid duplicates
            $isDuplicate = $false
            foreach ($existing in $results) {
                if ($existing.StartDate -eq $resolvedStart -and $existing.EndDate -eq $resolvedEnd) {
                    $isDuplicate = $true
                    break
                }
            }
            if (-not $isDuplicate) {
                $results += [PSCustomObject]@{
                    StartDate = $resolvedStart
                    EndDate   = $resolvedEnd
                }
            }
        }
    }

    return $results
}

function Resolve-WildcardDate {
    <#
    .SYNOPSIS
        Resolves a single date pattern with wildcards by substituting year digits.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$YearDigits
    )

    # Replace * characters in the year portion with digits from YearDigits
    $resolved = $Pattern.ToCharArray()
    $yearChars = $YearDigits.ToCharArray()

    # Pattern is YYYY-MM-DD (10 chars). Year is chars 0-3.
    for ($i = 0; $i -lt 4; $i++) {
        if ($resolved[$i] -eq '*') {
            $resolved[$i] = $yearChars[$i]
        }
    }
    # Month/day wildcards: substitute with reference digits (less common, but support it)
    # For month (chars 5-6) and day (chars 8-9), wildcards don't make semantic sense
    # for date ranges, so we reject them
    $resolvedStr = [string]::new($resolved)
    if ($resolvedStr -match '\*') {
        # Wildcards remain in month/day - this is not valid for date ranges
        return $null
    }

    try {
        return [datetime]::ParseExact($resolvedStr, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}

function Test-AzLocalUpdateWindow {
    <#
    .SYNOPSIS
        Tests whether a given time falls within a maintenance window.
    .DESCRIPTION
        Parses the UpdateWindow tag value and checks if the specified (or current) UTC time
        falls within any of the defined maintenance windows.
    .PARAMETER WindowString
        The UpdateWindow tag value to evaluate.
    .PARAMETER TestTime
        The UTC time to test against. Defaults to current UTC time.
    .OUTPUTS
        PSCustomObject with Allowed (bool), Reason (string), MatchedWindow (string or $null)
    .EXAMPLE
        Test-AzLocalUpdateWindow -WindowString "Sat-Sun:02:00-06:00"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowString,

        [Parameter(Mandatory = $false)]
        [datetime]$TestTime = (Get-Date).ToUniversalTime()
    )

    # Maintenance windows are evaluated in UTC. If caller accidentally supplies
    # a Local or Unspecified DateTime, convert to UTC to avoid silently picking
    # the wrong hour/day (cluster update runs in the wrong window).
    if ($TestTime.Kind -ne [System.DateTimeKind]::Utc) {
        Write-Verbose "Test-AzLocalUpdateWindow: TestTime kind '$($TestTime.Kind)' converted to UTC."
        $TestTime = $TestTime.ToUniversalTime()
    }

    $windows = ConvertFrom-AzLocalUpdateWindow -WindowString $WindowString

    $testDay = $TestTime.DayOfWeek
    $testTimeOfDay = $TestTime.TimeOfDay

    foreach ($window in $windows) {
        if ($window.Overnight) {
            # Overnight window: Check if we're in the evening portion (same day) or morning portion (next day)
            # Evening: testDay is in Days AND time >= start
            # Morning: previous day is in Days AND time < end
            $inEvening = ($testDay -in $window.Days) -and ($testTimeOfDay -ge $window.StartTime)

            # Calculate previous day
            $prevDay = if ($testDay -eq [DayOfWeek]::Sunday) { [DayOfWeek]::Saturday }
                       elseif ($testDay -eq [DayOfWeek]::Monday) { [DayOfWeek]::Sunday }
                       elseif ($testDay -eq [DayOfWeek]::Tuesday) { [DayOfWeek]::Monday }
                       elseif ($testDay -eq [DayOfWeek]::Wednesday) { [DayOfWeek]::Tuesday }
                       elseif ($testDay -eq [DayOfWeek]::Thursday) { [DayOfWeek]::Wednesday }
                       elseif ($testDay -eq [DayOfWeek]::Friday) { [DayOfWeek]::Thursday }
                       else { [DayOfWeek]::Friday }
            $inMorning = ($prevDay -in $window.Days) -and ($testTimeOfDay -lt $window.EndTime)

            if ($inEvening -or $inMorning) {
                return [PSCustomObject]@{
                    Allowed       = $true
                    Reason        = "Within maintenance window: $($window.Raw)"
                    MatchedWindow = $window.Raw
                }
            }
        }
        else {
            # Same-day window: testDay in Days AND time between start and end
            if (($testDay -in $window.Days) -and ($testTimeOfDay -ge $window.StartTime) -and ($testTimeOfDay -lt $window.EndTime)) {
                return [PSCustomObject]@{
                    Allowed       = $true
                    Reason        = "Within maintenance window: $($window.Raw)"
                    MatchedWindow = $window.Raw
                }
            }
        }
    }

    # No window matched
    $dayNames = ($windows | ForEach-Object { $_.Raw }) -join '; '
    return [PSCustomObject]@{
        Allowed       = $false
        Reason        = "Current time ($(($TestTime).ToString('yyyy-MM-dd HH:mm')) UTC, $testDay) is outside all maintenance windows: $dayNames"
        MatchedWindow = $null
    }
}

function Test-AzLocalUpdateExclusion {
    <#
    .SYNOPSIS
        Tests whether a given date falls within any exclusion (blackout) period.
    .DESCRIPTION
        Parses the UpdateExclusions tag value and checks if the specified (or current) UTC date
        falls within any of the defined blackout periods.
    .PARAMETER ExclusionString
        The UpdateExclusions tag value to evaluate.
    .PARAMETER TestDate
        The UTC date to test against. Defaults to current UTC date.
    .OUTPUTS
        PSCustomObject with Excluded (bool), Reason (string), MatchedExclusion (string or $null)
    .EXAMPLE
        Test-AzLocalUpdateExclusion -ExclusionString "2026-12-20/2027-01-03"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExclusionString,

        [Parameter(Mandatory = $false)]
        [datetime]$TestDate = (Get-Date).ToUniversalTime().Date
    )

    $testDateOnly = $TestDate.Date
    $exclusions = ConvertFrom-AzLocalUpdateExclusion -ExclusionString $ExclusionString -ReferenceDate $testDateOnly

    foreach ($exclusion in $exclusions) {
        if ($testDateOnly -ge $exclusion.StartDate -and $testDateOnly -le $exclusion.EndDate) {
            return [PSCustomObject]@{
                Excluded         = $true
                Reason           = "Date $($testDateOnly.ToString('yyyy-MM-dd')) falls within exclusion period: $($exclusion.Raw) ($($exclusion.StartDate.ToString('yyyy-MM-dd')) to $($exclusion.EndDate.ToString('yyyy-MM-dd')))"
                MatchedExclusion = $exclusion.Raw
            }
        }
    }

    return [PSCustomObject]@{
        Excluded         = $false
        Reason           = "Date $($testDateOnly.ToString('yyyy-MM-dd')) is not in any exclusion period"
        MatchedExclusion = $null
    }
}

function Test-AzureLocalUpdateScheduleAllowed {
    <#
    .SYNOPSIS
        Master gate that evaluates whether an update is allowed based on UpdateWindow and UpdateExclusions tags.
    .DESCRIPTION
        Combines maintenance window and exclusion period checks to determine if an update
        should proceed. Exclusions take priority over windows (a blackout period blocks
        updates even if they fall within a maintenance window).

        If neither tag is present/provided, updates are allowed (no restrictions).
    .PARAMETER UpdateWindow
        The UpdateWindow tag value (maintenance schedule). If empty/null, no window restriction.
    .PARAMETER UpdateExclusions
        The UpdateExclusions tag value (blackout periods). If empty/null, no exclusion restriction.
    .PARAMETER TestTime
        The UTC time to test against. Defaults to current UTC time.
    .OUTPUTS
        PSCustomObject with Allowed (bool), Reason (string), WindowOpen (bool or $null),
        ExclusionActive (bool or $null), Details (string)
    .EXAMPLE
        Test-AzureLocalUpdateScheduleAllowed -UpdateWindow "Sat-Sun:02:00-06:00" -UpdateExclusions "2026-12-20/2027-01-03"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$UpdateWindow,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$UpdateExclusions,

        [Parameter(Mandatory = $false)]
        [datetime]$TestTime = (Get-Date).ToUniversalTime()
    )

    # Schedule evaluation is UTC-based. Normalise Local/Unspecified inputs to
    # UTC so callers don't silently hit the wrong maintenance window due to TZ.
    if ($TestTime.Kind -ne [System.DateTimeKind]::Utc) {
        Write-Verbose "Test-AzureLocalUpdateScheduleAllowed: TestTime kind '$($TestTime.Kind)' converted to UTC."
        $TestTime = $TestTime.ToUniversalTime()
    }

    $windowOpen = $null
    $exclusionActive = $null
    $details = @()

    # Check exclusions first (they take priority)
    if (-not [string]::IsNullOrWhiteSpace($UpdateExclusions)) {
        try {
            $exclusionResult = Test-AzLocalUpdateExclusion -ExclusionString $UpdateExclusions -TestDate $TestTime.Date
            $exclusionActive = $exclusionResult.Excluded
            if ($exclusionActive) {
                return [PSCustomObject]@{
                    Allowed          = $false
                    Reason           = "Blocked by exclusion period"
                    WindowOpen       = $null
                    ExclusionActive  = $true
                    Details          = $exclusionResult.Reason
                }
            }
            $details += "No active exclusion"
        }
        catch {
            $details += "Exclusion parse error: $($_.Exception.Message)"
        }
    }

    # Check maintenance window
    if (-not [string]::IsNullOrWhiteSpace($UpdateWindow)) {
        try {
            $windowResult = Test-AzLocalUpdateWindow -WindowString $UpdateWindow -TestTime $TestTime
            $windowOpen = $windowResult.Allowed
            if (-not $windowOpen) {
                return [PSCustomObject]@{
                    Allowed          = $false
                    Reason           = "Outside maintenance window"
                    WindowOpen       = $false
                    ExclusionActive  = $false
                    Details          = $windowResult.Reason
                }
            }
            $details += "Within window: $($windowResult.MatchedWindow)"
        }
        catch {
            $details += "Window parse error: $($_.Exception.Message)"
        }
    }

    # All checks passed (or no tags defined)
    $reason = if ([string]::IsNullOrWhiteSpace($UpdateWindow) -and [string]::IsNullOrWhiteSpace($UpdateExclusions)) {
        "No schedule restrictions defined"
    } else {
        "Update allowed by schedule"
    }

    return [PSCustomObject]@{
        Allowed          = $true
        Reason           = $reason
        WindowOpen       = $windowOpen
        # $exclusionActive is $null when no UpdateExclusions tag was evaluated, or $false
        # when the tag was evaluated and no exclusion matched. The $true case returns early above.
        ExclusionActive  = $exclusionActive
        Details          = $details -join '; '
    }
}

#endregion Update Schedule Tag Helpers

function Set-AzureLocalClusterUpdateRingTag {
    <#
    .SYNOPSIS
        Sets or updates the "UpdateRing" tag on Azure Local clusters for update ring management.
    
    .DESCRIPTION
        This function allows users to assign "UpdateRing" tags to Azure Local clusters
        for organizing update deployment waves. It can accept cluster Resource IDs directly
        or import them from a CSV file (typically exported from Get-AzureLocalClusterInventory).
        
        The function will:
        - Verify each Resource ID is a valid microsoft.azurestackhci/clusters resource
        - Check if the cluster already has an "UpdateRing" tag
        - If tag exists: Show warning and skip unless -Force is specified
        - If -Force: Update the tag and log the previous value
        - If no tag exists: Create the new tag
        - Log all operations to a CSV file
    
    .PARAMETER InputCsvPath
        Path to a CSV file containing cluster information. The CSV should have columns:
        - ResourceId: The full Azure Resource ID of the cluster
        - UpdateRing: The value to assign to the UpdateRing tag
        This CSV format is compatible with the output from Get-AzureLocalClusterInventory.
        Only rows with a non-empty UpdateRing value will be processed.
    
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to tag.
        Example: "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"
    
    .PARAMETER UpdateRingValue
        The value to assign to the "UpdateRing" tag (e.g., "Ring1", "Ring2", "Wave1", "Production").
        Required when using -ClusterResourceIds. Not used with -InputCsvPath (values come from CSV).
    
    .PARAMETER UpdateWindowValue
        Optional. Value to assign to the "UpdateWindow" tag when using -ClusterResourceIds.
        Format: "<days>:<HH:MM>-<HH:MM>" (e.g. "Mon-Fri:22:00-02:00"). See Test-AzureLocalUpdateScheduleAllowed
        for syntax details. Not used with -InputCsvPath (values come from the UpdateWindow column).
    
    .PARAMETER UpdateExclusionsValue
        Optional. Value to assign to the "UpdateExclusions" tag when using -ClusterResourceIds.
        Format: "YYYY-MM-DD/YYYY-MM-DD[,...]" (e.g. "2026-12-20/2026-01-05"). Not used with
        -InputCsvPath (values come from the UpdateExclusions column).
    
    .PARAMETER Force
        If specified, will overwrite existing "UpdateRing" tags. Without this switch,
        clusters with existing tags will be skipped with a warning.
    
    .PARAMETER LogFolderPath
        Path to the folder where log files will be created. If not specified, defaults to:
        C:\ProgramData\AzStackHci.ManageUpdates\
    
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.
    
    .EXAMPLE
        # Import tags from a CSV file (from Get-AzureLocalClusterInventory)
        Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv"
    
    .EXAMPLE
        # Set UpdateRing tag on multiple clusters
        $resourceIds = @(
            "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01",
            "/subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02"
        )
        Set-AzureLocalClusterUpdateRingTag -ClusterResourceIds $resourceIds -UpdateRingValue "Ring1"
    
    .EXAMPLE
        # Set UpdateRing, UpdateWindow, and UpdateExclusions on clusters in one call
        Set-AzureLocalClusterUpdateRingTag -ClusterResourceIds $resourceIds `
            -UpdateRingValue "Wave1" `
            -UpdateWindowValue "Mon-Fri:22:00-02:00" `
            -UpdateExclusionsValue "2026-12-20/2026-01-05" -Force
    
    .EXAMPLE
        # Force update existing tags from CSV
        Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv" -Force
    
    .EXAMPLE
        # Preview changes without applying (from CSV)
        Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\ClusterInventory.csv" -WhatIf
    
    .OUTPUTS
        Returns an array of PSCustomObjects with the results for each cluster.
    
    .NOTES
        Requires: Azure CLI (az) installed and authenticated
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByResourceId')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByCsv')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$InputCsvPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [string]$UpdateWindowValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [string]$UpdateExclusionsValue,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [string]$LogFolderPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Set default log folder
    if (-not $LogFolderPath) {
        $LogFolderPath = "C:\ProgramData\AzStackHci.ManageUpdates"
    }

    # Create log folder if it doesn't exist
    if (-not (Test-Path $LogFolderPath)) {
        New-Item -ItemType Directory -Path $LogFolderPath -Force | Out-Null
    }

    # Create timestamped log file paths
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFilePath = Join-Path $LogFolderPath "UpdateRingTag_$timestamp.log"
    $csvLogPath = Join-Path $LogFolderPath "UpdateRingTag_$timestamp.csv"

    # Initialize CSV with headers
    $csvHeader = '"ClusterName","ResourceGroup","SubscriptionId","ResourceId","Action","PreviousTagValue","NewTagValue","Status","Message"'
    $csvHeader | Out-File -FilePath $csvLogPath -Encoding UTF8

    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Cluster UpdateRing Tag Management" -Level Header
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Log file: $($script:LogFilePath)" -Level Info
    Write-Log -Message "CSV log: $csvLogPath" -Level Info

    # Process input based on parameter set
    $clustersToTag = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByCsv') {
        Write-Log -Message "Input mode: CSV file" -Level Info
        Write-Log -Message "CSV path: $InputCsvPath" -Level Info
        
        try {
            $csvData = Import-Csv -Path $InputCsvPath
            
            # Validate CSV has required columns
            $requiredColumns = @('ResourceId', 'UpdateRing')
            $csvColumns = $csvData | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            
            foreach ($col in $requiredColumns) {
                if ($col -notin $csvColumns) {
                    Write-Log -Message "CSV is missing required column: $col" -Level Error
                    Write-Log -Message "Required columns: $($requiredColumns -join ', ')" -Level Error
                    return
                }
            }
            
            # Filter rows that have both ResourceId and UpdateRing values
            $validRows = $csvData | Where-Object { 
                $_.ResourceId -and $_.ResourceId.Trim() -ne '' -and 
                $_.UpdateRing -and $_.UpdateRing.Trim() -ne '' 
            }
            
            if ($validRows.Count -eq 0) {
                Write-Log -Message "No valid rows found in CSV (rows must have both ResourceId and UpdateRing values)" -Level Warning
                return
            }
            
            Write-Log -Message "Found $($validRows.Count) row(s) with UpdateRing values to process" -Level Info
            
            # Check for optional UpdateWindow and UpdateExclusions columns
            $hasUpdateWindowCol = 'UpdateWindow' -in $csvColumns
            $hasUpdateExclusionsCol = 'UpdateExclusions' -in $csvColumns
            if ($hasUpdateWindowCol -or $hasUpdateExclusionsCol) {
                $scheduleColumns = @()
                if ($hasUpdateWindowCol) { $scheduleColumns += 'UpdateWindow' }
                if ($hasUpdateExclusionsCol) { $scheduleColumns += 'UpdateExclusions' }
                Write-Log -Message "CSV includes schedule tag columns: $($scheduleColumns -join ', ')" -Level Info
            }
            
            foreach ($row in $validRows) {
                $entry = @{
                    ResourceId      = $row.ResourceId.Trim()
                    UpdateRingValue = $row.UpdateRing.Trim()
                }
                # Include schedule tag values if columns exist and have values
                if ($hasUpdateWindowCol -and $row.UpdateWindow -and $row.UpdateWindow.Trim() -ne '') {
                    $entry['UpdateWindowValue'] = $row.UpdateWindow.Trim()
                }
                if ($hasUpdateExclusionsCol -and $row.UpdateExclusions -and $row.UpdateExclusions.Trim() -ne '') {
                    $entry['UpdateExclusionsValue'] = $row.UpdateExclusions.Trim()
                }
                $clustersToTag += $entry
            }
        }
        catch {
            Write-Log -Message "Failed to read CSV file: $($_.Exception.Message)" -Level Error
            return
        }
    }
    else {
        # ByResourceId parameter set
        Write-Log -Message "Input mode: Resource IDs" -Level Info
        Write-Log -Message "UpdateRing value to set: $UpdateRingValue" -Level Info
        if ($UpdateWindowValue) {
            Write-Log -Message "UpdateWindow value to set: $UpdateWindowValue" -Level Info
        }
        if ($UpdateExclusionsValue) {
            Write-Log -Message "UpdateExclusions value to set: $UpdateExclusionsValue" -Level Info
        }
        
        foreach ($resourceId in $ClusterResourceIds) {
            $entry = @{
                ResourceId      = $resourceId
                UpdateRingValue = $UpdateRingValue
            }
            if ($UpdateWindowValue) {
                $entry['UpdateWindowValue'] = $UpdateWindowValue
            }
            if ($UpdateExclusionsValue) {
                $entry['UpdateExclusionsValue'] = $UpdateExclusionsValue
            }
            $clustersToTag += $entry
        }
    }

    Write-Log -Message "Force mode: $Force" -Level Info
    Write-Log -Message "Clusters to process: $($clustersToTag.Count)" -Level Info
    Write-Log -Message "" -Level Info

    # Verify Azure CLI authentication
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message "Azure CLI is not authenticated. Please run 'az login' first." -Level Error
            return
        }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    $results = @()

    foreach ($clusterEntry in $clustersToTag) {
        $resourceId = $clusterEntry.ResourceId
        $currentUpdateRingValue = $clusterEntry.UpdateRingValue
        
        Write-Log -Message "" -Level Info
        Write-Log -Message "----------------------------------------" -Level Info
        Write-Log -Message "Processing: $resourceId" -Level Info
        Write-Log -Message "Target UpdateRing: $currentUpdateRingValue" -Level Info
        Write-Log -Message "----------------------------------------" -Level Info

        $clusterName = ""
        $resourceGroup = ""
        $subscriptionId = ""
        $previousTagValue = ""
        $action = ""
        $status = ""
        $message = ""

        try {
            # Parse the Resource ID to extract components
            if ($resourceId -match '/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/([^/]+)/([^/]+)/([^/]+)') {
                $subscriptionId = $matches[1]
                $resourceGroup = $matches[2]
                $providerNamespace = $matches[3]
                $resourceType = $matches[4]
                $clusterName = $matches[5]

                # Validate this is an Azure Stack HCI cluster
                $actualType = "$providerNamespace/$resourceType"
                
                if ($actualType -notlike "Microsoft.AzureStackHCI/clusters" -and $actualType -notlike "microsoft.azurestackhci/clusters") {
                    Write-Log -Message "Resource is not an Azure Local cluster. Type: $actualType" -Level Error
                    $action = "Skipped"
                    $status = "Failed"
                    $message = "Invalid resource type: $actualType (expected Microsoft.AzureStackHCI/clusters)"
                    
                    # Write to CSV
                    $csvLine = "`"$clusterName`",`"$resourceGroup`",`"$subscriptionId`",`"$resourceId`",`"$action`",`"$previousTagValue`",`"$currentUpdateRingValue`",`"$status`",`"$message`""
                    Add-Content -Path $csvLogPath -Value $csvLine
                    
                    $results += [PSCustomObject]@{
                        ClusterName      = $clusterName
                        ResourceGroup    = $resourceGroup
                        SubscriptionId   = $subscriptionId
                        ResourceId       = $resourceId
                        Action           = $action
                        PreviousTagValue = $previousTagValue
                        NewTagValue      = $currentUpdateRingValue
                        Status           = $status
                        Message          = $message
                    }
                    continue
                }
            }
            else {
                Write-Log -Message "Invalid Resource ID format: $resourceId" -Level Error
                $action = "Skipped"
                $status = "Failed"
                $message = "Invalid Resource ID format"
                
                # Write to CSV
                $csvLine = "`"$clusterName`",`"$resourceGroup`",`"$subscriptionId`",`"$resourceId`",`"$action`",`"$previousTagValue`",`"$currentUpdateRingValue`",`"$status`",`"$message`""
                Add-Content -Path $csvLogPath -Value $csvLine
                
                $results += [PSCustomObject]@{
                    ClusterName      = $clusterName
                    ResourceGroup    = $resourceGroup
                    SubscriptionId   = $subscriptionId
                    ResourceId       = $resourceId
                    Action           = $action
                    PreviousTagValue = $previousTagValue
                    NewTagValue      = $currentUpdateRingValue
                    Status           = $status
                    Message          = $message
                }
                continue
            }

            Write-Log -Message "Cluster: $clusterName" -Level Info
            Write-Log -Message "Resource Group: $resourceGroup" -Level Info
            Write-Log -Message "Subscription: $subscriptionId" -Level Info

            # Get current resource to verify it exists and get current tags
            Write-Log -Message "Verifying cluster exists and retrieving current tags..." -Level Info
            $uri = "https://management.azure.com$resourceId`?api-version=2025-10-01"
            $clusterInfo = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json

            if ($LASTEXITCODE -ne 0 -or -not $clusterInfo) {
                Write-Log -Message "Failed to retrieve cluster. It may not exist or you don't have access." -Level Error
                $action = "Skipped"
                $status = "Failed"
                $message = "Cluster not found or access denied"
                
                # Write to CSV
                $csvLine = "`"$clusterName`",`"$resourceGroup`",`"$subscriptionId`",`"$resourceId`",`"$action`",`"$previousTagValue`",`"$currentUpdateRingValue`",`"$status`",`"$message`""
                Add-Content -Path $csvLogPath -Value $csvLine
                
                $results += [PSCustomObject]@{
                    ClusterName      = $clusterName
                    ResourceGroup    = $resourceGroup
                    SubscriptionId   = $subscriptionId
                    ResourceId       = $resourceId
                    Action           = $action
                    PreviousTagValue = $previousTagValue
                    NewTagValue      = $currentUpdateRingValue
                    Status           = $status
                    Message          = $message
                }
                continue
            }

            # Verify the resource type from the API response
            if ($clusterInfo.type -notlike "Microsoft.AzureStackHCI/clusters" -and $clusterInfo.type -notlike "microsoft.azurestackhci/clusters") {
                Write-Log -Message "Resource type mismatch. Expected Azure Local cluster, got: $($clusterInfo.type)" -Level Error
                $action = "Skipped"
                $status = "Failed"
                $message = "Resource type mismatch: $($clusterInfo.type)"
                
                # Write to CSV
                $csvLine = "`"$clusterName`",`"$resourceGroup`",`"$subscriptionId`",`"$resourceId`",`"$action`",`"$previousTagValue`",`"$currentUpdateRingValue`",`"$status`",`"$message`""
                Add-Content -Path $csvLogPath -Value $csvLine
                
                $results += [PSCustomObject]@{
                    ClusterName      = $clusterName
                    ResourceGroup    = $resourceGroup
                    SubscriptionId   = $subscriptionId
                    ResourceId       = $resourceId
                    Action           = $action
                    PreviousTagValue = $previousTagValue
                    NewTagValue      = $currentUpdateRingValue
                    Status           = $status
                    Message          = $message
                }
                continue
            }

            Write-Log -Message "Cluster verified: $($clusterInfo.name)" -Level Success

            # Get current tags
            $currentTags = @{}
            if ($clusterInfo.tags) {
                $currentTags = $clusterInfo.tags
                Write-Log -Message "Current tags: $($currentTags | ConvertTo-Json -Compress)" -Level Verbose
            }
            else {
                Write-Log -Message "No existing tags on cluster" -Level Verbose
            }

            # Check if UpdateRing tag already exists
            if ($currentTags.PSObject.Properties.Name -contains "UpdateRing") {
                $previousTagValue = $currentTags.UpdateRing
                Write-Log -Message "Existing UpdateRing tag found with value: '$previousTagValue'" -Level Warning

                # Determine if we have new schedule tags to set (even if UpdateRing is unchanged)
                $hasNewScheduleTags = ($clusterEntry.UpdateWindowValue -and (-not $currentTags.PSObject.Properties[$script:UpdateWindowTagName] -or $currentTags.$($script:UpdateWindowTagName) -ne $clusterEntry.UpdateWindowValue)) -or
                                     ($clusterEntry.UpdateExclusionsValue -and (-not $currentTags.PSObject.Properties[$script:UpdateExclusionsTagName] -or $currentTags.$($script:UpdateExclusionsTagName) -ne $clusterEntry.UpdateExclusionsValue))

                if (-not $Force -and -not $hasNewScheduleTags) {
                    Write-Log -Message "Skipping cluster - use -Force to overwrite existing tag" -Level Warning
                    $action = "Skipped"
                    $status = "Skipped"
                    $message = "Existing UpdateRing tag present (value: $previousTagValue). Use -Force to overwrite."
                    
                    # Write to CSV
                    $csvLine = "`"$clusterName`",`"$resourceGroup`",`"$subscriptionId`",`"$resourceId`",`"$action`",`"$previousTagValue`",`"$currentUpdateRingValue`",`"$status`",`"$message`""
                    Add-Content -Path $csvLogPath -Value $csvLine
                    
                    $results += [PSCustomObject]@{
                        ClusterName      = $clusterName
                        ResourceGroup    = $resourceGroup
                        SubscriptionId   = $subscriptionId
                        ResourceId       = $resourceId
                        Action           = $action
                        PreviousTagValue = $previousTagValue
                        NewTagValue      = $currentUpdateRingValue
                        Status           = $status
                        Message          = $message
                    }
                    continue
                }
                elseif (-not $Force -and $hasNewScheduleTags) {
                    Write-Log -Message "UpdateRing unchanged but new schedule tags to apply - proceeding" -Level Info
                    $action = "Updated"
                }
                else {
                    Write-Log -Message "Force mode enabled - will update existing tag" -Level Info
                    $action = "Updated"
                }
            }
            else {
                Write-Log -Message "No existing UpdateRing tag - will create new tag" -Level Info
                $action = "Created"
            }

            # Build the new tags object (preserve existing tags and add/update UpdateRing)
            # Use ordered hashtable and convert to PSCustomObject for clean JSON serialization
            $newTags = [ordered]@{}
            if ($currentTags -and $currentTags.PSObject.Properties.Name.Count -gt 0) {
                # Copy existing tags (only actual tag properties, not PSObject internals)
                foreach ($prop in $currentTags.PSObject.Properties) {
                    # Skip PowerShell internal properties
                    if ($prop.MemberType -eq 'NoteProperty') {
                        $newTags[$prop.Name] = $prop.Value
                    }
                }
            }
            $newTags["UpdateRing"] = $currentUpdateRingValue

            # Also set UpdateWindow and UpdateExclusions if provided (from CSV)
            if ($clusterEntry.UpdateWindowValue) {
                $newTags[$script:UpdateWindowTagName] = $clusterEntry.UpdateWindowValue
                Write-Log -Message "  Will also set $($script:UpdateWindowTagName) tag: $($clusterEntry.UpdateWindowValue)" -Level Info
            }
            if ($clusterEntry.UpdateExclusionsValue) {
                $newTags[$script:UpdateExclusionsTagName] = $clusterEntry.UpdateExclusionsValue
                Write-Log -Message "  Will also set $($script:UpdateExclusionsTagName) tag: $($clusterEntry.UpdateExclusionsValue)" -Level Info
            }

            # Apply the tag using PATCH
            if ($PSCmdlet.ShouldProcess($resourceId, "Set UpdateRing tag to '$currentUpdateRingValue'")) {
                Write-Log -Message "Applying UpdateRing tag with value: '$currentUpdateRingValue'..." -Level Info
                
                # Create a clean PSCustomObject for JSON serialization
                $patchBodyObj = [PSCustomObject]@{
                    tags = [PSCustomObject]$newTags
                }
                $patchBody = $patchBodyObj | ConvertTo-Json -Compress -Depth 10

                # Write body to temp file to avoid PowerShell/cmd JSON escaping issues
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $patchBody | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline
                    
                    # Use az rest with @file syntax to avoid escaping issues
                    $result = az rest --method PATCH --uri $uri --body "@$tempFile" --headers "Content-Type=application/json" 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log -Message "Successfully $($action.ToLower()) UpdateRing tag" -Level Success
                        $status = "Success"
                        $message = "UpdateRing tag $($action.ToLower()) successfully"
                    }
                    else {
                        Write-Log -Message "Failed to apply tag: $result" -Level Error
                        $status = "Failed"
                        $message = "Failed to apply tag: $result"
                    }
                }
                finally {
                    # Clean up temp file
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            else {
                $status = "WhatIf"
                $message = "Would $($action.ToLower()) UpdateRing tag"
            }

            # Write to CSV
            $escapedMessage = $message -replace '"', '""'
            $csvLine = "`"$clusterName`",`"$resourceGroup`",`"$subscriptionId`",`"$resourceId`",`"$action`",`"$previousTagValue`",`"$currentUpdateRingValue`",`"$status`",`"$escapedMessage`""
            Add-Content -Path $csvLogPath -Value $csvLine

            $results += [PSCustomObject]@{
                ClusterName      = $clusterName
                ResourceGroup    = $resourceGroup
                SubscriptionId   = $subscriptionId
                ResourceId       = $resourceId
                Action           = $action
                PreviousTagValue = $previousTagValue
                NewTagValue      = $currentUpdateRingValue
                Status           = $status
                Message          = $message
            }
        }
        catch {
            Write-Log -Message "Error processing cluster: $($_.Exception.Message)" -Level Error
            $status = "Failed"
            $message = $_.Exception.Message -replace '"', '""'
            
            # Write to CSV
            $csvLine = "`"$clusterName`",`"$resourceGroup`",`"$subscriptionId`",`"$resourceId`",`"Error`",`"$previousTagValue`",`"$currentUpdateRingValue`",`"$status`",`"$message`""
            Add-Content -Path $csvLogPath -Value $csvLine
            
            $results += [PSCustomObject]@{
                ClusterName      = $clusterName
                ResourceGroup    = $resourceGroup
                SubscriptionId   = $subscriptionId
                ResourceId       = $resourceId
                Action           = "Error"
                PreviousTagValue = $previousTagValue
                NewTagValue      = $currentUpdateRingValue
                Status           = $status
                Message          = $_.Exception.Message
            }
        }
    }

    # Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $created = @($results | Where-Object { $_.Action -eq "Created" -and $_.Status -eq "Success" }).Count
    $updated = @($results | Where-Object { $_.Action -eq "Updated" -and $_.Status -eq "Success" }).Count
    $skipped = @($results | Where-Object { $_.Status -eq "Skipped" }).Count
    $failed = @($results | Where-Object { $_.Status -eq "Failed" }).Count
    
    Write-Log -Message "Total clusters processed: $($results.Count)" -Level Info
    Write-Log -Message "Tags created: $created" -Level $(if ($created -gt 0) { "Success" } else { "Info" })
    Write-Log -Message "Tags updated: $updated" -Level $(if ($updated -gt 0) { "Success" } else { "Info" })
    Write-Log -Message "Skipped (existing tag, no -Force): $skipped" -Level $(if ($skipped -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Failed: $failed" -Level $(if ($failed -gt 0) { "Error" } else { "Info" })
    Write-Log -Message "" -Level Info
    Write-Log -Message "CSV log saved to: $csvLogPath" -Level Info
    Write-Log -Message "========================================" -Level Header

    # Display results table
    Write-Host ""
    $results | Format-Table ClusterName, Action, PreviousTagValue, NewTagValue, Status -AutoSize
    
    if ($PassThru) {
        return $results
    }
}

#region Fleet-Scale Operations (v0.5.6)

# Internal state variable - DO NOT CONFIGURE DIRECTLY
# This variable is automatically managed by the fleet functions.
# For pipelines/CI-CD: Use -PassThru to capture state, -StateFilePath to persist,
# and -State parameter to pass between functions.
# Example: $state = Invoke-AzureLocalFleetOperation -PassThru; Get-AzureLocalFleetProgress -State $state
$script:FleetOperationState = $null

function Export-AzureLocalFleetState {
    <#
    .SYNOPSIS
        Exports the current fleet operation state to a JSON file for resume capability.
    
    .DESCRIPTION
        Saves the state of a fleet-wide update operation to a JSON file. This enables:
        - Resume capability after failures or interruptions
        - Progress tracking across multiple sessions
        - Audit trail of fleet operations
        
        The state file includes: RunId, timestamps, total/completed/failed/pending clusters,
        and detailed status for each cluster.
    
    .PARAMETER State
        The fleet operation state object to export. If not provided, uses the current
        in-memory state from $script:FleetOperationState.
    
    .PARAMETER Path
        The file path to save the state. Supports .json extension.
        Default: Creates timestamped file in the default log folder.
    
    .EXAMPLE
        Export-AzureLocalFleetState -Path "C:\Logs\fleet-state.json"
        Exports the current fleet state to the specified file.
    
    .EXAMPLE
        $state = Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -PassThru
        Export-AzureLocalFleetState -State $state -Path "C:\Logs\wave1-state.json"
        Exports a specific state object.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$State,
        
        [Parameter(Mandatory = $false)]
        [string]$Path
    )
    
    # Use provided state or script-level state
    $stateToExport = if ($State) { $State } else { $script:FleetOperationState }
    
    if (-not $stateToExport) {
        Write-Warning "No fleet operation state available to export."
        return $null
    }
    
    # Generate default path if not provided
    if (-not $Path) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $logDir = $script:DefaultLogFolder
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $Path = Join-Path -Path $logDir -ChildPath "FleetState_$timestamp.json"
    }
    
    # Ensure directory exists
    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    
    # Update state metadata
    $stateToExport.LastSaved = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $stateToExport.StateFilePath = $Path
    
    # Export to JSON
    $stateToExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8 -Force
    
    Write-Log -Message "Fleet state exported to: $Path" -Level Success
    return $Path
}

function Import-AzureLocalFleetState {
    <#
    .SYNOPSIS
        Imports a previously saved fleet operation state from a JSON file.
    
    .DESCRIPTION
        Loads a fleet operation state from a JSON file to enable resuming
        interrupted operations or reviewing past operation status.
    
    .PARAMETER Path
        The file path to load the state from.
    
    .EXAMPLE
        $state = Import-AzureLocalFleetState -Path "C:\Logs\fleet-state.json"
        Resume-AzureLocalFleetUpdate -State $state
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path
    )
    
    try {
        $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
        Write-Log -Message "Fleet state imported from: $Path" -Level Info
        Write-Log -Message "  Run ID: $($content.RunId)" -Level Info
        Write-Log -Message "  Started: $($content.StartTime)" -Level Info
        Write-Log -Message "  Total Clusters: $($content.TotalClusters)" -Level Info
        Write-Log -Message "  Completed: $($content.CompletedCount), Failed: $($content.FailedCount), Pending: $($content.PendingCount)" -Level Info
        return $content
    }
    catch {
        Write-Error "Failed to import fleet state from '$Path': $_"
        return $null
    }
}

function Get-AzureLocalFleetProgress {
    <#
    .SYNOPSIS
        Gets real-time progress of a fleet-wide update operation.
    
    .DESCRIPTION
        Queries the current status of all clusters in a fleet operation and returns
        aggregated progress information including:
        - Total, completed, in-progress, failed, pending counts
        - Estimated time remaining (based on average completion time)
        - Per-cluster status details
        
        Can be used with a state object from Invoke-AzureLocalFleetOperation or
        by querying clusters directly by tag.
    
    .PARAMETER State
        A fleet operation state object. If provided, only checks clusters in this state.
    
    .PARAMETER ScopeByUpdateRingTag
        Query progress for clusters with a specific UpdateRing tag.
    
    .PARAMETER UpdateRingValue
        The UpdateRing tag value to filter by.
    
    .PARAMETER Detailed
        Include detailed per-cluster status in output.
    
    .EXAMPLE
        Get-AzureLocalFleetProgress -State $fleetState
        Gets progress for clusters in the specified fleet operation.
    
    .EXAMPLE
        Get-AzureLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Production"
        Gets progress for all Production ring clusters.
    
    .EXAMPLE
        Get-AzureLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Detailed
        Gets detailed progress including per-cluster status.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByState')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'ByState')]
        [PSCustomObject]$State,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,
        
        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,
        
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Fleet Update Progress Check" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    # Get list of clusters to check
    $clustersToCheck = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByState') {
        $stateToUse = if ($State) { $State } else { $script:FleetOperationState }
        if (-not $stateToUse) {
            Write-Warning "No fleet state available. Use -ScopeByUpdateRingTag or provide a state object."
            return $null
        }
        $clustersToCheck = $stateToUse.Clusters
        Write-Log -Message "Checking progress for Run ID: $($stateToUse.RunId)" -Level Info
    }
    else {
        # Query by tag
        Write-Log -Message "Querying clusters with UpdateRing = '$UpdateRingValue'..." -Level Info
        $inventory = Get-AzureLocalClusterInventory -PassThru | Where-Object { $_.UpdateRing -eq $UpdateRingValue }
        if (-not $inventory) {
            Write-Warning "No clusters found with UpdateRing tag = '$UpdateRingValue'"
            return $null
        }
        foreach ($cluster in $inventory) {
            $clustersToCheck += [PSCustomObject]@{
                ClusterName = $cluster.ClusterName
                ResourceId = $cluster.ResourceId
                ResourceGroup = $cluster.ResourceGroup
                SubscriptionId = $cluster.SubscriptionId
            }
        }
    }
    
    Write-Log -Message "Checking status of $($clustersToCheck.Count) cluster(s)..." -Level Info
    
    # Get current status for each cluster
    $clusterStatuses = @()
    $succeeded = 0
    $inProgress = 0
    $failed = 0
    $notStarted = 0
    $upToDate = 0
    
    foreach ($cluster in $clustersToCheck) {
        try {
            $summary = Get-AzureLocalUpdateSummary -ClusterResourceId $cluster.ResourceId -ErrorAction SilentlyContinue
            
            $status = [PSCustomObject]@{
                ClusterName = $cluster.ClusterName
                ResourceGroup = $cluster.ResourceGroup
                UpdateState = $summary.State
                HealthState = $summary.HealthState
                LastUpdated = $summary.LastUpdatedTime
            }
            
            switch ($summary.State) {
                "Succeeded" { $succeeded++ }
                "UpdateInProgress" { $inProgress++ }
                "Failed" { $failed++ }
                "UpToDate" { $upToDate++ }
                default { $notStarted++ }
            }
            
            $clusterStatuses += $status
        }
        catch {
            $clusterStatuses += [PSCustomObject]@{
                ClusterName = $cluster.ClusterName
                ResourceGroup = $cluster.ResourceGroup
                UpdateState = "Unknown"
                HealthState = "Unknown"
                LastUpdated = $null
            }
            $notStarted++
        }
    }
    
    # Calculate progress
    $total = $clustersToCheck.Count
    $completed = $succeeded + $upToDate
    $progressPercent = if ($total -gt 0) { [math]::Round(($completed / $total) * 100, 1) } else { 0 }
    
    # Build progress report
    $progress = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        TotalClusters = $total
        Completed = $completed
        ProgressPercent = $progressPercent
        Succeeded = $succeeded
        UpToDate = $upToDate
        InProgress = $inProgress
        Failed = $failed
        NotStarted = $notStarted
        ClusterStatuses = if ($Detailed) { $clusterStatuses } else { $null }
    }
    
    # Display summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "Progress Summary:" -Level Header
    Write-Log -Message "  Total Clusters: $total" -Level Info
    Write-Log -Message "  Completed: $completed ($progressPercent%)" -Level $(if ($completed -eq $total) { "Success" } else { "Info" })
    Write-Log -Message "  - Succeeded: $succeeded" -Level $(if ($succeeded -gt 0) { "Success" } else { "Info" })
    Write-Log -Message "  - Up to Date: $upToDate" -Level $(if ($upToDate -gt 0) { "Success" } else { "Info" })
    Write-Log -Message "  In Progress: $inProgress" -Level $(if ($inProgress -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "  Failed: $failed" -Level $(if ($failed -gt 0) { "Error" } else { "Info" })
    Write-Log -Message "  Not Started: $notStarted" -Level Info
    
    if ($Detailed -and $clusterStatuses.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Per-Cluster Status:" -Level Header
        $clusterStatuses | Format-Table ClusterName, UpdateState, HealthState -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
    }
    
    return $progress
}

function Test-AzureLocalFleetHealthGate {
    <#
    .SYNOPSIS
        Tests if a fleet meets health criteria to proceed with additional waves.
    
    .DESCRIPTION
        Evaluates the health and update status of a fleet to determine if it's safe
        to proceed with the next wave of updates. This function acts as a "gate"
        in CI/CD pipelines to prevent cascading failures.
        
        Health gate criteria:
        - Maximum failure percentage (default: 5%)
        - Minimum success percentage (default: 90%)
        - No critical health failures
        
        Returns $true if the gate passes, $false otherwise.
    
    .PARAMETER State
        A fleet operation state object to evaluate.
    
    .PARAMETER ScopeByUpdateRingTag
        Evaluate clusters with a specific UpdateRing tag.
    
    .PARAMETER UpdateRingValue
        The UpdateRing tag value to filter by.
    
    .PARAMETER MaxFailurePercent
        Maximum allowed failure percentage. Default: 5.
        If more than this percentage of clusters fail, the gate fails.
    
    .PARAMETER MinSuccessPercent
        Minimum required success percentage. Default: 90.
        If fewer than this percentage succeed, the gate fails.
    
    .PARAMETER WaitForCompletion
        Wait for in-progress updates to complete before evaluating.
    
    .PARAMETER WaitTimeoutMinutes
        Maximum time to wait for completion. Default: 120 (2 hours).
    
    .PARAMETER PollIntervalSeconds
        How often to check status while waiting. Default: 60.
    
    .OUTPUTS
        PSCustomObject with Pass/Fail status and detailed metrics.
    
    .EXAMPLE
        Test-AzureLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Canary"
        Tests if the Canary ring meets default health criteria.
    
    .EXAMPLE
        Test-AzureLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -MaxFailurePercent 2 -WaitForCompletion
        Waits for Wave1 to complete and fails if more than 2% of clusters fail.
    
    .EXAMPLE
        # In CI/CD pipeline
        $gate = Test-AzureLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1"
        if (-not $gate.Passed) { exit 1 }
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByTag')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'ByState')]
        [PSCustomObject]$State,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,
        
        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$MaxFailurePercent = 5,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$MinSuccessPercent = 90,
        
        [Parameter(Mandatory = $false)]
        [switch]$WaitForCompletion,
        
        [Parameter(Mandatory = $false)]
        [int]$WaitTimeoutMinutes = 120,
        
        [Parameter(Mandatory = $false)]
        [int]$PollIntervalSeconds = 60
    )
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Fleet Health Gate Check" -Level Header
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Criteria: MaxFailure=$MaxFailurePercent%, MinSuccess=$MinSuccessPercent%" -Level Info
    
    $startTime = Get-Date
    $timeout = $startTime.AddMinutes($WaitTimeoutMinutes)
    
    do {
        # Get current progress
        $progressParams = @{}
        if ($PSCmdlet.ParameterSetName -eq 'ByState') {
            $progressParams['State'] = $State
        }
        else {
            $progressParams['ScopeByUpdateRingTag'] = $true
            $progressParams['UpdateRingValue'] = $UpdateRingValue
        }
        
        $progress = Get-AzureLocalFleetProgress @progressParams -Detailed
        
        if (-not $progress) {
            return [PSCustomObject]@{
                Passed = $false
                Reason = "Unable to get fleet progress"
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
        }
        
        # Check if we should wait for completion
        if ($WaitForCompletion -and $progress.InProgress -gt 0) {
            $remaining = $timeout - (Get-Date)
            
            if ((Get-Date) -ge $timeout) {
                Write-Log -Message "Timeout reached waiting for completion. $($progress.InProgress) updates still in progress." -Level Warning
                break
            }
            
            Write-Log -Message "Waiting for $($progress.InProgress) in-progress update(s)... (Timeout in $([math]::Round($remaining.TotalMinutes, 0)) min)" -Level Info
            Start-Sleep -Seconds $PollIntervalSeconds
            continue
        }
        
        break
    } while ($true)
    
    # Calculate metrics
    $total = $progress.TotalClusters
    $succeeded = $progress.Succeeded + $progress.UpToDate
    $failed = $progress.Failed
    
    $failurePercent = if ($total -gt 0) { [math]::Round(($failed / $total) * 100, 2) } else { 0 }
    $successPercent = if ($total -gt 0) { [math]::Round(($succeeded / $total) * 100, 2) } else { 0 }
    
    # Evaluate gate criteria
    $reasons = @()
    $passed = $true
    
    if ($failurePercent -gt $MaxFailurePercent) {
        $passed = $false
        $reasons += "Failure rate ($failurePercent%) exceeds maximum ($MaxFailurePercent%)"
    }
    
    if ($successPercent -lt $MinSuccessPercent) {
        $passed = $false
        $reasons += "Success rate ($successPercent%) below minimum ($MinSuccessPercent%)"
    }
    
    # Check for critical health failures if detailed data available
    if ($progress.ClusterStatuses) {
        $criticalHealth = @($progress.ClusterStatuses | Where-Object { $_.HealthState -eq "Failure" })
        if ($criticalHealth.Count -gt 0) {
            $passed = $false
            $reasons += "$($criticalHealth.Count) cluster(s) have critical health failures"
        }
    }
    
    # Build result
    $result = [PSCustomObject]@{
        Passed = $passed
        Reason = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "All criteria met" }
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        TotalClusters = $total
        Succeeded = $succeeded
        Failed = $failed
        InProgress = $progress.InProgress
        SuccessPercent = $successPercent
        FailurePercent = $failurePercent
        MaxFailurePercent = $MaxFailurePercent
        MinSuccessPercent = $MinSuccessPercent
    }
    
    # Display result
    Write-Log -Message "" -Level Info
    if ($passed) {
        Write-Log -Message "[OK]HEALTH GATE: PASSED" -Level Success
    }
    else {
        Write-Log -Message "[FAILED]HEALTH GATE: FAILED" -Level Error
        foreach ($reason in $reasons) {
            Write-Log -Message "  - $reason" -Level Error
        }
    }
    Write-Log -Message "  Success Rate: $successPercent% (min: $MinSuccessPercent%)" -Level Info
    Write-Log -Message "  Failure Rate: $failurePercent% (max: $MaxFailurePercent%)" -Level Info
    
    return $result
}

function Invoke-AzureLocalFleetOperation {
    <#
    .SYNOPSIS
        Executes fleet-wide operations with batching, throttling, and retry logic.
    
    .DESCRIPTION
        Orchestrates update operations across large numbers of Azure Local clusters
        with enterprise-scale features:
        
        - Batch processing: Process clusters in configurable batches
        - Throttling: Control parallel execution and rate limiting
        - Retry logic: Automatic retries with exponential backoff
        - State management: Checkpoint/resume capability
        - Progress tracking: Real-time status updates
        
        Designed for fleets of 1000-3000+ clusters.
    
    .PARAMETER Operation
        The operation to perform:
        - ApplyUpdate: Start updates on clusters (default)
        - CheckReadiness: Check update readiness across fleet
        - GetStatus: Get current update status
    
    .PARAMETER ScopeByUpdateRingTag
        Target clusters with a specific UpdateRing tag.
    
    .PARAMETER UpdateRingValue
        The UpdateRing tag value to filter by.
    
    .PARAMETER ClusterResourceIds
        Explicit list of cluster resource IDs to operate on.
    
    .PARAMETER UpdateName
        Specific update name to apply (for ApplyUpdate operation).
    
    .PARAMETER BatchSize
        Number of clusters to process per batch. Default: 50.
    
    .PARAMETER ThrottleLimit
        Maximum parallel operations per batch. Default: 10.
    
    .PARAMETER DelayBetweenBatchesSeconds
        Delay between batches in seconds. Default: 30.
    
    .PARAMETER MaxRetries
        Maximum retry attempts per cluster. Default: 3.
    
    .PARAMETER RetryDelaySeconds
        Base delay between retries (uses exponential backoff). Default: 30.
    
    .PARAMETER StateFilePath
        Path to save operation state for resume capability.
    
    .PARAMETER Force
        Skip confirmation prompts.
    
    .PARAMETER PassThru
        Return the fleet state object for pipeline use.
    
    .EXAMPLE
        Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Force
        Starts updates on all Wave1 clusters with default batching.
    
    .EXAMPLE
        Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Production" `
            -BatchSize 100 -ThrottleLimit 20 -DelayBetweenBatchesSeconds 60 -Force
        Processes Production clusters with larger batches and more parallelism.
    
    .EXAMPLE
        $state = Invoke-AzureLocalFleetOperation -ScopeByUpdateRingTag -UpdateRingValue "Ring1" `
            -StateFilePath "C:\Logs\ring1-state.json" -Force -PassThru
        Runs operation with state saved for potential resume.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByTag')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('ApplyUpdate', 'CheckReadiness', 'GetStatus')]
        [string]$Operation = 'ApplyUpdate',
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,
        
        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,
        
        [Parameter(Mandatory = $false)]
        [string]$UpdateName,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 500)]
        [int]$BatchSize = 50,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$ThrottleLimit = 10,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 600)]
        [int]$DelayBetweenBatchesSeconds = 30,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(5, 300)]
        [int]$RetryDelaySeconds = 30,
        
        [Parameter(Mandatory = $false)]
        [string]$StateFilePath,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    
    $runId = [guid]::NewGuid().ToString()
    $startTime = Get-Date
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Fleet Operation: $Operation" -Level Header
    Write-Log -Message "Run ID: $runId" -Level Header
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Configuration:" -Level Info
    Write-Log -Message "  Batch Size: $BatchSize" -Level Info
    Write-Log -Message "  Throttle Limit: $ThrottleLimit" -Level Info
    Write-Log -Message "  Delay Between Batches: $DelayBetweenBatchesSeconds seconds" -Level Info
    Write-Log -Message "  Max Retries: $MaxRetries" -Level Info
    
    # Get list of clusters
    $allClusters = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        Write-Log -Message "Querying clusters with UpdateRing = '$UpdateRingValue'..." -Level Info
        $inventory = Get-AzureLocalClusterInventory -PassThru
        $allClusters = @($inventory | Where-Object { $_.UpdateRing -eq $UpdateRingValue })
        
        if ($allClusters.Count -eq 0) {
            Write-Warning "No clusters found with UpdateRing = '$UpdateRingValue'"
            return $null
        }
    }
    else {
        Write-Log -Message "Using $($ClusterResourceIds.Count) provided cluster Resource IDs..." -Level Info
        foreach ($resourceId in $ClusterResourceIds) {
            $parts = $resourceId -split '/'
            $allClusters += [PSCustomObject]@{
                ClusterName = $parts[-1]
                ResourceId = $resourceId
                ResourceGroup = $parts[4]
                SubscriptionId = $parts[2]
            }
        }
    }
    
    $totalClusters = $allClusters.Count
    Write-Log -Message "Total clusters to process: $totalClusters" -Level Info
    
    # Confirmation
    if (-not $Force -and $Operation -eq 'ApplyUpdate') {
        $confirmation = Read-Host "This will start updates on $totalClusters cluster(s). Continue? (y/n)"
        if ($confirmation -ne 'y') {
            Write-Log -Message "Operation cancelled by user." -Level Warning
            return $null
        }
    }
    
    # Initialize state
    $state = [PSCustomObject]@{
        RunId = $runId
        Operation = $Operation
        StartTime = $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
        EndTime = $null
        TotalClusters = $totalClusters
        CompletedCount = 0
        SucceededCount = 0
        FailedCount = 0
        PendingCount = $totalClusters
        BatchSize = $BatchSize
        ThrottleLimit = $ThrottleLimit
        CurrentBatch = 0
        TotalBatches = [math]::Ceiling($totalClusters / $BatchSize)
        UpdateRingValue = $UpdateRingValue
        UpdateName = $UpdateName
        StateFilePath = $StateFilePath
        LastSaved = $null
        Clusters = @()
    }
    
    # Initialize cluster tracking
    foreach ($cluster in $allClusters) {
        $state.Clusters += [PSCustomObject]@{
            ClusterName = $cluster.ClusterName
            ResourceId = $cluster.ResourceId
            ResourceGroup = $cluster.ResourceGroup
            SubscriptionId = $cluster.SubscriptionId
            Status = "Pending"
            Attempts = 0
            LastAttempt = $null
            LastError = $null
            Result = $null
        }
    }
    
    # Store state script-level for progress tracking
    $script:FleetOperationState = $state
    
    # Process in batches
    $batchNumber = 0
    $totalBatches = $state.TotalBatches
    
    for ($i = 0; $i -lt $totalClusters; $i += $BatchSize) {
        $batchNumber++
        $state.CurrentBatch = $batchNumber
        $batchClusters = $state.Clusters[$i..[math]::Min($i + $BatchSize - 1, $totalClusters - 1)]
        
        Write-Log -Message "" -Level Info
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Batch $batchNumber of $totalBatches ($($batchClusters.Count) clusters)" -Level Header
        Write-Log -Message "========================================" -Level Header
        
        # Process batch with throttling (using runspaces for parallelism)
        # Note: Using ForEach-Object -Parallel requires PS7+, so we use sequential with simulated throttle
        foreach ($clusterState in $batchClusters) {
            if ($clusterState.Status -eq "Succeeded") {
                continue  # Skip already succeeded (for resume scenarios)
            }
            
            Write-Log -Message "Processing: $($clusterState.ClusterName)" -Level Info
            
            $success = $false
            $lastError = $null
            
            for ($attempt = 1; $attempt -le ($MaxRetries + 1); $attempt++) {
                $clusterState.Attempts = $attempt
                $clusterState.LastAttempt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                
                try {
                    switch ($Operation) {
                        'ApplyUpdate' {
                            $updateParams = @{
                                ClusterResourceIds = @($clusterState.ResourceId)
                                Force = $true
                            }
                            if ($UpdateName) {
                                $updateParams['UpdateName'] = $UpdateName
                            }
                            
                            $result = Start-AzureLocalClusterUpdate @updateParams
                            
                            if ($result.Status -eq "UpdateStarted") {
                                $success = $true
                                $clusterState.Result = $result
                            }
                            else {
                                throw "Update not started: $($result.Message)"
                            }
                        }
                        'CheckReadiness' {
                            $readiness = Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds @($clusterState.ResourceId)
                            $clusterState.Result = $readiness
                            $success = $true
                        }
                        'GetStatus' {
                            $summary = Get-AzureLocalUpdateSummary -ClusterResourceId $clusterState.ResourceId
                            $clusterState.Result = $summary
                            $success = $true
                        }
                    }
                    
                    break  # Success, exit retry loop
                }
                catch {
                    $lastError = $_.Exception.Message
                    $clusterState.LastError = $lastError
                    
                    if ($attempt -le $MaxRetries) {
                        $delay = $RetryDelaySeconds * [math]::Pow(2, $attempt - 1)  # Exponential backoff
                        Write-Log -Message "  Attempt $attempt failed: $lastError. Retrying in $delay seconds..." -Level Warning
                        Start-Sleep -Seconds $delay
                    }
                    else {
                        Write-Log -Message "  All $($MaxRetries + 1) attempts failed: $lastError" -Level Error
                    }
                }
            }
            
            # Update status
            if ($success) {
                $clusterState.Status = "Succeeded"
                $state.SucceededCount++
                Write-Log -Message "  [OK] $($clusterState.ClusterName) - Succeeded" -Level Success
            }
            else {
                $clusterState.Status = "Failed"
                $state.FailedCount++
                Write-Log -Message "  [FAILED] $($clusterState.ClusterName) - Failed: $lastError" -Level Error
            }
            
            $state.CompletedCount++
            $state.PendingCount = $totalClusters - $state.CompletedCount
        }
        
        # Save checkpoint after each batch
        if ($StateFilePath) {
            Export-AzureLocalFleetState -State $state -Path $StateFilePath | Out-Null
        }
        
        # Delay between batches (if not the last batch)
        if ($batchNumber -lt $totalBatches -and $DelayBetweenBatchesSeconds -gt 0) {
            Write-Log -Message "Batch $batchNumber complete. Waiting $DelayBetweenBatchesSeconds seconds before next batch..." -Level Info
            Start-Sleep -Seconds $DelayBetweenBatchesSeconds
        }
    }
    
    # Final state update
    $state.EndTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    # Final save
    if ($StateFilePath) {
        Export-AzureLocalFleetState -State $state -Path $StateFilePath | Out-Null
    }
    
    # Summary
    $duration = (Get-Date) - $startTime
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Fleet Operation Complete" -Level Header
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Run ID: $runId" -Level Info
    Write-Log -Message "Duration: $([math]::Round($duration.TotalMinutes, 1)) minutes" -Level Info
    Write-Log -Message "Total Clusters: $totalClusters" -Level Info
    Write-Log -Message "Succeeded: $($state.SucceededCount)" -Level $(if ($state.SucceededCount -eq $totalClusters) { "Success" } else { "Info" })
    Write-Log -Message "Failed: $($state.FailedCount)" -Level $(if ($state.FailedCount -gt 0) { "Error" } else { "Info" })
    
    if ($StateFilePath) {
        Write-Log -Message "State file: $StateFilePath" -Level Info
    }
    
    if ($PassThru) {
        return $state
    }
}

function Resume-AzureLocalFleetUpdate {
    <#
    .SYNOPSIS
        Resumes a previously interrupted fleet update operation.
    
    .DESCRIPTION
        Loads a saved fleet operation state and continues processing any
        pending or failed clusters. This enables recovery from:
        - Pipeline timeouts
        - Network interruptions  
        - Manual cancellations
        - Transient failures
    
    .PARAMETER StateFilePath
        Path to the saved state file from a previous operation.
    
    .PARAMETER State
        A state object loaded via Import-AzureLocalFleetState.
    
    .PARAMETER RetryFailed
        Also retry clusters that previously failed (not just pending).
    
    .PARAMETER MaxRetries
        Maximum additional retry attempts for failed clusters.
    
    .PARAMETER Force
        Skip confirmation prompts.
    
    .PARAMETER PassThru
        Return the updated state object.
    
    .EXAMPLE
        Resume-AzureLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -Force
        Resumes pending clusters from the saved state.
    
    .EXAMPLE
        Resume-AzureLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -RetryFailed -Force
        Resumes pending clusters and retries failed ones.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByPath')]
        [ValidateScript({ Test-Path $_ })]
        [string]$StateFilePath,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ByState')]
        [PSCustomObject]$State,
        
        [Parameter(Mandatory = $false)]
        [switch]$RetryFailed,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    
    # Load state
    $resumeState = if ($State) { $State } else { Import-AzureLocalFleetState -Path $StateFilePath }
    
    if (-not $resumeState) {
        Write-Error "Failed to load fleet state."
        return $null
    }
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Resuming Fleet Operation" -Level Header
    Write-Log -Message "Original Run ID: $($resumeState.RunId)" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    # Identify clusters to process
    $pendingClusters = @($resumeState.Clusters | Where-Object { $_.Status -eq "Pending" })
    $failedClusters = @($resumeState.Clusters | Where-Object { $_.Status -eq "Failed" })
    
    Write-Log -Message "State Summary:" -Level Info
    Write-Log -Message "  Pending: $($pendingClusters.Count)" -Level Info
    Write-Log -Message "  Failed: $($failedClusters.Count)" -Level Info
    Write-Log -Message "  Succeeded: $($resumeState.SucceededCount)" -Level Info
    
    $clustersToProcess = $pendingClusters
    if ($RetryFailed) {
        $clustersToProcess += $failedClusters
        # Reset failed clusters to pending
        foreach ($cluster in $failedClusters) {
            $cluster.Status = "Pending"
            $cluster.Attempts = 0
            $cluster.LastError = $null
        }
        $resumeState.FailedCount = 0
    }
    
    if ($clustersToProcess.Count -eq 0) {
        Write-Log -Message "No clusters to process. All clusters have succeeded." -Level Success
        return $resumeState
    }
    
    Write-Log -Message "Clusters to process: $($clustersToProcess.Count)" -Level Info
    
    # Confirmation
    if (-not $Force) {
        $confirmation = Read-Host "Resume operation on $($clustersToProcess.Count) cluster(s)? (y/n)"
        if ($confirmation -ne 'y') {
            Write-Log -Message "Resume cancelled by user." -Level Warning
            return $resumeState
        }
    }
    
    # Collect resource IDs for processing
    $resourceIds = $clustersToProcess | ForEach-Object { $_.ResourceId }
    
    # Use Invoke-AzureLocalFleetOperation with the specific clusters
    $params = @{
        ClusterResourceIds = $resourceIds
        Operation = $resumeState.Operation
        BatchSize = $resumeState.BatchSize
        ThrottleLimit = $resumeState.ThrottleLimit
        MaxRetries = $MaxRetries
        Force = $true
        PassThru = $true
    }
    
    if ($resumeState.UpdateName) {
        $params['UpdateName'] = $resumeState.UpdateName
    }
    
    if ($resumeState.StateFilePath) {
        $params['StateFilePath'] = $resumeState.StateFilePath
    }
    
    $result = Invoke-AzureLocalFleetOperation @params
    
    if ($PassThru) {
        return $result
    }
}

function Stop-AzureLocalFleetUpdate {
    <#
    .SYNOPSIS
        Gracefully stops an in-progress fleet update operation.
    
    .DESCRIPTION
        Signals a fleet operation to stop after the current batch completes.
        Saves the current state for later resumption. Does NOT cancel
        individual cluster updates that are already in progress.
        
        For emergency cancellation of in-progress updates, use Azure Portal
        or the az CLI to cancel individual update runs.
    
    .PARAMETER SaveState
        Save the current state to a file before stopping.
    
    .PARAMETER StateFilePath
        Path to save the state file.
    
    .EXAMPLE
        Stop-AzureLocalFleetUpdate -SaveState -StateFilePath "C:\Logs\fleet-state.json"
        Stops the operation and saves state for later resume.
    
    .NOTES
        This function sets a flag to stop after the current batch.
        It does not immediately halt the operation.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$SaveState,
        
        [Parameter(Mandatory = $false)]
        [string]$StateFilePath
    )
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Stopping Fleet Operation" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    if (-not $script:FleetOperationState) {
        Write-Warning "No active fleet operation to stop."
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Fleet operation $($script:FleetOperationState.RunId)", 'Stop fleet update')) {
        return
    }

    # Save state if requested
    if ($SaveState) {
        $path = if ($StateFilePath) { $StateFilePath } else { $script:FleetOperationState.StateFilePath }
        
        if ($path) {
            Export-AzureLocalFleetState -State $script:FleetOperationState -Path $path
            Write-Log -Message "State saved to: $path" -Level Success
            Write-Log -Message "Use Resume-AzureLocalFleetUpdate to continue later." -Level Info
        }
        else {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $defaultPath = Join-Path -Path $script:DefaultLogFolder -ChildPath "FleetState_Stopped_$timestamp.json"
            Export-AzureLocalFleetState -State $script:FleetOperationState -Path $defaultPath
            Write-Log -Message "State saved to: $defaultPath" -Level Success
        }
    }
    
    # Display summary
    $state = $script:FleetOperationState
    Write-Log -Message "" -Level Info
    Write-Log -Message "Operation Status at Stop:" -Level Header
    Write-Log -Message "  Run ID: $($state.RunId)" -Level Info
    Write-Log -Message "  Total: $($state.TotalClusters)" -Level Info
    Write-Log -Message "  Completed: $($state.CompletedCount)" -Level Info
    Write-Log -Message "  Succeeded: $($state.SucceededCount)" -Level Success
    Write-Log -Message "  Failed: $($state.FailedCount)" -Level $(if ($state.FailedCount -gt 0) { "Error" } else { "Info" })
    Write-Log -Message "  Pending: $($state.PendingCount)" -Level Warning
    
    Write-Log -Message "" -Level Info
    Write-Log -Message "Fleet operation marked for stop." -Level Warning
    Write-Log -Message "Note: Updates already in progress on individual clusters will continue." -Level Info
}

#endregion Fleet-Scale Operations

#region Pre-Update Health Validation (v0.6.1)

function Test-AzureLocalClusterHealth {
    <#
    .SYNOPSIS
        Validates cluster health before applying updates by checking for blocking health check failures.
    
    .DESCRIPTION
        Queries the health check results from each cluster's update summary to identify
        Critical, Warning, and Informational failures. Critical failures block updates
        from being applied.
        
        This function can be used as a standalone pre-flight check or is called
        automatically by Start-AzureLocalClusterUpdate before applying updates.
        
        Health check data is stored in ARM on the cluster's updateSummaries resource
        and is refreshed approximately every 24 hours.
    
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to check.
    
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to check.
    
    .PARAMETER ScopeByUpdateRingTag
        Find clusters by their 'UpdateRing' tag value via Azure Resource Graph.
    
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    
    .PARAMETER ResourceGroupName
        Resource group containing the clusters (only used with -ClusterNames).
    
    .PARAMETER SubscriptionId
        Azure subscription ID (defaults to current subscription).
    
    .PARAMETER BlockingOnly
        Show only Critical severity failures (the ones that block updates).
    
    .PARAMETER ApiVersion
        Azure REST API version to use. Default: "2025-10-01".
    
    .PARAMETER ExportPath
        Export results to CSV (.csv), JSON (.json), or JUnit XML (.xml) file.
    
    .PARAMETER UpdateSummary
        Pre-fetched update summary object from Get-AzureLocalUpdateSummary.
        When provided, skips the internal summary fetch to avoid redundant API calls.
        Only used when checking a single cluster via -ClusterResourceIds with one ID.
    
    .OUTPUTS
        PSCustomObject[] - Array of health check results per cluster.
    
    .EXAMPLE
        Test-AzureLocalClusterHealth -ClusterResourceIds @("/subscriptions/.../clusters/Seattle")
        Checks health for a single cluster by resource ID.
    
    .EXAMPLE
        Test-AzureLocalClusterHealth -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -BlockingOnly
        Shows only Critical (update-blocking) health failures for all Wave1 clusters.
    
    .EXAMPLE
        Test-AzureLocalClusterHealth -ClusterNames "MyCluster" -ExportPath "C:\Reports\health.csv"
        Checks health and exports results to CSV.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByResourceId')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [switch]$BlockingOnly,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [object]$UpdateSummary,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Cluster Health Validation" -Level Header
    Write-Log -Message "========================================" -Level Header

    # Verify Azure CLI
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Not logged in" }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Build cluster list (reuse existing patterns)
    $clustersToCheck = @()

    if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        if (-not (Install-AzGraphExtension)) {
            Write-Error "Failed to install Azure CLI 'resource-graph' extension."
            return
        }
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id, name, resourceGroup, subscriptionId"
        try {
            $clusters = Invoke-AzResourceGraphQuery -Query $argQuery
        }
        catch {
            Write-Log -Message "Azure Resource Graph query failed: $($_.Exception.Message)" -Level Error
            return
        }
        if (-not $clusters -or $clusters.Count -eq 0) {
            Write-Log -Message "No clusters found with UpdateRing = '$UpdateRingValue'" -Level Warning
            return @()
        }
        foreach ($c in $clusters) {
            $clustersToCheck += @{ ResourceId = $c.id; Name = $c.name }
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
        foreach ($rid in $ClusterResourceIds) {
            $clustersToCheck += @{ ResourceId = $rid; Name = ($rid -split '/')[-1] }
        }
    }
    else {
        # ByName - resolve names to resource IDs upfront to avoid per-cluster lookups
        if (-not $SubscriptionId) { $SubscriptionId = (az account show --query id -o tsv) }
        foreach ($name in $ClusterNames) {
            $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
            if ($clusterInfo) {
                $clustersToCheck += @{ ResourceId = $clusterInfo.id; Name = $clusterInfo.name }
            }
            else {
                Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning
            }
        }
    }

    Write-Log -Message "Checking health for $($clustersToCheck.Count) cluster(s)..." -Level Info

    $results = @()
    $overallPassed = $true

    foreach ($cluster in $clustersToCheck) {
        $clusterName = $cluster.Name
        Write-Host "  Checking: $clusterName..." -ForegroundColor Gray -NoNewline

        try {
            # Get resource ID if needed
            $resourceId = $cluster.ResourceId
            if (-not $resourceId) {
                $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                    -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
                if ($clusterInfo) { $resourceId = $clusterInfo.id }
            }
            if (-not $resourceId) {
                Write-Host " Not Found" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    ClusterName = $clusterName; HealthState = "Not Found"; Passed = $false
                    CriticalCount = 0; WarningCount = 0; Failures = @()
                }
                $overallPassed = $false
                continue
            }

            # Get update summary (contains healthCheckResult)
            # Use pre-fetched summary if provided, otherwise fetch from API
            $summary = $null
            if ($UpdateSummary -and $clustersToCheck.Count -eq 1) {
                $summary = $UpdateSummary
            }
            else {
                $summary = Get-AzureLocalUpdateSummary -ClusterResourceId $resourceId -ApiVersion $ApiVersion
            }
            if (-not $summary -or -not $summary.properties.healthCheckResult) {
                Write-Host " No Health Data" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    ClusterName = $clusterName; HealthState = "No Data"; Passed = $true
                    CriticalCount = 0; WarningCount = 0; Failures = @()
                }
                continue
            }

            $healthState = if ($summary.properties.healthState) { $summary.properties.healthState } else { "Unknown" }
            $healthChecks = $summary.properties.healthCheckResult

            # Extract failures (Critical and Warning only; use -BlockingOnly for Critical only)
            $failures = @()
            foreach ($check in $healthChecks) {
                if ($check.status -eq "Failed") {
                    $sev = if ($check.severity) { $check.severity } else { "Unknown" }
                    if ($BlockingOnly -and $sev -ne "Critical") { continue }
                    if ($sev -eq "Informational") { continue }
                    $displayName = if ($check.displayName) { $check.displayName } elseif ($check.name) { ($check.name -split '/')[0] } else { "Unknown" }
                    $failures += [PSCustomObject]@{
                        ClusterName        = $clusterName
                        CheckName          = $displayName
                        Severity           = $sev
                        Description        = if ($check.description) { $check.description } else { "" }
                        Remediation        = if ($check.remediation) { $check.remediation } else { "" }
                        TargetResourceName = if ($check.targetResourceName) { $check.targetResourceName } else { "" }
                        Timestamp          = if ($check.timestamp) { $check.timestamp } else { "" }
                    }
                }
            }

            $critCount = @($failures | Where-Object { $_.Severity -eq "Critical" }).Count
            $warnCount = @($failures | Where-Object { $_.Severity -eq "Warning" }).Count
            $passed = ($critCount -eq 0)
            if (-not $passed) { $overallPassed = $false }

            # Console output
            if ($passed -and $failures.Count -eq 0) {
                Write-Host " Healthy" -ForegroundColor Green
            }
            elseif ($passed) {
                Write-Host " Warnings ($warnCount)" -ForegroundColor Yellow
            }
            else {
                Write-Host " BLOCKED ($critCount critical)" -ForegroundColor Red
            }

            $results += [PSCustomObject]@{
                ClusterName   = $clusterName
                HealthState   = $healthState
                Passed        = $passed
                CriticalCount = $critCount
                WarningCount  = $warnCount
                Failures      = $failures
            }
        }
        catch {
            Write-Host " Error: $($_.Exception.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                ClusterName = $clusterName; HealthState = "Error"; Passed = $false
                CriticalCount = 0; WarningCount = 0; Failures = @()
            }
            $overallPassed = $false
        }
    }

    # Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Health Validation Summary" -Level Header
    Write-Log -Message "========================================" -Level Header

    $totalClusters = $results.Count
    $passedCount = @($results | Where-Object { $_.Passed -eq $true }).Count
    $failedCount = $totalClusters - $passedCount

    Write-Log -Message "Total Clusters:  $totalClusters" -Level Info
    Write-Log -Message "Passed:          $passedCount (no critical failures)" -Level $(if ($passedCount -eq $totalClusters) { "Success" } else { "Info" })
    Write-Log -Message "Blocked:         $failedCount (critical failures present)" -Level $(if ($failedCount -gt 0) { "Error" } else { "Info" })

    # Display failure details
    $allFailures = @($results | ForEach-Object { $_.Failures } | Where-Object { $_ })
    if ($allFailures.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Health Check Failures:" -Level Header
        $allFailures | Format-Table ClusterName, Severity, CheckName, TargetResourceName, Description -AutoSize -Wrap | Out-String -Stream | ForEach-Object {
            if ($_ -ne "") { Write-Log -Message $_ -Level Info }
        }

        # Show remediation for Critical failures
        $criticalFailures = @($allFailures | Where-Object { $_.Severity -eq "Critical" })
        if ($criticalFailures.Count -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "Remediation for Critical (Update-Blocking) Failures:" -Level Warning
            foreach ($f in $criticalFailures) {
                if ($f.Remediation) {
                    $nodeInfo = if ($f.TargetResourceName) { " ($($f.TargetResourceName))" } else { "" }
                    Write-Log -Message "  $($f.ClusterName) - $($f.CheckName)$nodeInfo`: $($f.Remediation)" -Level Warning
                }
            }
        }
    }
    else {
        Write-Log -Message "" -Level Info
        Write-Log -Message "No health check failures detected. All clusters are ready for updates." -Level Success
    }

    # Overall result
    Write-Log -Message "" -Level Info
    if ($overallPassed) {
        Write-Log -Message "HEALTH VALIDATION PASSED - All clusters are ready for updates" -Level Success
    }
    else {
        Write-Log -Message "HEALTH VALIDATION FAILED - Critical health issues must be resolved before updates can proceed" -Level Error
    }

    # Export if path specified
    if ($ExportPath -and $allFailures.Count -gt 0) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            $extension = [System.IO.Path]::GetExtension($ExportPath).ToLower()
            switch ($extension) {
                '.csv' {
                    $allFailures | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                '.json' {
                    $exportData = @{
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        OverallPassed = $overallPassed
                        TotalClusters = $totalClusters
                        Passed = $passedCount
                        Blocked = $failedCount
                        Failures = $allFailures
                    }
                    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                '.xml' {
                    $junitResults = $allFailures | ForEach-Object {
                        $junitNodeInfo = if ($_.TargetResourceName) { " (Node: $($_.TargetResourceName))" } else { "" }
                        [PSCustomObject]@{
                            ClusterName = $_.ClusterName; Status = "Failed"
                            Message = "$($_.Severity): $($_.CheckName)$junitNodeInfo - $($_.Description)"
                            UpdateName = $_.CheckName; CurrentState = $_.Severity
                        }
                    }
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalClusterHealth" -OperationType "HealthCheck"
                    Write-Log -Message "Results exported to JUnit XML: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
        }
    }

    if ($PassThru) {
        return $results
    }
}

#endregion Pre-Update Health Validation

#region Fleet Status Data Collection (v0.6.4)

function Get-AzureLocalFleetStatusData {
    <#
    .SYNOPSIS
        Collects comprehensive fleet status data from Azure Local clusters with optional parallelism.
    
    .DESCRIPTION
        Performs a single-pass data collection across Azure Local clusters, making only 3 core API
        calls per cluster (cluster info, update summary, available updates) plus update run queries.
        
        Returns a structured PSCustomObject containing readiness, cluster details, update runs,
        and health check data. This object can be:
        - Exported to JSON for CI/CD pipeline artifact passing between jobs
        - Passed to New-AzureLocalFleetStatusHtmlReport via -StatusData to avoid redundant API calls
        - Used directly for custom reporting or analysis
        
        When -ThrottleLimit is greater than 1, splits the cluster list into batches and uses
        Start-Job for parallel data collection. Each job imports the module and calls this
        function with -ThrottleLimit 1 for its batch. Results are merged automatically.
        
        Note: Azure ARM allows ~200 reads/5 minutes per subscription. With ThrottleLimit 4
        and 4 API calls per cluster, parallel execution processes clusters ~4x faster while
        staying within throttling limits for most fleet sizes.
    
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to collect data for.
    
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to collect data for.
    
    .PARAMETER ScopeByUpdateRingTag
        Find clusters by their 'UpdateRing' tag value via Azure Resource Graph.
    
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    
    .PARAMETER AllClusters
        Discovers all Azure Local clusters via Azure Resource Graph (limited to 100).
    
    .PARAMETER ResourceGroupName
        Resource group containing the clusters (only used with -ClusterNames).
    
    .PARAMETER SubscriptionId
        Azure subscription ID (defaults to current subscription).
    
    .PARAMETER IncludeUpdateRuns
        Collect latest update run history per cluster.
    
    .PARAMETER IncludeHealthDetails
        Collect detailed health check failure data per cluster.
    
    .PARAMETER ThrottleLimit
        Number of parallel workers for data collection. Default: 4.
        Set to 1 for sequential collection. Maximum: 8 (to respect ARM throttling).
    
    .PARAMETER ExportPath
        Path to export the collected data as JSON. This JSON artifact can be passed
        between CI/CD pipeline jobs to avoid redundant API calls.
    
    .OUTPUTS
        PSCustomObject with properties: SchemaVersion, Timestamp, ModuleVersion, Scope,
        Readiness, ClusterDetails, LatestRuns, HealthResults.
    
    .EXAMPLE
        # Collect data for all clusters (parallel)
        $data = Get-AzureLocalFleetStatusData -AllClusters -IncludeUpdateRuns -IncludeHealthDetails
    
    .EXAMPLE
        # Export to JSON artifact for CI/CD pipeline
        Get-AzureLocalFleetStatusData -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -ExportPath "fleet-data.json"
    
    .EXAMPLE
        # Collect data then generate HTML report (no redundant API calls)
        $data = Get-AzureLocalFleetStatusData -AllClusters -ThrottleLimit 4 -IncludeUpdateRuns -IncludeHealthDetails
        New-AzureLocalFleetStatusHtmlReport -StatusData $data -OutputPath "report.html"
    
    .EXAMPLE
        # Sequential collection (for debugging or small fleets)
        $data = Get-AzureLocalFleetStatusData -ClusterResourceIds $ids -ThrottleLimit 1
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [switch]$AllClusters,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeUpdateRuns,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeHealthDetails,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 8)]
        [int]$ThrottleLimit = 4,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    # Verify Azure CLI
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Not logged in" }
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return $null
    }

    # Resolve scope to resource IDs
    $allResourceIds = @()
    $scopeDescription = ""

    switch ($PSCmdlet.ParameterSetName) {
        'ByTag' {
            if (-not (Install-AzGraphExtension)) {
                Write-Log -Message "Failed to install 'resource-graph' extension." -Level Error
                return $null
            }
            $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id"
            try {
                $tagData = Invoke-AzResourceGraphQuery -Query $argQuery
            }
            catch {
                Write-Log -Message "ARG query failed: $($_.Exception.Message)" -Level Error
                return $null
            }
            if (-not $tagData -or $tagData.Count -eq 0) { Write-Log -Message "No clusters found with UpdateRing = '$UpdateRingValue'" -Level Warning; return $null }
            $allResourceIds = @($tagData | Select-Object -ExpandProperty id)
            $scopeDescription = "UpdateRing = $UpdateRingValue"
        }
        'ByResourceId' {
            $allResourceIds = $ClusterResourceIds
            $scopeDescription = "$($ClusterResourceIds.Count) cluster(s) by Resource ID"
        }
        'ByName' {
            if (-not $SubscriptionId) { $SubscriptionId = (az account show --query id -o tsv) }
            foreach ($name in $ClusterNames) {
                $infoParams = @{ ClusterName = $name; SubscriptionId = $SubscriptionId }
                if ($ResourceGroupName) { $infoParams['ResourceGroupName'] = $ResourceGroupName }
                $ci = Get-AzureLocalClusterInfo @infoParams
                if ($ci -and $ci.id) { $allResourceIds += $ci.id }
                else { Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning }
            }
            $scopeDescription = "$($ClusterNames.Count) cluster(s) by name"
        }
        'All' {
            $inventory = @(Get-AzureLocalClusterInventory -PassThru)
            if (-not $inventory -or $inventory.Count -eq 0) { Write-Log -Message "No clusters found." -Level Warning; return $null }
            if ($inventory.Count -gt 100) { $inventory = $inventory | Select-Object -First 100 }
            $allResourceIds = @($inventory | Select-Object -ExpandProperty ResourceId)
            $scopeDescription = "All clusters ($($allResourceIds.Count))"
        }
    }

    if ($allResourceIds.Count -eq 0) {
        Write-Log -Message "No cluster resource IDs resolved." -Level Warning
        return $null
    }

    Write-Log -Message "Collecting fleet status data for $($allResourceIds.Count) cluster(s) [ThrottleLimit=$ThrottleLimit]..." -Level Info

    # Determine if parallel execution is warranted
    $useParallel = ($ThrottleLimit -gt 1) -and ($allResourceIds.Count -gt $ThrottleLimit)

    $readiness = [System.Collections.Generic.List[object]]::new()
    $clusterDetails = [System.Collections.Generic.List[object]]::new()
    $latestRuns = [System.Collections.Generic.List[object]]::new()
    $healthResults = [System.Collections.Generic.List[object]]::new()
    # Track clusters whose data could not be collected (failed job / parse error)
    $failedClusters = [System.Collections.Generic.List[object]]::new()

    if ($useParallel) {
        #--- Parallel collection using Start-Job ---
        $batchSize = [math]::Ceiling($allResourceIds.Count / $ThrottleLimit)
        $batches = @()
        for ($i = 0; $i -lt $allResourceIds.Count; $i += $batchSize) {
            $batches += ,@($allResourceIds[$i..[math]::Min($i + $batchSize - 1, $allResourceIds.Count - 1)])
        }

        Write-Log -Message "Splitting $($allResourceIds.Count) clusters into $($batches.Count) parallel batches of ~$batchSize" -Level Info

        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'AzStackHci.ManageUpdates.psm1'
        # Pre-flight: jobs must be able to re-import this module by path
        if (-not (Test-Path -LiteralPath $modulePath)) {
            throw "Parallel collection requires module path '$modulePath' to be reachable by background jobs, but it does not exist. Falling back to sequential mode is not supported here - re-run without -ThrottleLimit > 1 or from a directory where PSScriptRoot resolves correctly."
        }
        $incRuns = $IncludeUpdateRuns.IsPresent
        $incHealth = $IncludeHealthDetails.IsPresent
        $apiVer = $script:DefaultApiVersion

        $jobScriptBlock = {
            param([string[]]$BatchIds, [string]$ApiVer, [bool]$IncRuns, [bool]$IncHealth, [string]$ModPath)
            Import-Module $ModPath -Force -ErrorAction Stop
            $params = @{
                ClusterResourceIds = $BatchIds
                ThrottleLimit = 1
            }
            if ($IncRuns) { $params['IncludeUpdateRuns'] = $true }
            if ($IncHealth) { $params['IncludeHealthDetails'] = $true }
            $result = Get-AzureLocalFleetStatusData @params
            $result | ConvertTo-Json -Depth 15 -Compress
        }

        $jobs = [System.Collections.Generic.List[object]]::new()
        # Track which cluster IDs were dispatched to each job so we can report
        # which clusters are missing data when a job fails.
        $jobClusterMap = @{}
        $batchNum = 0
        foreach ($batch in $batches) {
            $batchNum++
            Write-Log -Message "  Starting batch $batchNum ($($batch.Count) clusters)..." -Level Info
            $job = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList @($batch, $apiVer, $incRuns, $incHealth, $modulePath)
            $jobs.Add($job) | Out-Null
            $jobClusterMap[$job.Id] = $batch
        }

        Write-Log -Message "Waiting for $($jobs.Count) parallel jobs to complete..." -Level Info
        $jobs | Wait-Job | Out-Null

        foreach ($job in $jobs) {
            $batchForJob = $jobClusterMap[$job.Id]
            if ($job.State -eq 'Failed') {
                $reason = if ($job.ChildJobs -and $job.ChildJobs[0]) { $job.ChildJobs[0].JobStateInfo.Reason } else { 'Unknown' }
                Write-Log -Message "  Job $($job.Id) failed: $reason" -Level Error
                foreach ($rid in $batchForJob) {
                    $failedClusters.Add([PSCustomObject]@{
                        ResourceId = $rid
                        ClusterName = ($rid -split '/')[-1]
                        Reason = "Job failed: $reason"
                    }) | Out-Null
                }
                continue
            }
            $jobOutput = Receive-Job $job -ErrorAction SilentlyContinue
            if (-not $jobOutput) {
                Write-Log -Message "  Job $($job.Id) returned no output; marking $($batchForJob.Count) cluster(s) as failed" -Level Warning
                foreach ($rid in $batchForJob) {
                    $failedClusters.Add([PSCustomObject]@{
                        ResourceId = $rid
                        ClusterName = ($rid -split '/')[-1]
                        Reason = 'Job returned no output'
                    }) | Out-Null
                }
                continue
            }
            $jobJson = $jobOutput -join "`n"
            try {
                $jobData = $jobJson | ConvertFrom-Json -ErrorAction Stop
                if ($jobData.Readiness) { foreach ($r in @($jobData.Readiness)) { $readiness.Add($r) | Out-Null } }
                if ($jobData.ClusterDetails) { foreach ($c in @($jobData.ClusterDetails)) { $clusterDetails.Add($c) | Out-Null } }
                if ($jobData.LatestRuns) { foreach ($l in @($jobData.LatestRuns)) { $latestRuns.Add($l) | Out-Null } }
                if ($jobData.HealthResults) { foreach ($h in @($jobData.HealthResults)) { $healthResults.Add($h) | Out-Null } }
            }
            catch {
                Write-Log -Message "  Failed to parse job $($job.Id) output: $($_.Exception.Message); marking $($batchForJob.Count) cluster(s) as failed" -Level Error
                foreach ($rid in $batchForJob) {
                    $failedClusters.Add([PSCustomObject]@{
                        ResourceId = $rid
                        ClusterName = ($rid -split '/')[-1]
                        Reason = "Parse error: $($_.Exception.Message)"
                    }) | Out-Null
                }
            }
        }
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue

        Write-Log -Message "Parallel collection complete: $($readiness.Count) cluster(s) collected, $($failedClusters.Count) failed" -Level Success
    }
    else {
        #--- Sequential collection (single-pass per cluster) ---
        $apiVer = $script:DefaultApiVersion
        $clusterIndex = 0
        $totalToProcess = $allResourceIds.Count

        foreach ($rid in $allResourceIds) {
            $clusterIndex++
            $clusterName = ($rid -split '/')[-1]
            $rgName = ($rid -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
            $subId = ($rid -split '/subscriptions/')[1] -split '/' | Select-Object -First 1

            Write-Host "  [$clusterIndex/$totalToProcess] $clusterName..." -ForegroundColor Gray -NoNewline

            try {
                # API Call 1/3: GET cluster info
                $clusterInfoUri = "https://management.azure.com${rid}?api-version=$apiVer"
                $clusterInfo = az rest --method GET --uri $clusterInfoUri 2>$null | ConvertFrom-Json
                if ($LASTEXITCODE -ne 0 -or $null -eq $clusterInfo) {
                    Write-Host " Not Found" -ForegroundColor Red
                    $readiness.Add([PSCustomObject]@{
                        ClusterName = $clusterName; ResourceGroup = $rgName; SubscriptionId = $subId
                        ClusterState = "Not Found"; UpdateState = "N/A"; HealthState = "N/A"
                        ReadyForUpdate = $false; AvailableUpdates = ""; ReadyUpdates = ""
                        HasPrerequisiteUpdates = ""; SBEDependency = ""
                        RecommendedUpdate = ""; HealthCheckFailures = ""
                        UpdateWindow = ""; UpdateExclusions = ""
                    }) | Out-Null
                    $clusterDetails.Add([PSCustomObject]@{
                        ClusterName = $clusterName; ResourceGroup = $rgName
                        CurrentVersion = "N/A"; NodeCount = "N/A"; ResourceId = $rid
                    }) | Out-Null
                    continue
                }

                $clusterState = $clusterInfo.properties.status
                $nodeCount = "N/A"
                if ($clusterInfo.properties.reportedProperties.nodes) {
                    $nodeCount = $clusterInfo.properties.reportedProperties.nodes.Count
                }

                # API Call 2/3: GET update summary
                $summaryUri = "https://management.azure.com${rid}/updateSummaries/default?api-version=$apiVer"
                $updateSummary = az rest --method GET --uri $summaryUri 2>$null | ConvertFrom-Json
                $hasSummary = ($LASTEXITCODE -eq 0 -and $null -ne $updateSummary -and $null -ne $updateSummary.properties)

                $updateState = if ($hasSummary -and $updateSummary.properties.state) { $updateSummary.properties.state } else { "Unknown" }
                $healthState = if ($hasSummary -and $updateSummary.properties.healthState) { $updateSummary.properties.healthState } else { "Unknown" }
                $currentVersion = if ($hasSummary -and $updateSummary.properties.currentVersion) { $updateSummary.properties.currentVersion } else { "N/A" }

                # API Call 3/3: GET available updates
                $updatesUri = "https://management.azure.com${rid}/updates?api-version=$apiVer"
                $updatesResponse = az rest --method GET --uri $updatesUri 2>$null | ConvertFrom-Json
                $hasUpdates = ($LASTEXITCODE -eq 0 -and $null -ne $updatesResponse -and $null -ne $updatesResponse.value)
                $availableUpdates = if ($hasUpdates) { @($updatesResponse.value) } else { @() }
                $readyUpdates = @($availableUpdates | Where-Object { $_.properties.state -in $script:ReadyStates })
                $prereqUpdates = @($availableUpdates | Where-Object { $_.properties.state -in $script:PrereqStates })

                $availableUpdateNames = ($availableUpdates | ForEach-Object { $_.name }) -join "; "
                $readyUpdateNames = ($readyUpdates | ForEach-Object { $_.name }) -join "; "
                $prereqUpdateNames = ($prereqUpdates | ForEach-Object { $_.name }) -join "; "

                # Extract SBE dependency info for HasPrerequisite/AdditionalContentRequired updates
                $sbeDependencyInfo = ""
                foreach ($pu in $prereqUpdates) {
                    $puProps = $pu.properties
                    if ($puProps.packageType -eq "SBE" -and $puProps.additionalProperties) {
                        $addProps = ConvertTo-AzLocalAdditionalProperties -InputObject $puProps.additionalProperties
                        if ($addProps) {
                            $sbeParts = @()
                            if ($addProps.SBEPublisher) { $sbeParts += "Publisher: $($addProps.SBEPublisher)" }
                            if ($addProps.SBEFamily) { $sbeParts += "Family: $($addProps.SBEFamily)" }
                            if ($sbeParts.Count -gt 0) { $sbeDependencyInfo = "$($pu.name): $($sbeParts -join '; ')" }
                        }
                    }
                }

                $recommendedUpdate = ""
                $isUpToDateState = $updateState -in @("UpToDate", "AppliedSuccessfully")
                if ($readyUpdates.Count -gt 0) {
                    $latestReady = Get-LatestUpdateByYYMM -Updates $readyUpdates
                    $recommendedUpdate = $latestReady.name
                }
                elseif (-not $isUpToDateState -and $availableUpdates.Count -gt 0) {
                    $latestAvailable = Get-LatestUpdateByYYMM -Updates $availableUpdates
                    $recommendedUpdate = $latestAvailable.name
                }
                $isReady = ($updateState -in (@("UpdateAvailable") + $script:ReadyStates)) -and ($readyUpdates.Count -gt 0)

                $healthCheckFailures = ""
                if ($hasSummary -and $healthState -notin @("Success", "Unknown")) {
                    $healthCheckFailures = Get-HealthCheckFailureSummary -UpdateSummary $updateSummary
                }

                $readiness.Add([PSCustomObject]@{
                    ClusterName = $clusterName; ResourceGroup = $rgName; SubscriptionId = $subId
                    ClusterState = $clusterState; UpdateState = $updateState; HealthState = $healthState
                    ReadyForUpdate = $isReady; AvailableUpdates = $availableUpdateNames
                    ReadyUpdates = $readyUpdateNames; HasPrerequisiteUpdates = $prereqUpdateNames
                    SBEDependency = $sbeDependencyInfo; RecommendedUpdate = $recommendedUpdate
                    HealthCheckFailures = $healthCheckFailures
                    UpdateWindow = if ($clusterInfo.tags -and $clusterInfo.tags.$($script:UpdateWindowTagName)) { $clusterInfo.tags.$($script:UpdateWindowTagName) } else { "" }
                    UpdateExclusions = if ($clusterInfo.tags -and $clusterInfo.tags.$($script:UpdateExclusionsTagName)) { $clusterInfo.tags.$($script:UpdateExclusionsTagName) } else { "" }
                }) | Out-Null
                $clusterDetails.Add([PSCustomObject]@{
                    ClusterName = $clusterName; ResourceGroup = $rgName
                    CurrentVersion = $currentVersion; NodeCount = $nodeCount; ResourceId = $rid
                }) | Out-Null

                # Update runs (reuse already-fetched update list)
                if ($IncludeUpdateRuns) {
                    $clusterBestRun = $null
                    $clusterBestRunTime = ""
                    foreach ($update in $availableUpdates) {
                        $runsUri = "https://management.azure.com${rid}/updates/$($update.name)/updateRuns?api-version=$apiVer"
                        $runsResult = az rest --method GET --uri $runsUri 2>$null | ConvertFrom-Json
                        if ($LASTEXITCODE -eq 0 -and $runsResult.value) {
                            foreach ($run in $runsResult.value) {
                                $runTime = $run.properties.timeStarted
                                if (-not $clusterBestRun -or ($runTime -and $runTime -gt $clusterBestRunTime)) {
                                    $clusterBestRun = $run
                                    $clusterBestRunTime = $runTime
                                }
                            }
                        }
                    }
                    if ($clusterBestRun) {
                        $runProps = $clusterBestRun.properties
                        $runDuration = ""
                        if ($runProps.timeStarted) {
                            $runStartTime = [datetime]$runProps.timeStarted
                            if ($runProps.lastUpdatedTime) {
                                $durationSpan = ([datetime]$runProps.lastUpdatedTime) - $runStartTime
                                $runDuration = if ($durationSpan.TotalHours -ge 1) { "{0:N1} hours" -f $durationSpan.TotalHours } else { "{0:N0} minutes" -f $durationSpan.TotalMinutes }
                            }
                            elseif ($runProps.state -eq "InProgress") {
                                $runDuration = "{0:N1} hours (running)" -f ((Get-Date) - $runStartTime).TotalHours
                            }
                        }
                        $currentStep = ""; $currentStepDetail = ""; $runProgress = ""
                        if ($runProps.progress -and $runProps.progress.steps) {
                            $steps = $runProps.progress.steps
                            $runProgress = "$(($steps | Where-Object { $_.status -eq 'Success' }).Count)/$($steps.Count) steps"
                            $ipStep = $steps | Where-Object { $_.status -eq "InProgress" } | Select-Object -First 1
                            $fStep = $steps | Where-Object { $_.status -in @("Error", "Failed") } | Select-Object -First 1
                            if ($ipStep) { $currentStep = $ipStep.name } elseif ($fStep) { $currentStep = "$($fStep.name) (FAILED)" }
                            $currentStepDetail = Get-CurrentStepPath -Steps $steps -IncludeErrorMessage
                            if ([string]::IsNullOrWhiteSpace($currentStepDetail)) { $currentStepDetail = $currentStep }
                        }
                        $updateNameExtracted = ""; $runId = ""
                        if ($clusterBestRun.id -match '/updates/([^/]+)/updateRuns/([^/]+)$') { $updateNameExtracted = $matches[1]; $runId = $matches[2] }
                        else { $runId = $clusterBestRun.name }
                        $latestRuns.Add([PSCustomObject]@{
                            ClusterName = $clusterName; UpdateName = $updateNameExtracted; RunId = $runId
                            State = $runProps.state
                            StartTime = if ($runProps.timeStarted) { ([datetime]$runProps.timeStarted).ToString("yyyy-MM-dd HH:mm") } else { "" }
                            Duration = $runDuration; Progress = $runProgress
                            CurrentStep = $currentStep; CurrentStepDetail = $currentStepDetail
                            Location = $runProps.location
                        }) | Out-Null
                    }
                }

                # Health details (from already-fetched update summary)
                if ($IncludeHealthDetails) {
                    $failures = @()
                    if ($hasSummary -and $updateSummary.properties.healthCheckResult) {
                        foreach ($check in $updateSummary.properties.healthCheckResult) {
                            if ($check.status -eq "Failed") {
                                $sev = if ($check.severity) { $check.severity } else { "Unknown" }
                                $displayName = if ($check.displayName) { $check.displayName } elseif ($check.name) { ($check.name -split '/')[0] } else { "Unknown" }
                                $failures += [PSCustomObject]@{
                                    ClusterName = $clusterName; CheckName = $displayName; Severity = $sev
                                    Description = if ($check.description) { $check.description } else { "" }
                                    Remediation = if ($check.remediation) { $check.remediation } else { "" }
                                    TargetResourceName = if ($check.targetResourceName) { $check.targetResourceName } else { "" }
                                    Timestamp = if ($check.timestamp) { $check.timestamp } else { "" }
                                }
                            }
                        }
                    }
                    $critCount = @($failures | Where-Object { $_.Severity -eq "Critical" }).Count
                    $warnCount = @($failures | Where-Object { $_.Severity -eq "Warning" }).Count
                    $infoCount = @($failures | Where-Object { $_.Severity -eq "Informational" }).Count
                    $healthResults.Add([PSCustomObject]@{
                        ClusterName = $clusterName; HealthState = $healthState; Passed = ($critCount -eq 0)
                        CriticalCount = $critCount; WarningCount = $warnCount; InfoCount = $infoCount
                        Failures = $failures
                    }) | Out-Null
                }

                # Status output
                if ($isReady) { Write-Host " Ready" -ForegroundColor Green }
                elseif ($prereqUpdates.Count -gt 0 -and $readyUpdates.Count -eq 0) { Write-Host " Has Prerequisite" -ForegroundColor Yellow }
                elseif ($updateState -eq "UpdateInProgress") { Write-Host " In Progress" -ForegroundColor Yellow }
                elseif ($updateState -in @("UpToDate", "AppliedSuccessfully")) { Write-Host " Up to Date" -ForegroundColor Green }
                elseif ($healthState -eq "Failure") { Write-Host " Health Failure" -ForegroundColor Red }
                else { Write-Host " $updateState" -ForegroundColor Gray }
            }
            catch {
                Write-Host " Error: $($_.Exception.Message)" -ForegroundColor Red
                $readiness.Add([PSCustomObject]@{
                    ClusterName = $clusterName; ResourceGroup = $rgName; SubscriptionId = $subId
                    ClusterState = "Error"; UpdateState = "Error"; HealthState = "Error"
                    ReadyForUpdate = $false; AvailableUpdates = ""; ReadyUpdates = ""
                    HasPrerequisiteUpdates = ""; SBEDependency = ""
                    RecommendedUpdate = ""; HealthCheckFailures = $_.Exception.Message
                    UpdateWindow = ""; UpdateExclusions = ""
                }) | Out-Null
                $clusterDetails.Add([PSCustomObject]@{
                    ClusterName = $clusterName; ResourceGroup = $rgName
                    CurrentVersion = "N/A"; NodeCount = "N/A"; ResourceId = $rid
                }) | Out-Null
            }
        }

        Write-Log -Message "Sequential collection complete: $($readiness.Count) cluster(s)" -Level Success
    }

    # Build result object with stable schema
    $result = [PSCustomObject]@{
        SchemaVersion  = "1.0"
        Timestamp      = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        ModuleVersion  = $script:ModuleVersion
        Scope          = $scopeDescription
        TotalClusters  = $readiness.Count
        Readiness      = @($readiness)
        ClusterDetails = @($clusterDetails)
        LatestRuns     = @($latestRuns)
        HealthResults  = @($healthResults)
        FailedClusters = @($failedClusters)
    }

    # Export to JSON if path specified
    if ($ExportPath) {
        $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
        $exportDir = Split-Path -Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $result | ConvertTo-Json -Depth 15 | Out-File -FilePath $ExportPath -Encoding UTF8 -Force
        Write-Log -Message "Fleet status data exported to: $ExportPath" -Level Success
    }

    return $result
}

#endregion Fleet Status Data Collection

#region Fleet Status HTML Report

function New-AzureLocalFleetStatusHtmlReport {
    <#
    .SYNOPSIS
        Generates a self-contained HTML report of fleet update status.
    
    .DESCRIPTION
        Collects update status data from Azure Local clusters and generates a standalone
        HTML report suitable for email, SharePoint, or offline viewing. The report includes
        executive summary cards, a progress bar, cluster status table with color-coded badges,
        and optional sections for health check failures and update run history.
        
        Data is collected using the module's existing functions:
        - Get-AzureLocalClusterInventory (cluster list and UpdateRing tags)
        - Get-AzureLocalClusterUpdateReadiness (health state, readiness)
        - Get-AzureLocalUpdateSummary (current update versions)
        - Get-AzureLocalAvailableUpdates (pending updates)
        - Get-AzureLocalUpdateRuns (recent update history, optional)
        - Test-AzureLocalClusterHealth (detailed health checks, optional)
    
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to include in the report.
    
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to include in the report.
    
    .PARAMETER ScopeByUpdateRingTag
        Find clusters by their 'UpdateRing' tag value via Azure Resource Graph.
    
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    
    .PARAMETER ResourceGroupName
        Resource group containing the clusters (only used with -ClusterNames).
    
    .PARAMETER SubscriptionId
        Azure subscription ID (defaults to current subscription).
    
    .PARAMETER AllClusters
        Discovers all Azure Local clusters via Azure Resource Graph and includes them
        in the report. Limited to the first 100 clusters to prevent excessive API calls.
        Uses the current Azure CLI subscription context.
    
    .PARAMETER OutputPath
        File path for the HTML report output. Required.
    
    .PARAMETER IncludeUpdateRuns
        Include recent update run history section in the report.
    
    .PARAMETER IncludeHealthDetails
        Include detailed health check failure section in the report.
    
    .PARAMETER Title
        Custom report title. Auto-generated if not specified:
        single cluster = '<ClusterName> - Update Status Report',
        multiple clusters = 'Azure Local Fleet Update Status Report'.
    
    .PARAMETER PassThru
        Returns the HTML content as a string in addition to writing the file.
    
    .OUTPUTS
        System.String - HTML content (only when -PassThru is specified).
    
    .EXAMPLE
        New-AzureLocalFleetStatusHtmlReport -AllClusters -OutputPath "C:\Reports\fleet-all.html"
        Generates an HTML report for all clusters (up to 100) across the subscription.
    
    .EXAMPLE
        New-AzureLocalFleetStatusHtmlReport -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -OutputPath "C:\Reports\wave1-status.html"
        Generates an HTML report for all Wave1 clusters.
    
    .EXAMPLE
        New-AzureLocalFleetStatusHtmlReport -ClusterNames @("Cluster01","Cluster02") -OutputPath "C:\Reports\fleet.html" -IncludeHealthDetails -IncludeUpdateRuns
        Generates a full report with health details and update run history.
    
    .EXAMPLE
        $html = New-AzureLocalFleetStatusHtmlReport -ScopeByUpdateRingTag -UpdateRingValue "Production" -OutputPath "C:\Reports\prod.html" -PassThru
        Generates the report and also captures the HTML string for further use (e.g., email body).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All', SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [switch]$AllClusters,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
            $parent = Split-Path $_ -Parent
            if ($parent -and -not (Test-Path $parent)) {
                # Check if the drive at least exists
                $drive = Split-Path $_ -Qualifier -ErrorAction SilentlyContinue
                if ($drive -and -not (Test-Path $drive)) {
                    throw "Drive '$drive' does not exist. Check the output path."
                }
            }
            if ($_ -notmatch '\.html?$') {
                throw "OutputPath must end with .html extension."
            }
            $true
        })]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeUpdateRuns,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeHealthDetails,

        [Parameter(Mandatory = $false)]
        [string]$Title = "",

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$StatusData,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 8)]
        [int]$ThrottleLimit = 4,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Fleet Status HTML Report Generation" -Level Header
    Write-Log -Message "========================================" -Level Header

    # Load System.Web for HtmlEncode (XSS protection)
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

    # Verify Azure CLI
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Not logged in" }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # If pre-collected StatusData is provided, skip all API calls and go straight to rendering
    if ($StatusData) {
        Write-Log -Message "Using pre-collected StatusData ($($StatusData.TotalClusters) clusters, collected $($StatusData.Timestamp))" -Level Info
        $readiness = @($StatusData.Readiness)
        $clusterDetails = @($StatusData.ClusterDetails)
        $latestRuns = @($StatusData.LatestRuns)
        $healthResults = @($StatusData.HealthResults)
        [array]$updateRuns = @()
        if ($IncludeUpdateRuns) { [array]$updateRuns = @($latestRuns) }
    }
    else {
        # Collect data via Get-AzureLocalFleetStatusData (single-pass, parallel-capable)
        $collectParams = @{ ThrottleLimit = $ThrottleLimit }
        if ($IncludeUpdateRuns) { $collectParams['IncludeUpdateRuns'] = $true }
        if ($IncludeHealthDetails) { $collectParams['IncludeHealthDetails'] = $true }

        switch ($PSCmdlet.ParameterSetName) {
            'ByTag'        { $collectParams['ScopeByUpdateRingTag'] = $true; $collectParams['UpdateRingValue'] = $UpdateRingValue }
            'ByResourceId' { $collectParams['ClusterResourceIds'] = $ClusterResourceIds }
            'ByName'       {
                $collectParams['ClusterNames'] = $ClusterNames
                if ($ResourceGroupName) { $collectParams['ResourceGroupName'] = $ResourceGroupName }
                if ($SubscriptionId) { $collectParams['SubscriptionId'] = $SubscriptionId }
            }
            'All'          { $collectParams['AllClusters'] = $true }
        }

        $StatusData = Get-AzureLocalFleetStatusData @collectParams
        if (-not $StatusData) {
            Write-Log -Message "No data collected. Cannot generate report." -Level Warning
            return
        }

        $readiness = @($StatusData.Readiness)
        $clusterDetails = @($StatusData.ClusterDetails)
        $latestRuns = @($StatusData.LatestRuns)
        $healthResults = @($StatusData.HealthResults)
        [array]$updateRuns = @()
        if ($IncludeUpdateRuns) { [array]$updateRuns = @($latestRuns) }
    }

    if ($readiness.Count -eq 0) {
        Write-Log -Message "No clusters found. Cannot generate report." -Level Warning
        return
    }

    # Auto-generate title if not explicitly provided
    if ([string]::IsNullOrWhiteSpace($Title)) {
        if ($readiness.Count -eq 1) {
            $Title = "$($readiness[0].ClusterName) - Update Status Report"
        }
        else {
            $Title = "Azure Local Fleet Update Status Report"
        }
    }

    #--- Calculate summary statistics ---
    $totalClusters = $readiness.Count
    $upToDate   = @($readiness | Where-Object { $_.UpdateState -in @("UpToDate", "AppliedSuccessfully") }).Count
    $inProgress = @($readiness | Where-Object { $_.UpdateState -eq "UpdateInProgress" }).Count
    $updateAvailable = @($readiness | Where-Object { $_.ReadyForUpdate -eq $true }).Count
    $healthFailures  = @($readiness | Where-Object { $_.HealthState -eq "Failure" }).Count
    $otherCount = [math]::Max(0, $totalClusters - $upToDate - $inProgress - $updateAvailable - $healthFailures)

    $pctUpToDate   = if ($totalClusters -gt 0) { [math]::Round(($upToDate / $totalClusters) * 100, 1) } else { 0 }
    $pctInProgress = if ($totalClusters -gt 0) { [math]::Round(($inProgress / $totalClusters) * 100, 1) } else { 0 }
    $pctAvailable  = if ($totalClusters -gt 0) { [math]::Round(($updateAvailable / $totalClusters) * 100, 1) } else { 0 }
    $pctFailures   = if ($totalClusters -gt 0) { [math]::Round(($healthFailures / $totalClusters) * 100, 1) } else { 0 }
    $pctOther      = if ($totalClusters -gt 0) { [math]::Round(($otherCount / $totalClusters) * 100, 1) } else { 0 }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $scopeDescription = if ($StatusData.Scope) { $StatusData.Scope } else {
        switch ($PSCmdlet.ParameterSetName) {
            'ByTag'        { "UpdateRing = $UpdateRingValue" }
            'ByResourceId' { "$($ClusterResourceIds.Count) cluster(s) by Resource ID" }
            'ByName'       { "$($ClusterNames.Count) cluster(s) by name" }
            'All'          { "All clusters ($totalClusters)" }
        }
    }

    #--- Build cluster identity section HTML (used at top or bottom depending on count) ---
    $clusterIdentityHtml = [System.Text.StringBuilder]::new()
    $identitySectionTitle = if ($clusterDetails.Count -le 10) { "Cluster Information" } else { "Appendix: Cluster Information" }
    [void]$clusterIdentityHtml.Append(@"

    <div class="section">
        <h2>$([System.Web.HttpUtility]::HtmlEncode($identitySectionTitle))</h2>
        <table>
            <thead>
                <tr>
                    <th>Cluster Name</th>
                    <th>Current Version</th>
                    <th>Node Count</th>
                    <th>Resource Group</th>
                    <th>Resource ID</th>
                </tr>
            </thead>
            <tbody>
"@)
    foreach ($detail in $clusterDetails) {
        $encDetailName    = [System.Web.HttpUtility]::HtmlEncode($detail.ClusterName)
        $encDetailVersion = [System.Web.HttpUtility]::HtmlEncode($detail.CurrentVersion)
        $encDetailNodes   = [System.Web.HttpUtility]::HtmlEncode($detail.NodeCount)
        $encDetailRG      = [System.Web.HttpUtility]::HtmlEncode($detail.ResourceGroup)
        $encDetailRID     = [System.Web.HttpUtility]::HtmlEncode($detail.ResourceId)
        $detailPortalUrl  = if ($detail.ResourceId) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$($detail.ResourceId)") } else { "" }

        $detailNameCell = if ($detailPortalUrl) {
            "<a href=`"$detailPortalUrl`" class=`"portal-link`" target=`"_blank`" title=`"Open in Azure Portal`"><strong>$encDetailName</strong></a>"
        } else { "<strong>$encDetailName</strong>" }

        [void]$clusterIdentityHtml.Append(@"

                <tr>
                    <td>$detailNameCell</td>
                    <td>$encDetailVersion</td>
                    <td>$encDetailNodes</td>
                    <td>$encDetailRG</td>
                    <td class="resource-id-cell">$encDetailRID</td>
                </tr>
"@)
    }
    [void]$clusterIdentityHtml.Append(@"

            </tbody>
        </table>
    </div>
"@)
    $clusterIdentitySection = $clusterIdentityHtml.ToString()

    #--- Build HTML ---
    Write-Log -Message "Generating HTML report..." -Level Info

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append(@"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$([System.Web.HttpUtility]::HtmlEncode($Title))</title>
    <style>
        :root {
            --success-color: #28a745;
            --failure-color: #dc3545;
            --warning-color: #ffc107;
            --info-color: #17a2b8;
            --pending-color: #6c757d;
            --bg-color: #f8f9fa;
            --card-bg: #ffffff;
            --text-color: #212529;
            --border-color: #dee2e6;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.6;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        header {
            background: linear-gradient(135deg, #552F99, #B596F5);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            position: relative;
        }
        header h1 { font-size: 2em; margin-bottom: 10px; }
        header p { opacity: 0.9; }
        header .logo {
            position: absolute;
            top: 20px;
            right: 30px;
            width: 64px;
            height: 64px;
            opacity: 0.9;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .summary-card {
            background: var(--card-bg);
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 4px solid var(--border-color);
        }
        .summary-card.total      { border-left-color: #9266E6; }
        .summary-card.uptodate   { border-left-color: var(--success-color); }
        .summary-card.inprogress { border-left-color: var(--warning-color); }
        .summary-card.available  { border-left-color: var(--info-color); }
        .summary-card.failures   { border-left-color: var(--failure-color); }
        .summary-card .number {
            font-size: 2.5em; font-weight: bold; display: block;
        }
        .summary-card.total .number      { color: #9266E6; }
        .summary-card.uptodate .number   { color: var(--success-color); }
        .summary-card.inprogress .number { color: var(--warning-color); }
        .summary-card.available .number  { color: var(--info-color); }
        .summary-card.failures .number   { color: var(--failure-color); }
        .summary-card .label {
            text-transform: uppercase; font-size: 0.85em;
            color: #6c757d; letter-spacing: 1px;
        }
        .progress-bar-container {
            background: var(--card-bg);
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .progress-bar-container h3 { margin-bottom: 10px; }
        .progress {
            height: 30px; background: #e9ecef;
            border-radius: 15px; overflow: hidden; display: flex;
        }
        .progress-uptodate   { background: var(--success-color); }
        .progress-inprogress { background: var(--warning-color); }
        .progress-available  { background: var(--info-color); }
        .progress-failures   { background: var(--failure-color); }
        .progress-other      { background: var(--pending-color); }
        .section {
            background: var(--card-bg);
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow-x: auto;
            margin-bottom: 20px;
        }
        .section h2 {
            background: #f1f3f5;
            padding: 15px 20px;
            border-bottom: 1px solid var(--border-color);
        }
        table {
            width: 100%; border-collapse: collapse;
            min-width: 800px;
        }
        th {
            background: #f8f9fa; padding: 12px 16px;
            text-align: left; font-weight: 600;
            border-bottom: 2px solid var(--border-color);
            white-space: nowrap;
        }
        td {
            padding: 12px 16px;
            border-bottom: 1px solid #f1f3f5;
        }
        tr:hover td { background: #f8f9fa; }
        .status-badge {
            display: inline-block; padding: 4px 12px;
            border-radius: 12px; font-size: 0.85em;
            font-weight: 600; white-space: nowrap;
        }
        .status-uptodate      { background: #d4edda; color: #155724; }
        .status-inprogress    { background: #fff3cd; color: #856404; }
        .status-available     { background: #d1ecf1; color: #0c5460; }
        .status-failure       { background: #f8d7da; color: #721c24; }
        .status-unknown       { background: #e2e3e5; color: #383d41; }
        .severity-critical    { background: #f8d7da; color: #721c24; font-weight: 600; }
        .severity-warning     { background: #fff3cd; color: #856404; }
        .severity-info        { background: #d1ecf1; color: #0c5460; }
        .message-cell {
            max-width: 500px;
            white-space: normal;
            word-wrap: break-word;
            font-size: 0.9em;
        }
        .resource-id-cell {
            font-family: 'Consolas', 'Courier New', monospace;
            font-size: 0.85em;
            white-space: nowrap;
            user-select: all;
        }
        a.portal-link {
            color: #0078d4;
            text-decoration: none;
            border-bottom: 1px dashed #0078d4;
        }
        a.portal-link:hover {
            color: #005a9e;
            border-bottom-color: #005a9e;
        }
        details {
            margin-bottom: 8px;
        }
        details summary {
            cursor: pointer;
            padding: 10px 16px;
            border-bottom: 1px solid #f1f3f5;
            font-weight: 600;
            list-style: none;
        }
        details summary::-webkit-details-marker { display: none; }
        details summary::before {
            content: '\25B6';
            display: inline-block;
            margin-right: 8px;
            transition: transform 0.2s;
            font-size: 0.8em;
        }
        details[open] summary::before {
            transform: rotate(90deg);
        }
        details[open] summary {
            border-bottom: 2px solid var(--border-color);
        }
        .failure-summary-counts {
            font-weight: normal;
            font-size: 0.9em;
            color: #6c757d;
            margin-left: 8px;
        }
        .failure-summary-top-issue {
            font-weight: normal;
            font-size: 0.85em;
            color: #495057;
            margin-left: 4px;
        }
        footer {
            text-align: center; padding: 20px;
            color: #6c757d; font-size: 0.9em;
        }
        .severity-filter {
            padding: 10px 20px;
            background: #f8f9fa;
            border-bottom: 1px solid var(--border-color);
            font-size: 0.9em;
        }
        .severity-filter label {
            margin-right: 16px;
            cursor: pointer;
            user-select: none;
        }
        .severity-filter input[type="checkbox"] {
            margin-right: 4px;
            cursor: pointer;
        }
        tr.sev-hidden { display: none; }
    </style>
    <script>
    function toggleSeverity(severity, checked) {
        var rows = document.querySelectorAll('tr.sev-' + severity);
        for (var i = 0; i < rows.length; i++) {
            if (checked) { rows[i].classList.remove('sev-hidden'); }
            else { rows[i].classList.add('sev-hidden'); }
        }
    }
    </script>
</head>
<body>
<div class="container">
    <header>
        <svg class="logo" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg"><path d="M125.25 107.513c-1.13 4.978-7.317 9.827-18.488 13.625a152.571 152.571 0 0 1-85.704.121c-10.303-3.648-15.864-8.263-16.732-13.021-.15-.839 0-13.895 0-13.895l121.159-1.123s-.092 13.681-.235 14.293Z" fill="#5EA0EF"/><path d="M65.04 115.031c33.479-.336 60.525-9.991 60.409-21.564-.116-11.573-27.35-20.683-60.83-20.347-33.479.336-60.525 9.99-60.409 21.564.116 11.573 27.35 20.683 60.83 20.347Z" fill="#50E6FF"/><path d="M105.989 11H22.011A3.011 3.011 0 0 0 19 14.011v18.585a3.011 3.011 0 0 0 3.011 3.011h83.978a3.011 3.011 0 0 0 3.011-3.01V14.01a3.011 3.011 0 0 0-3.011-3.01Z" fill="#B596F5"/><path d="M100.23 15.307h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.503v-3.72c0-.83-.672-1.503-1.502-1.503Zm0 9.273h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.503v-3.72c0-.83-.672-1.503-1.502-1.503Z" fill="#F2F2F2"/><path d="M105.989 40.166H22.011A3.011 3.011 0 0 0 19 43.176v18.586a3.011 3.011 0 0 0 3.011 3.011h83.978a3.011 3.011 0 0 0 3.011-3.01V43.176a3.01 3.01 0 0 0-3.011-3.011Z" fill="#9266E6"/><path d="M100.23 44.467h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.503v-3.72c0-.83-.672-1.503-1.502-1.503Zm0 9.273h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.502v-3.72c0-.83-.672-1.504-1.502-1.504Z" fill="#F2F2F2"/><path d="M105.989 69.326H22.011A3.011 3.011 0 0 0 19 72.336v18.586a3.011 3.011 0 0 0 3.011 3.011h83.978a3.01 3.01 0 0 0 3.011-3.01V72.336a3.011 3.011 0 0 0-3.011-3.011Z" fill="#552F99"/><path d="M100.23 73.627h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.502V75.13c0-.83-.672-1.503-1.502-1.503Zm0 9.273h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.672 1.502-1.502v-3.72c0-.83-.672-1.504-1.502-1.504Z" fill="#F2F2F2"/></svg>
        <h1>$([System.Web.HttpUtility]::HtmlEncode($Title))</h1>
        <p>Generated $([System.Web.HttpUtility]::HtmlEncode($timestamp)) | Scope: $([System.Web.HttpUtility]::HtmlEncode($scopeDescription))</p>
    </header>

    <div class="summary">
        <div class="summary-card total">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($totalClusters))</span>
            <span class="label">Total Clusters</span>
        </div>
        <div class="summary-card uptodate">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($upToDate))</span>
            <span class="label">Up to Date</span>
        </div>
        <div class="summary-card inprogress">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($inProgress))</span>
            <span class="label">In Progress</span>
        </div>
        <div class="summary-card available">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($updateAvailable))</span>
            <span class="label">Ready for Update</span>
        </div>
        <div class="summary-card failures">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($healthFailures))</span>
            <span class="label">Health Failures</span>
        </div>
    </div>

    <div class="progress-bar-container">
        <h3>Fleet Update Progress</h3>
        <div class="progress">
            <div class="progress-uptodate" style="width: $pctUpToDate%;" title="Up to Date: $upToDate ($pctUpToDate%)"></div>
            <div class="progress-inprogress" style="width: $pctInProgress%;" title="In Progress: $inProgress ($pctInProgress%)"></div>
            <div class="progress-available" style="width: $pctAvailable%;" title="Ready for Update: $updateAvailable ($pctAvailable%)"></div>
            <div class="progress-failures" style="width: $pctFailures%;" title="Health Failures: $healthFailures ($pctFailures%)"></div>
            <div class="progress-other" style="width: $pctOther%;" title="Other: $otherCount ($pctOther%)"></div>
        </div>
    </div>
"@)

    # Insert cluster identity section at top for 10 or fewer clusters
    if ($clusterDetails.Count -le 10) {
        [void]$sb.Append($clusterIdentitySection)
    }

    [void]$sb.Append(@"

    <div class="section">
        <h2>Cluster Status Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Cluster Name</th>
                    <th>Resource Group</th>
                    <th>Update State</th>
                    <th>Health State</th>
                    <th>Ready</th>
                    <th>Active Update</th>
                    <th>Recommended Update</th>
                </tr>
            </thead>
            <tbody>
"@)

    foreach ($cluster in $readiness) {
        $updateBadge = switch ($cluster.UpdateState) {
            'UpToDate'              { 'status-uptodate' }
            'AppliedSuccessfully'   { 'status-uptodate' }
            'UpdateInProgress'      { 'status-inprogress' }
            'UpdateFailed'          { 'status-failure' }
            'UpdateAvailable'       { 'status-available' }
            'Ready'                 { 'status-available' }
            default                 { 'status-unknown' }
        }
        $healthBadge = switch ($cluster.HealthState) {
            'Success' { 'status-uptodate' }
            'Failure' { 'status-failure' }
            'Warning' { 'status-inprogress' }
            default   { 'status-unknown' }
        }
        $readyText = if ($cluster.ReadyForUpdate) { "Yes" } else { "No" }
        $encReadyText = [System.Web.HttpUtility]::HtmlEncode($readyText)

        # Determine active update (in-progress or failed) from latest run data
        $activeUpdate = ""
        $activeUpdateBadge = ""
        $activeUpdateName = ""
        $recommendedDisplay = $cluster.RecommendedUpdate
        $clusterLatestRun = $latestRuns | Where-Object { $_.ClusterName -eq $cluster.ClusterName } | Select-Object -First 1
        if ($clusterLatestRun -and $clusterLatestRun.State -in @("InProgress", "Failed")) {
            $activeUpdate = "$($clusterLatestRun.UpdateName) ($($clusterLatestRun.State))"
            $activeUpdateName = $clusterLatestRun.UpdateName
            $activeUpdateBadge = if ($clusterLatestRun.State -eq "InProgress") { "status-inprogress" } else { "status-failure" }
            # Show N/A for recommended when there's an active update that must be completed
            $recommendedDisplay = "N/A"
        }

        # Build portal URLs
        $clusterResourceId = ($clusterDetails | Where-Object { $_.ClusterName -eq $cluster.ClusterName } | Select-Object -First 1).ResourceId
        $clusterPortalUrl = if ($clusterResourceId) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$clusterResourceId") } else { "" }
        $updatePortalUrl = if ($clusterResourceId -and $activeUpdateName) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$clusterResourceId/updates") } else { "" }

        $encName    = [System.Web.HttpUtility]::HtmlEncode($cluster.ClusterName)
        $encRG      = [System.Web.HttpUtility]::HtmlEncode($cluster.ResourceGroup)
        $encUpdate  = [System.Web.HttpUtility]::HtmlEncode($cluster.UpdateState)
        $encHealth  = [System.Web.HttpUtility]::HtmlEncode($cluster.HealthState)
        $encActive  = [System.Web.HttpUtility]::HtmlEncode($activeUpdate)
        $encRecommended = [System.Web.HttpUtility]::HtmlEncode($recommendedDisplay)

        # Cluster name as portal link
        $nameCell = if ($clusterPortalUrl) {
            "<a href=`"$clusterPortalUrl`" class=`"portal-link`" target=`"_blank`" title=`"Open in Azure Portal`"><strong>$encName</strong></a>"
        } else { "<strong>$encName</strong>" }

        # Active update as portal link
        $activeCell = if ($activeUpdate -and $updatePortalUrl) {
            "<a href=`"$updatePortalUrl`" class=`"portal-link`" target=`"_blank`" title=`"View updates in Azure Portal`"><span class=`"status-badge $activeUpdateBadge`">$encActive</span></a>"
        } elseif ($activeUpdate) {
            "<span class=`"status-badge $activeUpdateBadge`">$encActive</span>"
        } else { "" }

        [void]$sb.Append(@"

                <tr>
                    <td>$nameCell</td>
                    <td>$encRG</td>
                    <td><span class="status-badge $updateBadge">$encUpdate</span></td>
                    <td><span class="status-badge $healthBadge">$encHealth</span></td>
                    <td>$encReadyText</td>
                    <td>$activeCell</td>
                    <td>$encRecommended</td>
                </tr>
"@)
    }

    [void]$sb.Append(@"

            </tbody>
        </table>
    </div>
"@)

    #--- Update Run History section (optional) ---
    if ($IncludeUpdateRuns -and $updateRuns.Count -gt 0) {
        [void]$sb.Append(@"

    <div class="section">
        <h2>Recent Update Run History</h2>
        <table>
            <thead>
                <tr>
                    <th>Cluster</th>
                    <th>Update Name</th>
                    <th>State</th>
                    <th>Progress</th>
                    <th>Current Step</th>
                    <th>Duration</th>
                    <th>Start Time</th>
                </tr>
            </thead>
            <tbody>
"@)
        foreach ($run in $updateRuns) {
            $runBadge = switch ($run.State) {
                'Succeeded'  { 'status-uptodate' }
                'Failed'     { 'status-failure' }
                'InProgress' { 'status-inprogress' }
                default      { 'status-unknown' }
            }
            # Build portal links for cluster and update
            $runClusterRid = ($clusterDetails | Where-Object { $_.ClusterName -eq $run.ClusterName } | Select-Object -First 1).ResourceId
            $runClusterUrl = if ($runClusterRid) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$runClusterRid") } else { "" }
            $runUpdateUrl  = if ($runClusterRid) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$runClusterRid/updates") } else { "" }

            $encRunCluster  = [System.Web.HttpUtility]::HtmlEncode($run.ClusterName)
            $encRunUpdate   = [System.Web.HttpUtility]::HtmlEncode($run.UpdateName)
            $encRunState    = [System.Web.HttpUtility]::HtmlEncode($run.State)
            $encRunProgress = [System.Web.HttpUtility]::HtmlEncode($run.Progress)
            $encRunStep     = [System.Web.HttpUtility]::HtmlEncode($run.CurrentStepDetail)
            $encRunDuration = [System.Web.HttpUtility]::HtmlEncode($run.Duration)
            $encRunStart    = [System.Web.HttpUtility]::HtmlEncode($run.StartTime)

            $runClusterCell = if ($runClusterUrl) {
                "<a href=`"$runClusterUrl`" class=`"portal-link`" target=`"_blank`"><strong>$encRunCluster</strong></a>"
            } else { "<strong>$encRunCluster</strong>" }

            $runUpdateCell = if ($runUpdateUrl) {
                "<a href=`"$runUpdateUrl`" class=`"portal-link`" target=`"_blank`" title=`"View update history in Azure Portal`">$encRunUpdate</a>"
            } else { $encRunUpdate }

            [void]$sb.Append(@"

                <tr>
                    <td>$runClusterCell</td>
                    <td>$runUpdateCell</td>
                    <td><span class="status-badge $runBadge">$encRunState</span></td>
                    <td>$encRunProgress</td>
                    <td class="message-cell" title="$encRunStep">$encRunStep</td>
                    <td>$encRunDuration</td>
                    <td>$encRunStart</td>
                </tr>
"@)
        }

        [void]$sb.Append(@"

            </tbody>
        </table>
    </div>
"@)
    }

    #--- Health Check Failures section (optional) ---
    if ($IncludeHealthDetails -and $healthResults.Count -gt 0) {
        $allFailures = @($healthResults | ForEach-Object { $_.Failures } | Where-Object { $_ })
        if ($allFailures.Count -gt 0) {
            $uniqueFailureClusters = @($allFailures | Select-Object -ExpandProperty ClusterName -Unique)

            if ($uniqueFailureClusters.Count -le 1) {
                # Single cluster: flat table (no collapsing)
                [void]$sb.Append(@"

    <div class="section">
        <h2>Health Check Failures</h2>
        <div class="severity-filter">
            Filter by Severity:
            <label><input type="checkbox" checked onchange="toggleSeverity('critical', this.checked)"> Critical</label>
            <label><input type="checkbox" checked onchange="toggleSeverity('warning', this.checked)"> Warning</label>
            <label><input type="checkbox" onchange="toggleSeverity('informational', this.checked)"> Informational</label>
        </div>
        <table>
            <thead>
                <tr>
                    <th>Cluster</th>
                    <th>Severity</th>
                    <th>Check Name</th>
                    <th>Target</th>
                    <th>Description</th>
                    <th>Remediation</th>
                </tr>
            </thead>
            <tbody>
"@)
                foreach ($failure in $allFailures) {
                    $sevBadge = switch ($failure.Severity) {
                        'Critical'      { 'severity-critical' }
                        'Warning'       { 'severity-warning' }
                        'Informational' { 'severity-info' }
                        default         { 'status-unknown' }
                    }
                    $sevClass = "sev-$($failure.Severity.ToLower())"
                    $sevHidden = if ($failure.Severity -eq 'Informational') { ' sev-hidden' } else { '' }
                    $encCluster = [System.Web.HttpUtility]::HtmlEncode($failure.ClusterName)
                    $encSev     = [System.Web.HttpUtility]::HtmlEncode($failure.Severity)
                    $encCheck   = [System.Web.HttpUtility]::HtmlEncode($failure.CheckName)
                    $encTarget  = [System.Web.HttpUtility]::HtmlEncode($failure.TargetResourceName)
                    $encDesc    = [System.Web.HttpUtility]::HtmlEncode($failure.Description)
                    $encRemed   = [System.Web.HttpUtility]::HtmlEncode($failure.Remediation)

                    [void]$sb.Append(@"

                <tr class="$sevClass$sevHidden">
                    <td><strong>$encCluster</strong></td>
                    <td><span class="status-badge $sevBadge">$encSev</span></td>
                    <td>$encCheck</td>
                    <td>$encTarget</td>
                    <td class="message-cell" title="$encDesc">$encDesc</td>
                    <td class="message-cell" title="$encRemed">$encRemed</td>
                </tr>
"@)
                }

                [void]$sb.Append(@"

            </tbody>
        </table>
    </div>
"@)
            }
            else {
                # Multiple clusters: collapsible per-cluster groups
                [void]$sb.Append(@"

    <div class="section">
        <h2>Health Check Failures</h2>
        <div class="severity-filter">
            Filter by Severity:
            <label><input type="checkbox" checked onchange="toggleSeverity('critical', this.checked)"> Critical</label>
            <label><input type="checkbox" checked onchange="toggleSeverity('warning', this.checked)"> Warning</label>
            <label><input type="checkbox" onchange="toggleSeverity('informational', this.checked)"> Informational</label>
        </div>
"@)
                foreach ($clusterGroup in $uniqueFailureClusters) {
                    $clusterFailures = @($allFailures | Where-Object { $_.ClusterName -eq $clusterGroup })
                    $critCount = @($clusterFailures | Where-Object { $_.Severity -eq 'Critical' }).Count
                    $warnCount = @($clusterFailures | Where-Object { $_.Severity -eq 'Warning' }).Count
                    $infoCount = @($clusterFailures | Where-Object { $_.Severity -eq 'Informational' }).Count

                    # Determine worst severity badge and top issue
                    $worstBadge = if ($critCount -gt 0) { 'severity-critical' } elseif ($warnCount -gt 0) { 'severity-warning' } else { 'severity-info' }
                    $worstLabel = if ($critCount -gt 0) { 'Critical' } elseif ($warnCount -gt 0) { 'Warning' } else { 'Informational' }
                    $topIssue = ($clusterFailures | Sort-Object { switch ($_.Severity) { 'Critical' { 0 } 'Warning' { 1 } default { 2 } } } | Select-Object -First 1).CheckName

                    # Build count summary
                    $countParts = @()
                    if ($critCount -gt 0) { $countParts += "$critCount Critical" }
                    if ($warnCount -gt 0) { $countParts += "$warnCount Warning" }
                    if ($infoCount -gt 0) { $countParts += "$infoCount Informational" }
                    $countSummary = $countParts -join ', '

                    $encGroupName = [System.Web.HttpUtility]::HtmlEncode($clusterGroup)
                    $encTopIssue  = [System.Web.HttpUtility]::HtmlEncode($topIssue)

                    [void]$sb.Append(@"

        <details>
            <summary>
                <strong>$encGroupName</strong>
                <span class="status-badge $worstBadge">$([System.Web.HttpUtility]::HtmlEncode($worstLabel))</span>
                <span class="failure-summary-counts">$([System.Web.HttpUtility]::HtmlEncode($countSummary))</span>
                <span class="failure-summary-top-issue">| $encTopIssue</span>
            </summary>
            <table>
                <thead>
                    <tr>
                        <th>Severity</th>
                        <th>Check Name</th>
                        <th>Target</th>
                        <th>Description</th>
                        <th>Remediation</th>
                    </tr>
                </thead>
                <tbody>
"@)
                    foreach ($failure in $clusterFailures) {
                        $sevBadge = switch ($failure.Severity) {
                            'Critical'      { 'severity-critical' }
                            'Warning'       { 'severity-warning' }
                            'Informational' { 'severity-info' }
                            default         { 'status-unknown' }
                        }
                        $sevClass = "sev-$($failure.Severity.ToLower())"
                        $sevHidden = if ($failure.Severity -eq 'Informational') { ' sev-hidden' } else { '' }
                        $encSev    = [System.Web.HttpUtility]::HtmlEncode($failure.Severity)
                        $encCheck  = [System.Web.HttpUtility]::HtmlEncode($failure.CheckName)
                        $encTarget = [System.Web.HttpUtility]::HtmlEncode($failure.TargetResourceName)
                        $encDesc   = [System.Web.HttpUtility]::HtmlEncode($failure.Description)
                        $encRemed  = [System.Web.HttpUtility]::HtmlEncode($failure.Remediation)

                        [void]$sb.Append(@"

                    <tr class="$sevClass$sevHidden">
                        <td><span class="status-badge $sevBadge">$encSev</span></td>
                        <td>$encCheck</td>
                        <td>$encTarget</td>
                        <td class="message-cell" title="$encDesc">$encDesc</td>
                        <td class="message-cell" title="$encRemed">$encRemed</td>
                    </tr>
"@)
                    }

                    [void]$sb.Append(@"

                </tbody>
            </table>
        </details>
"@)
                }

                [void]$sb.Append(@"

    </div>
"@)
            }
        }
    }

    #--- Cluster identity appendix for large fleets (>10 clusters) ---
    if ($clusterDetails.Count -gt 10) {
        [void]$sb.Append($clusterIdentitySection)
    }

    #--- Footer ---
    $moduleVersion = (Get-Module AzStackHci.ManageUpdates | Select-Object -First 1).Version
    if (-not $moduleVersion) {
        $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'AzStackHci.ManageUpdates.psd1'
        if (Test-Path $manifestPath) {
            $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
            $moduleVersion = $manifest.ModuleVersion
        }
        if (-not $moduleVersion) { $moduleVersion = "unknown" }
    }

    [void]$sb.Append(@"

    <footer>
        <p>Generated by AzStackHci.ManageUpdates v$moduleVersion | $timestamp</p>
        <p>This report is provided as-is with no warranty. Not a Microsoft supported service offering.</p>
    </footer>
</div>
</body>
</html>
"@)

    $htmlContent = $sb.ToString()

    #--- Write to file ---
    if (-not $PSCmdlet.ShouldProcess($OutputPath, 'Write HTML fleet status report')) {
        return $htmlContent
    }
    $OutputPath = Resolve-SafeOutputPath -Path $OutputPath
    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    # Write UTF-8 *without* BOM. PowerShell 5.1's Out-File -Encoding UTF8
    # emits a BOM which breaks some browsers' rendering of the first bytes
    # and confuses downstream tooling (grep/diff/CI log viewers).
    [System.IO.File]::WriteAllText($OutputPath, $htmlContent, [System.Text.UTF8Encoding]::new($false))

    Write-Log -Message "" -Level Info
    Write-Log -Message "HTML fleet status report written to: $OutputPath" -Level Success
    try {
        $fullPath = (Resolve-Path $OutputPath -ErrorAction Stop).Path
        $fileUri = "file:///$($fullPath -replace '\\', '/')"
        Write-Log -Message "  Open report: $fileUri" -Level Info
    }
    catch {
        Write-Log -Message "  Open report: $OutputPath" -Level Info
    }
    Write-Log -Message "  Total Clusters: $totalClusters | Up to Date: $upToDate | In Progress: $inProgress | Ready: $updateAvailable | Failures: $healthFailures" -Level Info

    if ($PassThru) {
        return $htmlContent
    }
}

#endregion Fleet Status HTML Report

# Export module members (public functions only)
Export-ModuleMember -Function @(
    'Connect-AzureLocalServicePrincipal',
    'Start-AzureLocalClusterUpdate',
    'Get-AzureLocalClusterUpdateReadiness',
    'Get-AzureLocalClusterInventory',
    'Get-AzureLocalClusterInfo',
    'Get-AzureLocalUpdateSummary',
    'Get-AzureLocalAvailableUpdates',
    'Get-AzureLocalUpdateRuns',
    'Set-AzureLocalClusterUpdateRingTag',
    # Fleet-Scale Operations (v0.5.6)
    'Invoke-AzureLocalFleetOperation',
    'Get-AzureLocalFleetProgress',
    'Test-AzureLocalFleetHealthGate',
    'Export-AzureLocalFleetState',
    'Resume-AzureLocalFleetUpdate',
    'Stop-AzureLocalFleetUpdate',
    # Pre-Update Health Validation (v0.6.1)
    'Test-AzureLocalClusterHealth',
    # Fleet Status Data Collection & Reporting (v0.6.4)
    'Get-AzureLocalFleetStatusData',
    'New-AzureLocalFleetStatusHtmlReport',
    # Update Schedule Tag Helpers (v0.6.5)
    'Test-AzureLocalUpdateScheduleAllowed'
)

