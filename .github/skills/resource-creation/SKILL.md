---
name: resource-creation
description: Orchestrates creation of all Azure resources for Azure AI Foundry multi-environment deployment. Coordinates resource-groups, service-principal, and ai-foundry-resources skills. Use when setting up a complete Azure AI Foundry infrastructure from scratch across dev, test, and prod environments.
license: Apache-2.0
---

# Azure AI Foundry Resource Creation Orchestrator

This skill orchestrates the creation of all Azure resources required for Azure AI Foundry deployments across multiple environments.

## Overview

A high-level orchestration skill that coordinates three specialized skills to create a complete Azure AI Foundry infrastructure:

1. **[resource-groups](../resource-groups)** - Creates Azure resource groups for multiple environments
2. **[service-principal](../service-principal)** - Creates Service Principal with workload identity federation and RBAC
3. **[ai-foundry-resources](../ai-foundry-resources)** - Creates AI Services resources and AI Foundry Projects

## When to Use This Skill

Use this skill when you need to:
- Set up complete Azure AI Foundry infrastructure from scratch
- Create multi-environment deployments (dev, test, prod)
- Orchestrate resource creation in proper dependency order
- Ensure consistent resource naming and tagging
- Configure RBAC and workload identity federation

## Orchestration Flow

When `-CreateAll` is specified, the orchestrator executes in this order:

### 1. Resource Groups (Always)
Calls [resource-groups/scripts/create-resource-groups.ps1](../resource-groups/scripts/create-resource-groups.ps1)
- Creates dev, test, prod resource groups
- Applies environment-specific tags
- Validates resource group creation

### 2. Service Principal (Conditional: `-CreateServicePrincipal`)
Calls [service-principal/scripts/create-service-principal.ps1](../service-principal/scripts/create-service-principal.ps1)
- Creates App Registration with workload identity federation
- Grants Contributor role on all resource groups
- Grants Cognitive Services User role
- Updates starter-config.json with credentials

### 3. AI Foundry Resources (Conditional: `-CreateAIProjects`)
Calls [ai-foundry-resources/scripts/create-ai-foundry-resources.ps1](../ai-foundry-resources/scripts/create-ai-foundry-resources.ps1)
- Creates AI Services resources for each environment
- Creates AI Foundry Projects
- Configures project endpoints
- Grants Cognitive Services User role to Service Principal

## Usage

```powershell
# Create all resources using configuration from starter-config.json
./create-resources.ps1 -UseConfig -CreateAll

# Create specific resources
./create-resources.ps1 -UseConfig -CreateServicePrincipal -CreateAIProjects

# Create for specific environment
./create-resources.ps1 `
    -ResourceGroupBaseName "rg-aif-demo" `
    -Location "eastus" `
    -Environment "dev" `
    -CreateAll

# Create without Service Principal
./create-resources.ps1 -UseConfig -Environment "all" -CreateAIProjects
```

## Parameters

### Configuration
- **`-UseConfig`**: Load resource names from starter-config.json

### Resource Naming
- **`-ResourceGroupBaseName`**: Base name for resource groups (e.g., "rg-aif-demo")
- **`-Location`**: Azure region (default: eastus)
- **`-ServicePrincipalName`**: Service Principal display name
- **`-AIProjectBaseName`**: Base name for AI resources

### Environment Selection
- **`-Environment`**: Target environment ('dev', 'test', 'prod', or 'all')

### Creation Flags
- **`-CreateServicePrincipal`**: Create Service Principal and configure RBAC
- **`-CreateAIProjects`**: Create AI Services and AI Foundry Projects
- **`-CreateAll`**: Enable both ServicePrincipal and AIProjects creation

### Output
- **`-OutputFormat`**: Output format ('text' or 'json')

## Examples

### Complete Setup (All Resources, All Environments)
```powershell
cd .github/skills/resource-creation
./create-resources.ps1 -UseConfig -CreateAll
```

### Dev Environment Only
```powershell
./create-resources.ps1 -UseConfig -Environment "dev" -CreateAll
```

### AI Resources Only (Skip Service Principal)
```powershell
./create-resources.ps1 `
    -ResourceGroupBaseName "rg-aif-demo" `
    -AIProjectBaseName "aif-demo" `
    -Location "eastus" `
    -Environment "all" `
    -CreateAIProjects
```

### Custom Naming with Service Principal
```powershell
./create-resources.ps1 `
    -ResourceGroupBaseName "rg-myapp-ai" `
    -ServicePrincipalName "sp-myapp-cicd" `
    -AIProjectBaseName "aif-myapp" `
    -Location "westus2" `
    -Environment "all" `
    -CreateAll
```

## Verification

After orchestration completes, verify the deployment:

```powershell
# Check Resource Groups
az group list --query "[?starts_with(name, 'rg-aif-demo')].{Name:name, Location:location}" -o table

# Check Service Principal
az ad sp list --display-name "sp-aif-demo-cicd" --query "[].{Name:displayName, AppId:appId}" -o table

