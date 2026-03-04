Function Import-AzLocalDeploymentCsv {
    <#
    .SYNOPSIS

    Reads and validates a cluster deployment CSV file.

    .DESCRIPTION

    Imports a CSV file containing cluster deployment definitions and validates that all
    required columns are present and row values are well-formed. Returns an array of
    PSCustomObjects, optionally filtered to rows where ReadyToDeploy is TRUE.

    Required CSV columns:
    UniqueID, ReadyToDeploy, SubscriptionId, TenantId, TypeOfDeployment, NodeCount,
    CredentialKeyVaultName, SubnetMask, DefaultGateway, StartingIPAddress, EndingIPAddress,
    NodeIPAddresses

    Optional columns (fall back to naming-standards-config.json defaults):
    Location, DnsServers, LocalAdminSecretName, LCMAdminSecretName

    .PARAMETER CsvFilePath
    Path to the CSV file.

    .PARAMETER ReadyOnly
    If specified, returns only rows where ReadyToDeploy is TRUE.

    #>

    [OutputType([PSCustomObject[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CsvFilePath,

        [Parameter(Mandatory = $false)]
        [switch]$ReadyOnly
    )

    if (-not (Test-Path $CsvFilePath)) {
        Write-AzLocalLog "CSV file not found: '$CsvFilePath'." -Level Error
        throw "CSV file not found: '$CsvFilePath'."
    }

    try {
        $csvData = @(Import-Csv -Path $CsvFilePath -ErrorAction Stop)
    } catch {
        Write-AzLocalLog "Failed to parse CSV file '$CsvFilePath'." -Level Error
        throw "Failed to parse CSV file '$CsvFilePath'. $($_.Exception.Message)"
    }

    if ($csvData.Count -eq 0) {
        Write-AzLocalLog "CSV file '$CsvFilePath' contains no data rows." -Level Error
        throw "CSV file '$CsvFilePath' contains no data rows."
    }

    # Validate required columns
    $requiredColumns = @(
        'UniqueID', 'ReadyToDeploy', 'SubscriptionId', 'TenantId',
        'TypeOfDeployment', 'NodeCount', 'CredentialKeyVaultName',
        'SubnetMask', 'DefaultGateway', 'StartingIPAddress', 'EndingIPAddress',
        'NodeIPAddresses'
    )
    $presentColumns = $csvData[0].PSObject.Properties.Name
    $missingColumns = @($requiredColumns | Where-Object { $_ -notin $presentColumns })
    if ($missingColumns.Count -gt 0) {
        $missingList = $missingColumns -join ', '
        Write-AzLocalLog "CSV file is missing required columns: $missingList" -Level Error
        throw "CSV file is missing required columns: $missingList"
    }

    # Validate each row
    $errors = @()
    $validTypes = @('SingleNode', 'StorageSwitchless', 'StorageSwitched', 'RackAware')
    $rowNum = 1
    foreach ($row in $csvData) {
        $rowNum++
        $uid = $row.UniqueID

        # UniqueID validation
        if ([string]::IsNullOrWhiteSpace($uid)) {
            $errors += "Row ${rowNum}: UniqueID is empty."
        } elseif ($uid -notmatch '^[a-zA-Z0-9]{2,8}$') {
            $errors += "Row $rowNum (UniqueID=$uid): UniqueID must be 2-8 alphanumeric characters."
        }

        # ReadyToDeploy validation (PowerShell -notin is case-insensitive)
        if ($row.ReadyToDeploy -notin @('TRUE', 'FALSE')) {
            $errors += "Row $rowNum (UniqueID=$uid): ReadyToDeploy must be TRUE or FALSE."
        }

        # GUID validation
        $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
        if ($row.SubscriptionId -notmatch $guidPattern) {
            $errors += "Row $rowNum (UniqueID=$uid): SubscriptionId is not a valid GUID."
        }
        if ($row.TenantId -notmatch $guidPattern) {
            $errors += "Row $rowNum (UniqueID=$uid): TenantId is not a valid GUID."
        }

        # TypeOfDeployment validation
        if ($row.TypeOfDeployment -notin $validTypes) {
            $errors += "Row $rowNum (UniqueID=$uid): TypeOfDeployment must be one of: $($validTypes -join ', ')."
        }

        # NodeCount validation
        $nodeCount = 0
        if (-not [int]::TryParse($row.NodeCount, [ref]$nodeCount)) {
            $errors += "Row $rowNum (UniqueID=$uid): NodeCount must be an integer."
        }

        # IP address fields validation
        foreach ($ipField in @('SubnetMask', 'DefaultGateway', 'StartingIPAddress', 'EndingIPAddress')) {
            $ipVal = $row.$ipField
            if (-not [string]::IsNullOrWhiteSpace($ipVal)) {
                try { [System.Net.IPAddress]::Parse($ipVal) | Out-Null } catch {
                    $errors += "Row $rowNum (UniqueID=$uid): $ipField '$ipVal' is not a valid IP address."
                }
            }
        }

        # NodeIPAddresses validation (semicolon-separated)
        if (-not [string]::IsNullOrWhiteSpace($row.NodeIPAddresses)) {
            $nodeIPs = $row.NodeIPAddresses -split ';'
            $validNodeIPs = @()
            foreach ($nip in $nodeIPs) {
                $nip = $nip.Trim()
                if ($nip -ne '') {
                    try { [System.Net.IPAddress]::Parse($nip) | Out-Null; $validNodeIPs += $nip } catch {
                        $errors += "Row $rowNum (UniqueID=$uid): NodeIPAddress '$nip' is not a valid IP address."
                    }
                }
            }

            # Validate NodeIPAddresses count matches NodeCount
            $expectedCount = if ($row.TypeOfDeployment -eq 'SingleNode') { 1 } else { $nodeCount }
            if ($nodeCount -gt 0 -and $validNodeIPs.Count -ne $expectedCount) {
                $errors += "Row $rowNum (UniqueID=$uid): NodeIPAddresses count ($($validNodeIPs.Count)) does not match expected node count ($expectedCount)."
            }
        }
    }

    if ($errors.Count -gt 0) {
        $errorMessage = "CSV validation failed with $($errors.Count) error(s):`n" + ($errors -join "`n")
        Write-AzLocalLog $errorMessage -Level Error
        throw $errorMessage
    }

    Write-AzLocalLog "CSV file validated successfully: $($csvData.Count) row(s) found." -Level Success

    if ($ReadyOnly) {
        $csvData = @($csvData | Where-Object { $_.ReadyToDeploy -eq 'TRUE' })
        Write-AzLocalLog "Filtered to $($csvData.Count) row(s) with ReadyToDeploy = TRUE." -Level Info
    }

    return $csvData
}
