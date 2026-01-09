# Configuration Management API Reference

Complete reference for all configuration management functions.

## Get-StarterConfig

Loads the starter configuration from file.

**Syntax:**
```powershell
Get-StarterConfig [-Path <string>]
```

**Parameters:**
- `Path` (optional) - Custom path to configuration file. Defaults to `../../../starter-config.json`

**Returns:** PSCustomObject containing the configuration, or `$null` if not found

**Examples:**
```powershell
# Load default configuration
$config = Get-StarterConfig

# Load from custom path
$config = Get-StarterConfig -Path "custom-config.json"

# With error handling
$config = Get-StarterConfig
if (-not $config) {
    Write-Error "Configuration not found"
    exit 1
}
```

## Set-StarterConfig

Saves the configuration to file with optional backup.

**Syntax:**
```powershell
Set-StarterConfig -Config <PSCustomObject> [-Path <string>] [-CreateBackup]
```

**Parameters:**
- `Config` (required) - Configuration object to save
- `Path` (optional) - Custom path to configuration file
- `CreateBackup` (optional) - Creates .backup file before saving

**Returns:** Boolean indicating success

**Examples:**
```powershell
# Save configuration
$config = Get-StarterConfig
$config.azure.location = "westus2"
Set-StarterConfig -Config $config

# Save with backup
Set-StarterConfig -Config $config -CreateBackup

# Save to custom path
Set-StarterConfig -Config $config -Path "custom-config.json"
```

**Notes:**
- Automatically updates `metadata.lastModified` timestamp
- Creates parent directories if they don't exist

## Get-ConfigValue

Retrieves a specific configuration value using dot notation path.

**Syntax:**
```powershell
Get-ConfigValue -Path <string> [-Default <object>] [-ConfigPath <string>]
```

**Parameters:**
- `Path` (required) - Dot-notation path (e.g., "azure.location")
- `Default` (optional) - Default value if path doesn't exist
- `ConfigPath` (optional) - Custom configuration file path

**Returns:** The value at the specified path, or default value

**Examples:**
```powershell
# Get single values
$org = Get-ConfigValue -Path "azureDevOps.organizationUrl"
$projectName = Get-ConfigValue -Path "naming.projectName"
$devEndpoint = Get-ConfigValue -Path "azure.aiFoundry.dev.projectEndpoint"

# Derive resource group from project name
$rgName = "rg-$projectName-dev"

# Get with default
$location = Get-ConfigValue -Path "azure.location" -Default "eastus"
$appId = Get-ConfigValue -Path "servicePrincipal.appId" -Default "NOT_SET"
```

## Set-ConfigValue

Updates a specific configuration value using dot notation path.

**Syntax:**
```powershell
Set-ConfigValue -Path <string> -Value <object> [-ConfigPath <string>]
```

**Parameters:**
- `Path` (required) - Dot-notation path (e.g., "azure.location")
- `Value` (required) - New value to set
- `ConfigPath` (optional) - Custom configuration file path

**Returns:** Boolean indicating success

**Examples:**
```powershell
# Update single values
Set-ConfigValue -Path "azure.location" -Value "westus2"
Set-ConfigValue -Path "servicePrincipal.appId" -Value "00000000-0000-..."

# Update nested values
Set-ConfigValue -Path "azure.aiFoundry.dev.projectEndpoint" -Value "https://..."

# Multiple updates
Set-ConfigValue -Path "azure.location" -Value "eastus2"
Set-ConfigValue -Path "naming.projectName" -Value "mynewproject"
```

**Notes:**
- Automatically saves configuration after update
- Returns `$false` if path is invalid

## Test-ConfigurationComplete

Validates that all required configuration values are present.

**Syntax:**
```powershell
Test-ConfigurationComplete [-Sections <string[]>] [-ConfigPath <string>]
```

**Parameters:**
- `Sections` (optional) - Array of section names to validate. Defaults to: `@("azureDevOps", "azure", "servicePrincipal")`
- `ConfigPath` (optional) - Custom configuration file path

**Returns:** Boolean indicating if configuration is complete

