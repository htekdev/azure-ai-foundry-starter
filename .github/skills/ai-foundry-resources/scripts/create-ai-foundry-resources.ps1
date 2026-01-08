#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates Azure AI Foundry resources (AI Services and Projects) for multi-environment deployment.

.DESCRIPTION
    This specialized skill creates Azure AI Services resources (kind: AIServices) with custom domains
    and AI Foundry Projects for each environment. It also configures RBAC permissions for Service
    Principals to access the AI Services resources.
    
    IMPORTANT: This creates AI Services resources (kind: AIServices), NOT ML Workspace hubs.
    Projects are created using 'az cognitiveservices account project create'.

.PARAMETER ResourceGroupBaseName
    Base name for resource groups (will be appended with -dev, -test, -prod)

.PARAMETER AIProjectBaseName
    Base name for AI Services resources and projects

.PARAMETER Location
    Azure region for resources (default: eastus)

.PARAMETER Environment
    Which environment(s) to create: 'dev', 'test', 'prod', or 'all' (default: all)

.PARAMETER ServicePrincipalAppId
    AppId of Service Principal to grant Cognitive Services User role

.PARAMETER UseConfig
    Load configuration from starter-config.json file

.PARAMETER UpdateConfig
    Update starter-config.json with project endpoints (default: true)

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./create-ai-foundry-resources.ps1 -ResourceGroupBaseName "rg-aif-demo" -AIProjectBaseName "aif-demo"

.EXAMPLE
    ./create-ai-foundry-resources.ps1 -UseConfig -Environment "dev"

