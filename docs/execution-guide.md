# Repository Migration - Command-Line Execution Guide
## Self-Sufficient Step-by-Step Process for GitHub Copilot

**Last Updated**: January 7, 2026  
**Purpose**: Complete command-line driven migration process with automatic resource discovery

---

## 🤖 GitHub Copilot Integration

This migration guide is enhanced with **GitHub Copilot Agent Skills** for automated execution and validation.

### Quick Start with Copilot

Use the custom migration agent for guided assistance:

```
@azure-devops-migration-agent I want to migrate my repository to Azure DevOps
```

Or use individual skills directly (always start with configuration):

```
@workspace Set up my migration configuration
@workspace Validate my environment for Azure DevOps migration
@workspace Create Azure resources needed for migration
@workspace Execute the repository migration process
```

### Available Skills

1. **⚙️ configuration-management** (USE THIS FIRST!) - Manages all configurable values
2. **🔍 environment-validation** - Validates prerequisites (tools, auth, connectivity, resources)
3. **🏗️ resource-creation** - Creates Azure resources (Service Principals, ML workspaces, OpenAI)
4. **🚀 migration-execution** - Executes the complete migration workflow

**Learn more**: See [.github/skills/](.github/skills/) directory for detailed skill documentation.

**IMPORTANT**: Always start with `configuration-management` to set up centralized configuration before using other skills.

---

## 🎯 Overview

This guide provides a **fully command-line driven** process for migrating a repository from GitHub to Azure DevOps. Every step can be executed via CLI - **no browser, no clicking, no manual configuration**.

### Authentication Methods

This guide supports **two authentication methods**:

1. **Bearer Token (Recommended)** - Using `az account get-access-token`
2. **Personal Access Token (PAT)** - Traditional method

**Why Bearer Token?**
- More secure (1-hour expiration)
- No need to create/manage PATs
- Works with service principals and managed identities
- Perfect for automation

---

## 📋 Prerequisites Check
Step 0: Set Up Configuration (REQUIRED)**

Before checking prerequisites, set up your centralized configuration:

```powershell
# Interactive setup (recommended)
./.github/skills/configuration-management/configure-migration.ps1 -Interactive

# Or auto-discover from environment
./.github/skills/configuration-management/configure-migration.ps1 -AutoDiscover

# Or ask Copilot
# "@workspace Set up my migration configuration"
```

**💡 Automated Option**: Use the environment-validation skill to check all prerequisites automatically:

```powershell
# Run validation using configuration (recommended)
./.github/skills/environment-validation/validation-script.ps1 -UseConfig

# Or with explicit parameters
# Run comprehensive validation
./.github/skills/environment-validation/validation-script.ps1 `
  -OrganizationUrl "https://dev.azure.com/YOUR_ORG" `
  -ProjectName "YOUR_PROJECT" `
  -ResourceGroup "YOUR_RG" `
  -MLWorkspace "YOUR_WORKSPACE" `
  -OpenAIService "YOUR_OPENAI"

# Or ask Copilot to validate
# "@workspace Validate my Azure DevOps migration environment"
```

**Manual Option**: Check prerequisites step by step:

### Step 1: Verify Tool Installation

```powershell
# Check PowerShell version (need 7+)
$PSVersionTable.PSVersion

# Check Git
git --version

# Check Azure CLI
az --version

# Check Python
python --version
```

**Expected**:
- PowerShell: 7.0+
- Git: 2.30+
- Azure CLI: 2.50+
- Python: 3.11+

### Step 2: Install Azure DevOps Extension

```powershell
# Install extension
az extension add --name azure-devops

# Verify installation
az extension list --output table
```

---

## 🔐 Authentication Setup

### Option A: Bearer Token Authentication (Recommended)

#### For User Authentication

```powershell
# Login to Azure
az login

# Set subscription
az account set --subscription "<subscription-id>"

# Get bearer token for Azure DevOps
# Resource ID: 499b84ac-1321-427f-aa17-267ca6975798 (Azure DevOps)
$env:ADO_TOKEN = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

# Verify token
if ($env:ADO_TOKEN) {
    Write-Host "✓ Bearer token obtained successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to get bearer token" -ForegroundColor Red
}

# Set up for Azure DevOps CLI
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

# Configure default organization and project
az devops configure --defaults `
    organization=https://dev.azure.com/<your-org> `
    project=<your-project>
