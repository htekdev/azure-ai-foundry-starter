---
name: configuration-management
description: Manages centralized configuration for Azure AI Foundry starter deployment including organization names, resource names, project names, and all other customizable values. Use this skill first to set up configuration, or when you need to retrieve/update deployment settings.
---

# Configuration Management for Azure AI Foundry Starter

Manages all configurable values for the Azure AI Foundry starter template deployment. Provides a single source of truth stored in `starter-config.json` at the repository root.

## Quick start

### 1. Create configuration interactively

```powershell
./.github/skills/configuration-management/configure-starter.ps1 -Interactive
```

Prompts for all required values and creates `starter-config.json`.

### 2. Auto-discover from environment

```powershell
./.github/skills/configuration-management/configure-starter.ps1 -AutoDiscover
```

Detects Azure subscription, resource groups, and Azure DevOps organizations.

### 3. Load configuration in scripts

```powershell
# Source functions
. ./.github/skills/configuration-management/config-functions.ps1

# Load config
$config = Get-StarterConfig

# Access values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
# Derive resource group base from project name
$rgBase = "rg-$($config.naming.projectName)"
$devEndpoint = $config.azure.aiFoundry.dev.projectEndpoint
```

## Configuration structure

```json
{
  "azureDevOps": {
    "organizationUrl": "https://dev.azure.com/YOUR_ORG",
    "projectName": "YOUR_PROJECT"
  },
  "azure": {
    "subscriptionId": "00000000-0000-0000-0000-000000000000",
    "subscriptionName": "YOUR_SUBSCRIPTION",
    "tenantId": "00000000-0000-0000-0000-000000000000",
    "location": "eastus",
    "aiFoundry": {
      "dev": { "projectEndpoint": "https://RESOURCE.services.ai.azure.com/api/projects/PROJECT" },
      "test": { "projectEndpoint": "https://RESOURCE.services.ai.azure.com/api/projects/PROJECT" },
      "prod": { "projectEndpoint": "https://RESOURCE.services.ai.azure.com/api/projects/PROJECT" }
    }
  },
  "servicePrincipal": {
    "appId": "00000000-0000-0000-0000-000000000000",
    "tenantId": "00000000-0000-0000-0000-000000000000"
  },
  "metadata": {
    "version": "2.0",
    "description": "Azure AI Foundry Starter Template Configuration",
    "lastModified": "2026-01-08"
  }
}
```

## Interactive configuration workflow

### Create configuration

```powershell
./.github/skills/configuration-management/configure-starter.ps1 -Interactive
```

Prompts for:
- Azure DevOps organization URL and project name
- Azure subscription, tenant, resource group base name, location
- AI Foundry project endpoints (dev/test/prod)
- Service Principal settings (created automatically)

### Validate configuration

```powershell
./.github/skills/configuration-management/configure-starter.ps1 -Validate
```

Checks completeness and validates against Azure environment.

### View configuration

```powershell
# Show all
./.github/skills/configuration-management/configure-starter.ps1 -Show

# Show section
./.github/skills/configuration-management/configure-starter.ps1 -Show -Section "azure"
```

## Programmatic usage

### Load and use configuration

```powershell
. ./.github/skills/configuration-management/config-functions.ps1

$config = Get-StarterConfig

# Use in resource creation
az group create `
  --name "rg-$($config.naming.projectName)-dev" \
  --location $config.azure.location

# Use in Azure DevOps commands
az repos create `
  --organization $config.azureDevOps.organizationUrl `
  --project $config.azureDevOps.projectName `
  --name "my-agent-repo"
```

### Update configuration

```powershell
. ./.github/skills/configuration-management/config-functions.ps1

$config = Get-StarterConfig
$config.azure.location = "westus2"
$config.servicePrincipal.appId = "NEW-APP-ID"
Set-StarterConfig -Config $config -CreateBackup
```

## Helper functions

For detailed function reference, see [API-REFERENCE.md](./references/API-REFERENCE.md).

Common functions:
- `Get-StarterConfig` - Load configuration from file
- `Set-StarterConfig` - Save configuration with optional backup
- `Get-ConfigValue` / `Set-ConfigValue` - Access nested values by path
- `Test-ConfigurationComplete` - Validate required fields
- `Test-ConfigurationValidity` - Verify against Azure environment

## Auto-discovery

```powershell
./.github/skills/configuration-management/configure-starter.ps1 -AutoDiscover
```

Automatically detects:
- ✅ Current Azure subscription and tenant
- ✅ Azure DevOps organizations
- ✅ Existing resource groups
- ✅ AI Foundry Hubs and AI Services
- ⚠️ Prompts for values that can't be detected



## Integration with other skills

### resource-creation skill
```powershell
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Create resource groups for all environments
@('dev', 'test', 'prod') | ForEach-Object {
  # Derive resource group name from project name
  $rgName = "rg-$($config.naming.projectName)-$_"
  az group create `
    --name $rgName `
    --location $config.azure.location
}
```

### service-connection-setup skill
```powershell
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Create service connections
az devops service-endpoint azurerm create `
  --organization $config.azureDevOps.organizationUrl `
  --project $config.azureDevOps.projectName `
  --name "Azure-Dev" `
  --azure-rm-subscription-id $config.azure.subscriptionId `
  --azure-rm-service-principal-id $config.servicePrincipal.appId `
  --azure-rm-tenant-id $config.servicePrincipal.tenantId
```

### environment-setup skill
```powershell
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Create variable groups with AI Foundry endpoints
az pipelines variable-group create `
  --organization $config.azureDevOps.organizationUrl `
  --project $config.azureDevOps.projectName `
  --name "DEV-Variables" `
  --variables AIPROJECT_CONNECTION_STRING="$($config.azure.aiFoundry.dev.projectEndpoint)"
```

## Best practices

- ✅ Create configuration before resource creation
- ✅ Validate after creation: `configure-starter.ps1 -Validate`
- ✅ Version control `starter-config.json`
- ✅ Back up before updates: `Set-StarterConfig -CreateBackup`
- ❌ Don't commit Service Principal secrets
- ✅ Use environment suffixes: `rg-{projectName}-dev`, `-test`, `-prod` (automatically derived)
- ✅ Follow Azure naming rules (lowercase, no special chars)

## Troubleshooting

### Configuration not found
```powershell
./.github/skills/configuration-management/configure-starter.ps1 -Interactive
```

### Invalid JSON
```powershell
Get-Content starter-config.json | ConvertFrom-Json
# If error, restore from backup
Copy-Item starter-config.json.backup starter-config.json
```

### Validation failures
```powershell
./.github/skills/configuration-management/configure-starter.ps1 -Validate
# Review errors and update values
./.github/skills/configuration-management/configure-starter.ps1 -Show
```

## Files

- [configure-starter.ps1](./configure-starter.ps1) - Interactive configuration wizard
- [config-functions.ps1](./config-functions.ps1) - PowerShell helper functions
- [config-template.json](./config-template.json) - Configuration template
- [SKILL.md](./SKILL.md) - This documentation

## Related skills

- [resource-creation](../resource-creation/SKILL.md) - Create Azure resources
- [service-principal](../service-principal/SKILL.md) - Create Service Principal
- [environment-setup](../environment-setup/SKILL.md) - Configure Azure DevOps environments
