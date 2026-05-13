function Invoke-FleetJobsInParallel {
    <#
    .SYNOPSIS
        Dispatches a scriptblock across a set of input items using Start-Job
        with a throttled batch model. Intended as the single parallelisation
        primitive used by fleet-wide functions in this module.
    .DESCRIPTION
        Items are divided into at most -ThrottleLimit batches. Each batch runs
        as one Start-Job so that per-job startup cost stays low for large
        fleets. When -ThrottleLimit is 1 the scriptblock is invoked inline
        (no Start-Job overhead) which is the fast path used by unit tests.

        The scriptblock receives positional arguments in the order:
            [object[]]$Batch, <ArgumentList...>, [string]$ModulePath

        The trailing $ModulePath is always appended so jobs can re-import
        the module with 'Import-Module $ModulePath -Force' before calling
        any exported function.
    .PARAMETER InputItems
        The collection of items to shard across batches. Empty collections
        return an empty [object[]] result.
    .PARAMETER ScriptBlock
        The scriptblock executed once per batch.
    .PARAMETER ThrottleLimit
        Maximum number of concurrent Start-Job instances. Defaults to 4.
        ThrottleLimit=1 triggers the inline fast-path.
    .PARAMETER ArgumentList
        Additional positional arguments forwarded to the scriptblock after
        $Batch and before the trailing $ModulePath.
    .PARAMETER JobTimeoutSeconds
        Per-job maximum wall-clock wait. Defaults to 30 minutes. Jobs that
        exceed this are stopped and reported as Failed with a timeout error.
    .PARAMETER ActivityName
        Prefix used to name the jobs (helpful when debugging with Get-Job).
    .OUTPUTS
        [object[]] of [PSCustomObject]@{
            BatchIndex; Items; Failed; Output; Error; DurationSeconds
        }
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$InputItems,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 32)]
        [int]$ThrottleLimit = 4,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [object[]]$ArgumentList = @(),

        [Parameter(Mandatory = $false)]
        [ValidateRange(30, 86400)]
        [int]$JobTimeoutSeconds = 1800,

        [Parameter(Mandatory = $false)]
        [string]$ActivityName = 'FleetJob'
    )

    $results = [System.Collections.Generic.List[object]]::new()

    if ($null -eq $InputItems -or $InputItems.Count -eq 0) {
        return , $results.ToArray()
    }

    $modulePath = $PSCommandPath

    if ($ThrottleLimit -le 1) {
        # Inline fast-path: run the whole batch in-process, no Start-Job.
        $allArgs = @(, [object[]]$InputItems) + $ArgumentList + @($modulePath)
        $started = Get-Date
        try {
            $out = & $ScriptBlock @allArgs
            [void]$results.Add([PSCustomObject]@{
                BatchIndex      = 0
                Items           = $InputItems
                Failed          = $false
                Output          = $out
                Error           = $null
                DurationSeconds = ((Get-Date) - $started).TotalSeconds
            })
        }
        catch {
            [void]$results.Add([PSCustomObject]@{
                BatchIndex      = 0
                Items           = $InputItems
                Failed          = $true
                Output          = $null
                Error           = $_.Exception.Message
                DurationSeconds = ((Get-Date) - $started).TotalSeconds
            })
        }
        return , $results.ToArray()
    }

    # Parallel path: shard items across at most $ThrottleLimit batches.
    $batchSize = [int][Math]::Max(1, [Math]::Ceiling($InputItems.Count / [double]$ThrottleLimit))
    $batches = [System.Collections.Generic.List[object[]]]::new()
    for ($i = 0; $i -lt $InputItems.Count; $i += $batchSize) {
        $end = [Math]::Min($i + $batchSize - 1, $InputItems.Count - 1)
        [void]$batches.Add(@($InputItems[$i..$end]))
    }

    $jobs = @()
    for ($bi = 0; $bi -lt $batches.Count; $bi++) {
        $jobArgs = @(, [object[]]$batches[$bi]) + $ArgumentList + @($modulePath)
        $job = Start-Job -Name "$ActivityName-$bi" -ScriptBlock $ScriptBlock -ArgumentList $jobArgs
        $jobs += [PSCustomObject]@{ BatchIndex = $bi; Batch = $batches[$bi]; Job = $job; Start = Get-Date }
    }

    foreach ($j in $jobs) {
        $elapsed = ((Get-Date) - $j.Start).TotalSeconds
        $remaining = [int][Math]::Max(1, $JobTimeoutSeconds - $elapsed)
        $finished = Wait-Job -Job $j.Job -Timeout $remaining
        if (-not $finished) {
            try { Stop-Job -Job $j.Job -ErrorAction SilentlyContinue } catch { Write-Verbose "Stop-Job failed: $($_.Exception.Message)" }
            [void]$results.Add([PSCustomObject]@{
                BatchIndex      = $j.BatchIndex
                Items           = $j.Batch
                Failed          = $true
                Output          = $null
                Error           = "Job timed out after $JobTimeoutSeconds seconds"
                DurationSeconds = ((Get-Date) - $j.Start).TotalSeconds
            })
        }
        else {
            try {
                $out = Receive-Job -Job $j.Job -ErrorAction Stop
                [void]$results.Add([PSCustomObject]@{
                    BatchIndex      = $j.BatchIndex
                    Items           = $j.Batch
                    Failed          = $false
                    Output          = $out
                    Error           = $null
                    DurationSeconds = ((Get-Date) - $j.Start).TotalSeconds
                })
            }
            catch {
                [void]$results.Add([PSCustomObject]@{
                    BatchIndex      = $j.BatchIndex
                    Items           = $j.Batch
                    Failed          = $true
                    Output          = $null
                    Error           = $_.Exception.Message
                    DurationSeconds = ((Get-Date) - $j.Start).TotalSeconds
                })
            }
        }
        Remove-Job -Job $j.Job -Force -ErrorAction SilentlyContinue
    }

    return , $results.ToArray()
}
