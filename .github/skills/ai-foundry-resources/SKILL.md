---
name: ai-foundry-resources
description: Creates Azure AI Foundry resources including AI Services (kind AIServices) and AI Foundry Projects for multi-environment deployments. Configures RBAC permissions for Service Principals. Use when provisioning Azure AI Services and AI Foundry Projects for development, testing, or production environments.
license: Apache-2.0
---

# Azure AI Foundry Resources Skill

This skill creates Azure AI Services resources and AI Foundry Projects across multiple environments.

## Overview

Creates Azure AI Services resources (kind: AIServices) with custom domains and AI Foundry Projects for each environment. Also configures RBAC permissions for Service Principals to access the AI Services resources.

**Important**: This creates AI Services resources (kind: AIServices), NOT ML Workspace hubs. Projects are created using 'az cognitiveservices account project create'.

## Usage

```powershell
# Using configuration file
scripts/create-ai-foundry-resources.ps1 -UseConfig -Environment "all"

# Using direct parameters  
scripts/create-ai-foundry-resources.ps1 `
    -ResourceGroupBaseName "rg-aif-demo" `
    -AIProjectBaseName "aif-demo" `
    -Location "eastus" `
    -Environment "dev" `
    -ServicePrincipalAppId "<app-id>"
```

## Key Features

- **AI Services creation**: Creates AIServices resources with custom domains
- **Project creation**: Creates AI Foundry Projects under each AI Services resource
- **RBAC configuration**: Assigns Cognitive Services User role to Service Principal
- **Endpoint capture**: Extracts and stores project endpoints
- **Configuration update**: Updates starter-config.json with project endpoints
- **Multi-environment**: Supports dev, test, prod deployments

## Resources Created

For each environment:
1. **AI Services Resource**: `aif-foundry-{env}` (kind: AIServices, SKU: S0)
2. **AI Foundry Project**: `aif-project-{env}`
3. **RBAC Assignment**: Cognitive Services User role on AI Services resource

## RBAC Permissions

Per [LESSONS_LEARNED.md](../starter-execution/LESSONS_LEARNED.md) #11:
- **Cognitive Services User** role must be granted on AI Services resources specifically, not just resource groups
- This skill handles this assignment after resource creation

## Parameters

- `ResourceGroupBaseName`: Base name for resource groups
- `AIProjectBaseName`: Base name for AI Services resources and projects
- `Location`: Azure region (default: eastus)
- `Environment`: Target environment(s) - 'dev', 'test', 'prod', or 'all'
- `ServicePrincipalAppId`: AppId of Service Principal to grant access
- `UseConfig`: Load configuration from starter-config.json
- `UpdateConfig`: Update starter-config.json with endpoints (default: true)
- `OutputFormat`: 'text' or 'json'

## Script Location

`scripts/create-ai-foundry-resources.ps1`
