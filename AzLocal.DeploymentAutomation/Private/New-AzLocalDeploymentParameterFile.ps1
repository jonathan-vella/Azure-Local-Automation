Function New-AzLocalDeploymentParameterFile {
    <#
    .SYNOPSIS

    This function updates the parameters for the Azure Local deployment and saves them to a file.

    .DESCRIPTION

    This function updates the parameters for the Azure Local deployment. It requires the following parameters:
    - UniqueID: The unique identifier for the deployment.
    - TypeOfDeployment: The type of deployment to perform (e.g., SingleNode, MultiNode, Switchless, RackAware).
    - ParameterFileSettings: The settings for the parameter file.
    - Parameters: The parameters for the deployment.

    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,Position=0)]
        [string]$UniqueID,

        [Parameter(Mandatory = $true,Position=1)]
        [ValidateSet("SingleNode","Switchless","MultiNode","RackAware")]
        [string]$TypeOfDeployment,

        [Parameter(Mandatory = $true,Position=2)]
        [PsCustomObject]$ParameterFileSettings,

        [Parameter(Mandatory = $true,Position=3)]
        [PsCustomObject]$Parameters
    )

    
    # Parameter file path
    $OutputDirectory = Join-Path $script:ModuleRoot "deployment-parameter-files"
    $parameterFileMap = @{
        'SingleNode'  = 'single-node-parameters-file.json'
        'Switchless'  = 'switchless-parameters-file.json'
        'MultiNode'   = 'multi-node-switched-parameters-file.json'
        'RackAware'   = 'rack-aware-parameters-file.json'
    }
    $DeploymentParameterFilePath = Join-Path $OutputDirectory "$($UniqueID)-$($parameterFileMap[$TypeOfDeployment])"
    # Check if the directory exists, if not create it
    if(-not(Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }

    # Update $ParameterFileSettings with the new values from $Parameters
    # Loop through the parameters in the parameter file settings
    ForEach($DeploymentParameter in $ParameterFileSettings.parameters) {

        ForEach ($property in ($DeploymentParameter.PSObject.Properties)) {

            # Check if the property name matches an entry in the parameters variable
            # If it does, update the value in the parameter file settings
            if($Parameters.$($property.Name)) {
                Write-Debug "Updating $($property.Name) value to parameter value = $($Parameters.$($property.Name))"
                $property.Value = $Parameters.$($property.Name)
            } else {
                # no match, do nothing
                Write-Debug "No match for $($property.Name) in parameters variable."
            }
        }
    }

    # Convert the updated parameter file settings back to JSON
    $UpdateParameterFileJSON = $ParameterFileSettings | ConvertTo-Json -Depth 100 | Format-Json

    # Save the updated JSON to the specified file
    try{
        $UpdateParameterFileJSON | Out-File -FilePath $DeploymentParameterFilePath -Encoding utf8 -ErrorAction Stop -Force
        Write-AzLocalLog "Deployment parameter file created at $DeploymentParameterFilePath" -Level Success
    } catch {
        Write-AzLocalLog "Error writing to file: $DeploymentParameterFilePath" -Level Error
        throw "Failed to write deployment parameter file '$DeploymentParameterFilePath'. $($_.Exception.Message)"
    }

    return $DeploymentParameterFilePath
}
