#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analyzes Azure DevOps pipeline failure
.DESCRIPTION
    Retrieves failure details and provides troubleshooting guidance
.PARAMETER RunId
    Pipeline run ID to analyze
.PARAMETER Project
    Azure DevOps project name (optional, reads from config)
.PARAMETER Organization
    Azure DevOps organization URL (optional, reads from config)
.EXAMPLE
    .\analyze-failure.ps1 -RunId 123
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$RunId,
    
    [Parameter(Mandatory = $false)]
    [string]$Project,
    
    [Parameter(Mandatory = $false)]
    [string]$Organization
)

$ErrorActionPreference = "Stop"

# Load configuration if not provided
if (-not $Project -or -not $Organization) {
    $configPath = Join-Path $PSScriptRoot "..\..\..\starter-config.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        if (-not $Project) { $Project = $config.azureDevOps.projectName }
        if (-not $Organization) { $Organization = $config.azureDevOps.organizationUrl }
    } else {
        Write-Error "❌ Configuration not found and Project/Organization not provided"
        exit 1
    }
}

# Verify authentication
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv 2>$null
if (-not $token) {
    Write-Error "❌ Azure DevOps authentication required. Run: az login"
    exit 1
}
$env:AZURE_DEVOPS_EXT_PAT = $token

Write-Host "`n🔍 Analyzing pipeline failure..." -ForegroundColor Yellow

# Get run details
try {
    $run = az pipelines runs show --id $RunId --project $Project --org $Organization --output json | ConvertFrom-Json
} catch {
    Write-Error "❌ Failed to get pipeline details: $_"
    exit 1
}

Write-Host "`n❌ Pipeline Failed" -ForegroundColor Red
Write-Host "   Run ID: $RunId" -ForegroundColor Gray
Write-Host "   Result: $($run.result)" -ForegroundColor Gray
Write-Host "   URL: $($run._links.web.href)" -ForegroundColor Gray

# Common error patterns and solutions
$troubleshooting = @{
    "ServiceConnection" = @{
        patterns = @("service connection", "Could not find service connection", "not authorized")
        solutions = @(
            "Verify service connection exists and is authorized"
            "Check federated credentials are configured"
            "Ensure service principal has correct RBAC permissions"
        )
    }
    "VariableGroup" = @{
        patterns = @("variable group", "Variable group not found", "Access denied")
        solutions = @(
            "Verify variable group exists in Azure DevOps"
            "Check variable group permissions"
            "Ensure all required variables are set"
        )
    }
    "RBAC" = @{
        patterns = @("Authorization failed", "Insufficient permissions", "Access denied")
        solutions = @(
            "Check service principal has required role assignments"
            "Verify RBAC permissions on resource groups"
            "Ensure subscription-level permissions if needed"
        )
    }
    "FederatedCredential" = @{
        patterns = @("AADSTS70021", "federated identity", "Invalid issuer")
        solutions = @(
            "Verify federated credentials exist on service principal"
            "Check issuer and subject match service connection"
            "Ensure Entra ID app has correct configuration"
        )
    }
}

Write-Host "`n💡 Common Issues to Check:" -ForegroundColor Cyan
foreach ($category in $troubleshooting.Keys) {
    Write-Host "`n   $category Issues:" -ForegroundColor Yellow
    foreach ($solution in $troubleshooting[$category].solutions) {
        Write-Host "   • $solution" -ForegroundColor Gray
    }
}

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. View full logs at: $($run._links.web.href)" -ForegroundColor Gray
Write-Host "   2. Search for error patterns in the logs" -ForegroundColor Gray
Write-Host "   3. Verify configuration in starter-config.json" -ForegroundColor Gray
Write-Host "   4. Check Azure resources and permissions" -ForegroundColor Gray

# Return structured result
$result = @{
    runId = $RunId
    result = $run.result
    url = $run._links.web.href
    succeeded = $false
    timestamp = (Get-Date).ToString("o")
} | ConvertTo-Json -Compress

Write-Output $result
