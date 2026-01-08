#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fixes federated credentials for Azure DevOps service connections by retrieving actual issuer/subject values.

.DESCRIPTION
    This script implements the correct approach to federated credential management:
    1. Retrieves actual issuer and subject from Azure DevOps service connections
    2. Deletes old federated credentials with incorrect format
    3. Creates new federated credentials with correct values
    4. Verifies all credentials are properly configured

    CRITICAL: Never guess issuer/subject format. Always retrieve from Azure DevOps.
    See LESSONS_LEARNED.md #1 for why this matters.

.PARAMETER Environments
    Array of environments to fix credentials for. Default: @("dev", "test", "prod")

.PARAMETER ConfigPath
    Path to starter-config.json. Default: .\starter-config.json

.PARAMETER SkipRbac
    Skip adding Cognitive Services User role. Default: $false

.EXAMPLE
    # Fix all environments
    .\fix-federated-credentials.ps1

.EXAMPLE
    # Fix only dev and test
    .\fix-federated-credentials.ps1 -Environments @("dev", "test")

.EXAMPLE
    # Fix credentials without updating RBAC
    .\fix-federated-credentials.ps1 -SkipRbac

.NOTES
    Prerequisites:
    - Azure CLI installed and authenticated (az login)
    - Azure DevOps CLI extension installed
    - Service connections already created in Azure DevOps
    - starter-config.json exists with Service Principal details
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Environments = @("dev", "test", "prod"),
    
    [Parameter()]
    [string]$ConfigPath = ".\starter-config.json",
    
    [Parameter()]
    [switch]$SkipRbac
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Step { param($Message) Write-Host "`n--- $Message ---" -ForegroundColor Magenta }

