<#
.SYNOPSIS
    Reports the "real" used and available storage on an Azure Local / Storage Spaces Direct (S2D) cluster.

.DESCRIPTION
    Azure Local provisions UserStorage_X volumes as Thin by default. As a result, the "Size" and
    "SizeRemaining" columns shown in Windows Admin Center, the Azure portal, and the Azure Local
    LENS workbook are logical (thin maximum) values, not physical capacity figures. This script
    surfaces the numbers that actually matter when planning capacity:

    Step 1 - Per-volume footprint on the pool
        For each virtual disk reports:
            ThinMaxTiB         The volume's logical ceiling (the "Size" column in WAC/Portal).
            FootprintOnPoolTiB Real physical bytes consumed (mirror overhead included).
            LogicalWrittenTiB  FootprintOnPool divided by NumberOfDataCopies, i.e. real workload data.

    Step 2 - Pool-wide "Real Available"
        Auto-detects the dominant resiliency factor from existing virtual disks, computes the
        capacity reserve (one capacity drive per node, capped at 4), and reports
        NewLogicalDataYouCanWriteTiB - the closest single number to "how much new application
        data can I deploy onto this cluster".

    Run from any node in the cluster. Read-only - the script does not modify any storage objects.

.EXAMPLE
    .\S2D-Show-Used-Available-Storage.ps1

    Runs both steps against the local cluster's storage pool and prints two tables.

.NOTES
    Author : Neil Bird, Microsoft
    Date   : May 2026
    Requires: Administrator privileges, FailoverClusters and Storage PowerShell modules,
              and that the host is a member of an Azure Local / S2D cluster.

    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR
    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service.
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
    implied warranties including, without limitation, any implied warranties of merchantability
    or of fitness for a particular purpose. The entire risk arising out of the use or performance
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the script be liable for
    any damages whatsoever (including, without limitation, damages for loss of business profits,
    business interruption, loss of business information, or other pecuniary loss) arising out of
    the use of or inability to use the sample or documentation, even if Microsoft has been advised
    of the possibility of such damages, rising out of the use of or inability to use the sample script,
    even if Microsoft has been advised of the possibility of such damages.
#>

[CmdletBinding()]
param()

# Requires elevation - Get-StoragePool / Get-VirtualDisk / Get-PhysicalDisk return limited or no data
# without administrator privileges.
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator."
}

# Step 1
# ---------- Per-volume real footprint on the pool (post-resiliency) ----------
Write-Host ""
Write-Host "Per-volume footprint on the storage pool:" -ForegroundColor Cyan

try {
    $virtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
}
catch {
    throw "Failed to enumerate virtual disks. Ensure the Storage module is available and that this host is a member of an S2D / Azure Local cluster. Error: $($_.Exception.Message)"
}

if ($virtualDisks.Count -eq 0) {
    Write-Warning "No virtual disks were found on this host."
}
else {
    $virtualDisks | ForEach-Object {
        $vd = $_
        $resFactor = if ($vd.NumberOfDataCopies) { $vd.NumberOfDataCopies } else { 1 }
        [pscustomobject]@{
            Volume             = $vd.FriendlyName
            Resiliency         = $vd.ResiliencySettingName
            DataCopies         = $vd.NumberOfDataCopies
            ProvisioningType   = $vd.ProvisioningType   # Thin or Fixed
            ThinMaxTiB         = [math]::Round($vd.Size/1TB, 2)
            FootprintOnPoolTiB = [math]::Round($vd.FootprintOnPool/1TB, 2)
            LogicalWrittenTiB  = [math]::Round($vd.FootprintOnPool/$resFactor/1TB, 2)
        }
    } | Format-Table -AutoSize
}

# Step 2
# ---------- Pool-wide "Real Available" ----------
Write-Host "Pool-wide capacity summary:" -ForegroundColor Cyan

$pool = Get-StoragePool -ErrorAction SilentlyContinue |
    Where-Object { -not $_.IsPrimordial } |
    Select-Object -First 1

if (-not $pool) {
    throw "No non-primordial storage pool was found on this host. Run this script from a node in an S2D / Azure Local cluster."
}

$poolSize      = $pool.Size
$poolAllocated = $pool.AllocatedSize          # sum of all FootprintOnPool values
$poolFreeRaw   = $poolSize - $poolAllocated

# Detect the dominant resiliency factor from existing virtual disks.
# If the cluster mixes resiliency tiers, the dominant one is used and flagged.
[int[]]$copiesObserved = @($virtualDisks |
    Where-Object { $_.NumberOfDataCopies } |
    Select-Object -ExpandProperty NumberOfDataCopies)

if ($copiesObserved.Count -gt 0) {
    $dominant  = $copiesObserved | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
    $resFactor = [int]$dominant.Name
    $resSource = "detected from $($copiesObserved.Count) volume(s); dominant = $resFactor-copy"
    $unique    = @($copiesObserved | Sort-Object -Unique)
    if ($unique.Count -gt 1) {
        $mix       = $unique -join ', '
        $resSource = "MIXED resiliency on cluster ($mix copies); using dominant = $resFactor"
    }
}
else {
    $resFactor = 3
    $resSource = "no virtual disks found - defaulting to 3-way mirror"
}

# Capacity reserve: one capacity drive per node, capped at 4 (Azure Local guidance for repair).
try {
    $nodes = @(Get-ClusterNode -ErrorAction Stop).Count
}
catch {
    Write-Warning "Get-ClusterNode failed; defaulting node count to 1. Error: $($_.Exception.Message)"
    $nodes = 1
}

$reserveDrives   = [math]::Min($nodes, 4)
$largestCapDrive = (Get-PhysicalDisk |
                    Where-Object { $_.Usage -eq 'Auto-Select' } |
                    Sort-Object Size -Descending |
                    Select-Object -First 1).Size
if (-not $largestCapDrive) { $largestCapDrive = 0 }
$capacityReserve = $largestCapDrive * $reserveDrives
$poolFreeUsable  = $poolFreeRaw - $capacityReserve

[pscustomobject]@{
    PoolSizeTiB                  = [math]::Round($poolSize/1TB, 2)
    PoolAllocatedTiB             = [math]::Round($poolAllocated/1TB, 2)
    PoolFreeRawTiB               = [math]::Round($poolFreeRaw/1TB, 2)
    CapacityReserveTiB           = [math]::Round($capacityReserve/1TB, 2)
    ReserveDrivesUsed            = "$reserveDrives (one per node, capped at 4)"
    PoolFreeAfterReserveTiB      = [math]::Round($poolFreeUsable/1TB, 2)
    ResiliencyFactorAssumed      = $resFactor
    ResiliencySource             = $resSource
    NewLogicalDataYouCanWriteTiB = [math]::Round($poolFreeUsable/$resFactor/1TB, 2)
} | Format-List
