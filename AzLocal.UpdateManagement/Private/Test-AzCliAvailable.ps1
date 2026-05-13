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
            try { $installProcess.Kill() } catch { $null = $_ <# process may have just exited between WaitForExit and Kill; nothing to do #> }
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