```

#### For Service Principal Authentication

```powershell
# Login with service principal
az login --service-principal `
    -u $env:AZURE_CLIENT_ID `
    -p $env:AZURE_CLIENT_SECRET `
    --tenant $env:AZURE_TENANT_ID

# Set subscription
az account set --subscription $env:AZURE_SUBSCRIPTION_ID

# Get bearer token
$env:ADO_TOKEN = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

# Configure defaults
az devops configure --defaults `
    organization=https://dev.azure.com/<your-org> `
    project=<your-project>
```

### Option B: Personal Access Token (PAT)

```powershell
# Create PAT via API (requires existing auth)
$organization = "<your-org>"
$headers = @{
    "Authorization" = "Bearer $env:ADO_TOKEN"
    "Content-Type" = "application/json"
}

$body = @{
    displayName = "Migration Token $(Get-Date -Format 'yyyy-MM-dd')"
    scope = "app_token"
    validTo = (Get-Date).AddDays(30).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    allOrgs = $false
} | ConvertTo-Json

$uri = "https://vssps.dev.azure.com/$organization/_apis/tokens/pats?api-version=7.1-preview.1"
$pat = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body

# Store PAT
$env:AZURE_DEVOPS_EXT_PAT = $pat.patToken.token

# Configure defaults
az devops configure --defaults `
    organization=https://dev.azure.com/<your-org> `
    project=<your-project>
```

---

## 🔍 Resource Discovery

### Step 3: Discover Existing Azure Resources

```powershell
# Store organization and project
$organization = az devops configure --list | Select-String "organization" | ForEach-Object { ($_ -split "=")[1].Trim() }
$project = az devops configure --list | Select-String "project" | ForEach-Object { ($_ -split "=")[1].Trim() }

Write-Host "Organization: $organization"
Write-Host "Project: $project"

# List existing repositories
Write-Host "`n=== Existing Repositories ===" -ForegroundColor Cyan
az repos list --output table

# List existing pipelines
Write-Host "`n=== Existing Pipelines ===" -ForegroundColor Cyan
az pipelines list --output table

# List service connections
Write-Host "`n=== Service Connections ===" -ForegroundColor Cyan
az devops service-endpoint list --output table

# List variable groups (uses configuration)
# "@workspace Check and create Azure resources needed for migration"

# Configuration is automatically loaded from migration-config.json
# No need to specify resource names - they come from your configuration "Bearer $env:ADO_TOKEN"
}
$envs.value | Select-Object id, name | Format-Table
```

### Step 4: Discover Azure Resources

**💡 Automated Option**: Use the resource-creation skill to discover and create resources:

```powershell
# Ask Copilot to handle resource discovery and creation
# "@workspace Check and create Azure resources needed for migration"

# Or run the resource creation script
./.github/skills/resource-creation/create-resources.ps1 `
  -ResourceGroupName "northwind-ml-rg" `
  -Location "eastus" `
  -CheckExisting $true `
  -SkipIfExists $true
```

**Manual Option**: Discover resources step by step:

```powershell
# Ensure logged in to Azure
az account show

# List Azure AI/ML workspaces
Write-Host "`n=== Azure AI/ML Workspaces ===" -ForegroundColor Cyan
az ml workspace list --output table

# List Azure OpenAI accounts
Write-Host "`n=== Azure OpenAI Services ===" -ForegroundColor Cyan
az cognitiveservices account list `
    --query "[?kind=='OpenAI']" `
    --output table

# Get OpenAI endpoint and keys
$openaiAccounts = az cognitiveservices account list `
    --query "[?kind=='OpenAI'].{name:name, resourceGroup:resourceGroup}" `
    | ConvertFrom-Json

foreach ($account in $openaiAccounts) {
    Write-Host "`nOpenAI Account: $($account.name)" -ForegroundColor Yellow
    
    # Get endpoint
    $endpoint = az cognitiveservices account show `
        --name $account.name `
        --resource-group $account.resourceGroup `
        --query "properties.endpoint" `
        --output tsv
    
    Write-Host "  Endpoint: $endpoint"
    
    # Get deployment names
    $deployments = az cognitiveservices account deployment list `
        --name $account.name `
        --resource-group $account.resourceGroup `
        --query "[].name" `
        --output tsv
    
    Write-Host "  Deployments: $($deployments -join ', ')"
}

