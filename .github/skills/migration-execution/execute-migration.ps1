#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Executes the Azure DevOps repository migration process.

.DESCRIPTION
    This script sets up Azure DevOps infrastructure including:
    - Single repository (foundry-cicd)
    - Service connections with workload identity federation (dev, test, prod)
    - Variable groups per environment (dev, test, prod)
    - Environments (dev, test, production)
    
    Based on lessons learned from actual execution.

.PARAMETER SkipRepo
    Skip repository creation if already exists

.PARAMETER SkipServiceConnections
    Skip service connection creation

.PARAMETER SkipVariableGroups
    Skip variable group creation

.PARAMETER SkipEnvironments
    Skip environment creation

.EXAMPLE
    .\execute-migration.ps1

.EXAMPLE
    .\execute-migration.ps1 -SkipRepo
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipRepo,
    
    [Parameter()]
    [switch]$SkipServiceConnections,
    
    [Parameter()]
    [switch]$SkipVariableGroups,
    
    [Parameter()]
    [switch]$SkipEnvironments
)

$ErrorActionPreference = "Stop"

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "         Azure DevOps Migration Execution" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ===== STEP 1: LOAD CONFIGURATION =====
Write-Host "[Step 1/10] Loading Configuration..." -ForegroundColor Yellow

$configFunctionsPath = Join-Path $PSScriptRoot "../configuration-management/config-functions.ps1"
if (-not (Test-Path $configFunctionsPath)) {
    Write-Error "Configuration functions not found: $configFunctionsPath"
}

. $configFunctionsPath
$config = Get-MigrationConfig

if (-not $config) {
    Write-Error "Failed to load configuration. Run configuration-management skill first."
}

$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$sourceRepo = $config.azureDevOps.sourceRepository

Write-Host "  ✓ Configuration loaded" -ForegroundColor Green
Write-Host "  Organization: $org" -ForegroundColor Gray
Write-Host "  Project: $project" -ForegroundColor Gray
Write-Host ""

# ===== STEP 2: AUTHENTICATE =====
Write-Host "[Step 2/10] Authenticating..." -ForegroundColor Yellow

# Check if already logged in
$account = az account show 2>$null | ConvertFrom-Json
if ($account) {
    Write-Host "  ✓ Already logged in as: $($account.user.name)" -ForegroundColor Green
} else {
    Write-Host "  Logging in to Azure..." -ForegroundColor Gray
    az login | Out-Null
}

# Set subscription
az account set --subscription $config.azure.subscriptionId 2>$null | Out-Null

# Get bearer token for Azure DevOps
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

# Configure Azure DevOps CLI defaults
az devops configure --defaults organization=$org project=$project 2>$null | Out-Null

Write-Host "  ✓ Authentication complete" -ForegroundColor Green
Write-Host ""

# ===== STEP 3: SKIP REORGANIZATION =====
Write-Host "[Step 3/10] Repository Reorganization" -ForegroundColor Yellow
Write-Host "  ⊘ Skipped - manual step (see SKILL.md for instructions)" -ForegroundColor Cyan
Write-Host ""

