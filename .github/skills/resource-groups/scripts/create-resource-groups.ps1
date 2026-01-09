#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates Azure Resource Groups for Azure AI Foundry multi-environment deployment.

.DESCRIPTION
    This specialized skill creates resource groups across multiple environments (dev, test, prod).
    It checks for existing resource groups and applies appropriate tags for environment tracking.
    Can operate standalone or be called by other orchestration scripts.

.PARAMETER ResourceGroupBaseName
    Base name for resource groups (will be appended with -dev, -test, -prod)

.PARAMETER Location
    Azure region for resource groups (default: eastus)

.PARAMETER Environment
    Which environment(s) to create: 'dev', 'test', 'prod', or 'all' (default: all)

.PARAMETER UseConfig
    Load configuration from starter-config.json file

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./create-resource-groups.ps1 -ResourceGroupBaseName "rg-aif-demo" -Location "eastus"

.EXAMPLE
    ./create-resource-groups.ps1 -UseConfig -Environment "dev"

.OUTPUTS
    PSCustomObject with creation results for each resource group
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupBaseName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'test', 'prod', 'all')]
    [string]$Environment = 'all',

    [Parameter(Mandatory = $false)]
    [switch]$UseConfig,

    [Parameter(Mandatory = $false)]
    [ValidateSet('text', 'json')]
    [string]$OutputFormat = 'text'
)

$ErrorActionPreference = 'Stop'

# Ensure Azure CLI is in PATH
$azCliPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
if ((Test-Path $azCliPath) -and ($env:Path -notlike "*$azCliPath*")) {
    $env:Path += ";$azCliPath"
}

# Load configuration if UseConfig is specified
if ($UseConfig) {
    . "$PSScriptRoot/../../configuration-management/config-functions.ps1"
    $config = Get-StarterConfig
    
    if ($config) {
        $ResourceGroupBaseName = "rg-$($config.naming.projectName)"
        $Location = $config.azure.location
        Write-Host "[OK] Loaded configuration from starter-config.json" -ForegroundColor Green
    }
    else {
        Write-Error "Could not load configuration. Run: ../configuration-management/configure-starter.ps1 -Interactive"
        exit 1
    }
}

# Validate required parameters
if (-not $ResourceGroupBaseName) {
    Write-Error "ResourceGroupBaseName is required. Use -UseConfig or specify -ResourceGroupBaseName"
    exit 1
}

# Determine which environments to create
$environments = @()
if ($Environment -eq 'all') {
    $environments = @('dev', 'test', 'prod')
} else {
    $environments = @($Environment)
}

# Results tracking
$results = @{
    Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ResourceGroups   = @()
    Summary          = @{
        Created = 0
        Skipped = 0
        Failed  = 0
    }
}

Write-Host "=== Azure Resource Group Creation ===" -ForegroundColor Cyan
Write-Host "Base Name: $ResourceGroupBaseName" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host "Environments: $($environments -join ', ')" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "[Creating Resource Groups]" -ForegroundColor Yellow
    
    foreach ($env in $environments) {
        $rgName = "$ResourceGroupBaseName-$env"
        Write-Host "  Environment: $env" -ForegroundColor Cyan
        
        $result = @{
            Environment = $env
            Name        = $rgName
            Location    = $Location
            Status      = $null
            Message     = $null
        }
        
        try {
            $rgExistsResult = az group exists --name $rgName
            if ($rgExistsResult -eq "true") {
                Write-Host "    [OK] Resource group already exists: $rgName" -ForegroundColor Green
                $result.Status = "Skipped"
                $result.Message = "Already exists"
                $results.Summary.Skipped++
            }
            else {
                Write-Host "    Creating resource group: $rgName..." -ForegroundColor Gray
                $rgJson = az group create `
                    --name $rgName `
                    --location $Location `
                    --tags "Environment=$env" "Project=AIFoundry" "ManagedBy=Starter" `
                    --only-show-errors 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    [OK] Resource group created successfully" -ForegroundColor Green
                    $result.Status = "Created"
                    $result.Message = "Created in $Location"
                    $results.Summary.Created++
                }
                else {
                    throw "Failed to create resource group: $rgJson"
                }
            }
        }
        catch {
            Write-Host "    [ERROR] Failed to create resource group: $_" -ForegroundColor Red
            $result.Status = "Failed"
            $result.Message = $_.Exception.Message
            $results.Summary.Failed++
        }
        
        $results.ResourceGroups += $result
    }
    
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Created: $($results.Summary.Created)" -ForegroundColor Green
    Write-Host "Skipped: $($results.Summary.Skipped)" -ForegroundColor Yellow
    Write-Host "Failed: $($results.Summary.Failed)" -ForegroundColor $(if ($results.Summary.Failed -gt 0) { "Red" } else { "Gray" })
    Write-Host ""
    
    # Output in requested format
    if ($OutputFormat -eq 'json') {
        $results | ConvertTo-Json -Depth 10
    }
    
    # Exit with appropriate code
    if ($results.Summary.Failed -gt 0) {
        Write-Host "[ERROR] Some resource groups failed to create" -ForegroundColor Red
        exit 1
    }
    elseif ($results.Summary.Created -gt 0) {
        Write-Host "[OK] Resource group creation completed successfully" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "[OK] All resource groups already exist" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "Resource group creation error: $_"
    exit 2
}