# List resource groups
Write-Host "`n=== Resource Groups ===" -ForegroundColor Cyan
az group list --output table

# Get service principal info
Write-Host "`n=== Current Identity ===" -ForegroundColor Cyan
$identity = az account show | ConvertFrom-Json
Write-Host "User: $($identity.user.name)"
Write-Host "Tenant: $($identity.tenantId)"
Write-Host "Subscription: $($identity.name) ($($identity.id))"
```

---

## 🏗️ Create Missing Azure Resources

**💡 Automated Option**: See the [resource-creation skill](.github/skills/resource-creation/SKILL.md) for comprehensive resource creation automation.

### Step 5: Create Service Principal (if needed)


```powershell
# Check if service principal exists
$spName = "foundry-cicd-sp"

$existingSp = az ad sp list --display-name $spName --query "[].{appId:appId, displayName:displayName}" --output json | ConvertFrom-Json

if ($existingSp) {
    Write-Host "✓ Service Principal '$spName' already exists" -ForegroundColor Green
    $spAppId = $existingSp.appId
} else {
    Write-Host "Creating new Service Principal: $spName" -ForegroundColor Yellow
    
    # Get subscription ID
    $subscriptionId = az account show --query id --output tsv
    
    # Create service principal
    $sp = az ad sp create-for-rbac `
        --name $spName `
        --role "Contributor" `
        --scopes "/subscriptions/$subscriptionId" `
        --output json | ConvertFrom-Json
    
    Write-Host "✓ Service Principal created" -ForegroundColor Green
    Write-Host "  App ID: $($sp.appId)"
    Write-Host "  Tenant: $($sp.tenant)"
    Write-Host "  ⚠️  Secret: $($sp.password) (SAVE THIS - shown only once)" -ForegroundColor Red
    
    $spAppId = $sp.appId
    
    # Store for later use
    $env:AZURE_CLIENT_ID = $sp.appId
    $env:AZURE_CLIENT_SECRET = $sp.password
    $env:AZURE_TENANT_ID = $sp.tenant
}
```

### Step 6: Create Azure AI/ML Workspace (if needed)

```powershell
# Variables
$resourceGroup = "rg-foundry-cicd"
$location = "eastus"
$workspaceName = "mlw-foundry-cicd-dev"

# Check if resource group exists
$rgExists = az group exists --name $resourceGroup

if ($rgExists -eq "false") {
    Write-Host "Creating resource group: $resourceGroup" -ForegroundColor Yellow
    az group create --name $resourceGroup --location $location
    Write-Host "✓ Resource group created" -ForegroundColor Green
}

# Check if workspace exists
$workspaceExists = az ml workspace show `
    --name $workspaceName `
    --resource-group $resourceGroup `
    --query "name" `
    --output tsv 2>$null

