# Complete Repository Migration Guide
## From GitHub (balakreshnan/foundrycicdbasic) to Azure DevOps with Reorganization

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Pre-Migration Checklist](#pre-migration-checklist)
4. [Phase 1: Preparation](#phase-1-preparation)
5. [Phase 2: Repository Creation](#phase-2-repository-creation)
6. [Phase 3: Code Migration](#phase-3-code-migration)
7. [Phase 4: Reorganization](#phase-4-reorganization)
8. [Phase 5: Azure DevOps Configuration](#phase-5-azure-devops-configuration)
9. [Phase 6: Testing & Validation](#phase-6-testing--validation)
10. [Rollback Procedures](#rollback-procedures)
11. [Troubleshooting](#troubleshooting)

---

## Overview

### What This Guide Does

This comprehensive guide will help you:
- Clone the `balakreshnan/foundrycicdbasic` repository from GitHub
- Reorganize its structure for better maintainability
- Create a new repository in Azure DevOps
- Configure CI/CD pipelines using Azure DevOps REST API
- Set up service connections, variable groups, and environments
- Validate the complete migration

### Timeline Estimate

- **Small Team (1-2 people)**: 4-6 hours
- **Preparation**: 1 hour
- **Migration**: 2-3 hours
- **Configuration**: 1-2 hours
- **Testing & Validation**: 30-60 minutes

### Migration Strategy

**Approach**: Fresh start with reorganization
- Clone source repository
- Reorganize locally
- Push to new Azure DevOps repository
- Configure pipelines and infrastructure
- Preserve git history (optional)

---

## Prerequisites

### Required Access & Permissions

#### Azure DevOps
- [ ] Azure DevOps organization access
- [ ] Project Administrator or Build Administrator permissions
- [ ] Ability to create service connections
- [ ] Ability to create pipelines
- [ ] Ability to manage variable groups

#### Azure Subscription
- [ ] Azure subscription with appropriate permissions
- [ ] Ability to create service principals
- [ ] Access to Azure AI Foundry resources
- [ ] Access to Azure OpenAI resources

#### Development Environment
- [ ] Git installed (version 2.30+)
- [ ] Azure CLI installed (version 2.50+)
- [ ] PowerShell 7+ (Windows/Mac/Linux) OR Bash
- [ ] Python 3.11+ installed
- [ ] Code editor (VS Code recommended)

### Required Tools

```powershell
# Check Git
git --version  # Should be 2.30 or higher

# Check Azure CLI
az --version  # Should be 2.50 or higher

# Check PowerShell
$PSVersionTable.PSVersion  # Should be 7.0 or higher

# Check Python
python --version  # Should be 3.11 or higher
```

### Authentication Setup

#### 1. Azure DevOps Personal Access Token (PAT)

1. Navigate to Azure DevOps: `https://dev.azure.com/{your-organization}`
2. Click on **User Settings** (top right) → **Personal Access Tokens**
3. Click **+ New Token**
4. Configure:
   - **Name**: `Repository Migration Token`
   - **Organization**: Select your organization
   - **Expiration**: 30 days (or custom)
   - **Scopes**: 
     - ✅ **Code** (Full)
     - ✅ **Build** (Read & execute)
     - ✅ **Release** (Read, write, & execute)
     - ✅ **Service Connections** (Read, query, & manage)
     - ✅ **Variable Groups** (Read, create, & manage)
5. Click **Create**
6. **IMPORTANT**: Copy and securely store the PAT (you won't see it again)

```powershell
# Store PAT securely
$env:AZURE_DEVOPS_PAT = "your-pat-token-here"
```

#### 2. Azure Service Principal

Create a service principal for Azure resource access:

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac --name "foundry-cicd-migration-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/{subscription-id}"

# Output will look like:
# {
#   "appId": "xxx-xxx-xxx",          # This is CLIENT_ID
#   "displayName": "...",
#   "password": "xxx-xxx-xxx",       # This is CLIENT_SECRET
#   "tenant": "xxx-xxx-xxx"          # This is TENANT_ID
# }
```

Save these values securely:
```powershell
$env:AZURE_CLIENT_ID = "xxx"
$env:AZURE_CLIENT_SECRET = "xxx"
$env:AZURE_TENANT_ID = "xxx"
$env:AZURE_SUBSCRIPTION_ID = "xxx"
```

#### 3. Assign Azure Roles

Grant the service principal necessary permissions:

```bash
# For Azure AI Foundry
az role assignment create \
  --assignee $env:AZURE_CLIENT_ID \
  --role "Azure AI Developer" \
  --scope "/subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/{your-rg}"

# For Azure OpenAI
az role assignment create \
  --assignee $env:AZURE_CLIENT_ID \
  --role "Cognitive Services Contributor" \
  --scope "/subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/{your-rg}"
```

---

## Pre-Migration Checklist

### Information Gathering

Complete this checklist before starting:

```yaml
# Azure DevOps Information
- Organization URL: https://dev.azure.com/{organization}
- Project Name: _______________
- New Repository Name: foundry-cicd
- PAT Token: (stored securely) ✓

# Azure Resources (for each environment: dev, test, prod)
Dev Environment:
  - Azure AI Project URL: https://______.api.azureml.ms
  - Azure OpenAI Endpoint: https://______.openai.azure.com/
  - Azure OpenAI Deployment Name: gpt-4o
  - Resource Group Name: _______________

Test Environment:
  - Azure AI Project URL: https://______.api.azureml.ms
  - Azure OpenAI Endpoint: https://______.openai.azure.com/
  - Azure OpenAI Deployment Name: gpt-4o
  - Resource Group Name: _______________

Prod Environment:
  - Azure AI Project URL: https://______.api.azureml.ms
  - Azure OpenAI Endpoint: https://______.openai.azure.com/
  - Azure OpenAI Deployment Name: gpt-4o
  - Resource Group Name: _______________

# Service Principal Information
- Client ID: _______________
- Client Secret: (stored securely) ✓
- Tenant ID: _______________
- Subscription ID: _______________
```

### Create Working Directory

```powershell
# Create migration workspace
New-Item -ItemType Directory -Path "C:\Repos\northwind-systems\migration-workspace" -Force
Set-Location "C:\Repos\northwind-systems\migration-workspace"
```

---

## Phase 1: Preparation

### Step 1.1: Clone Source Repository

```powershell
# Clone from GitHub
git clone https://github.com/balakreshnan/foundrycicdbasic.git source-repo
cd source-repo

# Verify contents
Get-ChildItem -Recurse -Depth 2
```

### Step 1.2: Backup Original

```powershell
# Create backup
cd ..
Copy-Item -Path "source-repo" -Destination "source-repo-backup" -Recurse

# Create archive
Compress-Archive -Path "source-repo-backup" -DestinationPath "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
```

### Step 1.3: Analyze Repository

```powershell
cd source-repo

# Check file count
(Get-ChildItem -Recurse -File).Count

# Check total size
(Get-ChildItem -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB

# List all files
Get-ChildItem -Recurse -File | Select-Object FullName
```

---

## Phase 2: Repository Creation

### Step 2.1: Create Azure DevOps Repository via REST API

#### Manual Method (Azure DevOps Portal)

1. Navigate to `https://dev.azure.com/{organization}/{project}`
2. Click **Repos** → **Files**
3. Click dropdown at top → **+ New repository**
4. Configure:
   - **Repository name**: `foundry-cicd`
   - **Type**: Git
   - **Add a README**: ❌ (we'll push our own)
   - **Add .gitignore**: ❌ (we have one)
5. Click **Create**

#### Automated Method (REST API)

```powershell
# Set variables
$organization = "your-organization"
$project = "your-project"
$repoName = "foundry-cicd"
$pat = $env:AZURE_DEVOPS_PAT

# Encode PAT for Basic Auth
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))

# Create repository
$uri = "https://dev.azure.com/$organization/$project/_apis/git/repositories?api-version=7.1"
$body = @{
    name = $repoName
    project = @{
        name = $project
    }
} | ConvertTo-Json

$headers = @{
    Authorization = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body

Write-Host "Repository created successfully!"
Write-Host "Repository ID: $($response.id)"
Write-Host "Clone URL: $($response.remoteUrl)"

# Save clone URL for later
$cloneUrl = $response.remoteUrl
$env:AZURE_DEVOPS_REPO_URL = $cloneUrl
```

### Step 2.2: Configure Git Remote

```powershell
cd source-repo

# Add Azure DevOps remote
git remote add azure $env:AZURE_DEVOPS_REPO_URL

# Verify remotes
git remote -v
```

---

## Phase 3: Code Migration

### Step 3.1: Create New Branch for Reorganization

```powershell
# Create and checkout new branch
git checkout -b migration/reorganize-structure

# Verify clean working directory
git status
```

### Step 3.2: Reorganize Directory Structure

This is the core migration step where we reorganize files.

```powershell
# Create new directory structure
$directories = @(
    ".azure-pipelines",
    ".azure-pipelines/templates",
    "config",
    "docs/getting-started",
    "docs/architecture",
    "docs/guides",
    "docs/cicd",
    "docs/api",
    "src",
    "src/agents",
    "src/evaluation",
    "src/security",
    "src/utils",
    "scripts/setup",
    "scripts/deployment",
    "scripts/utilities",
    "tests/unit",
    "tests/integration",
    "tests/fixtures",
    "examples/basic-agent",
    "examples/advanced-agent",
    "examples/ci-cd-samples",
    "tools/migration",
    "tools/dev"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Path $dir -Force
}

Write-Host "✓ Directory structure created"
```

### Step 3.3: Move and Rename Files

```powershell
# Move Python scripts to src/
Move-Item -Path "createagent.py" -Destination "src/agents/create_agent.py"
Move-Item -Path "exagent.py" -Destination "src/agents/test_agent.py"
Move-Item -Path "agenteval.py" -Destination "src/evaluation/evaluate_agent.py"
Move-Item -Path "redteam.py" -Destination "src/security/redteam_scan.py"
Move-Item -Path "redteam1.py" -Destination "src/security/redteam_advanced.py"

Write-Host "✓ Python scripts moved"

# Move CI/CD files
Move-Item -Path "cicd/createagentpipeline.yml" -Destination ".azure-pipelines/create-agent-pipeline.yml"
Move-Item -Path "cicd/agentconsumptionpipeline.yml" -Destination ".azure-pipelines/test-agent-pipeline.yml"
Move-Item -Path "cicd/README.md" -Destination ".azure-pipelines/README.md"

Write-Host "✓ CI/CD files moved"

# Reorganize documentation
Move-Item -Path "docs/architecture.md" -Destination "docs/architecture/overview.md"
Move-Item -Path "docs/createagent.md" -Destination "docs/guides/agent-creation.md"
Move-Item -Path "docs/exagent.md" -Destination "docs/guides/agent-testing.md"
Move-Item -Path "docs/agenteval.md" -Destination "docs/guides/agent-evaluation.md"
Move-Item -Path "docs/redteam.md" -Destination "docs/guides/security-testing.md"
Move-Item -Path "docs/deployment.md" -Destination "docs/cicd/deployment-overview.md"

Write-Host "✓ Documentation reorganized"

# Clean up old cicd directory
Remove-Item -Path "cicd" -Recurse -Force

Write-Host "✓ Old directories cleaned"
```

### Step 3.4: Create __init__.py Files for Python Packages

```powershell
# Create __init__.py in all src subdirectories
$pythonPackages = @(
    "src/__init__.py",
    "src/agents/__init__.py",
    "src/evaluation/__init__.py",
    "src/security/__init__.py",
    "src/utils/__init__.py",
    "tests/__init__.py",
    "tests/unit/__init__.py",
    "tests/integration/__init__.py"
)

foreach ($file in $pythonPackages) {
    New-Item -ItemType File -Path $file -Force
    Add-Content -Path $file -Value "# Auto-generated package file"
}

Write-Host "✓ Python package files created"
```

### Step 3.5: Update Import Statements

Create a PowerShell script to update imports:

```powershell
# Save this as update-imports.ps1

$filesToUpdate = Get-ChildItem -Path "src" -Recurse -Filter "*.py"

foreach ($file in $filesToUpdate) {
    $content = Get-Content -Path $file.FullName -Raw
    
    # Update relative imports (example patterns - adjust as needed)
    $content = $content -replace 'from createagent import', 'from src.agents.create_agent import'
    $content = $content -replace 'from exagent import', 'from src.agents.test_agent import'
    $content = $content -replace 'from agenteval import', 'from src.evaluation.evaluate_agent import'
    $content = $content -replace 'from redteam import', 'from src.security.redteam_scan import'
    
    Set-Content -Path $file.FullName -Value $content
}

Write-Host "✓ Import statements updated"
```

### Step 3.6: Create Configuration Templates

```powershell
# Create .env.template
$envTemplate = @"
# Azure AI Project Configuration
AZURE_AI_PROJECT=https://your-project.api.azureml.ms
AZURE_AI_PROJECT_ENDPOINT=https://your-project.api.azureml.ms

# Azure Authentication
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret

# Azure OpenAI Configuration
AZURE_OPENAI_ENDPOINT=https://your-openai.openai.azure.com/
AZURE_OPENAI_KEY=your-api-key
AZURE_OPENAI_API_VERSION=2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT=gpt-4o

# Environment
ENVIRONMENT=dev
"@

Set-Content -Path "config/.env.template" -Value $envTemplate

Write-Host "✓ Configuration template created"
```

### Step 3.7: Update Pipeline References

Update `.azure-pipelines/create-agent-pipeline.yml`:

```powershell
$pipelineContent = Get-Content -Path ".azure-pipelines/create-agent-pipeline.yml" -Raw

# Update script paths
$pipelineContent = $pipelineContent -replace 'createagent.py', 'src/agents/create_agent.py'

Set-Content -Path ".azure-pipelines/create-agent-pipeline.yml" -Value $pipelineContent

Write-Host "✓ Pipeline references updated"
```

### Step 3.8: Stage All Changes

```powershell
# Stage all changes
git add -A

# Check what's staged
git status

# Commit changes
git commit -m "Reorganize repository structure

- Move Python scripts to src/ directory with module structure
- Reorganize CI/CD files to .azure-pipelines/
- Restructure documentation by category
- Add configuration templates
- Update import statements and pipeline references
- Create proper Python package structure with __init__.py files
"

Write-Host "✓ Changes committed locally"
```

---

## Phase 4: Push to Azure DevOps

### Step 4.1: Push to Azure DevOps

```powershell
# Configure git credentials (if using PAT)
git config credential.helper store

# Or use Azure DevOps credential manager
git config --global credential.https://dev.azure.com.useHttpPath true

# Push main branch
git checkout main
git push azure main

# Push reorganization branch
git checkout migration/reorganize-structure
git push azure migration/reorganize-structure

Write-Host "✓ Code pushed to Azure DevOps"
```

### Step 4.2: Create Pull Request (Optional)

If you want to review before merging:

```powershell
# Create PR via REST API
$prUri = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repoName/pullrequests?api-version=7.1"

$prBody = @{
    sourceRefName = "refs/heads/migration/reorganize-structure"
    targetRefName = "refs/heads/main"
    title = "Repository Reorganization for Improved Structure"
    description = "This PR reorganizes the repository structure for better maintainability, clearer module boundaries, and improved developer experience."
} | ConvertTo-Json

$prResponse = Invoke-RestMethod -Uri $prUri -Method Post -Headers $headers -Body $prBody

Write-Host "Pull Request created: $($prResponse.url)"
```

---

## Phase 5: Azure DevOps Configuration

### Step 5.1: Create Service Connections

#### Method 1: Azure DevOps Portal

1. Navigate to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Select **Service principal (manual)**
4. Fill in:
   - **Subscription ID**: `$env:AZURE_SUBSCRIPTION_ID`
   - **Subscription Name**: Your subscription name
   - **Service Principal ID**: `$env:AZURE_CLIENT_ID`
   - **Service Principal Key**: `$env:AZURE_CLIENT_SECRET`
   - **Tenant ID**: `$env:AZURE_TENANT_ID`
5. **Service connection name**: `azure-foundry-dev`
6. ✅ Grant access permission to all pipelines
7. Click **Verify and save**
8. Repeat for **test** and **prod** environments

#### Method 2: REST API

```powershell
# Create service connection via API
$scUri = "https://dev.azure.com/$organization/$project/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"

$environments = @("dev", "test", "prod")

foreach ($env in $environments) {
    $scBody = @{
        name = "azure-foundry-$env"
        type = "azurerm"
        url = "https://management.azure.com/"
        description = "Azure service connection for $env environment"
        authorization = @{
            parameters = @{
                serviceprincipalid = $env:AZURE_CLIENT_ID
                serviceprincipalkey = $env:AZURE_CLIENT_SECRET
                tenantid = $env:AZURE_TENANT_ID
            }
            scheme = "ServicePrincipal"
        }
        data = @{
            subscriptionId = $env:AZURE_SUBSCRIPTION_ID
            subscriptionName = "Your Subscription"
            environment = "AzureCloud"
            creationMode = "Manual"
        }
        isShared = $false
        isReady = $true
    } | ConvertTo-Json -Depth 10

    $scResponse = Invoke-RestMethod -Uri $scUri -Method Post -Headers $headers -Body $scBody -ContentType "application/json"
    
    Write-Host "✓ Service connection created: azure-foundry-$env"
}
```

### Step 5.2: Create Variable Groups

#### Method 1: Azure DevOps Portal

1. Navigate to **Pipelines** → **Library** → **+ Variable group**
2. Name: `{projectName}-dev-vars` (replace {projectName} with your config.naming.projectName value)
3. Add variables:
```yaml
AZURE_AI_PROJECT_DEV: https://your-dev-project.api.azureml.ms
AZURE_AI_PROJECT_ENDPOINT_DEV: https://your-dev-project.api.azureml.ms
AZURE_OPENAI_ENDPOINT_DEV: https://your-dev-openai.openai.azure.com/
AZURE_OPENAI_KEY_DEV: [Make secret]
AZURE_OPENAI_API_VERSION_DEV: 2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT_DEV: gpt-4o
AZURE_SERVICE_CONNECTION_DEV: azure-foundry-dev
```
4. Repeat for **test** and **prod**

#### Method 2: REST API

```powershell
# Create variable groups via API
$vgUri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"

$environments = @{
    "dev" = @{
        project = "https://dev-project.api.azureml.ms"
        openai = "https://dev-openai.openai.azure.com/"
        key = "dev-key"
    }
    "test" = @{
        project = "https://test-project.api.azureml.ms"
        openai = "https://test-openai.openai.azure.com/"
        key = "test-key"
    }
    "prod" = @{
        project = "https://prod-project.api.azureml.ms"
        openai = "https://prod-openai.openai.azure.com/"
        key = "prod-key"
    }
}

foreach ($env in $environments.Keys) {
    $envConfig = $environments[$env]
    
    $vgBody = @{
        name = "foundry-$env-vars"
        description = "Variables for $env environment"
        type = "Vsts"
        variables = @{
            "AZURE_AI_PROJECT_$($env.ToUpper())" = @{
                value = $envConfig.project
                isSecret = $false
            }
            "AZURE_AI_PROJECT_ENDPOINT_$($env.ToUpper())" = @{
                value = $envConfig.project
                isSecret = $false
            }
            "AZURE_OPENAI_ENDPOINT_$($env.ToUpper())" = @{
                value = $envConfig.openai
                isSecret = $false
            }
            "AZURE_OPENAI_KEY_$($env.ToUpper())" = @{
                value = $envConfig.key
                isSecret = $true
            }
            "AZURE_OPENAI_API_VERSION_$($env.ToUpper())" = @{
                value = "2024-02-15-preview"
                isSecret = $false
            }
            "AZURE_OPENAI_DEPLOYMENT_$($env.ToUpper())" = @{
                value = "gpt-4o"
                isSecret = $false
            }
            "AZURE_SERVICE_CONNECTION_$($env.ToUpper())" = @{
                value = "azure-foundry-$env"
                isSecret = $false
            }
        }
    } | ConvertTo-Json -Depth 10

    $vgResponse = Invoke-RestMethod -Uri $vgUri -Method Post -Headers $headers -Body $vgBody -ContentType "application/json"
    
    Write-Host "✓ Variable group created: foundry-$env-vars"
}
```

### Step 5.3: Create Environments

#### Method 1: Azure DevOps Portal

1. Navigate to **Pipelines** → **Environments**
2. Click **New environment**
3. Name: `dev`, Resource: None, Click **Create**
4. Repeat for `test` and `production`

For production, add approvals:
1. Click on `production` environment
2. Click **⋮** (more options) → **Approvals and checks**
3. Click **Approvals**
4. Add approvers
5. Set timeout: 7 days
6. Save

#### Method 2: REST API

```powershell
# Note: Environments API is limited; portal method is recommended
# This creates basic environments without approval gates

$envUri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"

$envNames = @("dev", "test", "production")

foreach ($envName in $envNames) {
    $envBody = @{
        name = $envName
        description = "$envName environment for foundry-cicd"
    } | ConvertTo-Json

    try {
        $envResponse = Invoke-RestMethod -Uri $envUri -Method Post -Headers $headers -Body $envBody -ContentType "application/json"
        Write-Host "✓ Environment created: $envName"
    } catch {
        Write-Host "⚠ Environment may already exist: $envName"
    }
}
```

### Step 5.4: Create Pipelines

#### Method 1: Azure DevOps Portal

1. Navigate to **Pipelines** → **Pipelines** → **New pipeline**
2. Select **Azure Repos Git**
3. Select your repository: `foundry-cicd`
4. Select **Existing Azure Pipelines YAML file**
5. Branch: `main` (or `migration/reorganize-structure`)
6. Path: `/.azure-pipelines/create-agent-pipeline.yml`
7. Click **Continue** → **Run** or **Save**
8. Rename pipeline to "Foundry Agent Creation"
9. Repeat for `test-agent-pipeline.yml` (name it "Foundry Agent Testing")

#### Method 2: REST API

```powershell
# Create pipeline via API
$pipelineUri = "https://dev.azure.com/$organization/$project/_apis/pipelines?api-version=7.1-preview.1"

$pipelines = @(
    @{
        name = "Foundry Agent Creation"
        path = ".azure-pipelines/create-agent-pipeline.yml"
    },
    @{
        name = "Foundry Agent Testing"
        path = ".azure-pipelines/test-agent-pipeline.yml"
    }
)

foreach ($pipeline in $pipelines) {
    $pipelineBody = @{
        name = $pipeline.name
        folder = "\"
        configuration = @{
            type = "yaml"
            path = $pipeline.path
            repository = @{
                id = $response.id  # From repository creation
                name = $repoName
                type = "azureReposGit"
            }
        }
    } | ConvertTo-Json -Depth 10

    $pipelineResponse = Invoke-RestMethod -Uri $pipelineUri -Method Post -Headers $headers -Body $pipelineBody -ContentType "application/json"
    
    Write-Host "✓ Pipeline created: $($pipeline.name)"
    Write-Host "  Pipeline ID: $($pipelineResponse.id)"
}
```

---

## Phase 6: Testing & Validation

### Step 6.1: Validate Repository Structure

```powershell
# Check repository structure
cd source-repo

# Verify directories exist
$requiredDirs = @(
    ".azure-pipelines",
    "src/agents",
    "src/evaluation",
    "src/security",
    "config",
    "docs",
    "scripts"
)

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host "✓ $dir exists"
    } else {
        Write-Host "✗ $dir missing" -ForegroundColor Red
    }
}
```

### Step 6.2: Validate Python Imports

```powershell
# Run Python syntax check
python -m py_compile src/agents/create_agent.py
python -m py_compile src/agents/test_agent.py
python -m py_compile src/evaluation/evaluate_agent.py
python -m py_compile src/security/redteam_scan.py

Write-Host "✓ Python syntax validation passed"
```

### Step 6.3: Run Pipeline (Dry Run)

```powershell
# Queue pipeline run via API
$runUri = "https://dev.azure.com/$organization/$project/_apis/pipelines/$($pipelineResponse.id)/runs?api-version=7.1-preview.1"

$runBody = @{
    resources = @{
        repositories = @{
            self = @{
                refName = "refs/heads/main"
            }
        }
    }
} | ConvertTo-Json -Depth 10

$runResponse = Invoke-RestMethod -Uri $runUri -Method Post -Headers $headers -Body $runBody -ContentType "application/json"

Write-Host "Pipeline run queued: $($runResponse.url)"
```

### Step 6.4: Validation Checklist

Run through this checklist:

```yaml
Repository:
  - [ ] Repository created in Azure DevOps
  - [ ] Code pushed successfully
  - [ ] Branch structure preserved
  - [ ] File structure reorganized correctly

Configuration:
  - [ ] Service connections created for dev/test/prod
  - [ ] Variable groups created with correct values
  - [ ] Environments created (dev/test/production)
  - [ ] Approval gates configured for production

Pipelines:
  - [ ] Agent creation pipeline created
  - [ ] Agent testing pipeline created
  - [ ] Pipelines can be triggered manually
  - [ ] Pipeline YAML syntax is valid

Access:
  - [ ] Team members have appropriate permissions
  - [ ] Service principal has Azure roles assigned
  - [ ] PAT token is stored securely

Documentation:
  - [ ] README updated with new structure
  - [ ] Migration notes documented
  - [ ] Team notified of changes
```

---

## Rollback Procedures

### If Migration Fails Before Push

```powershell
# Restore from backup
cd C:\Repos\northwind-systems\migration-workspace
Remove-Item -Path "source-repo" -Recurse -Force
Copy-Item -Path "source-repo-backup" -Destination "source-repo" -Recurse

Write-Host "Restored from backup"
```

### If Migration Fails After Push

```powershell
# Delete Azure DevOps repository (if needed)
$deleteUri = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$($response.id)?api-version=7.1"
Invoke-RestMethod -Uri $deleteUri -Method Delete -Headers $headers

Write-Host "Repository deleted from Azure DevOps"

# Start over from Phase 2
```

### If Configuration Fails

```powershell
# Delete service connections
# (Must be done via portal - API has limitations)

# Delete variable groups
$vgListUri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
$vgList = Invoke-RestMethod -Uri $vgListUri -Method Get -Headers $headers

foreach ($vg in $vgList.value | Where-Object { $_.name -like "foundry-*" }) {
    $deleteVgUri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/variablegroups/$($vg.id)?api-version=7.1-preview.2"
    Invoke-RestMethod -Uri $deleteVgUri -Method Delete -Headers $headers
    Write-Host "Deleted variable group: $($vg.name)"
}
```

---

## Troubleshooting

### Issue: Authentication Failed

**Symptoms**: 401 Unauthorized or 403 Forbidden errors

**Solutions**:
1. Verify PAT token is valid and not expired
2. Check PAT scopes include required permissions
3. Ensure Basic Auth header is properly encoded
4. Try regenerating PAT token

```powershell
# Test authentication
$testUri = "https://dev.azure.com/$organization/_apis/projects?api-version=7.1"
try {
    $test = Invoke-RestMethod -Uri $testUri -Method Get -Headers $headers
    Write-Host "✓ Authentication successful"
} catch {
    Write-Host "✗ Authentication failed: $_" -ForegroundColor Red
}
```

### Issue: Import Errors in Python

**Symptoms**: ModuleNotFoundError or ImportError

**Solutions**:
1. Verify all `__init__.py` files are created
2. Check import paths in Python files
3. Ensure PYTHONPATH includes src directory

```powershell
# Add src to Python path
$env:PYTHONPATH = "$(Get-Location)\src;$env:PYTHONPATH"

# Test imports
python -c "from src.agents.create_agent import main"
```

### Issue: Pipeline Fails to Trigger

**Symptoms**: Pipeline doesn't run on commit/push

**Solutions**:
1. Check trigger paths in YAML match changed files
2. Verify branch names in trigger configuration
3. Ensure repository is correctly linked to pipeline
4. Check pipeline is not disabled

```powershell
# Check pipeline status
$pipelineStatusUri = "https://dev.azure.com/$organization/$project/_apis/pipelines/$pipelineId?api-version=7.1"
$pipelineStatus = Invoke-RestMethod -Uri $pipelineStatusUri -Method Get -Headers $headers
Write-Host "Pipeline state: $($pipelineStatus.state)"
```

### Issue: Service Connection Not Working

**Symptoms**: Pipeline fails at Azure connection step

**Solutions**:
1. Verify service principal credentials are correct
2. Check Azure role assignments
3. Ensure subscription ID is correct
4. Test service principal manually

```bash
# Test service principal
az login --service-principal \
  -u $env:AZURE_CLIENT_ID \
  -p $env:AZURE_CLIENT_SECRET \
  --tenant $env:AZURE_TENANT_ID

az account show
```

### Issue: Variable Group Not Accessible

**Symptoms**: Pipeline can't read variables

**Solutions**:
1. Check variable group permissions
2. Ensure "Grant access permission to all pipelines" is checked
3. Link variable group explicitly in pipeline YAML
4. Verify variable group name matches YAML reference

### Issue: Git Push Fails

**Symptoms**: Authentication failure or large file errors

**Solutions**:

```powershell
# For authentication issues
git config --global credential.helper manager-core

# For large files
git lfs install
git lfs track "*.bin"
git lfs track "*.model"

# For push failures
git push azure main --force-with-lease  # Use with caution
```

---

## Post-Migration Tasks

### 1. Update Team Documentation

- [ ] Update team wiki with new repository location
- [ ] Document new directory structure
- [ ] Update onboarding guides
- [ ] Create migration announcement

### 2. Configure Branch Policies

1. Navigate to **Project Settings** → **Repositories** → **foundry-cicd** → **Policies**
2. Configure **main** branch:
   - ✅ Require a minimum number of reviewers: 2
   - ✅ Check for linked work items
   - ✅ Check for comment resolution
   - ✅ Limit merge types: Squash merge only

### 3. Set Up CI/CD Notifications

1. Navigate to **Project Settings** → **Notifications**
2. Create subscription:
   - Event: Build completed
   - Filter: foundry-cicd repository
   - Recipients: Team email/Teams channel

### 4. Archive Old Repository

If migrating from GitHub:
```bash
# Archive the original repo
# Via GitHub UI: Settings → Archive this repository
```

### 5. Update External References

- [ ] Update documentation links
- [ ] Update CI/CD badges in README
- [ ] Update integration URLs
- [ ] Notify dependent systems

---

## Success Criteria

Your migration is successful when:

✅ **Repository**
- New repository exists in Azure DevOps
- All files are present and organized
- Git history is preserved (if desired)
- Branches are migrated

✅ **Code**
- Python scripts are in modular structure
- Import statements work correctly
- Configuration is centralized
- Documentation is organized

✅ **CI/CD**
- Pipelines are created and configured
- Service connections work
- Variable groups are accessible
- Environments have proper approval gates

✅ **Testing**
- Manual pipeline run succeeds
- Code validation passes
- Team can access and contribute
- Documentation is up to date

---

## Next Steps

After successful migration:

1. **Merge reorganization branch** (if using PR workflow)
2. **Run comprehensive tests** in all environments
3. **Train team** on new structure
4. **Monitor pipelines** for first few runs
5. **Gather feedback** and iterate

---

## Additional Resources

### Azure DevOps Documentation
- [REST API Reference](https://learn.microsoft.com/en-us/rest/api/azure/devops/)
- [Git Repositories API](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/repositories)
- [Pipelines API](https://learn.microsoft.com/en-us/rest/api/azure/devops/pipelines)
- [Service Endpoints API](https://learn.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpoints)

### Azure CLI
- [Azure CLI Reference](https://learn.microsoft.com/en-us/cli/azure/)
- [Azure DevOps Extension](https://learn.microsoft.com/en-us/azure/devops/cli/)

### Git
- [Git Documentation](https://git-scm.com/doc)
- [Git Large File Storage](https://git-lfs.github.com/)

---

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Azure DevOps service health
3. Consult Azure DevOps documentation
4. Contact your Azure administrator
5. Reach out to DevOps team

---

**Document Version**: 1.0  
**Last Updated**: January 7, 2026  
**Maintained by**: DevOps Migration Team
