---
name: pipeline-setup
description: Creates Azure DevOps CI/CD pipelines from the template YAML files. This skill creates pipelines for agent creation, testing, and deployment automation using the ready-to-use pipeline definitions.
---

# Pipeline Setup for Azure AI Foundry

This skill handles **creating Azure DevOps pipelines** from the template YAML files in your repository.

## When to use this skill

Use this skill when you need to:
- Create CI/CD pipelines from template YAML files
- Set up automated agent deployment pipelines
- Configure pipeline triggers and branches
- Enable continuous integration and deployment

## Prerequisites

Before using this skill, ensure:
- ✅ Configuration loaded (use `configuration-management` skill first)
- ✅ Repository created with template code (use `repository-setup` skill)
- ✅ Service connections configured (use `service-connection-setup` skill)
- ✅ Variable groups and environments created (use `environment-setup` skill)
- ✅ Azure DevOps authentication configured (bearer token set)

## What This Skill Creates

- **CI/CD Pipelines** from template YAML files
- **Pipeline definitions** linked to your repository
- **Automated triggers** (optional) for continuous deployment

## Automated Script

This skill includes `scripts/create-pipelines.ps1` which automates the entire pipeline setup process:

**What it does automatically**:
1. ✅ **Updates pipeline YAML files** - Replaces `REPLACE_WITH_YOUR_PROJECTNAME` placeholder with actual `config.naming.projectName`
2. ✅ **Commits and pushes changes** - Updates YAML files in the repository
3. ✅ **Creates pipelines** - Sets up pipelines from the updated YAML files

**Usage**:
```powershell
cd .github/skills/pipeline-setup
./scripts/create-pipelines.ps1 -UseConfig
```

**Why is this needed?**
- Variable groups are named `{projectName}-{env}-vars` (e.g., `myproject-dev-vars`)
- Pipeline YAML files must reference the correct variable group names
- The script ensures consistency between created infrastructure and pipeline configuration

## Pipeline Templates Available

The template application includes these pipeline YAML files:

| Pipeline | YAML Path | Purpose |
|----------|-----------|---------|
| Create Agent | `.azure-pipelines/createagentpipeline.yml` | Deploys AI agent to Azure AI Foundry |
| Agent Evaluation | `.azure-pipelines/agenteval.yml` | Runs agent evaluation tests |
| Red Team Testing | `.azure-pipelines/redteam.yml` | Runs security red team tests |

## Step-by-step execution

### Step 1: Load Configuration

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Extract values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$projectName = $config.naming.projectName
$repoName = "azure-ai-foundry-app"  # Your repository name

# Verify repository exists
$repoExists = az repos show --repository $repoName --query "id" -o tsv
if (-not $repoExists) {
    Write-Host "❌ Repository not found: $repoName"
    Write-Host "   Run the repository-setup skill first"
    exit 1
}

Write-Host "✓ Configuration loaded"
Write-Host "✓ Repository found: $repoName"
Write-Host "✓ Project name from config: $projectName"
```

### Step 2: Update Pipeline YAML Files (Automated)

**Important**: The pipeline YAML files contain placeholders that need to be replaced with your actual project name.

The `create-pipelines.ps1` script **automatically**:
1. Clones the repository temporarily
2. Replaces `REPLACE_WITH_YOUR_PROJECTNAME` with `$projectName` from config
3. Commits and pushes the updated YAML files back to the repository
4. Creates the pipelines from the updated YAML files

**Example replacement**:
```yaml
# Before (in repository)
variables:
  - group: 'REPLACE_WITH_YOUR_PROJECTNAME-dev-vars'

# After (automated replacement)
variables:
  - group: 'myproject-dev-vars'  # Where myproject = config.naming.projectName
```

**Manual alternative** (if needed):
```powershell
# Clone repository
git clone https://dev.azure.com/$org/$project/_git/$repoName
cd $repoName

# Replace placeholders in YAML files
$yamlFiles = Get-ChildItem -Path ".azure-pipelines" -Filter "*.yml"
foreach ($file in $yamlFiles) {
    (Get-Content $file.FullName) -replace "REPLACE_WITH_YOUR_PROJECTNAME", $projectName | Set-Content $file.FullName
}

