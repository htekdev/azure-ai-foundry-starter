#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates and configures Azure resources required for Azure AI Foundry starter deployment.

.DESCRIPTION
    This script automates the creation of Azure resources including Service Principals,
    AI Foundry projects, and supporting infrastructure. It checks for resource
    existence before creating and ensures proper RBAC configuration.
    
    NOTE: Federated credentials are NOT created here. They must be created AFTER
    Azure DevOps service connections are set up, using the actual issuer/subject
    values from the service connection. See starter-execution/LESSONS_LEARNED.md #1.

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
    [string]$ResourceGroupBaseName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalName,

    [Parameter(Mandatory = $false)]
    [string]$AIProjectBaseName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'test', 'prod', 'all')]
    [string]$Environment = 'all',

    [Parameter(Mandatory = $false)]
    [bool]$CreateServicePrincipal = $false,

    [Parameter(Mandatory = $false)]
    [bool]$CreateAIProjects = $false,

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
    $config = Get-StarterConfig
    
    if ($config) {
        $ResourceGroupBaseName = $config.azure.resourceGroup
        $Location = $config.azure.location
        $ServicePrincipalName = "sp-$ResourceGroupBaseName"
        $AIProjectBaseName = $ResourceGroupBaseName
        
        Write-Host "✅ Loaded configuration from starter-config.json" -ForegroundColor Green
    }
    else {
        Write-Error "Could not load configuration. Run: ../configuration-management/configure-starter.ps1 -Interactive"
        exit 1
    }
}

