Function Get-ValidUniqueID {
    <#
    .SYNOPSIS

    This function asks for and validates a Unique ID for the deployment.

    .DESCRIPTION

    This function prompts for a Unique ID (e.g., store number, site code, or location identifier)
    and validates it is a non-empty alphanumeric string (2-8 characters).
    Returns the Unique ID if valid, or throws an error if invalid.

    #>

    # Prompt for Unique ID
    [string]$UniqueID = Read-Host "`nPlease enter the Unique ID for the new deployment (e.g., store number, site code - 2 to 8 alphanumeric characters)" -ErrorAction Stop
    
    # Validation
    if([string]::IsNullOrWhiteSpace($UniqueID)) {
        Write-AzLocalLog "Null Unique ID - This is a mandatory requirement." -Level Error
        throw "Unique ID is required and cannot be empty."
    } elseif ($UniqueID -match "^[a-zA-Z0-9]{2,8}$") {
        Write-AzLocalLog "Unique ID '$UniqueID' is valid." -Level Success
    } else {
        Write-AzLocalLog "Invalid: Unique ID must be 2-8 alphanumeric characters (letters and numbers only)." -Level Error
        throw "Invalid Unique ID '$UniqueID'. Must be 2-8 alphanumeric characters."
    }

    return $UniqueID
}
