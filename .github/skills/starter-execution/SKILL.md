---
name: starter-execution
description: Deploys the Azure AI Foundry starter application to Azure DevOps. This skill provides step-by-step instructions for deploying the ready-to-use template application, creating Azure DevOps resources (1 repo, 3 environments, service connections, variable groups), and setting up CI/CD pipelines. Use this to quickly start a new Azure AI Foundry project.
---

# Starter Execution for Azure AI Foundry

This skill provides **step-by-step instructions** for deploying the Azure AI Foundry starter template to Azure DevOps with proper environment configuration.

## When to use this skill

Use this skill when you need to:
- Deploy the Azure AI Foundry starter application to Azure DevOps
- Set up a new AI agent project from the template
- Configure Azure DevOps repository, service connections, and variable groups
- Set up environment-specific CI/CD pipelines (DEV/TEST/PROD)
- Deploy your first AI agent to Azure AI Foundry

## Prerequisites

Before using this skill, ensure:
- ✅ Configuration set up (use `configuration-management` skill FIRST)
- ✅ Environment validation passed (use `environment-validation` skill)
- ✅ All Azure resources created (use `resource-creation` skill with Service Principal)
- ✅ Bearer token is valid (30+ minutes remaining)
- ✅ Azure DevOps permissions configured

## Deployment Overview

This deployment uses the ready-to-use template application in `template-app/` to quickly set up an Azure AI Foundry project.

### What You'll Create
- **1 Azure DevOps Repository** (with ready-to-deploy application code)
- **3 Service Connections** (one per environment: dev, test, prod with federated credentials)
- **3 Variable Groups** (one per environment with environment-specific configuration)
- **3 Environments** (dev, test, production)
- **2+ Pipelines** (agent creation and testing pipelines)

### Deployment Phases

1. **Phase 1: Preparation** - Authenticate, validate, configure
2. **Phase 2: Repository Setup** - Create Azure DevOps repo and push template code
3. **Phase 3: Azure DevOps Setup** - Create service connections with workload identity federation
4. **Phase 4: Environment Configuration** - Create variable groups and environments
5. **Phase 5: Pipeline Setup** - Create pipelines from template YAML files
6. **Phase 6: Validation** - Deploy first agent and verify

## Step-by-step execution

**💡 Important**: This skill provides step-by-step instructions. Execute each command individually and verify success before proceeding.

### Step 1: Load Configuration

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Extract values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$targetRepo = "azure-ai-foundry-app"  # Your repository name
```

### Step 2: Authenticate

```powershell
# Login to Azure
az login

# Set subscription
az account set --subscription $config.azure.subscriptionId

# Get bearer token
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

# Configure Azure DevOps CLI
az devops configure --defaults organization=$org project=$project
```

### Step 3: Prepare Template Application

```powershell
# Navigate to template-app directory
$templatePath = "$PSScriptRoot/../../../template-app"
Set-Location $templatePath

# Initialize git if not already initialized
if (-not (Test-Path ".git")) {
    git init
    git add -A
    git commit -m "Initial commit - Azure AI Foundry starter template"
}

# Create .env file from sample.env
Copy-Item "sample.env" ".env"
Write-Host "⚠️  IMPORTANT: Edit .env file with your Azure resource details"
```

### Step 4: Create Azure DevOps Repository

```powershell
# Create repository for your application
$repoName = $targetRepo

$existingRepo = az repos list --query "[?name=='$repoName'].id" --output tsv

if (-not $existingRepo) {
    $repo = az repos create --name $repoName --output json | ConvertFrom-Json
    Write-Host "✓ Repository created: $repoName"
} else {
    Write-Host "✓ Repository already exists: $repoName"
}

# Get repository details
$repoDetails = az repos show --repository $repoName --output json | ConvertFrom-Json
$remoteUrl = $repoDetails.remoteUrl
```

### Step 5: Push Template Code to Azure DevOps

```powershell
# Add Azure DevOps remote
git remote add azure $remoteUrl

