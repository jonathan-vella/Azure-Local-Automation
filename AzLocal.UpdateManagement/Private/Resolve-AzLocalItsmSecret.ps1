function Resolve-AzLocalItsmSecret {
    <#
    .SYNOPSIS
        Resolves an ITSM secret reference to a plaintext value.

    .DESCRIPTION
        Accepts a secret reference in one of these forms and returns the
        resolved plaintext string (the caller is responsible for handling
        the result securely):
          - 'kv://<vault>/<secret>' -- Azure Key Vault, current Az session
          - 'env://<NAME>'          -- environment variable
          - '<bareName>'            -- when -DefaultKeyVault is supplied, the
                                       bare name is resolved as a Key Vault
                                       secret in that vault
          - 'literal://<value>'     -- explicit literal (only when -AllowLiteral
                                       is passed; defends against accidental
                                       in-config secrets)
        Designed for the AzLocal.UpdateManagement ITSM connector.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Reference,

        [Parameter(Mandatory = $false)]
        [string]$DefaultKeyVault,

        [Parameter(Mandatory = $false)]
        [switch]$AllowLiteral
    )

    if ($Reference -match '^kv://([^/]+)/(.+)$') {
        $vault  = $Matches[1]
        $secret = $Matches[2]
        return Get-AzKeyVaultSecretPlainText -VaultName $vault -SecretName $secret
    }

    if ($Reference -match '^env://(.+)$') {
        $envName = $Matches[1]
        $value = [Environment]::GetEnvironmentVariable($envName)
        if ([string]::IsNullOrEmpty($value)) {
            throw "ITSM secret reference '$Reference' resolved to an empty environment variable. Set `$env:$envName before running."
        }
        return $value
    }

    if ($Reference -match '^literal://(.*)$') {
        if (-not $AllowLiteral) {
            throw "ITSM secret reference uses 'literal://' but -AllowLiteral was not specified. Refusing to treat config-embedded literal as a secret."
        }
        return $Matches[1]
    }

    if ($Reference -match '^[A-Za-z0-9._-]+$') {
        if (-not $DefaultKeyVault) {
            throw "ITSM secret reference '$Reference' is a bare name but no DefaultKeyVault was provided. Use 'kv://<vault>/<secret>' or 'env://<NAME>' instead."
        }
        return Get-AzKeyVaultSecretPlainText -VaultName $DefaultKeyVault -SecretName $Reference
    }

    throw "ITSM secret reference '$Reference' is not a recognised form. Use 'kv://<vault>/<secret>', 'env://<NAME>', or a bare secret name with -DefaultKeyVault."
}

function Get-AzKeyVaultSecretPlainText {
    <#
    .SYNOPSIS
        Thin wrapper around Get-AzKeyVaultSecret -AsPlainText that exists
        so the parent function can be unit-tested by mocking just this call.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$VaultName,
        [Parameter(Mandatory = $true)][string]$SecretName
    )

    if (-not (Get-Command Get-AzKeyVaultSecret -ErrorAction SilentlyContinue)) {
        throw "Az.KeyVault module is not loaded. Install with: Install-Module Az.KeyVault -Scope CurrentUser"
    }

    try {
        $value = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText -ErrorAction Stop
    }
    catch {
        throw "Failed to read Key Vault secret '$SecretName' from vault '$VaultName': $($_.Exception.Message)"
    }

    if ([string]::IsNullOrEmpty($value)) {
        throw "Key Vault secret '$VaultName/$SecretName' resolved to an empty value."
    }

    return $value
}
