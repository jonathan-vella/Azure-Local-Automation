Function Get-AzLocalParameterFilePath {
    <#
    .SYNOPSIS

    This function retrieves the parameters for the Azure Local deployment.

    .DESCRIPTION

    This function retrieves the parameters for the Azure Local deployment. It requires the following parameters:
    - TypeOfDeployment: The type of deployment.

    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,Position=0)]
        [ValidateSet("SingleNode","Switchless","MultiNode","RackAware")]
        [string]$TypeOfDeployment
    )

    # Prompt for Parameter File
    # ///// Parameter File Prompt
    
    $parameterFilesDirectory = Join-Path $script:ModuleRoot "template-parameter-files"

    $parameterFileMap = @{
        'SingleNode'  = 'single-node-parameters-file.json'
        'Switchless'  = 'switchless-parameters-file.json'
        'MultiNode'   = 'multi-node-switched-parameters-file.json'
        'RackAware'   = 'rack-aware-parameters-file.json'
    }
    $ParameterFile = Join-Path $parameterFilesDirectory $parameterFileMap[$TypeOfDeployment]

    # Check if the file exists
    if(-not(Test-Path $ParameterFile)) {
        Write-AzLocalLog "Parameter file not found at '$ParameterFile'." -Level Error
        throw "Parameter file not found at '$ParameterFile'."
    } else {
        # return the parameter file path
        Write-AzLocalLog "Copying template parameter for $TypeOfDeployment deployment from path '$ParameterFile'" -Level Success
        return $ParameterFile
    }

}
