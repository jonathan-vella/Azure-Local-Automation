function Get-CurrentStepPath {
    <#
    .SYNOPSIS
        Recursively walks the update run step hierarchy to find the deepest InProgress or Failed step.
    .DESCRIPTION
        Update runs can have steps nested up to 8-9 levels deep. This function traverses
        the step.steps children recursively and returns the full path (e.g., "Step1 > Step2 > Step3").
        Looks for InProgress or Error/Failed status, returning the deepest match.
        Also captures the errorMessage from the deepest failed step if available.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [array]$Steps,

        [Parameter(Mandatory = $false)]
        [string]$ParentPath = "",

        [Parameter(Mandatory = $false)]
        [switch]$IncludeErrorMessage,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 20
    )

    if (-not $Steps -or $Steps.Count -eq 0 -or $MaxDepth -le 0) { return "" }

    foreach ($step in $Steps) {
        if (-not $step.name) { continue }
        $currentPath = if ($ParentPath) { "$ParentPath > $($step.name)" } else { $step.name }

        if ($step.status -in @("InProgress", "Error", "Failed")) {
            # Check if there are deeper nested steps with the same status
            if ($step.steps -and $step.steps.Count -gt 0) {
                $deeper = Get-CurrentStepPath -Steps $step.steps -ParentPath $currentPath -IncludeErrorMessage:$IncludeErrorMessage -MaxDepth ($MaxDepth - 1)
                if ($deeper) { return $deeper }
            }
            # At the deepest level - append error message if requested and available
            if ($IncludeErrorMessage -and $step.errorMessage) {
                return "$currentPath : $($step.errorMessage)"
            }
            return $currentPath
        }
    }
    return ""
}
