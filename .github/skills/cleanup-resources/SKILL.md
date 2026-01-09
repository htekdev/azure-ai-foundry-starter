---
name: cleanup-resources
description: Safely deletes all Azure resources created by the Azure AI Foundry starter template including resource groups, AI Services, AI Foundry Projects, Service Principal, federated credentials, and RBAC assignments. Use when tearing down environments or starting fresh.
license: Apache-2.0
---

# Azure AI Foundry Cleanup Resources

This skill safely deletes all Azure resources created by the Azure AI Foundry starter template.

## Overview

A comprehensive cleanup skill that removes all Azure infrastructure created during deployment:

- **Resource Groups** (dev, test, prod) - Deletes all contained resources automatically
- **AI Foundry Projects** - All projects and configurations
- **AI Services** - All AI Services resources and deployments
- **Service Principal** - App registration, federated credentials, and role assignments
- **RBAC Assignments** - All role assignments on deleted resources

⚠️ **Warning**: This action is **IRREVERSIBLE**. All data, configurations, and deployments will be permanently lost.

## When to Use This Skill

Use this skill when you need to:
- **Tear down demo/test environments** completely
- **Start fresh** after failed deployments or experiments
- **Clean up resources** to avoid Azure costs
- **Remove all infrastructure** before redeployment
- **Decommission projects** permanently

## Prerequisites

- **Azure CLI** installed and authenticated
- **Contributor access** to the subscription
- **Valid starter-config.json** file with resource information
- **Application Administrator** role (for Service Principal deletion)

## Usage

### Preview Before Deletion (Recommended)

```powershell
cd .github/skills/cleanup-resources/scripts
.\cleanup-resources.ps1 -DryRun
```

**Output**: Lists all resources that would be deleted without actually deleting them.

### Interactive Deletion (Safe)

```powershell
.\cleanup-resources.ps1
```

**Process**:
1. Lists all resources to be deleted
2. Prompts for confirmation: Type `DELETE` (uppercase) to proceed
3. Deletes resources with progress updates
4. Provides summary and next steps

### Force Deletion (Skip Confirmation)

```powershell
.\cleanup-resources.ps1 -Force
```

⚠️ **Caution**: Immediately deletes resources without confirmation prompt.

### Custom Configuration Path

```powershell
.\cleanup-resources.ps1 -ConfigPath "C:\path\to\custom-config.json"
```

## Parameters

### `-DryRun`
- **Type**: Switch
- **Purpose**: Preview what will be deleted without making changes
- **Use Case**: Verify resources before actual deletion

### `-Force`
- **Type**: Switch  
- **Purpose**: Skip confirmation prompt and delete immediately
- **Use Case**: Automated cleanup scripts, CI/CD teardown

### `-ConfigPath`
- **Type**: String
- **Default**: `.\starter-config.json`
- **Purpose**: Specify custom configuration file location
- **Use Case**: Multiple environments or non-standard paths

## What Gets Deleted

Based on your `starter-config.json`:

### 1. Resource Groups (with all contents)

Resource groups follow the naming pattern: `rg-{projectName}-{env}` where `{projectName}` is derived from `config.naming.projectName`.

```
rg-{projectName}-dev
  ├── AI Foundry Project (aif-project-dev)
  ├── AI Services (aif-foundry-dev)
  ├── Deployments
  └── All other resources

rg-{projectName}-test
  └── (similar structure)

rg-{projectName}-prod
  └── (similar structure)
```

**Example**: If `config.naming.projectName = "ai-foundry-starter"`, resource groups will be named:
- `rg-ai-foundry-starter-dev`
- `rg-ai-foundry-starter-test`
- `rg-ai-foundry-starter-prod`

**Note**: Deleting resource groups automatically deletes all contained resources.

### 2. Service Principal

- **App Registration** with configured name
- **Federated Credentials** (dev, test, prod)
- **Role Assignments** (Contributor, Cognitive Services User)

### 3. Azure Resources Summary

| Resource Type | Count | Examples |
|---------------|-------|----------|
| Resource Groups | 3 | dev, test, prod |
| AI Foundry Projects | 3 | One per environment |
| AI Services | 3 | One per environment |
| Service Principal | 1 | With 3 federated credentials |
| Role Assignments | 6+ | Contributor + Cognitive Services User per RG |

## Execution Flow

### Phase 1: Configuration & Authentication

```powershell
# Load configuration
$config = Get-Content .\starter-config.json | ConvertFrom-Json

# Set Azure subscription context
az account set --subscription $config.azure.subscriptionId
```

### Phase 2: Discovery

