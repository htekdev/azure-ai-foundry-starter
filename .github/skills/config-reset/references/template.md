# Config Template Reference

This document provides the complete template structure for `starter-config.json`.

## Default Template

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
        "resourceGroup": "",
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

## Field Descriptions

### Azure DevOps Section

- **organizationUrl**: Full URL to Azure DevOps organization (e.g., `https://dev.azure.com/myorg`)
- **projectName**: Name of the Azure DevOps project

### Azure Section

- **subscriptionId**: Azure subscription GUID
- **subscriptionName**: Human-readable subscription name
- **tenantId**: Azure AD tenant GUID
- **resourceGroup**: Name of the resource group
- **location**: Azure region (default: `eastus`)

### AI Foundry Section

Each environment (dev, test, prod) has:
- **projectEndpoint**: Full endpoint URL for the AI Foundry project

### Service Principal Section

- **appId**: Application (client) ID of the service principal
- **tenantId**: Azure AD tenant GUID (typically same as azure.tenantId)

### Metadata Section

- **version**: Configuration schema version (always "2.0")
- **description**: Configuration description
- **lastModified**: Last modification date (YYYY-MM-DD format)

## Version History

### Version 2.0 (Current)

- Separated environments into dev/test/prod
- Added metadata section
- Standardized project endpoint format
- Added location field with default

### Version 1.0 (Legacy)

- Single environment configuration
- No metadata section
- Different endpoint format
