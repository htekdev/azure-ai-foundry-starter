---
name: environment-setup
description: Creates Azure DevOps variable groups and environments for dev, test, and production. This skill configures environment-specific variables and approval gates required for CI/CD pipelines.
---

# Environment Setup for Azure AI Foundry

This skill handles **creating variable groups** and **environments** in Azure DevOps for development, test, and production stages.

## When to use this skill

Use this skill when you need to:
- Create variable groups with environment-specific configuration
- Set up Azure DevOps environments for deployment stages
- Configure environment variables for AI Foundry projects
- Prepare environments for CI/CD pipeline execution

## Prerequisites

Before using this skill, ensure:
- ✅ Configuration loaded (use `configuration-management` skill first)
- ✅ Azure resources created (use `resource-creation` skill)
- ✅ Service connections created (use `service-connection-setup` skill)
- ✅ Azure DevOps authentication configured (bearer token set)

## What This Skill Creates

- **3 Variable Groups** (one per environment: dev, test, prod)
- **3 Environments** (dev, test, production for deployment approvals)
- **Environment-specific configuration** from starter-config.json

## Understanding Variable Groups vs Environments

**Variable Groups:**
- Store configuration values (endpoints, resource names, etc.)
- Can be shared across multiple pipelines
- Authorized for pipeline access automatically
- Name format: `foundry-{env}-vars`

**Environments:**
- Represent deployment targets (dev, test, production)
- Can have approval gates and checks
- Track deployment history
- Used in pipeline stages for deployments

## Step-by-step execution

### Step 1: Load Configuration

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Extract values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$subscriptionId = $config.azure.subscriptionId
# Derive resource group name from project name
$resourceGroup = "rg-$($config.naming.projectName)"

Write-Host "✓ Configuration loaded"
```

### Step 2: Create Variable Groups

**IMPORTANT:** Variable group names must match exactly what's referenced in pipeline YAML files!

```powershell
# Define environment-specific configurations with derived resource groups
$environments = @{
    "dev" = @{
        projectEndpoint = $config.azure.aiFoundry.dev.projectEndpoint
        projectName = $config.azure.aiFoundry.dev.projectName
        modelDeployment = "gpt-4o"  # or from config if specified
        resourceGroup = "$resourceGroup-dev"  # rg-{projectName}-dev
    }
    "test" = @{
        projectEndpoint = $config.azure.aiFoundry.test.projectEndpoint
        projectName = $config.azure.aiFoundry.test.projectName
        modelDeployment = "gpt-4o"
        resourceGroup = "$resourceGroup-test"  # rg-{projectName}-test
    }
    "prod" = @{
        projectEndpoint = $config.azure.aiFoundry.prod.projectEndpoint
        projectName = $config.azure.aiFoundry.prod.projectName
        modelDeployment = "gpt-4o"
        resourceGroup = "$resourceGroup-prod"  # rg-{projectName}-prod
    }
}

Write-Host "`nCreating variable groups..."

