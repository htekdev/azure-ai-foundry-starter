#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates and configures Azure resources required for repository migration.

.DESCRIPTION
    This script automates the creation of Azure resources including Service Principals,
    ML workspaces, OpenAI services, and supporting infrastructure. It checks for resource
    existence before creating and ensures proper RBAC configuration.

.PARAMETER UseConfig
    Load configuration from migration-config.json file

.PARAMETER ResourceGroupName
    Azure resource group name

.PARAMETER Location
    Azure region for resources

.PARAMETER ServicePrincipalName
    Name for the Service Principal

.PARAMETER MLWorkspaceName
    Name for the ML workspace

.PARAMETER OpenAIServiceName
    Name for the OpenAI service

.PARAMETER CreateServicePrincipal
    Create Service Principal if true

.PARAMETER CreateMLWorkspace
    Create ML workspace if true

.PARAMETER CreateOpenAI
    Create OpenAI service if true

.PARAMETER CreateAll
    Create all resources

.PARAMETER CheckExisting
    Check if resources exist before creating

.PARAMETER SkipIfExists
    Skip creation if resource already exists

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./create-resources.ps1 -UseConfig -CreateAll

.EXAMPLE
    ./create-resources.ps1 -ResourceGroupName "rg-demo" -Location "eastus" -CreateMLWorkspace
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$UseConfig,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalName,

    [Parameter(Mandatory = $false)]
    [string]$MLWorkspaceName,

    [Parameter(Mandatory = $false)]
    [string]$OpenAIServiceName,

    [Parameter(Mandatory = $false)]
    [bool]$CreateServicePrincipal = $false,

    [Parameter(Mandatory = $false)]
    [bool]$CreateMLWorkspace = $false,

    [Parameter(Mandatory = $false)]
    [bool]$CreateOpenAI = $false,

    [Parameter(Mandatory = $false)]
    [switch]$CreateAll,

    [Parameter(Mandatory = $false)]
    [switch]$CheckExisting,

    [Parameter(Mandatory = $false)]
    [switch]$SkipIfExists,

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

# Results tracking
$results = @{
    Timestamp       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ResourcesCreated = @()
    ResourcesSkipped = @()
    Errors          = @()
    Summary         = @{
        Created = 0
        Skipped = 0
        Failed  = 0
    }
}

# Load configuration if UseConfig is specified
if ($UseConfig) {
    . "$PSScriptRoot/../configuration-management/config-functions.ps1"
    $config = Get-MigrationConfig
    
    if ($config) {
        $ResourceGroupName = $config.azure.resourceGroupName
        $Location = $config.azure.location
        $ServicePrincipalName = $config.servicePrincipal.name
        $MLWorkspaceName = $config.azure.mlWorkspaceName
        $OpenAIServiceName = $config.azure.openAIServiceName
        
        Write-Host "✅ Loaded configuration from migration-config.json" -ForegroundColor Green
    }
    else {
        Write-Error "Could not load configuration. Run: ../configuration-management/configure-migration.ps1 -Interactive"
        exit 1
    }
}

# Set flags if CreateAll is specified
if ($CreateAll) {
    $CreateServicePrincipal = $true
    $CreateMLWorkspace = $true
    $CreateOpenAI = $true
}

# Validate required parameters
if (-not $ResourceGroupName) {
    Write-Error "ResourceGroupName is required. Use -UseConfig or specify -ResourceGroupName"
    exit 1
}

Write-Host "=== Azure Resource Creation ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host ""

# Helper function to add result
function Add-Result {
    param(
        [string]$Resource,
        [string]$Name,
        [string]$Status,
        [string]$Message
    )

    $result = @{
        Resource = $Resource
        Name     = $Name
        Status   = $Status
        Message  = $Message
    }

    switch ($Status) {
        'Created' {
            $results.ResourcesCreated += $result
            $results.Summary.Created++
        }
        'Skipped' {
            $results.ResourcesSkipped += $result
            $results.Summary.Skipped++
        }
        'Failed' {
            $results.Errors += $result
            $results.Summary.Failed++
        }
    }
}

