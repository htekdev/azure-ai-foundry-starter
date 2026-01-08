---
name: repository-setup
description: Creates Azure DevOps repository and pushes the ready-to-use Azure AI Foundry template application code. This skill handles git initialization, repository creation via Azure DevOps CLI, and pushing the template code with proper authentication.
---

# Repository Setup for Azure AI Foundry

This skill handles **creating the Azure DevOps repository** and **pushing the template application code** from the `template-app/` directory.

## When to use this skill

Use this skill when you need to:
- Create a new Azure DevOps repository for the AI Foundry application
- Push the ready-to-use template application code to Azure DevOps
- Initialize git repository and configure remote connections
- Set up the application repository structure

## Prerequisites

Before using this skill, ensure:
- ✅ Configuration loaded (use `configuration-management` skill first)
- ✅ Azure DevOps authentication configured (bearer token set)
- ✅ Azure DevOps CLI configured with organization and project defaults
- ✅ Template application exists in `template-app/` directory

## What This Skill Creates

- **1 Azure DevOps Repository** with the template application code
- **Git configuration** with Azure DevOps remote
- **.env file** from sample.env template

## Step-by-step execution

### Step 1: Load Configuration

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Extract values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$targetRepo = "azure-ai-foundry-app"  # Your repository name

# Verify Azure DevOps CLI is configured
az devops configure --defaults organization=$org project=$project
```

### Step 2: Prepare Template Application

```powershell
# Navigate to template-app directory
$templatePath = "$PSScriptRoot/../../../template-app"
Set-Location $templatePath

# Initialize git if not already initialized
if (-not (Test-Path ".git")) {
    git init
    git add -A
    git commit -m "Initial commit - Azure AI Foundry starter template"
    Write-Host "✓ Git repository initialized"
} else {
    Write-Host "✓ Git repository already initialized"
}

# Create .env file from sample.env
if (-not (Test-Path ".env")) {
    Copy-Item "sample.env" ".env"
    Write-Host "✓ .env file created from sample.env"
    Write-Host "⚠️  IMPORTANT: Edit .env file with your Azure resource details"
} else {
    Write-Host "✓ .env file already exists"
}
```

### Step 3: Create Azure DevOps Repository

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
Write-Host "✓ Repository URL: $remoteUrl"
```

### Step 4: Push Template Code to Azure DevOps

```powershell
# Add Azure DevOps remote (or update if exists)
$existingRemote = git remote get-url azure 2>$null
if ($existingRemote) {
    git remote set-url azure $remoteUrl
    Write-Host "✓ Azure remote updated"
} else {
    git remote add azure $remoteUrl
    Write-Host "✓ Azure remote added"
}

# Configure git authentication
git config --local http.extraheader "AUTHORIZATION: bearer $env:ADO_TOKEN"

# Push code to main branch
try {
    git push azure main
    Write-Host "✓ Template code pushed to Azure DevOps"
} catch {
    Write-Host "⚠️  Push failed - checking if repository is initialized..."
    # Create main branch if it doesn't exist
    git branch -M main
    git push -u azure main
    Write-Host "✓ Template code pushed to Azure DevOps (new main branch)"
}

# Remove auth header (security best practice)
git config --local --unset http.extraheader

Write-Host "`n✅ Repository setup complete!"
Write-Host "Repository: $org/$project/_git/$repoName"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Repository Already Exists
**Error:** `TF400948: A Git repository with the name xyz already exists`
**Solution:** The script handles this automatically by checking for existing repositories. If you need to recreate, delete the repository first:
```powershell
az repos delete --id $repoName --yes
```

#### 2. Git Push Authentication Failed
**Error:** `fatal: Authentication failed`
**Solution:** Refresh your bearer token:
```powershell
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```

#### 3. Remote Already Exists
**Error:** `fatal: remote azure already exists`
**Solution:** The script handles this by using `set-url` instead of `add`. To manually fix:
```powershell
git remote remove azure
git remote add azure $remoteUrl
```

#### 4. Template App Directory Not Found
**Error:** `Cannot find path`
**Solution:** Ensure you're in the azure-ai-foundry-starter workspace:
```powershell
Set-Location "C:\Repos\ado\azure-ai-foundry-starter"
```

## Best practices

1. **Use meaningful repository names** - Choose names that reflect your project (e.g., "contoso-support-agent")
2. **Protect the .env file** - Ensure .env is in .gitignore and never committed
3. **Keep template updated** - Pull latest changes from the starter repository periodically
4. **Document customizations** - Track any changes you make to the template in a separate CHANGELOG
5. **Use branch protection** - Configure branch policies after initial setup for production use

## Integration with other skills

This skill works together with:
- **configuration-management** (required first) - Loads centralized configuration
- **service-connection-setup** (next step) - Creates service connections for the repository
- **environment-setup** (after service connections) - Creates variable groups and environments
- **pipeline-setup** (after environments) - Creates CI/CD pipelines from the repository

## Related resources

- [docs/starter-guide.md](../../../docs/starter-guide.md) - Complete deployment guide
- [docs/quick-start.md](../../../docs/quick-start.md) - Fast track guide
- [template-app/README.md](../../../template-app/README.md) - Template application documentation
- [template-app/FEEDBACK.md](../../../template-app/FEEDBACK.md) - Submit feedback about the template
