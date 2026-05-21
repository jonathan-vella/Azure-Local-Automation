# AzLocal.UpdateManagement RBAC Reference

> **What you will find here:** Every Azure RBAC role and scope the module needs, broken down by cmdlet group (read-only, planning, executing updates, hybrid runners). Use this when granting an automation principal the least-privilege set of roles before wiring up a pipeline.
>
> **Cross-reference:** The main [README.md](../README.md) only summarises the role list. This file is the canonical reference.

---

## RBAC Requirements

To start updates on Azure Local clusters, users need specific permissions on the `Microsoft.AzureStackHCI` resource provider.

### Recommended Built-in Roles

| Role | Role ID | Description |
|------|---------|-------------|
| **Azure Stack HCI Administrator** | `bda0d508-adf1-4af0-9c28-88919fc3ae06` | Full access to cluster and resources, including updates |
| **Azure Stack HCI Device Management Role** | `865ae368-6a45-4bd1-8fbf-0d5151f56fc1` | Full cluster operations including updates |

### Specific Permissions Required

The following permissions are required for update + fleet-connectivity operations:

| Operation | Required Permission |
|-----------|---------------------|
| Read cluster info | `Microsoft.AzureStackHCI/clusters/read` |
| Read update summary | `Microsoft.AzureStackHCI/clusters/updateSummaries/read` |
| List available updates | `Microsoft.AzureStackHCI/clusters/updates/read` |
| **Start/Apply update** | `Microsoft.AzureStackHCI/clusters/updates/apply/action` |
| Monitor update runs | `Microsoft.AzureStackHCI/clusters/updates/updateRuns/read` |
| Query clusters (Resource Graph) | `Microsoft.ResourceGraph/resources/read` |
| **Read/Write tags** | `Microsoft.Resources/tags/read`, `Microsoft.Resources/tags/write` |
| Read Arc machine agent status (Step.4) | `Microsoft.HybridCompute/machines/read` |
| Read Arc machine extensions (reserved for future extension reporting) | `Microsoft.HybridCompute/machines/extensions/read` |
| Read physical NIC inventory via edge devices (Step.4) | `Microsoft.AzureStackHCI/edgeDevices/read` |
| Read Azure Resource Bridge appliance status (Step.4) | `Microsoft.ResourceConnector/appliances/read` |

> **v0.7.80 note:** The last three rows above were added in v0.7.80. They are required by `Get-AzLocalFleetConnectivityStatus` (introduced in v0.7.79) and therefore by the `Step.4_fleet-connectivity-status.yml` pipeline. Without them, the cmdlet still returns the cluster connectivity section but every other section (Arc agents, physical NICs, Azure Resource Bridges) silently returns zero rows because ARG yields an empty `.data` array for resource types the caller cannot read. Pipelines that were created against the v0.7.79-or-earlier custom-role JSON will see 0 Arc agents / 0 NICs / 0 ARBs until the role is updated.

### Roles That Do NOT Have Update Permissions

| Role | Reason |
|------|--------|
| Azure Stack HCI VM Contributor | Only has `clusters/read` - cannot apply updates |
| Azure Stack HCI VM Reader | Read-only access to VMs, no cluster update permissions |
| Contributor (generic) | Does not include `Microsoft.AzureStackHCI` permissions by default |

### Custom "Azure Stack HCI Update Operator" Role Definition (Least Privilege)

If you need a least-privilege custom role specifically for update operations:

> **JSON format - CLI/PowerShell vs Portal "JSON tab":** The role definition below is in the **CLI / PowerShell format** (top-level `Name`, `IsCustom`, `Actions`, `AssignableScopes`) - the shape consumed by `az role definition create` / `update` and `New-AzRoleDefinition`. The Azure portal's **Edit a custom role -> JSON tab** uses a different shape (the ARM resource representation, wrapped in `properties` with lowercase camelCase and `actions` nested under `permissions[0]`). Pasting this JSON into the portal JSON tab will fail with `Malformed JSON: "properties" property not present or value is null`. To update an existing role from the portal, use the **Permissions** tab (add or remove the actions there) instead of the JSON tab, or run `az role definition create` / `update --role-definition <file>` from a shell.

> **UTF-8 BOM gotcha (`az` CLI):** `az role definition create` / `update` uses Python's `json` parser, which rejects files that start with a UTF-8 BOM and fails with `Failed to parse string as JSON ... Expecting value: line 1 column 1 (char 0)`. If you copy the JSON below into a file via Windows PowerShell `Out-File` / `Set-Content` / `>` redirection, or Notepad `Save As -> UTF-8`, the file may pick up a BOM. Verify with `'{0:X2}' -f [IO.File]::ReadAllBytes($f)[0]` (expect `7B` for `{`, not `EF`). To strip a BOM in place: `[IO.File]::WriteAllText($f, [IO.File]::ReadAllText($f, [Text.UTF8Encoding]::new($false)), [Text.UTF8Encoding]::new($false))`. The bundled file at [`Automation-Pipeline-Examples/azlocal-update-management-custom-role.json`](../Automation-Pipeline-Examples/azlocal-update-management-custom-role.json) ships BOM-free.