foreach ($env in $environments.Keys) {
    $vgName = "foundry-$env-vars"
    $envConfig = $environments[$env]
    
    # Check if variable group already exists
    $existingVg = az pipelines variable-group list --query "[?name=='$vgName'].id" --output tsv
    
    if (-not $existingVg) {
        Write-Host "Creating variable group: $vgName"
        
        # Create variable group with environment-specific values
        $vgId = az pipelines variable-group create `
            --name $vgName `
            --variables `
                AZURE_AI_PROJECT_ENDPOINT="$($envConfig.projectEndpoint)" `
                AZURE_AI_PROJECT_NAME="$($envConfig.projectName)" `
                AZURE_AI_MODEL_DEPLOYMENT_NAME="$($envConfig.modelDeployment)" `
                AZURE_RESOURCE_GROUP="$($envConfig.resourceGroup)" `
                AZURE_SUBSCRIPTION_ID="$subscriptionId" `
            --authorize true `
            --output json | ConvertFrom-Json | Select-Object -ExpandProperty id
        
        Write-Host "✓ Variable group created: $vgName (ID: $vgId)"
        
        # Display created variables
        Write-Host "  Variables:"
        Write-Host "    - AZURE_AI_PROJECT_ENDPOINT: $($envConfig.projectEndpoint)"
        Write-Host "    - AZURE_AI_PROJECT_NAME: $($envConfig.projectName)"
        Write-Host "    - AZURE_AI_MODEL_DEPLOYMENT_NAME: $($envConfig.modelDeployment)"
        Write-Host "    - AZURE_RESOURCE_GROUP: $($envConfig.resourceGroup)"
        Write-Host "    - AZURE_SUBSCRIPTION_ID: $subscriptionId"
    } else {
        Write-Host "✓ Variable group already exists: $vgName (ID: $existingVg)"
    }
}
```

### Step 3: Create Environments

**Note:** Environments enable deployment tracking, approvals, and checks in pipelines.

```powershell
Write-Host "`nCreating environments..."

# Create dev, test, production environments using REST API
$envNames = @("dev", "test", "production")
$uri = "$org/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"

foreach ($envName in $envNames) {
    # Check if environment exists
    $existingEnvs = Invoke-RestMethod -Uri $uri -Headers @{
        "Authorization" = "Bearer $env:ADO_TOKEN"
    }
    
    $exists = $existingEnvs.value | Where-Object { $_.name -eq $envName }
    
    if (-not $exists) {
        Write-Host "Creating environment: $envName"
        
        $body = @{
            name = $envName
            description = "$envName environment for Azure AI Foundry deployments"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers @{
            "Authorization" = "Bearer $env:ADO_TOKEN"
            "Content-Type" = "application/json"
        } -Body $body
        
        Write-Host "✓ Environment created: $envName (ID: $($response.id))"
    } else {
        Write-Host "✓ Environment already exists: $envName (ID: $($exists.id))"
    }
}

Write-Host "`n✅ Environment setup complete!"
```

### Step 4: (Optional) Configure Approval Gates

For production environments, you may want to add approval gates:

```powershell
Write-Host "`n=== Optional: Configure Approval Gates ==="
Write-Host "To add approvals for production deployments:"
Write-Host "1. Go to: $org/$project/_settings/environments"
Write-Host "2. Select 'production' environment"
Write-Host "3. Click '+ Add resource' > 'Approvals and checks'"
Write-Host "4. Add approvers (users or groups)"
Write-Host "5. Configure approval timeout and policy"
```

## Variable Group Naming Convention

**Critical:** Pipeline YAML files reference these exact names!

- `{projectName}-dev-vars` - Development environment (where {projectName} is from config.naming.projectName)
- `{projectName}-test-vars` - Test environment
- `{projectName}-prod-vars` - Production environment

**Naming rules:**
- ✅ Use hyphens: `{projectName}-dev-vars` (from config.naming.projectName)
- ❌ No underscores: `foundry_dev_vars`
- ❌ No spaces: `foundry dev vars`
- ❌ No special characters

## Environment Variables Reference

Each variable group contains:

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_AI_PROJECT_ENDPOINT` | AI Foundry project endpoint URL | `https://aif-foundry-dev.cognitiveservices.azure.com` |
| `AZURE_AI_PROJECT_NAME` | AI Foundry project name | `aif-foundry-dev` |
| `AZURE_AI_MODEL_DEPLOYMENT_NAME` | Deployed model name | `gpt-4o` |
| `AZURE_RESOURCE_GROUP` | Azure resource group (environment-specific) | `rg-{projectName}-dev` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `12345678-1234-1234-1234-123456789012` |

## Troubleshooting

### Common Issues and Solutions

#### 1. Variable Group Name Contains Invalid Characters
**Error:** `Variable group name contains invalid characters`

**Solution:** Use alphanumeric characters and hyphens only:
```powershell
# ✅ CORRECT
$vgName = "foundry-dev-vars"

# ❌ WRONG
$vgName = "foundry_dev_vars"  # No underscores
$vgName = "foundry dev vars"  # No spaces
```

#### 2. Variable Group Not Authorized for Pipeline
**Error:** `The pipeline is not valid. Could not find variable group`

**Solution:** Ensure `--authorize true` flag is used when creating:
```powershell
az pipelines variable-group create --name $vgName --authorize true ...
```

Or authorize manually:
```powershell
$vgId = az pipelines variable-group list --query "[?name=='$vgName'].id" -o tsv
az pipelines variable-group update --id $vgId --authorize true
```

#### 3. Environment Already Exists Error
**Error:** `TF400734: The environment xyz already exists`

**Solution:** The script handles this automatically. If you need to recreate, delete manually:
1. Go to Project Settings > Environments
2. Select environment > More options > Delete

#### 4. REST API Call Fails for Environments
**Error:** 401 Unauthorized when creating environment

**Solution:** Refresh your bearer token:
```powershell
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```

#### 5. Missing Configuration Values
**Error:** Empty values in variable group

**Solution:** Verify configuration is loaded correctly:
```powershell
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig
$config.azure.aiFoundry.dev.projectEndpoint  # Should not be empty
```

## Best practices

1. **Use descriptive variable names** - Match Azure resource naming conventions
2. **Authorize variable groups immediately** - Use `--authorize true` flag
3. **Keep variable group names consistent** - Follow the pattern: `foundry-{env}-vars`
4. **Document custom variables** - Add comments in your pipeline YAML
5. **Use environments for approvals** - Enable approval gates for production
6. **Separate secrets** - Use Azure Key Vault for sensitive values (not variable groups)
7. **Version control** - Document variable changes in your repo

## Integration with other skills

This skill works together with:
- **configuration-management** (required first) - Loads centralized configuration
- **resource-creation** (required) - Creates the Azure resources referenced in variables
- **service-connection-setup** (before this) - Creates service connections
- **pipeline-setup** (next step) - Creates pipelines that use these variable groups and environments

## Related resources

- [docs/troubleshooting.md](../../../docs/troubleshooting.md) - Lesson #4: Variable group restrictions
- [docs/starter-guide.md](../../../docs/starter-guide.md) - Complete deployment guide
- [Azure DevOps: Variable groups](https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups)
- [Azure DevOps: Environments](https://learn.microsoft.com/azure/devops/pipelines/process/environments)
