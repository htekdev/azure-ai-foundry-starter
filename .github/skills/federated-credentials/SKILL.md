---
name: federated-credentials
description: Manages federated credentials for Azure DevOps service connections using Workload Identity Federation. Retrieves actual issuer/subject from service connections and creates/updates federated credentials on Service Principals.
---

# Federated Credentials Management for Azure DevOps Service Connections

This skill manages the creation and update of federated credentials for Azure DevOps service connections that use Workload Identity Federation (no secrets). It ensures credentials use the correct issuer and subject format retrieved directly from Azure DevOps.

## When to use this skill

Use this skill when you need to:
- Create federated credentials for new service connections
- Fix federated credentials with incorrect issuer/subject format
- Update federated credentials after service connection changes
- Troubleshoot authentication failures in pipelines
- Implement Lesson #1 from LESSONS_LEARNED.md

## Critical Lesson: Federated Credential Format

**NEVER** guess or construct the issuer/subject format manually. Always retrieve the actual values from Azure DevOps service connections.

### ❌ WRONG - Guessed format (will fail):
```
issuer: https://vstoken.dev.azure.com/{tenantId}
subject: sc://{org}/{project}/{serviceConnectionName}
```

### ✅ CORRECT - Retrieved from Azure DevOps:
```
issuer: https://login.microsoftonline.com/{tenantId}/v2.0
subject: /eid1/c/pub/t/{encodedTenantId}/a/{encodedAppId}/sc/{projectId}/{serviceConnectionId}
```

## Prerequisites

Before running this skill:
1. Configuration file exists: `starter-config.json`
2. Azure DevOps service connections created
3. Service Principal exists with appropriate permissions
4. Azure CLI authenticated: `az login`
5. Azure DevOps CLI extension installed
6. Azure DevOps bearer token available

## Quick Start

### Fix all federated credentials

```powershell
# Fix federated credentials for all environments
./.github/skills/federated-credentials/fix-federated-credentials.ps1

# Or with specific environments
./.github/skills/federated-credentials/fix-federated-credentials.ps1 -Environments @("dev", "test")
```

### Manual step-by-step process

If you need to understand the process or troubleshoot:

#### Step 1: Retrieve service connection details

```powershell
# Set up authentication
$org = "https://dev.azure.com/{your-org}"
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv

# Get project ID
$projectId = az devops project show --project "{your-project}" --organization $org --query id -o tsv

# Get service connections with federation details
$serviceConnections = Invoke-RestMethod `
    -Uri "$org/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" `
    -Headers @{ Authorization = "Bearer $env:ADO_TOKEN" } `
    -Method Get

# Display connection details
$serviceConnections.value | ForEach-Object {
    Write-Host "Name: $($_.name)"
    Write-Host "ID: $($_.id)"
    Write-Host "Issuer: $($_.authorization.parameters.workloadIdentityFederationIssuer)"
    Write-Host "Subject: $($_.authorization.parameters.workloadIdentityFederationSubject)"
    Write-Host "---"
}
```

#### Step 2: Delete old federated credentials

```powershell
# Load configuration
$config = Get-Content .\starter-config.json | ConvertFrom-Json
$spAppId = $config.servicePrincipal.appId

# Delete old credential (for each environment)
az ad app federated-credential delete `
    --id $spAppId `
    --federated-credential-id "azure-foundry-dev"
