Function Test-AzLocalResourceNames {
    <#
    .SYNOPSIS

    Validates all resolved Azure resource names against Azure naming rules.

    .DESCRIPTION

    Checks each resolved resource name against Azure naming constraints (maximum length,
    allowed characters, required prefixes) and throws an error if any name is invalid.
    This prevents deployment failures caused by invalid resource names.

    Azure resource naming rules enforced:
    - Storage Accounts: 3-24 chars, lowercase alphanumeric only (no hyphens/underscores)
    - Key Vaults: 3-24 chars, alphanumeric and hyphens, must start with a letter
    - Resource Groups: 1-90 chars, alphanumeric, hyphens, underscores, periods, parentheses
    - Cluster Name: 1-15 chars, alphanumeric only (NetBIOS computer name)
    - Node Names: 1-15 chars, alphanumeric only (NetBIOS computer name)
    - Custom Location: 1-63 chars, alphanumeric and hyphens
    - Resource Bridge: 1-63 chars, alphanumeric and hyphens
    - Deployment Name: 1-64 chars, alphanumeric, hyphens, underscores, periods

    .PARAMETER Names
    A hashtable of resource name label to resolved name value.

    #>

    [OutputType([void])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable]$Names
    )

    # Define Azure naming rules per resource type
    # Each rule: MaxLength, Pattern (regex of allowed chars), Description (for error messages)
    $rules = @{
        'ClusterName'                     = @{ MaxLength = 15;  Pattern = '^[a-zA-Z0-9]+$';                      Description = '1-15 chars, alphanumeric only (NetBIOS name)' }
        'ResourceGroupName'               = @{ MaxLength = 90;  Pattern = '^[a-zA-Z0-9\.\-_\(\)]+$';             Description = '1-90 chars, alphanumeric, hyphens, underscores, periods, parentheses' }
        'KeyVaultName'                    = @{ MaxLength = 24;  Pattern = '^[a-zA-Z][a-zA-Z0-9\-]+$';            Description = '3-24 chars, alphanumeric and hyphens, must start with a letter'; MinLength = 3 }
        'CustomLocation'                  = @{ MaxLength = 63;  Pattern = '^[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$'; Description = '1-63 chars, alphanumeric and hyphens, cannot start/end with hyphen' }
        'ResourceBridgeName'              = @{ MaxLength = 63;  Pattern = '^[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$'; Description = '1-63 chars, alphanumeric and hyphens, cannot start/end with hyphen' }
        'DiagnosticStorageAccountName'    = @{ MaxLength = 24;  Pattern = '^[a-z0-9]+$';                         Description = '3-24 chars, lowercase alphanumeric only (no hyphens or uppercase)'; MinLength = 3 }
        'ClusterWitnessStorageAccountName'= @{ MaxLength = 24;  Pattern = '^[a-z0-9]+$';                         Description = '3-24 chars, lowercase alphanumeric only (no hyphens or uppercase)'; MinLength = 3 }
        'NodeName'                        = @{ MaxLength = 15;  Pattern = '^[a-zA-Z0-9]+$';                      Description = '1-15 chars, alphanumeric only (NetBIOS name)' }
        'DeploymentName'                  = @{ MaxLength = 64;  Pattern = '^[a-zA-Z0-9\.\-_]+$';                 Description = '1-64 chars, alphanumeric, hyphens, underscores, periods' }
    }

    $errors = @()

    foreach ($entry in $Names.GetEnumerator()) {
        $label = $entry.Key
        $name = $entry.Value

        if ([string]::IsNullOrWhiteSpace($name)) {
            $errors += "  - $label : Name is empty or null."
            continue
        }

        # Determine which rule to apply based on the label
        $ruleKey = $null
        switch -Wildcard ($label) {
            'ClusterName'                         { $ruleKey = 'ClusterName' }
            'ResourceGroupName'                   { $ruleKey = 'ResourceGroupName' }
            'KeyVaultName'                        { $ruleKey = 'KeyVaultName' }
            'CustomLocation'                      { $ruleKey = 'CustomLocation' }
            'ResourceBridgeName'                  { $ruleKey = 'ResourceBridgeName' }
            'DiagnosticStorageAccountName'         { $ruleKey = 'DiagnosticStorageAccountName' }
            'ClusterWitnessStorageAccountName'    { $ruleKey = 'ClusterWitnessStorageAccountName' }
            'NodeName*'                           { $ruleKey = 'NodeName' }
            'DeploymentName'                      { $ruleKey = 'DeploymentName' }
            default                               { continue }
        }

        $rule = $rules[$ruleKey]

        # Check minimum length
        $minLen = if ($rule.ContainsKey('MinLength')) { $rule.MinLength } else { 1 }
        if ($name.Length -lt $minLen) {
            $errors += "  - $label = '$name' ($($name.Length) chars): Too short. $($rule.Description)"
        }

        # Check maximum length
        if ($name.Length -gt $rule.MaxLength) {
            $errors += "  - $label = '$name' ($($name.Length) chars): Exceeds maximum of $($rule.MaxLength) characters. $($rule.Description)"
        }

        # Check allowed characters (case-sensitive match to enforce lowercase-only rules like storage accounts)
        if ($name -cnotmatch $rule.Pattern) {
            $errors += "  - $label = '$name': Contains invalid characters. $($rule.Description)"
        }
    }

    if ($errors.Count -gt 0) {
        $errorMessage = "Resource name validation failed:`n" + ($errors -join "`n")
        Write-AzLocalLog $errorMessage -Level Error
        Write-AzLocalLog "Adjust the naming patterns in .config/naming-standards-config.json or use a shorter/valid UniqueID." -Level Warning
        throw $errorMessage
    }

    Write-Verbose "All resource names passed Azure naming validation."
}
