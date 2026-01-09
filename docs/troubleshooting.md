# Troubleshooting Guide

This guide provides solutions to common issues encountered when deploying the Azure AI Foundry Starter template.

> **Note:** This troubleshooting guide is derived from 22+ real pipeline iterations. See [LESSONS_LEARNED.md](../.github/skills/starter-execution/LESSONS_LEARNED.md) for the complete detailed history.

## 📋 Table of Contents

1. [Quick Diagnostics](#-quick-diagnostics)
2. [Authentication Issues](#-authentication-issues)
3. [Service Connection Errors](#-service-connection-errors)
4. [Pipeline Validation Failures](#-pipeline-validation-failures)
5. [Variable Configuration Issues](#-variable-configuration-issues)
6. [Permission Errors](#-permission-errors)
7. [Agent Deployment Issues](#-agent-deployment-issues)
8. [Common Error Messages](#-common-error-messages)

---

## 🔍 Quick Diagnostics

Before diving into specific issues, run these diagnostic commands:

```powershell
# Check authentication
az account show
az devops project list --organization "https://dev.azure.com/YOUR_ORG"

# Check Azure resources
az group list --query "[?starts_with(name, 'rg-')].{Name:name, Location:location}" -o table

# Check Azure DevOps resources
az devops service-endpoint list --query "[].{Name:name, Type:type, Status:isReady}" -o table
az pipelines variable-group list --query "[].{Name:name, Variables:length(variables)}" -o table
az pipelines list --query "[].{Name:name, Status:status}" -o table
```

---

## 🔐 Authentication Issues

### Issue: "Not logged in to Azure"

**Error:**
```
ERROR: Please run 'az login' to setup account.
```

**Solution:**
```powershell
# Login to Azure
az login

# Set correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify
az account show
```

---

### Issue: "Azure DevOps authentication failed"

**Error:**
```
ERROR: The token could not be resolved. Please provide a valid token.
```

**Solution:**
```powershell
# Get fresh Azure DevOps token
$env:ADO_TOKEN = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" -o tsv

$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

# Verify
az devops project list --organization "https://dev.azure.com/YOUR_ORG"
```

**Note:** Tokens expire after 60 minutes. Re-run these commands if you get authentication errors.

---

## 🔌 Service Connection Errors

### Issue: "No matching federated identity record found"

**Error:**
```
ERROR: AADSTS700211: No matching federated identity record found for presented assertion issuer.
```

**Root Cause:** The federated credential's issuer and subject don't match what Azure DevOps actually sends.

**What Azure DevOps Actually Sends:**
- **Issuer**: `https://login.microsoftonline.com/{tenantId}/v2.0` (NOT `https://vstoken.dev.azure.com/{tenantId}`)
- **Subject**: Encoded path like `/eid1/c/pub/t/.../sc/.../...` (NOT `sc://org/project/name`)

**Solution:**

**Step 1:** Get the actual issuer and subject from the service connection:
```powershell
$org = "https://dev.azure.com/YOUR_ORG"
$project = "YOUR_PROJECT"
$scName = "foundrycicd-dev"

$projectId = az devops project show --organization $org --project $project --query id -o tsv
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

$serviceConnections = Invoke-RestMethod `
    -Uri "$org/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" `
    -Headers $headers

$conn = $serviceConnections.value | Where-Object { $_.name -eq $scName }
$issuer = $conn.authorization.parameters.workloadIdentityFederationIssuer
$subject = $conn.authorization.parameters.workloadIdentityFederationSubject

Write-Host "Issuer: $issuer"
Write-Host "Subject: $subject"
```

**Step 2:** Create federated credential with the ACTUAL values:
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
```

**Best Practice:** Always create service connections FIRST, then retrieve their federation parameters, then create federated credentials.

---

### Issue: "Service connection not authorized for pipeline"

**Error:**
```
ERROR: The pipeline is not valid. Job: 'job_name': Step 'task_name' references service connection 'foundrycicd-dev' which could not be found or is not authorized for use.
```

**Solution:**
```powershell
# Authorize service connection for all pipelines
$scId = az devops service-endpoint list --query "[?name=='foundrycicd-dev'].id" -o tsv

az devops service-endpoint update --id $scId --enable-for-all true
```

---

## ⚠️ Pipeline Validation Failures

### Issue: "Service connection variable not resolved"

**Error:**
```yaml
# ❌ DOES NOT WORK
- task: AzureCLI@2
  inputs:
    azureSubscription: '$(AZURE_SERVICE_CONNECTION_DEV)'  # FAILS VALIDATION
```

**Root Cause:** The `azureSubscription` field requires literal service connection names for pipeline validation. Variables are only resolved at runtime, but validation happens before that.

**Solution:** Hardcode service connection names per stage:
```yaml
# ✅ WORKS
- stage: Dev
  variables:
    - group: 'foundrycicd-dev-vars'
  jobs:
    - deployment: DeployAgentDev
      steps:
        - task: AzureCLI@2
          inputs:
            azureSubscription: 'foundrycicd-dev'  # Hardcoded literal value
```

---

### Issue: "Variable group not found"

**Error:**
```
ERROR: Variable group 'agent-dev-vars' could not be found.
```

**Solution:** Update YAML to match the actual variable group names:
```powershell
# List actual variable groups
az pipelines variable-group list --query "[].name" -o table

# Update YAML file
(Get-Content pipeline.yml) -replace "agent-dev-vars", "foundrycicd-dev-vars" | Set-Content pipeline.yml
git add pipeline.yml
git commit -m "Fix variable group name"
git push
```

**Best Practice:** Configuration should define resource names, and YAML should be updated to match. Don't rename Azure DevOps resources to match YAML.

---

## 🔧 Variable Configuration Issues

### Issue: "ValueError: model_id must be a non-empty string"

**Error:**
```
ValueError: model_id must be a non-empty string
```

**Root Cause:** Missing `AZURE_AI_MODEL_DEPLOYMENT_NAME` variable. This is NOT documented in some official guides but IS required by the agent-framework library.

**Solution:**
```powershell
# Add to variable group
az pipelines variable-group variable create `
    --group-id <id> `
    --name "AZURE_AI_MODEL_DEPLOYMENT_NAME" `
    --value "gpt-4o" `
    --organization "https://dev.azure.com/YOUR_ORG" `
    --project "YOUR_PROJECT"
```

**Update YAML to export the variable:**
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'foundrycicd-dev'
    scriptType: 'bash'
    addSpnToEnvironment: true
    inlineScript: |
      export AZURE_AI_MODEL_DEPLOYMENT_NAME="$(AZURE_AI_MODEL_DEPLOYMENT_NAME)"
      python src/agents/createagent.py
```

**Best Practice:** Always check the source repository's `sample.env` file for ALL required environment variables.

---

### Issue: "Invalid Azure AI Project endpoint"

**Error:**
```
AttributeError: project endpoint not valid
```

**Root Cause:** Wrong endpoint format. Common mistakes:
- ❌ `https://ml.azure.com` - Portal URL, not an API endpoint
- ❌ `https://eastus.api.azureml.ms` - ML workspace API, different service

**Correct Format:**
```
https://<ai-services-resource-name>.services.ai.azure.com/api/projects/<project-name>
```

**How to Find the Correct Endpoint:**

**Method 1: Azure CLI**
```powershell
az resource show `
    --ids "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.CognitiveServices/accounts/<ai-services-resource>/projects/<project-name>" `
    --query "properties.endpoints" -o json
```

**Method 2: Azure AI Foundry Portal**
1. Go to [Azure AI Foundry](https://ai.azure.com)
2. Select your project
3. In the **Overview** section, copy the **Foundry project endpoint**

**Update Variable Group:**
```powershell
az pipelines variable-group variable update `
    --group-id <id> `
    --name "AZURE_AI_PROJECT_ENDPOINT" `
    --value "https://your-resource.services.ai.azure.com/api/projects/your-project" `
    --organization "https://dev.azure.com/YOUR_ORG" `
    --project "YOUR_PROJECT"
```

---

### Issue: "Missing environment variables"

**Error:**
```
ERROR: Environment variable AZURE_SUBSCRIPTION_ID not found
```

**Root Cause:** Trying to use pipeline variables that don't exist in variable groups.

**Solution:** Use automatic environment variables provided by Azure CLI task:

Available automatic variables when `addSpnToEnvironment: true`:
- `$servicePrincipalId` - The service principal/application ID
- `$tenantId` - The Azure AD tenant ID
- `$subscriptionId` - The Azure subscription ID

**Fixed YAML:**
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'foundrycicd-dev'
    scriptType: 'bash'
    addSpnToEnvironment: true  # ✅ Enables automatic variables
    inlineScript: |
      export AZURE_SUBSCRIPTION_ID="$subscriptionId"
      export AZURE_TENANT_ID="$tenantId"
      export AZURE_CLIENT_ID="$servicePrincipalId"
      python src/agents/createagent.py
```

---

## 🔒 Permission Errors

### Issue: "PermissionDenied: Data action not allowed"

**Error:**
```
PermissionDenied: The principal lacks the required data action:
Microsoft.CognitiveServices/accounts/AIServices/agents/write
```

**Root Cause:** Service Principal lacks data plane permissions on AI Services resource.

**Solution:** Grant 'Cognitive Services User' role to Service Principal:
```powershell
$spObjectId = az ad sp show --id <app-id> --query id -o tsv
$aiResource = "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.CognitiveServices/accounts/<resource-name>"

az role assignment create `
    --assignee $spObjectId `
    --role "Cognitive Services User" `
    --scope $aiResource
```

**Required for all environments:**
- DEV Service Principal → Cognitive Services User on DEV AI Services
- TEST Service Principal → Cognitive Services User on TEST AI Services  
- PROD Service Principal → Cognitive Services User on PROD AI Services

**Key Insight:** Control plane (Azure Resource Manager) and data plane (AI Services) permissions are separate. Federated auth grants ARM access but NOT data plane access.

---

### Issue: "403 Forbidden when accessing resources"

**Error:**
```
ERROR: The client '...' with object id '...' does not have authorization to perform action 'Microsoft.Resources/subscriptions/resourceGroups/read'
```

**Solution:** Assign Contributor role to Service Principal:
```powershell
$spId = az ad sp list --display-name "sp-foundrycicd-cicd" --query "[0].id" -o tsv

az role assignment create `
    --assignee $spId `
    --role "Contributor" `
    --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>"
```

---

## 🤖 Agent Deployment Issues

### Issue: "Agent not visible via REST API"

**Problem:** Agent created successfully (visible in portal) but REST API returns empty array.

**Explanation:** Agent-framework SDK creates **persistent agents** that appear in the Azure AI Foundry portal, but they may use a different storage mechanism than the standard OpenAI Assistants API.

**Verification Methods:**

**✅ Method 1: Azure AI Foundry Portal (Most Reliable)**
1. Navigate to [https://ai.azure.com](https://ai.azure.com)
2. Select your project
3. Go to "Agents" section
4. Agent should be visible with name, version, and type

**Method 2: Pipeline Logs**
- Check stage completion status
- Look for agent response output
- Successful execution = agent created

**Validation Checklist:**
- ✅ Pipeline stage completes with "succeeded" status
- ✅ Agent responds to test query in logs
- ✅ Agent visible in Azure AI Foundry Portal

**Note:** Portal visibility is the authoritative source for agent existence.

---

## 📋 Common Error Messages

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `AADSTS700211: No matching federated identity record found` | Federated credential issuer/subject mismatch | Retrieve actual issuer/subject from service connection, recreate federated credential |
| `service connection $(VAR) could not be found` | Variable used in azureSubscription field | Hardcode service connection name in YAML |
| `Variable group X could not be found` | Wrong variable group name in YAML | Update YAML group name to match created variable group |
| `service connection has not been authorized` | Service connection not authorized for pipeline | Authorize service connection: `az devops service-endpoint update --enable-for-all true` |
| `No hosted parallelism has been purchased` | Azure DevOps org limitation | Request free grant or purchase parallelism |
| `ValueError: model_id must be a non-empty string` | Missing AZURE_AI_MODEL_DEPLOYMENT_NAME | Add variable to variable group |
| `PermissionDenied: data action not allowed` | Missing Cognitive Services User role | Grant role: `az role assignment create --role "Cognitive Services User"` |
| `[Errno 2] No such file or directory` | File paths in YAML don't match structure | Update Python file references (e.g., `src/agents/createagent.py`) |

---

## 🔄 General Troubleshooting Workflow

1. **Check Validation Results First:**
   ```powershell
   az pipelines runs show --id <run-id> --query "validationResults" -o json
   ```
   Fix YAML/configuration issues before worrying about execution errors.

2. **Verify Resources Exist:**
   - Service connections: `az devops service-endpoint list -o table`
   - Variable groups: `az pipelines variable-group list -o table`
   - Environments: `az pipelines environment list -o table`

3. **Check Permissions:**
   - Service Principal roles: `az role assignment list --assignee <sp-id> -o table`
   - Federated credentials: `az ad app federated-credential list --id <app-id> -o table`

4. **Review Pipeline Logs:**
   - Go to Azure DevOps → Pipelines → Select run → View logs
   - Look for the first error message (subsequent errors are often cascading)

5. **Fix One Issue at a Time:**
   - Make a single change
   - Commit and push
   - Re-run pipeline
   - Verify the specific issue is resolved

---

## 📚 Additional Resources

- **Complete History:** [LESSONS_LEARNED.md](../.github/skills/starter-execution/LESSONS_LEARNED.md)
- **Setup Guide:** [SETUP_GUIDE.md](../SETUP_GUIDE.md)
- **Architecture:** [architecture.md](architecture.md)
- **Azure DevOps CLI Reference:** [az-devops-cli-reference.md](az-devops-cli-reference.md)

---

## 💡 Best Practices

1. **Update YAML, Don't Update Infrastructure:** YAML is code (flexible), Azure DevOps resources are infrastructure (rigid).

2. **Validate Incrementally:** After each change, validate before proceeding.

3. **Use Literal Values in Task Fields:** Pipeline task fields like `azureSubscription` require literal values for validation.

4. **Create Service Connections First:** Always create service connections before federated credentials.

5. **Check sample.env:** Use the application's environment file as the source of truth for required variables.

6. **Grant Both Permissions:** Remember to grant both control plane (Contributor) and data plane (Cognitive Services User) permissions.

---

**Last Updated:** January 2026  
**Based on:** 22+ real pipeline iterations and production deployments
