# CI/CD Pipeline Examples for Azure Local Cluster Update Management

> **Disclaimer**: This module is **NOT** a Microsoft supported service offering or product. It is provided as example code only, with no warranty or official support. Refer to the [MIT license](https://github.com/NeilBird/Azure-Local/blob/main/LICENSE) for further information.

This folder is the setup-and-configure landing page for the example GitHub Actions and Azure DevOps pipelines that ship with the `AzLocal.UpdateManagement` PowerShell module. It walks an operator from "nothing wired" to "a staged-rollout update programme runs itself, with optional ServiceNow ticketing on failures".

It is written in the same step-by-step style as [`ITSM/README.md`](../ITSM/README.md). If something here is unclear, that file is a good cross-reference for the connector portion.

---

## Table of contents

1. [What you'll have when you're done](#1-what-youll-have-when-youre-done)
   - [1.1 Why the pipelines are named `Step.N - <description>`](#11-why-the-pipelines-are-named-stepn---description)
2. [Prerequisites](#2-prerequisites)
3. [Choose your CI/CD platform and authentication](#3-choose-your-cicd-platform-and-authentication)
   - [3.1 GitHub Actions with OpenID Connect (recommended)](#31-github-actions-with-openid-connect-recommended)
   - [3.2 Azure DevOps with Workload Identity Federation (recommended)](#32-azure-devops-with-workload-identity-federation-recommended)
   - [3.3 Self-hosted runners with Managed Identity](#33-self-hosted-runners-with-managed-identity)
   - [3.4 Service Principal + client secret (legacy fallback)](#34-service-principal--client-secret-legacy-fallback)
4. [Required Azure permissions](#4-required-azure-permissions)
5. [Wire the pipeline files into your repo](#5-wire-the-pipeline-files-into-your-repo)
   - [5.1 GitHub Actions](#51-github-actions)
   - [5.2 Azure DevOps](#52-azure-devops)
   - [5.3 Optional configuration (not recommended): pin the module version](#53-optional-configuration-not-recommended-pin-the-module-version)
6. [End-to-end runbook: bring an estate online](#6-end-to-end-runbook-bring-an-estate-online)
   - [6.1 Inventory the estate](#61-inventory-the-estate)
   - [6.2 Plan update rings, windows, and exclusions](#62-plan-update-rings-windows-and-exclusions)
   - [6.3 Apply tags](#63-apply-tags)
   - [6.4 Pre-flight readiness assessment](#64-pre-flight-readiness-assessment)
   - [6.5 Apply updates - one wave at a time](#65-apply-updates---one-wave-at-a-time)
   - [6.6 Continuous fleet monitoring](#66-continuous-fleet-monitoring)
   - [6.7 Schedule coverage drift detection (new in v0.7.65)](#67-schedule-coverage-drift-detection-new-in-v0765)
7. [Optional: open ITSM tickets for clusters needing operator action](#7-optional-open-itsm-tickets-for-clusters-needing-operator-action)
8. [Scheduling, maintenance windows, and change-freeze periods](#8-scheduling-maintenance-windows-and-change-freeze-periods)
   - [8.3 End-to-end runbook: Apply-Updates Schedule Coverage Audit](#83-end-to-end-runbook-apply-updates-schedule-coverage-audit)
9. [Tuning throughput (`-ThrottleLimit`)](#9-tuning-throughput--throttlelimit)
10. [Standalone HTML report (no pipeline)](#10-standalone-html-report-no-pipeline)
11. [Security model](#11-security-model)
12. [Troubleshooting](#12-troubleshooting)
13. [File layout](#13-file-layout)
14. [Appendix A: Pipeline reference](#appendix-a-pipeline-reference)
15. [Appendix B: Release history](#appendix-b-release-history)
    - [B.1 v0.7.70 (current)](#b1-v0770-current)
    - [B.2 v0.7.69](#b2-v0769)
    - [B.3 v0.7.68](#b3-v0768)
    - [B.4 v0.7.66](#b4-v0766)
    - [B.5 v0.7.65](#b5-v0765)
    - [B.5 v0.7.4](#b5-v074)
    - [B.6 v0.7.2](#b6-v072)
    - [B.7 v0.7.1](#b7-v071)
    - [B.8 v0.7.0](#b8-v070)
16. [Related documentation](#16-related-documentation)

---

## 1. What you'll have when you're done

By the end of this guide you will have:

- A federated identity (no client secrets) wired into your CI/CD platform with the **minimum** Azure RBAC needed for cluster update management.
- Seven working pipelines committed to your repo and visible in the Actions / Pipelines UI:
  - **Inventory** - enumerate every Azure Local cluster the identity can see and export a CSV. *Scheduled weekly + manual.*
  - **Manage UpdateRing tags** - bulk-apply `UpdateRing`, `UpdateWindow`, `UpdateExclusions` tags from that CSV. *Manual only.*
  - **Assess Update Readiness** - pre-flight, report-only readiness + blocking-health snapshot, published as JUnit XML. *Manual only.*
  - **Apply Updates** - apply updates to a single `UpdateRing` wave at a time, with WhatIf / dry-run support. *Manual only by default - **you must add a schedule** that lines up with your cluster `UpdateWindow` tags, see [Appendix A.4](#a4-apply-updates) and [section 8](#8-scheduling-maintenance-windows-and-change-freeze-periods).*
  - **Fleet Update Status** - scheduled daily snapshot of fleet update state, surfaced in the Tests tab. *Scheduled daily 06:00 UTC + manual.*
  - **Fleet Health Status** (v0.7.65) - scheduled daily snapshot of 24-hour system health-check failures, surfaced in the Tests tab. *Scheduled daily 07:00 UTC + manual.*
  - **Apply-Updates Schedule Coverage Audit** (v0.7.65) - read-only weekly audit that compares the cron(s) in your `apply-updates` pipeline to the `UpdateWindow` tags actually present on your clusters and flags any (UpdateRing, UpdateWindow) pair that no cron will reach. *Scheduled weekly Mon 05:00 UTC + manual.*
- An end-to-end "ring-based" rollout pattern: Pilot -> Wave2 -> Production, with each ring gated on the previous wave's success.
- **Optional**: a ServiceNow integration that opens deduped incidents for clusters whose run status indicates the module's own retries cannot recover (failures, blocking health checks, sideloaded payload missing) - see [section 7](#7-optional-open-itsm-tickets-for-clusters-needing-operator-action).

The pipelines are **fully opt-in additive layers** over the module. The PowerShell functions also work without any pipeline at all - see [section 10](#10-standalone-html-report-no-pipeline) for the ad-hoc / desktop story.

### 1.1 Why the pipelines are named `Step.N - <description>`

The eight YAMLs ship with a `Step.N_` filename prefix **and** a matching `Step.N - <description>` value in each workflow's `name:` field (GitHub Actions) / header title (Azure DevOps):

| Step | File / Workflow name |
|---:|---|
| 0 | Step.0 - Authentication Validation and Subscription Scope Report |
| 1 | Step.1 - Inventory Azure Local Clusters |
| 2 | Step.2 - Manage UpdateRing Tags |
| 3 | Step.3 - Apply-Updates Schedule Coverage Audit |
| 4 | Step.4 - Assess Update Readiness |
| 5 | Step.5 - Apply Updates |
| 6 | Step.6 - Fleet Update Status |
| 7 | Step.7 - Fleet Health Status |

- **GitHub Actions**: the Actions sidebar sorts workflows alphabetically by the `name:` field inside the YAML. Because every `name:` starts with `Step.N - `, the sidebar lists the eight workflows in execution order (Step.0 first, Step.7 last) instead of the cosmetically confusing alphabetical scatter (`Apply Updates`, `Apply-Updates Schedule Coverage Audit`, `Assess Update Readiness`, ...).
- **Azure DevOps**: the Pipelines list sorts by the pipeline **definition name** chosen at *import time* (not by the YAML filename and not by any top-level `name:` field - the `name:` field in an ADO YAML controls the per-run *build number*, not the pipeline display name). When you import each YAML, the import wizard prefills the suggested pipeline name from the YAML's leading title comment; the YAMLs in this repo open with `# Step.N - <description>`, so the suggested name is already correct. **Accept the suggested name** (or paste `Step.N - <description>` yourself), and the Pipelines list will sort in execution order. You can rename a pipeline later via *Pipeline -> Edit -> Settings -> Name*.

If you prefer a different naming scheme (e.g. `00 - Auth`, `01 - Inventory`, ...), just change the `name:` field in each GH Actions YAML and / or pick a different prefix at ADO import time. Nothing else in the module depends on these display names.

---

## 2. Prerequisites

| Requirement | Notes |
|---|---|
| Azure subscription(s) containing Azure Local clusters | One or many; multi-subscription is supported and is the common state at >~500 clusters because the per-subscription storage-account quota caps how many witness accounts (and therefore clusters) fit in one subscription. |
| Permissions to create app registrations in Microsoft Entra ID, or an existing one | Required so you can either set up Workload Identity Federation (recommended) or, as a fallback, a Service Principal + client secret. |
| GitHub repository **or** Azure DevOps project | The pipeline YAMLs are checked in to one of these and run on the platform's hosted Windows agents (or your self-hosted runners). |
| PowerShell 5.1 or later | Used by every pipeline step. Microsoft-hosted `windows-latest` agents ship with PowerShell 5.1 and PowerShell 7+ already installed - no extra install needed there. |
| `Az.Accounts` + `Az.KeyVault` modules | `Az.Accounts` is required by all pipelines. `Az.KeyVault` is required only if you opt in to the ITSM connector with Key Vault-sourced secrets (recommended). The pipelines install these on the agent as needed. |
| `powershell-yaml` module | Required only if you opt in to the ITSM connector and your matrix config is YAML (default). JSON config works on stock PowerShell. The pipeline installs this on the agent only when the ITSM step runs. |

You do **not** need any cluster-side prerequisites for the inventory, tag-management, readiness, or fleet-status pipelines. The Apply Updates pipeline does require the clusters be in a healthy ARM state for the update API to accept the request - that is what the readiness pre-flight in section 6.4 measures.

---

## 3. Choose your CI/CD platform and authentication

There are three supported authentication patterns, listed from **most to least secure**. Pick one - you do not need all three.

| Method | Security | Secret to manage | Best for |
|---|---|---|---|
| **OpenID Connect (OIDC) / Workload Identity Federation** | Strongest | None (secretless) | GitHub Actions and Azure DevOps. **Recommended for all new setups.** |
| **Managed Identity** | Strong | None | Self-hosted runners on Azure VMs. |
| **Service Principal + client secret** | Weak | Client secret (expires, leaks, must rotate) | Legacy environments where OIDC / federation is not available. |

> **Microsoft strongly recommends OIDC / Workload Identity Federation** over client secrets. Tokens are short-lived, scoped, and never stored anywhere you have to rotate.

### 3.1 GitHub Actions with OpenID Connect (recommended)

OIDC has the workflow request a short-lived token from Azure at runtime, with no stored secret. Subject claim binding ensures only **your** repository's workflows can mint the token.

> **Before you start - you need a GitHub repository**: the federated credential subjects below reference `<owner>/<repo>` (case-sensitive) and must match the exact path of the repo that will host the workflows. If you don't have one, create it first at **github.com -> New repository**; for Azure Local fleet-update automation a **private** repository is strongly recommended so the cluster inventory CSV, tag metadata, and any pipeline state are not publicly readable. An empty repo is fine - the workflow files are added later in [section 5.1](#51-github-actions). Note: `az ad app federated-credential create` does **not** validate `<owner>/<repo>` against GitHub - a typo here surfaces only at workflow run time as `AADSTS70021: No matching federated identity record found`.

**Step 1 - create the App Registration**

```bash
# Create App Registration (no client secret needed)
az ad app create --display-name "AzureLocal-UpdateAutomation-OIDC"
# Note the appId from the output - this becomes AZURE_CLIENT_ID.
```

**Step 2 - create the Service Principal and assign a role**

First create the Service Principal:

```bash
az ad sp create --id <appId-from-step-1>
```

Then assign **one** of the following. The custom role is recommended for production / governed estates because it grants only the actions the pipelines actually use; the built-in role is a quick-start option for lab and PoC work.

**Option A (recommended) - assign the least-privilege custom role**

This pattern grants the Service Principal only the actions the seven pipelines need (read clusters, read/apply updates, read update runs, read/write tags, Resource Graph queries). The full JSON role definition and `az role definition create` command live in [section 4 below](#4-required-azure-permissions) - run that block once per tenant first, then assign:

```bash
az role assignment create `
    --assignee <appId-from-step-1> `
    --role    "Azure Stack HCI Update Operator" `
    --scope   "/subscriptions/<your-subscription-id>"
```

**Option B (quick start) - assign the built-in Azure Stack HCI Administrator role**

Use this only for lab / PoC where over-grant is acceptable. It includes broad cluster-management permissions far beyond what the pipelines exercise.

```bash
az role assignment create `
    --assignee <appId-from-step-1> `
    --role    "Azure Stack HCI Administrator" `
    --scope   "/subscriptions/<your-subscription-id>"
```

For multi-subscription estates, run the `role assignment create` step once per subscription. The custom role definition itself is created once per tenant, then assigned at each subscription scope.

**Step 3 - federate the workflow**

> **Plan your GitHub environments now**: environment-scoped subjects (`...:environment:<name>`) only succeed at workflow run time if a GitHub environment with the exact same name exists in the repo (names are **case-sensitive**). The `az` command will accept any string you put in `subject` - Entra ID does **not** validate it against GitHub - but a missing or mistyped environment fails the OIDC exchange at runtime with `AADSTS70021: No matching federated identity record found`. The create order does not technically matter, but it is easiest to decide on environment names now (and ideally create them up-front under **your repo -> Settings -> Environments -> New environment**) so the strings you put into the federated credentials definitely match what GitHub will later send in the token. For the ring-based rollout pattern this guide describes, three are recommended:
>
> | Environment | Purpose | Suggested protection rules |
> |---|---|---|
> | `DevTest` | Pilot ring - first cluster(s) to receive a new build. | Required reviewers: 0-1 (auto-promote acceptable). |
> | `PreProduction` | Wave2 ring - broader validation before fleet-wide rollout. | Required reviewers: 1. |
> | `Production` | Final ring - the bulk of the fleet. | Required reviewers: 2. Deployment branches: `main` only. Optional wait timer. |
>
> Each environment becomes **one** federated credential, one `environment:` line in the workflow job, and one independent approval gate. A single app registration supports up to 20 federated credentials, so this comfortably scales if you later add more rings.
>
> The names `DevTest`, `PreProduction`, and `Production` are just suggestions to match the ring pattern in this guide - **pick whatever names suit your organisation** (e.g. `Pilot`, `Wave2`, `Prod`, `Ring0`, `Ring1`, `Ring2`). Whatever you choose, use the **same name** in (a) the GitHub environment, (b) the federated credential `subject`, and (c) the `environment:` line of the workflow job that targets that ring.
>
> **GitHub environments and `UpdateRing` tag values are independent.** The `UpdateRing` tag lives on the cluster ARM resource and is what the PowerShell functions filter on (`-UpdateRing Wave1`). A GitHub environment is just an approval gate and federated credential subject. They do **not** have to share names, and the mapping is many-to-many: one GitHub environment can run updates across multiple `UpdateRing` values (different workflow runs pass different `-UpdateRing` parameters under the same approval gate), and multiple environments can target the same `UpdateRing` (e.g. a `PreProductionDryRun` environment that runs with `-WhatIf` against the `Production` ring). The workflow YAML decides which ring tag a given environment-gated run applies to.

```bash
# Branch-scoped credential (for default-branch / scheduled runs).
az ad app federated-credential create `
    --id <appId-from-step-1> `
    --parameters '{
        "name": "GitHubActions-main",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:<owner>/<repo>:ref:refs/heads/main",
        "audiences": ["api://AzureADTokenExchange"]
    }'

# Environment-scoped credential - one per GitHub environment (DevTest, PreProduction, Production).
# Repeat this command three times, substituting both `name` and `subject` to match each environment.
az ad app federated-credential create `
    --id <appId-from-step-1> `
    --parameters '{
        "name": "GitHubActions-Production",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:<owner>/<repo>:environment:Production",
        "audiences": ["api://AzureADTokenExchange"]
    }'
```

Subject-claim patterns for other trigger types:

| Trigger | Subject claim |
|---|---|
| Push to a branch | `repo:<owner>/<repo>:ref:refs/heads/<branch>` |
| Pull request | `repo:<owner>/<repo>:pull_request` |
| Environment | `repo:<owner>/<repo>:environment:<env>` |
| Tag | `repo:<owner>/<repo>:ref:refs/tags/<tag>` |

> **PowerShell on Windows**: passing the `--parameters` JSON as an inline string (as shown above) fails on Windows PowerShell - and on PowerShell 7+ on Windows - with `Failed to parse string as JSON: ... Expecting property name enclosed in double quotes`. The `az` CLI on Windows is a `.cmd` shim, and cmd.exe strips the inner double quotes from the JSON before `az` ever sees them. Microsoft's [quoting guidance](https://learn.microsoft.com/cli/azure/use-azure-cli-successfully-quoting#json-strings) recommends bypassing the shell entirely by writing the JSON to a file and passing it with the `@<filepath>` prefix - this is the universally safe pattern and works on Linux/macOS too:
>
> ```powershell
> # Reusable temp file for all federated-credential payloads in this section
> $paramsFile = Join-Path $env:TEMP 'fed-cred.json'
>
> # Branch-scoped credential (for default-branch / scheduled runs)
> @{
>     name      = 'GitHubActions-main'
>     issuer    = 'https://token.actions.githubusercontent.com'
>     subject   = 'repo:<owner>/<repo>:ref:refs/heads/main'
>     audiences = @('api://AzureADTokenExchange')
> } | ConvertTo-Json | Out-File -FilePath $paramsFile -Encoding utf8 -Force
>
> az ad app federated-credential create `
>     --id <appId-from-step-1> `
>     --parameters "@$paramsFile"
>
> # Environment-scoped credentials - one per GitHub environment (names are case-sensitive
> # and must match the environments that will exist in your repo at workflow run time)
> foreach ($envName in 'DevTest','PreProduction','Production') {
>     @{
>         name      = "GitHubActions-$envName"
>         issuer    = 'https://token.actions.githubusercontent.com'
>         subject   = "repo:<owner>/<repo>:environment:$envName"
>         audiences = @('api://AzureADTokenExchange')
>     } | ConvertTo-Json | Out-File -FilePath $paramsFile -Encoding utf8 -Force
>
>     Write-Host "Creating federated credential for $envName environment..."
>     az ad app federated-credential create `
>         --id <appId-from-step-1> `
>         --parameters "@$paramsFile"
> }
>
> Remove-Item $paramsFile
> ```
>
> The `@` in `"@$paramsFile"` is the **az CLI's** "read from file" prefix (not PowerShell splatting). The surrounding double quotes ensure PowerShell expands `$paramsFile` and passes `az` a single literal string like `@C:\Users\...\Temp\fed-cred.json`. Add or remove names from the `foreach` to match the environments you actually created. Repeat the same build-file-then-pass pattern for any other subject claims you need (`pull_request`, tag, additional branches).

**Step 4 - add the one GitHub Secret and two GitHub Variables**

| Name | Kind | Value |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | The App Registration `appId` from step 1. |
| `AZURE_TENANT_ID` | **Variable** (not a Secret) | Your Entra ID tenant ID. A tenant id is a public ARM/AAD identifier (it is logged on every `azure/login@v3` run and rendered in workflow telemetry), not a credential. |
| `AZURE_SUBSCRIPTION_ID` | **Variable** (not a Secret) | Any subscription the federated identity can read - it is used to set the runner's default `az account` context, nothing more. The bundled cmdlets query Azure Resource Graph fleet-wide and never scope to this id. |

> **Why are `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` repository Variables, not Secrets?** Both values are public ARM/AAD identifiers - they appear in workflow logs on every `azure/login@v3` run, in the OIDC token issuer URL, and in portal deep-links built from per-row ARG data - not credentials. They are each consumed in exactly one place: the `tenant-id:` and `subscription-id:` inputs to `azure/login@v3`, which exchanges the OIDC token for an Azure AD token in the tenant and then runs `az account set --subscription <id>` so the runner has a default `az account` context. Neither value is used to scope Azure Resource Graph queries (the bundled cmdlets omit `--subscriptions` and therefore enumerate every cluster the federated identity can read across the tenant) and neither is interpolated into portal deep-link URLs (those are built from the per-row `subscriptionId` that ARG returns alongside each cluster). A Variable is preferred over a Secret because (a) the values are public identifiers rather than credentials, and (b) `gh variable list` returns the value, which is useful for setup verification. The OIDC `client-id` is the only remaining Secret (legacy path: `client-secret` is also a Secret).

No `AZURE_CLIENT_SECRET` is needed.

For public repositories, prefer [environment secrets with required reviewers](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-secrets) over repository-level secrets - they restrict who can run the workflow against production identities.

You can add the secrets via the **GitHub UI** (**Settings -> Secrets and variables -> Actions -> New repository secret**, then **Settings -> Environments -> `<env>` -> Add secret** for environment-scoped values), or scripted via the **GitHub CLI** (`gh`) - expand the section below.

<details>
<summary><b>Show GitHub CLI (<code>gh</code>) scripted setup</b></summary>

> **Install the GitHub CLI (`gh`)** - one-time setup. Pick whichever applies on your workstation; all options give you the same `gh` binary:
>
> ```powershell
> # Windows - winget (recommended on Windows 10/11)
> winget install --id GitHub.cli
>
> # Windows - Chocolatey alternative
> choco install gh
>
> # macOS - Homebrew
> brew install gh
>
> # Linux - see https://github.com/cli/cli/blob/trunk/docs/install_linux.md
> ```
>
> Then authenticate once (opens a browser, asks you to sign in to GitHub and grant the CLI permission):
>
> ```powershell
> gh auth login
> # Choose: GitHub.com -> HTTPS -> Login with a web browser
> # Confirm with: gh auth status
> ```
>
> `gh` reuses the credentials of the signed-in account, so it can write secrets to any repo that account can write to. No personal access token needed for interactive use.

**Script the secrets and environments (recommended)** - end-to-end: creates the GitHub environments your federated credentials reference, writes the three repo-level secrets, and (optionally) pins `AZURE_CLIENT_ID` at each environment. Substitute `<owner>/<repo>` for your target repo:

```powershell
# Inputs - reuse the variables from the federation step where you can
$repo     = '<owner>/<repo>'                                 # e.g. contoso/azlocal-update-automation (your GitHub repo)
$clientId = '<appId-from-step-1>'                            # GUID printed by az ad app create (from step 1)
$subId    = (az account show --query id       -o tsv)        # current az subscription
$tenantId = (az account show --query tenantId -o tsv)        # current az tenant
$envs     = 'DevTest','PreProduction','Production'           # match the names in your federated credentials

# 0. Preflight - confirm gh is signed in as the right account and can write to $repo.
#    Skipping this is the most common cause of opaque HTTP 404s in step 1.
gh auth status                                              # check signed-in account + token scopes
gh repo view $repo                                          # must print repo details, confirm as you expect
gh api "/repos/$repo" --jq '.permissions'                   # must show "admin": true - env creation is admin-only
#    If gh repo view returns 404 or shows a "Repository setup required" prompt:
#      - the repo path is wrong (typo in $repo), OR
#      - your gh account doesn't have access at all (org owner / repo admin only), OR
#      - the org enforces SAML SSO and your OAuth grant is not yet authorised.
#    Fix before proceeding:
#      gh auth refresh -h github.com -s admin:org,repo,workflow
#    Then visit https://github.com/$repo in a browser to accept any pending
#    invitation / SSO consent. Re-run 'gh repo view $repo' until it succeeds.
#
#    If gh repo view succeeds but '.permissions' shows '"admin": false':
#      - you have read/push but NOT admin on the repo.
#      - 'gh api PUT /environments/...' (and 'gh secret set') require admin.
#      - Ask a repo admin to either run this block, or grant your account the
#        Admin role under repo Settings -> Collaborators and teams.

# 1. Create the GitHub environments (idempotent - PUT creates if missing, no-op if it exists).
#    The federated credentials in step 3 only succeed at workflow run time if these exist.
#    No 'gh env create' command exists - use the REST API via gh api.
foreach ($envName in $envs) {
    Write-Host "Ensuring environment '$envName' exists in $repo..."
    gh api `
        --method PUT `
        -H "Accept: application/vnd.github+json" `
        "/repos/$repo/environments/$envName" | Out-Null
}

# 2. Repository-level secret and variables (REQUIRED - visible to every workflow run in the repo).
#    AZURE_CLIENT_ID identifies the app registration for OIDC and is the only Secret.
#    AZURE_TENANT_ID and AZURE_SUBSCRIPTION_ID are *Variables* (not Secrets) because they are
#    public ARM/AAD identifiers, not credentials. Each is consumed only by the corresponding
#    `azure/login@v3` input (`tenant-id:` / `subscription-id:`) - the bundled cmdlets run
#    ARG queries fleet-wide (no --subscriptions scoping) and build portal URLs from per-row
#    ARG data.
gh secret   set AZURE_CLIENT_ID       --body $clientId  --repo $repo
gh variable set AZURE_TENANT_ID       --body $tenantId  --repo $repo
gh variable set AZURE_SUBSCRIPTION_ID --body $subId     --repo $repo

# 3. Optional, additive on top of step 2 (NOT a replacement) - pin AZURE_CLIENT_ID
#    at each environment scope. GitHub resolves secrets env-first then repo-first,
#    so an env-scoped value shadows the repo-level one for jobs targeting that env.
#    Use this if you want a future repo-level CLIENT_ID rotation to require an
#    explicit per-env update before it applies to Production. Skip if you're happy
#    with the single repo-level value (the common case for first-time setup).
foreach ($envName in $envs) {
    gh secret set AZURE_CLIENT_ID --body $clientId --env $envName --repo $repo
}

# Verify (lists names only, never the values - secret values are write-only in GitHub).
# Variable values ARE returned by 'gh variable list' (variables are not masked, by design).
gh secret   list --repo $repo
gh variable list --repo $repo
gh secret   list --env  Production --repo $repo
gh api "/repos/$repo/environments" --jq '.environments[].name'
```

**What success looks like.** With step 3 skipped (the common first-time-setup path), expect output along these lines (timestamps and order may vary):

```text
# gh secret set AZURE_CLIENT_ID ...
[OK] Set Actions secret AZURE_CLIENT_ID for <owner>/<repo>
# gh variable set AZURE_TENANT_ID ...
[OK] Set Actions variable AZURE_TENANT_ID for <owner>/<repo>
# gh variable set AZURE_SUBSCRIPTION_ID ...
[OK] Set Actions variable AZURE_SUBSCRIPTION_ID for <owner>/<repo>

# gh secret list --repo $repo
NAME                   UPDATED
AZURE_CLIENT_ID        about 1 minute ago

# gh variable list --repo $repo
NAME                   VALUE                                  UPDATED
AZURE_TENANT_ID        00000000-0000-0000-0000-000000000000   about 1 minute ago
AZURE_SUBSCRIPTION_ID  00000000-0000-0000-0000-000000000000   about 1 minute ago

# gh secret list --env Production --repo $repo
no secrets found

# gh api "/repos/$repo/environments" --jq '.environments[].name'
DevTest
PreProduction
Production
```

The key signals are: one repo-level secret (`AZURE_CLIENT_ID`), two repo-level variables (`AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) with their values visible, and all three environments listed. The blank env-scoped secret list is **expected** and confirms OIDC is working as designed - see the next note.

> **`no secrets found` at env scope is expected with OIDC + federated credentials.** When you authenticate with OIDC, the `azure/login` action does not need a stored client secret; the single repo-level secret in step 2 carries only the OIDC App Registration's public `AZURE_CLIENT_ID`, the tenant id and subscription id are repo-level Variables (consumed only by `azure/login`'s `tenant-id:` and `subscription-id:` inputs), and the federated-credential `subject` claim (which includes the environment name) is what restricts who can mint a token. Env-scoped secrets in step 3 are only needed if you want to pin a different `AZURE_CLIENT_ID` per environment (e.g. one App Registration per ring). The empty `gh secret list --env Production` output is the correct steady state, not a misconfiguration.

> **Note**: `gh secret list` shows only the secret **names** and last-updated timestamps - GitHub never returns the secret values back, even to admins. If you need to confirm what's there, the names + dates are the only signal; to verify a value you must overwrite with the same `gh secret set` command.

> **Protection rules are not set by this block.** `gh api PUT /environments/<name>` with no body creates a plain environment with no required reviewers, no deployment-branch policy, and no wait timer. For Production you almost certainly want at least required reviewers - the simplest path is to set those in the UI (**Settings -> Environments -> Production -> Configure**), or extend the `gh api` call with a JSON body per the [REST API reference](https://docs.github.com/en/rest/deployments/environments#create-or-update-an-environment). Required-reviewer values must be user/team **IDs**, not names, which is why the UI is often easier here.

</details>

Microsoft Learn reference: [Use GitHub Actions with OpenID Connect](https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect).

### 3.2 Azure DevOps with Workload Identity Federation (recommended)

Workload Identity Federation is the Azure DevOps equivalent of OIDC. ADO creates the App Registration and federated credential for you, and unlike GitHub Actions there are **no `AZURE_*` secrets to manage** - the service connection itself is the auth wiring (`clientId`, `tenantId`, `subscriptionId`, and the federated identity are all stored on the connection). Pipeline tasks like `AzureCLI@2` just reference it by name (`azureSubscription: 'AzureLocal-ServiceConnection'`).

**UI flow (one-off setup)**:

1. Open your Azure DevOps project.
2. **Project Settings -> Service connections -> New service connection**.
3. Pick **Azure Resource Manager**.
4. Pick **Workload Identity federation (automatic)**.
5. Select your subscription and scope.
6. Name the connection **`AzureLocal-ServiceConnection`** so the example YAMLs work without edits. If you pick a different name, update the `azureSubscription:` value in each ADO YAML.
7. **Save**.

**Scripted alternative (optional)** - use the `azure-devops` extension for the Azure CLI. There is no Azure DevOps equivalent of the GitHub CLI; ADO scripting is done through `az devops` and `az pipelines`. Expand the section below.

<details>
<summary><b>Show Azure DevOps CLI (<code>az devops</code>) scripted setup</b></summary>

> **Install the `azure-devops` `az` extension** - one-time:
>
> ```powershell
> # Adds the 'az devops' / 'az pipelines' / 'az repos' / 'az boards' command groups
> az extension add --name azure-devops
>
> # Cache org + project defaults so later commands don't repeat them
> az devops configure --defaults `
>     organization=https://dev.azure.com/<your-org> `
>     project='<your-project>'
> ```
>
> No separate auth step is needed - the extension reuses your existing `az login` token.

```powershell
# Inputs - reuse variables from the federation steps where you can
$subId    = (az account show --query id           -o tsv)
$tenantId = (az account show --query tenantId     -o tsv)
$subName  = (az account show --query name         -o tsv)

# 1. Create the service connection with automatic workload identity federation.
#    ADO creates the App Registration + federated credential for you.
az devops service-endpoint azurerm create `
    --name                        'AzureLocal-ServiceConnection' `
    --azure-rm-service-principal-id '' `                                # auto-create the SP
    --azure-rm-subscription-id     $subId `
    --azure-rm-subscription-name   $subName `
    --azure-rm-tenant-id           $tenantId `
    --service-principal-tenantid   $tenantId `
    --workload-identity-federation-issuer ''                            # auto

# 2. Verify the connection was created and is workload-identity-federated.
az devops service-endpoint list `
    --query "[?name=='AzureLocal-ServiceConnection'].{name:name, authorizationScheme:authorization.scheme, isReady:isReady}" `
    -o table

# 3. Grab the auto-created App Registration's appId so you can grant it the role.
#    The App Registration display name will match the connection name.
$adoSpAppId = az ad sp list `
    --display-name 'AzureLocal-ServiceConnection' `
    --query '[0].appId' -o tsv
```

Then grant the **`Azure Stack HCI Update Operator`** custom role from [section 4.1](#41-custom-role-azure-stack-hci-update-operator-recommended) on the same scope you selected in step 5 (or, for quick-start labs only, the built-in `Azure Stack HCI Administrator` role). Re-use the security-group pattern from 4.1 if you prefer:

```powershell
# Direct assignment to the auto-created SP
az role assignment create `
    --assignee $adoSpAppId `
    --role    "Azure Stack HCI Update Operator" `
    --scope   "/subscriptions/$subId"

# OR (recommended): add it to the operators security group so the group's role is inherited
$spObjectId = az ad sp show --id $adoSpAppId --query id -o tsv
az ad group member add --group <operators-group-objectId> --member-id $spObjectId
```

> **ADO variable groups (if you use them)**: the only `AZURE_*` value you might still want to pin as a pipeline variable is the **subscription id** for read-only display in run logs - there's no `AZURE_CLIENT_SECRET` to protect. If you do want one, the equivalent of `gh secret set` is:
>
> ```powershell
> az pipelines variable-group create `
>     --name        'AzureLocal-PipelineVars' `
>     --variables   AZURE_SUBSCRIPTION_ID=$subId `
>     --authorize   true
> ```
>
> The service connection still does the heavy lifting; variable groups are optional metadata.

</details>

### 3.3 Self-hosted runners with Managed Identity

If your GitHub Actions runner or Azure DevOps agent is a VM in Azure, Managed Identity is the cleanest option - no secret, no federation config.

```bash
# System-assigned managed identity on the agent VM
az vm identity assign --name runner-vm --resource-group runners-rg

# Grant the role to that identity (recommended: custom role from section 4.1)
$principalId = az vm show -n runner-vm -g runners-rg --query identity.principalId -o tsv
az role assignment create `
    --assignee $principalId `
    --role    "Azure Stack HCI Update Operator" `
    --scope   "/subscriptions/<your-subscription-id>"

# Quick-start / lab fallback - built-in role with broader privileges:
# az role assignment create `
#     --assignee $principalId `
#     --role    "Azure Stack HCI Administrator" `
#     --scope   "/subscriptions/<your-subscription-id>"
```

In GitHub Actions, log in with:

```yaml
- name: Azure CLI Login (Managed Identity)
  uses: azure/login@v2
  with:
    auth-type: IDENTITY
    client-id: ${{ secrets.AZURE_CLIENT_ID }}  # only required for user-assigned identity
```

In the PowerShell module directly:

```powershell
Connect-AzureLocalServicePrincipal -UseManagedIdentity
```

### 3.4 Service Principal + client secret (legacy fallback)

Use this **only** if OIDC and Workload Identity Federation are unavailable.

Create the SP first, then assign the custom role from [section 4.1](#41-custom-role-azure-stack-hci-update-operator-recommended) (recommended) so the legacy client-secret identity is still least-privilege:

```bash
# Create SP without assigning any role yet
az ad sp create-for-rbac --name "AzureLocal-UpdateAutomation" --skip-assignment

# Recommended: assign the custom role (after running the role-definition create from section 4.1)
az role assignment create `
    --assignee <appId-from-create-for-rbac> `
    --role    "Azure Stack HCI Update Operator" `
    --scope   "/subscriptions/<your-subscription-id>"

# Quick-start / lab fallback - one-shot create + assign the built-in role:
# az ad sp create-for-rbac `
#     --name   "AzureLocal-UpdateAutomation" `
#     --role   "Azure Stack HCI Administrator" `
#     --scopes "/subscriptions/<your-subscription-id>"
```

Save the `appId`, `password`, and `tenant` from the output - they go into two Secrets and two Variables:

| Name | Kind | Value |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | `appId` from the command output. |
| `AZURE_CLIENT_SECRET` | Secret | `password` from the command output. **Expires - rotate every 90 days.** |
| `AZURE_TENANT_ID` | **Variable** (not a Secret) | `tenant` from the command output. A tenant id is a public ARM/AAD identifier; see the OIDC section above for why this is a Variable, not a Secret. |
| `AZURE_SUBSCRIPTION_ID` | **Variable** (not a Secret) | Your subscription ID. See the OIDC section above for why this is a Variable, not a Secret. |

In the example GitHub Actions YAMLs, the OIDC step is active by default and the client-secret variant is left commented out. Switch the comments around (and remove the OIDC `permissions:` block) to flip to client-secret auth.

If you must use client secrets:

1. **Expire fast** - 90 days or less.
2. **Rotate on a schedule** - automate it; do not rely on humans.
3. **Use environment-level secrets** with required reviewers for public repos.
4. **Audit** - enable Activity Log monitoring for the Service Principal's sign-ins.

---

## 4. Required Azure permissions

The identity created in section 3 needs the following permissions on every subscription that contains clusters in scope. The built-in **Azure Stack HCI Administrator** role covers all of them; the custom-role definition below is the **recommended** least-privilege alternative for production / governed estates.

| Permission | Used by |
|---|---|
| `Microsoft.AzureStackHCI/clusters/read` | All pipelines (inventory + readiness + apply + status). |
| `Microsoft.AzureStackHCI/clusters/updates/read` | Apply Updates, Fleet Update Status. |
| `Microsoft.AzureStackHCI/clusters/updates/apply/action` | Apply Updates. |
| `Microsoft.AzureStackHCI/clusters/updateSummaries/read` | Apply Updates, Fleet Update Status. |
| `Microsoft.AzureStackHCI/clusters/updates/updateRuns/read` | Apply Updates, Fleet Update Status. |
| `Microsoft.ResourceGraph/resources/read` | All pipelines (Resource Graph lookups). |
| `Microsoft.Resources/subscriptions/resourceGroups/read` | All pipelines (resolve cluster scopes). |
| `Microsoft.Resources/tags/read` | Manage UpdateRing Tags, sideloaded workflow. |
| `Microsoft.Resources/tags/write` | Manage UpdateRing Tags, sideloaded workflow (`UpdateSideloaded` + `UpdateVersionInProgress`). |

If you opt in to the ITSM connector with Key Vault-sourced secrets, the identity additionally needs **Key Vault Secrets User** on the configured vault. No other new RBAC.

> **Tag-management identity (Manage UpdateRing Tags pipeline)** can use the built-in **Tag Contributor** role on its own - it grants exactly `Microsoft.Resources/tags/*` and nothing else. Since v0.7.65, `Set-AzureLocalClusterUpdateRingTag` writes tags via the dedicated `Microsoft.Resources/tags/default` PATCH endpoint, so the broader `microsoft.azurestackhci/clusters/write` action (full cluster Contributor) is **not** required for tag changes. If you run the tag-management workflow under a separate identity from the update-apply identity (recommended in regulated estates), grant that identity Tag Contributor only.

### 4.1 Custom role: `Azure Stack HCI Update Operator` (recommended)

This is the least-privilege role that supports every pipeline in this folder. The same definition is documented in the module-level [`AzLocal.UpdateManagement/README.md`](../README.md#permissions-required-for-update-operations) and is reproduced here so this folder is self-contained.

**Role definition (`azlocal-update-management-custom-role.json`):**

```json
{
  "Name": "Azure Stack HCI Update Operator",
  "IsCustom": true,
  "Description": "Can view and apply updates on Azure Local clusters, manage UpdateRing tags",
  "Actions": [
    "Microsoft.AzureStackHCI/clusters/read",
    "Microsoft.AzureStackHCI/clusters/updateSummaries/read",
    "Microsoft.AzureStackHCI/clusters/updates/read",
    "Microsoft.AzureStackHCI/clusters/updates/apply/action",
    "Microsoft.AzureStackHCI/clusters/updates/updateRuns/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.ResourceGraph/resources/read",
    "Microsoft.Resources/tags/read",
    "Microsoft.Resources/tags/write"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<your-subscription-id>"
  ]
}
```

Add every in-scope subscription ID to `AssignableScopes` before creating the role - a custom role can only be assigned at or below a scope listed here.

**Who can run these commands?**

Creating a custom role definition and assigning it are **separate, privileged Azure RBAC operations** - they are not granted by the new custom role itself. The user (or automation identity) running the commands needs the underlying RBAC actions in the table below at the scope listed in `AssignableScopes`.

| Operation | Required action | Built-in Azure RBAC roles that grant it |
|---|---|---|
| `az role definition create` / `update` | `Microsoft.Authorization/roleDefinitions/write` | **Owner**, **User Access Administrator**, **Role Based Access Control Administrator** |
| `az role assignment create` / `delete` | `Microsoft.Authorization/roleAssignments/write` | **Owner**, **User Access Administrator**, **Role Based Access Control Administrator** |

> **Note**: The Entra ID **Global Administrator** directory role is **not** by itself an Azure RBAC role and does not grant `Microsoft.Authorization/*` actions. A Global Administrator can, however, [elevate access](https://learn.microsoft.com/azure/role-based-access-control/elevate-access-global-admin) once to gain **User Access Administrator** at the tenant root (`/`) scope, then perform these operations or delegate them. For day-to-day work, grant **Role Based Access Control Administrator** on the target subscription(s) to the operator instead.

If you don't hold one of those roles, ask whoever does (typically a subscription Owner or your platform team) to either run the commands for you or grant you **Role Based Access Control Administrator** scoped to the in-scope subscription(s). [`Microsoft.Authorization/roleDefinitions/write`](https://learn.microsoft.com/azure/role-based-access-control/role-definitions) is the smallest action you actually need.

**Create the role (one time per tenant):**

`AssignableScopes` must contain a real subscription ID (or a list of them) - the literal `<your-subscription-id>` placeholder will be rejected by `az role definition create`. Capture the current subscription first, or hard-code the IDs you intend to manage:

```powershell
# Use the current az CLI subscription, or set $subId manually
$subId = az account show --query id -o tsv
# For multiple subscriptions, build an array of scope strings instead:
# $scopes = @("/subscriptions/00000000-0000-0000-0000-000000000000",
#             "/subscriptions/11111111-1111-1111-1111-111111111111")
```

```powershell
# Option 1 - JSON file already on disk: substitute the placeholder, then create
(Get-Content ./azlocal-update-management-custom-role.json -Raw) `
    -replace '<your-subscription-id>', $subId |
    Set-Content ./azlocal-update-management-custom-role.json -Encoding UTF8

az role definition create --role-definition ./azlocal-update-management-custom-role.json

# Option 2 - inline create with an expanding PowerShell here-string ($subId is interpolated)
@"
{
  "Name": "Azure Stack HCI Update Operator",
  "IsCustom": true,
  "Description": "Can view and apply updates on Azure Local clusters, manage UpdateRing tags",
  "Actions": [
    "Microsoft.AzureStackHCI/clusters/read",
    "Microsoft.AzureStackHCI/clusters/updateSummaries/read",
    "Microsoft.AzureStackHCI/clusters/updates/read",
    "Microsoft.AzureStackHCI/clusters/updates/apply/action",
    "Microsoft.AzureStackHCI/clusters/updates/updateRuns/read",
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

> **Note**: The here-string in Option 2 uses double quotes (`@"..."@`) so PowerShell expands `$subId` into the JSON before it's written to disk. If you switch to a literal here-string (`@'...'@`), the variable is not expanded and you must substitute the placeholder yourself like in Option 1.

**Assign the custom role to the pipeline identity (per subscription):**

```bash
az role assignment create `
    --assignee <appId-or-principalId> `
    --role    "Azure Stack HCI Update Operator" `
    --scope   "/subscriptions/<your-subscription-id>"
```

To extend the custom role to additional subscriptions, first update `AssignableScopes` with `az role definition update`, then run the `az role assignment create` command above against each new subscription scope.

**Common errors and how to fix them**

| Error | Cause | Fix |
|---|---|---|
| `(AuthorizationFailed) ... does not have authorization to perform action 'Microsoft.Authorization/roleDefinitions/write'` | The signed-in identity is not **Owner**, **User Access Administrator**, or **Role Based Access Control Administrator** on the subscription in `AssignableScopes`. | Have a subscription Owner grant you **Role Based Access Control Administrator** on that subscription (least privilege), or ask them to run the command for you. See "Who can run these commands?" above. |
| `(AuthorizationFailed) ... 'Microsoft.Authorization/roleAssignments/write'` | Same as above but for the assignment step. | Same fix - the same three built-in roles grant both `roleDefinitions/write` and `roleAssignments/write`, so a single role grant unblocks both commands. |
| `RoleDefinitionWithSameNameExists` | A role definition with `Name = "Azure Stack HCI Update Operator"` already exists in the tenant. | Use `az role definition update --role-definition ./azlocal-update-management-custom-role.json` instead of `create`, or pick a unique `Name`. |
| `AssignableScopeNotUnderRoleDefinitionScope` when running `az role assignment create` | The scope you are assigning to is not listed in the role definition's `AssignableScopes`. | Update `AssignableScopes` (`az role definition update`) before re-running the assignment. |
| `Readonly attribute type will be ignored in class ... RoleDefinition` (warning, not an error) | Cosmetic Azure CLI warning emitted by the Python SDK when it sees a read-only field in the JSON; the command still succeeds. | Safe to ignore. |

**Example: AuthorizationFailed when creating the role**

The command and message look like this (subscription / tenant / user identifiers obfuscated):

```text
az role definition create --role-definition "C:\Users\joe.bloggs\azlocal-update-management-custom-role.json"
Readonly attribute type will be ignored in class <class 'azure.mgmt.authorization.models._models_py3.RoleDefinition'>
(AuthorizationFailed) The client 'joe.bloggs@contoso.com' with object id 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
does not have authorization to perform action 'Microsoft.Authorization/roleDefinitions/write' over scope
'/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/providers/Microsoft.Authorization/roleDefinitions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
or the scope is invalid. If access was recently granted, please refresh your credentials.
Code: AuthorizationFailed
```

The fix is **not** to escalate to Global Administrator (an Entra ID role, see note above). The fix is to temporarily give the identity running this command an Azure RBAC role on the subscription that grants `Microsoft.Authorization/roleDefinitions/write` - **Role Based Access Control Administrator** is the most narrowly-scoped built-in option. Alternatively, ask another person / administrator who has the permissions in your tenant to run this one-time setup command on your behalf.

**Example: AuthorizationFailed when assigning the role**

The role definition can be created successfully (often by a platform / RBAC admin) but the **assignment** step then fails for a less-privileged operator. The two operations require different RBAC actions, so passing the `create` step does **not** guarantee `assignment create` will work:

```text
az role assignment create `
    --assignee xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx `
    --role    "Azure Stack HCI Update Operator" `
    --scope   "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
(AuthorizationFailed) The client 'joe.bloggs@contoso.com' with object id 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write' over scope
'/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/providers/Microsoft.Authorization/roleAssignments/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
or the scope is invalid. If access was recently granted, please refresh your credentials.
Code: AuthorizationFailed
```

Same remediation as the create case: have a subscription Owner grant the operator **Role Based Access Control Administrator** on the target subscription (least privilege - covers both `roleDefinitions/write` and `roleAssignments/write`), or have that admin run the `az role assignment create` step on the operator's behalf. **Role Based Access Control Administrator** can additionally be scoped with [conditions](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-conditions-overview) that restrict which roles the holder can assign (e.g. "only `Azure Stack HCI Update Operator`"), which is the cleanest way to delegate this single role grant without handing out broader RBAC powers.

**Tip - delegate via a security group (recommended for >1 identity)**

For larger environments, instead of running `az role assignment create` once per identity, assign the custom role to an Entra ID **security group** (a standard one - not Microsoft 365, not role-assignable), then add the pipeline's service principal (the Enterprise Application in Entra ID) plus any other user / SP that needs the same access as members. This shifts ongoing grants from an Azure RBAC operation to a group-membership operation, which is much easier to delegate and audit:

- The expensive RBAC operation (`Microsoft.Authorization/roleAssignments/write`) runs **once per subscription**, against the group.
- Subsequent grants become **group membership changes** - delegated to the group's owner (or to your Identity Governance / access-package workflow), with no Azure RBAC role required on the operator.
- Compatible with [PIM for Groups](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/concept-pim-for-groups) if you want just-in-time activation of update-operator access.

```bash
# 1. Create the security group (once per tenant)
$groupId = az ad group create `
    --display-name  "AzureLocal-UpdateAutomation-Operators" `
    --mail-nickname "az-local-upd-ops" `
    --query id -o tsv

# 2. Assign the custom role to the GROUP (once per subscription, requires RBAC Admin)
az role assignment create `
    --assignee-object-id      $groupId `
    --assignee-principal-type Group `
    --role  "Azure Stack HCI Update Operator" `
    --scope "/subscriptions/$subId"

# 3. Add the pipeline's SP (and any other identities) to the group - the only ongoing op.
# For an Enterprise Application, --member-id is the SP object ID, NOT the appId.
$spObjectId = az ad sp show --id <appId> --query id -o tsv
az ad group member add --group $groupId --member-id $spObjectId
```

> **Note**: only **security groups** can have service principals as members - Microsoft 365 groups cannot. Avoid setting `isAssignableToRole = true` on the group unless you actually need it for Entra ID directory-role assignment; it is a stricter group type with extra constraints on who can manage membership and is not required for assigning Azure RBAC roles.

**Verify the grant**

Two independent probes - run them both. The first one works even if your interactive sign-in lacks `Microsoft.Authorization/roleAssignments/read` (common when your RBAC Admin / Owner role is held just-in-time via PIM and the activation window has expired - see note below):

```powershell
# Resolve the SP's OBJECT id from its APP id (clientId). They are different GUIDs.
# Use the appId you noted from "az ad app create" in section 3.1, step 1.
$spObjectId = az ad sp show --id <appId> --query id -o tsv

# 1. Is the SP a member of the operators group?
#    Returns { "value": true } if membership is in place.
az ad group member check `
    --group     $groupId `
    --member-id $spObjectId

# 2. Does the group hold the custom role at the subscription scope?
#    Lists every role assignment scoped to the subscription where the group is the principal.
az role assignment list `
    --scope "/subscriptions/$subId" `
    --query "[?principalId=='$groupId'].{Role:roleDefinitionName, PrincipalType:principalType, Scope:scope}" `
    -o table
```

If (1) returns `true` and (2) shows one row with `Azure Stack HCI Update Operator` / `Group` / your subscription scope, the chain is wired correctly and the pipeline SP has the role via the group.

> **PIM gotcha - empty list output**: `az role assignment list` requires `Microsoft.Authorization/roleAssignments/read` on the scope. If you originally received `Owner` / `User Access Administrator` / `Role Based Access Control Administrator` via PIM and the activation window has lapsed, the `list` calls **return nothing silently** (no 403) - and the (1) `group member check` call still works because it goes through Microsoft Graph, not Azure RBAC. If (1) is `true` but (2) is empty, you have **not** lost the grant - you have lost your own read permission. Re-activate the PIM role (Portal: **Entra ID -> Identity Governance -> Privileged Identity Management -> My roles -> Azure resources -> Activate** against the subscription) and the list calls will repopulate. The pipeline SP is unaffected either way - the first workflow run is the real end-to-end test.

> **Tip**: If you started with the built-in `Azure Stack HCI Administrator` role and want to migrate to the custom role with no downtime, assign the custom role first, verify a pipeline run succeeds, then remove the built-in assignment with `az role assignment delete`.

### 4.2 Extending to additional subscriptions (built-in role)

If you accepted the built-in role in section 3, extend it to additional subscriptions with:

```bash
az role assignment create `
    --assignee <appId-or-principalId> `
    --role    "Azure Stack HCI Administrator" `
    --scope   "/subscriptions/<additional-subscription-id>"
```

---

## 5. Wire the pipeline files into your repo

Both platforms expect the YAML files inside this folder to land in a platform-specific location in your **consumer** repo.

> **Shortcut**: install the module first and use `Copy-AzureLocalPipelineExample` to copy this entire folder out of the module install location into a working folder, instead of cloning the repo or hunting through `$module.ModuleBase`:
>
> ```powershell
> Install-Module -Name AzLocal.UpdateManagement -Scope CurrentUser
> Import-Module AzLocal.UpdateManagement
>
> # IMPORTANT: cd into the root of YOUR consumer repo first - all paths below
> # are relative to the current working directory.
> Set-Location 'C:\path\to\your\repo'
>
> # OPTIONAL - copy EVERYTHING (both platforms + shared README + .itsm/) into
> # .\Automation-Pipeline-Examples\ in the current folder. Useful for browsing
> # before you commit to a layout. Skip this if you already know which platform
> # you're targeting and just want the YAMLs in their final location.
> # Copy-AzureLocalPipelineExample
>
> # For a GitHub Actions repo: copy ONLY the GitHub workflow YAML files straight
> # into .github\workflows\ - relative to the repo root you cd'd into above.
> New-Item -ItemType Directory .\.github\workflows -Force | Out-Null
> Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
>
> # For an Azure DevOps repo: copy ONLY the ADO pipeline YAML files into a
> # pipelines folder of your choice (ADO has no fixed-path convention like
> # .github\workflows\).
> New-Item -ItemType Directory .\pipelines -Force | Out-Null
> Copy-AzureLocalPipelineExample -Destination .\pipelines -Platform AzureDevOps
> ```
>
> The function prints a short "next steps" summary pointing at the copied YAML location with the recommended workflow / pipeline to run first (the **Authentication Validation and Subscription Scope Report** - see sections 5.1 and 5.2 below). Supports `-Platform GitHub | AzureDevOps | All`, `-PassThru`, `-WhatIf`, `-Confirm`.
>
> **Refusing to overwrite**: the function will refuse to overwrite any file that already exists in `-Destination`, listing the conflicts in the error message. To refresh after a module upgrade, delete the existing copies first (`Remove-Item .\.github\workflows\*.yml`) and re-run.

### 5.1 GitHub Actions

1. **Run the Authentication Validation and Subscription Scope Report first (strongly recommended).** Before exercising all seven workflows, validate that the App Registration, federated credentials, GitHub secrets, environments, and RBAC role assignment all line up - and capture the count + per-subscription detail of subscriptions visible to the pipeline identity - by running **`Step.0 - Authentication Validation and Subscription Scope Report`**. This narrows any failure to *one* small YAML file instead of debugging seven interacting workflows simultaneously. **Re-run periodically** (recommended monthly, or after any RBAC change in the tenant) to confirm the pipeline identity's subscription scope has not silently widened or narrowed - drift here is the earliest signal that downstream fleet reports are about to under- or over-count clusters.

   The validation workflow ships with the module at [`github-actions/Step.0_authentication-test.yml`](./github-actions/Step.0_authentication-test.yml). v0.7.70 emits a **JUnit XML** report (Authentication / Subscription Scope / Resource Graph Reachability) rendered in the run's Checks UI via `dorny/test-reporter`, a **markdown summary** with the subscription count + subscription detail table written to `$GITHUB_STEP_SUMMARY`, and a `auth-report` artifact (XML + `subscriptions.json` + `subscriptions.csv`) for ITSM / dashboard ingest.

   - **If you used the `Copy-AzureLocalPipelineExample` shortcut above**: the file is already in `.github/workflows/` alongside the other seven workflow YAMLs - those will ride along on the commit but stay dormant until you trigger them manually (`gh workflow run`) or their schedules fire. Commit and push to the default branch, then run the trigger commands below.
   - **If you didn't use the shortcut**: copy just that one file into your repo's `.github/workflows/`, commit, and push to the default branch.

   Then trigger it twice - once branch-scoped, once environment-scoped - to prove **both** federated credential types work end-to-end:

   ```powershell
   # 1. Branch-scoped run - exercises the 'GitHubActions-main' federated credential.
   gh workflow run Step.0_authentication-test.yml --repo $repo

   # 2. Environment-scoped run - exercises the 'GitHubActions-DevTest' federated credential.
   gh workflow run Step.0_authentication-test.yml --repo $repo -f environment=DevTest

   # Watch the most recent run live (Ctrl+C to stop watching, run continues).
   gh run watch --repo $repo
   ```

   **What success looks like.** Two layers of output, both should be green.

   At the `gh` CLI level, `gh run watch` shows the run summary as the steps complete (`gh` actually renders these as Unicode check marks; reproduced here in ASCII):

   ```text
   ? Select a workflow run * Step.0 - Authentication Validation and Subscription Scope Report, Step.0 - Authentication Validation and Subscription Scope Report [main] 12s ago
   [OK] main Step.0 - Authentication Validation and Subscription Scope Report - <run-id>
   Triggered via workflow_dispatch less than a minute ago

   JOBS
   [OK] Validate OIDC + RBAC + Subscription Scope in 32s (ID <job-id>)
     [OK] Set up job
     [OK] Azure login (OIDC)
     [OK] Collect Authentication and Subscription Scope Report
     [OK] Upload auth report artifact
     [OK] Publish Test Results
     [OK] Post Azure login (OIDC)
     [OK] Complete job

   [OK] Run Step.0 - Authentication Validation and Subscription Scope Report (<run-id>) completed with 'success'
   ```

   Inside the `Collect Authentication and Subscription Scope Report` step, the run log shows:

   ```text
   Login successful.
   --- az account show ---
   Name                     SubscriptionId    TenantId         User
   -----------------------  ----------------  ---------------  ------------------------------------
   <your-subscription>      <sub-guid>        <tenant-guid>    <appId>@<tenant-domain>
   --- role assignments for AZURE_CLIENT_ID ---
   Principal              Role                              Scope
   ---------------------  --------------------------------  -------------------------------------
   <appId>                Azure Stack HCI Update Operator   /subscriptions/<sub-guid>
   --- can the SP list Azure Local clusters? ---
   Name           ResourceGroup           SubscriptionId
   -------------  ----------------------  ----------------
   <cluster-1>    <rg-1>                  <sub-guid>
   ```

   ![Step.0 - Authentication Validation and Subscription Scope Report - Validate OIDC + RBAC + Subscription Scope job, showing the `Collect Authentication and Subscription Scope Report` step expanded with `az account show`, role assignments, the per-subscription scope table, and Resource Graph cluster count](../docs/images/auth-smoke-test-validate-oidc.png)

   You may see one informational `windows-latest` -> `windows-2025-vs2026` migration notice in the run annotations. The sample workflows pin `runs-on: windows-latest` (the module is a Windows-side PowerShell module), and GitHub will retarget the alias to the new image automatically when it becomes the default - no action required on your part. As of v0.7.60 the previously-seen Node.js 20 deprecation banner (against `actions/checkout@v4`, `azure/login@v2`, `actions/upload-artifact@v4`, `dorny/test-reporter@v1`) is gone: the sample workflows have been refreshed to Node 24-compatible majors (`@v5`, `@v3`, `@v6`, `@v3` respectively).

   **If it fails**, the most likely causes (and what to check) are:

   | Failure signature | Likely cause | Fix |
   |---|---|---|
   | `AADSTS70021: No matching federated identity record found` | The OIDC token's `sub` claim does not match any `subject` on the App Registration's federated credentials. | Check the actual `sub` in the run log (set `ACTIONS_STEP_DEBUG=true` to see it), then compare against `az ad app federated-credential list --id <appId>`. Mismatched env-name casing is the single most common cause. |
   | `AuthorizationFailed` on `az graph query` (but `az account show` succeeded) | Auth works, but the role assignment is missing, scoped wrong, or not yet propagated. | Re-check section 3.1 step 2 ran against the correct subscription, then re-run the validation workflow - role propagation can take 1-2 minutes. |
   | `Error: Could not fetch access token for Azure` (no AADSTS code) | The workflow lacks `permissions: id-token: write` or the secrets are missing/misspelt. | Confirm the `permissions:` block is present and run `gh secret list --repo $repo` shows all three `AZURE_*` secrets. |
   | Environment-scoped run hangs in **Waiting for review** | The environment has required-reviewers protection (good!) and is waiting for you to approve. | Approve in the **Actions** tab, or remove required reviewers from the validation run via the environment settings. |

   Once the run is green, leave `Step.0_authentication-test.yml` in place and schedule yourself to re-run it monthly (or whenever you change RBAC / federated credentials / subscription assignments). If you used the `Copy-AzureLocalPipelineExample` shortcut, the other seven workflows are already on the default branch - skip to step 4 to run them. Otherwise, proceed to step 2 to copy the remaining workflow files.

2. Copy every file from [`github-actions/`](./github-actions/) into `.github/workflows/` in your repo:
    ```text
    .github/
      workflows/
        Step.1_inventory-clusters.yml
        Step.2_manage-updatering-tags.yml
        Step.4_assess-update-readiness.yml
        Step.5_apply-updates.yml
        Step.6_fleet-update-status.yml
        Step.7_fleet-health-status.yml
        Step.3_apply-updates-schedule-audit.yml
    ```
3. Commit and push. The workflows appear in the **Actions** tab.
4. Each workflow exposes its inputs via the **Run workflow** button (workflow_dispatch). The scheduled triggers (e.g. `Step.6_fleet-update-status.yml` runs daily at 06:00 UTC, `Step.7_fleet-health-status.yml` runs daily at 07:00 UTC, `Step.3_apply-updates-schedule-audit.yml` runs weekly on Mondays at 05:00 UTC) activate automatically once the file is on the default branch.

### 5.2 Azure DevOps

1. **Run the Authentication Validation and Subscription Scope Report first (strongly recommended).** Before importing all seven pipelines, validate that the service connection (Workload Identity Federation), App Registration, and RBAC role assignment all line up - and capture the count + per-subscription detail of subscriptions visible to the pipeline identity - by running **`Step.0 - Authentication Validation and Subscription Scope Report`**. This narrows any failure to *one* small YAML file instead of debugging seven interacting pipelines simultaneously. **Re-run periodically** (recommended monthly, or after any RBAC change in the tenant) to confirm the pipeline identity's subscription scope has not silently widened or narrowed - drift here is the earliest signal that downstream fleet reports are about to under- or over-count clusters.

   The validation pipeline ships with the module at [`azure-devops/Step.0_authentication-test.yml`](./azure-devops/Step.0_authentication-test.yml). v0.7.70 emits a **JUnit XML** report (Authentication / Subscription Scope / Resource Graph Reachability) published via `PublishTestResults@2` and rendered in the run's **Tests** tab, a **markdown summary** with the subscription count + subscription detail table uploaded to the run's **Summary** tab via `##vso[task.uploadsummary]`, and a `auth-report` pipeline artifact (XML + `subscriptions.json` + `subscriptions.csv`) for ITSM / dashboard ingest.

   If you used the `Copy-AzureLocalPipelineExample` shortcut above, the file is already in your chosen pipelines folder alongside the other seven pipeline YAMLs - those YAMLs sit dormant until you import each one as a pipeline, so they're harmless at rest. Otherwise, copy just that one file into your repo. Either way, import it as a new pipeline:

   - **Pipelines -> New pipeline -> Azure Repos Git -> your repo -> Existing Azure Pipelines YAML file -> `/azure-devops/Step.0_authentication-test.yml`**.
   - **Save and run**. If your service connection has a name other than `AzureLocal-ServiceConnection`, edit `azureSubscription:` in the YAML first (the only configurable line).

   Unlike GitHub Actions, ADO does **not** have environment-scoped federated credentials at the auth layer - the service connection itself is the federation, so a single pipeline run validates everything. ADO **Environments** (Pipelines -> Environments) are approval gates only, layered on top of the service connection, and are not exercised by this validation pipeline.

   **What success looks like** (excerpt from the run log):

   ```text
   --- 1. az account show ---
   Name                     SubscriptionId    TenantId         User
   -----------------------  ----------------  ---------------  ------------------------------------
   <your-subscription>      <sub-guid>        <tenant-guid>    <appId>
   --- 2. role assignments ---
   Principal              Role                              Scope
   ---------------------  --------------------------------  -------------------------------------
   <appId>                Azure Stack HCI Update Operator   /subscriptions/<sub-guid>
   --- 3. Resource Graph ---
   Name           ResourceGroup           SubscriptionId
   -------------  ----------------------  ----------------
   <cluster-1>    <rg-1>                  <sub-guid>
   ```

   **If it fails**, the most likely causes (and what to check) are:

   | Failure signature | Likely cause | Fix |
   |---|---|---|
   | `There was a resource authorization issue: 'The pipeline is not valid. Job ... has authorization issues.'` | First-run pipeline approval is pending - ADO requires explicit consent to use a service connection from a new pipeline. | Open the run, click **View** next to the warning, and grant permission. |
   | `AADSTS700024: Client assertion is not within its valid time range` | Workload-identity-federation issuer is misconfigured on the auto-generated App Registration, or system clocks are skewed. | Re-create the service connection (UI flow in section 3.2) - ADO regenerates the federated credential cleanly. |
   | `AuthorizationFailed` on `az graph query` (but `az account show` succeeded) | Auth works, but the role assignment is missing, scoped wrong, or not yet propagated. | Re-check section 3.2 ran against the correct subscription, then re-run the validation pipeline - role propagation can take 1-2 minutes. |
   | `(InvalidScope) The scope '/subscriptions/<id>' is not valid` from `az role assignment list` | The service connection scope is set narrower than the role assignment, e.g. resource-group-scoped. | Widen the service connection scope to the subscription, or pass `--scope` explicitly to `az role assignment list`. |

   Once the run is green, leave the imported pipeline in place and schedule yourself to re-run it monthly (or whenever you change RBAC / service connection / subscription assignments). If you used the `Copy-AzureLocalPipelineExample` shortcut, the other seven YAML files are already in your repo - skip to step 3 to import each as a pipeline. Otherwise, proceed to step 2 to copy the remaining pipeline files.

2. Copy every file from [`azure-devops/`](./azure-devops/) into your repository at a path of your choice (the README assumes the same folder layout as this repo).
3. **Pipelines -> New pipeline -> Azure Repos Git -> your repo -> Existing Azure Pipelines YAML file**, then point at the path of each file. Repeat for all seven.
4. After the pipeline is created, click **Save** (not **Run**) until you are ready to execute.
5. Each pipeline references a service connection named `AzureLocal-ServiceConnection`. Either name your service connection to match, or change `azureSubscription:` in each YAML.

Optional: create a variable group named **`AzureLocal-Config`** in **Pipelines -> Library** for default values (e.g. the default `UpdateRing` for your most-common rollout). The example YAMLs do not require it.

### 5.3 Optional configuration (_not recommended_): pin the module version

Every example pipeline installs `AzLocal.UpdateManagement` from PSGallery at runtime instead of importing a vendored copy from the repo. By default the install step pulls the **latest** version on each run - this is the recommended "fix-forward" posture: bug fixes and new safety gates land on your fleet without you having to touch the YAML again.

If your change-control process requires you to pin the module version (so a release on PSGallery cannot change what runs in production without an explicit promotion), set `REQUIRED_MODULE_VERSION`. The install step pins to that exact version when set, and falls back to "latest" when empty.

**Note**: Pinning shifts ongoing maintenance onto you. With a pin in place you are responsible for: (1) periodically checking PowerShell Gallery for new `AzLocal.UpdateManagement` releases; (2) refreshing the pipeline YAMLs in your repository when a new version ships (run `Copy-AzureLocalPipelineExample -Update` - see further below); and (3) bumping `REQUIRED_MODULE_VERSION` to match the version those refreshed YAMLs were generated against. If the three drift apart, the drift-notice warnings (see below) lose most of their value.

**GitHub Actions** - resolution order (first non-empty wins):

1. Manual `workflow_dispatch` input `module_version` (per-run override).
2. Repository variable `REQUIRED_MODULE_VERSION` (estate-wide default).
3. Empty (install latest).

```bash
# Set an estate-wide pin (applies to every scheduled / event-triggered run):
gh variable set REQUIRED_MODULE_VERSION --body '0.7.60' --repo <owner>/<repo>

# Override for a single manual run, leaving the estate-wide pin untouched:
gh workflow run Step.6_fleet-update-status.yml -f module_version=0.7.60

# Clear the estate-wide pin to return to latest:
gh variable delete REQUIRED_MODULE_VERSION --repo <owner>/<repo>
```

**Azure DevOps** - resolution order (first non-empty wins):

1. Queue-time override of the `moduleVersion` pipeline parameter.
2. The pipeline parameter's default (defaults to empty / latest in the shipped YAMLs).

To set an estate-wide pin in ADO, either change the `moduleVersion` parameter default in each YAML, or wrap it in a variable group / template parameter and reference it from each pipeline.

**Drift notices.** Each install step compares three versions and emits a warning annotation (`::notice` in GitHub Actions, `##vso[task.logissue type=warning]` in Azure DevOps) when:

| Situation | What you see | What it means |
|---|---|---|
| `installed > generated` | "Pipeline YAML was generated against AzLocal.UpdateManagement v<X> but the agent installed v<Y>." | Your committed YAML is older than the module on the agent. Pipeline steps may have been improved since - re-run `Copy-AzureLocalPipelineExample -Update` to refresh. |
| `latest > installed` | "AzLocal.UpdateManagement v<L> is available on PSGallery; this run installed v<I>." | A newer module is on PSGallery than the one the pipeline pinned to. Review the [module CHANGELOG](../CHANGELOG.md) before bumping `REQUIRED_MODULE_VERSION` (or clear the pin to install the latest automatically). |

Both annotations are warnings, not failures - your pipeline still passes.

**Refreshing pipeline YAMLs after a module upgrade.** When the drift notice fires (or you want to pick up new pipeline features that ship in a module release), re-run the copy command with `-Update`:

```powershell
# Interactive (prompts per file with Y / A / N / L / S / ? options):
Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub -Update

# Unattended (for automation - overwrites every file without prompting):
Copy-AzureLocalPipelineExample -Destination .\pipelines -Platform AzureDevOps -Update -Confirm:$false

# Preview which files would change without writing anything:
Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub -Update -WhatIf
```

The destination folders are under git, so `git diff` after the refresh shows exactly which lines changed - giving you a final review gate before commit. `Copy-AzureLocalPipelineExample` deliberately does not expose a `-Force` switch; `-Update` (with optional `-Confirm:$false`) is the only path to overwrite, and git remains the rollback.

**Preserving operator edits across upgrades (v0.7.68+).** For estates that have edited the bundled YAMLs to add custom cron schedules, ITSM secret bindings, or environment-specific tweaks, the marker-aware `Update-AzureLocalPipelineExample` is the preferred refresh path. It replaces everything **outside** the documented customisation regions (paired `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` comments around `schedule-triggers` and, in Step.5, `itsm-secrets`) and **preserves** everything inside them, so a module bump no longer wipes your customer-specific cron lines or secret name mappings:

```powershell
# Preview the marker-aware merge (writes nothing, prints a per-file change manifest):
Update-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub -WhatIf

# Interactive merge (prompts per file):
Update-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub

# Unattended merge:
Update-AzureLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps -Force

# Capture the per-file change manifest:
$report = Update-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub -Force -PassThru
```

Use `Copy-AzureLocalPipelineExample -Update` when you want a clean overwrite (no operator edits to preserve, or you have intentionally chosen to discard them); use `Update-AzureLocalPipelineExample` when you have customised the bundled YAMLs and want to keep those edits.

---

## 6. End-to-end runbook: bring an estate online

This is the canonical "nothing wired -> staged rollout working" sequence. Follow it in order for the first rollout; afterwards sections 6.4-6.6 become recurring.

```text
+-----------------------------------------------------------------------+
|                          PHASE 1: INVENTORY                            |
|  6.1  Step.1_inventory-clusters.yml  ->  cluster-inventory.csv                |
+-----------------------------------------------------------------------+
                              v
+-----------------------------------------------------------------------+
|                          PHASE 2: TAG                                  |
|  6.2  Edit the CSV (UpdateRing, UpdateWindow, UpdateExclusions)        |
|  6.3  Step.2_manage-updatering-tags.yml                                       |
+-----------------------------------------------------------------------+
                              v
+-----------------------------------------------------------------------+
|                          PHASE 3: ROLLOUT                              |
|  6.4  Step.4_assess-update-readiness.yml  (report-only pre-flight)            |
|  6.5  Step.5_apply-updates.yml  Wave1 -> validate -> Wave2 -> Production      |
+-----------------------------------------------------------------------+
                              v
+-----------------------------------------------------------------------+
|                          PHASE 4: STEADY STATE                         |
|  6.6  Step.6_fleet-update-status.yml  (scheduled, daily 06:00 UTC)            |
|       - "Is each cluster up-to-date?"                                  |
|  6.7  Step.7_fleet-health-status.yml  (scheduled, daily 07:00 UTC) - v0.7.65  |
|       - "Do clusters have actionable health issues even when           |
|          up-to-date?" Surfaces 24-hour system health-check failures.   |
|  6.8  Step.3_apply-updates-schedule-audit.yml  (scheduled, weekly Mon 05:00   |
|       UTC) - v0.7.65                                                   |
|       - "Will any tagged UpdateWindow never be reached by the cron     |
|          schedule in Step.5_apply-updates.yml?" Read-only drift advisor.      |
+-----------------------------------------------------------------------+
```

#### Artifact handoffs at a glance

Every pipeline emits one or more artifacts (CSV / Markdown / JUnit XML / HTML). Downstream pipelines consume these artifacts as inputs. The map below shows which artifact crosses which boundary - useful when you are wiring approvals, audit trails, or ITSM forwarding (section 7) around the runbook.

```text
                                            +-------------------------------+
                                            |  Step.1_inventory-clusters.yml       |
                                            |  (read-only ARG)              |
                                            +-------------------------------+
                                                          |
                                                          v  out: cluster-inventory.csv
                                                          |  (one row per cluster, current tags)
                                                          |
                                            +-------------------------------+
                                            |  Operator: edit CSV           |
                                            |  (UpdateRing / UpdateWindow / |
                                            |   UpdateExclusions columns)   |
                                            +-------------------------------+
                                                          |
                                                          v  in:  cluster-inventory.csv (edited)
                                                          |  out: cluster-inventory.csv (echoed
                                                          |       as run artifact for audit)
                                                          |
                                            +-------------------------------+
                                            |  Step.2_manage-updatering-tags.yml   |
                                            |  (writes Microsoft.Resources/ |
                                            |   tags - DryRun first)        |
                                            +-------------------------------+
                                                          |
                                                          v  (cluster tags now committed)
                                                          |
                                            +-------------------------------+
                                            |  Step.4_assess-update-readiness.yml  |
                                            |  (read-only; per-ring         |
                                            |   gating evaluation)          |
                                            +-------------------------------+
                                                          |
                                                          v  out: cluster-readiness.csv
                                                          |  (ClusterResourceId, ReadyForUpdate,
                                                          |   BlockingReasons, HealthState, ...)
                                                          |
                                            +-------------------------------+
                                            |  Step.5_apply-updates.yml            |
                                            |  in:  cluster-readiness.csv   |
                                            |  (consumes ClusterResourceId  |
                                            |   filtered to ReadyForUpdate) |
                                            +-------------------------------+
                                                          |
                                                          v  out: apply-updates-results.csv
                                                          |       apply-updates-results.xml (JUnit)
                                                          |       apply-updates-summary.html
                                                          |
                  +------------------------+--------------+---------------+--------------------------+
                  |                        |                              |                          |
                  v                        v                              v                          v
   +-------------------------+ +---------------------------+ +-------------------------------+ +---------------------------+
   | Step.6_fleet-update-status.yml | | Step.7_fleet-health-status.yml   | | apply-updates-schedule-audit  | | (Optional) ITSM forwarder |
   | daily 06:00 UTC         | | daily 07:00 UTC           | | .yml                          | | (section 7)               |
   | out: fleet-update-      | | out: fleet-health-        | | weekly Mon 05:00 UTC          | | consumes:                 |
   |      status.csv         | |      failures.csv         | | in:  Step.5_apply-updates.yml        | |  - apply-updates-         |
   |      fleet-update-      | |      fleet-health-        | |      cron entries             | |    results.csv            |
   |      status.html        | |      summary.html         | | out: schedule-coverage-       | |  - fleet-health-          |
   +-------------------------+ +---------------------------+ |      audit.csv                | |    failures.csv           |
                                                             |      schedule-coverage-       | +---------------------------+
                                                             |      recommend.md             |
                                                             |      schedule-coverage-       |
                                                             |      audit.xml (JUnit)        |
                                                             +-------------------------------+
```

Key handoffs to remember:

- **`cluster-inventory.csv`** is the only artifact the operator edits by hand. Everything downstream is machine-generated.
- **`cluster-readiness.csv`** carries `ClusterResourceId` from Assess into Apply. Apply does not re-query ARG to pick targets - it consumes the ID column directly, so a stale or malformed readiness CSV silently produces zero ready clusters. Always treat the most recent readiness run as the source of truth for the next Apply.
- **`apply-updates-results.xml`** (JUnit) is what surfaces in the Tests tab on GH Actions and Azure DevOps. Failed-first ordering means actionable rows appear at the top of the reporter UI.
- **`schedule-coverage-recommend.md`** is the only artifact intended to be pasted by hand - directly back into `Step.5_apply-updates.yml`'s `on.schedule` / ADO trigger block when the audit reports `Uncovered` or `PartiallyCovered` rows.

### 6.1 Inventory the estate

Run **Inventory Clusters** with no parameters. It exports a CSV with one row per cluster and the current value of every update-management tag.

- **GitHub Actions**: *Actions -> Inventory Azure Local Clusters -> Run workflow*.
- **Azure DevOps**: *Pipelines -> Inventory Clusters -> Run pipeline*.

Download `cluster-inventory.csv` from the run artifacts. It contains `SubscriptionId`, `ResourceGroupName`, `ClusterName`, `ResourceId`, `UpdateRing`, `UpdateWindow`, `UpdateExclusions`, and the sideloaded-workflow columns added in v0.7.1.

**What a successful inventory run looks like.** The `Run Cluster Inventory` step prints the discovery summary, the absolute path of the exported CSV under the run artifacts, the `UpdateRing` tag distribution across all clusters, and a "Next Steps" block that points at `Set-AzureLocalClusterUpdateRingTag` for the next workflow:

![Step.1_inventory-clusters.yml run: Run Cluster Inventory step expanded, showing Inventory Summary with Total Clusters 20 / Clusters with UpdateRing tag 19 / 1 cluster without UpdateRing tag (warning), UpdateRing Distribution Canary=3 / Prod=9 / Ring1=3 / Ring2=4, CSV export path under the artifacts folder, and the Next Steps block guiding the operator to populate the UpdateRing column and then run Set-AzureLocalClusterUpdateRingTag](../docs/images/inventory-clusters-run-output.png)

> If you would rather skip the inventory pipeline entirely, the same operation runs from a local PowerShell session: `Import-Module ./AzLocal.UpdateManagement.psd1; Get-AzureLocalClusterInventory -ExportPath ./cluster-inventory.csv`. This is the same code path the pipeline uses.

### 6.2 Plan update rings, windows, and exclusions

Open the CSV and fill in three columns:

| Column | Required | Values | Purpose |
|---|---|---|---|
| `UpdateRing` | Yes | Free-form (e.g. `Wave1`, `Pilot`, `Production`) | Defines the wave the cluster belongs to. Apply Updates targets one ring at a time. |
| `UpdateWindow` | No | `<days>_<HH:MM>-<HH:MM>` in UTC, semicolon-separated | Allowed maintenance window. Updates outside it return `ScheduleBlocked`. |
| `UpdateExclusions` | No | `YYYY-MM-DD/YYYY-MM-DD`, comma-separated. Supports `*` wildcards. | Blackout / change-freeze periods. **Exclusions take priority over windows.** |

Example:

| ClusterName | UpdateRing | UpdateWindow | UpdateExclusions |
|---|---|---|---|
| HCI-Pilot01 | Wave1 | | |
| HCI-Pilot02 | Wave1 | | |
| HCI-Prod01  | Wave2 | `Sat-Sun_02:00-06:00` | `20**-12-20/20**-01-03` |
| HCI-Critical | Production | `Sat_02:00-06:00` | `20**-12-20/20**-01-03` |

Section 8 documents the full schedule grammar (multi-window, overnight, wrap-around, wildcards) and shows how to test it interactively with `Test-AzureLocalUpdateScheduleAllowed` before committing the tag.

### 6.3 Apply tags

Two equivalent ways to apply the edited CSV - pick whichever fits your workflow.

> **RBAC**: The identity running the tag write needs `Microsoft.Resources/tags/write` on each cluster (or on a containing scope). The built-in **Tag Contributor** role is sufficient. See section 4 for the full minimum-role table.

**Option A - via the pipeline (audit trail in CI/CD):**

1. Commit the edited CSV to your repo (e.g. `./cluster-tags.csv`).
2. Run **Manage UpdateRing Tags** and point its `csv_path` input at the committed CSV.
3. Inspect the run summary - it reports added / updated / unchanged tag counts per cluster.

**Option B - from PowerShell (faster for one-off changes):**

```powershell
Import-Module ./AzLocal.UpdateManagement.psd1
Set-AzureLocalClusterUpdateRingTag -InputCsvPath ./cluster-tags.csv
```

Either way verifies the tags in Azure with a follow-up read. Both paths use the same module function under the hood.

### 6.4 Pre-flight readiness assessment

Run **Assess Update Readiness** for the ring you are about to roll. It produces two JUnit XML files (visible in the Tests / Checks tab) and two CSV artefacts:

| Artefact | What it shows |
|---|---|
| `readiness.xml` / `readiness.csv` | One test per cluster from `Get-AzureLocalClusterUpdateReadiness`. Fails if `ReadyForUpdate = $false` (e.g. missing SBE prerequisite, no updates available, cluster in `Updating`). |
| `health-blocking.xml` / `health-blocking.csv` | One test per cluster from `Test-AzureLocalClusterHealth -BlockingOnly`. Fails if any **Critical** health failure exists. Non-critical findings are surfaced but do not fail the test. |

The pipeline itself is **report-only and always succeeds**. Per-cluster red tests are signal, not a stop condition for the wave - in a large fleet, one or two clusters out at any given moment is the norm, and blocking the entire wave on those is rarely what you want. `Start-AzureLocalClusterUpdate` is per-cluster-scoped and will no-op on the un-ready clusters anyway.

Common failure classes and where to fix them (the module *detects* blockers, it does not *remediate* them):

| Symptom | Remediation owner |
|---|---|
| Storage / drive / stamp health failure | Azure Local docs + Environment Checker. |
| SBE / firmware / driver prerequisite | Hardware vendor SBE package (Dell, HPE, Lenovo, DataON, ...). The `SBEDependency` and `HasPrerequisiteUpdates` columns identify the publisher and release-notes URL. |
| ADDS connectivity / certificate drift | Azure Local certificate rotation runbook. |
| Workload state preventing host updates | Windows Admin Center cluster validation. |

If you do want a hard go / no-go gate (typical for first production wave), have a downstream workflow read the job outputs `not_ready` and `critical_failures` and apply your own tolerance threshold there.

### 6.5 Apply updates - one wave at a time

For each ring in turn (Wave1 -> validate -> Wave2 -> validate -> Production), run **Apply Updates** with:

| Input | Value |
|---|---|
| `update_ring` | The ring to target (e.g. `Wave1`). |
| `update_name` | Leave blank to apply the latest ready update; set explicitly to pin a version. |
| `dry_run` | `true` for the first run of any new ring - prints the cluster list and intended actions without starting an update. |
| `throttle_limit` | See section 9. Default 4 is fine for fleets up to ~50 clusters. |

The pipeline publishes one test per cluster to the Tests tab and writes per-cluster status to artefacts:

| Status | Meaning | Action |
|---|---|---|
| `Started` / `UpdateStarted` / `Success` | Update is running or finished. | None. |
| `Skipped` | Cluster is up to date or has no ready updates. | None. |
| `ScheduleBlocked` | Cluster is outside its `UpdateWindow` or inside an `UpdateExclusions` period. | Re-run during the window, or update the tag if the schedule has drifted. |
| `HealthCheckBlocked` | Cluster has critical health failures. | Remediate per section 6.4. |
| `SideloadedBlocked` | Cluster has `UpdateSideloaded=False` waiting for an operator to stage the payload. | Stage the payload and flip the tag (or run `Reset-AzureLocalSideloadedTag`). |
| `Failed` / `Error` | The update request returned a non-success response. | Check pipeline logs and the cluster in Azure Portal. |

Use the duration data in `update-runs.csv` from the wave you just finished to size the maintenance window for the next ring.

For tighter control around production rollouts, add a manual approval gate between waves:

- **Azure DevOps**: a separate stage with a `ManualValidation@0` step (the `Step.5_apply-updates.yml` shipped here includes a commented-out `WaitForApproval` block ready to enable).
- **GitHub Actions**: an `environment:` on the production job with required reviewers, configured in *Settings -> Environments*.

### 6.6 Continuous fleet monitoring

The "steady-state" phase ships **two complementary pipelines**, both read-only, both scheduled, designed to be run together as your daily fleet operations baseline:

| Pipeline | Daily | Answers | Output |
|----------|-------|---------|--------|
| `Step.6_fleet-update-status.yml` | 06:00 UTC | *"Is each cluster up-to-date? Which ones need an apply, which ones are SBE-blocked, which ones failed?"* | JUnit + CSV/JSON + Markdown summary; one test case per cluster |
| `Step.7_fleet-health-status.yml` *(v0.7.65)* | 07:00 UTC | *"Do clusters have actionable health issues even when up-to-date? What failure reasons hit the most clusters?"* | JUnit + CSV/JSON + Markdown summary; one test case per (cluster, failing 24-hour health check) grouped under Critical / Warning testsuites |

The two run in distinct (offset) cron slots so they don't contend for the same agent.

**Fleet Update Status** is scheduled to run daily at 06:00 UTC once you push the YAML. It does no writes - it builds a fleet-wide JUnit + CSV + JSON snapshot for dashboards and alerting.

| Artefact | Description |
|---|---|
| `readiness-status.xml` | JUnit XML, one cluster per test (`Passed` = healthy + up to date, `Failed` = needs attention, `Failed/HasPrerequisite` = vendor SBE update required first). |
| `readiness-status.csv` | Spreadsheet view of the same data plus `UpdateWindow`, `UpdateExclusions`, `SBEDependency`. |
| `readiness-status.json` | Machine-readable, with summary counts. |
| `update-summaries.csv` | Update-summary state per cluster from Azure. |
| `available-updates.csv` | Every available update across the fleet with version + health state. |
| `update-runs.csv` | Recent run history per cluster (durations, failure summaries) - this is what section 6.5's "size the next maintenance window" advice consumes. |

**Fleet Health Status** *(new in v0.7.65)* runs daily at 07:00 UTC and surfaces the **24-hour system health-check failures** across every cluster the service connection can read - including clusters that are already "up to date". The 24-hour health checks continue to run on the cluster independently of update activity, so this pipeline is the dedicated place to triage fleet-wide health issues that exist OUTSIDE the update workflow.

It calls the new [`Get-AzureLocalFleetHealthFailures`](../README.md#get-azurelocalfleethealthfailures) cmdlet under the covers.

| Artefact | Description |
|---|---|
| `fleet-health-status.xml` | JUnit XML, one test case per (cluster, failing health check), grouped under `Critical Health Failures` / `Warning Health Failures` testsuites for two-level drill-down. `Failed/Critical` and `Failed/Warning` reflect the severity. |
| `fleet-health-detail.csv` | Per-(cluster, failing check) export. Columns: `ClusterName`, `Severity`, `FailureReason`, `FailureName`, `Description`, `Remediation`, `LastOccurrence`, `ResourceGroup`, `SubscriptionId`, `ClusterResourceId`. |
| `fleet-health-summary.csv` | Aggregated by `(FailureReason, Severity)`, ordered "most widespread first" (`ClusterCount desc`). Columns include `ClusterCount`, `FailureCount`, `AffectedClusters` (semicolon-separated), `LatestOccurrence`. This is the ready-made "what should we fix first?" prioritisation view. |
| `fleet-health-detail.json` / `fleet-health-summary.json` | Machine-readable equivalents for downstream automation. |
| Markdown step summary | Pipeline run summary leads with the pivot-by-failure-reason table, followed by a per-cluster "Detailed Results" table mirroring the standard "24-Hour System Health Checks - Detailed Results" view. |

**RBAC for Fleet Health Status** (read-only): the service connection needs `Reader` on each cluster (or the parent RG / subscription) plus `Microsoft.ResourceGraph/resources/read`. No write actions are taken.

Configure your CI/CD platform's alerting on the JUnit failures - GitHub Actions surfaces them in the run summary and Azure DevOps shows them in the Tests tab with trend analytics.

### 6.7 Schedule coverage drift detection *(new in v0.7.65)*

`Step.3_apply-updates-schedule-audit.yml` runs the read-only [`Test-AzureLocalApplyUpdatesScheduleCoverage`](../README.md#test-azurelocalapplyupdatesschedulecoverage) cmdlet weekly on Mondays at 05:00 UTC and answers:

> *"Is there any `(UpdateRing, UpdateWindow)` tag combination in my fleet that no cron in `Step.5_apply-updates.yml` will ever reach?"*

This is the safety net that catches drift between the cron schedule(s) you committed to `Step.5_apply-updates.yml` and the `UpdateWindow` tags that operators tag onto new clusters. It is intentionally **read-only** - it never edits cluster tags and never modifies pipeline YAML.

| Artefact | Description |
|---|---|
| `schedule-coverage-audit.xml` | JUnit XML, one `<testcase>` per `(UpdateRing, UpdateWindow)` pair. Uncovered / partially covered / malformed pairs become `<failure>`. Use the Tests tab to alert on regressions. |
| `schedule-coverage-audit.csv` | Same data in spreadsheet form. Columns: `Status`, `UpdateRing`, `UpdateWindow`, `ClusterCount`, `RequiredCronUTC`, `Issue`, `Recommendation`, `MatchingCrons`. |
| `schedule-coverage-matrix.csv` | Pure inventory view: every distinct `(UpdateRing, UpdateWindow)` pair with the cron expression the advisor would generate for it. |
| `schedule-coverage-recommend.md` | Ready-to-paste GH Actions + Azure DevOps cron blocks that cover every distinct `UpdateWindow` tag value in the fleet. |
| Markdown step / run summary | Tables for all of the above, headlined by `Covered` / `Uncovered` / `PartiallyCovered` / `MalformedTag` / `UnparseableCron` counts. |

**See also**: the [end-to-end runbook in section 8.3](#83-end-to-end-runbook-apply-updates-schedule-coverage-audit) walks through the full loop (tag a cluster -> see drift -> paste recommended cron -> re-run audit and watch it turn green).

---

## 7. Optional: open ITSM tickets for clusters needing operator action

> **This is optional and disabled by default.** Pipelines that do not toggle `raise_itsm_ticket=true` continue to behave exactly as before. The connector adds an additive step **after** `Publish Test Results` and never affects the apply-updates exit status.

The connector reads the JUnit results the Apply Updates pipeline already publishes and, for each cluster whose status matches your configured trigger matrix (default: `Failed`, `Error`, `HealthCheckBlocked`, `SideloadedBlocked`), opens a deduped ServiceNow incident via the Table API. Idempotency is enforced via a SHA256 dedupe key written to a custom `u_azlocal_dedupe_key` column, so re-running the same workflow does not create duplicates.

This README does not duplicate the setup - it is a single-source-of-truth in [`../ITSM/README.md`](../ITSM/README.md). Here is the high-level wiring you'll do over there:

> **Shortcut for getting the sample into your repo**: from the repo root, run
> ```powershell
> Copy-AzureLocalItsmSample
> ```
> This copies `azurelocal-itsm.yml` + `templates/incident-body.md` from the installed module into `.\.itsm\` - the exact relative path that `Step.5_apply-updates.yml` looks for at job runtime (`itsm_config_path` / `itsmConfigPath` default `./.itsm/azurelocal-itsm.yml`). The sample is CI-platform-agnostic; both GitHub Actions and Azure DevOps consume the same YAML, only the secret source differs. To refresh the sample after a module upgrade, re-run with `-Update` (per-file `ShouldContinue` prompt) or `-Update -Confirm:$false` (unattended). See [`Copy-AzureLocalItsmSample` reference](../Public/Copy-AzureLocalItsmSample.ps1).

| Step | Where it's documented |
|---|---|
| Register a ServiceNow OAuth application + technical user with the `itil` role | [ITSM/README.md section 3](../ITSM/README.md#3-servicenow-one-time-setup) |
| Add the five `u_azlocal_*` custom fields to the `incident` table (manual procedure in v0.7.4) | [ITSM/README.md section 3.2](../ITSM/README.md#32-add-the-five-custom-fields-on-the-incident-table) |
| Pick a secret source (Azure Key Vault recommended, environment-variable fallback) | [ITSM/README.md section 4](../ITSM/README.md#4-pick-a-secret-source) |
| Author the trigger matrix at `./.itsm/azurelocal-itsm.yml` (a ready-to-copy version ships in [`./.itsm/`](./.itsm/) - use `Copy-AzureLocalItsmSample` to drop it into your repo) | [ITSM/README.md section 5](../ITSM/README.md#5-author-the-trigger-matrix) |
| Validate end-to-end with `Test-AzureLocalItsmConnection` before flipping the pipeline switch | [ITSM/README.md section 6](../ITSM/README.md#6-validate-before-you-wire-it-into-a-pipeline) |

Once the ServiceNow side is set up, the pipeline-side change is **already in `Step.5_apply-updates.yml`** in this folder. You enable it by:

1. Setting `raise_itsm_ticket=true` when you trigger Apply Updates (workflow input in GH Actions, parameter in Azure DevOps).
2. Wiring the three secrets the step expects:
   - `ITSM_SN_INSTANCE_URL`
   - `ITSM_SN_CLIENT_ID`
   - `ITSM_SN_CLIENT_SECRET`
3. (Azure DevOps only) Uncomment the `- group: AzureLocal-ITSM-Secrets` line at the top of `Step.5_apply-updates.yml` once the variable group exists.

The first production run should keep `itsm_dry_run=true` (the connector still resolves secrets and performs the read-only dedupe lookup so you can validate the matrix + templates against a real workload, without creating tickets). The dry-run output includes a CSV + JUnit projection of "what would have been ticketed" - inspect those before flipping the switch.

Phase 2 (lifecycle close-out via `Sync-AzureLocalIncident`) and Phase 3 (Teams + Slack mirror) are designed in [`ITSM-Connector-Plan.md`](../ITSM/ITSM-Connector-Plan.md) but **deferred** - they are not shipped in v0.7.4. The example pipeline reserves the slot for the Sync step with `if: false` so the wiring is forward-compatible.

---

## 8. Scheduling, maintenance windows, and change-freeze periods

The `UpdateWindow` and `UpdateExclusions` tags on each cluster control when **Apply Updates** is allowed to start an update.

| Tag | Format | Example | Behaviour |
|---|---|---|---|
| `UpdateWindow` | `<days>_<HH:MM>-<HH:MM>` (UTC) | `Sat-Sun_02:00-06:00` | Updates only start while current UTC time is inside the window. |
| `UpdateExclusions` | `YYYY-MM-DD/YYYY-MM-DD`, comma-separated, supports `*` wildcards | `20**-12-20/20**-01-03,2027-06-01/2027-06-10` | No updates start during these dates. **Exclusions override windows.** |

> **CRITICAL: the `UpdateWindow` tag is a *gate*, not a *trigger*.** The tag only controls **whether** the Apply Updates pipeline is allowed to start an update on a given cluster when the pipeline is already running. The tag does **not** schedule the pipeline itself. The shipped `Step.5_apply-updates.yml` samples have **`workflow_dispatch` only** (GitHub Actions) / **`trigger: none`** (Azure DevOps) with no `schedule:` / `schedules:` block - which means **if you never trigger the pipeline manually during a window, no updates are ever applied automatically**, no matter what `UpdateWindow` you have tagged on your clusters.
>
> **You must add a `schedule:` (GH) / `schedules:` (ADO) block to `Step.5_apply-updates.yml` that fires *inside* (or a few minutes *before*) every `UpdateWindow` you have tagged.** If your fleet uses several distinct `UpdateWindow` values across rings, add one cron entry per window. Examples (UTC):
>
> | Cluster `UpdateWindow` tag | GitHub Actions `cron` | Azure DevOps `cron` | Notes |
> |---|---|---|---|
> | `Sat-Sun_02:00-06:00` | `'55 1 * * 6,0'` | `'55 1 * * 6,0'` | Fires Sat + Sun at 01:55 UTC so cluster enumeration + auth completes before the 02:00 window opens. |
> | `Mon-Fri_22:00-04:00` | `'55 21 * * 1-5'` | `'55 21 * * 1-5'` | Fires weeknights at 21:55 UTC. The overnight wrap is handled by `Test-AzureLocalUpdateScheduleAllowed`, you only need one cron per window opening. |
> | `Sun_03:00-07:00` | `'55 2 * * 0'` | `'55 2 * * 0'` | Single weekly maintenance slot. |
>
> Inside the pipeline, `Test-AzureLocalUpdateScheduleAllowed` is the per-cluster gate - clusters whose `UpdateWindow` does not cover "now" (or whose `UpdateExclusions` does cover "now") are skipped with `Status = ScheduleBlocked`. Running the pipeline outside any window is therefore safe but wasted - **running it during a window is the only way an update ever starts.**
>
> **Tip - one pipeline per ring**: if `Pilot` / `Wave1` / `Production` have different windows, the cleanest pattern is to either (a) copy `Step.5_apply-updates.yml` per ring with the ring's own schedule + `update_ring` hard-coded, or (b) keep one YAML but pass `update_ring` via a matrix indexed by cron entry. Sticking with the default "single manual workflow" is fine for ad-hoc / change-controlled estates - in that case the operator manually clicks **Run workflow** at the start of the maintenance window.

Grammar details:

- **Multiple windows** - separate with `;`: `Mon-Fri_22:00-06:00;Sat-Sun_02:00-10:00`.
- **Day ranges** - wrap-around is supported: `Fri-Mon_22:00-06:00` covers Friday through Monday.
- **Overnight windows** - `Sat_22:00-06:00` means Saturday 22:00 UTC to Sunday 06:00 UTC.
- **Recurring annual exclusions** - use `**` for the year: `20**-12-20/20**-01-03` means every year's Christmas freeze.
- **No tags at all** - updates proceed with no schedule restriction.
- **Malformed tag values** - blocking by default. v0.7.0+ refuses to start the update; pass `-Force` if you intentionally want to update with a known-bad schedule tag.

Test logic interactively before tagging:

```powershell
# Right now in UTC?
Test-AzureLocalUpdateScheduleAllowed -UpdateWindow "Sat-Sun_02:00-06:00" -UpdateExclusions "2026-12-20/2027-01-03"

# A specific past or future moment
Test-AzureLocalUpdateScheduleAllowed -UpdateWindow "Sat_02:00-06:00" -TestTime ([datetime]"2026-04-19 03:00:00")
```

### Multi-stage rollouts with approval gates

For production-critical environments, gate the production wave on the previous wave's success and a human's sign-off.

**Azure DevOps:**

```yaml
stages:
  - stage: Wave1
    jobs:
      - job: ApplyWave1Updates
        # ...

  - stage: ValidateWave1
    dependsOn: Wave1
    jobs:
      - job: WaitForApproval
        pool: server
        steps:
          - task: ManualValidation@0
            inputs:
              notifyUsers: 'ops-team@company.com'
              instructions: 'Review Wave1 update results before proceeding to Wave2.'

  - stage: Wave2
    dependsOn: ValidateWave1
    # ...
```

**GitHub Actions:**

```yaml
jobs:
  wave1:
    runs-on: windows-latest
    environment: wave1  # no approval required
    # ...

  wave2:
    needs: wave1
    runs-on: windows-latest
    environment: production  # configure required reviewers in repo settings
    # ...
```

### 8.3 End-to-end runbook: Apply-Updates Schedule Coverage Audit

*(New in v0.7.65. Pre-wired pipeline samples: [`github-actions/Step.3_apply-updates-schedule-audit.yml`](./github-actions/Step.3_apply-updates-schedule-audit.yml), [`azure-devops/Step.3_apply-updates-schedule-audit.yml`](./azure-devops/Step.3_apply-updates-schedule-audit.yml).)*

This runbook walks through the full loop of **discover -> fix -> verify** for `UpdateWindow` / cron drift. Use it the first time you tag a new ring, and rely on the weekly scheduled audit to catch drift afterwards.

#### Step 1 - One-time: deploy the audit pipeline

```powershell
# GitHub Actions
Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub

# Azure DevOps
Copy-AzureLocalPipelineExample -Destination .\pipelines -Platform AzureDevOps
```

The audit YAML is one of the files copied. Commit and push. On GitHub it appears in the Actions tab; on Azure DevOps, import `Step.3_apply-updates-schedule-audit.yml` as a new pipeline (same procedure as for the other YAMLs in section 5.2).

#### Step 2 - Tag a new ring with an UpdateWindow

```powershell
Set-AzureLocalClusterUpdateRingTag `
    -ClusterResourceId '/subscriptions/.../clusters/cl01' `
    -UpdateRingValue   'Wave2' `
    -UpdateWindowValue 'Mon-Fri_22:00-04:00'
```

Repeat for the rest of the ring.

#### Step 3 - Trigger the audit (or wait for the Monday 05:00 UTC schedule)

- **GitHub Actions**: *Actions -> Apply-Updates Schedule Coverage Audit -> Run workflow*.
- **Azure DevOps**: *Pipelines -> Apply-Updates Schedule Coverage Audit -> Run pipeline*.

Both default `pipelinePath` to the standard consumer location for the platform: `.github/workflows` on GitHub Actions, `.azure-pipelines` on Azure DevOps. If you copied `Step.5_apply-updates.yml` into one of those folders (the recommended layout), the audit finds it on the first run. Override `pipelinePath` only if your copied `Step.5_apply-updates.yml` lives somewhere else (e.g. `.\pipelines`).

#### Step 4 - Read the run summary

The markdown summary at the top of the run page leads with the counts:

```
| (Ring, Window) pairs audited | Covered | Uncovered | PartiallyCovered | MalformedTag | UnparseableCron |
|---|---|---|---|---|---|
| 4 | 1 | 2 | 0 | 0 | 0 |
```

Followed by the per-row detail (Uncovered first):

```
| Status    | UpdateRing  | UpdateWindow            | Clusters | Required Cron (UTC) | Recommendation               |
| Uncovered | Wave2       | Mon-Fri_22:00-04:00     | 47       | 55 21 * * 1-5       | Add: 55 21 * * 1-5           |
| Uncovered | Production  | Sun_03:00-07:00         | 312      | 55 2 * * 0          | Add: 55 2 * * 0              |
| Covered   | Pilot       | Sat-Sun_02:00-06:00     | 3        | 55 1 * * 6,0        | OK - keep the current schedule. |
```

And finally the **ready-to-paste cron block** (Recommend view):

````yaml
# --- GitHub Actions: paste under Step.5_apply-updates.yml `on:` ---
# schedule:
#   - cron: '55 1 * * 6,0'    # Sat-Sun_02:00-06:00 (rings: Pilot, 3 cluster(s))
#   - cron: '55 2 * * 0'      # Sun_03:00-07:00     (rings: Production, 312 cluster(s))
#   - cron: '55 21 * * 1-5'   # Mon-Fri_22:00-04:00 (rings: Wave2, 47 cluster(s))
````

#### Step 5 - Apply the recommendation

Open `Step.5_apply-updates.yml`, uncomment / paste the recommended `schedule:` (GH) or `schedules:` (ADO) block, and commit. The audit pipeline emits both blocks even when `-Platform Both` is the default - copy the section that matches your CI/CD platform.

#### Step 6 - Re-run the audit to verify

Trigger the audit pipeline again. The summary should now show **Uncovered = 0**, the Audit Detail table all `Covered`, and JUnit Test Results all green.

#### Step 7 - Catch drift automatically

Leave the weekly Monday 05:00 UTC schedule enabled. Any time someone tags a new cluster with a `UpdateWindow` value that the existing crons in `Step.5_apply-updates.yml` do not cover, the next Monday's audit run flips to **Uncovered** for that pair and surfaces it on the Tests tab. Configure your CI/CD alerting (GitHub Actions: branch-protection required check; Azure DevOps: notification on Test results) so the team is notified.

#### Ad-hoc / desktop equivalent (no pipeline)

The same advisor is available interactively for one-off use:

```powershell
# Audit the in-repo samples
Test-AzureLocalApplyUpdatesScheduleCoverage `
    -PipelineYamlPath .\AzLocal.UpdateManagement\Automation-Pipeline-Examples

# Just emit the recommended cron block, no audit
Test-AzureLocalApplyUpdatesScheduleCoverage -View Recommend -Platform GitHubActions

# Inventory every (Ring, Window) pair with its required cron, export to CSV
Test-AzureLocalApplyUpdatesScheduleCoverage -View Matrix -ExportPath .\windows.csv
```

---

## 9. Tuning throughput (`-ThrottleLimit`)

**v0.7.68 removed `-ThrottleLimit` from every fleet-scale read cmdlet.** Those cmdlets are now single-batch Azure Resource Graph queries - one ARG call per cmdlet invocation, regardless of fleet size - so the flag had no effect on read throughput and its presence misled operators into thinking they could tune it. The removed-from list:

| Function | `-ThrottleLimit` in v0.7.68 | Replacement back-end | Used by pipeline |
|---|---|---|---|
| `Get-AzureLocalUpdateSummary` | **Removed** | Single ARG batch read | Fleet Update Status. |
| `Get-AzureLocalAvailableUpdates` | **Removed** | Single ARG batch read | Apply Updates (pre-check), Assess Update Readiness. |
| `Get-AzureLocalClusterUpdateReadiness` | **Removed** | Single ARG batch read | Apply Updates (pre-check), Fleet Update Status, Assess Update Readiness. |
| `Test-AzureLocalClusterHealth` | **Removed** | Single ARG batch read (HCI health checks) | Assess Update Readiness, Fleet Health Status. |
| `Get-AzureLocalFleetProgress` | **Removed** | Single ARG batch read | Step.6 Fleet Update Status (JUnit emitter). |
| `Get-AzureLocalFleetStatusData` | **Removed** | Single ARG batch read | Step.6 Fleet Update Status, `New-AzureLocalFleetStatusHtmlReport`. |
| `New-AzureLocalFleetStatusHtmlReport` | **Removed** | Single ARG batch read | Standalone report. |
| `Get-AzureLocalUpdateRuns` | **Removed** | Single ARG batch read against `microsoft.azurestackhci/clusters/updates/updateruns` | Step.6 Fleet Update Status. |
| `Get-AzureLocalUpdateRunFailures` (new in v0.7.68) | n/a (ARG-only) | Single ARG batch read with 9-deep `mv-expand` | Step.5 Apply Updates post-mortem, ad-hoc triage. |

All shipped pipeline YAMLs were updated to stop passing `-ThrottleLimit` to these cmdlets. **If you had passed `throttle_limit` on the workflow input or as a `-ThrottleLimit` argument to any of the above, you can remove it** - the value was already a silent no-op against ARG, and v0.7.68 surfaces the change loudly by failing parameter binding for any caller still passing it.

### Where `-ThrottleLimit` still applies

Only the **apply-side fan-out** still uses any form of parallelism control, because applying updates legitimately is a per-cluster ARM PUT and benefits from controlled parallelism:

| Function | `-ThrottleLimit` exposed | Used by pipeline |
|---|---|---|
| `Start-AzureLocalClusterUpdate` (apply-side fleet ops) | Internal via `Invoke-FleetJobsInParallel`; no user-facing `-ThrottleLimit` parameter. | Step.5 Apply Updates. |

For Step.5 Apply Updates, the apply-side parallelism is bounded internally by the module's own job-pool helper; there is no operator-facing throttle knob to tune.

### Throttling on the read side (ARG 429 / `Retry-After`)

Even though the cmdlets are now single-batch reads, Azure Resource Graph has per-tenant rate limits. `Invoke-AzResourceGraphQuery` (the helper behind every ARG-first cmdlet) now retries on HTTP 429 - it inspects the `Retry-After` response header when present and otherwise applies bounded exponential backoff capped at the documented ARG throttling envelope. Large fleet sweeps no longer fall over at the throttling boundary.

If you see ARG-side `429 TooManyRequests` in the verbose logs from `Invoke-AzResourceGraphQuery`, the most common causes are: (a) running every pipeline on the same cron tick (stagger schedules at least 2-3 minutes apart), and (b) running multiple read pipelines from the same identity in a tight loop during development (add `Start-Sleep -Seconds 30` between iterations of an interactive harness).

---

## 10. Standalone HTML report (no pipeline)

For ad-hoc / offline reporting outside CI/CD, `New-AzureLocalFleetStatusHtmlReport` generates a self-contained HTML report you can email or upload to SharePoint. The function is the same code path the Fleet Update Status pipeline uses internally - no pipeline required.

```powershell
Import-Module ./AzLocal.UpdateManagement.psd1

# All clusters the current Az session can see (v0.7.0: uncapped by default; -MaxClusters trims)
New-AzureLocalFleetStatusHtmlReport -AllClusters `
    -OutputPath "C:\Reports\fleet-all.html" `
    -IncludeHealthDetails -IncludeUpdateRuns

# A single named cluster (auto-titles "Seattle - Update Status Report")
New-AzureLocalFleetStatusHtmlReport -ClusterNames Seattle `
    -OutputPath "C:\Reports\seattle.html" `
    -IncludeHealthDetails -IncludeUpdateRuns

# A whole ring at once
New-AzureLocalFleetStatusHtmlReport -ScopeByUpdateRingTag -UpdateRingValue Wave1 `
    -OutputPath "C:\Reports\wave1-status.html" `
    -IncludeHealthDetails -IncludeUpdateRuns

# Capture HTML for an email body
$html = New-AzureLocalFleetStatusHtmlReport -ClusterNames @('Cluster01','Cluster02') `
    -OutputPath "C:\Reports\fleet.html" -PassThru
```

The report includes executive summary cards, cluster information, a status table with Active Update and Recommended Update columns, full update-run history with recursive step traversal, and severity-filtered health-check failures.

---

## 11. Security model

- **Least privilege** - the role list in section 4 is the minimum. The `Azure Stack HCI Update Operator` custom role in [section 4.1](#41-custom-role-azure-stack-hci-update-operator-recommended) is the recommended default; the built-in `Azure Stack HCI Administrator` role is a quick-start convenience that over-grants for production.
- **OIDC / Workload Identity Federation** is the default authentication path. No client secret is stored, federated subject claims bind tokens to your repo / project, and tokens are short-lived.
- **Per-job `permissions:` blocks (GitHub Actions)** - every shipped GitHub Actions workflow declares its own `permissions:` block at the job level (e.g. `id-token: write`, `contents: read`, `checks: write` only where needed). This is intentional. Do **not** lift those blocks to the top-level `permissions:` of the workflow file when you copy a sample into your repo: per-job permissions are the security-recommended shape because they (a) limit token scope to exactly the job that needs the write, and (b) let you keep `id-token: write` off any read-only summary jobs. If you set repo-default permissions to **Read repository contents and packages permissions** under *Settings -> Actions -> General -> Workflow permissions* (the recommended hardening), the per-job `permissions:` blocks already declare every write the samples need, so the default-read posture is non-blocking.
- **No raw secrets in pipeline YAML or config.** ITSM secrets (when enabled) resolve from Azure Key Vault or CI-native secrets; bearer tokens live in agent memory only.
- **Step-level `env:` mapping** - secrets are mapped into the ITSM step's environment variables, not passed on the PowerShell command line. They never appear in process listings, rendered step inputs, or CI logs.
- **Approval gates** - require manual approval before the Production wave (section 8).
- **Branch protection** - require pull-request reviews for changes to pipeline definitions.
- **TLS 1.2+** is enforced before every HTTP call in the module.
- **CSV-injection sanitisation** - every CSV field produced by the module is neutralised for Excel formula injection (`=`, `+`, `-`, `@`, tab leaders), and CR/LF stripped (v0.7.0+).
- **HTML-escaping** - free-text fields rendered into ITSM tickets are HTML-escaped to defend against ITSM-side HTML injection.

---

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Azure CLI not authenticated` | Federated credential subject claim does not match the trigger that started the run (e.g. you triggered via `workflow_dispatch` from `production` environment but only federated `refs/heads/main`). | Add a federated credential for the actual subject claim (section 3.1). |
| `No clusters found` | Identity does not see the subscription, or clusters are not `Connected`. | Verify the role assignment scope; confirm cluster state in Azure Portal. The resource-graph extension is auto-installed by the pipelines. |
| `Permission denied applying tags` | Identity is missing `Microsoft.Resources/tags/write`. | Grant per section 4. Same permission covers the v0.7.1 sideloaded-workflow tag writes (`UpdateSideloaded`, `UpdateVersionInProgress`). |
| `Update failed to start` | Cluster is not in `Ready` state, or another update is in progress. | Check cluster health and update state in Azure Portal; review pipeline logs. |
| Apply Updates reports `ScheduleBlocked` for an unexpected cluster | Tag is set but the current UTC time is outside the window, or an `UpdateExclusions` blackout is active. | Confirm the tag value with `Test-AzureLocalUpdateScheduleAllowed` (section 8). |
| Apply Updates reports `SideloadedBlocked` | Cluster has `UpdateSideloaded=False`. | Operator must stage the sideloaded payload and flip the tag, or run `Reset-AzureLocalSideloadedTag` after the next successful run. |
| Fleet Update Status leaves a cluster's update missing from `update-runs.csv` | Pre-v0.7.2: `cp1252` warnings on `az rest` output corrupted JSON parsing. | Upgrade to v0.7.2+ (`--only-show-errors` is now passed everywhere). |
| `429 TooManyRequests` from ARM during fleet operations | Throttle limit too high for the subscription topology. | Reduce `throttle_limit`; consider matrix-by-subscription (section 9). |
| ITSM step always creates duplicates | `u_azlocal_dedupe_key` column was not indexed during ServiceNow setup. | Index it. See [ITSM/README.md section 3.2](../ITSM/README.md#32-add-the-five-custom-fields-on-the-incident-table). |

For ITSM-specific failures, the troubleshooting matrix in [`ITSM/README.md` section 9](../ITSM/README.md#9-troubleshooting) is more specific.

---

## 13. File layout

```text
Automation-Pipeline-Examples/
  README.md                           # This file.
  .itsm/                              # Ready-to-copy ITSM connector config.
    azurelocal-itsm.yml               #   - Matrix config (secrets, defaults, triggers).
    templates/
      incident-body.md                #   - Mustache-style ticket body template.
  github-actions/
    Step.1_inventory-clusters.yml            # 1. Inventory.
    Step.2_manage-updatering-tags.yml        # 2. Apply UpdateRing / UpdateWindow / UpdateExclusions tags.
    Step.4_assess-update-readiness.yml       # 3. Pre-flight readiness report (v0.7.0).
    Step.5_apply-updates.yml                 # 4. Apply updates to one UpdateRing (with optional ITSM step, v0.7.4).
    Step.6_fleet-update-status.yml           # 5. Scheduled fleet update-status snapshot (daily 06:00 UTC).
    Step.7_fleet-health-status.yml           # 6. Scheduled fleet 24-hour health-check failure report (daily 07:00 UTC, v0.7.65).
    Step.3_apply-updates-schedule-audit.yml  # 7. Weekly read-only audit: UpdateWindow tags vs apply-updates cron (Mon 05:00 UTC, v0.7.65).
  azure-devops/
    Step.1_inventory-clusters.yml
    Step.2_manage-updatering-tags.yml
    Step.4_assess-update-readiness.yml
    Step.5_apply-updates.yml
    Step.6_fleet-update-status.yml
    Step.7_fleet-health-status.yml
    Step.3_apply-updates-schedule-audit.yml
```

---

## Appendix A: Pipeline reference

This appendix summarises each pipeline's inputs and outputs without duplicating the YAML.

### Default triggers and schedules (at a glance)

The table below is the ground truth for what each shipped YAML does **out of the box**. Three of the seven pipelines (`fleet-update-status`, `fleet-health-status`, `apply-updates-schedule-audit`) and one optional (`inventory-clusters` weekly) are pre-wired with `schedule:` (GH) / `schedules:` (ADO) blocks. The remaining three (`manage-updatering-tags`, `assess-update-readiness`, `apply-updates`) are manual-only by design.

| Pipeline | GitHub Actions trigger | Azure DevOps trigger | Notes |
|---|---|---|---|
| `inventory-clusters` | `workflow_dispatch` + `schedule: cron '0 6 * * 1'` (Mondays 06:00 UTC) | `trigger: none` + `schedules: cron '0 6 * * 1'` | Weekly drift detection. Edit the cron to change cadence. |
| `manage-updatering-tags` | `workflow_dispatch` only | `trigger: none` (manual only) | Runs on-demand whenever you edit the CSV. |
| `assess-update-readiness` | `workflow_dispatch` only | `trigger: none` (manual only) | Run on demand before each Apply Updates window, or wire your own schedule. |
| `apply-updates` | `workflow_dispatch` only | `trigger: none` (manual only) | **No schedule shipped** - see the warning in A.4 below. The cluster `UpdateWindow` / `UpdateExclusions` tags only gate updates *while the pipeline is running*; they do **not** start the pipeline. |
| `fleet-update-status` | `workflow_dispatch` + `schedule: cron '0 6 * * *'` (daily 06:00 UTC) | `trigger: none` + `schedules: cron '0 6 * * *'` | Daily fleet update snapshot. |
| `fleet-health-status` (v0.7.65) | `workflow_dispatch` + `schedule: cron '0 7 * * *'` (daily 07:00 UTC) | `trigger: none` + `schedules: cron '0 7 * * *'` | Daily 24-hour health-check snapshot. Offset by one hour from `fleet-update-status` to avoid contention. |
| `apply-updates-schedule-audit` (v0.7.65) | `workflow_dispatch` + `schedule: cron '0 5 * * 1'` (Mondays 05:00 UTC) | `trigger: none` + `schedules: cron '0 5 * * 1'` | Weekly read-only drift advisor: compares apply-updates cron(s) to `UpdateWindow` tags. Runs before the daily fleet pipelines so its annotations are first on Monday mornings. |

> **All times are UTC.** GitHub Actions and Azure DevOps schedules both run on UTC; convert from your local timezone when picking cron values. Both platforms can delay scheduled runs by several minutes during high-load periods - do not rely on second-precision alignment.
>
> **GitHub Actions only**: scheduled workflows are **automatically disabled after 60 days of repository inactivity** (no commits, PRs, or issue activity). Re-enable them via the Actions UI or run any push. Azure DevOps schedules do not have this auto-disable behaviour.

### A.1 Inventory Clusters

| Aspect | Value |
|---|---|
| **Purpose** | Enumerate every Azure Local cluster the identity can see and export to CSV. |
| **Inputs** | None. |
| **Trigger** | Manual (`workflow_dispatch` / **Run pipeline** button) **plus** weekly scheduled run on Mondays at 06:00 UTC (`cron '0 6 * * 1'`). Edit the cron in the YAML to change the day / time. |
| **Artefacts** | `cluster-inventory.csv` (one row per cluster, includes current `UpdateRing` / `UpdateWindow` / `UpdateExclusions` and sideloaded-workflow tags). |
| **When to run** | First run of a new estate; periodically (default weekly) to detect new clusters or tag drift. |

### A.2 Manage UpdateRing Tags

| Aspect | Value |
|---|---|
| **Purpose** | Bulk-apply `UpdateRing`, `UpdateWindow`, `UpdateExclusions` tags from a CSV. |
| **Inputs** | `csv_path` (required). |
| **Trigger** | Manual only (`workflow_dispatch` / **Run pipeline** button). No schedule shipped - this is a deliberate change-controlled operation that should follow a CSV edit + review. Add a `schedule:` / `schedules:` block if your CSV is auto-generated and you want periodic re-application. |
| **Artefacts** | Pipeline log with added / updated / unchanged counts per cluster. |
| **When to run** | After editing the inventory CSV; whenever ring membership or maintenance windows change. |

### A.3 Assess Update Readiness

| Aspect | Value |
|---|---|
| **Purpose** | Pre-flight, report-only readiness + blocking-health snapshot for a single `UpdateRing`. **Always succeeds** - per-cluster failures show up as JUnit test failures. |
| **Inputs** | `update_ring` (required), `throttle_limit` (optional). |
| **Trigger** | Manual only (`workflow_dispatch` / **Run pipeline** button). No schedule shipped. To run automatically (e.g. 24-48 hours ahead of every Apply Updates window), add a `schedule:` / `schedules:` block to the YAML - for example `cron '0 6 * * 5'` to run every Friday at 06:00 UTC ahead of weekend maintenance windows. |
| **Artefacts** | `readiness.xml`, `readiness.csv`, `health-blocking.xml`, `health-blocking.csv`. |
| **When to run** | Before an Apply Updates run; or on a schedule a day or two ahead of the maintenance window. |

### A.4 Apply Updates

| Aspect | Value |
|---|---|
| **Purpose** | Apply updates to clusters filtered by `UpdateRing` tag value. |
| **Inputs** | `update_ring` (required), `update_name` (optional - leave blank for latest), `dry_run` (optional), `throttle_limit` (optional). **v0.7.4 adds** `raise_itsm_ticket`, `itsm_config_path`, `itsm_dry_run`, `itsm_force_create` (all optional, defaults preserve existing behaviour). |
| **Trigger** | **Manual only by default** (`workflow_dispatch` / **Run pipeline** button). **No schedule is shipped** - you must add one. See the **mandatory customisation note below** and the schedule-alignment guidance in [section 8](#8-scheduling-maintenance-windows-and-change-freeze-periods). |
| **Artefacts** | `update-results.xml` (JUnit, one cluster per test), `update-logs/*` (CSV + detail). When ITSM is enabled: `itsm-results.csv`, `itsm-results.xml`. |
| **When to run** | During the maintenance window for each ring, after the readiness assessment is reviewed. |

> **MANDATORY CUSTOMISATION: the Apply Updates pipeline does not ship with a schedule.** The cluster `UpdateWindow` / `UpdateExclusions` tags **only gate updates *while the pipeline is already running***; they do **not** start the pipeline. If you (a) use `UpdateWindow` tags to define when updates may be installed and (b) leave the shipped `Step.5_apply-updates.yml` with `workflow_dispatch` only (GH) / `trigger: none` (ADO), **no updates will ever be applied automatically** - the pipeline will simply never start during the window.
>
> Add a `schedule:` (GitHub Actions) / `schedules:` (Azure DevOps) block to `Step.5_apply-updates.yml` that fires at (or a few minutes before) the start of every `UpdateWindow` you have tagged. One cron entry per distinct window value. Worked examples and the per-cluster scheduling model are in [section 8](#8-scheduling-maintenance-windows-and-change-freeze-periods).

### A.5 Fleet Update Status

| Aspect | Value |
|---|---|
| **Purpose** | Daily fleet-wide snapshot of cluster update state. Read-only. |
| **Inputs** | Scope (`-AllClusters` or `-ScopeByUpdateRingTag`), `throttle_limit` (optional). |
| **Trigger** | Manual (`workflow_dispatch` / **Run pipeline** button) **plus** scheduled daily at 06:00 UTC (`cron '0 6 * * *'`). Edit the cron in the YAML to change cadence. |
| **Artefacts** | `readiness-status.xml` / `.csv` / `.json`, `cluster-inventory.csv`, `update-summaries.csv`, `available-updates.csv`, `update-runs.csv`. |
| **When to run** | Hands-off scheduled. Trigger manually for ad-hoc reporting. |

### A.6 Fleet Health Status (v0.7.65)

| Aspect | Value |
|---|---|
| **Purpose** | Daily fleet-wide snapshot of **24-hour system health-check failures** surfaced by every Azure Local cluster the identity can see. **Independent of update activity** - clusters that are "up to date" can still surface Critical / Warning issues that need operator triage. Read-only. |
| **Inputs** | `severity` (optional - `Critical`, `Warning`, or `All`; default `All`), `update_ring_tag` (optional - narrow to one wave), `throttle_limit` (optional). |
| **Trigger** | Manual (`workflow_dispatch` / **Run pipeline** button) **plus** scheduled daily at 07:00 UTC (`cron '0 7 * * *'`). Deliberately offset by one hour from `fleet-update-status` (06:00 UTC) to avoid agent and ARM contention. Edit the cron in the YAML to change cadence. |
| **Artefacts** | `fleet-health-status.xml` (JUnit, one `<testcase>` per failing check, grouped under `Critical Health Failures` / `Warning Health Failures` testsuites), `fleet-health-detail.csv` (one row per failing check), `fleet-health-summary.csv` (aggregated by `FailureReason` + `Severity`), markdown job summary. |
| **When to run** | Hands-off scheduled. Trigger manually for ad-hoc fleet-wide health triage outside the daily schedule, especially after operational events (capacity changes, network maintenance, certificate rotations) where health-check failures are expected to spike. |

### A.7 Apply-Updates Schedule Coverage Audit (v0.7.65)

| Aspect | Value |
|---|---|
| **Purpose** | Read-only advisor that compares the cron schedule(s) in your `Step.5_apply-updates.yml` to the `UpdateWindow` tag values present on your clusters, and flags any `(UpdateRing, UpdateWindow)` pair that no cron in `Step.5_apply-updates.yml` will ever reach. Never edits tags or YAML. Calls the [`Test-AzureLocalApplyUpdatesScheduleCoverage`](../README.md#test-azurelocalapplyupdatesschedulecoverage) cmdlet under the covers. |
| **Inputs** | `pipeline_path` (file or folder; default `.github/workflows` on GitHub Actions, `.azure-pipelines` on Azure DevOps - the standard consumer locations for the bundled `Step.5_apply-updates.yml` sample), `lead_time_minutes` (0-60, default 5), `include_untagged` (default false), `module_version` (optional). |
| **Trigger** | Manual (`workflow_dispatch` / **Run pipeline** button) **plus** scheduled weekly on Mondays at 05:00 UTC (`cron '0 5 * * 1'`). Deliberately runs before the daily `fleet-update-status` (06:00 UTC) and `fleet-health-status` (07:00 UTC) pipelines so its drift annotations land at the top of the operator's Monday-morning inbox. Edit the cron in the YAML to change cadence. |
| **Artefacts** | `schedule-coverage-audit.xml` (JUnit, one `<testcase>` per `(UpdateRing, UpdateWindow)` pair, uncovered = `<failure>`), `schedule-coverage-audit.csv` (full Audit view with `Status` / `Recommendation` columns), `schedule-coverage-matrix.csv` (every distinct `(Ring, Window)` pair with its required cron), `schedule-coverage-recommend.md` (ready-to-paste GH Actions + Azure DevOps cron blocks), markdown step summary. |
| **When to run** | Hands-off scheduled. Trigger manually whenever you have just tagged a new ring or changed a maintenance window - see the [end-to-end runbook in section 8.3](#83-end-to-end-runbook-apply-updates-schedule-coverage-audit). |
| **RBAC** | Read-only - same as A.1 (`Reader` on the cluster scope plus `Microsoft.ResourceGraph/resources/read`). No write actions are ever taken. |

---

## Appendix B: Release history

The body of this document tracks **v0.7.70** behaviour. Older versions are preserved below for reference.

### B.1 v0.7.70 (current)

> **Backward compatible.** All v0.7.70 changes are additive over v0.7.69. The Step.0 validation pipeline (`Step.0_authentication-test.yml`) is repositioned from a one-shot smoke test to a recurring **Authentication Validation and Subscription Scope Report**; the existing inline-script structure is preserved underneath. Pipeline pin bumps to `'0.7.70'`; refresh existing copies with `Update-AzureLocalPipelineExample`.

- **Step.0 repositioned as a recurring audit (`Step.0_authentication-test.yml`, GH + ADO).** Renamed from "Authentication Validation Test" to **"Step.0 - Authentication Validation and Subscription Scope Report"**. Now emits a **JUnit XML** report (Authentication / Subscription Scope / Resource Graph Reachability suites - one testcase per subscription accessible to the pipeline identity), a **markdown summary** with the subscription count + per-subscription detail table (rendered in the GitHub Checks UI via `dorny/test-reporter@v3` and the ADO **Tests** + **Summary** tabs via `PublishTestResults@2` + `##vso[task.uploadsummary]`), and a `auth-report` artifact (XML + `subscriptions.json` + `subscriptions.csv`). Operator guidance updated: run the validation periodically (recommended monthly, or after any RBAC change in the tenant) instead of deleting the file after the first green run - drift in subscription scope is the earliest signal that downstream fleet reports are about to under- or over-count clusters.
- **New cmdlet `Get-AzLocalFleetHealthOverview`.** ARG-first fleet health summary - one row per cluster, joining `microsoft.azurestackhci/clusters` with the cluster's `updateSummaries` extensibility resource via a single Azure Resource Graph batch read for fleet-scale performance. 12 columns including `ClusterName`, `ClusterPortalUrl`, `HealthStatus`, `UpdateStatus`, `CurrentVersion`, `SbeVersion`, `AzureConnection`, `LastChecked`, `HealthResultsAgeDays`. Supports `-SubscriptionId`, `-UpdateRingTag` (incl. wildcard `***` + semicolon-list), `-ExportPath`, `-PassThru`.
- **Step.6 Fleet Update Status pipeline (`Step.6_fleet-update-status.yml`, GH + ADO) - new "Update Run History and Error Details" section.** A new `<testsuite name="Update Run History and Error Details">` in the JUnit XML and a matching `### Update Run History and Error Details` markdown table in the run summary surface up to 25 of the most recent unresolved Failed update runs across the fleet (last 30 days). Each row links to the Azure portal `SingleInstanceHistoryDetails` deep-link and includes Status / CurrentStep / Duration / LastUpdated / DeepestErrMsg for at-a-glance triage. Sourced from `Get-AzureLocalUpdateRunFailures -State Failed -OnlyUnresolved` (ARG-first, fleet-scale).
- **Step.7 Fleet Health Status pipeline (`Step.7_fleet-health-status.yml`, GH + ADO) - cluster portal hyperlinks + 3 new detailed columns + new Fleet Health Overview section.** Summary and Detailed Results tables now render cluster cells as `[ClusterName](portalUrl)` markdown links. Detailed Results adds three columns: `Failure Remediation` (auto-renders as `[link](url)` when the value starts with `https://`), `Target Resource Name`, and `Target Resource Type`. A new `### Fleet Health Overview (fleet rollup)` section calls `Get-AzLocalFleetHealthOverview` and publishes `fleet-health-overview.csv` / `.json` to the Reports list.
- **`Test-AzureLocalApplyUpdatesScheduleCoverage` Audit rows now carry a `Section` discriminator** (`Schedule` for ring-level rows, `Cron` for cron-coverage rows). Default sort is Schedule-section first, then cron coverage. `-View Recommend` emits a multi-section markdown report with "add these rings to apply-updates-schedule.yml" first, then the cron-paste section.
- **`Get-AzureLocalFleetHealthFailures` Summary now sorts Critical-first** (Severity then ClusterCount desc then FailureCount desc). Detail rows gain `TargetResourceName`, `TargetResourceType`, and `ClusterPortalUrl`. Summary rows gain `AffectedClusterPortalUrls` aligned 1:1 with `AffectedClusters` (semicolon-space separator).
- **New durable Live-Integration Pester suite (`Tests/Live-Integration.Tests.ps1`).** 16 tests across 4 Describe blocks, all tagged `Live` and excluded from the default 565-test unit run. Asserts the v0.7.70 ARG-first projections (`Get-AzLocalFleetHealthOverview`, `Get-AzureLocalFleetHealthFailures`, `Get-AzureLocalUpdateRunFailures`) against a real Azure Local fleet. Each Describe auto-skips when `az` is not logged in or not pointed at the expected subscription, so the suite is safe to leave permanently in the repo. Opt-in via `.\Tests\Invoke-Tests.ps1 -IncludeLive` (unit + live) or `-LiveOnly` (live only). Validated end-to-end against the AdaptiveCloudLab 20-cluster fleet (49 unresolved health failures, 9 unresolved Failed update runs) in 1m26s.
- **Module version pin bumped to 0.7.70** in every production sample YAML. Run `Update-AzureLocalPipelineExample` (preferred, marker-aware) or `Copy-AzureLocalPipelineExample -Update` after upgrading.

### B.2 v0.7.69

> **Hard break vs v0.7.68.** Schema `schemaVersion: 1` for `apply-updates-schedule.yml` is the first stable version of this file. If you were running an experimental schedule from earlier development builds, regenerate via `New-AzLocalApplyUpdatesScheduleConfig`.

- **Ring-aware apply-updates schedule (5 new cmdlets).** Day-grain `apply-updates-schedule.yml` (schema v1) is now the single source of truth for *which `UpdateRing` is eligible on a given UTC date*. Three independent layers control "what runs when":
  1. **This file (day-grain)** says WHICH `UpdateRing` tag values are eligible TODAY.
  2. **The Step.5 cron schedule (intra-day-grain)** says HOW OFTEN the apply-updates job wakes up.
  3. **The per-cluster `UpdateWindow` tag (minute-grain)** says WHEN, during an eligible day, the actual update is allowed to start.
- New cmdlets: `Get-AzLocalApplyUpdatesScheduleConfig` (parse + validate), `Resolve-AzLocalApplyUpdatesScheduleRing` (date -> ring with cycle-week math + union semantics on overlap), `Get-AzLocalApplyUpdatesScheduleNextFirings` (preview the next N days), `New-AzLocalApplyUpdatesScheduleConfig` (strawman generator from live fleet `UpdateRing` tags; every row emitted commented out by design so the apply-updates pipeline hard-stops at the reader until the operator reviews and uncomments at least one row), `Update-AzLocalApplyUpdatesScheduleConfig` (idempotent recipe-driven migrator; recipes table ships empty for v1).
- **`Test-AzureLocalApplyUpdatesScheduleCoverage` gained `-SchedulePath` (two-way ring diff).** Emits two new status rows: `RingMissingFromSchedule` (fleet ring with no schedule row) and `RingOrphanedInSchedule` (schedule ring no cluster carries). Surfaced in the summary table, the JUnit XML failure list, and the Step.3 Markdown summary.
- **`Step.5_apply-updates.yml` (GH + ADO)** now resolves the `UpdateRing` value from `apply-updates-schedule.yml` on every **scheduled** firing. Manual `workflow_dispatch` (GH) / non-`Schedule` `Build.Reason` (ADO) runs still honour the operator-supplied `-UpdateRingValue` input verbatim, so back-compat for ad-hoc maintenance is preserved.
- **Concurrency on Step.5.** GitHub Actions gained a workflow-level `concurrency:` block to prevent overlapping cron firings. Azure DevOps has no first-class YAML concurrency primitive; the ADO version documents the equivalent **Pipeline Settings -> Triggers -> Limit concurrent runs** option in a banner comment.
- **`Step.3_apply-updates-schedule-audit.yml` (GH + ADO)** gained a `schedule_path` / `schedulePath` input (defaulted to the standard layout), a `debug` toggle for self-service triage (`$VerbosePreference=Continue`, `$DebugPreference=Continue`, plus a one-shot environment snapshot), and surfaces the new `RingMissingFromSchedule` / `RingOrphanedInSchedule` counts in the summary + JUnit failure list. When `pipeline_path` is empty and `schedule_path` is set, the audit runs schedule-file-only.
- **`apply-updates-schedule.example.yml` ships as documentation only.** `Copy-AzureLocalPipelineExample` / `Update-AzureLocalPipelineExample` do **not** touch it. Operators run `New-AzLocalApplyUpdatesScheduleConfig` to generate a strawman starting from their live fleet's `UpdateRing` tag values.
- **Module version pin bumped to 0.7.69** in every production sample YAML. Run `Update-AzureLocalPipelineExample` (preferred, marker-aware) or `Copy-AzureLocalPipelineExample -Update` after upgrading.
- **Test suite: 540 passed / 0 failed / 0 skipped.** 19 new tests cover reader, resolver, next-firings, generator, and update across the new ring-aware schedule cmdlets.

### B.3 v0.7.68

- **ARG-first refactor of every fleet-scale read cmdlet.** Seven cmdlets - `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalClusterUpdateReadiness`, `Test-AzureLocalClusterHealth`, `Get-AzureLocalFleetProgress`, `Get-AzureLocalFleetStatusData`, `New-AzureLocalFleetStatusHtmlReport` - and the new `Get-AzureLocalUpdateRunFailures` and the existing `Get-AzureLocalUpdateRuns` are now backed by a single Azure Resource Graph batch query each. No more N-way per-cluster ARM calls, no more `Start-Job` fan-out on the read path, no more 6-hour-runner-window failure mode on 1000+ cluster fleets. Read pipelines on a 1500-cluster fleet that previously consumed the bulk of a runner window complete in seconds.
- **`-ThrottleLimit` removed from those nine cmdlets.** The value was a silent no-op against an ARG batch read, so the parameter is now explicitly absent and any pipeline still passing it fails parameter binding loudly. All bundled pipeline YAMLs were updated to stop passing `-ThrottleLimit`. The apply-side cmdlet `Start-AzureLocalClusterUpdate` retains its internal job-pool throttle (no operator-facing parameter). See [Section 9](#9-tuning-throughput--throttlelimit) for the migration story.
- **New cmdlet `Get-AzureLocalUpdateRunFailures`.** ARG-only cmdlet that pulls failure rows out of `microsoft.azurestackhci/clusters/updates/updateruns` with a 9-deep `mv-expand` over the nested `actions[]` tree, returning a flat row per failed step with full breadcrumb path, error code, and operator-friendly message. Used by Step.5 Apply Updates post-mortem and ad-hoc triage. No equivalent ARM read path; this cmdlet is intentionally ARG-only.
- **`Update-AzureLocalPipelineExample` - marker-aware in-place YAML upgrade.** New cmdlet that refreshes a customer's copy of any bundled pipeline YAML to the version shipped with the current module **while preserving operator edits inside `BEGIN-AZLOCAL-CUSTOMIZE:<region>` / `END-AZLOCAL-CUSTOMIZE:<region>` marker pairs**. Customer-side cron schedules in `schedule-triggers` and ITSM secret bindings in `itsm-secrets` (Step.5 only) survive a module upgrade. Supports `-WhatIf`, `-Force`, and `-PassThru`. Recommended companion to `Copy-AzureLocalPipelineExample`: copy on first install, update on every module bump.
- **`Step.N - <description>` display-name prefix on every bundled GitHub Actions workflow and Azure DevOps pipeline.** Display ordering in the Actions / Pipelines UI now matches the runbook order in this README (Step.0 auth test, Step.1 inventory, Step.2 manage tags, Step.3 schedule audit, Step.4 readiness, Step.5 apply, Step.6 fleet status, Step.7 fleet health). See [Section 1.1](#11-why-the-pipelines-are-named-stepn---description) for the rationale.
- **Latent single-element-array unwrap bug fixed** in `Get-AzureLocalUpdateRuns` and `Get-AzureLocalClusterUpdateReadiness`. The per-cluster lookup pattern `$x = if (ContainsKey) { @($list) } else { @() }` silently unwrapped a single-element `Object[]` to its bare element under the if-block's pipeline return semantics on PowerShell 5.1, causing one-update-per-cluster results to be dropped. Replaced with assignment outside the if-block.
- **`Invoke-AzResourceGraphQuery` retries on 429.** The shared helper behind every ARG-first cmdlet now inspects the `Retry-After` response header when present and otherwise applies bounded exponential backoff capped at the documented ARG throttling envelope. Large fleet sweeps no longer fall over at the throttling boundary.
- **Test suite: 511 passed / 0 failed / 0 skipped.** Five previously-skipped Describes for the ARG-first read cmdlets were rewritten against the new code paths and now pass deterministically with `InModuleScope` + `function global:az { ... }` shim + `Mock Invoke-AzResourceGraphQuery`; the five rewritten Describes contribute 10 new tests. The v0.7.68 entry also adds +4 throttle-handling tests against `Invoke-AzResourceGraphQuery` (retry-then-succeed on 429, max-retries-exhausted, no-retry on non-throttle errors, diagnostic flags reset per call) and +3 `Get-AzureLocalFleetStatusData` schema-contract tests (top-level shape + types, `ValidateNotNullOrEmpty` on `-ClusterResourceIds`, `ModuleVersion` field tracks the module-scope constant).
- **Module version pin bumped to 0.7.68 in every production sample YAML.** Run `Update-AzureLocalPipelineExample` (preferred) or `Copy-AzureLocalPipelineExample -Update` after upgrading.

### B.4 v0.7.66

- **Fixed (critical) - `Get-AzureLocalFleetHealthFailures` failed JSON parsing on hosted Windows runners when the Azure CLI emitted a cp1252 encoding warning to stderr.** On `windows-latest` GitHub Actions runners (and any ADO Windows agent whose console code page is `cp1252`) the Azure CLI's underlying Python layer can surface `WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.` to stderr; the shared `Invoke-AzResourceGraphQuery` helper was capturing `2>&1` into a single merged stream and feeding it to `ConvertFrom-Json`, which then threw `Unexpected character encountered while parsing value: W. Path '', line 0, position 0.` **The actual fix** is the post-capture stream split: stderr lines surface as `[System.Management.Automation.ErrorRecord]` objects under `2>&1`, stdout lines as strings, and only the string stream is fed to `ConvertFrom-Json`. (The helper already passed `--only-show-errors` since v0.7.2, matching the existing `Invoke-AzRestJson` hardening, but the cp1252 encode warning can still leak through on some character paths, hence the belt-and-braces split.) The helper also sets `PYTHONIOENCODING=utf-8` as **cosmetic defence-in-depth only** - this is a structural no-op for stock `az.cmd` because `az.cmd` launches Python with `-I` (isolated) which implies `-E` and forces Python to ignore every `PYTHON*` env var per [Azure/azure-cli#28497](https://github.com/Azure/azure-cli/issues/28497) and the v0.7.2 root-cause analysis; it only takes effect on hosts that have manually patched `az.cmd` to remove `-I`.
- **Fixed (critical) - `Step.3_apply-updates-schedule-audit.yml` default `pipeline_path` only existed in this module's source repo.** The shipped default was `AzLocal.UpdateManagement/Automation-Pipeline-Examples` (i.e. the in-source path for *this* repo); every default-trigger run in a consumer repo therefore failed with `PipelineYamlPath '...' does not exist on the runner` before the schedule advisor could emit its JUnit XML, which then crashed `dorny/test-reporter` with `No test report files were found`. Defaults are now `'.github/workflows'` on GH Actions and `'.azure-pipelines'` on Azure DevOps - the standard consumer locations - and the path-missing error message now lists which common pipeline folders **do** exist in the checked-out repo so the operator knows what value to pass via `workflow_dispatch` / queue-time override.
- **Module version pin bumped to 0.7.66 in every production sample YAML that installs the module from PowerShell Gallery (14 across GitHub Actions and Azure DevOps; the two Step.0 validation YAMLs do not install the module and so are not version-pinned).** Run `Copy-AzureLocalPipelineExample -Update` after upgrading to refresh the samples in your repo.

#### v0.7.66 UX + capability refresh

- **Status emojis in the Fleet Update Status summary.** `Step.6_fleet-update-status.yml` on both platforms now uses a green tick / red cross / refresh / yellow circle / info glyph in the `Critical Health` and `Primary Status` summary tables instead of the legacy `[ok] / [fail] / [ready] / [running] / [blocked] / [info]` bracket markers. Plain markdown, so it renders identically on the GH Actions step summary, the ADO pipeline run extension, and any markdown viewer.
- **Generation timestamp in the Fleet Update Status H2 heading.** The summary heading on both platforms is now `## Fleet Update Status Summary  _(generated YYYY-MM-DD HH:MM:SS UTC)_`. Operators no longer have to cross-reference the pipeline run start time to know when the data was collected.
- **Failed clusters appear before passing clusters in the JUnit per-cluster block.** The per-cluster `<testcase>` ordering in `Step.6_fleet-update-status.yml` (both platforms) is now bucketed: failed first (sorted alphabetically), then passed (sorted alphabetically). Failing clusters lead the dorny/test-reporter view (GitHub) and the Tests tab (Azure DevOps).
- **Every downloadable artifact carries a UTC timestamp suffix.** All `actions/upload-artifact` (GH) and `PublishBuildArtifacts@1` / `PublishPipelineArtifact@1` (ADO) names now follow `azlocal-<purpose>_yyyyMMdd_HHmmss`. Two runs of the same pipeline on the same day produce distinct zip downloads (`azlocal-fleet-update-status-report_20260518_140000.zip` vs `azlocal-fleet-update-status-report_20260518_180000.zip`). Each job computes the timestamp once in a dedicated `Compute Artifact Timestamp` step. Affected artifact renames: `fleet-status-reports` -> `azlocal-fleet-update-status-report`; `fleet-health-reports` -> `azlocal-fleet-health-status-report`; `cluster-inventory` -> `azlocal-cluster-inventory`; `updatering-tag-logs` -> `azlocal-updatering-tag-logs`; `schedule-coverage-reports` / `ScheduleCoverageReports` -> `azlocal-apply-updates-schedule-audit-report`; `readiness-report` -> `azlocal-apply-updates-readiness-report`; `readiness-assessment` -> `azlocal-readiness-assessment-report`; `update-logs` -> `azlocal-apply-updates-logs`; `itsm-results` -> `azlocal-apply-updates-itsm-results`.
- **Pipeline `UpdateRing` inputs accept multi-value lists and the literal `***` wildcard.** Every pipeline that exposes `update_ring:` (GH `workflow_dispatch`) or `updateRing:` (ADO `parameters:`) now accepts:
  - A single ring (unchanged): `Wave1`
  - A semicolon-delimited list: `Prod;Ring2` (whitespace around each ring is trimmed)
  - The wildcard `***` (three stars, deliberate gesture) to match every cluster that **has** a non-empty `UpdateRing` tag. **Untagged clusters are excluded** so the wildcard preserves the existing opt-in gate. A single `*`, double `**`, or quadruple `****` are all REJECTED by the cmdlet's `[ValidatePattern]` so a one-character typo can no longer accidentally scope a fleet-wide write.

  The ADO `Step.5_apply-updates.yml` lost its closed `values:` enum (kept `type: string` so users still get a free-text editor in the ADO run dialog). The cmdlet-side `[ValidatePattern]` is tightened to `^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$` on 14 cmdlets that take `-UpdateRingValue` and on the 1 cmdlet (`Get-AzureLocalFleetHealthFailures`) that takes `-UpdateRingTag`. Hostile/malformed inputs (spaces, embedded quotes, `<script>`, leading/trailing `;`) are still rejected at the parameter binder before any Azure call.
- **New private helper `ConvertTo-AzLocalUpdateRingKqlFilter`.** Centralises the KQL clause construction for the three forms above. Returns `| where isnotempty(tags['UpdateRing'])` for `***` (matches only tagged clusters), a `| where tags['UpdateRing'] =~ 'single'` clause for a single value, and a `| where tags['UpdateRing'] in~ ('a','b')` clause for a list. Embedded single quotes are doubled (KQL string-literal escape). All 12 ARG-query call sites in the public cmdlets now go through this helper.

### B.5 v0.7.65

- **`Test-AzureLocalApplyUpdatesScheduleCoverage` cmdlet + `apply-updates-schedule-audit` pipelines (GitHub Actions + Azure DevOps).** Read-only weekly audit (Mon 05:00 UTC + manual) that compares the cron schedule(s) in your `apply-updates` pipeline to the `UpdateRing` / `UpdateWindow` tags actually present on your clusters and flags any pair that no cron will ever reach. Three views (`Audit`, `Matrix`, `Recommend`), per-segment cron generation for multi-window tags (`Sat-Sun_02:00-06:00;Mon-Fri_22:00-04:00`) and day ranges (`Fri-Mon`), configurable `-LeadTimeMinutes` (0-60, default 5). Each pipeline run emits JUnit XML (one `<testcase>` per `(Ring, Window)`), three CSV/MD exports (`schedule-coverage-audit.csv`, `schedule-coverage-matrix.csv`, `schedule-coverage-recommend.md`), and a Markdown step summary. Full step-by-step runbook in [Section 8.3](#83-end-to-end-runbook-apply-updates-schedule-coverage-audit); reference card in [Appendix A.7](#a7-apply-updates-schedule-coverage-audit-v0765).
- **`Get-AzureLocalFleetHealthFailures` cmdlet + `fleet-health-status` pipelines (GitHub Actions + Azure DevOps).** Dedicated entry point for surfacing the in-flight 24-hour system health-check failures across every readable cluster - independent of update activity (clusters that are already "up to date" can still surface Critical / Warning issues that need triage). Daily 07:00 UTC schedule (offset from `fleet-update-status` at 06:00). JUnit XML grouped under `Critical Health Failures` / `Warning Health Failures` testsuites + per-failure-reason and per-cluster CSV exports + Markdown step summary pivoted by `FailureReason`. Reference card in [Appendix A.6](#a6-fleet-health-status-v0765).
- **`Set-AzureLocalClusterUpdateRingTag` now uses the dedicated `Microsoft.Resources/tags/default` PATCH endpoint** instead of `PATCH`-ing the cluster resource. CI/CD service principals scoped to the built-in **Tag Contributor** role on the cluster (or resource group) can now write `UpdateRing` / `UpdateWindow` / `UpdateExclusions` tags without needing `microsoft.azurestackhci/clusters/write`. If you scoped your tag-management SP to "Contributor" purely as a workaround, you can safely drop it back to **Tag Contributor**. The custom-role guidance in [Section 4.1](#41-custom-role-azure-stack-hci-update-operator-recommended) and the per-step RBAC bullets in [Section 6.3](#63-apply-tags) and [Appendix A.2](#a2-manage-updatering-tags) have been updated accordingly.
- **Pester guardrail prevents pipeline-YAML version drift.** A new Pester context discovers every `*.yml` file under `Automation-Pipeline-Examples/` that installs the module from PSGallery and asserts that the `GENERATED_AGAINST_MODULE_VERSION` constant in each YAML matches the module manifest version. Supports both the inline GitHub Actions shape and the two-line Azure DevOps shape. Build fails if a sample YAML is forgotten when the manifest is bumped.
- **Fleet Update Status summary now reconciles with the JUnit pass/fail counts.** Two bug fixes ensure the summary table always adds up to **Total Clusters**: `Up to Date` now counts both `UpToDate` and `AppliedSuccessfully` states; each cluster is assigned to exactly one primary status via a priority cascade (`Update Failed` -> `Health Failure` -> `SBE Prerequisite Blocked` -> `Update In Progress` -> `Ready for Update` -> `Up to Date` -> `Needs Investigation`).
- **JUnit / step-summary ordering changed** in both `Step.6_fleet-update-status.yml` and `Step.7_fleet-health-status.yml` (both platforms): Summary block FIRST, JUnit Test Results SECOND, so the run-extensions / job-summary view leads with the operator-facing numbers.
- **Module version pin bumped to 0.7.65 in all 13 sample workflow YAMLs** (11 pre-existing + the two new `Step.3_apply-updates-schedule-audit.yml` files). Run `Copy-AzureLocalPipelineExample -Update` after upgrading to refresh the samples in your repo.

### B.5 v0.7.4

- **ITSM Connector - Phase 1 (ServiceNow)**. Apply Updates can now open ServiceNow incidents for clusters that need operator action (`Failed`, `Error`, `HealthCheckBlocked`, `SideloadedBlocked`) via the new `New-AzureLocalIncident` function, with idempotent SHA256 dedupe so re-running the same workflow does not create duplicates. **Fully opt-in** - pipelines that do not set `raise_itsm_ticket=true` are byte-identical to v0.7.3 behaviour. Sample config + Mustache ticket-body template ship at [`./.itsm/`](./.itsm/). Setup, secret sourcing, and troubleshooting documented in [`../ITSM/README.md`](../ITSM/README.md); design + decisions log in [`../ITSM/ITSM-Connector-Plan.md`](../ITSM/ITSM-Connector-Plan.md).
- **OAuth 2.0 `client_credentials`** only in Phase 1. Secrets resolve from Azure Key Vault (`kv://<vault>/<secret>`, **recommended**), environment variables (`env://NAME`, native-secret fallback), or explicit `literal://...` values guarded by `-AllowLiteral`. The pipeline service principal needs `Key Vault Secrets User` on the configured vault; no other new RBAC.
- **DryRun mode** (`-DryRun` on `New-AzureLocalIncident`, or pipeline input `itsm_dry_run=true`) resolves secrets, runs the read-only dedupe lookup, builds the full ticket payload, but does not POST. Output CSV + JUnit projection let you validate the trigger matrix and template rendering before pointing at production ServiceNow.
- **`Test-AzureLocalItsmConnection`** runs the OAuth token grant and a one-row read against `/api/now/table/incident`, matching the least-privilege scope used by ticket creation. Run it manually before flipping `raise_itsm_ticket=true`.
- **New JUnit projection** (`-ExportJUnitPath` on `New-AzureLocalIncident`) emits per-cluster ITSM actions as a JUnit XML artefact - `CreateFailed` -> `<failure>`, `Skipped` / `WhatIf` -> `<skipped>`, default -> success. Consumed by `dorny/test-reporter` / `PublishTestResults@2` so ITSM activity is visible in the Tests tab.
- **Phase 2 (`Sync-AzureLocalIncident` close-out)** and **Phase 3 (Teams + Slack mirror)** are designed in [`ITSM-Connector-Plan.md`](../ITSM/ITSM-Connector-Plan.md) and **deferred** to a future release. The `lifecycle` and `notifications` sections of the config schema are parsed and stored but not yet acted on.

### B.6 v0.7.2

- **Fleet read paths now work as documented under `-ThrottleLimit > 1`**. The `Step.6_fleet-update-status.yml` workflow (and any direct caller of `Get-AzureLocalUpdateRuns`, `Get-AzureLocalUpdateSummary`, or `Get-AzureLocalClusterUpdateReadiness` with `-ThrottleLimit` greater than 1) previously failed for every cluster with `The term 'Get-AzLocalClusterUpdateRuns' is not recognized...` because module-private helpers were not visible inside `Start-Job` child runspaces. Resolved via `& $module { ... }` dispatch through the loaded module's session state. **Action**: re-enable `-ThrottleLimit` in your fleet workflows.
- **Stray `cp1252` warnings no longer break JSON parsing on hosted Windows runners**. Default `windows-latest` GitHub runners and Azure DevOps `windows-2022` agents both run with the `cp1252` console code page; the Azure CLI emitted `WARNING: Unable to encode the output with cp1252 encoding...` on any ARM response containing non-ASCII characters. Captured via `2>&1`, that warning was prepended to the JSON body and silently broke `ConvertFrom-Json`, dropping update runs and available updates from pipeline reports. v0.7.2 passes `--only-show-errors` to every `az rest` and `az graph query` invocation. **No pipeline configuration change required** - upgrade and the runs/summaries are simply complete again.
- Full root-cause writeup: [main README v0.7.2 entry](../README.md#whats-new-in-v072).

### B.7 v0.7.1

- **Sideloaded payload workflow**. Two new tags coordinate human-driven sideloaded update payloads with the apply-updates pipeline:
  - `UpdateSideloaded` (operator-set, `True`/`False`/`1`/`0`) gates `Start-AzureLocalClusterUpdate`. When `False`, the apply-updates pipeline skips the cluster with `Status = SideloadedBlocked`.
  - `UpdateVersionInProgress` (module-managed; do not set manually) holds the staged update name. `Get-AzureLocalUpdateRuns` auto-resets `UpdateSideloaded -> False` and clears `UpdateVersionInProgress` when the latest run is `Succeeded` and its update name matches. Use `-SkipSideloadedReset` on read-only paths.
- **New public function** `Reset-AzureLocalSideloadedTag` for explicit-scope manual reset. Three parameter sets: `-ClusterNames`, `-ClusterResourceIds`, or `-ScopeByUpdateRingTag -UpdateRingValue`. Supports `-WhatIf`/`-Confirm`. Default behaviour requires `latest run = Succeeded` **and** a case-insensitive update-name match against `UpdateVersionInProgress`. `-Force` bypasses the version-match check (still requires `Succeeded` state). Returns one row per cluster with `Action` / `PreviousSideloaded` / `NewSideloaded` / `StagedVersion` / `MatchedRunUpdateName` / `Message`.
- **No new RBAC** - the existing `Microsoft.Resources/tags/read|write` permissions cover it.
- **Fully opt-in** - clusters without the `UpdateSideloaded` tag behave exactly as in v0.7.0.
- Full runbook: [main README sideloaded workflow section](../README.md#7a-sideloaded-payload-workflow-v071).

### B.8 v0.7.0

- **Parallel per-cluster operations**. `Get-AzureLocalClusterUpdateReadiness`, `Test-AzureLocalClusterHealth`, `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`, `Get-AzureLocalUpdateRuns`, and `Set-AzureLocalClusterUpdateRingTag` now run per-cluster ARM calls in parallel `Start-Job` batches. `Invoke-AzureLocalFleetOperation -ThrottleLimit` is honoured end-to-end. Expected 5-10x speedup on 1500-cluster runs.
- **`-ThrottleLimit` is a workflow input** on Apply Updates and Fleet Update Status (default 4, range 1-16).
- **ARG queries paginate**. All scope-resolving queries follow the `$skipToken` until exhausted (previously capped silently at 1000).
- **`-AllClusters` cap removed**. `New-AzureLocalFleetStatusHtmlReport -AllClusters` and `Get-AzureLocalFleetStatusData -AllClusters` no longer truncate at 100; use `-MaxClusters <n>` to trim explicitly.
- **CSV sanitisation**. Every CSV field is protected against Excel formula injection (`=`, `+`, `-`, `@`, tab leaders neutralised, CR/LF stripped).
- **Token refresh mid-run**. `Invoke-AzRestJson` refreshes on HTTP 401 so long-running apply jobs no longer die at the 1-hour token boundary.
- **Schedule-tag parse errors are blocking by default** unless `-Force`. A malformed `UpdateWindow` / `UpdateExclusions` no longer lets the update sneak through with just a warning.

---

## 16. Related documentation

- [Azure Local Update Management module README](../README.md)
- [ITSM Connector setup guide (`ITSM/README.md`)](../ITSM/README.md) - optional, opt-in ServiceNow integration.
- [ITSM Connector design + decisions log (`ITSM/ITSM-Connector-Plan.md`)](../ITSM/ITSM-Connector-Plan.md)
- [Azure Stack HCI documentation](https://learn.microsoft.com/azure-stack/hci/)
- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Azure DevOps Pipelines documentation](https://learn.microsoft.com/azure/devops/pipelines/)
