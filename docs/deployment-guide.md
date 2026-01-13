# Deployment Guide

This guide provides detailed information about deploying the Azure AI Foundry Starter template, including best practices, deployment patterns, and lessons learned from production deployments.

## 📋 Table of Contents

1. [Deployment Overview](#deployment-overview)
2. [Deployment Patterns](#deployment-patterns)
3. [Service Connection Setup](#service-connection-setup)
4. [Federated Credentials Configuration](#federated-credentials-configuration)
5. [Variable Group Management](#variable-group-management)
6. [Pipeline Configuration](#pipeline-configuration)
7. [Multi-Environment Strategy](#multi-environment-strategy)
8. [Security Best Practices](#security-best-practices)
9. [Deployment Validation](#deployment-validation)
10. [Production Considerations](#production-considerations)

---

## Deployment Overview

The Azure AI Foundry Starter template supports three deployment patterns:

1. **Automated Script Deployment** - Complete setup in 10-15 minutes
2. **GitHub Copilot Agent Deployment** - Interactive guided setup
3. **Manual Step-by-Step Deployment** - Full control with detailed instructions

### Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Resources                          │
│  - Service Principal (with federated credentials)           │
│  - Resource Groups (dev, test, prod)                        │
│  - AI Services Resources (per environment)                  │
│  - AI Foundry Projects (per environment)                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Azure DevOps Setup                         │
│  - Repository with application code                         │
│  - Service Connections (federated, per environment)         │
│  - Variable Groups (per environment)                        │
│  - Environments (dev, test, prod with approvals)            │
│  - CI/CD Pipelines (multi-stage)                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Deployment Flow                            │
│  DEV → Automatic                                            │
│  TEST → Automatic                                           │
│  PROD → Manual Approval Required                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Deployment Patterns

### Pattern 1: Automated Script Deployment

**Best for:** Quick setup, standardized deployments, CI/CD automation

**Command:**
```powershell
.\scripts\setup.ps1 `
    -ProjectName "foundrycicd" `
    -ADOProjectName "foundrycicd" `
    -OrganizationUrl "https://dev.azure.com/your-org" `
    -TenantId "YOUR_TENANT_ID" `
    -SubscriptionId "YOUR_SUBSCRIPTION_ID"
```

**What it does:**
1. Creates all Azure resources
2. Configures service principal with federated credentials
3. Sets up Azure DevOps infrastructure
4. Creates and configures pipelines
5. Validates complete deployment

**Time:** 10-15 minutes

---

### Pattern 2: GitHub Copilot Agent Deployment

**Best for:** Learning, interactive troubleshooting, customization

**Usage:**
```
@workspace I want to deploy the Azure AI Foundry starter
```

**Benefits:**
- Step-by-step guidance
- Explains each action
- Helps troubleshoot issues
- Interactive customization

**Time:** 20-30 minutes (with explanations)

---

### Pattern 3: Manual Deployment

**Best for:** Understanding internals, custom requirements, existing infrastructure

See [SETUP_GUIDE.md](../SETUP_GUIDE.md) for complete manual instructions.

**Time:** 45-60 minutes

---

## Service Connection Setup

### Using REST API (Recommended)

**Why REST API?** The Azure CLI `az devops service-endpoint azurerm create` command does NOT support federated credentials - it prompts for passwords/secrets. The REST API is the only way to create service connections with Workload Identity Federation.

### Creating Service Connection with Federated Credentials

```powershell
$org = "https://dev.azure.com/YOUR_ORG"
$projectId = az devops project show --project "YOUR_PROJECT" --query id -o tsv
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

$body = @{
    authorization = @{
        scheme = "WorkloadIdentityFederation"
        parameters = @{
            tenantid = "YOUR_TENANT_ID"
            serviceprincipalid = "YOUR_SP_APP_ID"
        }
    }
    data = @{
        subscriptionId = "YOUR_SUBSCRIPTION_ID"
        subscriptionName = "YOUR_SUBSCRIPTION_NAME"
    }
    name = "foundrycicd-dev"
    type = "azurerm"
    url = "https://management.azure.com/"
} | ConvertTo-Json -Depth 10

$sc = Invoke-RestMethod `
    -Uri "$org/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" `
    -Headers $headers `
    -Method Post `
    -Body $body

Write-Host "✓ Service connection created: $($sc.name)"
Write-Host "  ID: $($sc.id)"
```

### Authorizing Service Connection for Pipelines

```powershell
# Enable for all pipelines
az devops service-endpoint update --id $sc.id --enable-for-all true

# Or authorize for specific pipeline
$pipelineId = az pipelines list --query "[?name=='Your Pipeline'].id" -o tsv

$authBody = @{
    allPipelines = $false
    authorized = $true
    pipelines = @(@{ id = $pipelineId; authorized = $true })
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
    -Uri "$org/$projectId/_apis/pipelines/pipelinePermissions/endpoint/$($sc.id)/?api-version=7.1-preview.1" `
    -Headers $headers `
    -Method Patch `
    -Body $authBody
```

---

## Federated Credentials Configuration

### Critical: Get Actual Values from Service Connection

**DO NOT** try to predict the issuer and subject values. Azure DevOps uses specific formats that you MUST retrieve from the created service connection.

### Step 1: Create Service Connection First

Always create the service connection BEFORE creating federated credentials.

### Step 2: Retrieve Actual Issuer and Subject

```powershell
$org = "https://dev.azure.com/YOUR_ORG"
$projectId = az devops project show --project "YOUR_PROJECT" --query id -o tsv
$scName = "foundrycicd-dev"

$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
$headers = @{ Authorization = "Bearer $token" }

$serviceConnections = Invoke-RestMethod `
    -Uri "$org/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" `
    -Headers $headers

$conn = $serviceConnections.value | Where-Object { $_.name -eq $scName }

$issuer = $conn.authorization.parameters.workloadIdentityFederationIssuer
$subject = $conn.authorization.parameters.workloadIdentityFederationSubject

Write-Host "Issuer: $issuer"
Write-Host "Subject: $subject"
```

**What you'll see:**
- **Issuer**: `https://login.microsoftonline.com/{tenantId}/v2.0`
- **Subject**: `/eid1/c/pub/t/.../sc/.../...` (encoded path)

**NOT:**
- ~~`https://vstoken.dev.azure.com/{tenantId}`~~
- ~~`sc://{org}/{project}/{scName}`~~

### Step 3: Create Federated Credential with Actual Values

```powershell
$spAppId = "YOUR_SP_APP_ID"

$fedCred = @{
    name = "AzureDevOps-$scName"
    issuer = $issuer
    subject = $subject
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json

$fedCred | Out-File -FilePath "$env:TEMP\fed-cred.json" -Encoding utf8

az ad app federated-credential create --id $spAppId --parameters "$env:TEMP\fed-cred.json"

Write-Host "✓ Federated credential created for $scName"
```

### Verification

```powershell
# List federated credentials
az ad app federated-credential list --id $spAppId -o table

# Test service connection
az devops service-endpoint show --id $scId --query "isReady" -o tsv  # Should return: True
```

---

## Variable Group Management

### Creating Variable Groups

Variable groups store environment-specific configuration values that pipelines use at runtime.

```powershell
az pipelines variable-group create `
    --name "foundrycicd-dev-vars" `
    --variables `
        AZURE_AI_PROJECT_ENDPOINT="https://resource.services.ai.azure.com/api/projects/project-dev" `
        AZURE_AI_PROJECT_NAME="project-foundrycicd-dev" `
        AZURE_AI_MODEL_DEPLOYMENT_NAME="gpt-4o" `
        AZURE_OPENAI_ENDPOINT="https://resource.openai.azure.com/" `
        AZURE_OPENAI_DEPLOYMENT="gpt-4o" `
        AZURE_OPENAI_API_VERSION="2024-02-15-preview" `
        AZURE_RESOURCE_GROUP="rg-foundrycicd-dev" `
    --authorize true
```

### Required Variables

**Critical Variables (Often Missing from Documentation):**
- `AZURE_AI_PROJECT_ENDPOINT` - Full AI Foundry project endpoint
- `AZURE_AI_PROJECT_NAME` - Project name
- `AZURE_AI_MODEL_DEPLOYMENT_NAME` - Model deployment name ⚠️ **Often missed!**
- `AZURE_OPENAI_ENDPOINT` - OpenAI resource endpoint
- `AZURE_OPENAI_DEPLOYMENT` - Deployment name
- `AZURE_OPENAI_API_VERSION` - API version

**Pro Tip:** Always check the application's `sample.env` file for the complete list of required variables. Official documentation may be incomplete.

### Finding the Correct AI Foundry Project Endpoint

**Common Mistakes:**
- ❌ `https://ml.azure.com` - This is the portal URL, not an API endpoint
- ❌ `https://eastus.api.azureml.ms` - This is the ML workspace API, not AI Foundry

**Correct Format:**
```
https://<ai-services-resource-name>.services.ai.azure.com/api/projects/<project-name>
```

**Using Azure CLI:**
```powershell
az resource show `
    --ids "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<resource>/projects/<project>" `
    --query "properties.endpoints" -o json
```

**Using Portal:**
1. Go to [https://ai.azure.com](https://ai.azure.com)
2. Select your project
3. Overview → Copy "Foundry project endpoint"

### Authorizing Variable Groups

```powershell
# Authorize for all pipelines
$vgId = az pipelines variable-group list --query "[?name=='foundrycicd-dev-vars'].id" -o tsv
az pipelines variable-group update --id $vgId --authorize true
```

---

## Pipeline Configuration

### Critical YAML Patterns

#### ✅ Correct: Hardcoded Service Connection Names

```yaml
- stage: Dev
  variables:
    - group: 'foundrycicd-dev-vars'
  jobs:
    - deployment: DeployAgentDev
      environment: dev
      strategy:
        runOnce:
          deploy:
            steps:
              - task: AzureCLI@2
                inputs:
                  azureSubscription: 'foundrycicd-dev'  # ✅ Literal value
                  scriptType: 'bash'
                  addSpnToEnvironment: true
                  inlineScript: |
                    export AZURE_AI_PROJECT_ENDPOINT="$(AZURE_AI_PROJECT_ENDPOINT)"
                    export AZURE_AI_MODEL_DEPLOYMENT_NAME="$(AZURE_AI_MODEL_DEPLOYMENT_NAME)"
                    python src/agents/createagent.py
```

#### ❌ Incorrect: Variable References in azureSubscription

```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: '$(AZURE_SERVICE_CONNECTION_DEV)'  # ❌ Won't validate
```

**Why:** The `azureSubscription` field is validated before the pipeline runs, but variables are only resolved at runtime.

### Using Automatic Environment Variables

When `addSpnToEnvironment: true` is set, Azure CLI task provides:
- `$servicePrincipalId` - Service principal application ID
- `$tenantId` - Azure AD tenant ID
- `$subscriptionId` - Azure subscription ID

**Don't create these in variable groups - use the automatic ones:**

```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'foundrycicd-dev'
    scriptType: 'bash'
    addSpnToEnvironment: true  # ✅ Enables automatic variables
    inlineScript: |
      export AZURE_SUBSCRIPTION_ID="$subscriptionId"      # ✅ Automatic
      export AZURE_TENANT_ID="$tenantId"                 # ✅ Automatic
      export AZURE_CLIENT_ID="$servicePrincipalId"       # ✅ Automatic
      
      # Application-specific from variable groups
      export AZURE_AI_PROJECT_ENDPOINT="$(AZURE_AI_PROJECT_ENDPOINT)"
      export AZURE_AI_MODEL_DEPLOYMENT_NAME="$(AZURE_AI_MODEL_DEPLOYMENT_NAME)"
      
      python src/agents/createagent.py
```

---

## Multi-Environment Strategy

### Environment Configuration

**DEV Environment:**
- Automatic deployment on commit to main branch
- No approval required
- Used for development and integration testing

**TEST Environment:**
- Automatic deployment after DEV succeeds
- No approval required (optional: can add approval)
- Used for acceptance testing

**PROD Environment:**
- Deployment after TEST succeeds
- **Manual approval required**
- Used for production workloads

### Setting Up Approval Gates

```powershell
# Create environment with approval
$envName = "production"
az pipelines environment create --name $envName

# Add approval via portal (CLI doesn't support approvals yet)
# Go to: Pipelines → Environments → production → Approvals and checks → Add Approval
```

### Pipeline Structure

```yaml
trigger:
  - main

stages:
  - stage: Dev
    displayName: 'Deploy to DEV'
    variables:
      - group: 'foundrycicd-dev-vars'
    jobs:
      - deployment: DeployDev
        environment: dev
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: 'foundrycicd-dev'
                    # ... deployment steps

  - stage: Test
    displayName: 'Deploy to TEST'
    dependsOn: Dev
    condition: succeeded('Dev')
    variables:
      - group: 'foundrycicd-test-vars'
    jobs:
      - deployment: DeployTest
        environment: test
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: 'foundrycicd-test'
                    # ... deployment steps

  - stage: Prod
    displayName: 'Deploy to PROD'
    dependsOn: Test
    condition: succeeded('Test')
    variables:
      - group: 'foundrycicd-prod-vars'
    jobs:
      - deployment: DeployProd
        environment: production  # Has approval gate
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: 'foundrycicd-prod'
                    # ... deployment steps
```

---

## Security Best Practices

### 1. Zero-Secrets Architecture

**Principle:** Never store passwords or keys. Use Workload Identity Federation.

**Benefits:**
- No secrets in variable groups
- No secrets in pipeline definitions
- Automatic token rotation by Azure AD
- Better audit trail

### 2. Least Privilege RBAC

**Service Principal Permissions:**

**Control Plane (Azure Resource Manager):**
```powershell
# Grant Contributor on resource group only (not subscription)
az role assignment create `
    --assignee $spId `
    --role "Contributor" `
    --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>"
```

**Data Plane (AI Services):**
```powershell
# Grant Cognitive Services User for data operations
az role assignment create `
    --assignee $spId `
    --role "Cognitive Services User" `
    --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<resource>"
```

### 3. Environment Isolation

- Separate service principals per environment (optional but recommended)
- Separate variable groups per environment
- Separate service connections per environment
- Approval gates on production

### 4. Audit and Monitoring

```powershell
# Review role assignments
az role assignment list --assignee $spId -o table

# Review federated credentials
az ad app federated-credential list --id $spAppId -o table

# Review service connection usage
az pipelines runs list --query "[].{Name:definition.name, Status:status, Date:finishTime}" -o table
```

---

## Deployment Validation

### Pre-Deployment Checklist

```powershell
# 1. Verify authentication
az account show
az devops project show --project "YOUR_PROJECT"

# 2. Verify Azure resources
az group list --query "[?starts_with(name, 'rg-foundrycicd')].name" -o table
az cognitiveservices account list --query "[?starts_with(name, 'foundrycicd')].name" -o table

# 3. Verify Service Principal
az ad sp list --display-name "sp-foundrycicd-cicd" --query "[].{Name:displayName, AppId:appId}" -o table

# 4. Verify RBAC
$spId = az ad sp list --display-name "sp-foundrycicd-cicd" --query "[0].id" -o tsv
az role assignment list --assignee $spId --query "[].{Role:roleDefinitionName, Scope:scope}" -o table

# 5. Verify federated credentials
$spAppId = az ad sp list --display-name "sp-foundrycicd-cicd" --query "[0].appId" -o tsv
az ad app federated-credential list --id $spAppId -o table

# 6. Verify Azure DevOps resources
az devops service-endpoint list --query "[].{Name:name, Type:type, Ready:isReady}" -o table
az pipelines variable-group list --query "[].name" -o table
az pipelines environment list --query "[].name" -o table
az pipelines list --query "[].name" -o table
```

### Post-Deployment Validation

```powershell
# Run validation script
.\.github\skills\deployment-validation\scripts\validate-deployment.ps1 -UseConfig -Environment 'all'

# Or manual checks:

# 1. Trigger pipeline
$pipelineId = az pipelines list --query "[?name=='Azure AI Foundry - Create Agent'].id" -o tsv
$runId = az pipelines run --id $pipelineId --query "id" -o tsv

# 2. Monitor pipeline
az pipelines runs show --id $runId --query "{Status:status, Result:result}" -o json

# 3. Check pipeline logs
az pipelines runs show --id $runId --query "logs" -o json

# 4. Verify agent in portal
# Go to https://ai.azure.com → Select project → Agents → Verify agent exists
```

---

## Production Considerations

### 1. Pipeline Performance

**Optimization:**
- Cache Python dependencies
- Parallel job execution where possible
- Use self-hosted agents for faster builds

```yaml
- task: Cache@2
  inputs:
    key: 'python | "$(Agent.OS)" | requirements.txt'
    path: $(Pipeline.Workspace)/.pip
    restoreKeys: |
      python | "$(Agent.OS)"
  displayName: 'Cache pip packages'
```

### 2. Monitoring and Alerting

**Set up:**
- Azure DevOps pipeline notifications
- Azure Monitor alerts for AI Services
- Application Insights for agent telemetry

### 3. Backup and Recovery

```powershell
# Backup configuration
Copy-Item starter-config.json "backups/config-$(Get-Date -Format 'yyyyMMdd').json"

# Backup variable groups
az pipelines variable-group list -o json | Out-File "backups/var-groups-$(Get-Date -Format 'yyyyMMdd').json"

# Backup service principal info
az ad sp show --id $spAppId -o json | Out-File "backups/sp-$(Get-Date -Format 'yyyyMMdd').json"
```

### 4. Disaster Recovery

**Recovery Steps:**
1. Restore configuration from backup
2. Re-run setup script to recreate resources
3. Restore variable group values
4. Re-authorize service connections
5. Validate deployment

---

## 📚 Additional Resources

- **Setup Guide:** [SETUP_GUIDE.md](../SETUP_GUIDE.md)
- **Troubleshooting:** [troubleshooting.md](troubleshooting.md)
- **Lessons Learned:** [LESSONS_LEARNED.md](../.github/skills/starter-execution/LESSONS_LEARNED.md)
- **Architecture:** [architecture.md](architecture.md)
- **Azure DevOps CLI:** [az-devops-cli-reference.md](az-devops-cli-reference.md)

---

**Last Updated:** January 2026  
**Based on:** 22+ production deployments and iterative refinement