# Commit and push
git add .azure-pipelines/*.yml
git commit -m "Update pipeline YAML files with projectName: $projectName"
git push origin main
```

### Step 3: Create Pipelines from Templates

```powershell
Write-Host "`nCreating pipelines..."

# Define pipelines to create
$pipelines = @(
    @{
        name = "Azure AI Foundry - Create Agent"
        path = ".azure-pipelines/createagentpipeline.yml"
        description = "Deploys AI agent to Azure AI Foundry"
    },
    @{
        name = "Azure AI Foundry - Agent Evaluation"
        path = ".azure-pipelines/agenteval.yml"
        description = "Runs agent evaluation tests"
    },
    @{
        name = "Azure AI Foundry - Red Team"
        path = ".azure-pipelines/redteam.yml"
        description = "Runs security red team tests"
    }
)

foreach ($pipeline in $pipelines) {
    # Check if pipeline already exists
    $existingPipeline = az pipelines list --query "[?name=='$($pipeline.name)'].id" --output tsv
    
    if (-not $existingPipeline) {
        Write-Host "Creating pipeline: $($pipeline.name)"
        
        try {
            $pipelineId = az pipelines create `
                --name "$($pipeline.name)" `
                --repository $repoName `
                --repository-type tfsgit `
                --branch main `
                --yml-path "$($pipeline.path)" `
                --skip-first-run `
                --output json | ConvertFrom-Json | Select-Object -ExpandProperty id
            
            Write-Host "✓ Pipeline created: $($pipeline.name) (ID: $pipelineId)"
            Write-Host "  Description: $($pipeline.description)"
            Write-Host "  YAML: $($pipeline.path)"
        }
        catch {
            Write-Host "❌ Failed to create pipeline: $($pipeline.name)"
            Write-Host "   Error: $_"
            Write-Host "   Verify YAML path exists in repository: $($pipeline.path)"
        }
    } else {
        Write-Host "✓ Pipeline already exists: $($pipeline.name) (ID: $existingPipeline)"
    }
}

Write-Host "`n✅ Pipeline setup complete!"
```

### Step 4: Verify Pipeline Configuration

```powershell
Write-Host "`n=== Verifying Pipeline Configuration ==="

# List all pipelines
$allPipelines = az pipelines list --output json | ConvertFrom-Json

Write-Host "`nCreated Pipelines:"
foreach ($p in $allPipelines) {
    Write-Host "  - $($p.name)"
    Write-Host "    ID: $($p.id)"
    Write-Host "    Path: $($p.path)"
    Write-Host "    Repository: $($p.repository.name)"
}

Write-Host "`nPipeline URLs:"
foreach ($p in $allPipelines) {
    Write-Host "  - $($p.name): $org/$project/_build?definitionId=$($p.id)"
}
```

### Step 5: (Optional) Configure Pipeline Triggers

By default, pipelines are created with `--skip-first-run` to prevent automatic execution.

**To enable CI triggers (automatic runs on code push):**

```powershell
# Option 1: Update YAML file to enable triggers
# Edit .azure-pipelines/createagentpipeline.yml:
# trigger:
#   branches:
#     include:
#       - main
#   paths:
#     include:
#       - src/agents/*

# Option 2: Enable via Azure DevOps UI
Write-Host "`nTo enable CI triggers:"
Write-Host "1. Go to: $org/$project/_build"
Write-Host "2. Select pipeline > Edit"
Write-Host "3. Click 'Triggers' tab"
Write-Host "4. Enable 'Continuous integration'"
Write-Host "5. Configure branch filters and path filters"
```

### Step 6: (Optional) Run First Pipeline

```powershell
Write-Host "`n=== Running First Pipeline (Optional) ==="

# Get the Create Agent pipeline ID
$createAgentPipeline = az pipelines list --query "[?name=='Azure AI Foundry - Create Agent'].id" --output tsv

if ($createAgentPipeline) {
    Write-Host "To run the Create Agent pipeline:"
    Write-Host "1. Manual run via CLI:"
    Write-Host "   az pipelines run --id $createAgentPipeline"
    Write-Host ""
    Write-Host "2. Manual run via UI:"
    Write-Host "   $org/$project/_build?definitionId=$createAgentPipeline"
    Write-Host "   Click 'Run pipeline' button"
    Write-Host ""
    Write-Host "3. Automatic run on code push (if CI triggers enabled)"
} else {
    Write-Host "⚠️  Create Agent pipeline not found"
}
```

## Pipeline YAML Structure

Understanding the pipeline YAML structure helps with customization:

```yaml
# Basic structure of template pipelines
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - src/agents/*

variables:
  - group: REPLACE_WITH_YOUR_PROJECTNAME-dev-vars  # References variable group: {projectName}-dev-vars

stages:
  - stage: Dev
    jobs:
      - deployment: DeployAgent
        environment: dev  # References environment
        pool:
          vmImage: 'ubuntu-latest'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: 'azure-foundry-dev'  # References service connection
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Pipeline YAML Path Not Found
**Error:** `Could not find file at path .azure-pipelines/createagentpipeline.yml`

**Solution:** Verify the YAML file exists in your repository:
```powershell
# Check files in repository
az repos list-branches --repository $repoName

# Or check locally
Set-Location "C:\Repos\ado\azure-ai-foundry-app"
Test-Path ".azure-pipelines/createagentpipeline.yml"

# If missing, ensure template code was pushed correctly (repository-setup skill)
```

#### 2. Service Connection Not Found
**Error:** `The pipeline is not valid. Could not find service connection 'azure-foundry-dev'`

**Solution:** Verify service connections exist and are authorized:
```powershell
# List service connections
az devops service-endpoint list --query "[].name" --output tsv

# Authorize service connection for all pipelines
$scId = az devops service-endpoint list --query "[?name=='azure-foundry-dev'].id" --output tsv
az devops service-endpoint update --id $scId --enable-for-all true
```

#### 3. Variable Group Not Found
**Error:** `The pipeline is not valid. Could not find variable group '{projectName}-dev-vars'`

**Solution:** Verify variable groups exist and are authorized:
```powershell
# List variable groups
az pipelines variable-group list --query "[].name" --output tsv

# Authorize variable group (use your actual projectName from config)
$vgName = "$projectName-dev-vars"  # Replace with your config.naming.projectName
$vgId = az pipelines variable-group list --query "[?name=='$vgName'].id" --output tsv
az pipelines variable-group update --id $vgId --authorize true
```

#### 4. Environment Not Found
**Error:** `The pipeline is not valid. Could not find environment 'dev'`

**Solution:** Verify environments exist:
```powershell
# List environments
az pipelines environment list --query "[].name" --output tsv

# Create if missing (use environment-setup skill)
```

#### 5. Pipeline Creation Permission Denied
**Error:** `TF401027: You need the Git 'Create Repository' permission`

**Solution:** Verify you have necessary permissions:
1. Check Azure DevOps project permissions
2. Ensure you have "Build Administrator" role
3. Or use a PAT with "Build (read and execute)" and "Release (read, write, execute and manage)" scopes

#### 6. Repository Type Error
**Error:** `--repository-type must be github or tfsgit`

**Solution:** Ensure you specify `--repository-type tfsgit` for Azure DevOps repositories:
```powershell
az pipelines create `
    --repository-type tfsgit `  # Use tfsgit for Azure Repos
    ...
```

## Best practices

1. **Skip first run** - Use `--skip-first-run` to prevent immediate execution
2. **Review YAML before creating** - Understand pipeline logic and dependencies
3. **Use descriptive names** - Follow pattern: "Azure AI Foundry - {Purpose}"
4. **Enable CI triggers carefully** - Start manual, enable automation later
5. **Test one pipeline first** - Verify Create Agent pipeline before others
6. **Document customizations** - Track any changes to template YAML files
7. **Use pipeline templates** - Create reusable YAML templates for common tasks
8. **Monitor pipeline runs** - Check run history and logs regularly

## Pipeline Execution Order

Recommended order for first runs:

1. **Create Agent** - Deploy your first agent to AI Foundry
2. **Agent Evaluation** - Validate agent responses and behavior
3. **Red Team** - Test agent security and safety

## Integration with other skills

This skill works together with:
- **configuration-management** (required first) - Loads centralized configuration
- **repository-setup** (required) - Creates repository with template YAML files
- **service-connection-setup** (required) - Pipelines reference service connections
- **environment-setup** (required) - Pipelines reference variable groups and environments
- **deployment-validation** (next step) - Validates pipeline execution

## Related resources

- [docs/troubleshooting.md](../../../docs/troubleshooting.md) - Lesson #2, #5: Pipeline issues
- [docs/starter-guide.md](../../../docs/starter-guide.md) - Complete deployment guide
- [docs/azure-devops-cicd-reference.md](../../../docs/azure-devops-cicd-reference.md) - Pipeline reference
- [Azure DevOps: Pipelines](https://learn.microsoft.com/azure/devops/pipelines/)
- [Azure DevOps: YAML schema](https://learn.microsoft.com/azure/devops/pipelines/yaml-schema)