```json
{
  "Name": "Azure Stack HCI Update Operator",
  "IsCustom": true,
  "Description": "Can view and apply updates on Azure Local clusters, manage UpdateRing tags, and read the fleet-connectivity scopes (Arc machines, edge-device NICs, Azure Resource Bridges) required by Step.4.",
  "Actions": [
    "Microsoft.AzureStackHCI/clusters/read",
    "Microsoft.AzureStackHCI/clusters/updateSummaries/read",
    "Microsoft.AzureStackHCI/clusters/updates/read",
    "Microsoft.AzureStackHCI/clusters/updates/apply/action",
    "Microsoft.AzureStackHCI/clusters/updates/updateRuns/read",
    "Microsoft.AzureStackHCI/edgeDevices/read",
    "Microsoft.HybridCompute/machines/read",
    "Microsoft.HybridCompute/machines/extensions/read",
    "Microsoft.ResourceConnector/appliances/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.ResourceGraph/resources/read",
    "Microsoft.Resources/tags/read",
    "Microsoft.Resources/tags/write"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}"
  ]
}
```

Save this JSON to a file named `azlocal-update-management-custom-role.json`, then create the custom role using Azure CLI:

`AssignableScopes` must contain a real subscription ID - the literal `{subscription-id}` placeholder will be rejected by `az role definition create`. Capture the current subscription first, or hard-code the IDs you intend to manage:

```powershell
# Use the current az CLI subscription, or set $subId manually
$subId = az account show --query id -o tsv
```

```powershell
# Option 1: File already on disk - substitute the placeholder, then create
(Get-Content ./azlocal-update-management-custom-role.json -Raw) `
    -replace '\{subscription-id\}', $subId |
    Set-Content ./azlocal-update-management-custom-role.json -Encoding UTF8

az role definition create --role-definition ./azlocal-update-management-custom-role.json

# Option 2: Create the file and role in one step using PowerShell (expanding here-string - $subId is interpolated)
@"
{
  "Name": "Azure Stack HCI Update Operator",
  "IsCustom": true,
  "Description": "Can view and apply updates on Azure Local clusters, manage UpdateRing tags, and read the fleet-connectivity scopes (Arc machines, edge-device NICs, Azure Resource Bridges) required by Step.4.",
  "Actions": [
    "Microsoft.AzureStackHCI/clusters/read",
    "Microsoft.AzureStackHCI/clusters/updateSummaries/read",
    "Microsoft.AzureStackHCI/clusters/updates/read",
    "Microsoft.AzureStackHCI/clusters/updates/apply/action",
    "Microsoft.AzureStackHCI/clusters/updates/updateRuns/read",
    "Microsoft.AzureStackHCI/edgeDevices/read",
    "Microsoft.HybridCompute/machines/read",
    "Microsoft.HybridCompute/machines/extensions/read",
    "Microsoft.ResourceConnector/appliances/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.ResourceGraph/resources/read",
    "Microsoft.Resources/tags/read",
    "Microsoft.Resources/tags/write"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/$subId"
  ]
}
"@ | Out-File -FilePath ./azlocal-update-management-custom-role.json -Encoding UTF8

az role definition create --role-definition ./azlocal-update-management-custom-role.json
```

> **Note**: Option 2 uses a double-quoted here-string (`@"..."@`) so PowerShell expands `$subId` before writing the JSON to disk. A literal here-string (`@'...'@`) would NOT expand the variable - you would have to substitute the placeholder yourself as in Option 1.

### Updating an existing custom role (v0.7.79 -> v0.7.80)

If you created the custom role against the v0.7.79-or-earlier definition above, you are missing the three new fleet-connectivity reads (`Microsoft.HybridCompute/machines/read`, `Microsoft.AzureStackHCI/edgeDevices/read`, `Microsoft.ResourceConnector/appliances/read`). Update the existing role in place rather than recreating it (recreating it would invalidate the role ID and break every existing role assignment):

```powershell
# Refresh the local JSON to the v0.7.80 definition (re-run Option 1 or Option 2 above to overwrite the file),
# then update the role in Azure RBAC. Role permission changes propagate within a few minutes; no need to re-assign.
az role definition update --role-definition ./azlocal-update-management-custom-role.json
```

You can also use the Azure portal: Subscription > Access control (IAM) > Roles > "Azure Stack HCI Update Operator" > Clone/Edit > Permissions > add the three reads. Avoid the "Delete and recreate" path - it changes the role's GUID and unassigns every principal currently using it.

### Assigning a Role

```powershell
# Assign Azure Stack HCI Administrator role to a user
az role assignment create `
  --assignee "user@contoso.com" `
  --role "Azure Stack HCI Administrator" `
  --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}"
```

> **Reference**: [Azure built-in roles for Hybrid + multicloud](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/hybrid-multicloud)

