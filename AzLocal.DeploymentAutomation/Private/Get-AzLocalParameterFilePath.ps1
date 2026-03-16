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
        [ValidateSet("SingleNode","StorageSwitchless","StorageSwitched","RackAware")]
        [string]$TypeOfDeployment,

        [Parameter(Mandatory = $false,Position=1)]
        [ValidateRange(1,16)]
        [int]$NodeCount = 2
    )

    # Prompt for Parameter File
    # ///// Parameter File Prompt
    
    $parameterFilesDirectory = Join-Path $script:ModuleRoot "template-parameter-files"

    # StorageSwitchless deployments have a per-node-count template (2x(N-1) storage networks)
    $switchlessFileMap = @{
        2 = 'storage-switchless-2node-parameters-file.json'
        3 = 'storage-switchless-3node-parameters-file.json'
        4 = 'storage-switchless-4node-parameters-file.json'
    }

    $parameterFileMap = @{
        'SingleNode'          = 'single-node-parameters-file.json'
        'StorageSwitchless'   = $switchlessFileMap[$NodeCount]
        'StorageSwitched'     = 'storage-switched-parameters-file.json'
        'RackAware'           = 'rack-aware-parameters-file.json'
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
