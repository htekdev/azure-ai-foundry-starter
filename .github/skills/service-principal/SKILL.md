---
name: service-principal
description: Creates Azure Service Principal with Entra ID App Registration configured for workload identity federation. Grants RBAC permissions across multiple environments. Use when setting up CI/CD authentication for Azure DevOps pipelines or automated deployments requiring federated credentials.
license: Apache-2.0
---

# Azure Service Principal Skill

This skill creates and configures Azure Service Principals with workload identity federation for secure, passwordless authentication.

## Overview

Creates an Entra ID App Registration and Service Principal configured for workload identity federation (no secrets). Grants Contributor role on resource groups and prepares for Cognitive Services User role assignment on AI Services resources.

## Important: Federated Credentials

**Federated credentials are NOT created by this skill.** They must be created AFTER Azure DevOps service connections are set up, using the actual issuer/subject values from the service connection.

See: [LESSONS_LEARNED.md](../starter-execution/LESSONS_LEARNED.md) #1

## Usage

```powershell
# Using configuration file
scripts/create-service-principal.ps1 -UseConfig

# Using direct parameters
scripts/create-service-principal.ps1 `
    -ServicePrincipalName "sp-aif-demo" `
    -ResourceGroupBaseName "rg-aif-demo" `
    -Environment "all"
```

## Key Features

- **Workload Identity Federation**: No secrets/passwords required
- **Multi-environment RBAC**: Grants access across dev, test, prod resource groups
- **Contributor role**: Assigned at resource group level for resource management
- **Configuration update**: Automatically updates starter-config.json with AppId
- **App info export**: Saves detailed information to JSON file

## RBAC Permissions Granted

1. **Contributor** role on resource group (for resource management)
2. **Cognitive Services User** role on AI Services (assigned by ai-foundry-resources skill)

## Parameters

- `ServicePrincipalName`: Name for the Service Principal and App Registration
- `ResourceGroupBaseName`: Base name for resource groups to grant access to
- `Environment`: Target environment(s) - 'dev', 'test', 'prod', or 'all'
- `UseConfig`: Load configuration from starter-config.json
- `UpdateConfig`: Update starter-config.json with SP details (default: true)
- `OutputFormat`: 'text' or 'json'

## Script Location

`scripts/create-service-principal.ps1`