# Set flags if CreateAll is specified
if ($CreateAll) {
    $CreateServicePrincipal = $true
    $CreateAIProjects = $true
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

Write-Host "=== Azure AI Foundry Multi-Environment Resource Creation ===" -ForegroundColor Cyan
Write-Host "Base Name: $ResourceGroupBaseName" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host "Environments: $($environments -join ', ')" -ForegroundColor Gray
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
    # ===== CREATE RESOURCE GROUPS =====
    Write-Host "[Resource Groups]" -ForegroundColor Yellow
    foreach ($env in $environments) {
        $rgName = "$ResourceGroupBaseName-$env"
        Write-Host "  Environment: $env" -ForegroundColor Cyan
        try {
            $rgExistsResult = az group exists --name $rgName
            if ($rgExistsResult -eq "true") {
                Write-Host "    ✅ Resource group already exists: $rgName" -ForegroundColor Green
                Add-Result -Resource "ResourceGroup" -Name $rgName -Status "Skipped" -Message "Already exists"
            }
            else {
                Write-Host "    Creating resource group: $rgName..." -ForegroundColor Gray
                $rgJson = az group create `
                    --name $rgName `
                    --location $Location `
                    --tags "Environment=$env" "Project=AIFoundry" "ManagedBy=Starter" `
                    --only-show-errors 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✅ Resource group created successfully" -ForegroundColor Green
                    Add-Result -Resource "ResourceGroup" -Name $rgName -Status "Created" -Message "Created in $Location"
                }
                else {
                    throw "Failed to create resource group"
                }
            }
        }
        catch {
            Write-Host "    ❌ Failed to create resource group: $_" -ForegroundColor Red
            Add-Result -Resource "ResourceGroup" -Name $rgName -Status "Failed" -Message $_.Exception.Message
        }
    }
    Write-Host ""

    # Get subscription ID and tenant ID for RBAC
    $subscriptionId = az account show --query id -o tsv
    $tenantId = az account show --query tenantId -o tsv

    # ===== CREATE SERVICE PRINCIPAL =====
    if ($CreateServicePrincipal -and $ServicePrincipalName) {
        Write-Host "[Service Principal with RBAC for All Environments]" -ForegroundColor Yellow
        Write-Host "  Using workload identity federation (no secrets)" -ForegroundColor Cyan
        Write-Host "  Will grant access to all environment resource groups" -ForegroundColor Gray
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
                            
                            # Step 3: Grant RBAC permissions to ALL environment resource groups
                            # Per LESSONS_LEARNED #11: Cognitive Services User must be granted on
                            # AI Services resources specifically, not just resource groups
                            Write-Host "  Granting permissions to all environments..." -ForegroundColor Gray
                            
                            foreach ($env in $environments) {
                                $rgName = "$ResourceGroupBaseName-$env"
                                $scope = "/subscriptions/$subscriptionId/resourceGroups/$rgName"
                                
                                Write-Host "    Environment: $env" -ForegroundColor Cyan
                                
                                # Contributor role on resource group (for resource management)
                                Write-Host "      Assigning Contributor role on RG..." -ForegroundColor Gray
                                az role assignment create `
                                    --assignee $appId `
                                    --role "Contributor" `
                                    --scope $scope `
                                    --only-show-errors 2>&1 | Out-Null
                                
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Host "      ✅ Contributor role assigned" -ForegroundColor Green
                                }
                                
                                # Note: Cognitive Services User role will be assigned after
                                # AI Services resource is created (see AI Project creation section)
                            }
                            
                            Write-Host "" -ForegroundColor Yellow
                            Write-Host "  ⚠️  IMPORTANT: Federated Credentials" -ForegroundColor Yellow
                            Write-Host "  Federated credentials MUST be created AFTER service connections" -ForegroundColor Gray
                            Write-Host "  are set up in Azure DevOps. You need the actual issuer and" -ForegroundColor Gray
                            Write-Host "  subject values from the service connection." -ForegroundColor Gray
                            Write-Host "  See: .github/skills/starter-execution/LESSONS_LEARNED.md #1" -ForegroundColor Cyan
                            Write-Host "" -ForegroundColor Yellow
                            
                            # Save app info
                            $appInfo = @{
                                appId = $appId
                                objectId = $appObjectId
                                tenantId = $tenantId
                                displayName = $ServicePrincipalName
                                environments = $environments
                                federatedCredential = "To be created after service connection (see LESSONS_LEARNED.md #1)"
                            }
                            $appInfoFile = "$PSScriptRoot/sp-app-info-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                            $appInfo | ConvertTo-Json | Out-File -FilePath $appInfoFile -Encoding UTF8
                            Write-Host "  App info saved to: $appInfoFile" -ForegroundColor Gray
                            
                            # Update starter-config.json with Service Principal AppId
                            $configPath = "$PSScriptRoot/../starter-config.json"
                            if (Test-Path $configPath) {
                                try {
                                    $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
                                    $configContent.servicePrincipal.appId = $appId
                                    $configContent.servicePrincipal.tenantId = $tenantId
                                    $configContent.azure.subscriptionId = $subscriptionId
                                    $configContent.metadata.lastModified = (Get-Date -Format "yyyy-MM-dd")
                                    $configContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
                                    Write-Host "  ✅ Configuration updated with SP AppId" -ForegroundColor Green
                                }
                                catch {
                                    Write-Host "  ⚠️  Failed to update config: $_" -ForegroundColor Yellow
                                }
                            }
                            
                            Add-Result -Resource "ServicePrincipal" -Name $ServicePrincipalName -Status "Created" -Message "AppId: $appId (Federated creds: create after service connection)"
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

    # ===== CREATE AI FOUNDRY PROJECTS =====
    if ($CreateAIProjects -and $AIProjectBaseName) {
        Write-Host "[AI Foundry Projects]" -ForegroundColor Yellow
        Write-Host "  Creating AI Foundry Hub and Projects for each environment" -ForegroundColor Cyan
        
        foreach ($env in $environments) {
            $rgName = "$ResourceGroupBaseName-$env"
            $hubName = "$AIProjectBaseName-hub-$env"
            $projectName = "$AIProjectBaseName-project-$env"
            $storageAccountName = ($AIProjectBaseName + "st" + $env).ToLower() -replace '[^a-z0-9]', ''
            if ($storageAccountName.Length -gt 24) { $storageAccountName = $storageAccountName.Substring(0, 24) }
            
            Write-Host "  Environment: $env" -ForegroundColor Cyan
            Write-Host "    Hub: $hubName" -ForegroundColor Gray
            Write-Host "    Project: $projectName" -ForegroundColor Gray
            try {
                # Check if AI ML extension is installed
                $extensionsJson = az extension list --only-show-errors 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $extensions = $extensionsJson | ConvertFrom-Json
                    $mlExt = $extensions | Where-Object { $_.name -eq 'ml' }
                    
                    if (-not $mlExt) {
                        Write-Host "    Installing Azure ML extension..." -ForegroundColor Gray
                        az extension add --name ml --only-show-errors 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "    ✅ ML extension installed" -ForegroundColor Green
                        }
                    }
                }

                # Create Storage Account for AI Hub
                Write-Host "    Creating storage account: $storageAccountName..." -ForegroundColor Gray
                $storageJson = az storage account create `
                    --name $storageAccountName `
                    --resource-group $rgName `
                    --location $Location `
                    --sku Standard_LRS `
                    --kind StorageV2 `
                    --only-show-errors 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✅ Storage account created" -ForegroundColor Green
                }

                # Check if hub exists
                $hubJson = az ml workspace list `
                    --resource-group $rgName `
                    --query "[?name=='$hubName']" `
                    --only-show-errors 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $hub = $hubJson | ConvertFrom-Json
                    if ($hub -and $hub.Count -gt 0) {
                        Write-Host "    ✅ AI Hub already exists" -ForegroundColor Green
                        Add-Result -Resource "AIHub" -Name $hubName -Status "Skipped" -Message "Already exists"
                    }
                    else {
                        # Create AI Foundry Hub
                        Write-Host "    Creating AI Hub (this may take 2-3 minutes)..." -ForegroundColor Gray
                        $hubJson = az ml workspace create `
                            --resource-group $rgName `
                            --name $hubName `
                            --location $Location `
                            --kind Hub `
                            --description "AI Foundry Hub for $env environment" `
                            --storage-account "/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.Storage/storageAccounts/$storageAccountName" `
                            --public-network-access Enabled `
                            --only-show-errors 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "    ✅ AI Hub created successfully" -ForegroundColor Green
                            Add-Result -Resource "AIHub" -Name $hubName -Status "Created" -Message "Created in $Location"
                            
                            # AI Hub creation automatically creates an AI Services resource
                            # Find and grant Cognitive Services User role (per LESSONS_LEARNED #11)
                            Write-Host "    Finding associated AI Services resource..." -ForegroundColor Gray
                            Start-Sleep -Seconds 5  # Give Azure time to create associated resources
                            
                            $aiServicesJson = az cognitiveservices account list `
                                --resource-group $rgName `
                                --query "[?kind=='AIServices']" `
                                -o json `
                                --only-show-errors 2>&1
                            
                            if ($LASTEXITCODE -eq 0 -and $aiServicesJson) {
                                $aiServices = $aiServicesJson | ConvertFrom-Json
                                if ($aiServices -and $aiServices.Count -gt 0) {
                                    $aiServiceName = $aiServices[0].name
                                    $aiServiceId = $aiServices[0].id
                                    Write-Host "    Found AI Services: $aiServiceName" -ForegroundColor Gray
                                    
                                    # Grant Cognitive Services User role on AI Services resource
                                    Write-Host "    Assigning Cognitive Services User role on AI Services..." -ForegroundColor Gray
                                    
                                    # Get Service Principal object ID if not already retrieved
                                    if (-not $config) {
                                        $spListJson = az ad sp list --display-name $ServicePrincipalName --only-show-errors 2>&1
                                        if ($LASTEXITCODE -eq 0) {
                                            $spList = $spListJson | ConvertFrom-Json
                                            if ($spList -and $spList.Count -gt 0) {
                                                $spAppId = $spList[0].appId
                                            }
                                        }
                                    } else {
                                        $spAppId = $config.servicePrincipal.appId
                                        if (-not $spAppId -or $spAppId -eq '00000000-0000-0000-0000-000000000000') {
                                            # Get from recently created SP
                                            $spListJson = az ad sp list --display-name $ServicePrincipalName --only-show-errors 2>&1
                                            if ($LASTEXITCODE -eq 0) {
                                                $spList = $spListJson | ConvertFrom-Json
                                                if ($spList -and $spList.Count -gt 0) {
                                                    $spAppId = $spList[0].appId
                                                }
                                            }
                                        }
                                    }
                                    
                                    if ($spAppId) {
                                        az role assignment create `
                                            --assignee $spAppId `
                                            --role "Cognitive Services User" `
                                            --scope $aiServiceId `
                                            --only-show-errors 2>&1 | Out-Null
                                        
                                        if ($LASTEXITCODE -eq 0) {
                                            Write-Host "    ✅ Cognitive Services User role assigned to AI Services" -ForegroundColor Green
                                        } else {
                                            Write-Host "    ⚠️  Failed to assign Cognitive Services User role" -ForegroundColor Yellow
                                            Write-Host "    You may need to assign this manually for agent operations" -ForegroundColor Gray
                                        }
                                    }
                                } else {
                                    Write-Host "    ⚠️  AI Services resource not found yet (may be creating)" -ForegroundColor Yellow
                                }
                            }
                        }
                        else {
                            throw "Failed to create AI Hub: $hubJson"
                        }
                    }
                }

                # Create AI Foundry Project
                Write-Host "    Creating AI Project..." -ForegroundColor Gray
                $projectJson = az ml workspace create `
                    --resource-group $rgName `
                    --name $projectName `
                    --location $Location `
                    --kind Project `
                    --hub-id "/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.MachineLearningServices/workspaces/$hubName" `
                    --description "AI Foundry Project for $env environment" `
                    --public-network-access Enabled `
                    --only-show-errors 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ✅ AI Project created successfully" -ForegroundColor Green
                    Add-Result -Resource "AIProject" -Name $projectName -Status "Created" -Message "Created in $Location"
                    
                    # Get AI Foundry project endpoint (correct format per LESSONS_LEARNED #9)
                    # Format: https://<ai-service-resource>.services.ai.azure.com/api/projects/<project-name>
                    # This comes from the AI Services resource associated with the Hub
                    
                    Write-Host "    Retrieving AI Foundry project endpoint..." -ForegroundColor Gray
                    
                    # Get AI Services resource associated with the Hub
                    $aiServicesJson = az cognitiveservices account list `
                        --resource-group $rgName `
                        --query "[?kind=='AIServices']" `
                        -o json `
                        --only-show-errors 2>&1
                    
                    $projectEndpoint = $null
                    
                    if ($LASTEXITCODE -eq 0 -and $aiServicesJson) {
                        try {
                            $aiServices = $aiServicesJson | ConvertFrom-Json
                            if ($aiServices -and $aiServices.Count -gt 0) {
                                $aiServiceName = $aiServices[0].name
                                $aiServiceProperties = $aiServices[0].properties
                                
                                # Construct AI Foundry project endpoint
                                # Format: https://<ai-service>.services.ai.azure.com/api/projects/<project>
                                if ($aiServiceProperties.endpoint) {
                                    # Extract base endpoint and append project path
                                    $baseEndpoint = $aiServiceProperties.endpoint.TrimEnd('/')
                                    $projectEndpoint = "$baseEndpoint/api/projects/$projectName"
                                } else {
                                    # Construct from service name
                                    $projectEndpoint = "https://$aiServiceName.services.ai.azure.com/api/projects/$projectName"
                                }
                                
                                Write-Host "    AI Foundry Project Endpoint: $projectEndpoint" -ForegroundColor Gray
                        
                                # Update starter-config.json with correct AI Foundry project endpoint
                                $configPath = "$PSScriptRoot/../starter-config.json"
                                if (Test-Path $configPath) {
                                    try {
                                        $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
                                        $configContent.azure.aiFoundry.$env.projectEndpoint = $projectEndpoint
                                        $configContent.metadata.lastModified = (Get-Date -Format "yyyy-MM-dd")
                                        $configContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
                                        Write-Host "    ✅ Configuration updated with AI Foundry project endpoint" -ForegroundColor Green
                                    }
                                    catch {
                                        Write-Host "    ⚠️  Failed to update config: $_" -ForegroundColor Yellow
                                    }
                                }
                            } else {
                                Write-Host "    ⚠️  No AI Services found in resource group" -ForegroundColor Yellow
                                Write-Host "    AI Hub should create AI Services automatically" -ForegroundColor Gray
                            }
                        }
                        catch {
                            Write-Host "    ⚠️  Failed to parse AI Services details: $_" -ForegroundColor Yellow
                        }
                    }
                    
                    if (-not $projectEndpoint) {
                        Write-Host "    ⚠️  Could not auto-detect AI Foundry project endpoint" -ForegroundColor Yellow
                        Write-Host "    You'll need to update starter-config.json manually:" -ForegroundColor Gray
                        Write-Host "    1. Go to https://ai.azure.com" -ForegroundColor Cyan
                        Write-Host "    2. Select project: $projectName" -ForegroundColor Cyan
                        Write-Host "    3. Copy 'Project endpoint' from Overview" -ForegroundColor Cyan
                        Write-Host "    4. Format: https://<resource>.services.ai.azure.com/api/projects/$projectName" -ForegroundColor Cyan
                        Write-Host "    See: .github/skills/starter-execution/LESSONS_LEARNED.md #9" -ForegroundColor Gray
                    }
                }
                else {
                    throw "Failed to create AI Project: $projectJson"
                }
            }
            catch {
                Write-Host "    ⚠️  Failed to create AI resources for $env: $_" -ForegroundColor Yellow
                Write-Host "    These resources can be created manually if needed" -ForegroundColor Gray
                Add-Result -Resource "AIProject" -Name $projectName -Status "Failed" -Message $_.Exception.Message
            }
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