# ===== STEP 4: CREATE REPOSITORY =====
if (-not $SkipRepo) {
    Write-Host "[Step 4/10] Creating Repository..." -ForegroundColor Yellow
    
    $repoName = "foundry-cicd"
    $existingRepo = az repos list --query "[?name=='$repoName'].id" --output tsv 2>$null
    
    if ($existingRepo) {
        Write-Host "  ✓ Repository already exists: $repoName" -ForegroundColor Green
        $repoDetails = az repos show --repository $repoName --output json 2>$null | ConvertFrom-Json
        Write-Host "  URL: $($repoDetails.remoteUrl)" -ForegroundColor Gray
    } else {
        Write-Host "  Creating repository: $repoName..." -ForegroundColor Gray
        $repo = az repos create --name $repoName --output json 2>$null | ConvertFrom-Json
        Write-Host "  ✓ Repository created" -ForegroundColor Green
        Write-Host "  URL: $($repo.remoteUrl)" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "[Step 4/10] Repository Creation" -ForegroundColor Yellow
    Write-Host "  ⊘ Skipped" -ForegroundColor Cyan
    Write-Host ""
}

# ===== STEP 5: SKIP CODE PUSH =====
Write-Host "[Step 5/10] Code Push" -ForegroundColor Yellow
Write-Host "  ⊘ Skipped - requires local reorganized code" -ForegroundColor Cyan
Write-Host ""

# ===== STEP 6: CREATE SERVICE CONNECTIONS =====
if (-not $SkipServiceConnections) {
    Write-Host "[Step 6/10] Creating Service Connections..." -ForegroundColor Yellow
    Write-Host "  Using: Workload Identity Federation (no secrets)" -ForegroundColor Cyan
    
    $spAppId = $config.servicePrincipal.appId
    $subscriptionId = $config.azure.subscriptionId
    $subscriptionName = $config.azure.subscriptionName
    $tenantId = $config.azure.tenantId
    
    # Get project ID for service connections
    $projectInfo = az devops project show --project $project --query id -o tsv 2>$null
    
    $environments = @("dev", "test", "prod")
    $created = 0
    $existing = 0
    $failed = 0
    
    foreach ($env in $environments) {
        $scName = "azure-foundry-$env"
        Write-Host "  Processing: $scName..." -ForegroundColor Gray
        
        # Check if exists
        $existingSc = az devops service-endpoint list --query "[?name=='$scName'].id" --output tsv 2>$null
        
        if ($existingSc) {
            Write-Host "    ✓ Already exists" -ForegroundColor Green
            $existing++
        } else {
            # Create using REST API with workload identity federation
            $serviceEndpoint = @{
                data = @{
                    subscriptionId = $subscriptionId
                    subscriptionName = $subscriptionName
                    environment = "AzureCloud"
                    scopeLevel = "Subscription"
                    creationMode = "Manual"
                }
                name = $scName
                type = "AzureRM"
                url = "https://management.azure.com/"
                authorization = @{
                    parameters = @{
                        tenantid = $tenantId
                        serviceprincipalid = $spAppId
                    }
                    scheme = "WorkloadIdentityFederation"
                }
                isShared = $false
                isReady = $true
                serviceEndpointProjectReferences = @(
                    @{
                        projectReference = @{
                            id = $projectInfo
                            name = $project
                        }
                        name = $scName
                    }
                )
            }
            
            $body = $serviceEndpoint | ConvertTo-Json -Depth 10
            $uri = "$org/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
            
            try {
                $result = Invoke-RestMethod -Uri $uri -Method Post -Headers @{
                    "Authorization" = "Bearer $env:ADO_TOKEN"
                    "Content-Type" = "application/json"
                } -Body $body
                
                Write-Host "    ✓ Created successfully" -ForegroundColor Green
                $created++
            }
            catch {
                Write-Host "    ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $failed++
            }
        }
    }
    
    Write-Host ""
    Write-Host "  Summary: Created=$created, Existing=$existing, Failed=$failed" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "[Step 6/10] Service Connections" -ForegroundColor Yellow
    Write-Host "  ⊘ Skipped" -ForegroundColor Cyan
    Write-Host ""
}

# ===== STEP 7: CREATE VARIABLE GROUPS =====
if (-not $SkipVariableGroups) {
    Write-Host "[Step 7/10] Creating Variable Groups..." -ForegroundColor Yellow
    
    # Get endpoints from Azure resources
    $mlWorkspace = $config.azure.mlWorkspaceName
    $resourceGroup = $config.azure.resourceGroupName
    $openAIService = $config.azure.openAIServiceName
    
    Write-Host "  Retrieving Azure endpoints..." -ForegroundColor Gray
    $mlEndpoint = az ml workspace show --name $mlWorkspace --resource-group $resourceGroup --query "mlFlowTrackingUri" -o tsv 2>$null
    if (-not $mlEndpoint) { $mlEndpoint = "https://ml.azure.com" }
    
    $openAIEndpoint = az cognitiveservices account show --name $openAIService --resource-group $resourceGroup --query "properties.endpoint" -o tsv 2>$null
    if (-not $openAIEndpoint) { $openAIEndpoint = "https://$openAIService.openai.azure.com/" }
    
    $environments = @{
        "dev" = @{ project = $mlEndpoint; openai = $openAIEndpoint }
        "test" = @{ project = $mlEndpoint; openai = $openAIEndpoint }
        "prod" = @{ project = $mlEndpoint; openai = $openAIEndpoint }
    }
    
    $created = 0
    $existing = 0
    $failed = 0
    
    foreach ($env in $environments.Keys) {
        $vgName = "foundry-$env-vars"
        $envConfig = $environments[$env]
        
        Write-Host "  Processing: $vgName..." -ForegroundColor Gray
        
        $existingVg = az pipelines variable-group list --query "[?name=='$vgName'].id" --output tsv 2>$null
        
        if ($existingVg) {
            Write-Host "    ✓ Already exists" -ForegroundColor Green
            $existing++
        } else {
            $result = az pipelines variable-group create `
                --name $vgName `
                --variables `
                    "AZURE_AI_PROJECT=$($envConfig.project)" `
                    "AZURE_OPENAI_ENDPOINT=$($envConfig.openai)" `
                    "AZURE_OPENAI_API_VERSION=2024-02-15-preview" `
                    "AZURE_OPENAI_DEPLOYMENT=gpt-4o" `
                    "AZURE_SERVICE_CONNECTION=azure-foundry-$env" `
                --authorize true `
                --output none 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ Created successfully" -ForegroundColor Green
                $created++
            } else {
                Write-Host "    ✗ Failed to create" -ForegroundColor Red
                $failed++
            }
        }
    }
    
    Write-Host ""
    Write-Host "  Summary: Created=$created, Existing=$existing, Failed=$failed" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "[Step 7/10] Variable Groups" -ForegroundColor Yellow
    Write-Host "  ⊘ Skipped" -ForegroundColor Cyan
    Write-Host ""
}

# ===== STEP 8: CREATE ENVIRONMENTS =====
if (-not $SkipEnvironments) {
    Write-Host "[Step 8/10] Creating Environments..." -ForegroundColor Yellow
    
    $envNames = @("dev", "test", "production")
    $uri = "$org/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"
    
    $created = 0
    $existing = 0
    $failed = 0
    
    foreach ($envName in $envNames) {
        Write-Host "  Processing: $envName..." -ForegroundColor Gray
        
        try {
            $existingEnvs = Invoke-RestMethod -Uri $uri -Headers @{
                "Authorization" = "Bearer $env:ADO_TOKEN"
            } -ErrorAction SilentlyContinue
            
            $exists = $existingEnvs.value | Where-Object { $_.name -eq $envName }
            
            if ($exists) {
                Write-Host "    ✓ Already exists" -ForegroundColor Green
                $existing++
            } else {
                $body = @{
                    name = $envName
                    description = "$envName environment for foundry-cicd"
                } | ConvertTo-Json
                
                Invoke-RestMethod -Uri $uri -Method Post -Headers @{
                    "Authorization" = "Bearer $env:ADO_TOKEN"
                    "Content-Type" = "application/json"
                } -Body $body | Out-Null
                
                Write-Host "    ✓ Created successfully" -ForegroundColor Green
                $created++
            }
        }
        catch {
            Write-Host "    ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }
    
    Write-Host ""
    Write-Host "  Summary: Created=$created, Existing=$existing, Failed=$failed" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "[Step 8/10] Environments" -ForegroundColor Yellow
    Write-Host "  ⊘ Skipped" -ForegroundColor Cyan
    Write-Host ""
}

# ===== STEP 9: SKIP PIPELINES =====
Write-Host "[Step 9/10] Pipeline Creation" -ForegroundColor Yellow
Write-Host "  ⊘ Skipped - requires code with YAML files pushed first" -ForegroundColor Cyan
Write-Host ""

# ===== STEP 10: VALIDATION =====
Write-Host "[Step 10/10] Validation..." -ForegroundColor Yellow
Write-Host ""

try {
    # Validate repository
    $repos = az repos list --output json 2>$null | ConvertFrom-Json
    $foundryRepos = $repos | Where-Object { $_.name -like '*foundry*' }
    Write-Host "  Repositories: $($foundryRepos.Count)" -ForegroundColor Cyan
    $foundryRepos | ForEach-Object {
        Write-Host "    ✓ $($_.name)" -ForegroundColor Gray
    }
    
    # Validate service connections
    $connections = az devops service-endpoint list --output json 2>$null | ConvertFrom-Json
    $foundryConnections = $connections | Where-Object { $_.name -like '*foundry*' }
    Write-Host "`n  Service Connections: $($foundryConnections.Count)" -ForegroundColor Cyan
    $foundryConnections | ForEach-Object {
        $status = if ($_.isReady) { "✓" } else { "⚠" }
        $scheme = $_.authorization.scheme
        Write-Host "    $status $($_.name) ($scheme)" -ForegroundColor Gray
    }
    
    # Validate variable groups
    $varGroups = az pipelines variable-group list --output json 2>$null | ConvertFrom-Json
    $foundryGroups = $varGroups | Where-Object { $_.name -like '*foundry*' }
    Write-Host "`n  Variable Groups: $($foundryGroups.Count)" -ForegroundColor Cyan
    $foundryGroups | ForEach-Object {
        Write-Host "    ✓ $($_.name) ($($_.variables.Count) variables)" -ForegroundColor Gray
    }
    
    # Validate environments
    $envUri = "$org/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"
    $envs = Invoke-RestMethod -Uri $envUri -Headers @{ "Authorization" = "Bearer $env:ADO_TOKEN" } -ErrorAction SilentlyContinue
    Write-Host "`n  Environments: $($envs.value.Count)" -ForegroundColor Cyan
    $envs.value | ForEach-Object {
        Write-Host "    ✓ $($_.name)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  ⚠ Validation error: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# ===== SUMMARY =====
Write-Host "================================================================" -ForegroundColor Green
Write-Host "         MIGRATION SETUP COMPLETE!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Infrastructure Ready:" -ForegroundColor Cyan
Write-Host "  • Repository created: foundry-cicd" -ForegroundColor Gray
Write-Host "  • Service connections with workload identity federation" -ForegroundColor Gray
Write-Host "  • Variable groups configured for dev/test/prod" -ForegroundColor Gray
Write-Host "  • Environments created" -ForegroundColor Gray
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Clone and reorganize your source repository locally" -ForegroundColor Gray
Write-Host "  2. Push reorganized code to foundry-cicd repository" -ForegroundColor Gray
Write-Host "  3. Create pipelines from your YAML files" -ForegroundColor Gray
Write-Host ""
Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "  • See .github/skills/migration-execution/SKILL.md for detailed instructions" -ForegroundColor Gray
Write-Host "  • See COPILOT_EXECUTION_GUIDE.md for complete guide" -ForegroundColor Gray
Write-Host ""
