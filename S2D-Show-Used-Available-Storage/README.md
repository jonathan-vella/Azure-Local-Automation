# Azure Local - Show Real Used / Real Available Storage (S2D)

> **Disclaimer:** This script is NOT a Microsoft supported service offering or product. It is provided as example code only, with no warranty or official support. Refer to the [MIT License](https://github.com/NeilBird/Azure-Local/blob/main/LICENSE) for further information.

## Why the storage numbers don't tally across Portal, WAC and the Azure Local LENS workbook

The reason the numbers don't tally across the **Azure portal**, **Windows Admin Center (WAC)**, and the **Azure Local LENS workbook** is that **Azure Local provisions volumes as Thin by default**. Once you understand that, the "Real Used" / "Real Available" picture becomes much clearer, and so does why each tool can show a different value for what looks like the same thing.

The key thing to know:

Azure Local's deployment process creates **Thin** volumes by default for `UserStorage_X` volumes, plus **Fixed** volumes for the system data (`Infrastructure_1` and `ClusterPerformanceHistory`). The number of `UserStorage_X` volumes - and therefore each volume's thin maximum - is set at deployment time and varies by cluster, depending on the size of overall storage in the physical nodes. For example, a 2-node pattern can produce six 15.5 TiB volumes on one cluster and two 9.15 TiB volumes on another, depending on the number (and size) of physical data disks. The "Thin Maximum" is just the upper bound a thin volume can ever grow to; it is **not** a reservation of physical space, and it is **not** how much data the volume can actually hold.

Crucially, the sum of Thin Volume maximums across all volumes can exceed the pool's physical capacity. That's overprovisioning, and it's intentional - it lets each volume grow flexibly without you having to repartition the pool - but it's also why "Size" and "SizeRemaining" in the Azure portal and WAC can show you very little about real storage headroom.

This means:

- A volume's **"Size"** in the Portal/WAC is its **Thin Maximum** - a logical ceiling set at deployment time, not a physical allocation size.
- The volume's free space (**"SizeRemaining"**) is **not physical headroom** - it's logical headroom up to that thin maximum.
- All Thin volumes share the **same physical pool**, so "Real Available" is a **pool-wide** number, not a per-volume one. Any volume can grow until the pool fills to ~100%.

This is why the Azure portal (storage paths), WAC's Volumes view, and the Azure Local LENS workbook (Azure Resource Graph data for storage paths) can all look inconsistent or alarming - they're each showing a different layer of an inherently multi-layered picture.

## The four layers of capacity

| Layer | What it shows | Resiliency overhead included? |
|---|---|---|
| Raw / Physical | Sum of all disks in the cluster | No |
| Storage Pool | Pool size (raw minus metadata) | No |
| Virtual disk footprint on pool | Physical bytes a volume consumes | Yes - ~2x logical data for 2-way mirror, ~3x for 3-way |
| Volume Size / SizeRemaining | Thin maximum + logical headroom | Misleading on Thin CSV volumes (Azure Local default) |

## The numbers you actually want

- **Real Used per volume** = `FootprintOnPool` from `Get-VirtualDisk` - physical bytes consumed, already inclusive of mirror overhead.
- **Logical data written per volume** = `FootprintOnPool / NumberOfDataCopies` (so /2 for 2-way mirror, /3 for 3-way).
- **Real Available cluster-wide** = `Pool Size - Pool Allocated - Capacity Reserve`, then divided by the resiliency factor to express it as "how much new logical data can I deploy". The capacity reserve is roughly one capacity drive's worth per node, capped at four drives, kept aside for in-place repair.

## What this script does

The script (`S2D-Show-Used-Available-Storage.ps1`) is read-only and can be run from any node in an Azure Local / Storage Spaces Direct cluster. It auto-detects the resiliency factor from your existing volumes rather than assuming 2-way or 3-way mirror, and flags if the cluster has volumes at multiple resiliency tiers.

It produces two outputs:

1. **Step 1 - Per-volume table** showing each virtual disk's `ThinMaxTiB`, `FootprintOnPoolTiB` (Real Used), and `LogicalWrittenTiB`.
2. **Step 2 - Pool-wide summary** showing pool size, pool allocated, capacity reserve, and `NewLogicalDataYouCanWriteTiB` (Real Available).

## Requirements

- PowerShell 5.1 or later
- Administrator privileges (the storage cmdlets return limited or no data without elevation)
- `FailoverClusters` and `Storage` PowerShell modules
- Run from a node that is a member of an Azure Local / S2D cluster

## Usage

```powershell
# From any node in the cluster, in an elevated PowerShell session:
.\S2D-Show-Used-Available-Storage.ps1
```

You can also download and run it directly:

```powershell
Invoke-WebRequest -UseBasicParsing `
    -Uri 'https://raw.githubusercontent.com/NeilBird/Azure-Local/refs/heads/main/S2D-Show-Used-Available-Storage/S2D-Show-Used-Available-Storage.ps1' `
    -OutFile .\S2D-Show-Used-Available-Storage.ps1

.\S2D-Show-Used-Available-Storage.ps1
```

## How to read the output

### Per-volume table - one row per virtual disk

| Column | What it tells you |
|---|---|
| `Volume` | Friendly name of the virtual disk / CSV. |
| `Resiliency` | e.g. `Mirror`, `Parity`. Mirror is what most Azure Local clusters run. |
| `DataCopies` | How many copies of each block the cluster keeps. `2` = 2-way mirror (typical for 2-node), `3` = 3-way mirror (3+ nodes). This is the resiliency factor for that volume. |
| `ProvisioningType` | `Thin` (deployment default for `UserStorage` volumes) or `Fixed` (used for system volumes like `Infrastructure_1` and `ClusterPerformanceHistory`). If it says `Thin`, the `Size` column in WAC/Portal is the thin maximum, not real usage. |
| `ThinMaxTiB` | The volume's "Size" - the upper bound it can ever grow to. Set at deployment time, not a physical reservation. |
| `FootprintOnPoolTiB` | **Real Used** - actual physical bytes this volume is consuming on the pool, mirror overhead included. This is the number to use for capacity reporting. |
| `LogicalWrittenTiB` | Roughly how much real workload data is in the volume (`FootprintOnPool / DataCopies`). Useful for "how much data does this app actually have". |

### Pool-wide summary - the cluster-level view

| Field | What it tells you |
|---|---|
| `PoolSizeTiB` | Total usable pool size before any volumes. |
| `PoolAllocatedTiB` | Sum of every volume's `FootprintOnPool` - i.e. **Real Used** cluster-wide. |
| `PoolFreeRawTiB` | Physical free space in the pool, before reserving anything for repair. |
| `CapacityReserveTiB` / `ReserveDrivesUsed` | How much is being held back for in-place repair, and how it was sized. |
| `PoolFreeAfterReserveTiB` | Physical free space you can actually allocate to new or growing volumes. |
| `ResiliencyFactorAssumed` / `ResiliencySource` | The mirror factor used in the final calculation, and whether it was detected, mixed, or defaulted. If you see `MIXED`, treat the bottom-line number as a planning estimate rather than precise. |
| `NewLogicalDataYouCanWriteTiB` | **"Real" Available Space** - the closest single number to "how much new application data can I deploy onto this cluster". This is a cluster-wide shared budget, not per-volume: any logical data written to any thin volume consumes from this same number. Individual volumes are also bounded by their own thin maximum, whichever is hit first. |

In short: **`PoolAllocatedTiB` is your real used**, **`NewLogicalDataYouCanWriteTiB` is your real available**, and the per-volume **`FootprintOnPoolTiB`** shows the used-space distribution on a per-volume basis (how much space each volume is using).

## Cross-referencing the other tools

### Windows Admin Center (WAC)

In WAC -> cluster -> **Volumes**, treat the `Size` column as the **thin maximum** and the `Used` column as **logical data written** (not the pool footprint). The cluster Dashboard's storage tile is the closest WAC view to pool-level reality, but it doesn't subtract the capacity reserve - so it'll be slightly more optimistic than the PowerShell above.

> **Important:** if you're using WAC to administer Azure Local, please make sure the **Cluster Manager Extension** on your WAC instance is up to date (or reinstall WAC using the latest public bits). There's a known issue that can cause incorrect deletions when deleting volumes via WAC against Windows Server 2025 or Azure Local 24H2 - see [Windows Admin Center known issues](https://learn.microsoft.com/en-us/windows-server/manage/windows-admin-center/support/known-issues) on Microsoft Learn.

### Azure Local LENS Workbook

LENS uses Azure Resource Graph against the ARM-projected properties, which inherit the same thin-maximum view as the Portal - that's correct for what it shows but isn't currently surfacing the pool-level "Real Available" calculation. A pool-level capacity panel that does the reserve subtraction and resiliency division would be a useful future addition to the workbook.

## License

[MIT License](https://github.com/NeilBird/Azure-Local/blob/main/LICENSE)
