---
name: service-connection-setup
description: Creates Azure DevOps service connections with Workload Identity Federation (no secrets!) and configures federated credentials for the Service Principal. This skill sets up secure authentication between Azure DevOps and Azure using OpenID Connect.
---

# Service Connection Setup for Azure AI Foundry

This skill handles **creating Azure DevOps service connections** with **Workload Identity Federation** and configuring the required **federated credentials** on the Service Principal.

## When to use this skill

Use this skill when you need to:
- Create service connections for Azure DevOps pipelines
- Configure Workload Identity Federation (passwordless authentication)
- Set up federated credentials on the Service Principal
- Enable secure Azure resource access from pipelines

## Prerequisites

Before using this skill, ensure:
- ✅ Configuration loaded (use `configuration-management` skill first)
- ✅ Service Principal created with Azure resources (use `resource-creation` skill)
- ✅ Azure DevOps authentication configured (bearer token set)
- ✅ Azure DevOps repository exists (use `repository-setup` skill)

## What This Skill Creates

- **3 Service Connections** (one per environment: dev, test, prod)
- **Workload Identity Federation** configuration (no secrets/passwords!)
- **3 Federated Credentials** on the Service Principal
- **Authorization** for pipelines to use the service connections

## Understanding Workload Identity Federation

**Why this matters:**
- ✅ **No secrets** - No passwords or service principal keys to manage
- ✅ **More secure** - Uses short-lived tokens issued by Azure DevOps
- ✅ **No rotation** - No need to rotate credentials
- ✅ **Automatic** - Azure AD validates the trust relationship

**How it works:**
1. Azure DevOps issues an OIDC token when a pipeline runs
2. The token includes claims about the organization, project, and service connection
3. Azure AD validates the token against the federated credential
4. If valid, Azure AD issues an access token for Azure resources

## Step-by-step execution

### Step 1: Load Configuration

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Extract values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$spAppId = $config.servicePrincipal.appId
$subscriptionId = $config.azure.subscriptionId
$subscriptionName = $config.azure.subscriptionName
$tenantId = $config.azure.tenantId

# Get project ID (required for REST API)
$projectId = (az devops project show --project $project --output json | ConvertFrom-Json).id
Write-Host "✓ Configuration loaded"
```

### Step 2: Create Service Connections with Workload Identity Federation

**IMPORTANT:** Use REST API for federated credentials - Azure CLI does NOT support this!

```powershell
# Service connection configuration
$projectName = $config.naming.projectName
$environments = @("dev", "test", "prod")

foreach ($env in $environments) {
    $scName = "$projectName-$env"
    
    # Check if service connection already exists
    $existingSc = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv
    
    if (-not $existingSc) {
        Write-Host "Creating service connection: $scName"
        
        # Create via REST API with federated credentials
        $uri = "$org/$project/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
        
        $body = @{
            authorization = @{
                parameters = @{
                    serviceprincipalid = $spAppId
                    tenantid = $tenantId
                }
                scheme = "WorkloadIdentityFederation"
            }
            data = @{
                subscriptionId = $subscriptionId
                subscriptionName = $subscriptionName
            }
            name = $scName
            type = "azurerm"
            url = "https://management.azure.com/"
            serviceEndpointProjectReferences = @(
                @{
                    projectReference = @{
                        id = $projectId
                        name = $project
                    }
                    name = $scName
                }
            )
        } | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers @{
            "Authorization" = "Bearer $env:ADO_TOKEN"
            "Content-Type" = "application/json"
        } -Body $body
        
        Write-Host "✓ Service connection created: $scName (ID: $($response.id))"
        
        # CRITICAL: Authorize the service connection for all pipelines
        Start-Sleep -Seconds 2
        $scId = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv
        az devops service-endpoint update --id $scId --enable-for-all true
        Write-Host "✓ Service connection authorized for all pipelines"
        
    } else {
        Write-Host "✓ Service connection already exists: $scName"
    }
}
```

### Step 3: Add Federated Credentials to Service Principal

**CRITICAL:** This step is required for Workload Identity Federation to work!

The federated credential tells Azure AD which Azure DevOps service connections to trust.

```powershell
Write-Host "`nConfiguring federated credentials on Service Principal..."