```

#### Step 3: Create new federated credentials

```powershell
# Create credential JSON file
$credJson = @{
    name = "azure-foundry-dev"
    issuer = "https://login.microsoftonline.com/{tenantId}/v2.0"  # From Step 1
    subject = "/eid1/c/pub/t/.../sc/{serviceConnectionId}"  # From Step 1
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 10

$credJson | Out-File -FilePath "cred-dev.json" -Encoding UTF8

# Create federated credential
az ad app federated-credential create `
    --id $spAppId `
    --parameters "cred-dev.json"

# Clean up
Remove-Item "cred-dev.json"
```

#### Step 4: Verify credentials

```powershell
# List all federated credentials for the Service Principal
az ad app federated-credential list --id $spAppId --query "[].{Name:name, Issuer:issuer, Subject:subject}" -o table
```

## Common Issues and Solutions

### Issue 1: Empty service connection properties

**Symptom**: REST API returns service connections but name/ID are empty strings.

**Solution**: Token expired. Refresh bearer token:
```powershell
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
```

### Issue 2: "argument --id: expected one argument"

**Symptom**: Error when running `az ad app federated-credential create` with inline JSON.

**Solution**: Use JSON file instead of inline parameters:
```powershell
# Create JSON file first
$credJson | Out-File -FilePath "cred.json" -Encoding UTF8

# Then use file path
az ad app federated-credential create --id $spAppId --parameters "cred.json"
```

### Issue 3: Pipeline authentication still fails after fixing credentials

**Symptom**: Pipeline fails with authentication error even after federated credentials are fixed.

**Solution**: Check RBAC permissions. Service Principal needs both control plane and data plane roles:
```powershell
# Control plane (already has Contributor)
az role assignment list --assignee $spAppId --scope "/subscriptions/{subId}/resourceGroups/{rg}"

# Data plane - ADD THIS
az role assignment create `
    --assignee $spAppId `
    --role "Cognitive Services User" `
    --scope "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.CognitiveServices/accounts/{resourceName}"
```

See LESSONS_LEARNED.md #11 for details.

### Issue 4: Credential exists but wrong format

**Symptom**: Federated credential exists but has guessed issuer/subject format.

**Solution**: Delete and recreate with correct values from Azure DevOps:
```powershell
# Delete
az ad app federated-credential delete --id $spAppId --federated-credential-id "azure-foundry-dev"

# Recreate with correct values (from Step 1)
az ad app federated-credential create --id $spAppId --parameters "cred-dev.json"
```

## Output

When successful, you'll see:
- Federated credentials deleted (if they existed)
- New credentials created with correct issuer/subject format
- Verification showing all credentials with proper formatting

Example output:
```json
{
  "audiences": ["api://AzureADTokenExchange"],
  "id": "a7e3a90c-0fd1-41f6-a622-2052d7a7a092",
  "issuer": "https://login.microsoftonline.com/16b3c013-d300-468d-ac64-7eda0820b6d3/v2.0",
  "name": "azure-foundry-dev",
  "subject": "/eid1/c/pub/t/E8CzFgDTjUasZH7aCCC20w/a/rISbSSETf0KqFyZ8ppdXmA/sc/cc675aa2-a9f1-4091-9600-8fd083925744/259270a3-61be-4f9c-aee0-14478327844e"
}
```

## Architecture Notes

### Why Workload Identity Federation?

- **No secrets**: No service principal passwords or certificates to manage
- **Automatic rotation**: Azure DevOps and Azure AD handle token exchange
- **Audit trail**: All authentication attempts logged in Azure AD
- **Principle of least privilege**: Credentials scoped to specific service connections

### How it works

1. Pipeline requests token from Azure DevOps
2. Azure DevOps issues token with service connection subject
3. Pipeline presents token to Azure AD
4. Azure AD validates token against federated credential
5. Azure AD issues Azure access token to pipeline
6. Pipeline uses access token to deploy resources

### Security benefits

- No credentials in code or variable groups
- No credential expiration issues
- Service connection automatically revoked if deleted
- Per-environment credential isolation

## Related Skills

- **configuration-management**: Load configuration for this skill
- **starter-execution**: Creates service connections that need federated credentials
- **environment-validation**: Validates authentication including federated credentials

## Related Documentation

- [LESSONS_LEARNED.md](../../../docs/LESSONS_LEARNED.md) - Lesson #1: Federated credential format
- [troubleshooting.md](../../../docs/troubleshooting.md) - Authentication troubleshooting
- [Azure DevOps Workload Identity Federation](https://learn.microsoft.com/azure/devops/pipelines/library/connect-to-azure)

## Success Criteria

Federated credentials are correctly configured when:
- ✅ All service connections have corresponding federated credentials
- ✅ Issuer format is `https://login.microsoftonline.com/{tenantId}/v2.0`
- ✅ Subject format is `/eid1/c/pub/t/.../sc/{serviceConnectionId}`
- ✅ Audiences is `["api://AzureADTokenExchange"]`
- ✅ Pipeline can authenticate to Azure without errors
- ✅ No secrets or passwords stored anywhere
