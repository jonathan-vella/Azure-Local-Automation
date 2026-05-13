# ITSM Connector for AzLocal.UpdateManagement

> Optional feature. Disabled by default. Module: `AzLocal.UpdateManagement` v0.7.4+
> Phase 1 (this release): ServiceNow only. Phase 2 (Sync close-out) and Phase 3 (Teams / Slack mirror) ship in subsequent v0.7.4 commits on the same branch.

This folder is the setup-and-configure landing page for the ITSM Connector. It walks an operator through every step from "nothing wired" to "the apply-updates pipeline opens a deduped ServiceNow incident when a cluster needs human intervention".

The connector is **fully opt-in**: existing pipelines that do not set `raise_itsm_ticket=true` are unchanged.

| File | Purpose |
|---|---|
| `README.md` | This page - setup walkthrough and quick start. |
| [ITSM-Config-Reference.md](./ITSM-Config-Reference.md) | Full schema reference for the YAML/JSON config (every field, every default). |
| [ITSM-Connector-Plan.md](./ITSM-Connector-Plan.md) | Design + decisions log (architecture, trigger matrix, severity mapping, security model). |

A working sample config plus the Mustache ticket-body template live at [`../Automation-Pipeline-Examples/.itsm/`](../Automation-Pipeline-Examples/.itsm/).

---

## 1. What this connector does

When the `apply-updates` or `fleet-update-status` pipeline finishes, the connector reads the JUnit results file the module already emits and, for each cluster row whose `Status` is in your trigger matrix:

1. Computes a deterministic dedupe key (SHA256 of `ClusterResourceId | UpdateName | TriggerCategory`).
2. Asks ServiceNow whether an incident with that key already exists in state New / In Progress / On Hold.
3. If yes -> returns `Action='DedupedToExisting'` (no new ticket).
4. If no -> creates a new incident with the trigger's severity, category, and the five `u_azlocal_*` custom fields populated.

What it deliberately does **not** do in Phase 1: open Jira / ADO Work Items, send Teams / Slack notifications, or close tickets on success. See [ITSM-Connector-Plan.md Sections 2 + 9](./ITSM-Connector-Plan.md) for the phased roadmap.

---

## 2. Prerequisites

| Requirement | Notes |
|---|---|
| PowerShell 5.1+ | Same as the rest of the module. |
| `Az.Accounts` + `Az.KeyVault` modules | Only when `secrets.source: keyvault` (recommended). `Az.KeyVault` is checked at runtime - install with `Install-Module Az.KeyVault -Scope CurrentUser` if not present. |
| `powershell-yaml` module | Only when the config file is `.yml` / `.yaml`. JSON config works on stock PowerShell. Install with `Install-Module powershell-yaml -Scope CurrentUser`. |
| An Azure Key Vault | Recommended for storing the ServiceNow OAuth client_secret. CI-native secrets (`env://NAME`) are supported as a fallback for users with no Key Vault access. |
| ServiceNow instance | Any supported release. You will register one OAuth application + import one Update Set (see Section 3). |

---

## 3. ServiceNow one-time setup

You need three things in ServiceNow: an OAuth app, five custom fields on the `incident` table, and an assignment group.

### 3.1 Register an OAuth application registry

1. In ServiceNow, navigate to **System OAuth -> Application Registry**.
2. **New -> Create an OAuth API endpoint for external clients**.
3. Name: `AzLocal Update Management`. **Save**.
4. Copy the generated **Client ID** and **Client Secret** - both go into Key Vault in Section 4.
5. Note your instance URL (e.g. `https://yourco.service-now.com`).

### 3.2 Install the custom fields

The connector writes five custom fields to every incident it creates so future runs can find them:

| Field | Type | Purpose |
|---|---|---|
| `u_azlocal_dedupe_key` | String (64), indexed | SHA256 used to deduplicate. |
| `u_azlocal_cluster_resource_id` | String | Full Azure resource ID of the cluster. |
| `u_azlocal_update_name` | String | The HCI update name (e.g. `2511.0.10.0`). |
| `u_azlocal_run_id` | String | Workflow / pipeline run ID. |
| `u_azlocal_source` | String, default `AzLocal.UpdateManagement` | Discriminator. |

Easiest way to install them is the Update Set shipped with the module (delivered in a follow-up commit; the dictionary entries can also be added manually via **System Definition -> Dictionary**).

### 3.3 Create an assignment group

