Function Resolve-AzLocalResourceName {
    <#
    .SYNOPSIS

    Resolves a resource name by replacing placeholders in a naming pattern.

    .DESCRIPTION

    Takes a naming pattern from the configuration file and replaces placeholders with actual values:
    - {UniqueID} is replaced with the provided UniqueID value.
    - {NodeNumber} is replaced with a zero-padded (2-digit) node number.
    - {TypeOfDeployment} is replaced with the deployment type string.

    .PARAMETER Pattern
    The naming pattern string containing placeholders.

    .PARAMETER UniqueID
    The unique identifier to substitute into the pattern.

    .PARAMETER NodeNumber
    Optional. The node number (integer) to substitute. Will be zero-padded to 2 digits.

    .PARAMETER TypeOfDeployment
    Optional. The deployment type string to substitute.

    #>

    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Pattern,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$UniqueID,

        [Parameter(Mandatory = $false)]
        [int]$NodeNumber = 0,

        [Parameter(Mandatory = $false)]
        [string]$TypeOfDeployment = ""
    )

    $result = $Pattern -replace '\{UniqueID\}', $UniqueID

    if ($NodeNumber -gt 0) {
        $paddedNodeNumber = $NodeNumber.ToString("D2")
        $result = $result -replace '\{NodeNumber\}', $paddedNodeNumber
    }

    if ($TypeOfDeployment -ne "") {
        $result = $result -replace '\{TypeOfDeployment\}', $TypeOfDeployment
    }

    return $result
}
