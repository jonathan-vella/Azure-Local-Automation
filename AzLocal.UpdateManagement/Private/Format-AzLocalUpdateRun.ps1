function Format-AzLocalUpdateRun {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param($run, $clusterName = "", $clusterResourceId = "")

    $props = $run.properties

    # Resolve EndTime once via the central helper (used for both display and Duration fallback).
    $endTimeDt = Get-AzLocalRunEndTime -props $props
    $endTimeDisplay = if ($endTimeDt) { $endTimeDt.ToString("yyyy-MM-dd HH:mm") } else { "" }

    # Duration: prefer ARM-reported properties.duration (ISO-8601, e.g. "PT8H37M58S")
    # because it's authoritative and immune to clock skew. Fall back to
    # EndTime - StartTime, then to "running" for in-flight runs.
    $duration = ""
    $durationSpan = $null
    if ($props.PSObject.Properties['duration'] -and $props.duration) {
        try { $durationSpan = [System.Xml.XmlConvert]::ToTimeSpan([string]$props.duration) } catch {}
    }
    if (-not $durationSpan -and $props.timeStarted -and $endTimeDt) {
        try { $durationSpan = $endTimeDt - [datetime]$props.timeStarted } catch {}
    }
    if ($durationSpan) {
        $duration = Format-AzLocalDurationHuman -Value $durationSpan
    }
    elseif ($props.timeStarted -and $props.state -eq "InProgress") {
        try {
            $runningSpan = (Get-Date) - [datetime]$props.timeStarted
            $human = Format-AzLocalDurationHuman -Value $runningSpan
            if ($human) { $duration = "$human (running)" }
        } catch {}
    }

    $currentStep = ""
    $currentStepDetail = ""
    $progress = ""
    if ($props.progress -and $props.progress.steps) {
        $steps = $props.progress.steps
        # Wrap in @() so .Count returns 0 (not $null) when no step matches â€” previously the
        # "completed" numerator rendered blank for runs that failed before any step succeeded.
        $completedSteps = @($steps | Where-Object { $_.status -eq "Success" }).Count
        $totalSteps = @($steps).Count
        $progress = "$completedSteps/$totalSteps steps"

        $inProgressStep = $steps | Where-Object { $_.status -eq "InProgress" } | Select-Object -First 1
        $failedStep = $steps | Where-Object { $_.status -in @("Error", "Failed") } | Select-Object -First 1

        if ($inProgressStep) {
            $currentStep = $inProgressStep.name
        }
        elseif ($failedStep) {
            $currentStep = "$($failedStep.name) (FAILED)"
        }

        $currentStepDetail = Get-CurrentStepPath -Steps $steps -IncludeErrorMessage
        if ([string]::IsNullOrWhiteSpace($currentStepDetail)) {
            $currentStepDetail = $currentStep
        }
        if ($currentStepDetail -match 'health check' -and $props.state -eq 'Failed') {
            if ($currentStepDetail -notmatch 'Critical health issues') {
                $currentStepDetail = "$currentStepDetail - Critical health issues must be resolved before updates can proceed"
            }
        }
    }

    $updateNameExtracted = ""
    $runId = ""
    if ($run.id -match '/updates/([^/]+)/updateRuns/([^/]+)$') {
        $updateNameExtracted = $matches[1]
        $runId = $matches[2]
    }
    elseif ($run.name -match '/([^/]+)$') {
        $runId = $matches[1]
    }
    else {
        $runId = $run.name
    }

    $result = [PSCustomObject]@{
        UpdateName        = $updateNameExtracted
        RunId             = $runId
        State             = $props.state
        StartTime         = if ($props.timeStarted) { ([datetime]$props.timeStarted).ToString("yyyy-MM-dd HH:mm") } else { "" }
        EndTime           = $endTimeDisplay
        Duration          = $duration
        Progress          = $progress
        CurrentStep       = $currentStep
        CurrentStepDetail = $currentStepDetail
        Location          = $props.location
    }

    if ($clusterName) {
        $result | Add-Member -NotePropertyName "ClusterName" -NotePropertyValue $clusterName -Force
    }

    if ($clusterResourceId) {
        $result | Add-Member -NotePropertyName "ClusterResourceId" -NotePropertyValue $clusterResourceId -Force
    }

    return $result
}