`AzureLocal-Ops` (or whatever you set in `defaults.assignmentGroup`). New tickets are routed here so existing on-call rotations work unchanged.

---

## 4. Pick a secret source

The connector reads three secrets at run time: `clientId`, `clientSecret`, and (cosmetically) `instanceUrl`. Two supported sources:

### 4.1 Azure Key Vault (recommended)

```yaml
secrets:
  source: keyvault
  keyvaultName: corp-prod-kv-01
  servicenow:
    clientId:     sn-azlocal-clientid       # bare name resolved in corp-prod-kv-01
    clientSecret: sn-azlocal-clientsecret
    instanceUrl:  env://ITSM_SN_INSTANCE_URL # never a secret, kept here for parity
```

Grant the pipeline service principal **Key Vault Secrets User** on the vault scope:

```powershell
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee "<sp-object-id>" \
    --scope   "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/corp-prod-kv-01"
```

No extra Azure Key Vault access policies are needed beyond this RBAC. The connector reuses the **same** Az session the rest of the module uses, so no extra service principal management.

### 4.2 CI-native secrets (fallback for users without Key Vault)

```yaml
secrets:
  source: envvar
  servicenow:
    clientId:     env://ITSM_SN_CLIENT_ID
    clientSecret: env://ITSM_SN_CLIENT_SECRET
    instanceUrl:  env://ITSM_SN_INSTANCE_URL
```

Then in your pipeline YAML, surface the GitHub / Azure DevOps secrets as environment variables on the ITSM step. See [`../Automation-Pipeline-Examples/`](../Automation-Pipeline-Examples/) for working YAML.

> **Never put a raw secret in the config file.** The only literal-value form is `literal://<value>` and it is rejected unless the caller passes `-AllowLiteral` (used internally for `instanceUrl`, which is not a secret).

---

## 5. Author the trigger matrix

Drop a file at `./.itsm/azurelocal-itsm.yml` in the consumer repo. The full schema is in [`ITSM-Config-Reference.md`](./ITSM-Config-Reference.md). A minimum-viable matrix is:

```yaml
schemaVersion: 1
secrets:
  source: keyvault
  keyvaultName: corp-prod-kv-01
  servicenow:
    clientId:     sn-azlocal-clientid
    clientSecret: sn-azlocal-clientsecret
    instanceUrl:  env://ITSM_SN_INSTANCE_URL
defaults:
  itsmTarget: ServiceNow
  assignmentGroup: AzureLocal-Ops
triggers:
  Failed:             { raiseTicket: true,  severity: 2, category: 'Cluster update failure' }
  Error:              { raiseTicket: true,  severity: 2, category: 'Cluster update failure' }
  HealthCheckBlocked: { raiseTicket: true,  severity: 3, category: 'Pre-update health resolution' }
  SideloadedBlocked:  { raiseTicket: true,  severity: 4, category: 'Operator action: stage sideloaded payload' }
  ScheduleBlocked:    { raiseTicket: false }   # self-resolves; opt-in if desired
  Skipped:            { raiseTicket: false }
  NotReady:           { raiseTicket: false }
```

A ready-to-copy version with comments lives at [`../Automation-Pipeline-Examples/.itsm/azurelocal-itsm.yml`](../Automation-Pipeline-Examples/.itsm/azurelocal-itsm.yml).

---

## 6. Validate before you wire it into a pipeline

Run these two probes from any host that has the module + an Az session pointed at the same tenant the pipeline will use:

```powershell
Import-Module ./AzLocal.UpdateManagement.psd1 -Force
$cfg = Get-AzureLocalItsmConfig -Path ./.itsm/azurelocal-itsm.yml
$cfg.SchemaVersion              # -> 1
$cfg.Triggers['Failed']         # -> normalised hashtable

Test-AzureLocalItsmConnection -Config $cfg | Format-Table Step, Pass, Message
# Expected output: 4 rows all Pass=True
#   Resolve instanceUrl   True   https://yourco.service-now.com
#   Resolve OAuth secrets True   clientId + clientSecret resolved.
#   OAuth token grant     True   expires_in=1800s
#   Incident table read   True   GET incident?sysparm_limit=1 succeeded.
```

If any step shows `Pass=False`, fix that step before enabling the pipeline.

---

## 7. Dry run against a real JUnit file

Once `Test-AzureLocalItsmConnection` is all-green, run `New-AzureLocalIncident` in `-DryRun` mode to see what would be ticketed without making any HTTP writes:

