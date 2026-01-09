#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates Azure AI Foundry deployment

.DESCRIPTION
    This script provides comprehensive validation of the Azure AI Foundry deployment
    by checking all Azure resources and Azure DevOps configuration.

.PARAMETER UseConfig
    Load configuration from starter-config.json file

.PARAMETER Environment
    Which environment(s) to validate: 'dev', 'test', 'prod', or 'all' (default: all)

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./validate-deployment.ps1 -UseConfig

.EXAMPLE
    ./validate-deployment.ps1 -UseConfig -Environment dev
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$UseConfig,

    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'test', 'prod', 'all')]
    [string]$Environment = 'all',

    [Parameter(Mandatory = $false)]
    [ValidateSet('text', 'json')]
    [string]$OutputFormat = 'text'
)

$ErrorActionPreference = 'Stop'

# Load configuration if UseConfig is specified
if ($UseConfig) {
    . "$PSScriptRoot/../../configuration-management/config-functions.ps1"
    $config = Get-StarterConfig
    
    if ($config) {
        Write-Host "[OK] Loaded configuration from starter-config.json" -ForegroundColor Green
    }
    else {
        Write-Error "Could not load configuration"
        exit 1
    }
}

# Determine which environments to validate
$environments = @()
if ($Environment -eq 'all') {
    $environments = @('dev', 'test', 'prod')
} else {
    $environments = @($Environment)
}

$projectName = $config.naming.projectName
$subscriptionId = $config.azure.subscriptionId

Write-Host ""
Write-Host "=== Azure AI Foundry Deployment Validation ===" -ForegroundColor Cyan
Write-Host "Project: $projectName" -ForegroundColor Gray
Write-Host "Subscription: $($config.azure.subscriptionName)" -ForegroundColor Gray
Write-Host "Environments: $($environments -join ', ')" -ForegroundColor Gray
Write-Host ""

# Validation results
$results = @{
    ResourceGroups = @()
    ServicePrincipal = $null
    AIResources = @()
    Summary = @{
        Passed = 0
        Failed = 0
        Warnings = 0
    }
}

# Validate Resource Groups
Write-Host "[Validating Resource Groups]" -ForegroundColor Yellow
foreach ($env in $environments) {
    $rgName = "rg-$projectName-$env"
    $rgExists = az group exists --name $rgName
    
    if ($rgExists -eq "true") {
        Write-Host "  [OK] Resource group exists: $rgName" -ForegroundColor Green
        $results.ResourceGroups += @{ Name = $rgName; Status = "Exists" }
        $results.Summary.Passed++
    } else {
        Write-Host "  [ERROR] Resource group not found: $rgName" -ForegroundColor Red
        $results.ResourceGroups += @{ Name = $rgName; Status = "Missing" }
        $results.Summary.Failed++
    }
}

Write-Host ""

# Validate Service Principal
Write-Host "[Validating Service Principal]" -ForegroundColor Yellow
if ($config.servicePrincipal.appId -and $config.servicePrincipal.appId -ne '00000000-0000-0000-0000-000000000000') {
    $spAppId = $config.servicePrincipal.appId
    $spExists = az ad sp show --id $spAppId --query "appId" -o tsv 2>$null
    
    if ($spExists) {
        Write-Host "  [OK] Service Principal exists: $spAppId" -ForegroundColor Green
        $results.ServicePrincipal = @{ AppId = $spAppId; Status = "Exists" }
        $results.Summary.Passed++
    } else {
        Write-Host "  [ERROR] Service Principal not found: $spAppId" -ForegroundColor Red
        $results.ServicePrincipal = @{ AppId = $spAppId; Status = "Missing" }
        $results.Summary.Failed++
    }
} else {
    Write-Host "  [WARN] Service Principal not configured in starter-config.json" -ForegroundColor Yellow
    $results.Summary.Warnings++
}

Write-Host ""

# Validate AI Foundry Resources
Write-Host "[Validating AI Foundry Resources]" -ForegroundColor Yellow
foreach ($env in $environments) {
    $rgName = "rg-$projectName-$env"
    $resourceName = "$rgName"  # AI Services resource name matches the RG name pattern
    
    $ErrorActionPreference = 'Continue'
    $resource = az cognitiveservices account show `
        --name $resourceName `
        --resource-group $rgName `
        2>$null
    $ErrorActionPreference = 'Stop'
    
    if ($LASTEXITCODE -eq 0 -and $resource) {
        Write-Host "  [OK] AI Services resource exists: $resourceName" -ForegroundColor Green
        $results.AIResources += @{ Name = $resourceName; Environment = $env; Status = "Exists" }
        $results.Summary.Passed++
    } else {
        Write-Host "  [ERROR] AI Services resource not found: $resourceName" -ForegroundColor Red
        $results.AIResources += @{ Name = $resourceName; Environment = $env; Status = "Missing" }
        $results.Summary.Failed++
    }
}

Write-Host ""

# Summary
Write-Host "=== Validation Summary ===" -ForegroundColor Cyan
Write-Host "Passed:   $($results.Summary.Passed)" -ForegroundColor Green
Write-Host "Failed:   $($results.Summary.Failed)" -ForegroundColor $(if ($results.Summary.Failed -gt 0) { "Red" } else { "Gray" })
Write-Host "Warnings: $($results.Summary.Warnings)" -ForegroundColor $(if ($results.Summary.Warnings -gt 0) { "Yellow" } else { "Gray" })
Write-Host ""

if ($results.Summary.Failed -eq 0) {
    Write-Host "[OK] Azure resources validation completed successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Configure Azure DevOps service connections" -ForegroundColor Gray
    Write-Host "2. Create variable groups and environments" -ForegroundColor Gray
    Write-Host "3. Set up CI/CD pipelines" -ForegroundColor Gray
    Write-Host ""
    exit 0
} else {
    Write-Host "[ERROR] Deployment validation failed" -ForegroundColor Red
    Write-Host "Review the errors above and re-run the setup scripts" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