foreach ($env in $environments) {
    $credName = "azure-devops-$project-$env"
    
    # Check if credential already exists
    $existingCred = az ad app federated-credential list --id $spAppId --query "[?name=='$credName'].name" -o tsv
    
    if (-not $existingCred) {
        Write-Host "Creating federated credential: $credName"
        
        # Get service connection ID
        $scName = "azure-foundry-$env"
        $scId = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv
        
        # CRITICAL: These values must match exactly what Azure DevOps sends
        $issuer = "https://vstoken.dev.azure.com/$($org.Split('/')[-1])"
        $subject = "sc://$($org.Split('/')[-1])/$project/$scName"
        
        # Create federated credential
        az ad app federated-credential create `
            --id $spAppId `
            --parameters "{
                \`"name\`": \`"$credName\`",
                \`"issuer\`": \`"$issuer\`",
                \`"subject\`": \`"$subject\`",
                \`"audiences\`": [\`"api://AzureADTokenExchange\`"]
            }"
        
        Write-Host "✓ Federated credential created: $credName"
        Write-Host "  Issuer: $issuer"
        Write-Host "  Subject: $subject"
    } else {
        Write-Host "✓ Federated credential already exists: $credName"
    }
}
```

### Step 4: Verify RBAC Permissions

```powershell
Write-Host "`n=== Verifying RBAC Permissions ==="

# Get Service Principal Object ID
$spObjectId = (az ad sp show --id $spAppId --query id -o tsv)

# Check Contributor role on resource group
# Derive resource group name from project name
$rgName = "rg-$($config.naming.projectName)"
$rgScope = "/subscriptions/$subscriptionId/resourceGroups/$rgName"
$contributorRole = az role assignment list --assignee $spObjectId --scope $rgScope --role "Contributor" --query "[].roleDefinitionName" -o tsv

if ($contributorRole) {
    Write-Host "✓ Contributor role assigned on resource group"
} else {
    Write-Host "⚠️  WARNING: Missing Contributor role on resource group"
    Write-Host "   Run: az role assignment create --assignee $spAppId --role 'Contributor' --scope $rgScope"
}

# Check Cognitive Services User role on AI Foundry projects
$envs = @{
    "dev" = $config.azure.aiFoundry.dev.projectName
    "test" = $config.azure.aiFoundry.test.projectName
    "prod" = $config.azure.aiFoundry.prod.projectName
}

foreach ($env in $envs.Keys) {
    $projectName = $envs[$env]
    # Derive resource group name from project name
    $rgName = "rg-$($config.naming.projectName)"
    $projectScope = "/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.MachineLearningServices/workspaces/$projectName"
    
    $cognitiveRole = az role assignment list --assignee $spObjectId --scope $projectScope --role "Cognitive Services User" --query "[].roleDefinitionName" -o tsv
    
    if ($cognitiveRole) {
        Write-Host "✓ Cognitive Services User role assigned on $projectName"
    } else {
        Write-Host "⚠️  WARNING: Missing Cognitive Services User role on $projectName"
        Write-Host "   Run: az role assignment create --assignee $spAppId --role 'Cognitive Services User' --scope $projectScope"
    }
}

Write-Host "`n✅ Service connection setup complete!"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Federated Credential Issuer/Subject Mismatch
**Error:** `AADSTS70021: No matching federated identity record found`

**This is the #1 issue!** The issuer and subject must match EXACTLY what Azure DevOps sends.

**Solution:**
```powershell
# Get the correct values from Azure DevOps
# Replace {projectName} with your actual project name from config.naming.projectName
$scId = az devops service-endpoint list --query "[?name=='{projectName}-dev'].id" --output tsv
$orgName = $org.Split('/')[-1]

# Correct format
$issuer = "https://vstoken.dev.azure.com/$orgName"
$subject = "sc://$orgName/$project/{projectName}-dev"

# Delete old credential
$credId = az ad app federated-credential list --id $spAppId --query "[?name=='azure-devops-$project-dev'].id" -o tsv
az ad app federated-credential delete --id $spAppId --federated-credential-id $credId

# Recreate with correct values
az ad app federated-credential create --id $spAppId --parameters "{ ... }"
```

**Real example from troubleshooting:**
```
❌ WRONG: issuer = "https://login.microsoftonline.com/{tenantId}/v2.0"
✅ CORRECT: issuer = "https://vstoken.dev.azure.com/foundry-cicd-demo-01"

❌ WRONG: subject = "/eid1/c/pub/t/.../sc/{serviceConnectionId}"
✅ CORRECT: subject = "sc://foundry-cicd-demo-01/foundry-cicd-demo-01/{projectName}-dev"
```

#### 2. Service Connection Not Authorized
**Error:** `The pipeline is not valid. Job <job>: Step <step> references service connection <name> which could not be found.`

**Solution:**
```powershell
# Authorize service connection for all pipelines
$scId = az devops service-endpoint list --query "[?name=='azure-foundry-dev'].id" --output tsv
az devops service-endpoint update --id $scId --enable-for-all true
```

#### 3. Missing RBAC Permissions
**Error:** Pipeline fails with 403 Forbidden when accessing Azure resources

**Solution:**
```powershell
# Add required roles
$rgScope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
az role assignment create --assignee $spAppId --role "Contributor" --scope $rgScope

$projectScope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.MachineLearningServices/workspaces/$projectName"
az role assignment create --assignee $spAppId --role "Cognitive Services User" --scope $projectScope
```

#### 4. REST API Call Fails
**Error:** 401 Unauthorized when creating service connection

**Solution:** Refresh your bearer token:
```powershell
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```

#### 5. Project ID Not Found
**Error:** Cannot find project

**Solution:**
```powershell
# Verify project exists
az devops project show --project $project

# Ensure defaults are set
az devops configure --defaults organization=$org project=$project
```

## Best practices

1. **Always use Workload Identity Federation** - More secure than service principal keys
2. **Verify federated credentials** - Double-check issuer and subject format
3. **Grant minimal RBAC permissions** - Only Contributor + Cognitive Services User
4. **Authorize service connections early** - Enable for all pipelines immediately
5. **Document the pattern** - Keep this setup consistent across all projects
6. **Test immediately** - Run a simple pipeline to verify authentication works

## Integration with other skills

This skill works together with:
- **configuration-management** (required first) - Loads centralized configuration
- **resource-creation** (required) - Creates the Service Principal
- **repository-setup** (before this) - Creates the repository
- **environment-setup** (next step) - Creates variable groups and environments
- **pipeline-setup** (after environments) - Creates pipelines that use these connections

## Related resources

- [docs/troubleshooting.md](../../../docs/troubleshooting.md) - Lesson #1: Federated credentials
- [docs/starter-guide.md](../../../docs/starter-guide.md) - Complete deployment guide
- [Microsoft Docs: Workload Identity Federation](https://learn.microsoft.com/azure/active-directory/workload-identities/workload-identity-federation)
- [Azure DevOps: Service connections](https://learn.microsoft.com/azure/devops/pipelines/library/service-endpoints)
