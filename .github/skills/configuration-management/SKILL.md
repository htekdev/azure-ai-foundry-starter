---
name: configuration-management
description: Manages centralized configuration for Azure DevOps migration including organization names, resource names, project names, and all other customizable values. Use this skill first to set up configuration, or when you need to retrieve/update migration settings.
---

# Configuration Management for Azure DevOps Migration

This skill manages all configurable names, URLs, and settings used throughout the migration process. It eliminates hardcoded values and provides a single source of truth for all migration configuration.

## When to use this skill

Use this skill when you need to:
- Set up initial migration configuration
- Update organization or project names
- Define Azure resource names
- Configure variable group names
- Retrieve configuration values for scripts
- Validate configuration completeness
- Reset or regenerate configuration

## Configuration file location

All configuration is stored in:
```
.github/skills/migration-config.json
```

This file is used by all other skills and should be created before starting the migration.

## Quick start

### Interactive configuration setup

Run the configuration script to interactively set up all values:

```powershell
# Run interactive configuration
./.github/skills/configuration-management/configure-migration.ps1 -Interactive

# Or with Copilot
# "@workspace Set up my migration configuration"
```

### Load configuration in scripts

Use the helper function to load configuration in any PowerShell script:

```powershell
# Source the configuration functions
. ./.github/skills/configuration-management/config-functions.ps1

# Load configuration
$config = Get-MigrationConfig

# Access values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$rgName = $config.azure.resourceGroupName
```

## Configuration structure

The configuration file contains the following sections:

### Azure DevOps settings
- Organization URL
- Project name
- Source repository name
- Target repository names
- Default branch name

### Azure settings
- Subscription ID
- Tenant ID
- Resource group name
- Location/region
- ML workspace name
- OpenAI service name

### Service Principal settings
- Service principal name
- Application ID (stored after creation)
- Role assignments

### Pipeline settings
- Variable group names
- Service connection names
- Pipeline naming conventions
- Agent pool settings

### Migration settings
- Backup location
- Temporary working directory
- Log file location
- Validation preferences

## Interactive configuration

### Step 1: Run configuration script

```powershell
cd .github/skills/configuration-management
./configure-migration.ps1 -Interactive
```

The script will prompt for each value:

```
=== Azure DevOps Migration Configuration ===

[Azure DevOps Settings]
? Enter Azure DevOps organization URL: https://dev.azure.com/northwind-systems
? Enter project name: repository-migration-project
? Enter source repository name: monolithic-ml-repo
? Enter default branch name [main]: main

[Azure Settings]
? Enter Azure subscription ID: 12345678-1234-1234-1234-123456789abc
? Enter Azure tenant ID: 87654321-4321-4321-4321-cba987654321
? Enter resource group name: northwind-ml-rg
? Enter Azure region [eastus]: eastus
? Enter ML workspace name: northwind-ml-workspace
? Enter OpenAI service name: northwind-openai

[Target Repository Structure]
? Enter target repository names (comma-separated): ml-training-pipeline,ml-inference-service,ml-data-processing,ml-model-registry,shared-libraries,infrastructure,documentation

[Service Principal Settings]
? Enter service principal name: migration-sp
? Assign Contributor role? [Y/n]: Y

[Pipeline Settings]
? Enter ML variable group name: ML-Configuration
? Enter OpenAI variable group name: OpenAI-Configuration
? Enter service connection name: Azure-Production
? Enter agent pool [Azure Pipelines]: Azure Pipelines

[Migration Settings]
? Enter backup directory [./backups]: ./backups
? Enter working directory [./migration-temp]: ./migration-temp
? Enable verbose logging? [Y/n]: Y

✅ Configuration saved to: .github/skills/migration-config.json
```

### Step 2: Validate configuration

```powershell
# Validate configuration completeness
./configure-migration.ps1 -Validate

# Sample output:
# ✅ Azure DevOps configuration: Complete
# ✅ Azure configuration: Complete
# ✅ Target repositories: 7 defined
# ✅ Pipeline settings: Complete
# ⚠️  Service Principal App ID: Not set (will be populated after creation)
```

### Step 3: View current configuration

```powershell
# Display current configuration
./configure-migration.ps1 -Show

# Display specific section
./configure-migration.ps1 -Show -Section "azureDevOps"
```

## Programmatic configuration

### Create configuration from script