```powershell
# Derive resource group prefix from project name
$projectName = $config.naming.projectName
$rgPrefix = "rg-$projectName"

# Find all resource groups matching pattern
az group list --query "[?starts_with(name, '$rgPrefix')]"

# Check Service Principal
az ad sp show --id $config.servicePrincipal.appId

# List federated credentials
az ad app federated-credential list --id $config.servicePrincipal.appId
```

### Phase 3: Confirmation Display

Shows detailed list of:
- Resource groups with contained resources
- Service Principal with federated credentials
- Role assignments

### Phase 4: Deletion

```powershell
# Delete resource groups (async, background operation)
az group delete --name $rgName --yes --no-wait

# Delete Service Principal (synchronous)
az ad sp delete --id $spAppId
```

### Phase 5: Summary & Next Steps

- Deletion status
- Azure Portal verification link
- Azure DevOps cleanup instructions

## Examples

### Example 1: Safe Cleanup with Preview

```powershell
# First, preview what will be deleted
cd .github/skills/cleanup-resources/scripts
.\cleanup-resources.ps1 -DryRun

# Review the output, then proceed with deletion
.\cleanup-resources.ps1
# Type "DELETE" when prompted
```

### Example 2: Automated Cleanup

```powershell
# For automated scripts (CI/CD teardown)
.\cleanup-resources.ps1 -Force
```

### Example 3: Cleanup Specific Configuration

```powershell
# Use custom config file
.\cleanup-resources.ps1 -ConfigPath "..\..\..\..\config\prod-config.json" -DryRun
```

### Example 4: Full Workflow

```powershell
# 1. Load configuration to verify
$config = Get-Content .\starter-config.json | ConvertFrom-Json
Write-Host "Subscription: $($config.azure.subscriptionName)"
Write-Host "Resource Group Base: rg-$($config.naming.projectName)"

# 2. Preview deletion
.\cleanup-resources.ps1 -DryRun

# 3. Proceed with deletion
.\cleanup-resources.ps1

# 4. Monitor progress in Azure Portal
# https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups

# 5. Verify deletion complete
# Use resource group prefix from your configuration
$config = Get-Content .\starter-config.json | ConvertFrom-Json
$rgPrefix = "rg-$($config.naming.projectName)"
az group list --query "[?starts_with(name, '$rgPrefix')]" -o table
az ad sp show --id $config.servicePrincipal.appId 2>$null
```

## Verification

### Check Resource Deletion

```powershell
# Verify resource groups are deleted
$config = Get-Content .\starter-config.json | ConvertFrom-Json
$rgPrefix = "rg-$($config.naming.projectName)"
az group list --query "[?starts_with(name, '$rgPrefix')]" -o table

# Should return empty or show "Deleting" state
```

### Check Service Principal Deletion

```powershell
# Verify Service Principal is deleted
az ad sp show --id $config.servicePrincipal.appId 2>$null

# Should return error: "Resource not found"
```

### Check for Orphaned Resources

```powershell
# List all resources in subscription
az resource list --subscription $config.azure.subscriptionId -o table

# Filter for AI Foundry related resources
az resource list --query "[?contains(name, 'foundry') || contains(name, 'aif-')]" -o table
```

## Azure DevOps Cleanup

The script provides guidance for manual Azure DevOps cleanup:

### Repository
```powershell
az repos delete --id "azure-ai-foundry-app" --yes
```

### Service Connections
```powershell
$devConn = az devops service-endpoint list --query "[?name=='azure-foundry-dev'].id" -o tsv
az devops service-endpoint delete --id $devConn --yes

# Repeat for test and prod
```

### Variable Groups
```powershell
# Use your projectName from config.naming.projectName
$devVars = az pipelines variable-group list --query "[?name=='$projectName-dev-vars'].id" -o tsv
az pipelines variable-group delete --id $devVars --yes

# Repeat for test and prod
```

### Environments
```powershell
az pipelines environment delete --name "dev" --yes
az pipelines environment delete --name "test" --yes
az pipelines environment delete --name "production" --yes
```

### Pipelines
```powershell
# List pipelines
az pipelines list --query "[].{Name:name, Id:id}" -o table

# Delete each pipeline
az pipelines delete --id <pipeline-id> --yes
```

## Troubleshooting

### Issue: "Insufficient privileges to delete resource group"

**Solution**: Ensure you have Contributor or Owner role on the resource group:
```powershell
az role assignment list --scope "/subscriptions/$subscriptionId/resourceGroups/$rgName"
```

### Issue: "Cannot delete Service Principal - permission denied"

**Solution**: Requires **Application Administrator** role in Azure AD:
```powershell
# Check your Azure AD roles
az rest --method GET --url "https://graph.microsoft.com/v1.0/me/memberOf"

# Have admin grant Application Administrator role
```

### Issue: "Resource group deletion stuck"

**Symptom**: Resource group shows "Deleting" for extended period

