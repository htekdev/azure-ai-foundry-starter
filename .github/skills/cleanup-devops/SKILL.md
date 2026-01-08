---
name: cleanup-devops
description: Cleans up Azure DevOps resources (repositories, service connections, variable groups, pipelines) and resets configuration files. Use when you need to remove Azure DevOps artifacts after testing or to prepare for a fresh deployment of the Azure AI Foundry Starter template.
---

# Cleanup Azure DevOps Resources

## Overview

This skill automates the cleanup of Azure DevOps resources created by the Azure AI Foundry Starter template, including repositories, service connections, variable groups, and pipelines. It also provides options to reset the configuration file to its template state.

## Quick Start

Run the cleanup script interactively:

```powershell
.\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1
```

## Core Capabilities

### 1. Azure DevOps Resource Deletion

Removes all Azure DevOps artifacts created during deployment:

- **Repository**: azure-ai-foundry-app
- **Service Connections**: azure-foundry-dev, azure-foundry-test, azure-foundry-prod
- **Variable Groups**: foundry-dev-vars, foundry-test-vars, foundry-prod-vars
- **Pipelines**: All pipelines matching the foundry pattern

### 2. Configuration Reset

Resets `starter-config.json` to template state while creating a backup:

- Creates `.backup` file before resetting
- Restores empty template structure
- Preserves original for reference

### 3. Safety Features

- **Dry Run Mode**: Preview deletions without making changes (`-DryRun`)
- **Confirmation Required**: Must type 'DELETE' to proceed (unless `-Force`)
- **Selective Cleanup**: Choose specific resources (`-OnlyConfig`, `-SkipConfig`)
- **Error Handling**: Continues even if some resources fail to delete

## Usage Patterns

### Preview Before Deleting

```powershell
# See what would be deleted
.\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1 -DryRun
```

### Complete Cleanup

```powershell
# Interactive with confirmation
.\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1

# Force without confirmation
.\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1 -Force
```

### Selective Cleanup

```powershell
# Only reset config file (keep Azure DevOps resources)
.\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1 -OnlyConfig

# Only clean Azure DevOps (keep config file)
.\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1 -SkipConfig
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-ConfigPath` | String | Path to starter-config.json (default: ./starter-config.json) |
| `-Force` | Switch | Skip confirmation prompts |
| `-DryRun` | Switch | Preview deletions without making changes |
| `-SkipConfig` | Switch | Skip resetting the configuration file |
| `-OnlyConfig` | Switch | Only reset config file, skip Azure DevOps cleanup |

## Complete Cleanup Workflow

For a full cleanup of the Azure AI Foundry Starter deployment:

1. **Delete Azure Resources**: Run the cleanup-resources skill first
   ```powershell
   .\.github\skills\cleanup-resources\scripts\cleanup-resources.ps1
   ```

2. **Verify Azure Deletion**: Check Azure Portal for completion

3. **Clean Azure DevOps**: Run this skill
   ```powershell
   .\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1
   ```

4. **Verify DevOps**: Check Azure DevOps portal

5. **Fresh Start**: Repository is now clean for new deployment

## Prerequisites

- Azure DevOps CLI installed and configured
- Logged in to Azure DevOps: `az devops login`
- Project Administrator or higher permissions in Azure DevOps

## Troubleshooting

### Authentication Issues

If you see "Not logged in to Azure DevOps":
```powershell
az devops login
```

### Permission Denied

You need Project Administrator or higher permissions to delete these resources. Contact your Azure DevOps admin.

### Repository Deletion Failed

Repository deletion may fail if:
- The script is running from within the repository
- Organization policies restrict deletion
- Manual deletion required from Azure DevOps portal

If automatic deletion fails, manually delete from:
`https://dev.azure.com/{organization}/{project}/_settings/repositories`

## Notes

- **Pipeline History**: Deleted pipelines lose all run history
- **Service Connections**: Authentication credentials are permanently removed
- **Config Backup**: Always created before resetting configuration
- **Repository Limitation**: Cannot delete the repository if running from within it
