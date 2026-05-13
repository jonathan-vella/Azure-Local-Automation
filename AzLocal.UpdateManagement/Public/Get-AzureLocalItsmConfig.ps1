function Get-AzureLocalItsmConfig {
    <#
    .SYNOPSIS
        Loads and validates the AzLocal.UpdateManagement ITSM connector config.

    .DESCRIPTION
        Reads a YAML (.yml / .yaml) or JSON (.json) configuration file and
        returns a strongly typed config object suitable for hand-off to
        New-AzureLocalIncident, Test-AzureLocalItsmConnection, and (in
        Phase 2) Sync-AzureLocalIncident.

        YAML parsing requires the 'powershell-yaml' module. If the input is
        YAML but the module is not available, an actionable error is thrown.
        JSON works on stock PowerShell 5.1+.

        Validation enforces:
          - schemaVersion = 1
          - secrets.source in (keyvault, envvar, mixed)
          - defaults.itsmTarget = ServiceNow (v0.7.4 supports SN only)
          - At least one trigger with raiseTicket: true
          - Severity values in 1..5

        See AzLocal.UpdateManagement/Docs/ITSM-Connector-Plan.md Section 5
        and Docs/ITSM-Config-Reference.md for the full schema.

    .EXAMPLE
        $cfg = Get-AzureLocalItsmConfig -Path ./.itsm/azurelocal-itsm.yml
        $cfg.Triggers['Failed'].Severity
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "ITSM config file not found: $Path"
    }

    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    $raw = Get-Content -Path $Path -Raw

    switch ($ext) {
        '.json' {
            try {
                $data = $raw | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                throw "Failed to parse JSON config '$Path': $($_.Exception.Message)"
            }
            $config = ConvertTo-AzLocalItsmConfigHashtable -InputObject $data
        }
        { $_ -in '.yml','.yaml' } {
            if (-not (Get-Module -Name powershell-yaml -ListAvailable)) {
                throw "YAML config '$Path' requires the 'powershell-yaml' module. Install with: Install-Module powershell-yaml -Scope CurrentUser"
            }
            Import-Module powershell-yaml -ErrorAction Stop
            try {
                $config = ConvertFrom-Yaml -Yaml $raw -Ordered:$false
            }
            catch {
                throw "Failed to parse YAML config '$Path': $($_.Exception.Message)"
            }
        }
        default {
            throw "Unsupported ITSM config file extension '$ext'. Use .yml, .yaml, or .json."
        }
    }

    if (-not $config -or -not ($config -is [hashtable] -or $config -is [System.Collections.IDictionary])) {
        throw "ITSM config '$Path' did not parse to a dictionary."
    }

    Test-AzLocalItsmConfigShape -Config $config -SourcePath $Path

    # Surface a normalised object with case-stable property names.
    $secrets   = $config['secrets']
    $defaults  = $config['defaults']
    $triggers  = $config['triggers']
    $lifecycle = $config['lifecycle']
    $mirror    = $config['mirror']
    $storage   = $config['storage']

    $normalisedTriggers = @{}
    foreach ($key in $triggers.Keys) {
        $entry = $triggers[$key]
        if (-not $entry) { continue }
        $normalisedTriggers[$key] = @{
            RaiseTicket = [bool]($entry['raiseTicket'])
            Severity    = if ($entry.ContainsKey('severity')) { [int]$entry['severity'] } else { 3 }
            Category    = if ($entry.ContainsKey('category')) { [string]$entry['category'] } else { $null }
            MirrorTo    = if ($entry.ContainsKey('mirrorTo')) { @($entry['mirrorTo']) } else { $null }
        }
    }

    return [pscustomobject]@{
        SchemaVersion = [int]$config['schemaVersion']
        SourcePath    = (Resolve-Path -Path $Path).Path
        Secrets       = $secrets
        Defaults      = $defaults
        Triggers      = $normalisedTriggers
        Lifecycle     = $lifecycle
        Mirror        = $mirror
        Storage       = $storage
        Raw           = $config
    }
}

function ConvertTo-AzLocalItsmConfigHashtable {
    <#
    .SYNOPSIS
        Converts a ConvertFrom-Json pscustomobject tree into a hashtable tree
        so callers can use [hashtable]/.ContainsKey() uniformly with YAML.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$InputObject
    )

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $ht = @{}
        foreach ($k in $InputObject.Keys) {
            $ht[[string]$k] = ConvertTo-AzLocalItsmConfigHashtable -InputObject $InputObject[$k]
        }
        return $ht
    }

    if ($InputObject -is [pscustomobject]) {
        $ht = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $ht[$prop.Name] = ConvertTo-AzLocalItsmConfigHashtable -InputObject $prop.Value
        }
        return $ht
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $list = @()
        foreach ($item in $InputObject) {
            $list += ,(ConvertTo-AzLocalItsmConfigHashtable -InputObject $item)
        }
        return ,$list
    }

    return $InputObject
}

function Test-AzLocalItsmConfigShape {
    <#
    .SYNOPSIS
        Validates the shape of a parsed ITSM config hashtable. Throws on error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )

    if (-not $Config.ContainsKey('schemaVersion')) {
        throw "ITSM config '$SourcePath' missing required field 'schemaVersion'."
    }
    if ([int]$Config['schemaVersion'] -ne 1) {
        throw "ITSM config '$SourcePath' schemaVersion is $($Config['schemaVersion']); this module supports schemaVersion: 1."
    }

    foreach ($required in 'secrets','defaults','triggers') {
        if (-not $Config.ContainsKey($required)) {
            throw "ITSM config '$SourcePath' missing required top-level section '$required'."
        }
    }

    $allowedSources = 'keyvault','envvar','mixed'
    $src = [string]$Config['secrets']['source']
    if ($src -notin $allowedSources) {
        throw "ITSM config '$SourcePath' secrets.source='$src' is invalid. Use one of: $($allowedSources -join ', ')."
    }
    if ($src -eq 'keyvault' -and [string]::IsNullOrWhiteSpace([string]$Config['secrets']['keyvaultName'])) {
        throw "ITSM config '$SourcePath' secrets.source=keyvault but secrets.keyvaultName is not set."
    }

    $target = [string]$Config['defaults']['itsmTarget']
    if ($target -ne 'ServiceNow') {
        throw "ITSM config '$SourcePath' defaults.itsmTarget='$target' is not supported in v0.7.4. Only 'ServiceNow' is supported."
    }

    $hasAtLeastOneRaise = $false
    foreach ($key in $Config['triggers'].Keys) {
        $entry = $Config['triggers'][$key]
        if (-not $entry) { continue }
        if ($entry['raiseTicket']) { $hasAtLeastOneRaise = $true }
        if ($entry.ContainsKey('severity')) {
            $sev = [int]$entry['severity']
            if ($sev -lt 1 -or $sev -gt 5) {
                throw "ITSM config '$SourcePath' triggers.$key.severity=$sev is out of range. Use 1..5."
            }
        }
    }

    if (-not $hasAtLeastOneRaise) {
        Write-Warning "ITSM config '$SourcePath' has no triggers with raiseTicket=true. No tickets will be raised."
    }
}