```powershell
# Create configuration object
$config = @{
    azureDevOps = @{
        organizationUrl = "https://dev.azure.com/northwind-systems"
        projectName = "repository-migration-project"
        sourceRepository = "monolithic-ml-repo"
        targetRepositories = @(
            "ml-training-pipeline",
            "ml-inference-service",
            "ml-data-processing",
            "ml-model-registry",
            "shared-libraries",
            "infrastructure",
            "documentation"
        )
        defaultBranch = "main"
    }
    azure = @{
        subscriptionId = "12345678-1234-1234-1234-123456789abc"
        tenantId = "87654321-4321-4321-4321-cba987654321"
        resourceGroupName = "northwind-ml-rg"
        location = "eastus"
        mlWorkspaceName = "northwind-ml-workspace"
        openAIServiceName = "northwind-openai"
    }
    servicePrincipal = @{
        name = "migration-sp"
        appId = $null  # Populated after creation
        roles = @("Contributor")
    }
    pipelines = @{
        variableGroups = @{
            mlConfig = "ML-Configuration"
            openAIConfig = "OpenAI-Configuration"
        }
        serviceConnections = @{
            azure = "Azure-Production"
        }
        agentPool = "Azure Pipelines"
        pipelinePrefix = ""
        pipelineSuffix = "-CI"
    }
    migration = @{
        backupDirectory = "./backups"
        workingDirectory = "./migration-temp"
        logFile = "./migration.log"
        verboseLogging = $true
        validateBeforeExecute = $true
    }
    metadata = @{
        version = "1.0"
        createdDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        lastModified = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

# Save configuration
$config | ConvertTo-Json -Depth 10 | Set-Content -Path ".github/skills/migration-config.json"
```

### Update specific values

```powershell
# Source configuration functions
. ./.github/skills/configuration-management/config-functions.ps1

# Load current configuration
$config = Get-MigrationConfig

# Update specific values
$config.azure.location = "westus"
$config.pipelines.agentPool = "Self-Hosted"

# Save updated configuration
Set-MigrationConfig -Config $config
```

## Configuration helper functions

### Get-MigrationConfig

Loads the migration configuration from file:

```powershell
# Load configuration
$config = Get-MigrationConfig

# Load with error handling
$config = Get-MigrationConfig -ErrorAction SilentlyContinue
if (-not $config) {
    Write-Error "Configuration not found. Run: ./configure-migration.ps1 -Interactive"
    exit 1
}
```

### Set-MigrationConfig

Saves the migration configuration to file:

```powershell
# Save configuration
Set-MigrationConfig -Config $config

# Save with backup
Set-MigrationConfig -Config $config -CreateBackup
```

### Get-ConfigValue

Retrieves a specific configuration value by path:

```powershell
# Get single value
$org = Get-ConfigValue -Path "azureDevOps.organizationUrl"
$rgName = Get-ConfigValue -Path "azure.resourceGroupName"

# Get with default
$branch = Get-ConfigValue -Path "azureDevOps.defaultBranch" -Default "main"
```

### Set-ConfigValue

Updates a specific configuration value:

```powershell
# Set single value
Set-ConfigValue -Path "servicePrincipal.appId" -Value "12345678-abcd-1234-abcd-123456789abc"

# Multiple updates
Set-ConfigValue -Path "azure.location" -Value "westus"
Set-ConfigValue -Path "migration.verboseLogging" -Value $false
```

### Test-ConfigurationComplete

Validates that all required configuration is present:

```powershell
# Validate configuration
$isValid = Test-ConfigurationComplete

if (-not $isValid) {
    Write-Error "Configuration is incomplete. Please run: ./configure-migration.ps1 -Interactive"
    exit 1
}

# Validate specific sections
$isValid = Test-ConfigurationComplete -Sections @("azureDevOps", "azure")
```

## Auto-discovery from existing environment

The configuration script can discover values from your current Azure/Azure DevOps environment:

```powershell
# Auto-discover configuration
./configure-migration.ps1 -AutoDiscover

# This will:
# ✅ Detect current Azure subscription and tenant
# ✅ List available Azure DevOps organizations
# ✅ Find existing resource groups
# ✅ Discover ML workspaces and OpenAI services
# ✅ List existing service principals
# ⚠️  Prompt for any values that can't be auto-detected
```

### Auto-discovery process

```powershell
# 1. Detect Azure context
$subscription = az account show | ConvertFrom-Json
$config.azure.subscriptionId = $subscription.id
$config.azure.tenantId = $subscription.tenantId

# 2. List Azure DevOps organizations
$orgs = az devops project list --query "value[].name" -o tsv
# User selects from list

# 3. Discover Azure resources
$resourceGroups = az group list --query "[].name" -o tsv
$mlWorkspaces = az ml workspace list --query "[].name" -o tsv
$openAIServices = az cognitiveservices account list --query "[?kind=='OpenAI'].name" -o tsv

# 4. Discover service principals
$servicePrincipals = az ad sp list --all --query "[].displayName" -o tsv

# 5. Prompt for missing values
if (-not $config.azureDevOps.sourceRepository) {
    $repos = az repos list --query "[].name" -o tsv
    # User selects source repository
}
```