**Solution**:
```powershell
# Check deletion status
az group show --name $rgName --query "properties.provisioningState" -o tsv

# If stuck, try canceling and re-deleting
# (Note: May not always work)

# Check for resource locks
az lock list --resource-group $rgName -o table
```

### Issue: "Configuration file not found"

**Solution**:
```powershell
# Verify file exists
Test-Path .\starter-config.json

# Specify full path
.\cleanup-resources.ps1 -ConfigPath "C:\Repos\ado\azure-ai-foundry-starter\starter-config.json"
```

### Issue: "Some resources remain after deletion"

**Solution**:
```powershell
# Find remaining resources
az resource list --query "[?contains(name, 'foundry') || contains(name, 'aif-')]" -o table

# Delete individually
az resource delete --ids <resource-id>
```

## Best Practices

### Before Deletion
1. **Backup important data** - Export any critical configurations or data
2. **Document customizations** - Note any custom configurations for future reference
3. **Export Service Principal credentials** - Save for audit logs (if not already done)
4. **Take screenshots** - Document current state for reference

### During Deletion
1. **Use DryRun first** - Always preview before actual deletion
2. **Monitor progress** - Check Azure Portal for deletion status
3. **Wait for completion** - Resource group deletion takes 5-10 minutes
4. **Verify Service Principal** - Ensure it's fully deleted

### After Deletion
1. **Verify in Azure Portal** - Check all resources are gone
2. **Clean up Azure DevOps** - Follow guidance for repository, connections, pipelines
3. **Update documentation** - Note deletion date and reason
4. **Archive configuration** - Save `starter-config.json` for records

### Cost Management
- **Delete promptly** - Remove unused resources to avoid unnecessary costs
- **Schedule cleanup** - Automate cleanup for demo/test environments
- **Monitor subscription** - Check Azure Cost Management after deletion

### Security
- **Audit logs** - Resource deletions are logged in Azure Activity Log
- **Role-based access** - Limit who can run cleanup scripts
- **Configuration backup** - Store `starter-config.json` securely before deletion

## Related Skills

### Prerequisite Skills
- **[configuration-management](../configuration-management)** - Requires valid configuration file

### Complementary Skills
- **[resource-creation](../resource-creation)** - Recreate resources after cleanup
- **[environment-validation](../environment-validation)** - Validate environment before recreation

### Workflow Integration

**Cleanup → Recreate Workflow**:
```powershell
# 1. Clean up all resources
cd .github/skills/cleanup-resources/scripts
.\cleanup-resources.ps1

# 2. Verify deletion (uses your configured project name)
$config = Get-Content .\starter-config.json | ConvertFrom-Json
$rgPrefix = "rg-$($config.naming.projectName)"
az group list --query "[?starts_with(name, '$rgPrefix')]" -o table

# 3. Recreate from scratch
cd ../../resource-creation
.\create-resources.ps1 -UseConfig -CreateAll
```

## Documentation

- **[docs/troubleshooting.md](../../../docs/troubleshooting.md)** - General troubleshooting guide
- **[Azure Resource Group Deletion](https://learn.microsoft.com/azure/azure-resource-manager/management/delete-resource-group)** - Microsoft documentation
- **[Azure AD App Registration Management](https://learn.microsoft.com/azure/active-directory/develop/howto-remove-app)** - Service Principal deletion guide

## Safety Features

The cleanup script includes multiple safety features:

1. **Preview Mode** (`-DryRun`) - See what will be deleted without changes
2. **Confirmation Prompt** - Requires typing "DELETE" (uppercase) to proceed
3. **Detailed Display** - Shows all resources with nested contents
4. **Background Deletion** - Resource groups delete asynchronously (non-blocking)
5. **Error Handling** - Continues if some resources already deleted
6. **Summary Report** - Clear feedback on what was deleted

## Output Example

```
═══════════════════════════════════════════════════════════════
  WARNING: RESOURCE DELETION
═══════════════════════════════════════════════════════════════

The following resources will be PERMANENTLY DELETED:

📦 Resource Groups:
  ❌ rg-{projectName}-dev (eastus)
     Contains 3 resources:
       - aif-foundry-dev (accounts)
       - aif-project-dev (workspaces)
       - storage-dev (storageAccounts)
  ❌ rg-{projectName}-test (eastus)
  ❌ rg-{projectName}-prod (eastus)

👤 Service Principal:
  ❌ sp-aif-demo-cicd (App ID: f1ef8b31-...)
     Contains 3 federated credentials:
       - azure-foundry-dev
       - azure-foundry-test
       - azure-foundry-prod
     Has 6 role assignments

═══════════════════════════════════════════════════════════════

⚠️  This action is IRREVERSIBLE!
   All data, configurations, and deployments will be permanently lost.

Type 'DELETE' (in uppercase) to confirm deletion:
```