# Configure git authentication
git config --local http.extraheader "AUTHORIZATION: bearer $env:ADO_TOKEN"

# Push code
git push azure main

# Remove auth header (security)
git config --local --unset http.extraheader

Write-Host "✓ Template code pushed to Azure DevOps"
```

### Step 6: Create Service Connections with Workload Identity Federation

**IMPORTANT:** Use REST API for federated credentials - Azure CLI does NOT support this!

```powershell
# Service connection configuration
$environments = @("dev", "test", "prod")
$spAppId = $config.servicePrincipal.appId
$subscriptionId = $config.azure.subscriptionId
$subscriptionName = $config.azure.subscriptionName
$tenantId = $config.azure.tenantId

# Get project ID
$projectId = (az devops project show --project $project --output json | ConvertFrom-Json).id

foreach ($env in $environments) {
    $scName = "azure-foundry-$env"
    
    # Check if exists
    $existingSc = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv
    
    if (-not $existingSc) {
        # Create via REST API with federated credentials
        $uri = "$org/$project/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
        
        $body = @{
            authorization = @{
                parameters = @{
                    serviceprincipalid = $spAppId
                    tenantid = $tenantId
                }
                scheme = "WorkloadIdentityFederation"
            }
            data = @{
                subscriptionId = $subscriptionId
                subscriptionName = $subscriptionName
            }
            name = $scName
            type = "azurerm"
            url = "https://management.azure.com/"
            serviceEndpointProjectReferences = @(
                @{
                    projectReference = @{
                        id = $projectId
                        name = $project
                    }
                    name = $scName
                }
            )
        } | ConvertTo-Json -Depth 10
        
        Invoke-RestMethod -Uri $uri -Method Post -Headers @{
            "Authorization" = "Bearer $env:ADO_TOKEN"
            "Content-Type" = "application/json"
        } -Body $body
        
        Write-Host "✓ Service connection created: $scName"
        
        # CRITICAL: Authorize the service connection for all pipelines
        Start-Sleep -Seconds 2
        $scId = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv
        az devops service-endpoint update --id $scId --enable-for-all true
        
    } else {
        Write-Host "✓ Service connection exists: $scName"
    }
}
```

### Step 7: Create Variable Groups (One Per Environment)

**IMPORTANT:** Variable group names must match exactly what's referenced in pipeline YAML files!

```powershell
# Create variable groups with environment-specific values from your .env and config
$environments = @{
    "dev" = @{
        projectEndpoint = $config.azure.aiFoundry.dev.projectEndpoint
        modelDeployment = "gpt-4o"
        resourceGroup = $config.azure.resourceGroup
    }
    "test" = @{
        projectEndpoint = $config.azure.aiFoundry.test.projectEndpoint
        modelDeployment = "gpt-4o"
        resourceGroup = $config.azure.resourceGroup
    }
    "prod" = @{
        projectEndpoint = $config.azure.aiFoundry.prod.projectEndpoint
        modelDeployment = "gpt-4o"
        resourceGroup = $config.azure.resourceGroup
    }
}

foreach ($env in $environments.Keys) {
    $vgName = "foundry-$env-vars"
    $envConfig = $environments[$env]
    
    $existingVg = az pipelines variable-group list --query "[?name=='$vgName'].id" --output tsv
    
    if (-not $existingVg) {
        # Create variable group
        $vgId = az pipelines variable-group create `
            --name $vgName `
            --variables `
                AZURE_AI_PROJECT_ENDPOINT="$($envConfig.projectEndpoint)" `
                AZURE_AI_MODEL_DEPLOYMENT_NAME="$($envConfig.modelDeployment)" `
                AZURE_RESOURCE_GROUP="$($envConfig.resourceGroup)" `
                AZURE_SUBSCRIPTION_ID="$subscriptionId" `
            --authorize true `
            --output json | ConvertFrom-Json | Select-Object -ExpandProperty id
        
        Write-Host "✓ Variable group created: $vgName (ID: $vgId)"
    } else {
        Write-Host "✓ Variable group exists: $vgName"
    }
}
```

### Step 8: Create Environments

```powershell
# Create dev, test, production environments using REST API
$envNames = @("dev", "test", "production")
$uri = "$org/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"