if (-not $workspaceExists) {
    Write-Host "Creating Azure ML workspace: $workspaceName" -ForegroundColor Yellow
    
    az ml workspace create `
        --name $workspaceName `
        --resource-group $resourceGroup `
        --location $location
    
    Write-Host "✓ Workspace created" -ForegroundColor Green
} else {
    Write-Host "✓ Workspace '$workspaceName' already exists" -ForegroundColor Green
}

# Get workspace endpoint
$workspaceEndpoint = az ml workspace show `
    --name $workspaceName `
    --resource-group $resourceGroup `
    --query "mlFlowTrackingUri" `
    --output tsv

Write-Host "Workspace Endpoint: $workspaceEndpoint"
```

### Step 7: Create Azure OpenAI Service (if needed)

```powershell
$openaiName = "oai-foundry-cicd-dev"
$resourceGroup = "rg-foundry-cicd"
$location = "eastus"

# Check if OpenAI account exists
$openaiExists = az cognitiveservices account show `
    --name $openaiName `
    --resource-group $resourceGroup `
    --query "name" `
    --output tsv 2>$null

if (-not $openaiExists) {
    Write-Host "Creating Azure OpenAI service: $openaiName" -ForegroundColor Yellow
    
    az cognitiveservices account create `
        --name $openaiName `
        --resource-group $resourceGroup `
        --kind OpenAI `
        --sku S0 `
        --location $location `
        --yes
    
    Write-Host "✓ Azure OpenAI service created" -ForegroundColor Green
} else {
    Write-Host "✓ Azure OpenAI '$openaiName' already exists" -ForegroundColor Green
}

# Get endpoint and key
$openaiEndpoint = az cognitiveservices account show `
    --name $openaiName `
    --resource-group $resourceGroup `
    --query "properties.endpoint" `
    --output tsv

$openaiKey = az cognitiveservices account keys list `
    --name $openaiName `
    --resource-group $resourceGroup `
    --query "key1" `
    --output tsv

Write-Host "OpenAI Endpoint: $openaiEndpoint"
Write-Host "OpenAI Key: $openaiKey"

# Create deployment if needed
$deploymentName = "gpt-4o"

$deploymentExists = az cognitiveservices account deployment show `
    --name $openaiName `
    --resource-group $resourceGroup `
    --deployment-name $deploymentName `
    --query "name" `
    --output tsv 2>$null

if (-not $deploymentExists) {
    Write-Host "Creating deployment: $deploymentName" -ForegroundColor Yellow
    
    az cognitiveservices account deployment create `
        --name $openaiName `
        --resource-group $resourceGroup `
        --deployment-name $deploymentName `
        --model-name gpt-4o `
        --model-version "2024-05-13" `
        --model-format OpenAI `
        --sku-capacity 10 `
        --sku-name "Standard"
    
    Write-Host "✓ Deployment created" -ForegroundColor Green
} else {
    Write-Host "✓ Deployment '$deploymentName' already exists" -ForegroundColor Green
}
```

---

## 📦 Repository Migration

### Step 8: Clone Source Repository

```powershell
# Create workspace
$workspacePath = "C:\Repos\migration-workspace"
New-Item -ItemType Directory -Path $workspacePath -Force | Out-Null
Set-Location $workspacePath

# Clone from GitHub
$sourceRepo = "https://github.com/balakreshnan/foundrycicdbasic.git"
git clone $sourceRepo source-repo

# Enter repo
cd source-repo

# Verify contents
Get-ChildItem | Format-Table
```

### Step 9: Create Backup

```powershell
cd ..
$backupName = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -Path "source-repo" -Destination $backupName -Recurse
Compress-Archive -Path $backupName -DestinationPath "$backupName.zip"

Write-Host "✓ Backup created: $backupName.zip" -ForegroundColor Green
```

### Step 10: Reorganize Repository Structure

**💡 Automated Option**: Use the migration-execution skill for complete migration automation:

```powershell
# Ask Copilot to execute the migration
# "@workspace Execute the Azure DevOps repository migration"

# Or see the migration-execution skill for detailed guidance
# .github/skills/migration-execution/SKILL.md
```

**Manual Option**: Reorganize repository step by step:

```powershell
cd source-repo

# Create new directory structure
$directories = @(
    ".azure-pipelines",
    ".azure-pipelines/templates",
    "config",
    "docs/architecture",
    "docs/guides",
    "src/agents",
    "src/evaluation",
    "src/security",
    "src/utils",
    "scripts",
    "tests/unit",
    "tests/integration"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Write-Host "✓ Directory structure created" -ForegroundColor Green

# Move Python files
$fileMoves = @{
    "createagent.py" = "src/agents/create_agent.py"
    "exagent.py" = "src/agents/test_agent.py"
    "agenteval.py" = "src/evaluation/evaluate_agent.py"
    "redteam.py" = "src/security/redteam_scan.py"
    "redteam1.py" = "src/security/redteam_advanced.py"
}

foreach ($source in $fileMoves.Keys) {
    if (Test-Path $source) {
        Move-Item -Path $source -Destination $fileMoves[$source] -Force
        Write-Host "Moved: $source → $($fileMoves[$source])"
    }
}

# Move CI/CD files
if (Test-Path "cicd") {
    if (Test-Path "cicd/createagentpipeline.yml") {
        Move-Item "cicd/createagentpipeline.yml" ".azure-pipelines/create-agent-pipeline.yml" -Force
    }
    if (Test-Path "cicd/agentconsumptionpipeline.yml") {
        Move-Item "cicd/agentconsumptionpipeline.yml" ".azure-pipelines/test-agent-pipeline.yml" -Force
    }
    Remove-Item "cicd" -Recurse -Force
}

# Create __init__.py files
$initFiles = @(
    "src/__init__.py",
    "src/agents/__init__.py",
    "src/evaluation/__init__.py",
    "src/security/__init__.py",
    "src/utils/__init__.py"
)

foreach ($file in $initFiles) {
    New-Item -ItemType File -Path $file -Force | Out-Null
    Set-Content -Path $file -Value "# Package file"
}

Write-Host "✓ Files reorganized" -ForegroundColor Green

# Update pipeline references
Get-ChildItem -Path ".azure-pipelines" -Filter "*.yml" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace 'createagent\.py', 'src/agents/create_agent.py'
    $content = $content -replace 'exagent\.py', 'src/agents/test_agent.py'
    $content = $content -replace 'agenteval\.py', 'src/evaluation/evaluate_agent.py'
    $content = $content -replace 'redteam\.py', 'src/security/redteam_scan.py'
    Set-Content -Path $_.FullName -Value $content
}

Write-Host "✓ Pipeline references updated" -ForegroundColor Green
```

### Step 11: Commit Changes

```powershell
# Create branch
git checkout -b migration/reorganize

# Stage all changes
git add -A

# Commit
git commit -m "Reorganize repository structure

- Move Python scripts to src/ with module structure
- Reorganize CI/CD files to .azure-pipelines/
- Create Python package structure
- Update pipeline references"

Write-Host "✓ Changes committed" -ForegroundColor Green
```

---

## 🏗️ Azure DevOps Configuration

### Step 12: Create Repository

```powershell
$repoName = "foundry-cicd"

# Check if repository exists
$existingRepo = az repos list --query "[?name=='$repoName'].id" --output tsv

if ($existingRepo) {
    Write-Host "✓ Repository '$repoName' already exists" -ForegroundColor Yellow
    $repoId = $existingRepo
} else {
    Write-Host "Creating repository: $repoName" -ForegroundColor Yellow
    
    # Create repository
    $repo = az repos create --name $repoName --output json | ConvertFrom-Json
    $repoId = $repo.id
    
    Write-Host "✓ Repository created" -ForegroundColor Green
    Write-Host "  Clone URL: $($repo.remoteUrl)"
}

# Get repository details
$repoDetails = az repos show --repository $repoName --output json | ConvertFrom-Json
$remoteUrl = $repoDetails.remoteUrl

Write-Host "`nRepository URL: $remoteUrl"
```

### Step 13: Push Code to Azure DevOps

```powershell
# Add Azure DevOps remote
git remote add azure $remoteUrl

# Configure git to use bearer token
git config --local http.extraheader "AUTHORIZATION: bearer $env:ADO_TOKEN"

# Push main branch
git checkout main
git push azure main

# Push reorganization branch
git checkout migration/reorganize
git push azure migration/reorganize

Write-Host "✓ Code pushed to Azure DevOps" -ForegroundColor Green

# Remove extraheader (security)
git config --local --unset http.extraheader
```

### Step 14: Create Service Connections

```powershell
$environments = @("dev", "test", "prod")
$subscriptionId = az account show --query id --output tsv
$subscriptionName = az account show --query name --output tsv
$tenantId = az account show --query tenantId --output tsv

foreach ($env in $environments) {
    $scName = "azure-foundry-$env"
    
    # Check if service connection exists
    $existingSc = az devops service-endpoint list `
        --query "[?name=='$scName'].id" `
        --output tsv
    
    if ($existingSc) {
        Write-Host "✓ Service connection '$scName' already exists" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Creating service connection: $scName" -ForegroundColor Yellow
    
    # Create service connection
    az devops service-endpoint azurerm create `
        --azure-rm-service-principal-id $env:AZURE_CLIENT_ID `
        --azure-rm-subscription-id $subscriptionId `
        --azure-rm-subscription-name $subscriptionName `
        --azure-rm-tenant-id $tenantId `
        --name $scName
    
    # Set secret (requires separate call)
    $scId = az devops service-endpoint list `
        --query "[?name=='$scName'].id" `
        --output tsv
    
    az devops service-endpoint update `
        --id $scId `
        --enable-for-all true
    
    Write-Host "✓ Service connection created: $scName" -ForegroundColor Green
}
```

### Step 15: Create Variable Groups

```powershell
$environments = @{
    "dev" = @{
        project = "https://dev-project.api.azureml.ms"
        openai = "https://dev-openai.openai.azure.com/"
    }
    "test" = @{
        project = "https://test-project.api.azureml.ms"
        openai = "https://test-openai.openai.azure.com/"
    }
    "prod" = @{
        project = "https://prod-project.api.azureml.ms"
        openai = "https://prod-openai.openai.azure.com/"
    }
}

foreach ($env in $environments.Keys) {
    $vgName = "foundry-$env-vars"
    $config = $environments[$env]
    
    # Check if variable group exists
    $existingVg = az pipelines variable-group list `
        --query "[?name=='$vgName'].id" `
        --output tsv
    
    if ($existingVg) {
        Write-Host "✓ Variable group '$vgName' already exists" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Creating variable group: $vgName" -ForegroundColor Yellow
    
    # Create variable group
    az pipelines variable-group create `
        --name $vgName `
        --variables `
            AZURE_AI_PROJECT_$($env.ToUpper())="$($config.project)" `
            AZURE_OPENAI_ENDPOINT_$($env.ToUpper())="$($config.openai)" `
            AZURE_OPENAI_API_VERSION_$($env.ToUpper())="2024-02-15-preview" `
            AZURE_OPENAI_DEPLOYMENT_$($env.ToUpper())="gpt-4o" `
            AZURE_SERVICE_CONNECTION_$($env.ToUpper())="azure-foundry-$env" `
        --authorize true
    
    Write-Host "✓ Variable group created: $vgName" -ForegroundColor Green
    
    # Add secret variable (OpenAI key) separately
    $vgId = az pipelines variable-group list `
        --query "[?name=='$vgName'].id" `
        --output tsv
    
    az pipelines variable-group variable create `
        --group-id $vgId `
        --name "AZURE_OPENAI_KEY_$($env.ToUpper())" `
        --value "placeholder-update-this" `
        --secret true
}
```

### Step 16: Create Environments

```powershell
# Note: az devops doesn't support environments, using REST API
$orgUrl = az devops configure --list | Select-String "organization" | ForEach-Object { ($_ -split "=")[1].Trim() }
$projectName = az devops configure --list | Select-String "project" | ForEach-Object { ($_ -split "=")[1].Trim() }

$envNames = @("dev", "test", "production")

foreach ($envName in $envNames) {
    $uri = "$orgUrl/$projectName/_apis/distributedtask/environments?api-version=7.1-preview.1"
    
    # Check if environment exists
    $existingEnvs = Invoke-RestMethod -Uri $uri -Headers @{
        "Authorization" = "Bearer $env:ADO_TOKEN"
    }
    
    $exists = $existingEnvs.value | Where-Object { $_.name -eq $envName }
    
    if ($exists) {
        Write-Host "✓ Environment '$envName' already exists" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Creating environment: $envName" -ForegroundColor Yellow
    
    $body = @{
        name = $envName
        description = "$envName environment for foundry-cicd"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri $uri -Method Post -Headers @{
        "Authorization" = "Bearer $env:ADO_TOKEN"
        "Content-Type" = "application/json"
    } -Body $body
    
    Write-Host "✓ Environment created: $envName" -ForegroundColor Green
}
```

### Step 17: Create Pipelines

```powershell
$pipelines = @(
    @{
        name = "Foundry Agent Creation"
        path = ".azure-pipelines/create-agent-pipeline.yml"
    }
    @{
        name = "Foundry Agent Testing"
        path = ".azure-pipelines/test-agent-pipeline.yml"
    }
)

foreach ($pipeline in $pipelines) {
    # Check if pipeline exists
    $existingPipeline = az pipelines list `
        --query "[?name=='$($pipeline.name)'].id" `
        --output tsv
    
    if ($existingPipeline) {
        Write-Host "✓ Pipeline '$($pipeline.name)' already exists" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Creating pipeline: $($pipeline.name)" -ForegroundColor Yellow
    
    # Create pipeline
    az pipelines create `
        --name "$($pipeline.name)" `
        --repository $repoName `
        --repository-type tfsgit `
        --branch main `
        --yml-path "$($pipeline.path)" `
        --skip-first-run
    
    Write-Host "✓ Pipeline created: $($pipeline.name)" -ForegroundColor Green
}
```

---

## ✅ Validation & Testing

### Step 18: Validate Repository Structure

```powershell
Write-Host "`n=== Repository Validation ===" -ForegroundColor Cyan

# Check required directories
$requiredDirs = @(
    ".azure-pipelines",
    "src/agents",
    "src/evaluation",
    "src/security",
    "config"
)

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host "✓ $dir" -ForegroundColor Green
    } else {
        Write-Host "✗ $dir MISSING" -ForegroundColor Red
    }
}
```

### Step 19: Test Pipeline Run

```powershell
# Get pipeline ID
$pipelineName = "Foundry Agent Creation"
$pipelineId = az pipelines list `
    --query "[?name=='$pipelineName'].id" `
    --output tsv

Write-Host "Running pipeline: $pipelineName (ID: $pipelineId)" -ForegroundColor Yellow

# Queue pipeline run
$run = az pipelines run `
    --id $pipelineId `
    --branch main `
    --output json | ConvertFrom-Json

Write-Host "✓ Pipeline run queued" -ForegroundColor Green
Write-Host "  Run ID: $($run.id)"
Write-Host "  URL: $($run._links.web.href)"

# Open in browser (optional)
# Start-Process $run._links.web.href
```

### Step 20: Refresh Bearer Token (if expired)

```powershell
# Bearer tokens expire after 1 hour
# Refresh when needed

Write-Host "Refreshing bearer token..." -ForegroundColor Yellow

$env:ADO_TOKEN = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

Write-Host "✓ Bearer token refreshed" -ForegroundColor Green
```

---

## 🔧 Additional CLI Commands

### List All Resources

```powershell
# List repositories
az repos list --output table

# List pipelines
az pipelines list --output table

# List pipeline runs
az pipelines runs list --pipeline-ids <pipeline-id> --output table

# List builds
az pipelines build list --output table

# List service endpoints
az devops service-endpoint list --output table

# List variable groups
az pipelines variable-group list --output table

# List users
az devops user list --output table

# List teams
az devops team list --output table
```

### Update Variable Group

```powershell
# Use projectName from config.naming.projectName
$vgName = "$projectName-dev-vars"
$vgId = az pipelines variable-group list `
    --query "[?name=='$vgName'].id" `
    --output tsv

# Add/update variable
az pipelines variable-group variable create `
    --group-id $vgId `
    --name "NEW_VARIABLE" `
    --value "new-value"

# Update secret variable
az pipelines variable-group variable update `
    --group-id $vgId `
    --name "AZURE_OPENAI_KEY_DEV" `
    --value "actual-key-value" `
    --secret true
```

### Delete Resources

```powershell
# Delete repository
az repos delete --id <repo-id> --yes

# Delete pipeline
az pipelines delete --id <pipeline-id> --yes

# Delete service endpoint
az devops service-endpoint delete --id <endpoint-id> --yes

# Delete variable group
az pipelines variable-group delete --group-id <group-id> --yes
```

### Grant Permissions

```powershell with Configuration

Save this as `execute-migration.ps1`:

```powershell
# Complete Migration Script
# Run this to execute the entire migration

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Repository Migration - Automated Execution" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 0: Set up configuration (REQUIRED)
Write-Host "`n[0/21] Setting up configuration..." -ForegroundColor Yellow
./.github/skills/configuration-management/configure-migration.ps1 -Interactive
Write-Host "✓ Configuration set up" -ForegroundColor Green

# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-MigrationConfig

# Step 1: Authenticate
Write-Host "`n[1/21] Authenticating..." -ForegroundColor Yellow
az login
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
Write-Host "✓ Authenticated" -ForegroundColor Green

# Step 2: Configure defaults (from configuration)
Write-Host "`n[2/21] Configuring Azure DevOps..." -ForegroundColor Yellow
az devops configure --defaults `
    organization=$($config.azureDevOps.organizationUrl) `
    project=$($config.azureDevOps.projectName)
Write-Host "✓ Configured" -ForegroundColor Green

# Step 3: Validate environment
Write-Host "`n[3/21] Validating environment..." -ForegroundColor Yellow
./.github/skills/environment-validation/validation-script.ps1 -UseConfig
Write-Host "✓ Environment validated" -ForegroundColor Green

# Step 4-21: Continue with all steps using $config values...
# (Include all steps from above, using configuration values
# Step 1: Authenticate
Write-Host "`n[1/20] Authenticating..." -ForegroundColor Yellow
az login
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
Write-Host "✓ Authenticated" -ForegroundColor Green

# Step 2: Configure defaults
Write-Host "`n[2/20] Configuring Azure DevOps..." -ForegroundColor Yellow
az devops configure --defaults organization=https://dev.azure.com/<your-org> project=<your-project>
Write-Host "✓ Configured" -ForegroundColor Green

# Step 3-20: Continue with all steps...
# (Include all steps from above)

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Migration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
```

---

## 🚨 Troubleshooting

### Token Expired

```powershell
# Refresh bearer token
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```
⚙️ [configuration-management](.github/skills/configuration-management/)** - **USE THIS FIRST!**
  - Interactive configuration setup wizard
  - Auto-discovery of existing resources
  - Centralized configuration management
  - Eliminates hardcoded values throughout migration
  - Single source of truth for all settings

- **🔍 [environment-validation](.github/skills/environment-validation/)** - Comprehensive environment validation
  - Validates tool versions, authentication, connectivity, and resources
  - Loads configuration automatically with `-UseConfig` flag
  - Provides troubleshooting guidance for common issues
  - Generates detailed validation reports
  
- **🏗️ [resource-creation](.github/skills/resource-creation/)** - Azure resource provisioning
  - Creates Service Principals with proper RBAC
  - Deploys Azure ML workspaces
  - Sets up Azure OpenAI services with model deployments
  - Checks for existing resources before creating
  - Automatically loads configuration for consistent naming
  
- **🚀 [migration-execution](.github/skills/migration-execution/)** - Complete migration workflow
  - Executes repository reorganization
  - Configures Azure DevOps repositories and pipelines
  - Sets up service connections and variable groups
  - Validates migration success
  - Loads configuration for all operation
az pipelines runs show --id $runId --output json

# Download logs
az pipelines runs artifact download --artifact-name logs --path ./logs --run-id $runId
```

---

## 📚 Additional Resources

### GitHub Copilot Agent Skills

This guide is enhanced with custom Agent Skills for automated execution:

- **[environment-validation](.github/skills/environment-validation/)** - Comprehensive environment validation
  - Validates tool versions, authentication, connectivity, and resources
  - Provides troubleshooting guidance for common issues
  - Generates detailed valifour skills and guides you through the complete migration process with:
- **Phase 0: Configuration Setup** (always first)
- **Phase 1: Environment Validation**
- **Phase 2: Resource Provisioning**
- **Phase 3: Migration Execution**
- **Phase 4: Post-Migration Validation**
- **Continuous: Troubleshooting Support**services with model deployments
  - Checks for existing resources before creating
  
- **[migration-execution](.github/skills/migration-execution/)** - Complete migration workflow
  - Executes repository reorganization
  - Configures Azure DevOps repositories and pipelines
  - Sets up service connections and variable groups
  - Validates migration success

### Custom Agent

Use the **azure-devops-migration-agent** for guided assistance:

```
@azure-devops-migration-agent I want to migrate my repository
```

The agent orchestrates all skills and guides you through the complete migration process with:
- Environment validation
- Resource provisioning
- Migration execution
- Post-migration validation
- Troubleshooting support
Configuration set up and validated
- ✅ All Azure resources discovered or created
- ✅ Repository created and code pushed
- ✅ Service connections configured
- ✅ Variable groups created
- ✅ Environments created
- ✅ Pipelines created and tested
- ✅ All operations performed via CLI
- ✅ No manual browser interactions required
- ✅ Configuration file backed up and secure

This is the **Azure DevOps resource ID** used when requesting bearer tokens.

### Useful Links

- [az devops CLI reference](https://learn.microsoft.com/en-us/cli/azure/devops)
- [Azure DevOps REST API](https://learn.microsoft.com/en-us/rest/api/azure/devops/)
- [Bearer Token Authentication](https://learn.microsoft.com/en-us/azure/devops/cli/entra-tokens)

---

## ✅ Success Criteria

Migration is complete when:

- ✅ All Azure resources discovered or created
- ✅ Repository created and code pushed
- ✅ Service connections configured
- ✅ Variable groups created
- ✅ Environments created
- ✅ Pipelines created and tested
- ✅ All operations performed via CLI
- ✅ No manual browser interactions required

---

**Document Version**: 1.0  
**Last Updated**: January 7, 2026  
**Maintained by**: DevOps Team
