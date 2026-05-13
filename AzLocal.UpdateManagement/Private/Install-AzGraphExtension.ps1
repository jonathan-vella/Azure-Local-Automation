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