foreach ($envName in $envNames) {
    $existingEnvs = Invoke-RestMethod -Uri $uri -Headers @{
        "Authorization" = "Bearer $env:ADO_TOKEN"
    }
    
    $exists = $existingEnvs.value | Where-Object { $_.name -eq $envName }
    
    if (-not $exists) {
        $body = @{
            name = $envName
            description = "$envName environment for foundry-cicd"
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri $uri -Method Post -Headers @{
            "Authorization" = "Bearer $env:ADO_TOKEN"
            "Content-Type" = "application/json"
        } -Body $body
        
        Write-Host "✓ Environment created: $envName"
    } else {
        Write-Host "✓ Environment exists: $envName"
    }
}
```

### Step 9: Create Pipelines from Template

```powershell
# Create pipelines from the template YAML files
$pipelines = @(
    @{ name = "Azure AI Foundry - Create Agent"; path = ".azure-pipelines/createagentpipeline.yml" }
)

foreach ($pipeline in $pipelines) {
    $existingPipeline = az pipelines list --query "[?name=='$($pipeline.name)'].id" --output tsv
    
    if (-not $existingPipeline) {
        az pipelines create `
            --name "$($pipeline.name)" `
            --repository $repoName `
            --repository-type tfsgit `
            --branch main `
            --yml-path "$($pipeline.path)" `
            --skip-first-run
        
        Write-Host "✓ Pipeline created: $($pipeline.name)"
    } else {
        Write-Host "✓ Pipeline exists: $($pipeline.name)"
    }
}
```

### Step 10: Add Federated Credentials to Service Principal

**CRITICAL:** This step is required for workload identity federation to work!

```powershell
# Add federated credentials for each environment
$spObjectId = (az ad sp show --id $spAppId --query id -o tsv)

foreach ($env in $environments) {
    $credName = "azure-devops-$project-$env"
    
    # Check if credential already exists
    $existingCred = az ad app federated-credential list --id $spAppId --query "[?name=='$credName'].name" -o tsv
    
    if (-not $existingCred) {
        # Get service connection ID
        $scName = "azure-foundry-$env"
        $scId = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv
        
        $issuer = "$org/$project/_apis/serviceconnections/$scId"
        $subject = "sc://$org/$project/$scName"
        
        az ad app federated-credential create `
            --id $spAppId `
            --parameters "{
                \`"name\`": \`"$credName\`",
                \`"issuer\`": \`"$issuer\`",
                \`"subject\`": \`"$subject\`",
                \`"audiences\`": [\`"api://AzureADTokenExchange\`"]
            }"
        
        Write-Host "✓ Federated credential added: $credName"
    } else {
        Write-Host "✓ Federated credential exists: $credName"
    }
}

Write-Host "`n⚠️  IMPORTANT: Ensure Service Principal has these RBAC roles:"
Write-Host "  - Contributor (on resource group)"
Write-Host "  - Cognitive Services User (on AI Foundry project)"
```

### Step 11: Validate Deployment

```powershell
Write-Host "`n=== Deployment Validation ===" -ForegroundColor Cyan

# Validate repository
$repos = az repos list --output json | ConvertFrom-Json
Write-Host "✓ Repositories: $($repos.Count)"

# Validate service connections
$connections = az devops service-endpoint list --output json | ConvertFrom-Json
Write-Host "✓ Service connections: $($connections.Count)"

# Validate variable groups
$varGroups = az pipelines variable-group list --output json | ConvertFrom-Json
Write-Host "✓ Variable groups: $($varGroups.Count)"

# Validate environments
$envs = az pipelines environment list --output json | ConvertFrom-Json
Write-Host "✓ Environments: $($envs.Count)"

# Validate pipelines
$pipelines = az pipelines list --output json | ConvertFrom-Json
Write-Host "✓ Pipelines: $($pipelines.Count)"

Write-Host "`n✅ Deployment complete! Next: Run your first pipeline to deploy an agent."
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Federated Credential Issuer/Subject Mismatch
**Error:** `AADSTS70021: No matching federated identity record found`
**Solution:**
```powershell
# Verify issuer and subject match exactly
$scId = az devops service-endpoint list --query "[?name=='azure-foundry-dev'].id" --output tsv
$issuer = "$org/$project/_apis/serviceconnections/$scId"
$subject = "sc://$org/$project/azure-foundry-dev"

# Recreate credential with exact values
az ad app federated-credential delete --id $spAppId --federated-credential-id $credId
az ad app federated-credential create --id $spAppId --parameters "{ ... }"
```

#### 2. Service Connection Not Authorized
**Error:** `The pipeline is not valid. Job <job>: Step <step> references service connection <name> which could not be found.`
**Solution:**
```powershell
# Authorize service connection for all pipelines
$scId = az devops service-endpoint list --query "[?name=='azure-foundry-dev'].id" --output tsv
az devops service-endpoint update --id $scId --enable-for-all true
```

#### 3. Missing RBAC Permissions
**Error:** Agent creates but pipeline shows errors accessing Azure AI
**Solution:**
```powershell
# Add required roles
az role assignment create --assignee $spAppId --role "Contributor" --scope /subscriptions/$subscriptionId/resourceGroups/$resourceGroup
az role assignment create --assignee $spAppId --role "Cognitive Services User" --scope /subscriptions/$subscriptionId/resourceGroups/$resourceGroup
```

#### 4. Variable Group Field Restrictions
**Error:** `Variable group name contains invalid characters`
**Solution:** Use alphanumeric characters and hyphens only. Do NOT use underscores or spaces.

#### 5. Pipeline YAML Path Not Found
**Error:** `Could not find file at path`
**Solution:**
```powershell
# Verify path in repository
az repos show-branch --repository $repoName --name main

# Ensure path starts with . (e.g., .azure-pipelines/pipeline.yml)
```

#### 6. Token Expired
**Symptom:** Commands fail with 401 Unauthorized
**Solution:**
```powershell
# Refresh bearer token (expires after 1 hour)
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```

#### 7. Agent Not Visible in Portal
**Symptom:** REST API shows no agents, but deployment succeeded
**Solution:** Agent-framework SDK creates persistent agents - check Azure AI Foundry portal directly. Portal is authoritative source.

### See Also
- [docs/troubleshooting.md](../../../docs/troubleshooting.md) - Complete troubleshooting guide with all 12 lessons learned

## Best practices

1. **Use the template configuration** - Starter template includes all validated settings
2. **Follow the federated credential pattern** - Zero secrets, more secure
3. **One environment at a time** - Create and test dev, then test, then prod
4. **Verify RBAC before first run** - Contributor + Cognitive Services User roles required
5. **Check variable group names** - Must match exactly what's in pipeline YAML
6. **Document customizations** - Track any changes you make to the template
7. **Use the feedback mechanism** - Report issues via template-app/FEEDBACK.md

## Integration with other skills

This skill works together with:
- **configuration-management** (required first) - Set up centralized configuration
- **environment-validation** - Validate prerequisites before deployment
- **resource-creation** - Create Azure resources including Service Principal

## Related resources

- [docs/starter-guide.md](../../../docs/starter-guide.md) - Complete deployment guide
- [docs/quick-start.md](../../../docs/quick-start.md) - Fast track guide
- [docs/execution-guide.md](../../../docs/execution-guide.md) - GitHub Copilot usage
- [docs/troubleshooting.md](../../../docs/troubleshooting.md) - All 12 critical lessons
- [docs/az-devops-cli-reference.md](../../../docs/az-devops-cli-reference.md) - Azure DevOps CLI reference
- [template-app/FEEDBACK.md](../../../template-app/FEEDBACK.md) - Submit feedback
