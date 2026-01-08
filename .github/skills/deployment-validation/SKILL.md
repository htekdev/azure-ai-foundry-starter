---
name: deployment-validation
description: Validates the complete Azure AI Foundry deployment by checking repositories, service connections, variable groups, environments, pipelines, and optionally running the first agent deployment. This skill provides comprehensive verification of the deployment setup.
---

# Deployment Validation for Azure AI Foundry

This skill provides **comprehensive validation** of your Azure AI Foundry deployment by verifying all Azure DevOps resources are configured correctly.

## When to use this skill

Use this skill when you need to:
- Validate the complete deployment setup
- Verify all Azure DevOps resources were created correctly
- Check service connections, variable groups, environments, and pipelines
- Troubleshoot deployment issues
- Confirm readiness before first pipeline run

## Prerequisites

Before using this skill, ensure:
- ✅ Configuration loaded (use `configuration-management` skill first)
- ✅ Repository created (use `repository-setup` skill)
- ✅ Service connections configured (use `service-connection-setup` skill)
- ✅ Variable groups and environments created (use `environment-setup` skill)
- ✅ Pipelines created (use `pipeline-setup` skill)

## What This Skill Validates

- ✅ **Repository** - Code pushed and accessible
- ✅ **Service Connections** - Created with Workload Identity Federation
- ✅ **Federated Credentials** - Configured on Service Principal
- ✅ **Variable Groups** - Created with correct values
- ✅ **Environments** - Created for deployment stages
- ✅ **Pipelines** - Created and linked to repository
- ✅ **RBAC Permissions** - Service Principal has required roles
- ✅ **(Optional) First Run** - Execute and verify agent deployment

## Step-by-step execution

### Step 1: Load Configuration

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Extract values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$repoName = "azure-ai-foundry-app"
$spAppId = $config.servicePrincipal.appId
$subscriptionId = $config.azure.subscriptionId
$resourceGroup = $config.azure.resourceGroup

Write-Host "=== Azure AI Foundry Deployment Validation ===" -ForegroundColor Cyan
Write-Host ""
```

### Step 2: Validate Repository

```powershell
Write-Host "Validating Repository..." -ForegroundColor Yellow

