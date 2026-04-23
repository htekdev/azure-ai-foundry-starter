# Troubleshooting Guide

This guide documents real issues encountered during Azure AI Foundry deployments and their solutions. Content is drawn from production deployment experience across 22 pipeline iterations.

## Table of Contents

1. [Federated Credential Issuer/Subject Mismatch](#1-federated-credential-issuersubject-mismatch)
2. [Pipeline YAML Variable References in azureSubscription](#2-pipeline-yaml-variable-references-in-azuresubscription)
3. [Variable Group Naming Mismatch](#3-variable-group-naming-mismatch)
4. [Service Connection Not Authorized for Pipeline](#4-service-connection-not-authorized-for-pipeline)
5. [Variable Group Update Failures](#5-variable-group-update-failures)
6. [Multiple azureSubscription References Not Replaced](#6-multiple-azuresubscription-references-not-replaced)
7. [Missing Azure CLI Task Environment Variables](#7-missing-azure-cli-task-environment-variables)
8. [File Copy and Path Mistakes](#8-file-copy-and-path-mistakes)
9. [Incorrect AZURE_AI_PROJECT Endpoint Value](#9-incorrect-azure_ai_project-endpoint-value)
10. [Missing AZURE_AI_MODEL_DEPLOYMENT_NAME Variable](#10-missing-azure_ai_model_deployment_name-variable)
11. [Missing RBAC Permissions on AI Services Resource](#11-missing-rbac-permissions-on-ai-services-resource)
12. [Agent Verification and Portal vs API Discrepancy](#12-agent-verification-and-portal-vs-api-discrepancy)

---

## Quick Reference: Common Errors

| Error Message | Likely Cause | Jump To |
|---|---|---|
| `AADSTS700211: No matching federated identity record found` | Federated credential issuer/subject mismatch | [#1](#1-federated-credential-issuersubject-mismatch) |
| `service connection $(VAR) could not be found` | Variable used in `azureSubscription` field | [#2](#2-pipeline-yaml-variable-references-in-azuresubscription) |
| `Variable group X could not be found` | Wrong variable group name in YAML | [#3](#3-variable-group-naming-mismatch) |
| `service connection has not been authorized` | Service connection not authorized for pipeline | [#4](#4-service-connection-not-authorized-for-pipeline) |
| `Project information name is not valid for variable group` | Trying to update variable group with read-only fields | [#5](#5-variable-group-update-failures) |
| `[Errno 2] No such file or directory: 'script.py'` | File paths in YAML don't match repository structure | [#8](#8-file-copy-and-path-mistakes) |
| `ValueError: model_id must be a non-empty string` | Wrong AI project endpoint or missing model variable | [#9](#9-incorrect-azure_ai_project-endpoint-value), [#10](#10-missing-azure_ai_model_deployment_name-variable) |
| `PermissionDenied: lacks required data action ...agents/write` | Missing data plane RBAC on AI Services | [#11](#11-missing-rbac-permissions-on-ai-services-resource) |

---

## 1. Federated Credential Issuer/Subject Mismatch

**Severity:** 🔴 Critical

### Symptoms
Pipeline authentication fails immediately with:
```
ERROR: AADSTS700211: No matching federated identity record found for presented assertion issuer.
```

### Root Cause
Azure DevOps service connections use a different issuer and subject format than expected. The actual values are generated at service connection creation time and cannot be predicted in advance.

**What you might configure (wrong):**
```json
{
  "issuer": "https://vstoken.dev.azure.com/16b3c013-d300-468d-ac64-7eda0820b6d3",
  "subject": "sc://my-org/my-project/azure-foundry-dev"
}
```

**What Azure DevOps actually sends:**
```json
{
  "issuer": "https://login.microsoftonline.com/16b3c013-d300-468d-ac64-7eda0820b6d3/v2.0",
  "subject": "/eid1/c/pub/t/E8CzFgDTjUasZH7aCCC20w/a/rISbSSETf0KqFyZ8ppdXmA/sc/d5106ca9-0bc1-43d4-8696-0c69b4b62550/6a1d0b70-31d6-47a7-b105-81fb42da4b30"
}
```

### Solution

1. **Create the service connection first** (via REST API — see [#4](#4-service-connection-not-authorized-for-pipeline) for why not to use CLI).
2. **Retrieve the actual issuer and subject** from the created service connection:

```powershell
$projectId = (az devops project show --organization $org --project $project --query id -o tsv)
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$serviceConnections = Invoke-RestMethod -Uri "$org/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" -Headers $headers

$conn = $serviceConnections.value | Where-Object { $_.name -eq 'azure-foundry-dev' }
Write-Host "Issuer: $($conn.authorization.parameters.workloadIdentityFederationIssuer)"
Write-Host "Subject: $($conn.authorization.parameters.workloadIdentityFederationSubject)"
```

3. **Create the federated credential** using the actual values:

```powershell
$fedCred = @{
    name     = "AzureDevOps-azure-foundry-dev"
    issuer   = $conn.authorization.parameters.workloadIdentityFederationIssuer
    subject  = $conn.authorization.parameters.workloadIdentityFederationSubject
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json

$fedCred | Out-File -FilePath "$env:TEMP\fed-cred.json" -Encoding utf8
az ad app federated-credential create --id $spAppId --parameters "$env:TEMP\fed-cred.json"
```

### Prevention
- Always create service connections **before** federated credentials.
- Never hardcode issuer/subject values — always retrieve them from the created service connection.
- The `federated-credentials` skill automates this retrieval process.

---

## 2. Pipeline YAML Variable References in azureSubscription

**Severity:** 🔴 Critical

### Symptoms
Pipeline validation fails immediately (before the pipeline even runs):
```
The service connection '$(AZURE_SERVICE_CONNECTION_DEV)' could not be found.
```

### Root Cause
The `azureSubscription` field in pipeline YAML is validated **at queue time**, before variable groups are loaded at runtime. Runtime variables from variable groups cannot be used here.

```yaml
# ❌ DOES NOT WORK - Variable not resolved at validation time
- task: AzureCLI@2
  inputs:
    azureSubscription: '$(AZURE_SERVICE_CONNECTION_DEV)'  # FAILS VALIDATION
```

### Solution
Hardcode the service connection name per stage:

```yaml
# ✅ WORKS - Literal service connection name
- stage: Dev
  variables:
    - group: 'my-project-dev-vars'
  jobs:
    - deployment: DeployAgentDev
      steps:
        - task: AzureCLI@2
          inputs:
            azureSubscription: 'azure-foundry-dev'  # Hardcoded per stage
```

Each stage references its own service connection:
- Dev stage → `azure-foundry-dev`
- Test stage → `azure-foundry-test`
- Production stage → `azure-foundry-prod`

### Prevention
- When configuring pipeline YAML, always use literal service connection names in `azureSubscription`.
- The `pipeline-setup` skill generates YAML with hardcoded service connection names automatically.

---

## 3. Variable Group Naming Mismatch

**Severity:** 🟠 High

### Symptoms
Pipeline validation fails with:
```
Variable group 'my-project-dev-vars' could not be found in the project.
```

### Root Cause
Pipeline YAML references a variable group name that doesn't match what was created in Azure DevOps. This often happens when infrastructure was created with names derived from `config.naming.projectName` but the YAML was written with a different placeholder.

### Solution
The `pipeline-setup` skill automatically updates YAML to match created infrastructure:

```powershell
# Update variable group name placeholders with the actual projectName from config
(Get-Content pipeline.yml) -replace "REPLACE_WITH_YOUR_PROJECTNAME", $projectName | Set-Content pipeline.yml
```

To manually fix, update your pipeline YAML to reference the exact variable group names created:
```yaml
variables:
  - group: 'my-project-dev-vars'    # Must match exactly
```

Verify the variable group names in Azure DevOps:
```powershell
az pipelines variable-group list --organization $org --project $project --query "[].name" -o tsv
```

### Prevention
- Configuration management (`starter-config.json`) defines `naming.projectName`.
- Pipeline YAML uses `{projectName}-dev-vars`, `{projectName}-test-vars`, `{projectName}-prod-vars`.
- Always run `pipeline-setup` after infrastructure setup so names are synchronized.

---

## 4. Service Connection Not Authorized for Pipeline

**Severity:** 🟠 High

### Symptoms
Pipeline starts but immediately fails with:
```
##[error] The service connection 'azure-foundry-dev' has not been authorized for use.
```

### Root Cause
Creating a service connection does not automatically authorize it for use with pipelines. This is a separate step that must be explicitly performed.

### Solution
After creating pipelines, authorize each service connection:

```powershell
$body = @{
    allPipelines = $false
    authorized   = $true
    pipelines    = @(@{ id = $pipelineId; authorized = $true })
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "$org/$projectId/_apis/pipelines/pipelinePermissions/endpoint/$scId/?api-version=7.1-preview.1" `
    -Headers $headers -Method Patch -Body $body
```

The `pipeline-setup` skill performs this authorization automatically after creating pipelines.

### Prevention
- Always authorize service connections after pipeline creation, before the first run.
- Do not use the "Allow all pipelines" option in production — always authorize explicitly.

---

## 5. Variable Group Update Failures

**Severity:** 🟡 Medium

### Symptoms
REST API calls to update a variable group fail with:
```
Project information name is not valid for variable group
```
or other cryptic errors when trying to add/update variables via `PUT` or `PATCH`.

### Root Cause
Variable group objects retrieved from the API contain read-only properties that cannot be sent back. Attempting to modify the retrieved object and PUT it back causes validation failures.

```powershell
# ❌ This fails - the retrieved object has read-only fields
$devGroup.variables | Add-Member -NotePropertyName "NEW_VAR" -NotePropertyValue @{ value = "test" }
Invoke-RestMethod -Uri "..." -Method Put -Body ($devGroup | ConvertTo-Json)
```

### Solution
**Preferred approach:** Fix the YAML to use variables that already exist. Infrastructure should be created once and correctly; YAML is code that can be updated.

**If you must update a variable group**, add individual variables via the CLI:
```powershell
az pipelines variable-group variable create `
    --group-id <id> `
    --name "NEW_VAR" `
    --value "my-value" `
    --organization $org `
    --project $project
```

### Prevention
- Plan your variable group contents before creation and include all required variables upfront.
- Reference `sample.env` to identify all required variables before creating groups.
- Update YAML to match existing infrastructure rather than trying to modify infrastructure to match YAML.

---

## 6. Multiple azureSubscription References Not Replaced

**Severity:** 🟡 Medium

### Symptoms
After running a replacement script, some `azureSubscription` fields still contain old or variable values. The pipeline partially works but fails on certain stages.

### Root Cause
Regex replacements with overly complex patterns fail to match all occurrences in multi-stage YAML files.

```powershell
# ❌ This only replaced SOME occurrences
$content -replace "(?ms)(- stage: Dev.*?)(azureSubscription.*)", "`$1new-value"
```

### Solution
Use simple, global string replacements after verifying the pattern:

```powershell
# Step 1: Find all occurrences first
Get-Content pipeline.yml | Select-String -Pattern "azureSubscription"

# Step 2: Simple global replacement
(Get-Content pipeline.yml) -replace "azureSubscription: '\$\(AZURE_SERVICE_CONNECTION_DEV\)'", "azureSubscription: 'azure-foundry-dev'" | Set-Content pipeline.yml

# Step 3: Verify all were replaced
Get-Content pipeline.yml | Select-String -Pattern "azureSubscription"
```

### Prevention
- Verify replacements with grep/Select-String after applying them.
- Use the `pipeline-setup` skill which handles all replacements automatically.

---

## 7. Missing Azure CLI Task Environment Variables

**Severity:** 🟡 Medium

### Symptoms
Pipeline runs but agent script fails because expected environment variables are empty:
```
command not found: AZURE_SUBSCRIPTION_ID
Error: Environment variable AZURE_TENANT_ID is not set
```

### Root Cause
The pipeline YAML tries to export variables that don't exist in the variable group, using `$(VARIABLE_NAME)` syntax for values that should come from the Azure CLI task's built-in automatic variables.

```yaml
# ❌ These pipeline variables don't exist in the variable group
inlineScript: |
  export AZURE_SUBSCRIPTION_ID="$(AZURE_SUBSCRIPTION_ID)"  # Not in variable group
  export AZURE_TENANT_ID="$(AZURE_TENANT_ID)"              # Not in variable group
```

### Solution
Use the automatic environment variables provided by the Azure CLI task when `addSpnToEnvironment: true` is set:

```yaml
# ✅ Use automatic variables provided by the AzureCLI task
- task: AzureCLI@2
  inputs:
    azureSubscription: 'azure-foundry-dev'
    scriptType: 'bash'
    addSpnToEnvironment: true   # Enables automatic variables
    inlineScript: |
      export AZURE_SUBSCRIPTION_ID="$subscriptionId"    # From task
      export AZURE_TENANT_ID="$tenantId"               # From task
      export AZURE_CLIENT_ID="$servicePrincipalId"     # From task
```

Available automatic variables (when `addSpnToEnvironment: true`):
- `$servicePrincipalId` — The service principal / application ID
- `$tenantId` — The Azure AD tenant ID
- `$subscriptionId` — The Azure subscription ID
- `$servicePrincipalKey` — The SP key (not used with federated auth)

### Prevention
- Always set `addSpnToEnvironment: true` on `AzureCLI@2` tasks.
- Do not create `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, or `AZURE_CLIENT_ID` in variable groups — these are provided automatically.

---

## 8. File Copy and Path Mistakes

**Severity:** 🟡 Medium

### Symptoms
Pipeline agent execution fails with:
```
[Errno 2] No such file or directory: 'src/agents/my_agent.py'
```
or the wrong files are committed to the repository.

### Root Cause
Files were copied to incorrect locations, or pipeline YAML references paths that don't match the actual repository structure.

### Solution
1. Use explicit source and destination paths when copying:

```powershell
Copy-Item ..\source-repo\*.py src\agents\
Copy-Item ..\source-repo\cicd\*.yml .azure-pipelines\
```

2. Verify each copy before committing:

```powershell
Get-ChildItem src\agents\
Get-ChildItem .azure-pipelines\
```

3. After reorganizing, update all YAML file references:

```yaml
# ✅ Updated path matching reorganized structure
inlineScript: |
  python src/agents/my_agent.py
```

### Prevention
- Treat source repositories as read-only — all reorganization happens in the target directory.
- Verify file paths in YAML match the actual directory structure before pushing.
- Use the `repository-setup` skill which sets up the correct structure automatically.

---

## 9. Incorrect AZURE_AI_PROJECT Endpoint Value

**Severity:** 🔴 Critical

### Symptoms
```
ValueError: model_id must be a non-empty string
AttributeError: project endpoint not valid
```

### Root Cause
The `AZURE_AI_PROJECT` variable is set to a portal URL or ML workspace endpoint instead of the AI Foundry project API endpoint. Multiple incorrect endpoint formats exist:

| Endpoint | Status | Notes |
|---|---|---|
| `https://ml.azure.com` | ❌ Wrong | Portal URL, not an API endpoint |
| `https://eastus.api.azureml.ms` | ❌ Wrong | Azure ML workspace API, different service |
| `https://<workspace>.api.azureml.ms/discovery` | ❌ Wrong | ML workspace discovery endpoint |
| `https://<resource>.services.ai.azure.com/api/projects/<project>` | ✅ Correct | AI Foundry project endpoint |

### Solution
Find the correct endpoint using one of these methods:

**Method 1: Azure CLI**
```powershell
az resource show \
  --ids "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<ai-services-resource>/projects/<project-name>" \
  --query "properties.endpoints.['AI Foundry API']" \
  -o tsv
```

**Method 2: Azure AI Foundry Portal**
1. Go to [https://ai.azure.com](https://ai.azure.com)
2. Select your project
3. In the **Overview** section, copy the **Foundry project endpoint**

The correct format is:
```
https://<ai-services-resource-name>.services.ai.azure.com/api/projects/<project-name>
```

Update the variable group with the correct value:
```powershell
az pipelines variable-group variable update \
    --group-id <id> \
    --name "AZURE_AI_PROJECT" \
    --value "https://<resource>.services.ai.azure.com/api/projects/<project>" \
    --organization $org \
    --project $project
```

### Prevention
- Always retrieve the endpoint from the Azure AI Foundry portal or CLI after resource creation.
- The `ai-foundry-resources` skill stores the correct endpoint in `starter-config.json` automatically.

---

## 10. Missing AZURE_AI_MODEL_DEPLOYMENT_NAME Variable

**Severity:** 🔴 Critical

### Symptoms
```
ValueError: model_id must be a non-empty string
```

### Root Cause
The official Azure DevOps CI/CD guide is incomplete — it does not document `AZURE_AI_MODEL_DEPLOYMENT_NAME`, which is required by the agent-framework library. This variable is listed in `sample.env` but missing from the official pipeline documentation.

**Variables in official guide** (incomplete):
```
AZURE_AI_PROJECT_DEV
AZURE_OPENAI_ENDPOINT_DEV
AZURE_OPENAI_KEY_DEV
AZURE_OPENAI_API_VERSION_DEV
AZURE_OPENAI_DEPLOYMENT_DEV
```

**Variables actually required** (from `sample.env`):
```
AZURE_AI_PROJECT
AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_DEPLOYMENT
AZURE_AI_MODEL_DEPLOYMENT_NAME          ⚠️ Missing from official guide
AZURE_AI_PROJECT_ENDPOINT
AZURE_OPENAI_API_VERSION
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME       (optional, for some scenarios)
AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME  (optional, for some scenarios)
```

### Solution
Add the missing variable to all environment variable groups:

```powershell
az pipelines variable-group variable create \
    --group-id <id> \
    --name "AZURE_AI_MODEL_DEPLOYMENT_NAME" \
    --value "gpt-4o" \
    --organization $org \
    --project $project
```

Add the export to pipeline YAML:
```yaml
inlineScript: |
  export AZURE_AI_MODEL_DEPLOYMENT_NAME="$(AZURE_AI_MODEL_DEPLOYMENT_NAME)"
```

### Prevention
- Always cross-reference `sample.env` in the source repository against any official documentation.
- Use `sample.env` as the **source of truth** for required environment variables.
- Add all variables from `sample.env` to variable groups, even if not mentioned in official guides.

---

## 11. Missing RBAC Permissions on AI Services Resource

**Severity:** 🔴 Critical

### Symptoms
Service Principal authentication succeeds (federated credentials work) but agent creation fails:
```
PermissionDenied: The principal lacks the required data action
Microsoft.CognitiveServices/accounts/AIServices/agents/write
```

### Root Cause
Federated authentication grants access to the **Azure Resource Manager (control plane)**, but AI Services operations such as creating agents require separate **data plane RBAC** permissions. These are two distinct permission layers.

### Solution
Grant the `Cognitive Services User` role to each Service Principal on the AI Services resource:

```powershell
$spObjectId = (az ad sp show --id <app-id> --query id -o tsv)
$aiResource = '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<resource>'
az role assignment create --assignee $spObjectId --role 'Cognitive Services User' --scope $aiResource
```

Repeat for all environments:
- DEV Service Principal → `Cognitive Services User`
- TEST Service Principal → `Cognitive Services User`
- PROD Service Principal → `Cognitive Services User`

### Prevention
- Grant RBAC permissions immediately after creating Service Principals, before creating federated credentials.
- The `resource-creation` and `service-principal` skills assign both Contributor (control plane) and Cognitive Services User (data plane) roles automatically.

---

## 12. Agent Verification and Portal vs API Discrepancy

**Severity:** 🟢 Low (informational)

### Symptoms
Pipeline run succeeds, but a REST API query to `/assistants` returns an empty array even though the portal shows the agent.

### Root Cause
The agent-framework SDK creates **persistent agents** that are stored differently from those created via the standard Assistants REST API. Portal visibility is the authoritative source; the REST API endpoint may use a different storage mechanism.

### Solution / Verification

**Method 1: Azure AI Foundry Portal (most reliable)**
1. Go to [https://ai.azure.com](https://ai.azure.com)
2. Select your project
3. Click **Agents** in the left navigation
4. Verify the agent appears with the correct name, version, and type

**Method 2: REST API**
```powershell
$projectEndpoint = "https://<resource>.services.ai.azure.com/api/projects/<project>"
$token = az account get-access-token --resource "https://ai.azure.com" --query accessToken -o tsv
$agents = Invoke-RestMethod `
    -Uri "$projectEndpoint/assistants?api-version=2025-05-01" `
    -Headers @{Authorization = "Bearer $token"}
```
> **Note:** This may return an empty array for agent-framework agents. An empty result does NOT mean the agent failed to create.

**Method 3: Pipeline logs**
- Check that each DEV/TEST/PROD stage completed with status `succeeded`
- Look for the agent's response to the test query in the stage logs

**Validation checklist:**
- ✅ Pipeline stage completes with status `succeeded`
- ✅ Agent responds to test query in logs
- ✅ Agent visible in Azure AI Foundry Portal
- ✅ Agent shows correct name, version, and type

### Prevention
- Do not rely solely on the REST API `/assistants` endpoint for agent verification.
- Always confirm agent existence via the Azure AI Foundry Portal.

---

## General Best Practices

### Infrastructure vs YAML
**Golden Rule:** Infrastructure is rigid; YAML is flexible. When there's a mismatch, update the YAML.

- Create infrastructure resources once with clear, consistent names
- Update YAML to reference those exact names
- Never try to rename Azure DevOps resources to match YAML

### Correct Setup Order

1. Create Service Principals (one per environment)
2. Create service connections via REST API (not Azure CLI)
3. Retrieve actual issuer/subject from each service connection
4. Create federated credentials with the ACTUAL values from step 3
5. Grant RBAC: Contributor + Cognitive Services User on each SP
6. Create variable groups with ALL required variables (cross-reference `sample.env`)
7. Update YAML: hardcoded service connections, correct paths, automatic variables
8. Authorize service connections for pipelines
9. Commit, push, and validate pipeline
10. Fix validation errors (YAML issues) before addressing execution errors

### Debugging Pipeline Failures

Two categories of pipeline failures require different fixes:

**Validation errors** (fail immediately on queue):
- Service connection not found
- Variable group not found
- YAML syntax errors
- Missing required fields
- Check with: `az pipelines runs show --id <X> --query "validationResults"`

**Execution errors** (fail during run):
- Code bugs
- Missing environment variables
- Permission issues
- No parallelism grant

Always fix validation errors first — the pipeline cannot run until they are resolved.

### Bearer Token Usage

```powershell
# Get token
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv

# Use for REST API calls
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

# Use for Git operations
git config http.extraheader "Authorization: Bearer $token"
git push
git config --unset http.extraheader  # ALWAYS clean up after use
```

> **Security:** Always unset the git config after use to prevent token leakage.

---

## Additional Resources

- [LESSONS_LEARNED.md](../.github/skills/starter-execution/LESSONS_LEARNED.md) — Full deployment lessons with detailed context
- [deployment-guide.md](deployment-guide.md) — Step-by-step deployment instructions
- [quick-start.md](quick-start.md) — Getting started guide
- [azure-devops-cicd-reference.md](azure-devops-cicd-reference.md) — Azure DevOps CI/CD reference
