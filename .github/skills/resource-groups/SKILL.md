---
name: resource-groups
description: Creates Azure Resource Groups for multi-environment deployments (dev, test, prod). Use when you need to create or manage Azure resource groups with proper tagging and environment organization for Azure AI Foundry projects.
license: Apache-2.0
---

# Azure Resource Groups Skill

This skill handles creation and management of Azure Resource Groups across multiple environments.

## Overview

Creates resource groups with standardized naming conventions and tags for dev, test, and prod environments. Supports both configuration-driven and parameter-based execution.

## Usage

The skill provides a PowerShell script that creates resource groups with appropriate environment tags:

```powershell
# Using configuration file
scripts/create-resource-groups.ps1 -UseConfig -Environment "all"

# Using direct parameters
scripts/create-resource-groups.ps1 `
    -ResourceGroupBaseName "rg-aif-demo" `
    -Location "eastus" `
    -Environment "dev"
```

## Key Features

- **Multi-environment support**: Creates resource groups for dev, test, and prod
- **Idempotent operations**: Checks for existing resources before creation
- **Standardized tagging**: Applies Environment, Project, and ManagedBy tags
- **Configuration integration**: Loads settings from starter-config.json
- **JSON output option**: Supports both text and JSON output formats

## Parameters

- `ResourceGroupBaseName`: Base name for resource groups (appended with -dev, -test, -prod)
- `Location`: Azure region (default: eastus)
- `Environment`: Target environment(s) - 'dev', 'test', 'prod', or 'all'
- `UseConfig`: Load configuration from starter-config.json
- `OutputFormat`: 'text' or 'json'

## Script Location

`scripts/create-resource-groups.ps1`