# Check AI Services
az cognitiveservices account list --query "[?starts_with(name, 'aif-demo')].{Name:name, Kind:kind, Location:location}" -o table

# Check RBAC Assignments
$spId = az ad sp list --display-name "sp-aif-demo-cicd" --query "[0].id" -o tsv
az role assignment list --assignee $spId --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

## Configuration File

The orchestrator updates **starter-config.json** with created resource information:

```json
{
  "azure": {
    "subscriptionId": "00000000-0000-0000-0000-000000000000",
    "resourceGroups": {
      "dev": "rg-aif-demo-dev",
      "test": "rg-aif-demo-test",
      "prod": "rg-aif-demo-prod"
    },
    "location": "eastus"
  },
  "servicePrincipal": {
    "displayName": "sp-aif-demo-cicd",
    "appId": "00000000-0000-0000-0000-000000000000",
    "objectId": "00000000-0000-0000-0000-000000000000",
    "tenantId": "00000000-0000-0000-0000-000000000000"
  },
  "aiFoundry": {
    "dev": {
      "projectName": "aif-demo-dev",
      "projectEndpoint": "https://..."
    },
    "test": { ... },
    "prod": { ... }
  }
}
```

## Specialized Skills

This orchestrator delegates to three specialized skills:

### 1. Resource Groups Skill
**Location**: [../resource-groups](../resource-groups)  
**Purpose**: Creates Azure resource groups for multiple environments  
**Output**: Resource group names and IDs

**Direct Usage**:
```powershell
cd ../resource-groups/scripts
./create-resource-groups.ps1 `
    -ResourceGroupBaseName "rg-aif-demo" `
    -Location "eastus" `
    -Environment "all"
```

### 2. Service Principal Skill
**Location**: [../service-principal](../service-principal)  
**Purpose**: Creates Service Principal with workload identity and RBAC  
**Output**: Service Principal credentials and configuration

**Direct Usage**:
```powershell
cd ../service-principal/scripts
./create-service-principal.ps1 `
    -DisplayName "sp-aif-demo-cicd" `
    -ResourceGroupNames @("rg-aif-demo-dev", "rg-aif-demo-test", "rg-aif-demo-prod")
```

### 3. AI Foundry Resources Skill
**Location**: [../ai-foundry-resources](../ai-foundry-resources)  
**Purpose**: Creates AI Services and AI Foundry Projects  
**Output**: Project names and endpoints

**Direct Usage**:
```powershell
cd ../ai-foundry-resources/scripts
./create-ai-foundry-resources.ps1 `
    -ProjectBaseName "aif-demo" `
    -ResourceGroupName "rg-aif-demo-dev" `
    -Location "eastus" `
    -Environment "dev" `
    -ServicePrincipalId "00000000-0000-0000-0000-000000000000"
```

## Troubleshooting

### Orchestration Errors

**Symptom**: "Cannot find script file"
```powershell
# Verify skill structure
Get-ChildItem -Path .github/skills -Recurse -Filter "*.ps1"

# Ensure scripts are in correct locations:
# ../resource-groups/scripts/create-resource-groups.ps1
# ../service-principal/scripts/create-service-principal.ps1
# ../ai-foundry-resources/scripts/create-ai-foundry-resources.ps1
```

**Symptom**: "Resource group does not exist"
```powershell
# Run resource-groups skill first
cd .github/skills/resource-groups/scripts
./create-resource-groups.ps1 -UseConfig
```

**Symptom**: "Service Principal not found"
```powershell
# Verify Service Principal was created
az ad sp list --display-name "sp-aif-demo-cicd" -o table

# If missing, run service-principal skill
cd .github/skills/service-principal/scripts
./create-service-principal.ps1 -UseConfig
```

### Skill-Specific Issues

For detailed troubleshooting of individual skills, see:
- [Resource Groups Troubleshooting](../resource-groups/SKILL.md#troubleshooting)
- [Service Principal Troubleshooting](../service-principal/SKILL.md#troubleshooting)
- [AI Foundry Resources Troubleshooting](../ai-foundry-resources/SKILL.md#troubleshooting)

## Best Practices

### Execution Order
Always create resources in this order:
1. Resource Groups (required for all other resources)
2. Service Principal (optional, but recommended for CI/CD)
3. AI Foundry Resources (requires resource groups)

### Configuration Management
- Use **starter-config.json** for consistent naming across all skills
- Run with `-UseConfig` flag for automated deployments
- Review configuration before creating production resources

### Environment Strategy
- Start with **dev** environment for testing
- Validate resource creation and access
- Promote to **test** and **prod** incrementally

### Security
- Service Principal credentials are automatically saved to **starter-config.json**
- Store **starter-config.json** securely (add to .gitignore)
- Use Azure Key Vault for production credential storage
- Rotate Service Principal secrets regularly

### Cost Optimization
- Use `-Environment "dev"` for initial testing (creates only one environment)
- Delete dev resources when not in use
- Monitor costs with Azure Cost Management tags applied by skills
