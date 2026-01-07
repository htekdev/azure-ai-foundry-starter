# Quick Reference - Complete Migration Flow

## 🚀 30-Second Overview

```
1. Authenticate → 2. Discover Resources → 3. Create Missing → 4. Migrate Code → 5. Configure DevOps → 6. Validate
```

---

## 📋 Pre-Flight Checklist

```powershell
# Verify tools
git --version           # Need 2.30+
az --version            # Need 2.50+
python --version        # Need 3.11+
$PSVersionTable.PSVersion  # Need 7.0+

# Install Azure DevOps extension
az extension add --name azure-devops
```

✅ **Ready to proceed when all tools are installed**

---

## 🔐 Step 1: Authenticate (2 minutes)

```powershell
# Login to Azure
az login

# Get bearer token for Azure DevOps
$env:ADO_TOKEN = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

# Configure for az devops
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

# Set defaults (replace with your org/project)
az devops configure --defaults `
    organization=https://dev.azure.com/<your-org> `
    project=<your-project>
```

✅ **Authenticated when commands run without errors**

---

## 🔍 Step 2: Discover Existing Resources (3 minutes)

```powershell
# Discover Azure DevOps resources
az repos list --output table
az pipelines list --output table
az devops service-endpoint list --output table
az pipelines variable-group list --output table

# Discover Azure resources
az ml workspace list --output table
az cognitiveservices account list --query "[?kind=='OpenAI']" --output table
az group list --output table
```

✅ **Discovery complete when you see existing resources listed**

---

## 🏗️ Step 3: Create Missing Azure Resources (5 minutes)

### Service Principal

```powershell
$subscriptionId = az account show --query id --output tsv

# Check if exists
$existingSp = az ad sp list --display-name "foundry-cicd-sp" --query "[].appId" --output tsv

if (-not $existingSp) {
    # Create new
    $sp = az ad sp create-for-rbac `
        --name "foundry-cicd-sp" `
        --role "Contributor" `
        --scopes "/subscriptions/$subscriptionId" `
        --output json | ConvertFrom-Json
    
    Write-Host "✓ Service Principal created"
    Write-Host "  App ID: $($sp.appId)"
    Write-Host "  Secret: $($sp.password)  # SAVE THIS!"
}
```

### Azure ML Workspace

```powershell
$resourceGroup = "rg-foundry-cicd"
$workspaceName = "mlw-foundry-cicd-dev"

# Create resource group if needed
az group create --name $resourceGroup --location eastus

# Create workspace
az ml workspace create `
    --name $workspaceName `
    --resource-group $resourceGroup `
    --location eastus
```

### Azure OpenAI

```powershell
$openaiName = "oai-foundry-cicd-dev"

# Create service
az cognitiveservices account create `
    --name $openaiName `
    --resource-group $resourceGroup `
    --kind OpenAI `
    --sku S0 `
    --location eastus `
    --yes

# Create deployment
az cognitiveservices account deployment create `
    --name $openaiName `
    --resource-group $resourceGroup `
    --deployment-name "gpt-4o" `
    --model-name gpt-4o `
    --model-version "2024-05-13" `
    --model-format OpenAI `
    --sku-capacity 10 `
    --sku-name "Standard"
```

✅ **Resources ready when all commands succeed**

---

## 📦 Step 4: Clone & Reorganize Repository (5 minutes)

```powershell
# Create workspace
$workspacePath = "C:\Repos\migration-workspace"
New-Item -ItemType Directory -Path $workspacePath -Force
cd $workspacePath

# Clone source
git clone https://github.com/balakreshnan/foundrycicdbasic.git source-repo
cd source-repo

# Create backup
cd ..
Compress-Archive -Path "source-repo" -DestinationPath "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
cd source-repo

# Create structure
$directories = @(
    ".azure-pipelines", "config", "src/agents", "src/evaluation",
    "src/security", "src/utils", "scripts", "tests/unit"
)
$directories | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force }

# Move files
Move-Item "createagent.py" "src/agents/create_agent.py" -Force
Move-Item "exagent.py" "src/agents/test_agent.py" -Force
Move-Item "agenteval.py" "src/evaluation/evaluate_agent.py" -Force
Move-Item "redteam.py" "src/security/redteam_scan.py" -Force

# Move CI/CD files
Move-Item "cicd/createagentpipeline.yml" ".azure-pipelines/create-agent-pipeline.yml" -Force
Move-Item "cicd/agentconsumptionpipeline.yml" ".azure-pipelines/test-agent-pipeline.yml" -Force
Remove-Item "cicd" -Recurse -Force

# Create Python packages
@("src/__init__.py", "src/agents/__init__.py", "src/evaluation/__init__.py", 
  "src/security/__init__.py", "src/utils/__init__.py") | ForEach-Object {
    New-Item -ItemType File -Path $_ -Force
    Set-Content -Path $_ -Value "# Package file"
}

# Update pipeline paths
Get-ChildItem ".azure-pipelines" -Filter "*.yml" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace 'createagent\.py', 'src/agents/create_agent.py'
    $content = $content -replace 'exagent\.py', 'src/agents/test_agent.py'
    Set-Content -Path $_.FullName -Value $content
}

# Commit
git checkout -b migration/reorganize
git add -A
git commit -m "Reorganize repository structure"
```

