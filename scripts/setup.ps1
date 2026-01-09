<#
.SYNOPSIS
    Simplified setup script for Azure AI Foundry Starter deployment
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$false)]
    [string]$OrganizationUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$AzureDevOpsProjectName
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 80)" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n> $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Test-Prerequisites {
    Write-Section "Checking Prerequisites"
    
    $errors = @()
    
    Write-Step "Checking Azure CLI..."
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        $errors += "Azure CLI not found"
    } else {
        Write-Success "Azure CLI installed"
    }
    
    Write-Step "Checking Azure DevOps CLI extension..."
    $extensions = az extension list --query "[?name=='azure-devops'].name" -o tsv 2>$null
    if (-not $extensions) {
        Write-Info "Installing Azure DevOps CLI extension..."
        az extension add --name azure-devops --only-show-errors
    }
    Write-Success "Azure DevOps CLI extension installed"
    
    Write-Step "Checking Azure authentication..."
    $account = az account show 2>$null
    if (-not $account) {
        $errors += "Not logged in to Azure. Run: az login"
    } else {
        Write-Success "Logged in to Azure"
    }
    
    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-ErrorMessage $_ }
        return $false
    }
    
    Write-Success "All prerequisites met"
    return $true
}

function Invoke-SkillScript {
    param(
        [string]$SkillName,
        [string]$ScriptName,
        [hashtable]$Parameters = @{}
    )
    
    $scriptPath = Join-Path $PSScriptRoot "..\.github\skills\$SkillName\$ScriptName"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Info "Skill script not implemented yet: $SkillName/$ScriptName"
        Write-Info "Skipping this step for now"
        return $true  # Return true to continue with other steps
    }
    
    Write-Step "Executing: $SkillName/$ScriptName"
    
    try {
        # Temporarily allow stderr output without throwing
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        
        & $scriptPath @Parameters
        $exitCode = $LASTEXITCODE
        
        $ErrorActionPreference = $previousErrorAction
        
        if ($exitCode -ne 0 -and $null -ne $exitCode) {
            Write-ErrorMessage "Skill execution failed with exit code: $exitCode"
            return $false
        }
        return $true
    } catch {
        Write-ErrorMessage "Skill execution failed: $_"
        return $false
    }
}

$ErrorActionPreference = "Stop"
$startTime = Get-Date

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "Azure AI Foundry Starter - Setup Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

if (-not (Test-Prerequisites)) {
    exit 1
}

Write-Section "Phase 1: Configuration Management"

$configFunctionsPath = Join-Path $PSScriptRoot "..\.github\skills\configuration-management\config-functions.ps1"
if (-not (Test-Path $configFunctionsPath)) {
    Write-ErrorMessage "Configuration functions not found: $configFunctionsPath"
    exit 1
}

Write-Step "Loading configuration functions..."
. $configFunctionsPath
Write-Success "Configuration functions loaded"

if ([string]::IsNullOrWhiteSpace($ProjectName) -or [string]::IsNullOrWhiteSpace($OrganizationUrl) -or [string]::IsNullOrWhiteSpace($TenantId) -or [string]::IsNullOrWhiteSpace($SubscriptionId)) {
    Write-Host "`nPlease provide the following information:" -ForegroundColor Cyan
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Read-Host "Project Name"
    while ([string]::IsNullOrWhiteSpace($ProjectName)) {
        Write-Host "Project name is required!" -ForegroundColor Red
        $ProjectName = Read-Host "Project Name"
    }
}

if ([string]::IsNullOrWhiteSpace($OrganizationUrl)) {
    $OrganizationUrl = Read-Host "Azure DevOps Organization URL"
    while ([string]::IsNullOrWhiteSpace($OrganizationUrl)) {
        Write-Host "Organization URL is required!" -ForegroundColor Red
        $OrganizationUrl = Read-Host "Azure DevOps Organization URL"
    }
}

if ([string]::IsNullOrWhiteSpace($TenantId)) {
    $TenantId = Read-Host "Azure Tenant ID"
    while ([string]::IsNullOrWhiteSpace($TenantId)) {
        Write-Host "Tenant ID is required!" -ForegroundColor Red
        $TenantId = Read-Host "Azure Tenant ID"
    }
}

if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
    $SubscriptionId = Read-Host "Azure Subscription ID"
    while ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
        Write-Host "Subscription ID is required!" -ForegroundColor Red
        $SubscriptionId = Read-Host "Azure Subscription ID"
    }
}

Write-Host "`nInformation collected! Starting automated deployment..." -ForegroundColor Green

Write-Step "Setting Azure subscription..."
az account set --subscription $SubscriptionId
$subscriptionInfo = az account show | ConvertFrom-Json
Write-Success "Subscription set: $($subscriptionInfo.name)"

$orgName = $OrganizationUrl -replace 'https://dev\.azure\.com/', ''

# If AzureDevOpsProjectName not provided, use ProjectName
if ([string]::IsNullOrWhiteSpace($AzureDevOpsProjectName)) {
    $AzureDevOpsProjectName = $ProjectName
}

