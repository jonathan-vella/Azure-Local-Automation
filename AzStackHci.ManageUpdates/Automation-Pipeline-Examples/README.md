# CI/CD Pipeline Examples for Azure Local Cluster Update Management

> ⚠️ **Disclaimer**: This module is **NOT** a Microsoft supported service offering or product. It is provided as example code only, with no warranty or official support. Refer to the [MIT license](https://github.com/NeilBird/Azure-Local/blob/main/LICENSE) for further information.

This folder contains example CI/CD pipelines for automating Azure Local cluster update management using GitHub Actions and Azure DevOps.

## Overview

Four pipelines are provided for each platform:

| Pipeline | Description |
|----------|-------------|
| **Inventory Clusters** | Queries all Azure Local clusters and exports inventory to CSV with UpdateRing tag status |
| **Manage UpdateRing Tags** | Creates or updates UpdateRing tags on clusters from a CSV file |
| **Apply Updates** | Applies updates to clusters filtered by UpdateRing tag value |
| **Fleet Update Status** | 📊 Monitors update status across entire fleet with JUnit XML reports for dashboards |

> 📝 **Tip**: For ad-hoc reporting outside of CI/CD, you can also generate a standalone HTML report using `New-AzureLocalFleetStatusHtmlReport`. See [Standalone HTML Report](#standalone-html-report) below.

## Prerequisites

Before using these pipelines, you need:

1. **Azure Subscription** with Azure Local (Azure Stack HCI) clusters
2. **Azure Identity** - Service Principal or Managed Identity (see Authentication Options below)
3. **CI/CD Platform** (GitHub or Azure DevOps)

---

## 🔐 Authentication Options

Microsoft recommends three authentication methods for CI/CD pipelines, listed from **most to least secure**:

| Method | Security | Secrets Required | Best For |
|--------|----------|------------------|----------|
| **🥇 OpenID Connect (OIDC)** | ⭐⭐⭐⭐⭐ | None (secretless) | GitHub Actions, Azure DevOps |
| **🥈 Managed Identity** | ⭐⭐⭐⭐ | None | Self-hosted runners on Azure VMs |
| **🥉 Service Principal + Secret** | ⭐⭐ | Client Secret | Legacy systems only |

> ⚠️ **Important**: Microsoft recommends **OpenID Connect** over client secrets. Client secrets can expire, be leaked, and require rotation. OIDC uses short-lived tokens with no stored secrets.

---

## 🥇 Option 1: OpenID Connect (OIDC) - Recommended

OIDC uses federated identity credentials - your GitHub/Azure DevOps workflow requests a token from Azure without storing any secrets.

### Benefits
- ✅ **No secrets to manage or rotate**
- ✅ **Short-lived tokens** (valid only for workflow execution)
- ✅ **No risk of secret leakage**
- ✅ **Audit trail** of token usage

### Step 1: Create the App Registration

```bash
# Create App Registration (not a full Service Principal)
az ad app create --display-name "AzureLocal-UpdateAutomation-OIDC"

# Note the appId from output - this is your AZURE_CLIENT_ID
```

### Step 2: Create Service Principal and Assign Role

```bash
# Create Service Principal from the App Registration
az ad sp create --id {app-id-from-step-1}

# Assign Azure Stack HCI Administrator role
az role assignment create \
    --assignee {app-id-from-step-1} \
    --role "Azure Stack HCI Administrator" \
    --scope "/subscriptions/{your-subscription-id}"
```

### Step 3: Configure Federated Credentials

#### For GitHub Actions:

```bash
# Create federated credential for GitHub Actions
az ad app federated-credential create \
    --id {app-id-from-step-1} \
    --parameters '{
        "name": "GitHubActions-main",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:{owner}/{repo}:ref:refs/heads/main",
        "audiences": ["api://AzureADTokenExchange"]
    }'

# For workflow_dispatch (manual triggers), add another credential:
az ad app federated-credential create \
    --id {app-id-from-step-1} \
    --parameters '{
        "name": "GitHubActions-workflow-dispatch",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:{owner}/{repo}:environment:production",
        "audiences": ["api://AzureADTokenExchange"]
    }'
```

**Subject claim patterns:**
| Trigger | Subject |
|---------|---------|
| Branch push | `repo:{owner}/{repo}:ref:refs/heads/{branch}` |
| PR | `repo:{owner}/{repo}:pull_request` |
| Environment | `repo:{owner}/{repo}:environment:{env-name}` |
| Tag | `repo:{owner}/{repo}:ref:refs/tags/{tag}` |

#### For Azure DevOps:

```bash
# Create federated credential for Azure DevOps
az ad app federated-credential create \
    --id {app-id-from-step-1} \
    --parameters '{
        "name": "AzureDevOps",
        "issuer": "https://vstoken.dev.azure.com/{organization-id}",
        "subject": "sc://{organization}/{project}/{service-connection-name}",
        "audiences": ["api://AzureADTokenExchange"]
    }'
```

### Step 4: Add GitHub Secrets (No Secret Value!)

| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | App Registration ID |
| `AZURE_TENANT_ID` | Your Entra ID tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID |

> 📝 **Note**: No `AZURE_CLIENT_SECRET` needed with OIDC!

### Step 5: Update Workflow for OIDC

```yaml
jobs:
  update-clusters:
    runs-on: windows-latest
    permissions:
      id-token: write   # Required for OIDC
      contents: read
    
    steps:
    - name: Azure CLI Login (OIDC)
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

> **Reference**: [Use GitHub Actions with OpenID Connect](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)

---

## 🥈 Option 2: Managed Identity (Self-Hosted Runners)

If you run self-hosted GitHub runners or Azure DevOps agents on Azure VMs, use Managed Identity.

### Step 1: Enable Managed Identity on VM

```bash
# Enable system-assigned managed identity
az vm identity assign \
    --name "runner-vm" \
    --resource-group "runners-rg"
```

### Step 2: Assign Role to Managed Identity

```bash
# Get the principal ID of the managed identity
az vm show --name "runner-vm" --resource-group "runners-rg" --query identity.principalId -o tsv

# Assign role
az role assignment create \
    --assignee {principal-id} \
    --role "Azure Stack HCI Administrator" \
    --scope "/subscriptions/{your-subscription-id}"
```

### Step 3: Use in Pipeline

```yaml
- name: Azure CLI Login (Managed Identity)
  uses: azure/login@v2
  with:
    auth-type: IDENTITY
    client-id: ${{ secrets.AZURE_CLIENT_ID }}  # Only for user-assigned identity
```

Or with the PowerShell module:

```powershell
Connect-AzureLocalServicePrincipal -UseManagedIdentity
```

---

## 🥉 Option 3: Service Principal + Client Secret (Legacy)

> ⚠️ **Not Recommended**: Only use this if OIDC and Managed Identity are not available.

### Security Considerations for Client Secrets

If you must use client secrets:

1. **Set short expiration** - Create secrets with 90-day or shorter expiration
2. **Use environment-level secrets** - More secure than repository secrets for public repos
3. **Rotate regularly** - Automate secret rotation before expiration
4. **Limit scope** - Assign least-privilege roles

### Step 1: Create the Service Principal

```bash
# Create Service Principal with Azure Stack HCI Administrator role
az ad sp create-for-rbac \
    --name "AzureLocal-UpdateAutomation" \
    --role "Azure Stack HCI Administrator" \
    --scopes /subscriptions/{your-subscription-id}
```

**Save the output** - you'll need these values:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",      // AZURE_CLIENT_ID
  "displayName": "AzureLocal-UpdateAutomation",
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",       // AZURE_CLIENT_SECRET (expires!)
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"     // AZURE_TENANT_ID
}
```

### Step 2: Add All Secrets to GitHub

| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | The `appId` from Service Principal creation |
| `AZURE_CLIENT_SECRET` | The `password` from Service Principal creation |
| `AZURE_TENANT_ID` | The `tenant` from Service Principal creation |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID |

### Step 3: Workflow Uses JSON Credentials

```yaml
- name: Azure CLI Login (Client Secret)
  uses: azure/login@v2
  with:
    creds: '{"clientId":"${{ secrets.AZURE_CLIENT_ID }}","clientSecret":"${{ secrets.AZURE_CLIENT_SECRET }}","subscriptionId":"${{ secrets.AZURE_SUBSCRIPTION_ID }}","tenantId":"${{ secrets.AZURE_TENANT_ID }}"}'
```

---

## Required Permissions

Whichever authentication method you choose, the identity needs these permissions:

| Permission | Purpose |
|------------|---------|
| `Microsoft.AzureStackHCI/clusters/read` | Read cluster information |
| `Microsoft.AzureStackHCI/clusters/updates/read` | List available updates |
| `Microsoft.AzureStackHCI/clusters/updates/apply/action` | Apply updates |
| `Microsoft.AzureStackHCI/clusters/updateSummaries/read` | Read update summary |
| `Microsoft.AzureStackHCI/clusters/updateRuns/read` | Monitor update progress |
| `Microsoft.Resources/subscriptions/resources/read` | Query resources via Resource Graph |
| `Microsoft.Resources/tags/write` | Create/update resource tags |

### Grant Access to Multiple Subscriptions

```bash
# Grant access to additional subscriptions
az role assignment create \
    --assignee "{app-id-or-principal-id}" \
    --role "Azure Stack HCI Administrator" \
    --scope "/subscriptions/{additional-subscription-id}"
```

---

## GitHub Actions Setup

### Step 1: Add Repository Secrets

Based on your chosen authentication method:

**For OIDC (Recommended):**
| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | App Registration ID |
| `AZURE_TENANT_ID` | Entra ID tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |

**For Client Secret (Legacy):**
| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | The `appId` from Service Principal |
| `AZURE_CLIENT_SECRET` | The `password` from Service Principal |
| `AZURE_TENANT_ID` | The `tenant` from Service Principal |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID |

> 💡 **Tip**: For public repositories, use [environment secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-secrets) with required reviewers for additional security.

### Step 2: Copy Workflow Files

Copy the workflow files from `github-actions/` to your repository's `.github/workflows/` folder:

```
.github/
└── workflows/
    ├── inventory-clusters.yml
    ├── fleet-update-status.yml
    ├── manage-updatering-tags.yml
    └── apply-updates.yml
```

### Step 3: Run Workflows

1. Go to **Actions** tab in your repository
2. Select the workflow you want to run
3. Click **Run workflow**
4. Fill in the required inputs
5. Click **Run workflow** (green button)

---

## Azure DevOps Setup

Azure DevOps supports two authentication methods for Service Connections:

| Method | Security | When to Use |
|--------|----------|-------------|
| **Workload Identity Federation** | ⭐⭐⭐⭐⭐ | Recommended for all new setups |
| **Service Principal (manual)** | ⭐⭐ | Legacy - only if federation unavailable |

### Option A: Workload Identity Federation (Recommended)

1. Go to your Azure DevOps project
2. Navigate to **Project Settings** → **Service connections**
3. Click **New service connection**
4. Select **Azure Resource Manager**
5. Choose **Workload Identity federation (automatic)** 
6. Select your subscription and resource group scope
7. Name it `AzureLocal-ServiceConnection`
8. Click **Save**

Azure DevOps automatically creates the App Registration and federated credential for you.

> 📝 **Note**: This method requires no secrets and uses short-lived tokens.

### Option B: Service Principal (Manual/Legacy)

> ⚠️ **Not recommended** - Only use if Workload Identity Federation is not available.

1. Go to your Azure DevOps project
2. Navigate to **Project Settings** → **Service connections**
3. Click **New service connection**
4. Select **Azure Resource Manager**
5. Choose **Service principal (manual)**
6. Fill in the details:

| Field | Value |
|-------|-------|
| **Subscription ID** | Your Azure subscription ID |
| **Subscription Name** | A friendly name for the subscription |
| **Service Principal ID** | The `appId` from Service Principal creation |
| **Service Principal Key** | The `password` from Service Principal creation |
| **Tenant ID** | The `tenant` from Service Principal creation |
| **Service connection name** | `AzureLocal-ServiceConnection` (or your preferred name) |

7. Check **Grant access permission to all pipelines**
8. Click **Verify and save**

### Step 2: Create Pipeline Variable Group (Optional)

For additional configuration, create a variable group:

1. Go to **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name it `AzureLocal-Config`
4. Add variables as needed (e.g., default UpdateRing values)

### Step 3: Create Pipelines

For each pipeline definition in `azure-devops/`:

```
azure-devops/
├── inventory-clusters.yml
├── fleet-update-status.yml
├── manage-updatering-tags.yml
└── apply-updates.yml
```

1. Go to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select **Azure Repos Git** (or your repo source)
4. Select your repository
5. Choose **Existing Azure Pipelines YAML file**
6. Select the path to the YAML file (e.g., `/Automation-Pipeline-Examples/azure-devops/inventory-clusters.yml`)
7. Click **Continue** and then **Save** (not Run, unless you want to test immediately)

Repeat for each of the 4 pipeline files.

> 📝 **Note**: The pipeline YAML files reference a service connection named `AzureLocal-ServiceConnection`. Either name your service connection to match, or update the `azureSubscription` value in each YAML file to match your service connection name.

---

## Pipeline Descriptions

### 1. Inventory Clusters Pipeline

**Purpose:** Queries all Azure Local clusters and generates an inventory report showing:
- Cluster names and resource groups
- Current UpdateRing tag values
- Clusters without UpdateRing tags

**Outputs:**
- CSV file artifact with cluster inventory
- Console summary of UpdateRing distribution

**Use Case:** Run this first to understand your cluster landscape and identify clusters that need UpdateRing tags.

### 2. Manage UpdateRing Tags Pipeline

**Purpose:** Creates or updates update management tags on clusters based on a CSV input file.

**Inputs:**
- CSV file with `ResourceId` and `UpdateRing` columns (required), plus optional `UpdateWindow` and `UpdateExclusions` columns
- Optional: Force flag to overwrite existing tags

**Workflow:**
1. Run Inventory pipeline to get current state
2. Download the CSV artifact
3. Edit the CSV to set `UpdateRing` values (required), and optionally `UpdateWindow` and `UpdateExclusions` values
4. Upload the modified CSV to the repository or as pipeline input
5. Run this pipeline to apply the tags

**Use Case:** Organize clusters into update rings (Wave1, Wave2, Production, etc.) for staged rollouts, and optionally define per-cluster maintenance windows and change-freeze periods.

### 3. Apply Updates Pipeline

**Purpose:** Applies available updates to clusters filtered by UpdateRing tag.

**Inputs:**
- UpdateRing value to target (e.g., "Wave1")
- Optional: Specific update version to apply

**Outputs:**
- JUnit XML test results for CI/CD visualization
- CSV logs of started/skipped/schedule-blocked updates
- Detailed execution logs with per-cluster status (Started, Skipped, Failed, HealthCheckBlocked, ScheduleBlocked)

**Use Case:** Execute updates on a specific ring of clusters as part of a staged deployment. Clusters outside their `UpdateWindow` maintenance window or within an `UpdateExclusions` blackout period are automatically skipped with a `ScheduleBlocked` status.

### 4. Fleet Update Status Pipeline

**Purpose:** Monitors and reports on update status across the entire fleet of Azure Local clusters. Ideal for dashboards, compliance tracking, and executive reporting.

**Features:**
- 📊 **JUnit XML Reports**: Each cluster appears as a test case in GitHub Actions Test tab or Azure DevOps Tests tab
- 📁 **Multiple Formats**: CSV, JSON, and JUnit XML exports
- 🔍 **Comprehensive Data**: Inventory, readiness status, update summaries, available updates, and recent update run history
- 📅 **Scheduled Runs**: Automated daily checks at 6 AM UTC
- 🏷️ **Flexible Scope**: Filter all clusters or by UpdateRing tag value
- ⚡ **Efficient Fleet Queries**: Uses v0.5.6 fleet-wide query capabilities (no individual cluster loops)

**Outputs:**
| Artifact | Description |
|----------|-------------|
| `readiness-status.xml` | JUnit XML for CI/CD test visualization (passed=healthy, failed=issues/SBE blocked) |
| `readiness-status.csv` | Detailed cluster status spreadsheet (includes UpdateWindow, UpdateExclusions, SBEDependency) |
| `readiness-status.json` | Machine-readable format with summary counts including HasPrerequisite |
| `cluster-inventory.csv` | Full cluster inventory |
| `update-summaries.csv` | Fleet-wide update state summaries from Azure (current state, last updated, etc.) |
| `available-updates.csv` | All available updates across the fleet with versions and health states |
| `update-runs.csv` | Recent update run history per cluster (if enabled) |

**Understanding JUnit Test Results:**
| Test Status | Meaning |
|-------------|---------|
| ✅ **Passed** | Cluster is healthy and up-to-date or ready for updates |
| ❌ **Failed** (UpdateFailure) | Cluster has health failures or update issues requiring attention |
| ❌ **Failed** (HasPrerequisite) | Cluster has updates blocked by an SBE prerequisite - install the vendor SBE update first |

**Dashboard Integration:**
- **GitHub Actions**: Results appear in the workflow run's "Tests" summary
- **Azure DevOps**: Results appear in the pipeline's "Tests" tab with trend analytics
- **Third-party tools**: Import the JUnit XML into any CI/CD dashboard that supports JUnit format

**Use Cases:**
- Daily health checks on cluster update status
- Executive dashboards showing fleet-wide update adoption
- Alerting when clusters have update failures
- Compliance tracking for update deployments

---

## Typical Workflow

### Complete End-to-End Update Deployment

This workflow shows how to use all four pipelines together for a staged update deployment:

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 1: INITIAL SETUP                                      │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ① INVENTORY CLUSTERS                          ② ASSIGN UPDATE RINGS                    │
│  ┌────────────────────────────┐                ┌────────────────────────────┐           │
│  │ Run: inventory-clusters.yml│                │ Download CSV from artifacts│           │
│  │ Output: cluster-inventory/ │───────────────▶│ Edit in Excel:             │           │
│  │   • inventory.csv          │                │   Cluster01 → Wave1        │           │
│  │   • inventory.json         │                │   Cluster02 → Wave1        │           │
│  └────────────────────────────┘                │   Cluster03 → Wave2        │           │
│                                                │   Cluster04 → Production   │           │
│                                                └─────────────┬──────────────┘           │
│                                                              │                           │
│  ③ APPLY TAGS                                                ▼                           │
│  ┌────────────────────────────────────────────────────────────────────────┐             │
│  │ Run: manage-updatering-tags.yml with edited CSV                        │             │
│  │ Result: All clusters now have UpdateRing tags in Azure                 │             │
│  └────────────────────────────────────────────────────────────────────────┘             │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 2: STAGED UPDATE ROLLOUT                              │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  WAVE 1 (Pilot)                    WAVE 2                      PRODUCTION               │
│  Monday 10 PM                      Wednesday 10 PM             Saturday 2 AM            │
│  ┌─────────────────┐               ┌─────────────────┐         ┌─────────────────┐      │
│  │ apply-updates   │               │ apply-updates   │         │ apply-updates   │      │
│  │ UpdateRing=Wave1│               │ UpdateRing=Wave2│         │ UpdateRing=Prod │      │
│  └────────┬────────┘               └────────┬────────┘         └────────┬────────┘      │
│           │                                 │                           │               │
│           ▼                                 ▼                           ▼               │
│  ┌─────────────────┐               ┌─────────────────┐         ┌─────────────────┐      │
│  │ ✅ 2 clusters   │               │ ✅ 3 clusters   │         │ ✅ 10 clusters  │      │
│  │ Duration: 3.5 hrs│──────────────▶│ Duration: ~4 hrs│─────────▶│ Duration: ~4 hrs│      │
│  │ (validates next)│  (estimates)  │                 │          │                 │      │
│  └─────────────────┘               └─────────────────┘         └─────────────────┘      │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 3: ONGOING MONITORING                                 │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  DAILY (Automated)                              WEEKLY (Automated)                       │
│  ┌───────────────────────────────────┐          ┌───────────────────────────────────┐   │
│  │ fleet-update-status.yml (6 AM UTC)│          │ inventory-clusters.yml (Monday)   │   │
│  │                                   │          │                                   │   │
│  │ Outputs:                          │          │ Check for:                        │   │
│  │ • JUnit XML → CI/CD Dashboard     │          │ • New clusters needing tags       │   │
│  │ • update-runs.csv → Duration data │          │ • Tag drift or changes            │   │
│  │ • readiness-status.csv → Health   │          │ • Subscription changes            │   │
│  └───────────────────────────────────┘          └───────────────────────────────────┘   │
│                                                                                          │
│  ⚠️ ALERTS: Configure notifications for test failures in CI/CD platform                 │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Step-by-Step Instructions

#### Phase 1: Initial Setup (One-time)

1. **Run Inventory Pipeline**
   ```
   GitHub: Actions → Inventory Azure Local Clusters → Run workflow
   Azure DevOps: Pipelines → Inventory Clusters → Run
   ```

2. **Download and Edit CSV**
   - Download `ClusterInventory_*.csv` from pipeline artifacts
   - Open in Excel
   - Set values for the update management tag columns:
     | ClusterName | UpdateRing | UpdateWindow | UpdateExclusions |
     |-------------|------------|--------------|------------------|
     | HCI-Pilot01 | Wave1 | | |
     | HCI-Pilot02 | Wave1 | | |
     | HCI-Prod01  | Wave2 | Sat-Sun:02:00-06:00 | 20**-12-20/20**-01-03 |
     | HCI-Critical| Production | Sat:02:00-06:00 | 20**-12-20/20**-01-03 |
   
   - **UpdateRing** (required): The deployment wave for staged rollouts
   - **UpdateWindow** (optional): UTC maintenance window when updates are allowed. If omitted, updates proceed with no time restrictions.
   - **UpdateExclusions** (optional): Blackout/change-freeze periods. If omitted, no date restrictions. Use `*` for recurring annual patterns.

3. **Apply Tags**
   - Upload modified CSV to repository or provide as input
   - Run "Manage UpdateRing Tags" pipeline
   - Verify tags in Azure Portal

> 💡 **Local Alternative (No Pipeline Required)**: You can skip the download/upload workflow above and manage UpdateRing tags directly from PowerShell. This is often simpler for initial setup or small environments:
>
> ```powershell
> # Step 1: Export cluster inventory to CSV
> Import-Module .\AzStackHci.ManageUpdates.psd1
> Get-AzureLocalClusterInventory -ExportPath "C:\Temp\cluster-inventory.csv"
>
> # Step 2: Open the CSV in Excel — set UpdateRing, UpdateWindow, and UpdateExclusions values, save
>
> # Step 3: Apply all tags directly from PowerShell
> Set-AzureLocalClusterUpdateRingTag -InputCsvPath "C:\Temp\cluster-inventory.csv"
> ```
>
> This approach avoids the need to run the Inventory pipeline, download artifacts, re-upload, and run the Manage Tags pipeline. The `Set-AzureLocalClusterUpdateRingTag` function reads `UpdateRing`, `UpdateWindow`, and `UpdateExclusions` columns from the CSV (if present) and applies them in a single PATCH operation via the Azure REST API.

#### Phase 2: Update Deployment (Recurring)

4. **Wave1 Updates (Pilot clusters)**
   - Schedule: Monday 10 PM or manual trigger
   - Run "Apply Updates" with `UpdateRing = Wave1`
   - Monitor progress in CI/CD dashboard

5. **Analyze Wave1 Results**
   - Check duration from `update-runs.csv`
   - Review any failures before proceeding
   - Estimate time needed for Wave2/Production

6. **Wave2 and Production Updates**
   - Use Wave1 duration data to plan maintenance windows
   - Apply updates to subsequent rings
   - Monitor each wave before proceeding

#### Phase 3: Ongoing Operations

7. **Enable Automated Monitoring**
   - Fleet Update Status runs daily at 6 AM UTC
   - Configure alerts for test failures
   - Review dashboards for health trends

8. **Periodic Inventory Refresh**
   - Run inventory weekly/monthly
   - Identify new clusters needing tags
   - Update tags as environment changes

### Fleet Monitoring Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│              Daily Automated Fleet Monitoring                    │
├─────────────────────────────────────────────────────────────────┤
│  "Fleet Update Status" runs daily at 6 AM UTC (scheduled)       │
│                                                                  │
│  📊 Outputs (using v0.5.6 fleet-wide queries):                  │
│  ├── JUnit XML → CI/CD Dashboard (Tests tab)                    │
│  ├── CSV → Download for spreadsheet analysis                    │
│  │   • readiness-status.csv (cluster health)                    │
│  │   • update-summaries.csv (update states)                     │
│  │   • available-updates.csv (pending updates)                  │
│  │   • update-runs.csv (run history)                            │
│  └── JSON → Integration with external tools                     │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
    ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
    │  All Tests Pass │ │ Some Tests Fail │ │   Investigate   │
    │  ✅ Fleet OK    │ │  ❌ Issues!     │ │   Failures      │
    └─────────────────┘ └─────────────────┘ └─────────────────┘
                                                      │
                                                      ▼
                              ┌─────────────────────────────────────┐
                              │  Review test output for details:    │
                              │  • Cluster name                     │
                              │  • Update state                     │
                              │  • Health state                     │
                              │  • Health check failures            │
                              └─────────────────────────────────────┘
```

### Executive Dashboard Integration

The Fleet Update Status pipeline generates JUnit XML that integrates with CI/CD platforms:

**GitHub Actions:**
- Test results appear in the workflow run summary
- Failed tests show clusters needing attention
- Historical trends visible across workflow runs

**Azure DevOps:**
- Results appear in Tests tab with analytics
- Configure test trend widgets on dashboards
- Set up alerts for test failures

### Standalone HTML Report

For ad-hoc or offline reporting outside of CI/CD pipelines, use the `New-AzureLocalFleetStatusHtmlReport` function (v0.6.4) to generate a self-contained HTML report. This is useful for:
- Sharing fleet status via email or SharePoint
- Executive reporting without CI/CD dashboard access
- On-demand health checks from a local workstation

```powershell
Import-Module .\AzStackHci.ManageUpdates.psd1

# Generate a report for all clusters (up to 100) - auto-discovers via ARG
New-AzureLocalFleetStatusHtmlReport -AllClusters `
    -OutputPath "C:\Reports\fleet-all.html" -IncludeHealthDetails -IncludeUpdateRuns

# Generate a report for a single cluster (auto-titles as "Seattle - Update Status Report")
New-AzureLocalFleetStatusHtmlReport -ClusterNames Seattle `
    -OutputPath "C:\Reports\seattle.html" -IncludeHealthDetails -IncludeUpdateRuns

# Generate a report for all Wave1 clusters
New-AzureLocalFleetStatusHtmlReport -ScopeByUpdateRingTag -UpdateRingValue "Wave1" `
    -OutputPath "C:\Reports\wave1-status.html" -IncludeHealthDetails -IncludeUpdateRuns

# Capture HTML for email body
$html = New-AzureLocalFleetStatusHtmlReport -ClusterNames @("Cluster01","Cluster02") `
    -OutputPath "C:\Reports\fleet.html" -PassThru
```

The report includes executive summary cards, cluster information, status table with Active Update and Recommended Update columns, update run history with recursive step traversal, and health check failures with severity filtering.

---

## Scheduling Updates and Maintenance Windows

### Per-Cluster Maintenance Schedule Tags

Azure resource tags on each cluster control when the Apply Updates pipeline is allowed to start updates:

| Tag | Format | Example | Purpose |
|-----|--------|---------|---------|
| `UpdateWindow` | `<days>:<HH:MM>-<HH:MM>` | `Sat-Sun:02:00-06:00` | Maintenance window (UTC). Updates only start within this window. |
| `UpdateExclusions` | `YYYY-MM-DD/YYYY-MM-DD` | `2026-12-20/2027-01-03` | Blackout periods. No updates during these dates. Supports wildcards (`20**-12-20/20**-01-03` for recurring annual freeze). |

**Behavior:**
- If **neither tag** is set, updates proceed with no schedule restrictions
- If `UpdateWindow` is set, updates are only started when the current UTC time falls within the window
- If `UpdateExclusions` is set, updates are blocked during blackout periods — **exclusions take priority** over windows
- The pipeline returns `ScheduleBlocked` status for clusters outside their window, with the reason in the log output
- Schedule check failures (e.g., malformed tag values) are **non-blocking** — the update proceeds with a warning

**Multiple windows** can be separated with `;`: `Mon-Fri:22:00-06:00;Sat-Sun:02:00-10:00`

**Day ranges** support wrap-around: `Fri-Mon:22:00-06:00` covers Friday through Monday

**Overnight windows** are supported: `Sat:22:00-06:00` means Saturday 10 PM to Sunday 6 AM UTC

You can test schedule logic interactively before configuring pipelines:

```powershell
# Test if current UTC time is within a maintenance window
Test-AzureLocalUpdateScheduleAllowed -UpdateWindow "Sat-Sun:02:00-06:00" -UpdateExclusions "2026-12-20/2027-01-03"

# Test a specific time
Test-AzureLocalUpdateScheduleAllowed -UpdateWindow "Sat:02:00-06:00" -TestTime ([datetime]"2026-04-19 03:00:00")
```

The `readiness-status.csv` from the Fleet Update Status pipeline includes `UpdateWindow` and `UpdateExclusions` columns so ops teams can see which clusters have schedule restrictions defined.

### Planning Update Deployments

Azure Local cluster updates can take **2-6+ hours** depending on:
- Number of nodes in the cluster
- Update size (solution bundles vs. individual updates)
- Cluster health and workload during update

**Best Practice:** Use earlier update rings to estimate duration for later waves.

### Using Earlier Rings to Estimate Duration

The `update-runs.csv` output from Fleet Update Status includes duration data. Use Wave1/Pilot results to plan Production maintenance windows:

```powershell
# After Wave1 completes, analyze durations
$wave1Runs = Import-Csv "update-runs.csv" | Where-Object { $_.UpdateRing -eq "Wave1" }

# Calculate average and max duration
$durations = $wave1Runs | Where-Object { $_.Duration -match '\d' } | ForEach-Object {
    if ($_.Duration -match '([\d.]+)\s*hours') { [double]$matches[1] * 60 }
    elseif ($_.Duration -match '([\d.]+)\s*minutes') { [double]$matches[1] }
    else { 0 }
}

$avgMinutes = ($durations | Measure-Object -Average).Average
$maxMinutes = ($durations | Measure-Object -Maximum).Maximum

Write-Host "Wave1 Update Duration Analysis:"
Write-Host "  Average: $([math]::Round($avgMinutes / 60, 1)) hours"
Write-Host "  Maximum: $([math]::Round($maxMinutes / 60, 1)) hours"
Write-Host "  Recommended maintenance window: $([math]::Ceiling($maxMinutes * 1.2 / 60)) hours"
```

### Scheduling Patterns

| Ring | Schedule | Purpose |
|------|----------|---------|
| **Canary** | Manual trigger | Test update on 1-2 non-critical clusters |
| **Pilot/Wave1** | Monday 10 PM | Early adopter clusters, IT-managed workloads |
| **Wave2** | Wednesday 10 PM | Non-critical production (after Wave1 validates) |
| **Production** | Saturday 2 AM | Critical workloads during low-usage window |

### GitHub Actions Scheduled Triggers

```yaml
on:
  schedule:
    # Wave1: Monday at 10 PM UTC
    - cron: '0 22 * * 1'
  workflow_dispatch:
    inputs:
      update_ring:
        description: 'Update ring to process'
        required: true
        default: 'Wave1'
```

### Azure DevOps Scheduled Triggers

```yaml
schedules:
  - cron: '0 22 * * 1'  # Monday 10 PM UTC
    displayName: 'Wave1 Weekly Update'
    branches:
      include:
        - main
    always: true  # Run even if no code changes
```

### Multi-Stage Deployment with Approval Gates

For production-critical environments, add manual approval between waves:

**Azure DevOps:**
```yaml
stages:
  - stage: Wave1
    jobs:
      - job: ApplyWave1Updates
        # ... Wave1 update job

  - stage: ValidateWave1
    dependsOn: Wave1
    jobs:
      - job: WaitForApproval
        pool: server
        steps:
          - task: ManualValidation@0
            inputs:
              notifyUsers: 'ops-team@company.com'
              instructions: 'Review Wave1 update results before proceeding to Wave2'

  - stage: Wave2
    dependsOn: ValidateWave1
    # ... Wave2 update job
```

**GitHub Actions:**
```yaml
jobs:
  wave1:
    runs-on: windows-latest
    environment: wave1  # No approval required
    # ... Wave1 steps

  wave2:
    needs: wave1
    runs-on: windows-latest
    environment: production  # Requires approval (configure in repo settings)
    # ... Wave2 steps
```

---

## Security Best Practices

1. **Least Privilege**: Create a custom role with only the required permissions instead of using "Azure Stack HCI Administrator" if you want tighter security.

2. **Secret Rotation**: Rotate the Service Principal secret regularly (e.g., every 90 days).

3. **Audit Logging**: Enable Azure Activity Log monitoring for the Service Principal.

4. **Approval Gates**: Add manual approval steps before the "Apply Updates" pipeline in production.

5. **Branch Protection**: Require PR reviews for changes to pipeline definitions.

---

## Troubleshooting

### "Azure CLI not authenticated"
- Verify the Service Principal credentials are correct
- Check that secrets are properly configured in GitHub/Azure DevOps
- Ensure the Service Principal has not expired

### "No clusters found"
- Verify the Service Principal has access to the subscription(s)
- Check that clusters exist and are in "Connected" state
- Ensure the `resource-graph` extension is installed (pipelines do this automatically)

### "Permission denied applying tags"
- Verify the Service Principal has `Microsoft.Resources/tags/write` permission
- Check that the scope includes the resource groups containing the clusters

### "Update failed to start"
- Check cluster health status in Azure Portal
- Verify the update is in "Ready" state
- Review the detailed logs in the pipeline output

---

## File Structure

```
Automation-Pipeline-Examples/
├── README.md                           # This file
├── github-actions/
│   ├── inventory-clusters.yml          # GitHub Actions: Inventory pipeline
│   ├── manage-updatering-tags.yml      # GitHub Actions: Tag management pipeline
│   ├── apply-updates.yml               # GitHub Actions: Update application pipeline
│   └── fleet-update-status.yml         # GitHub Actions: Fleet status monitoring pipeline
└── azure-devops/
    ├── inventory-clusters.yml          # Azure DevOps: Inventory pipeline
    ├── manage-updatering-tags.yml      # Azure DevOps: Tag management pipeline
    ├── apply-updates.yml               # Azure DevOps: Update application pipeline
    └── fleet-update-status.yml         # Azure DevOps: Fleet status monitoring pipeline
```

---

## Related Documentation

- [Azure Local Update Management Module](../README.md)
- [Azure Stack HCI documentation](https://learn.microsoft.com/en-us/azure-stack/hci/)
- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Azure DevOps Pipelines documentation](https://learn.microsoft.com/en-us/azure/devops/pipelines/)