✅ **Repository ready when commit succeeds**

---

## 🏗️ Step 5: Configure Azure DevOps (10 minutes)

### Create Repository

```powershell
$repoName = "foundry-cicd"
$repo = az repos create --name $repoName --output json | ConvertFrom-Json
$remoteUrl = $repo.remoteUrl
```

### Push Code

```powershell
git remote add azure $remoteUrl
git config --local http.extraheader "AUTHORIZATION: bearer $env:ADO_TOKEN"

git checkout main
git push azure main

git checkout migration/reorganize
git push azure migration/reorganize

git config --local --unset http.extraheader
```

### Service Connections

```powershell
@("dev", "test", "prod") | ForEach-Object {
    az devops service-endpoint azurerm create `
        --azure-rm-service-principal-id $env:AZURE_CLIENT_ID `
        --azure-rm-subscription-id $(az account show --query id --output tsv) `
        --azure-rm-subscription-name "My Subscription" `
        --azure-rm-tenant-id $env:AZURE_TENANT_ID `
        --name "azure-foundry-$_"
    
    az devops service-endpoint update `
        --id $(az devops service-endpoint list --query "[?name=='azure-foundry-$_'].id" --output tsv) `
        --enable-for-all true
}
```

### Variable Groups

```powershell
@("dev", "test", "prod") | ForEach-Object {
    az pipelines variable-group create `
        --name "foundry-$_-vars" `
        --variables `
            ENVIRONMENT="$_" `
            AZURE_SERVICE_CONNECTION="azure-foundry-$_" `
            AZURE_OPENAI_API_VERSION="2024-02-15-preview" `
            AZURE_OPENAI_DEPLOYMENT="gpt-4o" `
        --authorize true
}
```

### Pipelines

```powershell
az pipelines create `
    --name "Foundry Agent Creation" `
    --repository $repoName `
    --repository-type tfsgit `
    --branch main `
    --yml-path ".azure-pipelines/create-agent-pipeline.yml" `
    --skip-first-run

az pipelines create `
    --name "Foundry Agent Testing" `
    --repository $repoName `
    --repository-type tfsgit `
    --branch main `
    --yml-path ".azure-pipelines/test-agent-pipeline.yml" `
    --skip-first-run
```

✅ **Azure DevOps configured when all resources created**

---

## ✅ Step 6: Validate (3 minutes)

```powershell
# Check repository
az repos list --output table

# Check pipelines
az pipelines list --output table

# Check service connections
az devops service-endpoint list --output table

# Check variable groups
az pipelines variable-group list --output table

# Run test pipeline
$pipelineId = az pipelines list --query "[?name=='Foundry Agent Creation'].id" --output tsv
az pipelines run --id $pipelineId --branch main
```

✅ **Migration complete when validation passes**

---

## ⏱️ Total Time: ~30 minutes

```
Authentication:          2 min
Resource Discovery:      3 min
Resource Creation:       5 min
Repository Migration:    5 min
Azure DevOps Config:    10 min
Validation:             3 min
─────────────────────────────
Total:                  28 min
```

---

## 🔄 Token Refresh (every 60 minutes)

```powershell
# Refresh bearer token
$env:ADO_TOKEN = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```

---

## 🚨 Emergency Rollback

```powershell
# Delete repository
$repoId = az repos list --query "[?name=='foundry-cicd'].id" --output tsv
az repos delete --id $repoId --yes

# Delete pipelines
az pipelines list --query "[?name contains(@, 'Foundry')].id" --output tsv | ForEach-Object {
    az pipelines delete --id $_ --yes
}

# Delete service connections
az devops service-endpoint list --query "[?name contains(@, 'azure-foundry')].id" --output tsv | ForEach-Object {
    az devops service-endpoint delete --id $_ --yes
}

# Delete variable groups
az pipelines variable-group list --query "[?name contains(@, 'foundry')].id" --output tsv | ForEach-Object {
    az pipelines variable-group delete --group-id $_ --yes
}
```

---

## 📚 Full Documentation

- **Complete Guide**: [COPILOT_EXECUTION_GUIDE.md](COPILOT_EXECUTION_GUIDE.md)
- **CLI Reference**: [AZ_DEVOPS_CLI_REFERENCE.md](AZ_DEVOPS_CLI_REFERENCE.md)
- **API Reference**: [API_REFERENCE.md](API_REFERENCE.md)
- **Overview**: [README.md](README.md)

---

## 💡 Pro Tips

1. **Copy entire code blocks** - They're designed to be run as-is
2. **Check after each step** - Use the ✅ checkpoints
3. **Save bearer token** - Store in `$env:ADO_TOKEN` for easy refresh
4. **Use tab completion** - Azure CLI supports tab completion
5. **Enable debug mode** - Set `$env:AZURE_DEVOPS_EXT_DEBUG = "true"` if issues

---

**Last Updated**: January 7, 2026  
**Quick Start Version**: 1.0
