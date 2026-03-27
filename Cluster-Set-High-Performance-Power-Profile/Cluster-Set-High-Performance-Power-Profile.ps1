# Requires elevation
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator."
}

# Get all cluster nodes
try {
    [array]$Nodes = Get-ClusterNode | Select-Object -ExpandProperty Name -ErrorAction Stop
}
catch {
    throw "Failed to get cluster nodes. Ensure this machine is part of a cluster and the Failover Clustering feature is installed. Error: $_"
}

Write-Host "Cluster nodes found: $($Nodes -join ', ')" -ForegroundColor Cyan

$ScriptBlock = {
    try {
        $highPerfAlias = "SCHEME_MIN"
        $activeScheme = powercfg /getactivescheme

        if ($activeScheme -match "High performance") {
            return [PSCustomObject]@{
                Node    = $env:COMPUTERNAME
                Status  = "AlreadyActive"
                Message = "High Performance power plan is already active."
            }
        }

        powercfg /setactive $highPerfAlias

        $activeSchemeAfter = powercfg /getactivescheme
        if ($activeSchemeAfter -match "High performance") {
            return [PSCustomObject]@{
                Node    = $env:COMPUTERNAME
                Status  = "Set"
                Message = "High Performance power plan successfully set."
            }
        }
        else {
            return [PSCustomObject]@{
                Node    = $env:COMPUTERNAME
                Status  = "Failed"
                Message = "Failed to set High Performance power plan."
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Node    = $env:COMPUTERNAME
            Status  = "Error"
            Message = "Error: $_"
        }
    }
}

try {
    $results = Invoke-Command -ComputerName $Nodes -ScriptBlock $ScriptBlock -ErrorAction Stop
}
catch {
    throw "Failed to invoke command on cluster nodes. Error: $_"
}

foreach ($result in $results) {
    switch ($result.Status) {
        "AlreadyActive" { Write-Host "[$($result.Node)] $($result.Message)" -ForegroundColor Green }
        "Set"           { Write-Host "[$($result.Node)] $($result.Message)" -ForegroundColor Green }
        "Failed"        { Write-Host "[$($result.Node)] $($result.Message)" -ForegroundColor Red }
        "Error"         { Write-Host "[$($result.Node)] $($result.Message)" -ForegroundColor Red }
    }
}