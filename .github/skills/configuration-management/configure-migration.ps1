#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Interactive configuration setup for Azure DevOps migration.

.DESCRIPTION
    Guides users through setting up all required configuration values for the migration.
    Supports interactive prompts, auto-discovery, and validation.

.PARAMETER Interactive
    Run in interactive mode with prompts for each value.

.PARAMETER AutoDiscover
    Attempt to auto-discover values from current Azure/Azure DevOps environment.

.PARAMETER Validate
    Validate existing configuration for completeness and validity.

.PARAMETER Show
    Display current configuration.

.PARAMETER Section
    Specific section to show or update.

.PARAMETER Update
    Update specific section interactively.

.PARAMETER OutputPath
    Custom path for configuration file. Defaults to repository root (../../../migration-config.json)

.EXAMPLE
    ./configure-migration.ps1 -Interactive

.EXAMPLE
    ./configure-migration.ps1 -AutoDiscover

.EXAMPLE
    ./configure-migration.ps1 -Validate

.EXAMPLE
    ./configure-migration.ps1 -Show -Section "azureDevOps"
#>

[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$Interactive,

    [Parameter(ParameterSetName = 'AutoDiscover')]
    [switch]$AutoDiscover,

    [Parameter(ParameterSetName = 'Validate')]
    [switch]$Validate,

    [Parameter(ParameterSetName = 'Show')]
    [switch]$Show,

    [Parameter(Mandatory = $false)]
    [ValidateSet('azureDevOps', 'azure', 'servicePrincipal', 'pipelines', 'migration')]
    [string]$Section,

    [Parameter(ParameterSetName = 'Update')]
    [switch]$Update,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot/../../../migration-config.json"
)

$ErrorActionPreference = 'Stop'

# Ensure Azure CLI is in PATH
$azCliPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
if ((Test-Path $azCliPath) -and ($env:Path -notlike "*$azCliPath*")) {
    $env:Path += ";$azCliPath"
}

# Set bearer token for Azure DevOps if authenticated to Azure
try {
    $tokenResult = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --only-show-errors 2>&1
    if ($LASTEXITCODE -eq 0) {
        $token = $tokenResult | ConvertFrom-Json
        $env:AZURE_DEVOPS_EXT_PAT = $token.accessToken
    }
}
catch {
    # Silently continue if token cannot be obtained
}

# Source helper functions
. "$PSScriptRoot/config-functions.ps1"

# Helper function to prompt for value with default
function Read-ConfigValue {
    param(
        [string]$Prompt,
        [string]$Default = "",
        [switch]$Required
    )

    if ($Default) {
        $fullPrompt = "$Prompt [$Default]"
    }
    else {
        $fullPrompt = $Prompt
    }

    $value = Read-Host $fullPrompt

    if ([string]::IsNullOrWhiteSpace($value)) {
        if ($Default) {
            return $Default
        }
        elseif ($Required) {
            Write-Host "This value is required." -ForegroundColor Red
            return Read-ConfigValue -Prompt $Prompt -Default $Default -Required
        }
    }

    return $value
}

# Helper function to select from list
function Select-FromList {
    param(
        [string]$Prompt,
        [array]$Options,
        [switch]$AllowCustom
    )

    Write-Host "`n$Prompt" -ForegroundColor Yellow
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "$($i + 1). $($Options[$i])"
    }

    if ($AllowCustom) {
        Write-Host "$($Options.Count + 1). Enter custom value"
    }

    $selection = Read-Host "Select option [1-$($Options.Count)]"

    $index = [int]$selection - 1
    if ($index -ge 0 -and $index -lt $Options.Count) {
        return $Options[$index]
    }
    elseif ($AllowCustom -and $index -eq $Options.Count) {
        return Read-Host "Enter custom value"
    }
    else {
        Write-Host "Invalid selection" -ForegroundColor Red
        return Select-FromList -Prompt $Prompt -Options $Options -AllowCustom:$AllowCustom
    }
}

