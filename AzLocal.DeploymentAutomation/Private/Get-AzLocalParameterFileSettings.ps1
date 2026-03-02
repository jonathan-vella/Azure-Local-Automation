Function Get-AzLocalParameterFileSettings {
    <#
    .SYNOPSIS

    This function loads the parameters for the Azure Local deployment.

    .DESCRIPTION

    This function loads the parameters for the Azure Local deployment. It requires the following parameters:
    - ParameterFilePath: The path to the parameter file.

    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,Position=0)]
        [string]$ParameterFilePath
    )

    # Load and parse the JSON file
    try {
        $ParameterFileSettings = Get-Content $ParameterFilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-AzLocalLog "Failed to load or parse parameter file '$ParameterFilePath'." -Level Error
        throw "Failed to load parameter file '$ParameterFilePath'. $($_.Exception.Message)"
    }
    Write-Verbose "Parameter file settings loaded from '$ParameterFilePath'."

    return $ParameterFileSettings
        
}
