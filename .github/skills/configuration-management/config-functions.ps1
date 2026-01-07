#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configuration management functions for Azure DevOps migration.

.DESCRIPTION
    Provides helper functions to load, save, and manipulate migration configuration.
    These functions are designed to be dot-sourced by other scripts.

.EXAMPLE
    # Source functions
    . ./config-functions.ps1
    
    # Load configuration
    $config = Get-MigrationConfig
    
    # Access values
    $org = $config.azureDevOps.organizationUrl
#>

# Configuration file is now stored in repository root
$script:ConfigFilePath = "$PSScriptRoot/../../../migration-config.json"

<#
.SYNOPSIS
    Gets the migration configuration from file.

.DESCRIPTION
    Loads the migration-config.json file and returns the configuration object.

.PARAMETER Path
    Optional custom path to configuration file. Defaults to ../migration-config.json

.OUTPUTS
    PSCustomObject containing the configuration.

.EXAMPLE
    $config = Get-MigrationConfig
    Write-Host $config.azureDevOps.organizationUrl
#>
function Get-MigrationConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = $script:ConfigFilePath
    )

    if (-not (Test-Path $Path)) {
        Write-Error "Configuration file not found at: $Path"
        Write-Host "Run './configure-migration.ps1 -Interactive' to create configuration" -ForegroundColor Yellow
        return $null
    }

    try {
        $json = Get-Content -Path $Path -Raw
        $config = $json | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Error "Failed to load configuration: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Saves the migration configuration to file.

.DESCRIPTION
    Saves the configuration object to migration-config.json.

.PARAMETER Config
    Configuration object to save.

.PARAMETER Path
    Optional custom path to configuration file. Defaults to ../migration-config.json

.PARAMETER CreateBackup
    If specified, creates a backup of existing configuration before saving.

.EXAMPLE
    $config = Get-MigrationConfig
    $config.azure.location = "westus"
    Set-MigrationConfig -Config $config -CreateBackup
#>
function Set-MigrationConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $false)]
        [string]$Path = $script:ConfigFilePath,

        [Parameter(Mandatory = $false)]
        [switch]$CreateBackup
    )

    # Create backup if requested and file exists
    if ($CreateBackup -and (Test-Path $Path)) {
        $backupPath = "$Path.backup"
        Copy-Item -Path $Path -Destination $backupPath -Force
        Write-Host "✅ Backup created: $backupPath" -ForegroundColor Green
    }

    # Update metadata
    if ($Config.PSObject.Properties.Name -contains 'metadata') {
        $Config.metadata.lastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        if (-not $Config.metadata.createdDate) {
            $Config.metadata.createdDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # Ensure directory exists
    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    try {
        $json = $Config | ConvertTo-Json -Depth 10
        Set-Content -Path $Path -Value $json -Encoding UTF8
        Write-Host "✅ Configuration saved: $Path" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to save configuration: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Gets a specific configuration value by path.

.DESCRIPTION
    Retrieves a nested configuration value using dot notation path.

.PARAMETER Path
    Dot-notation path to the configuration value (e.g., "azureDevOps.organizationUrl").

.PARAMETER Default
    Default value to return if path doesn't exist.

.PARAMETER ConfigPath
    Optional custom path to configuration file.

.EXAMPLE
    $org = Get-ConfigValue -Path "azureDevOps.organizationUrl"
    $region = Get-ConfigValue -Path "azure.location" -Default "eastus"
#>
function Get-ConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [object]$Default = $null,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = $script:ConfigFilePath
    )

    $config = Get-MigrationConfig -Path $ConfigPath
    if (-not $config) {
        return $Default
    }

    $parts = $Path.Split('.')
    $current = $config

    foreach ($part in $parts) {
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        }
        else {
            return $Default
        }
    }

    return $current
}

<#
.SYNOPSIS
    Sets a specific configuration value by path.

.DESCRIPTION
    Updates a nested configuration value using dot notation path.

.PARAMETER Path
    Dot-notation path to the configuration value (e.g., "azureDevOps.organizationUrl").

.PARAMETER Value
    The value to set.

.PARAMETER ConfigPath
    Optional custom path to configuration file.

.EXAMPLE
    Set-ConfigValue -Path "azure.location" -Value "westus"
    Set-ConfigValue -Path "servicePrincipal.appId" -Value "12345678-abcd-..."
#>
function Set-ConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Value,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = $script:ConfigFilePath
    )

    $config = Get-MigrationConfig -Path $ConfigPath
    if (-not $config) {
        Write-Error "Cannot set value: configuration not found"
        return $false
    }

    $parts = $Path.Split('.')
    $current = $config

    # Navigate to parent
    for ($i = 0; $i -lt ($parts.Count - 1); $i++) {
        $part = $parts[$i]
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        }
        else {
            Write-Error "Invalid path: $Path (stopped at $part)"
            return $false
        }
    }

    # Set the value
    $lastPart = $parts[-1]
    $current.$lastPart = $Value

    # Save configuration
    return Set-MigrationConfig -Config $config -Path $ConfigPath
}

<#
.SYNOPSIS
    Tests if the configuration is complete.

.DESCRIPTION
    Validates that all required configuration values are present.

.PARAMETER Sections
    Optional array of section names to validate. If not specified, validates all sections.

.PARAMETER ConfigPath
    Optional custom path to configuration file.

.OUTPUTS
    Boolean indicating if configuration is complete.