.OUTPUTS
    PSCustomObject with creation results for each environment's AI resources
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupBaseName,

    [Parameter(Mandatory = $false)]
    [string]$AIProjectBaseName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'test', 'prod', 'all')]
    [string]$Environment = 'all',

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalAppId,

    [Parameter(Mandatory = $false)]
    [switch]$UseConfig,

    [Parameter(Mandatory = $false)]
    [bool]$UpdateConfig = $true,

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
    . "$PSScriptRoot/../configuration-management/config-functions.ps1"
    $config = Get-StarterConfig
    
    if ($config) {
        $ResourceGroupBaseName = $config.azure.resourceGroup
        $Location = $config.azure.location
        $AIProjectBaseName = $ResourceGroupBaseName
        
        # Get Service Principal AppId from config if available
        if ($config.servicePrincipal.appId -and $config.servicePrincipal.appId -ne '00000000-0000-0000-0000-000000000000') {
            $ServicePrincipalAppId = $config.servicePrincipal.appId
        }
        
        Write-Host "✅ Loaded configuration from starter-config.json" -ForegroundColor Green
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

if (-not $AIProjectBaseName) {
    Write-Error "AIProjectBaseName is required. Use -UseConfig or specify -AIProjectBaseName"
    exit 1
}

# Determine which environments to create
$environments = @()
if ($Environment -eq 'all') {
    $environments = @('dev', 'test', 'prod')
} else {
    $environments = @($Environment)
}

# Get subscription information
$subscriptionId = az account show --query id -o tsv

# Results tracking
$results = @{
    Timestamp       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Environments    = @()
    Summary         = @{
        Created = 0
        Skipped = 0
        Failed  = 0
    }
}

Write-Host "=== Azure AI Foundry Resources Creation ===" -ForegroundColor Cyan
Write-Host "Resource Group Base: $ResourceGroupBaseName" -ForegroundColor Gray
Write-Host "AI Project Base: $AIProjectBaseName" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host "Environments: $($environments -join ', ')" -ForegroundColor Gray
Write-Host "Creating Azure AI Services (kind: AIServices) with projects" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "[AI Foundry Resources and Projects]" -ForegroundColor Yellow
    
    foreach ($env in $environments) {
        $rgName = "$ResourceGroupBaseName-$env"
        $resourceName = "aif-foundry-$env"
        $projectName = "aif-project-$env"
        
        $envResult = @{
            Environment     = $env
            ResourceGroup   = $rgName
            AIServices      = @{
                Name        = $resourceName
                Status      = $null
                Message     = $null
            }
            Project         = @{
                Name        = $projectName
                Status      = $null
                Message     = $null
                Endpoint    = $null
            }
            RBAC            = @{
                Status      = $null
                Message     = $null
            }
        }
        
        Write-Host "  Environment: $env" -ForegroundColor Cyan
        Write-Host "    Resource: $resourceName (AIServices)" -ForegroundColor Gray
        Write-Host "    Project: $projectName" -ForegroundColor Gray
        
        try {
            # ===== CREATE AI SERVICES RESOURCE =====
            $existingResource = az cognitiveservices account show `
                --name $resourceName `
                --resource-group $rgName `
                --only-show-errors 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✅ AI Services resource already exists" -ForegroundColor Green
                $envResult.AIServices.Status = "Skipped"
                $envResult.AIServices.Message = "Already exists"
                $results.Summary.Skipped++
            }
            else {
                # Create AI Services resource (kind: AIServices with custom domain)
                Write-Host "    Creating AI Services resource..." -ForegroundColor Gray
                $resourceJson = az cognitiveservices account create `
                    --name $resourceName `
                    --resource-group $rgName `
                    --kind AIServices `
                    --sku S0 `
                    --location $Location `
                    --custom-domain $resourceName `
                    --yes `
                    --only-show-errors 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✅ AI Services resource created" -ForegroundColor Green
                    $envResult.AIServices.Status = "Created"
                    $envResult.AIServices.Message = "Created in $Location"
                    $results.Summary.Created++
                }
                else {
                    throw "Failed to create AI Services resource: $resourceJson"
                }
            }
            
            # Wait a moment for resource to be fully provisioned
            Start-Sleep -Seconds 3
            
            # ===== CREATE AI FOUNDRY PROJECT =====
            $existingProject = az cognitiveservices account project show `
                --name $resourceName `
                --resource-group $rgName `
                --project-name $projectName `
                --only-show-errors 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✅ Project already exists" -ForegroundColor Green
                
                # Try to get existing project endpoint
                try {
                    $existingProjectObj = $existingProject | ConvertFrom-Json
                    $projectEndpoint = $existingProjectObj.properties.endpoints.'AI Foundry API'
                    $envResult.Project.Endpoint = $projectEndpoint
                    Write-Host "    Project Endpoint: $projectEndpoint" -ForegroundColor Cyan
                }
                catch {
                    Write-Host "    ⚠️  Could not parse existing project endpoint" -ForegroundColor Yellow
                }
                
                $envResult.Project.Status = "Skipped"
                $envResult.Project.Message = "Already exists"
                $results.Summary.Skipped++
            }
            else {
                # Create AI Foundry Project under the AI Services resource
                Write-Host "    Creating AI Foundry project..." -ForegroundColor Gray
                $projectJson = az cognitiveservices account project create `
                    --name $resourceName `
                    --resource-group $rgName `
                    --project-name $projectName `
                    --location $Location `
                    --only-show-errors 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✅ Project created successfully" -ForegroundColor Green
                    
                    # Parse project details to get endpoint
                    try {
                        $project = $projectJson | ConvertFrom-Json
                        $projectEndpoint = $project.properties.endpoints.'AI Foundry API'
                        
                        Write-Host "    Project Endpoint: $projectEndpoint" -ForegroundColor Cyan
                        
                        $envResult.Project.Status = "Created"
                        $envResult.Project.Message = "Successfully created"
                        $envResult.Project.Endpoint = $projectEndpoint
                        $results.Summary.Created++
                        
                        # Update starter-config.json with project endpoint
                        if ($UpdateConfig) {
                            $configPath = "$PSScriptRoot/../../../starter-config.json"
                            if (Test-Path $configPath) {
                                try {
                                    $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
                                    $configContent.azure.aiFoundry.$env.projectEndpoint = $projectEndpoint
                                    $configContent.metadata.lastModified = (Get-Date -Format "yyyy-MM-dd")
                                    $configContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
                                    Write-Host "    ✅ Configuration updated with project endpoint" -ForegroundColor Green
                                }
                                catch {
                                    Write-Host "    ⚠️  Failed to update config: $_" -ForegroundColor Yellow
                                }
                            }
                        }
                    }
                    catch {
                        Write-Host "    ⚠️  Could not parse project endpoint" -ForegroundColor Yellow
                        $envResult.Project.Status = "Created"
                        $envResult.Project.Message = "Created but endpoint not parsed"
                        $results.Summary.Created++
                    }
                }
                else {
                    throw "Failed to create project: $projectJson"
                }
            }
            
            # ===== GRANT RBAC PERMISSIONS TO SERVICE PRINCIPAL =====
            if ($ServicePrincipalAppId) {
                Write-Host "    Assigning Cognitive Services User role to Service Principal..." -ForegroundColor Gray
                
                $resourceId = "/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.CognitiveServices/accounts/$resourceName"
                az role assignment create `
                    --assignee $ServicePrincipalAppId `
                    --role "Cognitive Services User" `
                    --scope $resourceId `
                    --only-show-errors 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✅ Cognitive Services User role assigned" -ForegroundColor Green
                    $envResult.RBAC.Status = "Assigned"
                    $envResult.RBAC.Message = "Cognitive Services User on $resourceName"
                }
                else {
                    Write-Host "    ⚠️  RBAC assignment failed (may already exist)" -ForegroundColor Yellow
                    $envResult.RBAC.Status = "Skipped"
                    $envResult.RBAC.Message = "Failed or already exists"
                }
            }
            else {
                Write-Host "    ℹ️  No Service Principal specified, skipping RBAC" -ForegroundColor Gray
                $envResult.RBAC.Status = "Skipped"
                $envResult.RBAC.Message = "No Service Principal specified"
            }
            
        }
        catch {
            Write-Host "    ❌ Failed to create AI resources for $env`: $_" -ForegroundColor Red
            Write-Host "    Error details: $($_.Exception.Message)" -ForegroundColor Gray
            $envResult.AIServices.Status = "Failed"
            $envResult.AIServices.Message = $_.Exception.Message
            $envResult.Project.Status = "Failed"
            $envResult.Project.Message = $_.Exception.Message
            $results.Summary.Failed++
        }
        
        $results.Environments += $envResult
        Write-Host ""
    }
    
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
        Write-Host "❌ Some AI resources failed to create" -ForegroundColor Red
        exit 1
    }
    elseif ($results.Summary.Created -gt 0) {
        Write-Host "✅ AI Foundry resource creation completed successfully" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "✅ All AI resources already exist" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "AI Foundry resource creation error: $_"
    exit 2
}
