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
            throw "-ServicePrincipalSecret must be a [string] or [SecureString]. Got: $($ServicePrincipalSecret.GetType().FullName)"
        }
        else {
            $clientSecretPlain = $env:AZURE_CLIENT_SECRET
        }

        $tenant = if ($TenantId) { $TenantId } else { $env:AZURE_TENANT_ID }

        # Validate required credentials
        if (-not $clientId) {
            throw "Service Principal ID not provided. Set -ServicePrincipalId parameter or AZURE_CLIENT_ID environment variable."
        }
        if (-not $clientSecretPlain) {
            throw "Service Principal Secret not provided. Set -ServicePrincipalSecret parameter or AZURE_CLIENT_SECRET environment variable."
        }
        if (-not $tenant) {
            throw "Tenant ID not provided. Set -TenantId parameter or AZURE_TENANT_ID environment variable."
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
