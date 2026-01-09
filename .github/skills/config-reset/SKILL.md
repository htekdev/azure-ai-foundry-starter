---
name: config-reset
description: Resets starter-config.json to its default template state with automatic backup. Use when you need to clear all configuration values and start fresh, when the config file becomes corrupted, after testing/cleanup, or to prepare for a new deployment of the Azure AI Foundry Starter template.
---

# Config Reset

## Overview

This skill resets the `starter-config.json` file to its default template state, clearing all configuration values while preserving the proper structure. It automatically creates timestamped backups before resetting, ensuring no data is lost.

## Quick Start

Reset the config interactively:

```powershell
.\.github\skills\config-reset\scripts\reset-config.ps1
```

## Core Capabilities

### 1. Template State Reset

Resets the configuration file to default template with:

- **Empty values**: All fields set to empty strings (except metadata)
- **Proper structure**: Maintains correct JSON schema
- **Updated metadata**: Sets lastModified to current date
- **Default location**: Uses eastus as default Azure region

### 2. Automatic Backup

Creates timestamped backup before resetting:

- **Format**: `starter-config.json.backup.yyyyMMdd-HHmmss`
- **Location**: Same directory as config file
- **Preserved**: Original config saved for reference

### 3. Safety Features

- **Dry Run Mode**: Preview reset without making changes (`-DryRun`)
- **Confirmation Required**: Must type 'RESET' to proceed (unless `-Force`)
- **Backup Protection**: Always creates backup before resetting
- **Error Handling**: Graceful handling of missing or corrupted files

## Usage Patterns

### Preview Reset

```powershell
# See what will be reset
.\.github\skills\config-reset\scripts\reset-config.ps1 -DryRun
```

### Interactive Reset

```powershell
# Reset with confirmation prompt
.\.github\skills\config-reset\scripts\reset-config.ps1

# Reset without confirmation
.\.github\skills\config-reset\scripts\reset-config.ps1 -Force
```

### Custom Paths

```powershell
# Specify custom config path
.\.github\skills\config-reset\scripts\reset-config.ps1 -ConfigPath ".\custom-config.json"

# Specify custom backup location
.\.github\skills\config-reset\scripts\reset-config.ps1 -BackupPath ".\backups\config.backup"
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-ConfigPath` | String | Path to starter-config.json (default: ./starter-config.json) |
| `-BackupPath` | String | Custom backup location (default: auto-generated with timestamp) |
| `-Force` | Switch | Skip confirmation prompt |
| `-DryRun` | Switch | Preview reset without making changes |

## Template Structure

After reset, the config file contains:

```json
{
    "azureDevOps": {
        "organizationUrl": "",
        "projectName": ""
    },
    "azure": {
        "subscriptionId": "",
        "subscriptionName": "",
        "tenantId": "",
        "location": "eastus",
        "aiFoundry": {
            "dev": {
                "projectEndpoint": ""
            },
            "test": {
                "projectEndpoint": ""
            },
            "prod": {
                "projectEndpoint": ""
            }
        }
    },
    "servicePrincipal": {
        "appId": "",
        "tenantId": ""
    },
    "metadata": {
        "version": "2.0",
        "description": "Azure AI Foundry Starter Template Configuration",
        "lastModified": "YYYY-MM-DD"
    }
}
```

## Common Scenarios

### After Complete Cleanup

Reset config after using cleanup skills:

```powershell
# 1. Clean Azure resources
.\.github\skills\cleanup-resources\scripts\cleanup-resources.ps1

# 2. Clean Azure DevOps
.\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1

# 3. Reset config
.\.github\skills\config-reset\scripts\reset-config.ps1
```

### Fix Corrupted Config

If the config file becomes corrupted:

```powershell
# Reset to template state
.\.github\skills\config-reset\scripts\reset-config.ps1 -Force

# Then reconfigure
# Use configuration-management skill to set values
```

### Prepare for New Deployment

Before starting a fresh deployment:

```powershell
# Reset config to start clean
.\.github\skills\config-reset\scripts\reset-config.ps1

# Then run initial setup
# Follow deployment guide to populate values
```

## Integration with Other Skills

### Configuration Management

After reset, use configuration-management skill to populate values:

1. Reset config (this skill)
2. Use configuration-management to set values
3. Validate with environment-validation skill

### Complete Cleanup Workflow

For full cleanup and reset:

1. **cleanup-resources**: Delete Azure resources
2. **cleanup-devops**: Delete Azure DevOps resources  
3. **config-reset**: Reset configuration (this skill)
4. Ready for fresh deployment

## Prerequisites

- PowerShell 5.1 or higher
- Write access to config file directory
- Sufficient disk space for backup

## Troubleshooting

### File Not Found

If config file doesn't exist, the script creates a new template:
```
No existing config file found - creating new template
```

### Permission Denied

Ensure you have write permissions:
```powershell
# Check permissions
Get-Acl .\starter-config.json

# Run as administrator if needed
```

### Backup Failed

If backup creation fails, the script will warn but continue. Manual backup recommended:
```powershell
Copy-Item .\starter-config.json .\starter-config.json.manual-backup
```

## Notes

- **Version Compatibility**: Always resets to version "2.0" format
- **Backup Retention**: Script does not auto-delete old backups
- **No Validation**: Script does not validate existing config before reset
- **Clean State**: All configuration values cleared (except metadata and default location)
