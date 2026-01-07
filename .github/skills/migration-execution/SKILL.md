---
name: migration-execution
description: Executes the Azure DevOps repository migration process from GitHub to Azure DevOps. This skill provides manual step-by-step instructions for reorganizing a single repository, creating Azure DevOps resources (1 repo, 3 environments, service connections, variable groups), and setting up CI/CD pipelines. Use this when you need hands-on control over the migration process.
---

# Migration Execution for Azure DevOps

This skill provides **manual step-by-step instructions** for migrating a repository from GitHub to Azure DevOps with proper environment configuration.

## When to use this skill

Use this skill when you need to:
- Execute the repository migration process from GitHub to Azure DevOps
- Reorganize a single monolithic repository structure
- Configure Azure DevOps repository, service connections, and variable groups
- Set up environment-specific CI/CD pipelines
- Validate migration success

## Prerequisites

Before using this skill, ensure:
- ✅ Configuration set up (use `configuration-management` skill FIRST)
- ✅ Environment validation passed (use `environment-validation` skill)
- ✅ All Azure resources created (use `resource-creation` skill with Service Principal)
- ✅ Bearer token is valid (30+ minutes remaining)
- ✅ Azure DevOps permissions configured

## Migration Overview

This migration transforms a single GitHub repository into an Azure DevOps repository with proper CI/CD configuration.

### What You'll Create
- **1 Azure DevOps Repository** (single repo, not multiple repos)
- **3 Service Connections** (one per environment: dev, test, prod)
- **3 Variable Groups** (one per environment with environment-specific configuration)
- **3 Environments** (dev, test, production)
- **2+ Pipelines** (depends on your YAML files)

### Migration Phases

1. **Phase 1: Preparation** - Authenticate, validate, backup
2. **Phase 2: Repository Reorganization** - Clean up structure locally
3. **Phase 3: Azure DevOps Setup** - Create single repo and push code
4. **Phase 4: Environment Configuration** - Create service connections and variable groups per environment
5. **Phase 5: Pipeline Setup** - Create pipelines from YAML files
6. **Phase 6: Validation** - Test everything works

## Step-by-step execution

**💡 Important**: This skill provides MANUAL step-by-step instructions. Execute each command individually and verify success before proceeding.

### Step 1: Load Configuration

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-MigrationConfig

# Extract values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$sourceRepo = $config.azureDevOps.sourceRepository
$targetRepo = "foundry-cicd"  # Single repository name
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

### Step 3: Clone and Reorganize Repository

```powershell
# Clone source repository from GitHub
$workspacePath = "C:\Repos\migration-workspace"
New-Item -ItemType Directory -Path $workspacePath -Force | Out-Null
Set-Location $workspacePath

git clone "https://github.com/user/source-repo.git" source-repo
cd source-repo

# Create backup
cd ..
$backupName = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -Path "source-repo" -Destination $backupName -Recurse
Compress-Archive -Path $backupName -DestinationPath "$backupName.zip"

cd source-repo

# Create new directory structure
$directories = @(
    ".azure-pipelines",
    ".azure-pipelines/templates",
    "src/agents",
    "src/evaluation",
    "src/security",
    "config",
    "docs"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Move files (customize based on your repo structure)
# Example:
Move-Item "createagent.py" "src/agents/create_agent.py" -Force
Move-Item "exagent.py" "src/agents/test_agent.py" -Force
Move-Item "cicd/*.yml" ".azure-pipelines/" -Force

# Create __init__.py files for Python packages
"# Package file" | Set-Content "src/__init__.py"
"# Package file" | Set-Content "src/agents/__init__.py"

# Update file references in pipelines
Get-ChildItem ".azure-pipelines" -Filter "*.yml" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace 'createagent\.py', 'src/agents/create_agent.py'
    Set-Content $_.FullName $content
}

# Commit reorganization
git checkout -b migration/reorganize
git add -A
git commit -m "Reorganize repository structure for Azure DevOps"
```

### Step 4: Create Azure DevOps Repository (Single Repo)

```powershell
# Create ONE repository
$repoName = "foundry-cicd"

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

### Step 5: Push Code to Azure DevOps

```powershell
# Add Azure DevOps remote
git remote add azure $remoteUrl

# Configure git authentication
git config --local http.extraheader "AUTHORIZATION: bearer $env:ADO_TOKEN"

# Push code
git checkout main
git push azure main

git checkout migration/reorganize
git push azure migration/reorganize

# Remove auth header (security)
git config --local --unset http.extraheader

Write-Host "✓ Code pushed to Azure DevOps"
```

### Step 6: Create Service Connections (One Per Environment)

```powershell
# Create service connections for dev, test, prod
$environments = @("dev", "test", "prod")
$spAppId = $config.servicePrincipal.appId
$subscriptionId = $config.azure.subscriptionId
$subscriptionName = $config.azure.subscriptionName
$tenantId = $config.azure.tenantId