```powershell
$cfg = Get-AzureLocalItsmConfig -Path ./.itsm/azurelocal-itsm.yml

New-AzureLocalIncident `
    -InputArtifactPath ./artifacts/update-results.xml `
    -Config            $cfg `
    -RunMetadata       @{ Platform='manual'; RunId='dryrun-001'; RunUrl='n/a' } `
    -DryRun `
    -ExportPath        ./artifacts/itsm-dryrun.csv |
  Format-Table ClusterName, Status, Action, Severity, DedupeKey -AutoSize
```

`Action` will be one of: `Skipped` (status not raised by matrix), `DryRun` (would have created), `DedupedToExisting` (existing open incident found - DryRun still queries because Phase 1 dedupe is read-only), or `Created` / `CreateFailed` (only outside DryRun).

> **WhatIf vs DryRun**: `-DryRun` skips ALL HTTP writes. `-WhatIf` (PowerShell-native, via `SupportsShouldProcess`) still authenticates and de-duplicates - it only blocks the final `POST /incident` write.

---

## 8. Wire into the pipeline

The pipeline-side change is two new inputs and one step. See `ITSM-Connector-Plan.md` Section 10 for the full YAML, but the gist:

```yaml
- name: Raise ITSM tickets
  if: ${{ inputs.raise_itsm_ticket == true }}
  shell: pwsh
  run: |
    Import-Module ${{ env.MODULE_PATH }}/AzLocal.UpdateManagement.psd1 -Force
    $cfg = Get-AzureLocalItsmConfig -Path "${{ inputs.itsm_config_path }}"
    New-AzureLocalIncident `
        -InputArtifactPath ./artifacts/update-results.xml `
        -Config $cfg `
        -RunMetadata @{
            Platform = 'github'
            RunId    = $env:GITHUB_RUN_ID
            RunUrl   = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
        } `
        -ExportPath ./artifacts/itsm-results.csv |
      Format-Table ClusterName, Action, TicketId, Severity -AutoSize
```

The first production run should keep `raise_itsm_ticket: false` (or `itsm_dry_run: true`) and inspect the CSV / JUnit artefact before flipping the switch.

---

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Test-AzureLocalItsmConnection` step 1 fails with `not a recognised form` | A secret reference is malformed. | Confirm `kv://<vault>/<secret>` / `env://<NAME>` / bare-name format. Bare names need `secrets.source: keyvault` + `keyvaultName`. |
| Step 1 succeeds, step 2 fails with `Failed to read Key Vault secret` | Service principal lacks RBAC on the vault. | Grant `Key Vault Secrets User`. See Section 4.1. |
| Step 3 fails with `ServiceNow OAuth response did not contain an access_token` | Wrong client_id / client_secret, or the OAuth app is restricted to a different grant type. | Re-issue the secret in ServiceNow; ensure `Application Registry -> Auth Scope` allows the API endpoints used. |
| Step 4 fails with HTTP 403 | The OAuth app role is missing `web_service_admin` (read on the incident table). | Add the role to the OAuth user. |
| Connector creates a new ticket every run for the same problem | Custom field `u_azlocal_dedupe_key` not installed, so `FindByDedupe` always returns empty. | Install the custom fields (Section 3.2). |
| `Action='Skipped'` for a status you wanted to ticket | Status not in `triggers`, or `raiseTicket: false`. | Add an entry with `raiseTicket: true`. |
| `Action='CreateFailed'` with rate-limit messages | ServiceNow per-instance throttle (default 100 req/min). | The HTTP layer honours `Retry-After` automatically; if it still fails, lower the concurrent cluster count on the run or contact your SN admin. |

For deeper traces, run the step with `-Verbose`. The HTTP layer logs every attempt and retry; secret values in URLs are redacted.

---

## 10. Security model summary

- **No raw secrets ever live in config or on disk.** All secrets are read from Key Vault or environment variables at run time. The token is held in memory only.
- **Bearer tokens are redacted** in verbose logs (URL query and header values).
- **All free-text inputs** (cluster names, error text) are **HTML-escaped** when rendered into ticket descriptions to defend against ITSM-side HTML injection. Titles use plain text (no escape needed; ServiceNow `short_description` is plain text).
- **TLS 1.2+** is enforced before every HTTP call.
- **CSV-injection sanitisation** on inputs is unchanged (already present from v0.7.0).

Full security review: [`ITSM-Connector-Plan.md` Section 11](./ITSM-Connector-Plan.md).
