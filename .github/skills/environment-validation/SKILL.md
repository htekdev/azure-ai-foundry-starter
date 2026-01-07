---
name: environment-validation
description: Validates the Azure DevOps migration environment prerequisites including tool versions, authentication status, connectivity, and resource availability. Use this when setting up or troubleshooting migration environment, checking prerequisites, or validating configuration before starting migration.
---

# Environment Validation for Azure DevOps Migration

This skill validates that your environment meets all prerequisites for executing the Azure DevOps repository migration process defined in COPILOT_EXECUTION_GUIDE.md.

## When to use this skill

Use this skill when you need to:
- Validate environment setup before starting migration
- Troubleshoot migration environment issues
- Verify tool installations and versions
- Check authentication and connectivity
- Confirm Azure resource availability
- Generate a comprehensive environment health report

## Validation checklist

The skill validates the following components:

### 1. Required Tools
- **Git**: Version 2.30 or higher
- **Azure CLI (az)**: Version 2.50 or higher  
- **PowerShell**: Version 7.0 or higher
- **Python**: Version 3.11 or higher
- **Azure DevOps CLI Extension**: Installed and functional

### 2. Authentication
- Azure CLI authentication status (`az account show`)
- Bearer token availability (`az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798`)
- Token expiration time (should have at least 30 minutes remaining)
- Service Principal credentials (if using automated authentication)

### 3. Azure DevOps Connectivity
- Organization access (`az devops project list`)
- Repository list access
- Pipeline list access
- Service connection permissions

### 4. Azure Resources
- Resource group existence and access
- Azure Machine Learning workspace availability
- Azure OpenAI service availability
- Required RBAC permissions

## Validation process

Follow these steps to validate the environment:

### Step 1: Run the validation script

**💡 Recommended**: Use configuration management for centralized settings:

```powershell
# First, set up configuration (if not already done)
cd .github/skills/configuration-management
./configure-migration.ps1 -Interactive

# Then run validation using saved configuration
cd .github/skills/environment-validation
./validation-script.ps1 -UseConfig
```

**Alternative**: Provide parameters directly:

```powershell
cd .github/skills/environment-validation
./validation-script.ps1 `
  -OrganizationUrl "https://dev.azure.com/YOUR_ORG" `
  -ProjectName "YOUR_PROJECT" `
  -ResourceGroup "YOUR_RG" `
  -MLWorkspace "YOUR_WORKSPACE" `
  -OpenAIService "YOUR_OPENAI"
```

The script will:
1. Check all tool versions
2. Verify authentication status
3. Test Azure DevOps connectivity
4. Check Azure resource availability
5. Generate a detailed report

### Step 2: Review validation results

The script outputs a structured report with:
- ✅ **PASS**: Component meets requirements
- ⚠️  **WARNING**: Component works but may need attention
- ❌ **FAIL**: Component requires action before proceeding

### Step 3: Address failures

For any failures, refer to the troubleshooting guide below.

## Troubleshooting common issues

### Git not found or wrong version
```powershell
# Install Git for Windows
winget install --id Git.Git -e --source winget

# Verify installation
git --version
```

### Azure CLI not found or wrong version
```powershell
# Install Azure CLI
winget install --id Microsoft.AzureCLI -e --source winget

# Verify installation
az --version
```

### PowerShell version too old
```powershell
# Install PowerShell 7+
winget install --id Microsoft.PowerShell -e --source winget

# Launch PowerShell 7
pwsh
```

### Python not found or wrong version
```powershell
# Install Python 3.11+
winget install --id Python.Python.3.12 -e --source winget

# Verify installation
python --version
```

### Azure DevOps extension not installed
```powershell
# Install the extension
az extension add --name azure-devops

# Verify installation
az extension list --query "[?name=='azure-devops'].version" -o tsv
```

### Authentication failed
```powershell
# Login to Azure
az login

# Set default organization (optional)
az devops configure --defaults organization=https://dev.azure.com/YOUR_ORG project=YOUR_PROJECT

# Test bearer token
az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798
```

### Token expired
```powershell
# Refresh token
az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --only-show-errors

# Verify new expiration time
az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "expiresOn" -o tsv
```

### Azure DevOps connectivity issues
```powershell
# Check if you can list projects
az devops project list --organization https://dev.azure.com/YOUR_ORG

# Check repository access
az repos list --organization https://dev.azure.com/YOUR_ORG --project YOUR_PROJECT

# If access denied, verify permissions in Azure DevOps portal
```

### Azure resource not found
```powershell
# List available resource groups
az group list --query "[].{Name:name, Location:location}" -o table

# Check if ML workspace exists
az ml workspace show --resource-group YOUR_RG --workspace-name YOUR_WORKSPACE

# Check if OpenAI service exists
az cognitiveservices account show --resource-group YOUR_RG --name YOUR_OPENAI_SERVICE
```

## Expected output format

The validation script generates output in the following format:

```
=== Environment Validation Report ===
Generated: 2026-01-07 10:30:00

[Tools]
✅ Git: 2.43.0 (Required: 2.30+)
✅ Azure CLI: 2.55.0 (Required: 2.50+)
✅ PowerShell: 7.4.1 (Required: 7.0+)
✅ Python: 3.12.1 (Required: 3.11+)
✅ Azure DevOps Extension: 1.0.1

[Authentication]
✅ Azure Login: Authenticated as user@domain.com
✅ Bearer Token: Valid (expires in 58 minutes)
✅ Token Resource: 499b84ac-1321-427f-aa17-267ca6975798

[Azure DevOps Connectivity]
✅ Organization: https://dev.azure.com/northwind-systems
✅ Project Access: repository-migration-project
✅ Repository List: 15 repositories found
✅ Pipeline List: 8 pipelines found

[Azure Resources]
✅ Resource Group: northwind-ml-rg (eastus)
✅ ML Workspace: northwind-ml-workspace
✅ OpenAI Service: northwind-openai
⚠️  RBAC Permissions: Read-only (may need Contributor for some operations)

[Summary]
Status: READY ✅
Warnings: 1
Failures: 0

You can proceed with the migration process.
For detailed instructions, see COPILOT_EXECUTION_GUIDE.md
```

## Integration with migration workflow

This skill should be used as the first step in the migration process:

1. **Before migration**: Run validation to ensure all prerequisites are met
2. **During migration**: Re-run if encountering authentication or connectivity issues
3. **After migration**: Validate that resources were created successfully

## Automation tips

For GitHub Copilot execution:
- The validation script can be run non-interactively with parameters
- Exit codes indicate success (0) or failure (non-zero)
- JSON output format available with `-OutputFormat json` flag
- Can be integrated into CI/CD pipelines

Example Copilot prompt:
```
@workspace Validate my environment for Azure DevOps migration using the environment-validation skill
```

## Related resources

- [COPILOT_EXECUTION_GUIDE.md](../../../COPILOT_EXECUTION_GUIDE.md) - Complete migration process
- [validation-script.ps1](./validation-script.ps1) - PowerShell validation script
- [examples/validation-report.json](./examples/validation-report.json) - Sample JSON output
- [AZ_DEVOPS_CLI_REFERENCE.md](../../../AZ_DEVOPS_CLI_REFERENCE.md) - Azure DevOps CLI commands

## Best practices

- Run validation before starting any migration work
- Keep tools updated to latest versions
- Refresh authentication tokens before long-running operations
- Document any warnings for future reference
- Save validation reports for audit trails
- Re-validate after making environment changes