.EXAMPLE
    if (Test-ConfigurationComplete) {
        Write-Host "Configuration is valid"
    }
    
    # Validate specific sections
    if (Test-ConfigurationComplete -Sections @("azureDevOps", "azure")) {
        Write-Host "Required sections are valid"
    }
#>
function Test-ConfigurationComplete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Sections = @("azureDevOps", "azure", "servicePrincipal", "pipelines"),

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = $script:ConfigFilePath
    )

    $config = Get-MigrationConfig -Path $ConfigPath
    if (-not $config) {
        return $false
    }

    $allValid = $true

    # Define required fields for each section
    $requiredFields = @{
        azureDevOps        = @("organizationUrl", "projectName", "sourceRepository", "targetRepositories")
        azure              = @("subscriptionId", "tenantId", "resourceGroupName", "location")
        servicePrincipal   = @("name")
        pipelines          = @("variableGroups", "serviceConnections", "agentPool")
    }

    foreach ($section in $Sections) {
        if (-not ($config.PSObject.Properties.Name -contains $section)) {
            Write-Warning "Section missing: $section"
            $allValid = $false
            continue
        }

        $sectionConfig = $config.$section
        $requiredForSection = $requiredFields[$section]

        if ($requiredForSection) {
            foreach ($field in $requiredForSection) {
                if (-not ($sectionConfig.PSObject.Properties.Name -contains $field)) {
                    Write-Warning "Missing field: $section.$field"
                    $allValid = $false
                }
                elseif ($null -eq $sectionConfig.$field -or $sectionConfig.$field -eq "" -or $sectionConfig.$field -eq "YOUR_*") {
                    Write-Warning "Field not set: $section.$field"
                    $allValid = $false
                }
            }
        }
    }

    return $allValid
}

<#
.SYNOPSIS
    Validates configuration values against Azure/Azure DevOps environment.

.DESCRIPTION
    Checks if configured resources actually exist and are accessible.

.PARAMETER ConfigPath
    Optional custom path to configuration file.

.OUTPUTS
    Hashtable with validation results for each resource.

.EXAMPLE
    $results = Test-ConfigurationValidity
    if ($results.azureDevOps.valid) {
        Write-Host "Azure DevOps configuration is valid"
    }
#>
function Test-ConfigurationValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = $script:ConfigFilePath
    )

    $config = Get-MigrationConfig -Path $ConfigPath
    if (-not $config) {
        return @{ error = "Configuration not found" }
    }

    $results = @{
        azureDevOps = @{ valid = $false; message = "" }
        azure       = @{ valid = $false; message = "" }
        resources   = @{ valid = $false; message = "" }
    }

    # Test Azure DevOps connectivity
    try {
        $project = az devops project show `
            --organization $config.azureDevOps.organizationUrl `
            --project $config.azureDevOps.projectName `
            --only-show-errors 2>$null | ConvertFrom-Json
        
        if ($project) {
            $results.azureDevOps.valid = $true
            $results.azureDevOps.message = "Project accessible: $($project.name)"
        }
        else {
            $results.azureDevOps.message = "Project not found or not accessible"
        }
    }
    catch {
        $results.azureDevOps.message = "Error: $_"
    }

    # Test Azure subscription
    try {
        $sub = az account show --only-show-errors 2>$null | ConvertFrom-Json
        
        if ($sub.id -eq $config.azure.subscriptionId) {
            $results.azure.valid = $true
            $results.azure.message = "Subscription active: $($sub.name)"
        }
        else {
            $results.azure.message = "Different subscription active (expected: $($config.azure.subscriptionId))"
        }
    }
    catch {
        $results.azure.message = "Error: $_"
    }

    # Test resource group
    try {
        $rg = az group show --name $config.azure.resourceGroupName --only-show-errors 2>$null | ConvertFrom-Json
        
        if ($rg) {
            $results.resources.valid = $true
            $results.resources.message = "Resource group exists: $($rg.name) in $($rg.location)"
        }
        else {
            $results.resources.message = "Resource group not found: $($config.azure.resourceGroupName)"
        }
    }
    catch {
        $results.resources.message = "Error: $_"
    }

    return $results
}

<#
.SYNOPSIS
    Displays the current configuration in a readable format.

.DESCRIPTION
    Pretty-prints the configuration to the console.

.PARAMETER Section
    Optional section name to display. If not specified, displays entire configuration.

.PARAMETER ConfigPath
    Optional custom path to configuration file.

.EXAMPLE
    Show-MigrationConfig
    Show-MigrationConfig -Section "azureDevOps"
#>
function Show-MigrationConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Section = "",

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = $script:ConfigFilePath
    )

    $config = Get-MigrationConfig -Path $ConfigPath
    if (-not $config) {
        return
    }

    Write-Host "`n=== Migration Configuration ===" -ForegroundColor Cyan

    if ($Section) {
        if ($config.PSObject.Properties.Name -contains $Section) {
            Write-Host "`n[$Section]" -ForegroundColor Yellow
            $config.$Section | ConvertTo-Json -Depth 10 | Write-Host
        }
        else {
            Write-Warning "Section not found: $Section"
        }
    }
    else {
        $config | ConvertTo-Json -Depth 10 | Write-Host
    }

    Write-Host ""
}

# Note: Export-ModuleMember is not needed when dot-sourcing
# Functions are automatically available in the calling scope