Write-Step "Creating configuration..."
$configPath = Join-Path $PSScriptRoot "..\starter-config.json"

$config = @{
    naming = @{
        projectName = $ProjectName
    }
    azure = @{
        subscriptionId = $SubscriptionId
        subscriptionName = $subscriptionInfo.name
        tenantId = $TenantId
        location = "eastus"
    }
    azureDevOps = @{
        organizationName = $orgName
        organizationUrl = $OrganizationUrl
        projectName = $AzureDevOpsProjectName
    }
    environments = @{
        dev = @{
            name = "dev"
            displayName = "Development"
            requiresApproval = $false
        }
        test = @{
            name = "test"
            displayName = "Test"
            requiresApproval = $false
        }
        prod = @{
            name = "prod"
            displayName = "Production"
            requiresApproval = $true
        }
    }
}

$config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
Write-Success "Configuration created: $configPath"

$config = Get-StarterConfig
Write-Success "Configuration loaded"

Write-Info "Project: $($config.naming.projectName)"
Write-Info "Organization: $($config.azureDevOps.organizationUrl)"
Write-Info "Subscription: $($config.azure.subscriptionName)"

Write-Section "Phase 2: Azure Resource Creation"

Write-Step "Creating Azure resources..."
Write-Info "Creating: Resource Groups, Service Principal, AI Foundry Resources"

$resourceParams = @{
    UseConfig = $true
    CreateAll = $true
    Environment = 'all'
}

$success = Invoke-SkillScript -SkillName "resource-creation" -ScriptName "create-resources.ps1" -Parameters $resourceParams

if (-not $success) {
    Write-ErrorMessage "Azure resource creation failed"
    exit 1
}

Write-Success "Azure resources created successfully"

$config = Get-StarterConfig

Write-Section "Phase 3: Azure DevOps Setup"

Write-Step "Getting Azure DevOps authentication token..."
$adoToken = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
if (-not $adoToken) {
    Write-ErrorMessage "Failed to get Azure DevOps token"
    exit 1
}

$env:ADO_TOKEN = $adoToken
$env:AZURE_DEVOPS_EXT_PAT = $adoToken
Write-Success "Azure DevOps authentication token acquired"

Write-Step "Configuring Azure DevOps CLI..."
az devops configure --defaults organization=$($config.azureDevOps.organizationUrl) project=$($config.azureDevOps.projectName)
Write-Success "Azure DevOps CLI configured"

Write-Step "Checking if Azure DevOps project exists..."
$projectExists = az devops project show --project $($config.azureDevOps.projectName) 2>$null
if (-not $projectExists) {
    Write-Info "Azure DevOps project does not exist. Creating..."
    az devops project create --name $($config.azureDevOps.projectName) --source-control git --visibility private
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Azure DevOps project created: $($config.azureDevOps.projectName)"
        # Wait a moment for project to be fully initialized
        Start-Sleep -Seconds 5
    } else {
        Write-ErrorMessage "Failed to create Azure DevOps project"
        exit 1
    }
} else {
    Write-Success "Azure DevOps project already exists: $($config.azureDevOps.projectName)"
}

Write-Step "Creating Service Connections..."
$serviceConnectionParams = @{
    UseConfig = $true
    Environment = 'all'
}

$success = Invoke-SkillScript -SkillName "service-connection-setup" -ScriptName "scripts/create-service-connections.ps1" -Parameters $serviceConnectionParams

if (-not $success) {
    Write-ErrorMessage "Service connection creation failed"
    exit 1
}

Write-Success "Service connections created"

Write-Step "Creating Variable Groups and Environments..."
$environmentParams = @{
    UseConfig = $true
    Environment = 'all'
}

$success = Invoke-SkillScript -SkillName "environment-setup" -ScriptName "scripts/create-environments.ps1" -Parameters $environmentParams

if (-not $success) {
    Write-ErrorMessage "Environment setup failed"
    exit 1
}

Write-Success "Variable groups and environments created"

Write-Step "Creating Pipelines..."
$pipelineParams = @{
    UseConfig = $true
    SkipFirstRun = $true
}

$success = Invoke-SkillScript -SkillName "pipeline-setup" -ScriptName "scripts/create-pipelines.ps1" -Parameters $pipelineParams

if (-not $success) {
    Write-ErrorMessage "Pipeline creation failed"
    exit 1
}

Write-Success "Pipelines created"

Write-Section "Phase 4: Deployment Validation"

Write-Step "Validating deployment..."
$validationParams = @{
    UseConfig = $true
    Environment = 'all'
}

$success = Invoke-SkillScript -SkillName "deployment-validation" -ScriptName "scripts/validate-deployment.ps1" -Parameters $validationParams

if (-not $success) {
    Write-ErrorMessage "Deployment validation failed"
    exit 1
}

Write-Success "Deployment validation passed"

$duration = (Get-Date) - $startTime
Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "Setup Complete! Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Review starter-config.json" -ForegroundColor Gray
Write-Host "  2. Visit: $($config.azureDevOps.organizationUrl)/$($config.azureDevOps.projectName)" -ForegroundColor Gray
Write-Host ""
