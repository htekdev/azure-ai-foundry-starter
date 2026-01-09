#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates Azure DevOps service connections with Workload Identity Federation

.DESCRIPTION
    This script creates service connections for Azure DevOps pipelines using
    Workload Identity Federation (no secrets!). It also configures federated
    credentials on the Service Principal.

.PARAMETER UseConfig
    Load configuration from starter-config.json file

.PARAMETER Environment
    Which environment(s) to create: 'dev', 'test', 'prod', or 'all' (default: all)

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./create-service-connections.ps1 -UseConfig

.EXAMPLE
    ./create-service-connections.ps1 -UseConfig -Environment dev
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

Write-Host "=== Azure DevOps Service Connection Setup ===" -ForegroundColor Cyan
Write-Host "Organization: $($config.azureDevOps.organizationUrl)" -ForegroundColor Gray
Write-Host "Project: $($config.azureDevOps.projectName)" -ForegroundColor Gray
Write-Host "Environments: $($environments -join ', ')" -ForegroundColor Gray
Write-Host ""

$orgUrl = $config.azureDevOps.organizationUrl
$orgName = $orgUrl -replace 'https://dev\.azure\.com/', ''
$project = $config.azureDevOps.projectName
$subscriptionId = $config.azure.subscriptionId
$subscriptionName = $config.azure.subscriptionName
$tenantId = $config.azure.tenantId
$spAppId = $config.servicePrincipal.appId
$projectName = $config.naming.projectName

if (-not $spAppId -or $spAppId -eq '00000000-0000-0000-0000-000000000000') {
    Write-Host "[ERROR] Service Principal not found in configuration" -ForegroundColor Red
    Write-Host "Please run resource creation first" -ForegroundColor Yellow
    exit 1
}

# Get project ID (required for REST API)
Write-Host "[Getting Project ID]" -ForegroundColor Yellow
$projectInfo = az devops project show --project $project --output json 2>$null | ConvertFrom-Json
if (-not $projectInfo) {
    Write-Host "[ERROR] Could not find project: $project" -ForegroundColor Red
    exit 1
}
$projectId = $projectInfo.id
Write-Host "  [OK] Project ID: $projectId" -ForegroundColor Green
Write-Host ""

Write-Host "[Creating Service Connections with Workload Identity Federation]" -ForegroundColor Yellow

# Check if ADO_TOKEN is set
if (-not $env:ADO_TOKEN) {
    Write-Host "[ERROR] ADO_TOKEN environment variable not set" -ForegroundColor Red
    Write-Host "Please set it first using: `$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query 'accessToken' -o tsv" -ForegroundColor Yellow
    exit 1
}

foreach ($env in $environments) {
    $scName = "$projectName-$env"
    $rgName = "rg-$projectName-$env"
    
    # Check if service connection already exists
    $existingSc = az devops service-endpoint list `
        --org $orgUrl `
        --project $project `
        --query "[?name=='$scName'].id" `
        -o tsv 2>$null
    
    if ($existingSc) {
        Write-Host "  [OK] Service connection already exists: $scName (ID: $existingSc)" -ForegroundColor Green
        
        # Ensure it's authorized for all pipelines
        az devops service-endpoint update --id $existingSc --enable-for-all true --org $orgUrl --project $project 2>$null
        continue
    }
    
    Write-Host "  [INFO] Creating service connection: $scName" -ForegroundColor Blue
    
    # Create service connection via REST API with Workload Identity Federation
    $apiUrl = "$orgUrl/$project/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
    
    $body = @{
        authorization = @{
            parameters = @{
                serviceprincipalid = $spAppId
                tenantid = $tenantId
            }
            scheme = "WorkloadIdentityFederation"
        }
        data = @{
            subscriptionId = $subscriptionId
            subscriptionName = $subscriptionName
            creationMode = "Manual"
        }
        name = $scName
        type = "azurerm"
        url = "https://management.azure.com/"
        description = "Service connection for $env environment using Workload Identity Federation"
        serviceEndpointProjectReferences = @(
            @{
                projectReference = @{
                    id = $projectId
                    name = $project
                }
                name = $scName
            }
        )
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers @{
            "Authorization" = "Bearer $env:ADO_TOKEN"
            "Content-Type" = "application/json"
        } -Body $body -ErrorAction Stop
        
        Write-Host "  [OK] Created service connection: $scName (ID: $($response.id))" -ForegroundColor Green
        
        # Wait a moment for the service connection to be fully created
        Start-Sleep -Seconds 2
        
        # Authorize for all pipelines
        az devops service-endpoint update --id $response.id --enable-for-all true --org $orgUrl --project $project 2>$null
        Write-Host "  [OK] Authorized service connection for all pipelines" -ForegroundColor Green
        
    } catch {
        Write-Host "  [ERROR] Failed to create service connection: $scName" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }
}

Write-Host ""

# Create federated credentials for each service connection
Write-Host "[Creating Federated Credentials]" -ForegroundColor Yellow

foreach ($env in $environments) {
    $scName = "$projectName-$env"
    $credName = "sc-$projectName-$env"
    
    # Check if credential already exists
    $existingCred = az ad app federated-credential list `
        --id $spAppId `
        --query "[?name=='$credName'].name" `
        -o tsv 2>$null
    
    if ($existingCred) {
        Write-Host "  [OK] Federated credential already exists: $credName" -ForegroundColor Green
        continue
    }
    
    Write-Host "  [INFO] Creating federated credential: $credName" -ForegroundColor Blue
    
    # CRITICAL: These values must match exactly what Azure DevOps sends
    $issuer = "https://vstoken.dev.azure.com/$orgName"
    $subject = "sc://$orgName/$project/$scName"
    
    # Create temp file for JSON to avoid escaping issues
    $tempFile = [System.IO.Path]::GetTempFileName()
    @{
        name = $credName
        issuer = $issuer
        subject = $subject
        description = "Federated credential for $scName service connection"
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json | Set-Content $tempFile -Encoding UTF8
    
    $credResult = az ad app federated-credential create `
        --id $spAppId `
        --parameters "@$tempFile" `
        2>&1
    
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Created federated credential: $credName" -ForegroundColor Green
        Write-Host "      Issuer: $issuer" -ForegroundColor Gray
        Write-Host "      Subject: $subject" -ForegroundColor Gray
    } else {
        Write-Host "  [ERROR] Failed to create federated credential: $credName" -ForegroundColor Red
        Write-Host "  $credResult" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[OK] Service connection setup completed" -ForegroundColor Green
exit 0