## Configuration templates

### Template: Single ML repository migration

```json
{
  "azureDevOps": {
    "organizationUrl": "https://dev.azure.com/YOUR_ORG",
    "projectName": "YOUR_PROJECT",
    "sourceRepository": "ml-monorepo",
    "targetRepositories": [
      "ml-training",
      "ml-inference",
      "ml-shared"
    ],
    "defaultBranch": "main"
  },
  "azure": {
    "resourceGroupName": "ml-rg",
    "location": "eastus",
    "mlWorkspaceName": "ml-workspace",
    "openAIServiceName": "ml-openai"
  }
}
```

### Template: Multi-team enterprise migration

```json
{
  "azureDevOps": {
    "organizationUrl": "https://dev.azure.com/enterprise-org",
    "projectName": "data-science",
    "sourceRepository": "legacy-ml-platform",
    "targetRepositories": [
      "team-alpha-training",
      "team-alpha-inference",
      "team-beta-training",
      "team-beta-inference",
      "shared-libraries",
      "shared-infrastructure",
      "documentation"
    ],
    "defaultBranch": "main"
  },
  "azure": {
    "resourceGroupName": "enterprise-ml-prod-rg",
    "location": "eastus2",
    "mlWorkspaceName": "enterprise-ml-prod",
    "openAIServiceName": "enterprise-openai-prod"
  },
  "pipelines": {
    "pipelinePrefix": "ds-",
    "pipelineSuffix": "-prod-ci"
  }
}
```

## Integration with other skills

All other skills should load configuration instead of using hardcoded values:

### In environment-validation

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-MigrationConfig

# Use configuration values
./validation-script.ps1 `
  -OrganizationUrl $config.azureDevOps.organizationUrl `
  -ProjectName $config.azureDevOps.projectName `
  -ResourceGroup $config.azure.resourceGroupName `
  -MLWorkspace $config.azure.mlWorkspaceName `
  -OpenAIService $config.azure.openAIServiceName
```

### In resource-creation

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-MigrationConfig

# Create resources using configuration
./create-resources.ps1 `
  -ResourceGroupName $config.azure.resourceGroupName `
  -Location $config.azure.location `
  -ServicePrincipalName $config.servicePrincipal.name `
  -MLWorkspaceName $config.azure.mlWorkspaceName `
  -OpenAIServiceName $config.azure.openAIServiceName
```

### In migration-execution

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-MigrationConfig

# Execute migration using configuration
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$sourceRepo = $config.azureDevOps.sourceRepository
$newStructure = $config.azureDevOps.targetRepositories
```

## Best practices

### Configuration management
- ✅ Create configuration before starting migration
- ✅ Validate configuration after creation
- ✅ Back up configuration file
- ✅ Use version control for configuration
- ❌ Don't commit sensitive values (use Azure Key Vault)
- ✅ Document any custom naming conventions

### Naming conventions
- Use consistent prefixes/suffixes
- Follow Azure naming rules
- Include environment indicators (dev, test, prod)
- Keep names under Azure length limits
- Use lowercase for Azure resources

### Security
- Store configuration file securely
- Don't commit Service Principal credentials
- Use placeholders for sensitive values
- Reference Azure Key Vault for secrets
- Rotate credentials after migration

## Troubleshooting

### Configuration file not found

```powershell
# Create new configuration
./configure-migration.ps1 -Interactive

# Or copy from template
Copy-Item ".github/skills/configuration-management/config-template.json" ".github/skills/migration-config.json"
```

### Invalid configuration format

```powershell
# Validate JSON syntax
Get-Content ".github/skills/migration-config.json" | ConvertFrom-Json

# If invalid, restore from backup
Copy-Item ".github/skills/migration-config.json.backup" ".github/skills/migration-config.json"
```

### Missing required values

```powershell
# Check what's missing
./configure-migration.ps1 -Validate

# Update missing values
./configure-migration.ps1 -Update -Section "azureDevOps"
```

## Related resources

- [configure-migration.ps1](./configure-migration.ps1) - Configuration setup script
- [config-functions.ps1](./config-functions.ps1) - Helper functions
- [config-template.json](./config-template.json) - Configuration template
- [COPILOT_EXECUTION_GUIDE.md](../../../COPILOT_EXECUTION_GUIDE.md) - Migration guide