**Examples:**
```powershell
# Validate all sections
if (Test-ConfigurationComplete) {
    Write-Host "Configuration is complete"
} else {
    Write-Error "Configuration is incomplete"
    exit 1
}

# Validate specific sections
if (Test-ConfigurationComplete -Sections @("azureDevOps", "azure")) {
    Write-Host "Core configuration is valid"
}

# Use in script guard
if (-not (Test-ConfigurationComplete)) {
    Write-Error "Please run: ./configure-starter.ps1 -Interactive"
    exit 1
}
```

**Validation Rules:**

Each section has required fields:

- **azureDevOps**: `organizationUrl`, `projectName`
- **azure**: `subscriptionId`, `tenantId`, `location`
- **naming**: `projectName` (resource groups derived as `rg-{projectName}`)
- **servicePrincipal**: `appId`, `tenantId`

Fields are considered invalid if:
- Property doesn't exist
- Value is `$null` or empty string
- Value contains "YOUR_*" placeholder text

## Test-ConfigurationValidity

Validates configuration against actual Azure and Azure DevOps resources.

**Syntax:**
```powershell
Test-ConfigurationValidity [-ConfigPath <string>]
```

**Parameters:**
- `ConfigPath` (optional) - Custom configuration file path

**Returns:** Hashtable with validation results

**Return Structure:**
```powershell
@{
    azureDevOps = @{ valid = $bool; message = "string" }
    azure       = @{ valid = $bool; message = "string" }
    resources   = @{ valid = $bool; message = "string" }
}
```

**Examples:**
```powershell
# Full validation
$results = Test-ConfigurationValidity

if ($results.azureDevOps.valid) {
    Write-Host "✅ $($results.azureDevOps.message)"
} else {
    Write-Host "❌ $($results.azureDevOps.message)"
}

# Check all results
$allValid = ($results.Values | Where-Object { -not $_.valid }).Count -eq 0
if ($allValid) {
    Write-Host "All configuration is valid"
} else {
    Write-Warning "Some configuration needs attention"
}
```

**Checks Performed:**

1. **Azure DevOps** - Verifies project exists and is accessible
2. **Azure** - Confirms correct subscription is active
3. **Resources** - Checks if resource group exists (checks `rg-{projectName}-dev`)

**Requirements:**
- Azure CLI must be authenticated
- Azure DevOps CLI extension must be configured
- User must have access to configured resources

## Show-StarterConfig

Displays configuration in readable JSON format.

**Syntax:**
```powershell
Show-StarterConfig [-Section <string>] [-ConfigPath <string>]
```

**Parameters:**
- `Section` (optional) - Display only specified section
- `ConfigPath` (optional) - Custom configuration file path

**Returns:** None (outputs to console)

**Examples:**
```powershell
# Show entire configuration
Show-StarterConfig

# Show specific section
Show-StarterConfig -Section "azureDevOps"
Show-StarterConfig -Section "azure"
Show-StarterConfig -Section "servicePrincipal"

# Show from custom path
Show-StarterConfig -ConfigPath "custom-config.json"
```

**Output Format:**
```
=== Starter Configuration ===

[sectionName]
{
  "field1": "value1",
  "field2": "value2"
}
```

## Common Patterns

### Load and validate
```powershell
. ./.github/skills/configuration-management/config-functions.ps1

$config = Get-StarterConfig
if (-not $config) {
    Write-Error "Configuration not found"
    exit 1
}

if (-not (Test-ConfigurationComplete)) {
    Write-Error "Configuration incomplete"
    exit 1
}
```

### Update and save with backup
```powershell
$config = Get-StarterConfig
$config.azure.location = "westus2"
$config.servicePrincipal.appId = "NEW-APP-ID"
Set-StarterConfig -Config $config -CreateBackup
```

### Conditional value access
```powershell
$location = Get-ConfigValue -Path "azure.location" -Default "eastus"
$customField = Get-ConfigValue -Path "custom.field" -Default $null

if ($customField) {
    Write-Host "Custom field is set to: $customField"
}
```

### Batch updates
```powershell
$updates = @{
    "azure.location" = "westus2"
    "naming.projectName" = "mynewproject"
    "servicePrincipal.appId" = "00000000-0000-..."
}

foreach ($path in $updates.Keys) {
    Set-ConfigValue -Path $path -Value $updates[$path]
}
```
