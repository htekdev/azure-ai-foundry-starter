#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Interactive configuration setup for Azure AI Foundry starter deployment.

.DESCRIPTION
    Guides users through setting up all required configuration values for the starter template.
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
    Custom path for configuration file. Defaults to repository root (../../../starter-config.json)

.EXAMPLE
    ./configure-starter.ps1 -Interactive

.EXAMPLE
    ./configure-starter.ps1 -AutoDiscover

.EXAMPLE
    ./configure-starter.ps1 -Validate

.EXAMPLE
    ./configure-starter.ps1 -Show -Section "azureDevOps"
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
    [ValidateSet('azureDevOps', 'azure', 'servicePrincipal', 'aiFoundry')]
    [string]$Section,

    [Parameter(ParameterSetName = 'Update')]
    [switch]$Update,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot/../../../starter-config.json"
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
            Write-Host "=== Azure AI Foundry Starter Configuration ===" -ForegroundColor Cyan
            Write-Host "This wizard will help you set up configuration for the starter template.`n" -ForegroundColor Gray

            $config = @{
                azureDevOps      = @{}
                azure            = @{
                    aiFoundry = @{
                        dev  = @{}
                        test = @{}
                        prod = @{}
                    }
                }
                servicePrincipal = @{}
                metadata         = @{}
            }

            # Azure DevOps Settings
            Write-Host "`n[Azure DevOps Settings]" -ForegroundColor Yellow
            $config.azureDevOps.organizationUrl = Read-ConfigValue -Prompt "? Enter Azure DevOps organization URL (e.g., https://dev.azure.com/myorg)" -Required
            $config.azureDevOps.projectName = Read-ConfigValue -Prompt "? Enter project name" -Required

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

            $config.azure.subscriptionName = Read-ConfigValue -Prompt "? Enter Azure subscription name" -Default "YOUR_SUBSCRIPTION_NAME"
            $config.azure.resourceGroup = Read-ConfigValue -Prompt "? Enter resource group base name (will create {name}-dev, -test, -prod)" -Required
            $config.azure.location = Read-ConfigValue -Prompt "? Enter Azure region" -Default "eastus"
            
            # AI Foundry project endpoints (per LESSONS_LEARNED #9: format is https://<resource>.services.ai.azure.com/api/projects/<project>)
            Write-Host "`n[AI Foundry Project Endpoints]" -ForegroundColor Yellow
            Write-Host "Format: https://<resource>.services.ai.azure.com/api/projects/<project>" -ForegroundColor Gray
            Write-Host "You can get these from https://ai.azure.com after creating projects" -ForegroundColor Gray
            
            $config.azure.aiFoundry.dev.projectEndpoint = Read-ConfigValue -Prompt "? Enter DEV project endpoint" -Default "https://YOUR-DEV-PROJECT.services.ai.azure.com/api/projects/YOUR-DEV-PROJECT"
            $config.azure.aiFoundry.test.projectEndpoint = Read-ConfigValue -Prompt "? Enter TEST project endpoint" -Default "https://YOUR-TEST-PROJECT.services.ai.azure.com/api/projects/YOUR-TEST-PROJECT"
            $config.azure.aiFoundry.prod.projectEndpoint = Read-ConfigValue -Prompt "? Enter PROD project endpoint" -Default "https://YOUR-PROD-PROJECT.services.ai.azure.com/api/projects/YOUR-PROD-PROJECT"

            # Service Principal Settings
            Write-Host "`n[Service Principal Settings]" -ForegroundColor Yellow
            Write-Host "Note: Service Principal will be created with Contributor + Cognitive Services User roles" -ForegroundColor Gray
            $config.servicePrincipal.appId = "00000000-0000-0000-0000-000000000000"
            $config.servicePrincipal.tenantId = $config.azure.tenantId

            # Metadata
            $config.metadata.version = "2.0"
            $config.metadata.description = "Azure AI Foundry Starter Template Configuration"
            $config.metadata.lastModified = Get-Date -Format "yyyy-MM-dd"

            # Save configuration
            Write-Host "`n"
            $configObj = [PSCustomObject]$config
            if (Set-StarterConfig -Config $configObj -Path $OutputPath -CreateBackup) {
                Write-Host "✅ Configuration saved successfully to: $OutputPath" -ForegroundColor Green
                Write-Host "`nNext steps:" -ForegroundColor Cyan
                Write-Host "1. Review configuration: ./configure-starter.ps1 -Show"
                Write-Host "2. Validate configuration: ./configure-starter.ps1 -Validate"
                Write-Host "3. Create Azure resources: ../resource-creation/create-resources.ps1 -UseConfig -CreateAll"
                Write-Host "4. Set up Azure DevOps: ../starter-execution/SKILL.md"
            }
        }

        'AutoDiscover' {
            Write-Host "=== Auto-Discovering Configuration ===" -ForegroundColor Cyan

            $config = @{
                azureDevOps      = @{}
                azure            = @{
                    aiFoundry = @{
                        dev  = @{}
                        test = @{}
                        prod = @{}
                    }
                }
                servicePrincipal = @{}
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

            # Discover AI Foundry Hubs
            Write-Host "`nDiscovering AI Foundry Hubs..." -ForegroundColor Yellow
            try {
                $hubs = az ml workspace list --query "[?kind=='Hub'].{Name:name, ResourceGroup:resourceGroup}" --only-show-errors 2>$null | ConvertFrom-Json
                if ($hubs -and $hubs.Count -gt 0) {
                    Write-Host "Found $($hubs.Count) AI Foundry Hubs:" -ForegroundColor Gray
                    $hubs | ForEach-Object { Write-Host "  - $($_.Name) (RG: $($_.ResourceGroup))" }
                }
            }
            catch {
                Write-Host "⚠️  Could not discover AI Foundry Hubs" -ForegroundColor Yellow
            }

            # Discover AI Services
            Write-Host "`nDiscovering AI Services..." -ForegroundColor Yellow
            try {
                $aiServices = az cognitiveservices account list --query "[?kind=='AIServices'].{Name:name, ResourceGroup:resourceGroup, Location:location, Endpoint:properties.endpoint}" --only-show-errors 2>$null | ConvertFrom-Json
                if ($aiServices -and $aiServices.Count -gt 0) {
                    Write-Host "Found $($aiServices.Count) AI Services:" -ForegroundColor Gray
                    $aiServices | ForEach-Object { Write-Host "  - $($_.Name) in $($_.Location) (RG: $($_.ResourceGroup))" }
                    Write-Host "    Endpoint format: https://<resource>.services.ai.azure.com/api/projects/<project>" -ForegroundColor DarkGray
                }
            }
            catch {
                Write-Host "⚠️  Could not discover AI Services" -ForegroundColor Yellow
            }

            Write-Host "`n✅ Auto-discovery complete!" -ForegroundColor Green
            Write-Host "Run './configure-starter.ps1 -Interactive' to complete configuration with discovered values." -ForegroundColor Cyan
        }

        'Validate' {
            Write-Host "=== Validating Configuration ===" -ForegroundColor Cyan

            if (-not (Test-Path $OutputPath)) {
                Write-Host "❌ Configuration file not found: $OutputPath" -ForegroundColor Red
                Write-Host "Run './configure-starter.ps1 -Interactive' to create configuration." -ForegroundColor Yellow
                exit 1
            }

            $config = Get-StarterConfig -Path $OutputPath
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
                Show-StarterConfig -Section $Section -ConfigPath $OutputPath
            }
            else {
                Show-StarterConfig -ConfigPath $OutputPath
            }
        }

        'Update' {
            if (-not $Section) {
                Write-Host "Please specify a section to update with -Section parameter" -ForegroundColor Yellow
                Write-Host "Available sections: azureDevOps, azure, servicePrincipal, aiFoundry" -ForegroundColor Gray
                exit 1
            }

            Write-Host "=== Update Configuration: $Section ===" -ForegroundColor Cyan
            Write-Host "Feature coming soon..." -ForegroundColor Yellow
        }

        Default {
            # No parameters specified, show usage
            Write-Host "=== Azure AI Foundry Starter Configuration Tool ===" -ForegroundColor Cyan
            Write-Host "`nUsage:" -ForegroundColor Yellow
            Write-Host "  ./configure-starter.ps1 -Interactive       # Interactive setup"
            Write-Host "  ./configure-starter.ps1 -AutoDiscover      # Auto-discover values"
            Write-Host "  ./configure-starter.ps1 -Validate          # Validate configuration"
            Write-Host "  ./configure-starter.ps1 -Show              # Show configuration"
            Write-Host "  ./configure-starter.ps1 -Show -Section ... # Show specific section"
            Write-Host ""
        }
    }
}
catch {
    Write-Error "Configuration error: $_"
    exit 2
}
