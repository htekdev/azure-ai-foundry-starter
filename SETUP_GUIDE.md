# 🚀 Azure AI Foundry Starter - Setup Guide

Welcome! This guide walks you through setting up your Azure AI Foundry environment with Azure DevOps CI/CD pipelines. You can follow the automated script approach or perform each step manually through the Azure Portal and Azure DevOps.

---

## 📋 Table of Contents

1. [Prerequisites](#-prerequisites)
2. [Phase 1: Configuration Setup](#-phase-1-configuration-setup)
3. [Phase 2: Azure Resource Creation](#-phase-2-azure-resource-creation)
4. [Phase 3: Azure DevOps Setup](#-phase-3-azure-devops-setup)
5. [Phase 4: Deployment Validation](#-phase-4-deployment-validation)
6. [Next Steps](#-next-steps)
7. [Troubleshooting](#-troubleshooting)

---

## 📦 Prerequisites

Before you begin, ensure you have the following tools and permissions:

### Required Tools

| Tool | Version | Installation | Verification |
|------|---------|--------------|--------------|
| **Azure CLI** | 2.50+ | [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | `az --version` |
| **PowerShell** | 7.0+ | [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) | `$PSVersionTable.PSVersion` |
| **Git** | 2.30+ | [Install Git](https://git-scm.com/downloads) | `git --version` |
| **Azure DevOps CLI** | Latest | `az extension add --name azure-devops` | `az extension list` |

### Required Permissions

✅ **Azure Subscription**
- Contributor role or higher
- Ability to create resource groups
- Ability to create App Registrations (Service Principals)
- Access to assign RBAC roles

✅ **Azure DevOps Organization**
- Project Administrator role
- Ability to create/manage service connections
- Ability to create/manage pipelines
- Ability to create/manage repositories

### Information You'll Need

Before starting, gather the following information:

| Item | Where to Find It | Example |
|------|------------------|---------|
| **Project Name** | Choose a unique name (lowercase, 10-15 chars) | `foundrycicd` |
| **Azure Subscription ID** | Azure Portal → Subscriptions | `86b6d0e0-2ecd-4842-ae88-859a6b2fd0fe` |
| **Azure Tenant ID** | Azure Portal → Azure Active Directory → Properties | `16b3c013-d300-468d-ac64-7eda0820b6d3` |
| **Azure DevOps Organization URL** | Your organization URL | `https://dev.azure.com/my-org` |
| **Azure DevOps Project Name** | Choose a project name | `foundrycicd` |

### Quick Prerequisite Check

Run this PowerShell script to verify all prerequisites:

```powershell
# Check Azure CLI
Write-Host "Checking prerequisites..." -ForegroundColor Cyan
if (Get-Command az -ErrorAction SilentlyContinue) {
    Write-Host "✓ Azure CLI installed: $(az --version | Select-String 'azure-cli')" -ForegroundColor Green
} else {
    Write-Host "✗ Azure CLI not found" -ForegroundColor Red
}

# Check Azure DevOps extension
$adoExt = az extension list --query "[?name=='azure-devops'].version" -o tsv
if ($adoExt) {
    Write-Host "✓ Azure DevOps CLI extension: $adoExt" -ForegroundColor Green
} else {
    Write-Host "✗ Azure DevOps CLI extension not found. Installing..." -ForegroundColor Yellow
    az extension add --name azure-devops
}

# Check Azure login
$account = az account show 2>$null
if ($account) {
    $accountInfo = $account | ConvertFrom-Json
    Write-Host "✓ Logged in to Azure: $($accountInfo.user.name)" -ForegroundColor Green
    Write-Host "  Subscription: $($accountInfo.name)" -ForegroundColor Gray
} else {
    Write-Host "✗ Not logged in to Azure. Run: az login" -ForegroundColor Red
}

# Check Git
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "✓ Git installed: $(git --version)" -ForegroundColor Green
} else {
    Write-Host "✗ Git not found" -ForegroundColor Red
}

Write-Host "`nPrerequisite check complete!" -ForegroundColor Cyan
```

---

## 🔧 Phase 1: Configuration Setup

Set up your project configuration that will be used throughout the deployment.

<details>
<summary><strong>📜 Script Approach (Automated)</strong></summary>

### Create Configuration Script

Run this PowerShell script to create your configuration file:

```powershell
# Navigate to the project directory
cd c:\Repos\ado\azure-ai-foundry-starter

# Gather required information
$projectName = "foundrycicd"  # Change this to your project name
$organizationUrl = "https://dev.azure.com/my-org"  # Your Azure DevOps org
$tenantId = "16b3c013-d300-468d-ac64-7eda0820b6d3"  # Your Azure Tenant ID
$subscriptionId = "86b6d0e0-2ecd-4842-ae88-859a6b2fd0fe"  # Your Azure Subscription ID

# Set Azure subscription context
Write-Host "Setting Azure subscription..." -ForegroundColor Cyan
az account set --subscription $subscriptionId
$subscriptionInfo = az account show | ConvertFrom-Json
Write-Host "✓ Subscription set: $($subscriptionInfo.name)" -ForegroundColor Green

# Extract organization name
$orgName = $organizationUrl -replace 'https://dev\.azure\.com/', ''

# Create configuration object
$config = @{
    naming = @{
        projectName = $projectName
    }
    azure = @{
        subscriptionId = $subscriptionId
        subscriptionName = $subscriptionInfo.name
        tenantId = $tenantId
        location = "eastus"
    }
    azureDevOps = @{
        organizationName = $orgName
        organizationUrl = $organizationUrl
        projectName = $projectName
    }
}

# Save configuration to file
$configPath = ".\starter-config.json"
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
Write-Host "✓ Configuration created: $configPath" -ForegroundColor Green

# Display configuration summary
Write-Host "`nConfiguration Summary:" -ForegroundColor Cyan
Write-Host "  Project Name: $projectName" -ForegroundColor Gray
Write-Host "  Azure Subscription: $($subscriptionInfo.name)" -ForegroundColor Gray
Write-Host "  Azure DevOps Org: $organizationUrl" -ForegroundColor Gray
Write-Host "  Location: eastus" -ForegroundColor Gray
Write-Host "`n✅ Phase 1 complete! Proceed to Phase 2." -ForegroundColor Green
```

The script will:
- ✅ Validate Azure login
- ✅ Create `starter-config.json` with your settings
- ✅ Set Azure subscription context
- ✅ Display configuration summary

### What Gets Created

The configuration file (`starter-config.json`) will look like this:

```json
{
    "naming": {
        "projectName": "foundrycicd"
    },
    "azure": {
        "subscriptionId": "86b6d0e0-2ecd-4842-ae88-859a6b2fd0fe",
        "subscriptionName": "My Azure Subscription",
        "tenantId": "16b3c013-d300-468d-ac64-7eda0820b6d3",
        "location": "eastus"
    },
    "azureDevOps": {
        "organizationName": "my-org",
        "organizationUrl": "https://dev.azure.com/my-org",
        "projectName": "foundrycicd"
    },
    "environments": {
        "dev": {
            "name": "dev",
            "displayName": "Development",
            "requiresApproval": false
        },
        "test": {
            "name": "test",
            "displayName": "Test",
            "requiresApproval": false
        },
        "prod": {
            "name": "prod",
            "displayName": "Production",
            "requiresApproval": true
        }
    }
}
```

</details>

<details>
<summary><strong>🌐 Portal Approach (Manual)</strong></summary>

### Step 1: Create Configuration File

Create a new file named `starter-config.json` in the root directory:

```powershell
cd c:\Repos\ado\azure-ai-foundry-starter
New-Item -Path "starter-config.json" -ItemType File
```

### Step 2: Gather Azure Information

**Get Subscription Information:**
1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to **Subscriptions**
3. Copy your **Subscription ID** and **Subscription Name**

**Get Tenant ID:**
1. In Azure Portal, go to **Azure Active Directory**
2. Click **Properties**
3. Copy your **Tenant ID**

### Step 3: Gather Azure DevOps Information

**Get Organization Name:**
1. Open your [Azure DevOps](https://dev.azure.com) organization
2. The URL format is: `https://dev.azure.com/{organization-name}`
3. Note your organization name

**Choose Project Name:**
- Use the same name as your Azure resources for consistency
- Must be lowercase, alphanumeric, and hyphens only
- Recommended: 10-15 characters

### Step 4: Populate Configuration File

Edit `starter-config.json` with your information:

```json
{
    "naming": {
        "projectName": "YOUR_PROJECT_NAME"
    },
    "azure": {
        "subscriptionId": "YOUR_SUBSCRIPTION_ID",
        "subscriptionName": "YOUR_SUBSCRIPTION_NAME",
        "tenantId": "YOUR_TENANT_ID",
        "location": "eastus"
    },
    "azureDevOps": {
        "organizationName": "YOUR_ORG_NAME",
        "organizationUrl": "https://dev.azure.com/YOUR_ORG_NAME",
        "projectName": "YOUR_PROJECT_NAME"
    },
    "environments": {
        "dev": {
            "name": "dev",
            "displayName": "Development",
            "requiresApproval": false
        },
        "test": {
            "name": "test",
            "displayName": "Test",
            "requiresApproval": false
        },
        "prod": {
            "name": "prod",
            "displayName": "Production",
            "requiresApproval": true
        }
    }
}
```

### Step 5: Set Azure Context

```powershell
# Login to Azure (if not already logged in)
az login

# Set the subscription context
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify the subscription is set correctly
az account show
```

### Step 6: Configure Azure DevOps CLI

```powershell
# Configure Azure DevOps defaults
az devops configure --defaults `
    organization="https://dev.azure.com/YOUR_ORG_NAME" `
    project="YOUR_PROJECT_NAME"
```

</details>

---

## 🏗️ Phase 2: Azure Resource Creation

Create all required Azure resources including resource groups, service principal, and AI Foundry projects.

<details>
<summary><strong>📜 Script Approach (Automated)</strong></summary>

### Run Resource Creation Script

If you used the automated setup script in Phase 1, this phase is **automatically executed**. Otherwise, run:

```powershell
# Navigate to the project directory
cd c:\Repos\ado\azure-ai-foundry-starter

# Run the resource creation skill
.\.github\skills\resource-creation\create-resources.ps1 `
    -UseConfig `
    -CreateAll `
    -Environment 'all'
```

### What Gets Created

The script creates resources in this order:

**1. Resource Groups** (3 environments)
- `rg-foundrycicd-dev`
- `rg-foundrycicd-test`
- `rg-foundrycicd-prod`

**2. Service Principal**
- Display Name: `sp-foundrycicd-cicd`
- Configured with Workload Identity Federation (no passwords!)
- RBAC roles assigned:
  - Contributor on all resource groups
  - Cognitive Services User on AI resources

**3. AI Foundry Resources** (per environment)
- AI Services (kind: AIServices)
- AI Foundry Projects
- Project endpoints configured

### Progress Tracking

Watch for these success messages:

```
✓ Resource Groups created
✓ Service Principal created
✓ RBAC roles assigned
✓ AI Foundry resources created (dev)
✓ AI Foundry resources created (test)
✓ AI Foundry resources created (prod)
✓ Configuration updated
```

### Verify Resource Creation

```powershell
# Check resource groups
az group list --query "[?starts_with(name, 'rg-foundrycicd')].{Name:name, Location:location}" -o table

# Check service principal
az ad sp list --display-name "sp-foundrycicd-cicd" --query "[].{Name:displayName, AppId:appId}" -o table

# Check AI resources
az cognitiveservices account list --query "[?starts_with(name, 'foundrycicd')].{Name:name, Kind:kind, Location:location}" -o table
```

</details>

<details>
<summary><strong>🌐 Portal Approach (Manual)</strong></summary>

### Step 1: Create Resource Groups

**Using Azure Portal:**

For each environment (dev, test, prod):

1. Open [Azure Portal](https://portal.azure.com)
2. Click **Resource groups** → **+ Create**
3. Fill in details:
   - **Subscription**: Your subscription
   - **Resource group**: `rg-foundrycicd-dev` (change suffix for each env)
   - **Region**: East US
4. Click **Review + create** → **Create**
5. Repeat for test and prod environments

**Using Azure CLI:**

```powershell
# Set variables
$projectName = "foundrycicd"
$location = "eastus"

# Create resource groups
az group create --name "rg-$projectName-dev" --location $location
az group create --name "rg-$projectName-test" --location $location
az group create --name "rg-$projectName-prod" --location $location

# Verify creation
az group list --query "[?starts_with(name, 'rg-$projectName')].name" -o table
```

### Step 2: Create Service Principal

**Using Azure Portal:**

1. Go to **Azure Active Directory** → **App registrations**
2. Click **+ New registration**
3. Fill in details:
   - **Name**: `sp-foundrycicd-cicd`
   - **Supported account types**: Single tenant
4. Click **Register**
5. Note the **Application (client) ID** and **Object ID**

**Using Azure CLI:**

```powershell
# Create app registration
$spName = "sp-$projectName-cicd"
$sp = az ad sp create-for-rbac `
    --name $spName `
    --role Contributor `
    --scopes /subscriptions/YOUR_SUBSCRIPTION_ID `
    --sdk-auth | ConvertFrom-Json

# Save the output (you'll need appId and tenantId)
Write-Host "Service Principal created:"
Write-Host "  App ID: $($sp.clientId)"
Write-Host "  Tenant ID: $($sp.tenantId)"

# Important: Store these values securely!
```

### Step 3: Assign RBAC Roles

**Grant Contributor role on Resource Groups:**

For each resource group:

1. In Azure Portal, navigate to the resource group
2. Click **Access control (IAM)** → **+ Add** → **Add role assignment**
3. Select **Contributor** role
4. Click **Next**
5. Select **User, group, or service principal**
6. Search for `sp-foundrycicd-cicd`
7. Click **Select** → **Review + assign**

**Using Azure CLI:**

```powershell
$spId = az ad sp list --display-name $spName --query "[0].id" -o tsv

# Assign Contributor role to each resource group
az role assignment create `
    --assignee $spId `
    --role "Contributor" `
    --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-$projectName-dev"

az role assignment create `
    --assignee $spId `
    --role "Contributor" `
    --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-$projectName-test"

az role assignment create `
    --assignee $spId `
    --role "Contributor" `
    --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-$projectName-prod"
```

### Step 4: Create AI Services Resources

For each environment (dev, test, prod):

**Using Azure Portal:**

1. Navigate to resource group (e.g., `rg-foundrycicd-dev`)
2. Click **+ Create**
3. Search for **Azure AI Services**
4. Click **Create**
5. Fill in details:
   - **Resource group**: Your resource group
   - **Region**: East US
   - **Name**: `foundrycicd-dev` (unique name)
   - **Pricing tier**: Standard S0
6. Click **Review + create** → **Create**

**Using Azure CLI:**

```powershell
# Create AI Services for dev
az cognitiveservices account create `
    --name "foundrycicd-dev" `
    --resource-group "rg-$projectName-dev" `
    --kind "AIServices" `
    --sku "S0" `
    --location $location `
    --yes

# Repeat for test and prod
az cognitiveservices account create `
    --name "foundrycicd-test" `
    --resource-group "rg-$projectName-test" `
    --kind "AIServices" `
    --sku "S0" `
    --location $location `
    --yes

az cognitiveservices account create `
    --name "foundrycicd-prod" `
    --resource-group "rg-$projectName-prod" `
    --kind "AIServices" `
    --sku "S0" `
    --location $location `
    --yes
```

### Step 5: Create AI Foundry Projects

For each environment:

**Using Azure Portal:**

1. Navigate to [Azure AI Foundry](https://ai.azure.com)
2. Click **+ New project**
3. Fill in details:
   - **Project name**: `project-foundrycicd-dev`
   - **AI resource**: Select the AI Service created above
   - **Location**: East US
4. Click **Create**
5. Note the **Project endpoint** URL
6. Repeat for test and prod

**Note**: AI Foundry Projects are typically created through the Azure AI Studio portal, as they require additional setup beyond basic Azure resources.

### Step 6: Grant Cognitive Services User Role

For each AI Foundry project:

1. Navigate to the AI Foundry project resource
2. Click **Access control (IAM)** → **+ Add** → **Add role assignment**
3. Select **Cognitive Services User** role
4. Select your Service Principal (`sp-foundrycicd-cicd`)
5. Click **Review + assign**

**Using Azure CLI:**

```powershell
$spId = az ad sp list --display-name $spName --query "[0].id" -o tsv

# Assign role for each environment
az role assignment create `
    --assignee $spId `
    --role "Cognitive Services User" `
    --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-$projectName-dev/providers/Microsoft.CognitiveServices/accounts/foundrycicd-dev"

# Repeat for test and prod...
```

### Step 7: Update Configuration File

Update `starter-config.json` with the created resource information:

```json
{
    "servicePrincipal": {
        "displayName": "sp-foundrycicd-cicd",
        "appId": "YOUR_APP_ID",
        "objectId": "YOUR_OBJECT_ID",
        "tenantId": "YOUR_TENANT_ID"
    },
    "azure": {
        "resourceGroups": {
            "dev": "rg-foundrycicd-dev",
            "test": "rg-foundrycicd-test",
            "prod": "rg-foundrycicd-prod"
        },
        "aiFoundry": {
            "dev": {
                "projectName": "project-foundrycicd-dev",
                "projectEndpoint": "YOUR_PROJECT_ENDPOINT"
            },
            "test": {
                "projectName": "project-foundrycicd-test",
                "projectEndpoint": "YOUR_PROJECT_ENDPOINT"
            },
            "prod": {
                "projectName": "project-foundrycicd-prod",
                "projectEndpoint": "YOUR_PROJECT_ENDPOINT"
            }
        }
    }
}
```

</details>

---

## ⚙️ Phase 3: Azure DevOps Setup

Configure Azure DevOps with service connections, variable groups, environments, and pipelines.

<details>
<summary><strong>📜 Script Approach (Automated)</strong></summary>

### Prerequisites

Ensure you have an Azure DevOps authentication token:

```powershell
# Get Azure DevOps token
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```

### Step 1: Create Azure DevOps Project (if needed)

```powershell
# Check if project exists
$projectExists = az devops project show --project "foundrycicd" 2>$null

if (-not $projectExists) {
    # Create the project
    az devops project create `
        --name "foundrycicd" `
        --source-control git `
        --visibility private
    
    Write-Host "✓ Azure DevOps project created"
    Start-Sleep -Seconds 5  # Wait for initialization
} else {
    Write-Host "✓ Azure DevOps project already exists"
}
```

### Step 2: Create Service Connections

```powershell
# Run service connection setup
.\.github\skills\service-connection-setup\scripts\create-service-connections.ps1 `
    -UseConfig `
    -Environment 'all'
```

This creates:
- `foundrycicd-dev` service connection
- `foundrycicd-test` service connection
- `foundrycicd-prod` service connection
- Federated credentials on Service Principal

### Step 3: Create Variable Groups and Environments

```powershell
# Run environment setup
.\.github\skills\environment-setup\scripts\create-environments.ps1 `
    -UseConfig `
    -Environment 'all'
```

This creates:
- Variable groups: `foundrycicd-dev-vars`, `foundrycicd-test-vars`, `foundrycicd-prod-vars`
- Environments: `dev`, `test`, `production`

### Step 4: Create Pipelines

```powershell
# Run pipeline setup
.\.github\skills\pipeline-setup\scripts\create-pipelines.ps1 `
    -UseConfig `
    -SkipFirstRun
```

This creates pipelines from YAML files in `.azure-pipelines/` directory.

### Verify Setup

```powershell
# List service connections
az devops service-endpoint list --query "[].name" -o table

# List variable groups
az pipelines variable-group list --query "[].name" -o table

# List environments
az pipelines environment list --query "[].name" -o table

# List pipelines
az pipelines list --query "[].name" -o table
```

</details>

<details>
<summary><strong>🌐 Portal Approach (Manual)</strong></summary>

### Step 1: Create Azure DevOps Project

1. Navigate to [Azure DevOps](https://dev.azure.com)
2. Click **+ New project**
3. Fill in details:
   - **Project name**: `foundrycicd`
   - **Visibility**: Private
   - **Version control**: Git
   - **Work item process**: Agile
4. Click **Create**

### Step 2: Create Service Connections with Workload Identity Federation

**⚠️ Important:** Use Workload Identity Federation (no passwords!)

For each environment (dev, test, prod):

1. Go to **Project Settings** → **Service connections**
2. Click **+ New service connection**
3. Select **Azure Resource Manager** → **Next**
4. Select **Workload Identity federation (automatic)** → **Next**
5. Fill in details:
   - **Subscription**: Your Azure subscription
   - **Resource group**: Leave empty (access all)
   - **Service connection name**: `foundrycicd-dev` (change suffix for each env)
   - **Grant access permission to all pipelines**: ✅ Checked
6. Click **Save**

### Step 3: Configure Federated Credentials

**Critical Step:** Add federated credentials to your Service Principal.

For each service connection:

**Get Service Connection Information:**

```powershell
# Get service connection ID
$scName = "foundrycicd-dev"
$scId = az devops service-endpoint list --query "[?name=='$scName'].id" -o tsv

# The issuer and subject must match exactly
$orgName = "YOUR_ORG_NAME"
$projectName = "foundrycicd"
$issuer = "https://vstoken.dev.azure.com/$orgName"
$subject = "sc://$orgName/$projectName/$scName"
```

**Create Federated Credential:**

```powershell
# Get Service Principal App ID
$spAppId = "YOUR_SP_APP_ID"

# Create federated credential
az ad app federated-credential create `
    --id $spAppId `
    --parameters "{
        \`"name\`": \`"azure-devops-$projectName-dev\`",
        \`"issuer\`": \`"$issuer\`",
        \`"subject\`": \`"$subject\`",
        \`"audiences\`": [\`"api://AzureADTokenExchange\`"]
    }"
```

**Using Azure Portal:**

1. Go to **Azure Active Directory** → **App registrations**
2. Find your Service Principal: `sp-foundrycicd-cicd`
3. Click **Certificates & secrets** → **Federated credentials** tab
4. Click **+ Add credential**
5. Select **Other issuer**
6. Fill in:
   - **Name**: `azure-devops-foundrycicd-dev`
   - **Issuer**: `https://vstoken.dev.azure.com/YOUR_ORG_NAME`
   - **Subject identifier**: `sc://YOUR_ORG_NAME/foundrycicd/foundrycicd-dev`
   - **Audience**: `api://AzureADTokenExchange`
7. Click **Add**
8. Repeat for test and prod

### Step 4: Create Variable Groups

For each environment (dev, test, prod):

1. Go to **Pipelines** → **Library** → **+ Variable group**
2. Fill in details:
   - **Variable group name**: `foundrycicd-dev-vars` (change suffix for each env)
   - **Description**: Dev environment variables
3. Add variables:

   | Variable Name | Value (Example) |
   |---------------|-----------------|
   | `AZURE_AI_PROJECT_ENDPOINT` | `https://foundrycicd-dev.cognitiveservices.azure.com` |
   | `AZURE_AI_PROJECT_NAME` | `project-foundrycicd-dev` |
   | `AZURE_AI_MODEL_DEPLOYMENT_NAME` | `gpt-4o` |
   | `AZURE_RESOURCE_GROUP` | `rg-foundrycicd-dev` |
   | `AZURE_SUBSCRIPTION_ID` | `YOUR_SUBSCRIPTION_ID` |

4. **Pipeline permissions** → Click **+** → Select **Permit all pipelines**
5. Click **Save**
6. Repeat for test and prod

### Step 5: Create Environments

For each environment (dev, test, production):

1. Go to **Pipelines** → **Environments**
2. Click **+ New environment**
3. Fill in details:
   - **Name**: `dev` (change for each: dev, test, production)
   - **Description**: Development environment
   - **Resource**: None
4. Click **Create**

**For Production Environment - Add Approvals:**

1. Click on the **production** environment
2. Click **⋮** (More actions) → **Approvals and checks**
3. Click **+** → **Approvals**
4. Add approvers (users or groups)
5. Configure:
   - **Approvers**: Select users/groups
   - **Timeout**: 30 days
   - **Approval policy**: Any one user
6. Click **Create**

### Step 6: Create Pipelines

Assuming you have pipeline YAML files in your repository:

For each pipeline:

1. Go to **Pipelines** → **Pipelines**
2. Click **+ New pipeline**
3. Select **Azure Repos Git**
4. Select your repository
5. Select **Existing Azure Pipelines YAML file**
6. Choose the YAML file:
   - `.azure-pipelines/createagentpipeline.yml`
   - `.azure-pipelines/agenteval.yml`
   - `.azure-pipelines/redteam.yml`
7. Click **Continue**
8. Review the YAML
9. Click **Save** (don't run yet)
10. Rename pipeline:
    - Click **⋮** → **Rename/move**
    - Name: `Azure AI Foundry - Create Agent`
11. Repeat for other pipelines

**Using Azure CLI:**

```powershell
# Create Create Agent pipeline
az pipelines create `
    --name "Azure AI Foundry - Create Agent" `
    --repository "azure-ai-foundry-app" `
    --repository-type tfsgit `
    --branch main `
    --yml-path ".azure-pipelines/createagentpipeline.yml" `
    --skip-first-run

# Repeat for other pipelines...
```

### Step 7: Authorize Resources

Ensure all resources are authorized for pipelines:

**Service Connections:**
```powershell
$connections = @("foundrycicd-dev", "foundrycicd-test", "foundrycicd-prod")
foreach ($sc in $connections) {
    $scId = az devops service-endpoint list --query "[?name=='$sc'].id" -o tsv
    az devops service-endpoint update --id $scId --enable-for-all true
}
```

**Variable Groups:**
```powershell
$varGroups = @("foundrycicd-dev-vars", "foundrycicd-test-vars", "foundrycicd-prod-vars")
foreach ($vg in $varGroups) {
    $vgId = az pipelines variable-group list --query "[?name=='$vg'].id" -o tsv
    az pipelines variable-group update --id $vgId --authorize true
}
```

</details>

---

## ✅ Phase 4: Deployment Validation

Verify that everything is configured correctly before running your first deployment.

<details>
<summary><strong>📜 Script Approach (Automated)</strong></summary>

### Run Validation Script

```powershell
# Run deployment validation
.\.github\skills\deployment-validation\scripts\validate-deployment.ps1 `
    -UseConfig `
    -Environment 'all'
```

### What Gets Validated

The script checks:
- ✅ Configuration file exists and is valid
- ✅ Azure resources exist (resource groups, AI projects)
- ✅ Service Principal exists with correct permissions
- ✅ Service connections exist and are configured
- ✅ Variable groups exist with correct variables
- ✅ Environments exist
- ✅ Pipelines exist and reference correct resources
- ✅ RBAC permissions are correctly assigned

### Expected Output

```
=== Deployment Validation ===
✓ Configuration loaded successfully
✓ Resource groups exist (dev, test, prod)
✓ Service Principal exists
✓ RBAC roles assigned correctly
✓ AI Foundry projects exist
✓ Service connections exist and configured
✓ Variable groups exist with correct variables
✓ Environments exist
✓ Pipelines exist

Validation Summary:
  Total Checks: 15
  Passed: 15
  Failed: 0

✅ Deployment validation passed!
```

### Run Test Pipeline (Optional)

```powershell
# Get the Create Agent pipeline ID
$pipelineId = az pipelines list --query "[?name=='Azure AI Foundry - Create Agent'].id" -o tsv

# Run the pipeline
az pipelines run --id $pipelineId
```

</details>

<details>
<summary><strong>🌐 Portal Approach (Manual)</strong></summary>

### Manual Validation Checklist

Go through each item to verify your deployment:

#### ✅ Azure Resources

**Resource Groups:**
```powershell
az group list --query "[?starts_with(name, 'rg-foundrycicd')].{Name:name, Location:location, ProvisioningState:properties.provisioningState}" -o table
```

Expected output:
- `rg-foundrycicd-dev` (Succeeded)
- `rg-foundrycicd-test` (Succeeded)
- `rg-foundrycicd-prod` (Succeeded)

**Service Principal:**
```powershell
az ad sp list --display-name "sp-foundrycicd-cicd" --query "[].{DisplayName:displayName, AppId:appId}" -o table
```

Expected: One service principal with matching name and App ID

**AI Resources:**
```powershell
az cognitiveservices account list --query "[?starts_with(name, 'foundrycicd')].{Name:name, Kind:kind, Location:location, ProvisioningState:properties.provisioningState}" -o table
```

Expected: AI Services resources for dev, test, prod

#### ✅ RBAC Permissions

**Check Contributor Role:**
```powershell
$spId = az ad sp list --display-name "sp-foundrycicd-cicd" --query "[0].id" -o tsv
az role assignment list --assignee $spId --query "[?roleDefinitionName=='Contributor'].{Role:roleDefinitionName, Scope:scope}" -o table
```

Expected: Contributor role on all three resource groups

**Check Cognitive Services User Role:**
```powershell
az role assignment list --assignee $spId --query "[?roleDefinitionName=='Cognitive Services User'].{Role:roleDefinitionName, Scope:scope}" -o table
```

Expected: Cognitive Services User role on AI resources

#### ✅ Azure DevOps Resources

**Service Connections:**

1. Go to **Project Settings** → **Service connections**
2. Verify you see:
   - `foundrycicd-dev` (Azure Resource Manager)
   - `foundrycicd-test` (Azure Resource Manager)
   - `foundrycicd-prod` (Azure Resource Manager)
3. Each should show:
   - ✅ Ready
   - ✅ Workload Identity federation
   - ✅ Authorized for all pipelines

**Variable Groups:**

1. Go to **Pipelines** → **Library**
2. Verify you see:
   - `foundrycicd-dev-vars`
   - `foundrycicd-test-vars`
   - `foundrycicd-prod-vars`
3. Click each and verify variables are populated:
   - `AZURE_AI_PROJECT_ENDPOINT`
   - `AZURE_AI_PROJECT_NAME`
   - `AZURE_AI_MODEL_DEPLOYMENT_NAME`
   - `AZURE_RESOURCE_GROUP`
   - `AZURE_SUBSCRIPTION_ID`

**Environments:**

1. Go to **Pipelines** → **Environments**
2. Verify you see:
   - `dev`
   - `test`
   - `production` (with approval gate icon if configured)

**Pipelines:**

1. Go to **Pipelines** → **Pipelines**
2. Verify you see pipelines like:
   - `Azure AI Foundry - Create Agent`
   - `Azure AI Foundry - Agent Evaluation`
   - `Azure AI Foundry - Red Team`

#### ✅ Federated Credentials

**Verify Federated Credentials:**

```powershell
$spAppId = "YOUR_SP_APP_ID"
az ad app federated-credential list --id $spAppId --query "[].{Name:name, Issuer:issuer, Subject:subject}" -o table
```

Expected: 3 federated credentials (one per environment) with correct issuer and subject patterns.

#### ✅ Test Pipeline Run

1. Go to **Pipelines** → **Pipelines**
2. Select **Azure AI Foundry - Create Agent**
3. Click **Run pipeline**
4. Select **main** branch
5. Click **Run**
6. Monitor the pipeline execution
7. Expected: Pipeline runs successfully through all stages

### Validation Summary

Create a checklist and mark off each item:

```
Azure Resources:
☐ Resource groups created (dev, test, prod)
☐ Service Principal created
☐ AI Services resources created
☐ AI Foundry Projects created

RBAC Permissions:
☐ Contributor role assigned on resource groups
☐ Cognitive Services User role assigned on AI resources
☐ Federated credentials configured

Azure DevOps:
☐ Project created
☐ Service connections created and authorized
☐ Variable groups created with correct variables
☐ Environments created (dev, test, production)
☐ Pipelines created from YAML files
☐ Test pipeline run successful
```

</details>

---

## 🎯 Next Steps

Congratulations! Your Azure AI Foundry environment is now set up. Here's what you can do next:

### 1. Review Configuration

```powershell
# View your complete configuration
Get-Content .\starter-config.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

### 2. Visit Your Azure DevOps Project

Open your project in a browser:
```
https://dev.azure.com/YOUR_ORG_NAME/foundrycicd
```

### 3. Run Your First Agent Deployment

**Option A: Via Azure DevOps Portal**
1. Navigate to **Pipelines** → **Pipelines**
2. Select **Azure AI Foundry - Create Agent**
3. Click **Run pipeline**
4. Monitor the deployment

**Option B: Via CLI**
```powershell
# Get pipeline ID
$pipelineId = az pipelines list --query "[?name=='Azure AI Foundry - Create Agent'].id" -o tsv

# Run the pipeline
az pipelines run --id $pipelineId --branch main

# Monitor the run
az pipelines runs list --pipeline-ids $pipelineId --top 1
```

### 4. Explore Azure AI Foundry

Visit [Azure AI Foundry](https://ai.azure.com) to:
- View your deployed agents
- Test agent interactions
- Monitor performance metrics
- Explore evaluation results

### 5. Customize Your Deployment

- **Modify agent code**: Edit files in `src/agents/`
- **Update pipelines**: Customize YAML files in `.azure-pipelines/`
- **Add new environments**: Extend configuration for additional stages
- **Configure approvals**: Add approval gates for production deployments

### 6. Learn More

Explore additional documentation:

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [API Reference](docs/api-reference.md)
- [Azure DevOps CI/CD Reference](docs/azure-devops-cicd-reference.md)

---

## 🔧 Troubleshooting

Common issues and solutions:

### Issue: "Azure CLI not found"

**Solution:**
```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Or download from: https://learn.microsoft.com/cli/azure/install-azure-cli
```

### Issue: "Not logged in to Azure"

**Solution:**
```powershell
# Login to Azure
az login

# Verify login
az account show

# Set correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Issue: "Service connection authentication failed"

**Cause:** Federated credentials not configured correctly.

**Solution:**
```powershell
# Verify issuer and subject format
$orgName = "YOUR_ORG_NAME"
$projectName = "foundrycicd"
$scName = "foundrycicd-dev"

# Correct format
$issuer = "https://vstoken.dev.azure.com/$orgName"
$subject = "sc://$orgName/$projectName/$scName"

# Delete old credential and recreate
az ad app federated-credential delete --id $spAppId --federated-credential-id "OLD_ID"
az ad app federated-credential create --id $spAppId --parameters "{ ... }"
```

### Issue: "Variable group not found in pipeline"

**Solution:**
```powershell
# Authorize variable group for all pipelines
$vgId = az pipelines variable-group list --query "[?name=='foundrycicd-dev-vars'].id" -o tsv
az pipelines variable-group update --id $vgId --authorize true
```

### Issue: "Environment not found"

**Solution:**
Create the environment through Azure DevOps portal:
1. Go to **Pipelines** → **Environments**
2. Click **+ New environment**
3. Name it `dev` (or `test`, `production`)
4. Click **Create**

### Issue: "Permission denied when creating resources"

**Solution:**
Verify you have the necessary Azure permissions:
- Contributor role on subscription or resource group
- User Access Administrator role (for assigning RBAC)
- Application Administrator role in Azure AD (for creating Service Principals)

### Issue: "Pipeline fails with 403 Forbidden"

**Cause:** RBAC roles not assigned correctly.

**Solution:**
```powershell
# Re-assign roles
$spId = az ad sp list --display-name "sp-foundrycicd-cicd" --query "[0].id" -o tsv

az role assignment create `
    --assignee $spId `
    --role "Contributor" `
    --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-foundrycicd-dev"

az role assignment create `
    --assignee $spId `
    --role "Cognitive Services User" `
    --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-foundrycicd-dev/providers/Microsoft.CognitiveServices/accounts/foundrycicd-dev"
```

### Get More Help

- **Detailed Troubleshooting**: See [docs/troubleshooting.md](docs/troubleshooting.md)
- **Azure DevOps Issues**: [Azure DevOps Documentation](https://learn.microsoft.com/azure/devops/)
- **Azure AI Foundry**: [Azure AI Foundry Documentation](https://learn.microsoft.com/azure/ai-studio/)
- **GitHub Issues**: [Report an issue](https://github.com/your-repo/issues)

---

## 📚 Additional Resources

### Documentation

- [README.md](README.md) - Project overview
- [docs/quick-start.md](docs/quick-start.md) - Quick start guide
- [docs/architecture.md](docs/architecture.md) - Architecture overview
- [docs/naming-convention.md](docs/naming-convention.md) - Resource naming patterns

### Skills Reference

- [configuration-management](.github/skills/configuration-management/SKILL.md)
- [resource-creation](.github/skills/resource-creation/SKILL.md)
- [service-connection-setup](.github/skills/service-connection-setup/SKILL.md)
- [environment-setup](.github/skills/environment-setup/SKILL.md)
- [pipeline-setup](.github/skills/pipeline-setup/SKILL.md)
- [deployment-validation](.github/skills/deployment-validation/SKILL.md)

### External Links

- [Azure Portal](https://portal.azure.com)
- [Azure AI Foundry](https://ai.azure.com)
- [Azure DevOps](https://dev.azure.com)
- [Azure CLI Documentation](https://learn.microsoft.com/cli/azure/)
- [Azure DevOps CLI Documentation](https://learn.microsoft.com/cli/azure/devops)

---

## 💬 Feedback

Have suggestions or questions? We'd love to hear from you!

- **File Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Submit Feedback**: See [FEEDBACK.md](FEEDBACK.md)
- **Contributing**: See contribution guidelines in [README.md](README.md)

---

**Happy deploying! 🚀**