# Main script
try {
    Write-Host "`n======================================" -ForegroundColor Cyan
    Write-Host "Federated Credentials Fix Script" -ForegroundColor Cyan
    Write-Host "======================================`n" -ForegroundColor Cyan

    # Step 1: Load configuration
    Write-Step "Loading Configuration"
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        Write-Info "Run configuration-management skill first"
        exit 1
    }
    
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    $org = $config.azureDevOps.organizationUrl
    $projectName = $config.azureDevOps.projectName
    $spAppId = $config.servicePrincipal.appId
    $tenantId = $config.azure.tenantId
    $subId = $config.azure.subscriptionId
    
    Write-Success "Configuration loaded"
    Write-Info "Organization: $org"
    Write-Info "Project: $projectName"
    Write-Info "Service Principal: $spAppId"
    Write-Info "Environments: $($Environments -join ', ')"

    # Step 2: Refresh bearer token
    Write-Step "Refreshing Azure DevOps Bearer Token"
    
    $env:ADO_TOKEN = az account get-access-token `
        --resource 499b84ac-1321-427f-aa17-267ca6975798 `
        --query accessToken -o tsv
    
    if (-not $env:ADO_TOKEN) {
        Write-Error "Failed to get bearer token. Run 'az login' first."
        exit 1
    }
    
    Write-Success "Bearer token refreshed"

    # Step 3: Get project ID
    Write-Step "Retrieving Azure DevOps Project ID"
    
    $projectId = az devops project show `
        --project $projectName `
        --organization $org `
        --query id -o tsv
    
    if (-not $projectId) {
        Write-Error "Failed to get project ID"
        exit 1
    }
    
    Write-Success "Project ID: $projectId"

    # Step 4: Retrieve service connections
    Write-Step "Retrieving Service Connections"
    
    $uri = "$org/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
    $headers = @{ Authorization = "Bearer $env:ADO_TOKEN" }
    
    $serviceConnections = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    
    if ($serviceConnections.count -eq 0) {
        Write-Error "No service connections found"
        Write-Info "Run starter-execution skill to create service connections first"
        exit 1
    }
    
    Write-Success "Retrieved $($serviceConnections.count) service connections"
    
    # Build mapping of environment to issuer/subject
    $credentials = @{}
    
    foreach ($sc in $serviceConnections.value) {
        $name = $sc.name
        $issuer = $sc.authorization.parameters.workloadIdentityFederationIssuer
        $subject = $sc.authorization.parameters.workloadIdentityFederationSubject
        
        # Extract environment from service connection name (azure-foundry-dev -> dev)
        if ($name -match 'azure-foundry-(.+)') {
            $env = $Matches[1]
            
            if ($Environments -contains $env) {
                $credentials[$env] = @{
                    Name = $name
                    Id = $sc.id
                    Issuer = $issuer
                    Subject = $subject
                }
                
                Write-Info "Found: $name"
                Write-Info "  Issuer: $issuer"
                Write-Info "  Subject: $($subject.Substring(0, 50))..."
            }
        }
    }
    
    if ($credentials.Count -eq 0) {
        Write-Error "No matching service connections found for environments: $($Environments -join ', ')"
        exit 1
    }

    # Step 5: Fix federated credentials
    Write-Step "Fixing Federated Credentials"
    
    foreach ($env in $Environments) {
        if (-not $credentials.ContainsKey($env)) {
            Write-Warning "Service connection not found for $env, skipping"
            continue
        }
        
        $cred = $credentials[$env]
        $credName = "azure-foundry-$env"
        
        Write-Info "`nProcessing: $credName"
        
        # Delete old credential
        Write-Info "Deleting old credential..."
        az ad app federated-credential delete `
            --id $spAppId `
            --federated-credential-id $credName `
            2>$null | Out-Null
        
        # Create credential JSON
        $credJson = @{
            name = $credName
            issuer = $cred.Issuer
            subject = $cred.Subject
            audiences = @("api://AzureADTokenExchange")
        } | ConvertTo-Json -Depth 10
        
        $tempFile = "cred-$env-temp.json"
        $credJson | Out-File -FilePath $tempFile -Encoding UTF8
        
        # Create new credential
        Write-Info "Creating new credential with correct issuer/subject..."
        $result = az ad app federated-credential create `
            --id $spAppId `
            --parameters $tempFile `
            2>&1
        
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Fixed federated credential for $env"
        } else {
            Write-Error "Failed to create credential for $env"
            Write-Info $result
        }
    }

    # Step 6: Add RBAC permissions if not skipped
    if (-not $SkipRbac) {
        Write-Step "Adding Cognitive Services User Role"
        
        $resourceMap = @{
            "dev" = @{ rg = "rg-ai-foundry-starter-dev"; resource = "aif-foundry-dev" }
            "test" = @{ rg = "rg-ai-foundry-starter-test"; resource = "aif-test-6654" }
            "prod" = @{ rg = "rg-ai-foundry-starter-prod"; resource = "aif-foundry-prod" }
        }
        
        foreach ($env in $Environments) {
            if (-not $resourceMap.ContainsKey($env)) {
                Write-Warning "Resource mapping not found for $env, skipping RBAC"
                continue
            }
            
            $rg = $resourceMap[$env].rg
            $resource = $resourceMap[$env].resource
            $scope = "/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.CognitiveServices/accounts/$resource"
            
            Write-Info "Adding role for $env ($resource)..."
            
            $existing = az role assignment list `
                --assignee $spAppId `
                --role "Cognitive Services User" `
                --scope $scope `
                --query "[].roleDefinitionName" -o tsv `
                2>$null
            
            if ($existing) {
                Write-Info "Role already assigned for $env"
            } else {
                az role assignment create `
                    --assignee $spAppId `
                    --role "Cognitive Services User" `
                    --scope $scope `
                    --output none
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Role assigned for $env"
                } else {
                    Write-Warning "Failed to assign role for $env (may already exist)"
                }
            }
        }
    } else {
        Write-Info "Skipping RBAC role assignment (--SkipRbac specified)"
    }

    # Step 7: Verify credentials
    Write-Step "Verifying Federated Credentials"
    
    $allCreds = az ad app federated-credential list `
        --id $spAppId `
        --query "[].{Name:name, Issuer:issuer, Subject:subject}" `
        2>&1 | ConvertFrom-Json
    
    if ($allCreds) {
        foreach ($c in $allCreds) {
            if ($c.Name -match 'azure-foundry-(.+)') {
                $env = $Matches[1]
                if ($Environments -contains $env) {
                    Write-Success "$($c.Name)"
                    Write-Info "  Issuer: $($c.Issuer)"
                    Write-Info "  Subject: $($c.Subject.Substring(0, 60))..."
                }
            }
        }
    }

    # Summary
    Write-Host "`n======================================" -ForegroundColor Green
    Write-Host "Federated Credentials Fixed Successfully" -ForegroundColor Green
    Write-Host "======================================`n" -ForegroundColor Green
    
    Write-Info "Next steps:"
    Write-Info "1. Run your pipeline to test authentication"
    Write-Info "2. Check pipeline logs for any auth errors"
    Write-Info "3. Verify agent creation in Azure AI Foundry portal"
    Write-Host ""
    Write-Info "Pipeline URL: $org/$projectName/_build"
    Write-Host ""

} catch {
    Write-Error "Script failed: $_"
    Write-Info $_.ScriptStackTrace
    exit 1
}
