function Convert-AzLocalScheduleSchemaVersion {
    <#
    .SYNOPSIS
        Migrates an apply-updates-schedule.yml file from an older schema
        version to the module's current schema version (or any chosen
        target). Text-surgery based - customer comments and row order are
        preserved verbatim.

    .DESCRIPTION
        The function walks the per-hop recipe table registered in this
        file (see $script:ScheduleSchemaRecipes below). Each recipe is a
        ScriptBlock with signature:

            param([string]$Text) -> @{ Text = <new>; Changes = @(<strings>) }

        Recipes operate on RAW TEXT, not on the parsed structure. This is
        deliberate so operator-authored YAML comments above schedule
        rows (typically change-control references) survive every
        migration hop. Each recipe is expected to be IDEMPOTENT: running
        it twice on the same input must produce the same output.

        Walker behaviour:
          * If $current == $target  -> return Migrated=$false (no-op).
          * If $current  > $target  -> throw (downgrade requested; bad).
          * If $current  < $target  -> walk recipes $current -> $current+1
                                       -> ... -> $target. If any hop is
                                       missing from the table, throw.

        Backup-on-write is performed by the caller
        (Update-AzureLocalPipelineExample) - this function only computes
        the new text and reports what changed.

    .PARAMETER Text
        Raw YAML text of the customer's schedule file.

    .PARAMETER TargetSchemaVersion
        Schema version to migrate TO. Default: this module's current
        ($script:ScheduleSchemaCurrentVersion). Tests can override to
        exercise specific hops.

    .PARAMETER SourcePath
        Optional path used in error messages.

    .OUTPUTS
        [PSCustomObject] with:
          Migrated       [bool]
          FromVersion    [int]
          ToVersion      [int]
          NewText        [string]   - migrated YAML text (or original if no-op)
          Hops           [object[]] - one row per executed recipe:
                                       { FromVersion, ToVersion, Changes[] }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [int]$TargetSchemaVersion = $script:ScheduleSchemaCurrentVersion,

        [Parameter(Mandatory = $false)]
        [string]$SourcePath = '<inline>'
    )

    # Parse just enough to read the current schemaVersion. Re-parse after
    # each hop so future recipes can rely on structured access if they want.
    $cfg = ConvertFrom-AzLocalScheduleYaml -Text $Text -SourcePath $SourcePath
    if ($null -eq $cfg.SchemaVersion -or $cfg.SchemaVersion -isnot [int]) {
        throw "Convert-AzLocalScheduleSchemaVersion: '$SourcePath' has no readable top-level 'schemaVersion'. Cannot migrate."
    }
    $current = [int]$cfg.SchemaVersion

    if ($current -gt $TargetSchemaVersion) {
        throw "Convert-AzLocalScheduleSchemaVersion: '$SourcePath' is on schemaVersion=$current but this module only supports up to $TargetSchemaVersion. Upgrade the AzLocal.UpdateManagement module, then re-run Update-AzureLocalPipelineExample."
    }

    if ($current -eq $TargetSchemaVersion) {
        return [pscustomobject]@{
            Migrated    = $false
            FromVersion = $current
            ToVersion   = $TargetSchemaVersion
            NewText     = $Text
            Hops        = @()
        }
    }

    $hops = New-Object System.Collections.Generic.List[object]
    $workingText = $Text
    for ($v = $current; $v -lt $TargetSchemaVersion; $v++) {
        $key = "$v->$($v + 1)"
        # $script:ScheduleSchemaRecipes is an [ordered] dictionary, which
        # exposes .Contains() but NOT .ContainsKey() - the latter throws
        # MethodNotFound on System.Collections.Specialized.OrderedDictionary.
        if (-not $script:ScheduleSchemaRecipes.Contains($key)) {
            throw "Convert-AzLocalScheduleSchemaVersion: no migration recipe registered for '$key'. The module is missing a hop - this is a bug; file at https://github.com/NeilBird/Azure-Local/issues."
        }
        $recipe = $script:ScheduleSchemaRecipes[$key]
        $hopResult = & $recipe $workingText
        if (-not $hopResult.ContainsKey('Text') -or -not $hopResult.ContainsKey('Changes')) {
            throw "Convert-AzLocalScheduleSchemaVersion: recipe '$key' did not return the expected @{ Text=...; Changes=... } shape."
        }
        $workingText = [string]$hopResult.Text
        $hops.Add([pscustomobject]@{
            FromVersion = $v
            ToVersion   = $v + 1
            Changes     = @($hopResult.Changes)
        }) | Out-Null
    }

    return [pscustomobject]@{
        Migrated    = $true
        FromVersion = $current
        ToVersion   = $TargetSchemaVersion
        NewText     = $workingText
        Hops        = $hops.ToArray()
    }
}

# =====================================================================
# Schedule schema migration recipes - dispatch table
# =====================================================================
# Each value is a ScriptBlock with signature:
#   param([string]$Text) -> @{ Text = <new YAML>; Changes = @(<strings>) }
#
# Recipes MUST be idempotent (running twice = same output as running once)
# and MUST update the top-level 'schemaVersion:' line themselves.
#
# To add a new hop in a future module version:
#   1. Bump $script:ScheduleSchemaCurrentVersion in the .psm1.
#   2. Append a recipe here with the new 'N->N+1' key.
#   3. Add tests in Tests/AzLocal.UpdateManagement.Tests.ps1 for the new
#      hop in isolation AND chained from version 1.
# =====================================================================
$script:ScheduleSchemaRecipes = [ordered]@{
    # v0.7.69 ships schema v1 only. No real hops yet; the dispatch table
    # exists so v0.7.70+ can plug in '1->2' without touching the framework.
}