try {
    # ===== CREATE RESOURCE GROUP =====
    Write-Host "[Resource Group]" -ForegroundColor Yellow
    try {
        $rgExistsResult = az group exists --name $ResourceGroupName
        if ($rgExistsResult -eq "true") {
            Write-Host "  ✅ Resource group already exists" -ForegroundColor Green
            Add-Result -Resource "ResourceGroup" -Name $ResourceGroupName -Status "Skipped" -Message "Already exists"
        }
        else {
            Write-Host "  Creating resource group..." -ForegroundColor Gray
            $rgJson = az group create `
                --name $ResourceGroupName `
                --location $Location `
                --tags "Environment=Production" "Project=Migration" `
                --only-show-errors 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Resource group created successfully" -ForegroundColor Green
                Add-Result -Resource "ResourceGroup" -Name $ResourceGroupName -Status "Created" -Message "Created in $Location"
            }
            else {
                throw "Failed to create resource group"
            }
        }
    }
    catch {
        Write-Host "  ❌ Failed to create resource group: $_" -ForegroundColor Red
        Add-Result -Resource "ResourceGroup" -Name $ResourceGroupName -Status "Failed" -Message $_.Exception.Message
    }
    Write-Host ""

    # Get subscription ID for RBAC
    $subscriptionId = az account show --query id -o tsv

    # ===== CREATE SERVICE PRINCIPAL =====
    if ($CreateServicePrincipal -and $ServicePrincipalName) {
        Write-Host "[Service Principal with Federated Credentials]" -ForegroundColor Yellow
        Write-Host "  Using workload identity federation (no secrets)" -ForegroundColor Cyan
        try {
            # Check if app already exists
            $appListJson = az ad app list --display-name $ServicePrincipalName --only-show-errors 2>&1
            if ($LASTEXITCODE -eq 0) {
                $appList = $appListJson | ConvertFrom-Json
                if ($appList -and $appList.Count -gt 0) {
                    Write-Host "  ✅ App registration already exists" -ForegroundColor Green
                    $appId = $appList[0].appId
                    $appObjectId = $appList[0].id
                    Write-Host "  Using existing AppId: $appId" -ForegroundColor Gray
                    Add-Result -Resource "ServicePrincipal" -Name $ServicePrincipalName -Status "Skipped" -Message "Using existing: $appId"
                }
                else {
                    # Step 1: Create Entra ID App Registration
                    Write-Host "  Creating Entra ID app registration..." -ForegroundColor Gray
                    $appJson = az ad app create `
                        --display-name $ServicePrincipalName `
                        --sign-in-audience "AzureADMyOrg" `
                        --only-show-errors 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $app = $appJson | ConvertFrom-Json
                        $appId = $app.appId
                        $appObjectId = $app.id
                        Write-Host "  ✅ App registration created: $appId" -ForegroundColor Green
                        
                        # Step 2: Create Service Principal from App
                        Write-Host "  Creating service principal from app..." -ForegroundColor Gray
                        $spJson = az ad sp create --id $appId --only-show-errors 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  ✅ Service principal created" -ForegroundColor Green
                            
                            # Step 3: Grant RBAC permissions
                            Write-Host "  Granting Contributor role..." -ForegroundColor Gray
                            $scope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName"
                            az role assignment create `
                                --assignee $appId `
                                --role "Contributor" `
                                --scope $scope `
                                --only-show-errors 2>&1 | Out-Null
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "  ✅ Contributor role assigned" -ForegroundColor Green
                            }
                            
                            # Step 4: Add federated credential for Azure DevOps
                            Write-Host "  Adding federated credential for Azure DevOps..." -ForegroundColor Gray
                            
                            # Get Azure DevOps organization info
                            $orgUrl = $config.azureDevOps.organizationUrl
                            $projectName = $config.azureDevOps.projectName
                            $orgName = ($orgUrl -split '/')[-1]
                            
                            # Create federated credential JSON
                            $fedCredJson = @{
                                name = "AzureDevOpsFederation"
                                issuer = "https://vstoken.dev.azure.com/$($config.azure.tenantId)"
                                subject = "sc://$orgName/$projectName/Azure-Production"
                                description = "Federated credential for Azure DevOps service connection"
                                audiences = @("api://AzureADTokenExchange")
                            } | ConvertTo-Json
                            
                            $fedCredFile = "$PSScriptRoot/fedcred-temp.json"
                            $fedCredJson | Out-File -FilePath $fedCredFile -Encoding UTF8
                            
                            az ad app federated-credential create `
                                --id $appObjectId `
                                --parameters $fedCredFile `
                                --only-show-errors 2>&1 | Out-Null
                            
                            Remove-Item $fedCredFile -ErrorAction SilentlyContinue
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "  ✅ Federated credential added (no secrets needed!)" -ForegroundColor Green
                            }
                            
                            # Save app info
                            $appInfo = @{
                                appId = $appId
                                objectId = $appObjectId
                                tenantId = $config.azure.tenantId
                                displayName = $ServicePrincipalName
                                federatedCredential = "Configured for Azure DevOps"
                            }
                            $appInfoFile = "$PSScriptRoot/sp-app-info-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                            $appInfo | ConvertTo-Json | Out-File -FilePath $appInfoFile -Encoding UTF8
                            Write-Host "  App info saved to: $appInfoFile" -ForegroundColor Gray
                            
                            # Update migration-config.json with Service Principal AppId
                            $configPath = "$PSScriptRoot/../migration-config.json"
                            if (Test-Path $configPath) {
                                try {
                                    $configContent = Get-Content $configPath | ConvertFrom-Json
                                    $configContent.servicePrincipal.appId = $appId
                                    $configContent.metadata.lastModified = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                                    $configContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
                                    Write-Host "  ✅ Configuration updated with SP AppId" -ForegroundColor Green
                                }
                                catch {
                                    Write-Host "  ⚠️  Failed to update config: $_" -ForegroundColor Yellow
                                }
                            }
                            
                            Add-Result -Resource "ServicePrincipal" -Name $ServicePrincipalName -Status "Created" -Message "AppId: $appId (Federated)"
                        }
                        else {
                            throw "Failed to create service principal from app"
                        }
                    }
                    else {
                        throw "Failed to create app registration"
                    }
                }
            }
            else {
                Write-Host "  ⚠️  Cannot list app registrations" -ForegroundColor Yellow
                Add-Result -Resource "ServicePrincipal" -Name $ServicePrincipalName -Status "Skipped" -Message "Cannot verify"
            }
        }
        catch {
            Write-Host "  ⚠️  Service Principal creation failed: $_" -ForegroundColor Yellow
            Write-Host "  Migration can proceed with your current authentication" -ForegroundColor Gray
            Add-Result -Resource "ServicePrincipal" -Name $ServicePrincipalName -Status "Skipped" -Message "Failed - not required for migration"
        }
        Write-Host ""
    }

    # ===== CREATE ML WORKSPACE =====
    if ($CreateMLWorkspace -and $MLWorkspaceName) {
        Write-Host "[ML Workspace]" -ForegroundColor Yellow
        try {
            # Check if ML extension is installed
            $extensionsJson = az extension list --only-show-errors 2>&1
            if ($LASTEXITCODE -eq 0) {
                $extensions = $extensionsJson | ConvertFrom-Json
                $mlExt = $extensions | Where-Object { $_.name -eq 'ml' }
                
                if (-not $mlExt) {
                    Write-Host "  Installing Azure ML extension..." -ForegroundColor Gray
                    az extension add --name ml --only-show-errors 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✅ ML extension installed" -ForegroundColor Green
                    }
                }
            }

            # Check if workspace exists using resource list (faster)
            $workspaceJson = az resource list `
                --resource-group $ResourceGroupName `
                --resource-type "Microsoft.MachineLearningServices/workspaces" `
                --name $MLWorkspaceName `
                --only-show-errors 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $workspace = $workspaceJson | ConvertFrom-Json
                if ($workspace -and $workspace.Count -gt 0) {
                    Write-Host "  ✅ ML Workspace already exists" -ForegroundColor Green
                    Add-Result -Resource "MLWorkspace" -Name $MLWorkspaceName -Status "Skipped" -Message "Already exists"
                }
                else {
                    # Create ML workspace
                    Write-Host "  Creating ML workspace (this may take 2-3 minutes)..." -ForegroundColor Gray
                    $wsJson = az ml workspace create `
                        --resource-group $ResourceGroupName `
                        --name $MLWorkspaceName `
                        --location $Location `
                        --description "ML workspace for repository migration" `
                        --public-network-access Enabled `
                        --only-show-errors 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✅ ML Workspace created successfully" -ForegroundColor Green
                        Add-Result -Resource "MLWorkspace" -Name $MLWorkspaceName -Status "Created" -Message "Created in $Location"
                    }
                    else {
                        throw "Failed to create ML workspace: $wsJson"
                    }
                }
            }
        }
        catch {
            # Check if it actually succeeded despite the experimental warning
            $checkJson = az resource list `
                --resource-group $ResourceGroupName `
                --resource-type "Microsoft.MachineLearningServices/workspaces" `
                --name $MLWorkspaceName `
                --only-show-errors 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $check = $checkJson | ConvertFrom-Json
                if ($check -and $check.Count -gt 0) {
                    Write-Host "  ✅ ML Workspace created successfully (experimental warning can be ignored)" -ForegroundColor Green
                    Add-Result -Resource "MLWorkspace" -Name $MLWorkspaceName -Status "Created" -Message "Created in $Location"
                }
                else {
                    Write-Host "  ⚠️  Failed to create ML Workspace: $_" -ForegroundColor Yellow
                    Write-Host "  This resource can be created manually if needed" -ForegroundColor Gray
                    Add-Result -Resource "MLWorkspace" -Name $MLWorkspaceName -Status "Failed" -Message $_.Exception.Message
                }
            }
            else {
                Write-Host "  ⚠️  Failed to create ML Workspace: $_" -ForegroundColor Yellow
                Write-Host "  This resource can be created manually if needed" -ForegroundColor Gray
                Add-Result -Resource "MLWorkspace" -Name $MLWorkspaceName -Status "Failed" -Message $_.Exception.Message
            }
        }
        Write-Host ""
    }

    # ===== CREATE OPENAI SERVICE =====
    if ($CreateOpenAI -and $OpenAIServiceName) {
        Write-Host "[OpenAI Service]" -ForegroundColor Yellow
        try {
            # Check if service exists
            $openaiJson = az resource list `
                --resource-group $ResourceGroupName `
                --resource-type "Microsoft.CognitiveServices/accounts" `
                --name $OpenAIServiceName `
                --only-show-errors 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $openai = $openaiJson | ConvertFrom-Json
                if ($openai -and $openai.Count -gt 0) {
                    Write-Host "  ✅ OpenAI Service already exists" -ForegroundColor Green
                    Add-Result -Resource "OpenAIService" -Name $OpenAIServiceName -Status "Skipped" -Message "Already exists"
                }
                else {
                    # Create OpenAI service
                    Write-Host "  Creating OpenAI service..." -ForegroundColor Gray
                    $openaiJson = az cognitiveservices account create `
                        --resource-group $ResourceGroupName `
                        --name $OpenAIServiceName `
                        --location $Location `
                        --kind "OpenAI" `
                        --sku "S0" `
                        --custom-domain $OpenAIServiceName `
                        --only-show-errors 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✅ OpenAI Service created successfully" -ForegroundColor Green
                        Add-Result -Resource "OpenAIService" -Name $OpenAIServiceName -Status "Created" -Message "Created in $Location"
                        
                        # Wait for service to be ready
                        Write-Host "  Waiting for service to be ready..." -ForegroundColor Gray
                        Start-Sleep -Seconds 10
                        
                        # Deploy GPT-4o model (current version)
                        Write-Host "  Deploying GPT-4o model..." -ForegroundColor Gray
                        az cognitiveservices account deployment create `
                            --resource-group $ResourceGroupName `
                            --name $OpenAIServiceName `
                            --deployment-name "gpt-4o" `
                            --model-name "gpt-4o" `
                            --model-version "2024-11-20" `
                            --model-format "OpenAI" `
                            --sku-capacity 10 `
                            --sku-name "Standard" `
                            --only-show-errors 2>&1 | Out-Null
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  ✅ GPT-4o model deployed" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  ⚠️  GPT-4o deployment failed, trying alternative..." -ForegroundColor Yellow
                        }
                        
                        # Deploy GPT-4o-mini model (cost-effective alternative)
                        Write-Host "  Deploying GPT-4o-mini model..." -ForegroundColor Gray
                        az cognitiveservices account deployment create `
                            --resource-group $ResourceGroupName `
                            --name $OpenAIServiceName `
                            --deployment-name "gpt-4o-mini" `
                            --model-name "gpt-4o-mini" `
                            --model-version "2024-07-18" `
                            --model-format "OpenAI" `
                            --sku-capacity 10 `
                            --sku-name "Standard" `
                            --only-show-errors 2>&1 | Out-Null
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  ✅ GPT-4o-mini model deployed" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  ⚠️  GPT-4o-mini deployment failed" -ForegroundColor Yellow
                        }
                    }
                    else {
                        throw "Failed to create OpenAI service: $openaiJson"
                    }
                }
            }
        }
        catch {
            Write-Host "  ⚠️  Failed to create OpenAI Service: $_" -ForegroundColor Yellow
            Write-Host "  This resource can be created manually if needed" -ForegroundColor Gray
            Add-Result -Resource "OpenAIService" -Name $OpenAIServiceName -Status "Failed" -Message $_.Exception.Message
        }
        Write-Host ""
    }

    # ===== SUMMARY =====
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Created: $($results.Summary.Created)" -ForegroundColor Green
    Write-Host "Skipped: $($results.Summary.Skipped)" -ForegroundColor Yellow
    Write-Host "Failed: $($results.Summary.Failed)" -ForegroundColor $(if ($results.Summary.Failed -gt 0) { "Red" } else { "Gray" })
    Write-Host ""

    if ($results.ResourcesCreated.Count -gt 0) {
        Write-Host "Resources Created:" -ForegroundColor Green
        $results.ResourcesCreated | ForEach-Object {
            Write-Host "  ✅ $($_.Resource): $($_.Name)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($results.ResourcesSkipped.Count -gt 0) {
        Write-Host "Resources Skipped:" -ForegroundColor Yellow
        $results.ResourcesSkipped | ForEach-Object {
            Write-Host "  ⏭️  $($_.Resource): $($_.Name)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($results.Errors.Count -gt 0) {
        Write-Host "Errors:" -ForegroundColor Red
        $results.Errors | ForEach-Object {
            Write-Host "  ❌ $($_.Resource): $($_.Message)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # Output in requested format
    if ($OutputFormat -eq 'json') {
        $results | ConvertTo-Json -Depth 10
    }

    # Exit with appropriate code
    if ($results.Summary.Failed -gt 0 -and $results.Summary.Created -eq 0) {
        Write-Host "❌ Resource creation failed" -ForegroundColor Red
        exit 1
    }
    elseif ($results.Summary.Created -gt 0) {
        Write-Host "✅ Resource creation completed successfully" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "✅ All resources already exist" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "Resource creation error: $_"
    exit 2
}
