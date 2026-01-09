#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates an Azure Service Principal with workload identity federation for multi-environment access.

.DESCRIPTION
    This specialized skill creates an Entra ID App Registration and Service Principal configured
    for workload identity federation (federated credentials). It grants appropriate RBAC permissions
    across multiple environment resource groups (dev, test, prod).
    
    IMPORTANT: Federated credentials are NOT created by this script. They must be created AFTER
    Azure DevOps service connections are set up, using the actual issuer/subject values from the
    service connection. See starter-execution/LESSONS_LEARNED.md #1.

.PARAMETER ServicePrincipalName
    Name for the Service Principal and App Registration

.PARAMETER ResourceGroupBaseName
    Base name for resource groups to grant access to (will be appended with -dev, -test, -prod)

.PARAMETER Environment
    Which environment(s) to grant access to: 'dev', 'test', 'prod', or 'all' (default: all)

.PARAMETER UseConfig
    Load configuration from starter-config.json file

.PARAMETER UpdateConfig
    Update starter-config.json with Service Principal details (default: true)

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./create-service-principal.ps1 -ServicePrincipalName "sp-aif-demo" -ResourceGroupBaseName "rg-aif-demo"

.EXAMPLE
    ./create-service-principal.ps1 -UseConfig

.OUTPUTS
    PSCustomObject with Service Principal details (AppId, ObjectId, TenantId, etc.)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalName,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupBaseName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'test', 'prod', 'all')]
    [string]$Environment = 'all',

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
    . "$PSScriptRoot/../../configuration-management/config-functions.ps1"
    $config = Get-StarterConfig
    
    if ($config) {
        $ResourceGroupBaseName = "rg-$($config.naming.projectName)"
        $ServicePrincipalName = "sp-$ResourceGroupBaseName"
        Write-Host "[OK] Loaded configuration from starter-config.json" -ForegroundColor Green
    }
    else {
        Write-Error "Could not load configuration. Run: ../configuration-management/configure-starter.ps1 -Interactive"
        exit 1
    }
}

# Validate required parameters
if (-not $ServicePrincipalName) {
    Write-Error "ServicePrincipalName is required. Use -UseConfig or specify -ServicePrincipalName"
    exit 1
}

if (-not $ResourceGroupBaseName) {
    Write-Error "ResourceGroupBaseName is required. Use -UseConfig or specify -ResourceGroupBaseName"
    exit 1
}

# Determine which environments to grant access to
$environments = @()
if ($Environment -eq 'all') {
    $environments = @('dev', 'test', 'prod')
} else {
    $environments = @($Environment)
}

# Get subscription and tenant information
$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv

# Results tracking
$result = @{
    Timestamp           = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ServicePrincipal    = @{
        Name            = $ServicePrincipalName
        AppId           = $null
        ObjectId        = $null
        TenantId        = $tenantId
        Status          = $null
        Message         = $null
    }
    RoleAssignments     = @()
    Summary             = @{
        Created         = 0
        Skipped         = 0
        Failed          = 0
    }
}

