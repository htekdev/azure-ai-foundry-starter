#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates Azure DevOps variable groups and environments

.DESCRIPTION
    This script creates variable groups and environments for dev, test, and production.
    Variable groups store environment-specific configuration and environments enable
    deployment tracking and approval gates.

.PARAMETER UseConfig
    Load configuration from starter-config.json file

.PARAMETER Environment
    Which environment(s) to create: 'dev', 'test', 'prod', or 'all' (default: all)

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./create-environments.ps1 -UseConfig

.EXAMPLE
    ./create-environments.ps1 -UseConfig -Environment dev
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

# Determine which environments to create
$environments = @()
if ($Environment -eq 'all') {
    $environments = @('dev', 'test', 'prod')
} else {
    $environments = @($Environment)
}

$projectName = $config.naming.projectName
$subscriptionId = $config.azure.subscriptionId
$orgUrl = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName

Write-Host "=== Azure DevOps Environment Setup ===" -ForegroundColor Cyan
Write-Host "Organization: $orgUrl" -ForegroundColor Gray
Write-Host "Project: $project" -ForegroundColor Gray
Write-Host "Environments: $($environments -join ', ')" -ForegroundColor Gray
Write-Host ""

# Create variable groups for each environment
Write-Host "[Creating Variable Groups]" -ForegroundColor Yellow
foreach ($env in $environments) {
    $vgName = "$projectName-$env-vars"
    $rgName = "rg-$projectName-$env"
    
    # Check if variable group already exists
    $existingVg = az pipelines variable-group list --org $orgUrl --project $project --group-name $vgName 2>$null | ConvertFrom-Json
    
    if ($existingVg -and $existingVg.Count -gt 0) {
        Write-Host "  [OK] Variable group already exists: $vgName" -ForegroundColor Green
        continue
    }
    
    # Get AI project endpoint from config
    $aiProjectName = "rg-$projectName-project-$env"
    $aiProjectEndpoint = "https://rg-$projectName-$env.services.ai.azure.com/api/projects/$aiProjectName"
    
    # Create variable group with required variables
    Write-Host "  [INFO] Creating variable group: $vgName" -ForegroundColor Blue
    
    $variables = @{
        "AZURE_AI_PROJECT_ENDPOINT" = $aiProjectEndpoint
        "AZURE_AI_PROJECT_NAME" = $aiProjectName
        "AZURE_AI_MODEL_DEPLOYMENT_NAME" = "gpt-4o"
        "AZURE_RESOURCE_GROUP" = $rgName
        "AZURE_SUBSCRIPTION_ID" = $subscriptionId
    }
    
    # Create variable group with a single dummy variable first
    # (Azure CLI doesn't support creating empty variable groups)
    $result = az pipelines variable-group create `
        --org $orgUrl `
        --project $project `
        --name $vgName `
        --variables "PLACEHOLDER=temp" `
        --authorize true `
        --description "Variables for $env environment" `
        2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Created variable group: $vgName" -ForegroundColor Green
        
        # Get the variable group ID
        $vgId = az pipelines variable-group list `
            --org $orgUrl `
            --project $project `
            --query "[?name=='$vgName'].id" `
            -o tsv
        
        # Add each variable individually
        foreach ($key in $variables.Keys) {
            $value = $variables[$key]
            Write-Host "    Adding variable: $key" -ForegroundColor Gray
            az pipelines variable-group variable create `
                --org $orgUrl `
                --project $project `
                --group-id $vgId `
                --name $key `
                --value $value `
                2>&1 | Out-Null
        }
        
        # Delete the placeholder variable
        az pipelines variable-group variable delete `
            --org $orgUrl `
            --project $project `
            --group-id $vgId `
            --name "PLACEHOLDER" `
            --yes `
            2>&1 | Out-Null
        
        Write-Host "  [OK] Added all variables to $vgName" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Failed to create variable group: $vgName" -ForegroundColor Red
        Write-Host "  $result" -ForegroundColor Red
    }
}

Write-Host ""

# Create environments for deployment tracking
Write-Host "[Creating Environments]" -ForegroundColor Yellow

# Map environment names (prod -> production for ADO)
$envMap = @{
    'dev' = 'dev'
    'test' = 'test'
    'prod' = 'production'
}

# Get ADO token from environment variable (set by setup.ps1)
$adoToken = $env:AZURE_DEVOPS_EXT_PAT
if (-not $adoToken) {
    Write-Host "  [WARNING] AZURE_DEVOPS_EXT_PAT not set, attempting to get token..." -ForegroundColor Yellow
    $adoToken = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
}

$orgName = $orgUrl -replace 'https://dev\.azure\.com/', ''

foreach ($env in $environments) {
    $envName = $envMap[$env]
    
    # Check if environment exists using Invoke-RestMethod
    $checkUrl = "https://dev.azure.com/$orgName/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"
    
    try {
        $headers = @{
            'Authorization' = "Bearer $adoToken"
            'Content-Type' = 'application/json'
        }
        
        $existingEnvs = Invoke-RestMethod -Uri $checkUrl -Method Get -Headers $headers -ErrorAction SilentlyContinue
        $existing = $existingEnvs.value | Where-Object { $_.name -eq $envName }
        
        if ($existing) {
            Write-Host "  [OK] Environment already exists: $envName" -ForegroundColor Green
            continue
        }
    } catch {
        Write-Host "  [WARNING] Could not check existing environments: $_" -ForegroundColor Yellow
    }
    
    # Create environment via REST API
    Write-Host "  [INFO] Creating environment: $envName" -ForegroundColor Blue
    
    $createUrl = "https://dev.azure.com/$orgName/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"
    $body = @{
        name = $envName
        description = "$envName environment for $projectName"
    }
    
    try {
        $result = Invoke-RestMethod -Uri $createUrl -Method Post -Headers $headers -Body ($body | ConvertTo-Json) -ContentType 'application/json'
        Write-Host "  [OK] Created environment: $envName (ID: $($result.id))" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Failed to create environment: $envName" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            Write-Host "  Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "[OK] Environment setup completed" -ForegroundColor Green
exit 0