foreach ($env in $environments) {
    $scName = "azure-foundry-$env"
    
    $existingSc = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv
    
    if (-not $existingSc) {
        az devops service-endpoint azurerm create `
            --name $scName `
            --azure-rm-service-principal-id $spAppId `
            --azure-rm-subscription-id $subscriptionId `
            --azure-rm-subscription-name $subscriptionName `
            --azure-rm-tenant-id $tenantId
        
        # Enable for all pipelines
        $scId = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv
        az devops service-endpoint update --id $scId --enable-for-all true
        
        Write-Host "✓ Service connection created: $scName"
    } else {
        Write-Host "✓ Service connection exists: $scName"
    }
}
```

### Step 7: Create Variable Groups (One Per Environment)

```powershell
# Create variable groups with environment-specific values
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
    
    $existingVg = az pipelines variable-group list --query "[?name=='$vgName'].id" --output tsv
    
    if (-not $existingVg) {
        az pipelines variable-group create `
            --name $vgName `
            --variables `
                AZURE_AI_PROJECT="$($config.project)" `
                AZURE_OPENAI_ENDPOINT="$($config.openai)" `
                AZURE_OPENAI_API_VERSION="2024-02-15-preview" `
                AZURE_OPENAI_DEPLOYMENT="gpt-4o" `
                AZURE_SERVICE_CONNECTION="azure-foundry-$env" `
            --authorize true
        
        Write-Host "✓ Variable group created: $vgName"
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

### Step 9: Create Pipelines

```powershell
# Create pipelines from YAML files in the repository
$pipelines = @(
    @{ name = "Foundry Agent Creation"; path = ".azure-pipelines/create-agent-pipeline.yml" }
    @{ name = "Foundry Agent Testing"; path = ".azure-pipelines/test-agent-pipeline.yml" }
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

### Step 10: Validate Migration

```powershell
Write-Host "`n=== Migration Validation ===" -ForegroundColor Cyan

# Validate repository
$repos = az repos list --output json | ConvertFrom-Json
Write-Host "✓ Repositories: $($repos.Count)"

# Validate service connections
$connections = az devops service-endpoint list --output json | ConvertFrom-Json
Write-Host "✓ Service connections: $($connections.Count)"

# Validate variable groups
$varGroups = az pipelines variable-group list --output json | ConvertFrom-Json
Write-Host "✓ Variable groups: $($varGroups.Count)"

# Validate pipelines
$pipelines = az pipelines list --output json | ConvertFrom-Json
Write-Host "✓ Pipelines: $($pipelines.Count)"

Write-Host "`n✅ Migration complete!"
```

## Troubleshooting

### Token Expired
```powershell
# Refresh bearer token (tokens expire after 1 hour)
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```

### Repository Already Exists
```powershell
# List existing repositories
az repos list --output table

# Delete repository if needed (careful!)
az repos delete --id <repo-id> --yes
```

### Service Connection Creation Fails
```powershell
# Verify Service Principal exists
az ad sp show --id $spAppId

# Check permissions
az role assignment list --assignee $spAppId --output table

# Recreate with explicit parameters
az devops service-endpoint azurerm create --help
```

### Variable Group Creation Fails
```powershell
# List existing variable groups
az pipelines variable-group list --output table

# Update existing variable group
$vgId = az pipelines variable-group list --query "[?name=='foundry-dev-vars'].id" --output tsv
az pipelines variable-group variable create --group-id $vgId --name "NEW_VAR" --value "value"
```

### Pipeline Creation Fails
```powershell
# Verify YAML file exists in repository
az repos show-branch --repository $repoName --name main

# Check YAML syntax
az pipelines create --name "test" --repository $repoName --yml-path "path/to/pipeline.yml" --dry-run
```

## Best practices

1. **Always use configuration** - Run configuration-management skill first
2. **Test in non-production** - Validate process before production migration
3. **One environment at a time** - Create and test dev, then test, then prod
4. **Backup everything** - Keep backups for at least 30 days
5. **Document changes** - Record all commands and decisions
6. **Validate frequently** - Check each step before proceeding

## Integration with other skills

This skill works together with:
- **configuration-management** (required first) - Set up centralized configuration
- **environment-validation** - Validate prerequisites before migration
- **resource-creation** - Create Azure resources including Service Principal

## Related resources

- [COPILOT_EXECUTION_GUIDE.md](../../../COPILOT_EXECUTION_GUIDE.md) - Complete step-by-step migration guide
- [AZ_DEVOPS_CLI_REFERENCE.md](../../../AZ_DEVOPS_CLI_REFERENCE.md) - Azure DevOps CLI command reference
- [environment-validation/SKILL.md](../environment-validation/SKILL.md) - Environment validation documentation
- [resource-creation/SKILL.md](../resource-creation/SKILL.md) - Resource creation documentation
- [configuration-management/SKILL.md](../configuration-management/SKILL.md) - Configuration management documentation