try {
    $repo = az repos show --repository $repoName --output json | ConvertFrom-Json
    Write-Host "✓ Repository exists: $($repo.name)" -ForegroundColor Green
    Write-Host "  URL: $($repo.webUrl)"
    Write-Host "  ID: $($repo.id)"
    
    # Check if code is pushed
    $branches = az repos list-branches --repository $repoName --output json | ConvertFrom-Json
    if ($branches.Count -gt 0) {
        Write-Host "✓ Code pushed: $($branches.Count) branch(es) found" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Warning: No branches found - code may not be pushed" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Repository not found: $repoName" -ForegroundColor Red
    Write-Host "   Run repository-setup skill" -ForegroundColor Red
}

Write-Host ""
```

### Step 3: Validate Service Connections

```powershell
Write-Host "Validating Service Connections..." -ForegroundColor Yellow

$expectedSCs = @("azure-foundry-dev", "azure-foundry-test", "azure-foundry-prod")
$foundSCs = 0

foreach ($scName in $expectedSCs) {
    try {
        $sc = az devops service-endpoint list --query "[?name=='$scName']" --output json | ConvertFrom-Json
        if ($sc.Count -gt 0) {
            $scInfo = $sc[0]
            Write-Host "✓ Service connection exists: $scName" -ForegroundColor Green
            Write-Host "  ID: $($scInfo.id)"
            Write-Host "  Type: $($scInfo.type)"
            Write-Host "  Auth: $($scInfo.authorization.scheme)"
            
            # Check if authorized for all pipelines
            if ($scInfo.isShared -eq $true) {
                Write-Host "  ✓ Authorized for all pipelines" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  Not authorized for all pipelines" -ForegroundColor Yellow
            }
            
            $foundSCs++
        } else {
            Write-Host "❌ Service connection not found: $scName" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error checking service connection: $scName" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Service Connections: $foundSCs / $($expectedSCs.Count)" -ForegroundColor $(if ($foundSCs -eq $expectedSCs.Count) { "Green" } else { "Yellow" })
Write-Host ""
```

### Step 4: Validate Federated Credentials

```powershell
Write-Host "Validating Federated Credentials..." -ForegroundColor Yellow

try {
    $creds = az ad app federated-credential list --id $spAppId --output json | ConvertFrom-Json
    
    if ($creds.Count -gt 0) {
        Write-Host "✓ Federated credentials found: $($creds.Count)" -ForegroundColor Green
        
        foreach ($cred in $creds) {
            Write-Host "  - $($cred.name)"
            Write-Host "    Issuer: $($cred.issuer)"
            Write-Host "    Subject: $($cred.subject)"
        }
    } else {
        Write-Host "❌ No federated credentials found" -ForegroundColor Red
        Write-Host "   Run service-connection-setup skill Step 3" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ Error checking federated credentials" -ForegroundColor Red
}

Write-Host ""
```

### Step 5: Validate Variable Groups

```powershell
Write-Host "Validating Variable Groups..." -ForegroundColor Yellow

$expectedVGs = @("foundry-dev-vars", "foundry-test-vars", "foundry-prod-vars")
$foundVGs = 0

foreach ($vgName in $expectedVGs) {
    try {
        $vg = az pipelines variable-group list --query "[?name=='$vgName']" --output json | ConvertFrom-Json
        if ($vg.Count -gt 0) {
            $vgInfo = $vg[0]
            Write-Host "✓ Variable group exists: $vgName" -ForegroundColor Green
            Write-Host "  ID: $($vgInfo.id)"
            Write-Host "  Variables: $($vgInfo.variables.PSObject.Properties.Count)"
            
            # List key variables
            $requiredVars = @("AZURE_AI_PROJECT_ENDPOINT", "AZURE_AI_MODEL_DEPLOYMENT_NAME", "AZURE_RESOURCE_GROUP", "AZURE_SUBSCRIPTION_ID")
            foreach ($varName in $requiredVars) {
                if ($vgInfo.variables.$varName) {
                    Write-Host "    ✓ $varName" -ForegroundColor Green
                } else {
                    Write-Host "    ⚠️  Missing: $varName" -ForegroundColor Yellow
                }
            }
            
            $foundVGs++
        } else {
            Write-Host "❌ Variable group not found: $vgName" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Error checking variable group: $vgName" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Variable Groups: $foundVGs / $($expectedVGs.Count)" -ForegroundColor $(if ($foundVGs -eq $expectedVGs.Count) { "Green" } else { "Yellow" })
Write-Host ""
```

### Step 6: Validate Environments

```powershell
Write-Host "Validating Environments..." -ForegroundColor Yellow

try {
    $envs = az pipelines environment list --output json | ConvertFrom-Json
    
    $expectedEnvs = @("dev", "test", "production")
    $foundEnvs = 0
    
    foreach ($envName in $expectedEnvs) {
        $env = $envs | Where-Object { $_.name -eq $envName }
        if ($env) {
            Write-Host "✓ Environment exists: $envName" -ForegroundColor Green
            Write-Host "  ID: $($env.id)"
            $foundEnvs++
        } else {
            Write-Host "❌ Environment not found: $envName" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Environments: $foundEnvs / $($expectedEnvs.Count)" -ForegroundColor $(if ($foundEnvs -eq $expectedEnvs.Count) { "Green" } else { "Yellow" })
}
catch {
    Write-Host "❌ Error checking environments" -ForegroundColor Red
}

Write-Host ""
```

### Step 7: Validate Pipelines

```powershell
Write-Host "Validating Pipelines..." -ForegroundColor Yellow

try {
    $pipelines = az pipelines list --output json | ConvertFrom-Json
    
    if ($pipelines.Count -gt 0) {
        Write-Host "✓ Pipelines found: $($pipelines.Count)" -ForegroundColor Green
        
        foreach ($pipeline in $pipelines) {
            Write-Host "  - $($pipeline.name)"
            Write-Host "    ID: $($pipeline.id)"
            Write-Host "    Path: $($pipeline.path)"
            Write-Host "    URL: $org/$project/_build?definitionId=$($pipeline.id)"
        }
    } else {
        Write-Host "❌ No pipelines found" -ForegroundColor Red
        Write-Host "   Run pipeline-setup skill" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ Error checking pipelines" -ForegroundColor Red
}

Write-Host ""
```

### Step 8: Validate RBAC Permissions

```powershell
Write-Host "Validating RBAC Permissions..." -ForegroundColor Yellow

# Get Service Principal Object ID
$spObjectId = (az ad sp show --id $spAppId --query id -o tsv)

# Check Contributor role on resource group
$rgScope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
$contributorRole = az role assignment list --assignee $spObjectId --scope $rgScope --role "Contributor" --query "[].roleDefinitionName" -o tsv

if ($contributorRole) {
    Write-Host "✓ Contributor role assigned on resource group" -ForegroundColor Green
} else {
    Write-Host "❌ Missing Contributor role on resource group" -ForegroundColor Red
    Write-Host "   Run: az role assignment create --assignee $spAppId --role 'Contributor' --scope $rgScope" -ForegroundColor Yellow
}

# Check Cognitive Services User role on AI Foundry projects
$envs = @{
    "dev" = $config.azure.aiFoundry.dev.projectName
    "test" = $config.azure.aiFoundry.test.projectName
    "prod" = $config.azure.aiFoundry.prod.projectName
}

foreach ($env in $envs.Keys) {
    $projectName = $envs[$env]
    $projectScope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.MachineLearningServices/workspaces/$projectName"
    
    $cognitiveRole = az role assignment list --assignee $spObjectId --scope $projectScope --role "Cognitive Services User" --query "[].roleDefinitionName" -o tsv
    
    if ($cognitiveRole) {
        Write-Host "✓ Cognitive Services User role assigned on $projectName" -ForegroundColor Green
    } else {
        Write-Host "❌ Missing Cognitive Services User role on $projectName" -ForegroundColor Red
        Write-Host "   Run: az role assignment create --assignee $spAppId --role 'Cognitive Services User' --scope $projectScope" -ForegroundColor Yellow
    }
}

Write-Host ""
```

### Step 9: Deployment Summary

```powershell
Write-Host "=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository:          $(if ($repo) { '✓ Created' } else { '❌ Missing' })" -ForegroundColor $(if ($repo) { 'Green' } else { 'Red' })
Write-Host "Service Connections: $(if ($foundSCs -eq 3) { '✓ All created (3/3)' } else { "⚠️  Incomplete ($foundSCs/3)" })" -ForegroundColor $(if ($foundSCs -eq 3) { 'Green' } else { 'Yellow' })
Write-Host "Federated Creds:     $(if ($creds.Count -ge 3) { '✓ Configured' } else { '❌ Missing' })" -ForegroundColor $(if ($creds.Count -ge 3) { 'Green' } else { 'Red' })
Write-Host "Variable Groups:     $(if ($foundVGs -eq 3) { '✓ All created (3/3)' } else { "⚠️  Incomplete ($foundVGs/3)" })" -ForegroundColor $(if ($foundVGs -eq 3) { 'Green' } else { 'Yellow' })
Write-Host "Environments:        $(if ($foundEnvs -eq 3) { '✓ All created (3/3)' } else { "⚠️  Incomplete ($foundEnvs/3)" })" -ForegroundColor $(if ($foundEnvs -eq 3) { 'Green' } else { 'Yellow' })
Write-Host "Pipelines:           $(if ($pipelines.Count -gt 0) { "✓ Created ($($pipelines.Count))" } else { '❌ Missing' })" -ForegroundColor $(if ($pipelines.Count -gt 0) { 'Green' } else { 'Red' })
Write-Host "RBAC Permissions:    $(if ($contributorRole -and $cognitiveRole) { '✓ Configured' } else { '⚠️  Incomplete' })" -ForegroundColor $(if ($contributorRole -and $cognitiveRole) { 'Green' } else { 'Yellow' })
Write-Host ""

# Overall status
$allValid = $repo -and ($foundSCs -eq 3) -and ($creds.Count -ge 3) -and ($foundVGs -eq 3) -and ($foundEnvs -eq 3) -and ($pipelines.Count -gt 0) -and $contributorRole

if ($allValid) {
    Write-Host "✅ Deployment validation PASSED - Ready to run pipelines!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Deployment validation INCOMPLETE - Review errors above" -ForegroundColor Yellow
}

Write-Host ""
```

### Step 10: (Optional) Run First Pipeline

```powershell
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host ""

# Get Create Agent pipeline
$createAgentPipeline = az pipelines list --query "[?name=='Azure AI Foundry - Create Agent'].id" --output tsv

if ($createAgentPipeline) {
    Write-Host "Ready to deploy your first agent!"
    Write-Host ""
    Write-Host "Option 1 - Run via CLI:"
    Write-Host "  az pipelines run --id $createAgentPipeline" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 2 - Run via Azure DevOps Portal:"
    Write-Host "  $org/$project/_build?definitionId=$createAgentPipeline" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The pipeline will:"
    Write-Host "  1. Authenticate using Workload Identity Federation"
    Write-Host "  2. Install dependencies (azure-ai-projects SDK)"
    Write-Host "  3. Create/update agent in Azure AI Foundry"
    Write-Host "  4. Deploy to dev environment"
    Write-Host ""
}

Write-Host "Monitor pipeline runs:"
Write-Host "  $org/$project/_build" -ForegroundColor Cyan
Write-Host ""
```

## Validation Checklist

Use this checklist to verify deployment readiness:

- [ ] Repository exists with template code
- [ ] 3 service connections created (dev, test, prod)
- [ ] Service connections use Workload Identity Federation
- [ ] Service connections authorized for all pipelines
- [ ] 3 federated credentials on Service Principal
- [ ] 3 variable groups created with correct values
- [ ] 3 environments created (dev, test, production)
- [ ] Pipelines created from template YAML files
- [ ] Service Principal has Contributor role on resource group
- [ ] Service Principal has Cognitive Services User role on AI Foundry projects
- [ ] First pipeline run succeeds

## Troubleshooting

### Common Issues and Solutions

#### 1. Service Connection Not Authorized
**Symptom:** Pipeline fails with "service connection not found"

**Solution:**
```powershell
$scId = az devops service-endpoint list --query "[?name=='azure-foundry-dev'].id" --output tsv
az devops service-endpoint update --id $scId --enable-for-all true
```

#### 2. Federated Credential Mismatch
**Symptom:** Pipeline fails with AADSTS70021 error

**Solution:** Verify issuer and subject match Azure DevOps format:
```powershell
$orgName = $org.Split('/')[-1]
$issuer = "https://vstoken.dev.azure.com/$orgName"
$subject = "sc://$orgName/$project/azure-foundry-dev"
```

#### 3. Missing RBAC Permissions
**Symptom:** Pipeline fails accessing Azure resources

**Solution:**
```powershell
az role assignment create --assignee $spAppId --role "Contributor" --scope $rgScope
az role assignment create --assignee $spAppId --role "Cognitive Services User" --scope $projectScope
```

#### 4. Variable Group Values Empty
**Symptom:** Pipeline runs but fails due to empty variables

**Solution:** Update variable group with correct values:
```powershell
$vgId = az pipelines variable-group list --query "[?name=='foundry-dev-vars'].id" -o tsv
az pipelines variable-group variable update --id $vgId --name "AZURE_AI_PROJECT_ENDPOINT" --value "https://..."
```

## Best practices

1. **Run validation after each setup phase** - Catch issues early
2. **Fix issues immediately** - Don't proceed with incomplete setup
3. **Document customizations** - Track any deviations from template
4. **Test one environment first** - Validate dev before test/prod
5. **Monitor first pipeline run** - Review logs for any warnings
6. **Keep validation script** - Rerun after making changes

## Integration with other skills

This skill validates the output of:
- **repository-setup** - Checks repository and code
- **service-connection-setup** - Validates service connections and federated credentials
- **environment-setup** - Confirms variable groups and environments
- **pipeline-setup** - Verifies pipelines exist and are configured

## Related resources

- [docs/troubleshooting.md](../../../docs/troubleshooting.md) - Complete troubleshooting guide
- [docs/starter-guide.md](../../../docs/starter-guide.md) - Complete deployment guide
- [docs/quick-start.md](../../../docs/quick-start.md) - Fast track guide
- [docs/manual-checklist.md](../../../docs/manual-checklist.md) - Manual validation checklist