# Main execution
try {
    switch ($PSCmdlet.ParameterSetName) {
        'Interactive' {
            Write-Host "=== Azure DevOps Migration Configuration ===" -ForegroundColor Cyan
            Write-Host "This wizard will help you set up configuration for the migration.`n" -ForegroundColor Gray

            $config = @{
                azureDevOps      = @{}
                azure            = @{}
                servicePrincipal = @{}
                pipelines        = @{}
                migration        = @{}
                metadata         = @{}
            }

            # Azure DevOps Settings
            Write-Host "`n[Azure DevOps Settings]" -ForegroundColor Yellow
            $config.azureDevOps.organizationUrl = Read-ConfigValue -Prompt "? Enter Azure DevOps organization URL (e.g., https://dev.azure.com/myorg)" -Required
            $config.azureDevOps.projectName = Read-ConfigValue -Prompt "? Enter project name" -Required
            $config.azureDevOps.sourceRepository = Read-ConfigValue -Prompt "? Enter source repository name" -Required
            
            $targetRepos = Read-ConfigValue -Prompt "? Enter target repository names (comma-separated)" -Required
            $config.azureDevOps.targetRepositories = $targetRepos.Split(',').Trim()
            
            $config.azureDevOps.defaultBranch = Read-ConfigValue -Prompt "? Enter default branch name" -Default "main"

            # Azure Settings
            Write-Host "`n[Azure Settings]" -ForegroundColor Yellow
            
            # Try to get current subscription
            try {
                $currentSub = az account show --only-show-errors 2>$null | ConvertFrom-Json
                if ($currentSub) {
                    Write-Host "Current subscription: $($currentSub.name) ($($currentSub.id))" -ForegroundColor Gray
                    $useCurrent = Read-Host "Use this subscription? [Y/n]"
                    
                    if ($useCurrent -ne 'n' -and $useCurrent -ne 'N') {
                        $config.azure.subscriptionId = $currentSub.id
                        $config.azure.tenantId = $currentSub.tenantId
                    }
                }
            }
            catch {
                Write-Host "Could not detect current subscription" -ForegroundColor Gray
            }

            if (-not $config.azure.subscriptionId) {
                $config.azure.subscriptionId = Read-ConfigValue -Prompt "? Enter Azure subscription ID" -Required
                $config.azure.tenantId = Read-ConfigValue -Prompt "? Enter Azure tenant ID" -Required
            }

            $config.azure.resourceGroupName = Read-ConfigValue -Prompt "? Enter resource group name" -Required
            $config.azure.location = Read-ConfigValue -Prompt "? Enter Azure region" -Default "eastus"
            $config.azure.mlWorkspaceName = Read-ConfigValue -Prompt "? Enter ML workspace name" -Required
            $config.azure.openAIServiceName = Read-ConfigValue -Prompt "? Enter OpenAI service name" -Required

            # Service Principal Settings
            Write-Host "`n[Service Principal Settings]" -ForegroundColor Yellow
            $config.servicePrincipal.name = Read-ConfigValue -Prompt "? Enter service principal name" -Default "migration-sp"
            $config.servicePrincipal.appId = $null
            $config.servicePrincipal.roles = @("Contributor")

            $additionalRoles = Read-Host "? Add additional roles? (comma-separated, or press Enter to skip)"
            if ($additionalRoles) {
                $config.servicePrincipal.roles += $additionalRoles.Split(',').Trim()
            }

            # Pipeline Settings
            Write-Host "`n[Pipeline Settings]" -ForegroundColor Yellow
            $config.pipelines = @{
                variableGroups     = @{
                    mlConfig     = Read-ConfigValue -Prompt "? Enter ML variable group name" -Default "ML-Configuration"
                    openAIConfig = Read-ConfigValue -Prompt "? Enter OpenAI variable group name" -Default "OpenAI-Configuration"
                }
                serviceConnections = @{
                    azure = Read-ConfigValue -Prompt "? Enter Azure service connection name" -Default "Azure-Production"
                }
                agentPool          = Read-ConfigValue -Prompt "? Enter agent pool name" -Default "Azure Pipelines"
                pipelinePrefix     = Read-ConfigValue -Prompt "? Enter pipeline name prefix (or press Enter for none)" -Default ""
                pipelineSuffix     = Read-ConfigValue -Prompt "? Enter pipeline name suffix" -Default "-CI"
            }

            # Migration Settings
            Write-Host "`n[Migration Settings]" -ForegroundColor Yellow
            $config.migration.backupDirectory = Read-ConfigValue -Prompt "? Enter backup directory" -Default "./backups"
            $config.migration.workingDirectory = Read-ConfigValue -Prompt "? Enter working directory" -Default "./migration-temp"
            $config.migration.logFile = Read-ConfigValue -Prompt "? Enter log file path" -Default "./migration.log"
            
            $verboseLogging = Read-Host "? Enable verbose logging? [Y/n]"
            $config.migration.verboseLogging = ($verboseLogging -ne 'n' -and $verboseLogging -ne 'N')
            $config.migration.validateBeforeExecute = $true

            # Metadata
            $config.metadata.version = "1.0"
            $config.metadata.createdDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $config.metadata.lastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            # Save configuration
            Write-Host "`n"
            $configObj = [PSCustomObject]$config
            if (Set-MigrationConfig -Config $configObj -Path $OutputPath -CreateBackup) {
                Write-Host "✅ Configuration saved successfully!" -ForegroundColor Green
                Write-Host "`nNext steps:" -ForegroundColor Cyan
                Write-Host "1. Review configuration: ./configure-migration.ps1 -Show"
                Write-Host "2. Validate configuration: ./configure-migration.ps1 -Validate"
                Write-Host "3. Start migration: Use the migration-execution skill"
            }
        }

        'AutoDiscover' {
            Write-Host "=== Auto-Discovering Configuration ===" -ForegroundColor Cyan

            $config = @{
                azureDevOps      = @{}
                azure            = @{}
                servicePrincipal = @{}
                pipelines        = @{}
                migration        = @{}
                metadata         = @{}
            }

            # Discover Azure subscription
            Write-Host "`nDiscovering Azure subscription..." -ForegroundColor Yellow
            try {
                $currentSub = az account show --only-show-errors 2>$null | ConvertFrom-Json
                if ($currentSub) {
                    $config.azure.subscriptionId = $currentSub.id
                    $config.azure.tenantId = $currentSub.tenantId
                    Write-Host "✅ Found subscription: $($currentSub.name)" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "⚠️  Could not discover subscription" -ForegroundColor Yellow
            }

            # Discover Azure DevOps organizations
            Write-Host "`nDiscovering Azure DevOps organizations..." -ForegroundColor Yellow
            try {
                # Use REST API to find organizations
                $userEmail = $currentSub.user.name
                $orgsJson = az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 --method get --uri "https://app.vssps.visualstudio.com/_apis/accounts?memberId=$userEmail&api-version=7.1-preview.1" --only-show-errors 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $orgsData = $orgsJson | ConvertFrom-Json
                    if ($orgsData -and $orgsData.Count -gt 0) {
                        Write-Host "Found $($orgsData.Count) organization(s):" -ForegroundColor Gray
                        $orgsData | ForEach-Object {
                            $orgName = $_.AccountName
                            Write-Host "  - https://dev.azure.com/$orgName" -ForegroundColor Gray
                            
                            # Try to list projects in this org
                            try {
                                $projectsJson = az devops project list --org "https://dev.azure.com/$orgName" --only-show-errors 2>$null
                                if ($LASTEXITCODE -eq 0) {
                                    $projects = $projectsJson | ConvertFrom-Json
                                    if ($projects -and $projects.Count -gt 0) {
                                        Write-Host "    Projects: $($projects.Count)" -ForegroundColor DarkGray
                                    }
                                }
                            }
                            catch {
                                # Silently continue if can't access projects
                            }
                        }
                    }
                }
            }
            catch {
                Write-Host "⚠️  Could not discover Azure DevOps organizations" -ForegroundColor Yellow
            }

            # Discover resource groups
            Write-Host "`nDiscovering resource groups..." -ForegroundColor Yellow
            try {
                $rgs = az group list --query "[].{Name:name, Location:location}" --only-show-errors 2>$null | ConvertFrom-Json
                if ($rgs -and $rgs.Count -gt 0) {
                    Write-Host "Found $($rgs.Count) resource groups:" -ForegroundColor Gray
                    $rgs | ForEach-Object { Write-Host "  - $($_.Name) ($($_.Location))" }
                }
            }
            catch {
                Write-Host "⚠️  Could not discover resource groups" -ForegroundColor Yellow
            }

            # Discover ML workspaces
            Write-Host "`nDiscovering ML workspaces..." -ForegroundColor Yellow
            try {
                $workspaces = az ml workspace list --query "[].{Name:name, ResourceGroup:resourceGroup}" --only-show-errors 2>$null | ConvertFrom-Json
                if ($workspaces -and $workspaces.Count -gt 0) {
                    Write-Host "Found $($workspaces.Count) ML workspaces:" -ForegroundColor Gray
                    $workspaces | ForEach-Object { Write-Host "  - $($_.Name) (RG: $($_.ResourceGroup))" }
                }
            }
            catch {
                Write-Host "⚠️  Could not discover ML workspaces" -ForegroundColor Yellow
            }

            # Discover OpenAI services
            Write-Host "`nDiscovering OpenAI services..." -ForegroundColor Yellow
            try {
                $openAIServices = az cognitiveservices account list --query "[?kind=='OpenAI'].{Name:name, ResourceGroup:resourceGroup, Location:location}" --only-show-errors 2>$null | ConvertFrom-Json
                if ($openAIServices -and $openAIServices.Count -gt 0) {
                    Write-Host "Found $($openAIServices.Count) OpenAI services:" -ForegroundColor Gray
                    $openAIServices | ForEach-Object { Write-Host "  - $($_.Name) in $($_.Location) (RG: $($_.ResourceGroup))" }
                }
            }
            catch {
                Write-Host "⚠️  Could not discover OpenAI services" -ForegroundColor Yellow
            }

            Write-Host "`n✅ Auto-discovery complete!" -ForegroundColor Green
            Write-Host "Run './configure-migration.ps1 -Interactive' to complete configuration with discovered values." -ForegroundColor Cyan
        }

        'Validate' {
            Write-Host "=== Validating Configuration ===" -ForegroundColor Cyan

            if (-not (Test-Path $OutputPath)) {
                Write-Host "❌ Configuration file not found: $OutputPath" -ForegroundColor Red
                Write-Host "Run './configure-migration.ps1 -Interactive' to create configuration." -ForegroundColor Yellow
                exit 1
            }

            $config = Get-MigrationConfig -Path $OutputPath
            if (-not $config) {
                Write-Host "❌ Failed to load configuration" -ForegroundColor Red
                exit 1
            }

            # Test completeness
            Write-Host "`nChecking completeness..." -ForegroundColor Yellow
            $isComplete = Test-ConfigurationComplete -ConfigPath $OutputPath

            if ($isComplete) {
                Write-Host "✅ Configuration is complete" -ForegroundColor Green
            }
            else {
                Write-Host "⚠️  Configuration has missing or invalid values" -ForegroundColor Yellow
            }

            # Test validity
            Write-Host "`nValidating against Azure environment..." -ForegroundColor Yellow
            $validity = Test-ConfigurationValidity -ConfigPath $OutputPath

            Write-Host "`nValidation Results:" -ForegroundColor Cyan
            foreach ($key in $validity.Keys) {
                $result = $validity[$key]
                if ($result.valid) {
                    Write-Host "  ✅ $key - $($result.message)" -ForegroundColor Green
                }
                else {
                    Write-Host "  ❌ $key - $($result.message)" -ForegroundColor Red
                }
            }

            if ($isComplete -and ($validity.Values | Where-Object { $_.valid -eq $false }).Count -eq 0) {
                Write-Host "`n✅ Configuration is valid and ready for migration!" -ForegroundColor Green
                exit 0
            }
            else {
                Write-Host "`n⚠️  Please address the issues above before proceeding." -ForegroundColor Yellow
                exit 1
            }
        }

        'Show' {
            if ($Section) {
                Show-MigrationConfig -Section $Section -ConfigPath $OutputPath
            }
            else {
                Show-MigrationConfig -ConfigPath $OutputPath
            }
        }

        'Update' {
            if (-not $Section) {
                Write-Host "Please specify a section to update with -Section parameter" -ForegroundColor Yellow
                Write-Host "Available sections: azureDevOps, azure, servicePrincipal, pipelines, migration" -ForegroundColor Gray
                exit 1
            }

            Write-Host "=== Update Configuration: $Section ===" -ForegroundColor Cyan
            Write-Host "Feature coming soon..." -ForegroundColor Yellow
        }

        Default {
            # No parameters specified, show usage
            Write-Host "=== Azure DevOps Migration Configuration Tool ===" -ForegroundColor Cyan
            Write-Host "`nUsage:" -ForegroundColor Yellow
            Write-Host "  ./configure-migration.ps1 -Interactive       # Interactive setup"
            Write-Host "  ./configure-migration.ps1 -AutoDiscover      # Auto-discover values"
            Write-Host "  ./configure-migration.ps1 -Validate          # Validate configuration"
            Write-Host "  ./configure-migration.ps1 -Show              # Show configuration"
            Write-Host "  ./configure-migration.ps1 -Show -Section ... # Show specific section"
            Write-Host ""
        }
    }
}
catch {
    Write-Error "Configuration error: $_"
    exit 2
}