Write-Host "=== Azure Service Principal Creation ===" -ForegroundColor Cyan
Write-Host "Service Principal: $ServicePrincipalName" -ForegroundColor Gray
Write-Host "Resource Group Base: $ResourceGroupBaseName" -ForegroundColor Gray
Write-Host "Environments: $($environments -join ', ')" -ForegroundColor Gray
Write-Host "Using Workload Identity Federation (no secrets)" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "[Service Principal with RBAC for All Environments]" -ForegroundColor Yellow
    
    # Check if app already exists
    $appListJson = az ad app list --display-name $ServicePrincipalName --only-show-errors 2>&1
    if ($LASTEXITCODE -eq 0) {
        $appList = $appListJson | ConvertFrom-Json
        if ($appList -and $appList.Count -gt 0) {
            Write-Host "  [OK] App registration already exists" -ForegroundColor Green
            $appId = $appList[0].appId
            $appObjectId = $appList[0].id
            Write-Host "  Using existing AppId: $appId" -ForegroundColor Gray
            
            $result.ServicePrincipal.AppId = $appId
            $result.ServicePrincipal.ObjectId = $appObjectId
            $result.ServicePrincipal.Status = "Skipped"
            $result.ServicePrincipal.Message = "Using existing"
            $result.Summary.Skipped++
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
                Write-Host "  [OK] App registration created: $appId" -ForegroundColor Green
                
                $result.ServicePrincipal.AppId = $appId
                $result.ServicePrincipal.ObjectId = $appObjectId
                $result.Summary.Created++
                
                # Step 2: Create Service Principal from App
                Write-Host "  Creating service principal from app..." -ForegroundColor Gray
                $spJson = az ad sp create --id $appId --only-show-errors 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [OK] Service principal created" -ForegroundColor Green
                    $result.ServicePrincipal.Status = "Created"
                    $result.ServicePrincipal.Message = "Successfully created"
                }
                else {
                    throw "Failed to create service principal from app: $spJson"
                }
            }
            else {
                throw "Failed to create app registration: $appJson"
            }
        }
        
        # Step 3: Grant RBAC permissions to ALL environment resource groups
        Write-Host "  Granting permissions to all environments..." -ForegroundColor Gray
        Write-Host ""
        
        foreach ($env in $environments) {
            $rgName = "$ResourceGroupBaseName-$env"
            $scope = "/subscriptions/$subscriptionId/resourceGroups/$rgName"
            
            $roleResult = @{
                Environment     = $env
                ResourceGroup   = $rgName
                Roles           = @()
            }
            
            Write-Host "    Environment: $env" -ForegroundColor Cyan
            
            # Contributor role on resource group (for resource management)
            Write-Host "      Assigning Contributor role on RG..." -ForegroundColor Gray
            az role assignment create `
                --assignee $appId `
                --role "Contributor" `
                --scope $scope `
                --only-show-errors 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      [OK] Contributor role assigned" -ForegroundColor Green
                $roleResult.Roles += @{
                    Role    = "Contributor"
                    Scope   = $scope
                    Status  = "Assigned"
                }
            }
            else {
                Write-Host "      [WARN] Contributor role assignment failed (may already exist)" -ForegroundColor Yellow
                $roleResult.Roles += @{
                    Role    = "Contributor"
                    Scope   = $scope
                    Status  = "Failed"
                }
            }
            
            $result.RoleAssignments += $roleResult
            
            # Note: Cognitive Services User role will be assigned after
            # AI Services resource is created (see create-ai-foundry-resources.ps1)
            Write-Host "      [INFO] Cognitive Services User role will be assigned after AI Services creation" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "  [WARN] IMPORTANT: Federated Credentials" -ForegroundColor Yellow
        Write-Host "  Federated credentials MUST be created AFTER service connections" -ForegroundColor Gray
        Write-Host "  are set up in Azure DevOps. You need the actual issuer and" -ForegroundColor Gray
        Write-Host "  subject values from the service connection." -ForegroundColor Gray
        Write-Host "  See: .github/skills/starter-execution/LESSONS_LEARNED.md #1" -ForegroundColor Cyan
        Write-Host ""
        
        # Save app info
        $appInfo = @{
            appId               = $appId
            objectId            = $appObjectId
            tenantId            = $tenantId
            displayName         = $ServicePrincipalName
            subscriptionId      = $subscriptionId
            environments        = $environments
            resourceGroups      = $environments | ForEach-Object { "$ResourceGroupBaseName-$_" }
            federatedCredential = "To be created after service connection (see LESSONS_LEARNED.md #1)"
            createdAt           = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        Write-Host "  Service Principal Details:" -ForegroundColor Gray
        Write-Host "    AppId: $appId" -ForegroundColor Gray
        Write-Host "    ObjectId: $appObjectId" -ForegroundColor Gray
        Write-Host "    TenantId: $tenantId" -ForegroundColor Gray
        Write-Host ""
        
        # Update starter-config.json with Service Principal AppId
        if ($UseConfig) {
            try {
                . "$PSScriptRoot/../../configuration-management/config-functions.ps1"
                $currentConfig = Get-StarterConfig
                
                # Add servicePrincipal section if it doesn't exist
                if (-not $currentConfig.servicePrincipal) {
                    $currentConfig | Add-Member -MemberType NoteProperty -Name "servicePrincipal" -Value @{} -Force
                }
                
                $currentConfig.servicePrincipal = @{
                    appId = $appId
                    tenantId = $tenantId
                    displayName = $ServicePrincipalName
                    createdAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                }
                
                Set-StarterConfig -Config $currentConfig
                Write-Host "  [OK] Configuration updated with SP AppId" -ForegroundColor Green
            }
            catch {
                Write-Host "  [WARN] Failed to update config: $_" -ForegroundColor Yellow
            }
        }
        
        # Output results
    }
    else {
        throw "Cannot list app registrations. Check permissions."
    }
    
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Status: $($result.ServicePrincipal.Status)" -ForegroundColor $(if ($result.ServicePrincipal.Status -eq "Created") { "Green" } else { "Yellow" })
    Write-Host "AppId: $($result.ServicePrincipal.AppId)" -ForegroundColor Gray
    Write-Host "Environments: $($environments.Count) configured" -ForegroundColor Gray
    Write-Host ""
    
    # Output in requested format
    if ($OutputFormat -eq 'json') {
        $result | ConvertTo-Json -Depth 10
    }
    
    # Return app info for use by calling scripts
    return $result
}
catch {
    Write-Host "  [ERROR] Service Principal creation failed: $_" -ForegroundColor Red
    Write-Host "  Migration can proceed with your current authentication" -ForegroundColor Gray
    $result.ServicePrincipal.Status = "Failed"
    $result.ServicePrincipal.Message = $_.Exception.Message
    $result.Summary.Failed++
    
    if ($OutputFormat -eq 'json') {
        $result | ConvertTo-Json -Depth 10
    }
    
    exit 1
}
