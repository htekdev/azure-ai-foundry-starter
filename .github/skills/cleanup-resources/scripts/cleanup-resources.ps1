# ============================================================================
# Azure AI Foundry Starter - Complete Resource Cleanup
# ============================================================================
# This script deletes ALL Azure resources created by the starter template.
# 
# WARNING: This action is IRREVERSIBLE. All resources will be permanently deleted.
#
# What gets deleted:
# - All Resource Groups (rg-ai-foundry-starter-dev, test, prod)
# - Service Principal and all federated credentials
# - All AI Foundry Projects and AI Services
# - All role assignments
#
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = ".\starter-config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Load configuration
if (Test-Path $ConfigPath) {
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    Write-Host "[OK] Loaded configuration from $ConfigPath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Configuration file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

# Extract values
$subscriptionId = $config.azure.subscriptionId
$tenantId = $config.azure.tenantId
$spAppId = $config.servicePrincipal.appId

# Set subscription context
Write-Host "`n[PROCESSING] Setting Azure subscription context..." -ForegroundColor Cyan
az account set --subscription $subscriptionId

# Get current subscription info
$currentSub = az account show | ConvertFrom-Json
Write-Host "  Subscription: $($currentSub.name)" -ForegroundColor Gray
Write-Host "  Subscription ID: $($currentSub.id)" -ForegroundColor Gray

# ============================================================================
# Display what will be deleted
# ============================================================================

Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  WARNING: RESOURCE DELETION" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow

Write-Host "`nThe following resources will be PERMANENTLY DELETED:" -ForegroundColor Red

# Check resource groups
Write-Host "`n[RESOURCE GROUPS]:" -ForegroundColor Cyan
$rgPattern = "rg-ai-foundry-starter*"
$resourceGroups = az group list --query "[?starts_with(name, 'rg-ai-foundry-starter')].{Name:name, Location:location}" -o json | ConvertFrom-Json

if ($resourceGroups.Count -gt 0) {
    foreach ($rg in $resourceGroups) {
        Write-Host "  [X] $($rg.Name) ($($rg.Location))" -ForegroundColor Red
        
        # List resources in the resource group
        $resources = az resource list --resource-group $rg.Name --query "[].{Name:name, Type:type}" -o json | ConvertFrom-Json
        if ($resources.Count -gt 0) {
            Write-Host "     Contains $($resources.Count) resources:" -ForegroundColor Gray
            foreach ($resource in $resources) {
                $typeParts = $resource.Type -split '/'
                $shortType = $typeParts[-1]
                Write-Host "       - $($resource.Name) ($shortType)" -ForegroundColor DarkGray
            }
        }
    }
} else {
    Write-Host "  [INFO] No resource groups found matching pattern: $rgPattern" -ForegroundColor Gray
}

# Check Service Principal
Write-Host "`n[SERVICE PRINCIPAL]:" -ForegroundColor Cyan
if ($spAppId) {
    $spInfo = az ad sp show --id $spAppId 2>$null | ConvertFrom-Json
    if ($spInfo) {
        Write-Host "  [X] $($spInfo.displayName) (App ID: $spAppId)" -ForegroundColor Red
        
        # List federated credentials
        $fedCreds = az ad app federated-credential list --id $spAppId 2>$null | ConvertFrom-Json
        if ($fedCreds -and $fedCreds.Count -gt 0) {
            Write-Host "     Contains $($fedCreds.Count) federated credentials:" -ForegroundColor Gray
            foreach ($cred in $fedCreds) {
                Write-Host "       - $($cred.name)" -ForegroundColor DarkGray
            }
        }
        
        # List role assignments
        $roleAssignments = az role assignment list --assignee $spAppId --query "[].{Role:roleDefinitionName, Scope:scope}" -o json | ConvertFrom-Json
        if ($roleAssignments -and $roleAssignments.Count -gt 0) {
            Write-Host "     Has $($roleAssignments.Count) role assignments" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [INFO] Service Principal not found (may already be deleted)" -ForegroundColor Gray
    }
} else {
    Write-Host "  [INFO] No Service Principal configured" -ForegroundColor Gray
}

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow

# ============================================================================
# Confirmation
# ============================================================================

if ($DryRun) {
    Write-Host "`n[DRY RUN] DRY RUN MODE - No resources will be deleted" -ForegroundColor Yellow
    Write-Host "`nTo actually delete resources, run without -DryRun flag" -ForegroundColor Gray
    exit 0
}

if (-not $Force) {
    Write-Host "`n[WARNING] This action is IRREVERSIBLE!" -ForegroundColor Red
    Write-Host "   All data, configurations, and deployments will be permanently lost." -ForegroundColor Red
    Write-Host ""
    $confirmation = Read-Host "Type 'DELETE' (in uppercase) to confirm deletion"
    
    if ($confirmation -ne "DELETE") {
        Write-Host "`n[CANCELLED] Deletion cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`n[DELETE] Starting resource deletion..." -ForegroundColor Red

# ============================================================================
# Delete Resource Groups (this deletes all contained resources)
# ============================================================================

if ($resourceGroups.Count -gt 0) {
    Write-Host "`n[RESOURCE GROUPS] Deleting Resource Groups..." -ForegroundColor Cyan
    
    foreach ($rg in $resourceGroups) {
        Write-Host "  [DELETE] Deleting: $($rg.Name)..." -ForegroundColor Yellow
        
        try {
            az group delete --name $rg.Name --yes --no-wait
            Write-Host "     [OK] Deletion initiated (running in background)" -ForegroundColor Green
        } catch {
            Write-Host "     [ERROR] Failed to delete: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n  [WAIT] Resource groups are being deleted in the background." -ForegroundColor Gray
    Write-Host "     This may take 5-10 minutes to complete." -ForegroundColor Gray
    Write-Host "     You can monitor progress in the Azure Portal." -ForegroundColor Gray
} else {
    Write-Host "`n[RESOURCE GROUPS] No resource groups to delete" -ForegroundColor Gray
}

# ============================================================================
# Delete Service Principal and Role Assignments
# ============================================================================

if ($spAppId) {
    Write-Host "`n[SERVICE PRINCIPAL] Deleting Service Principal..." -ForegroundColor Cyan
    
    $spInfo = az ad sp show --id $spAppId 2>$null | ConvertFrom-Json
    if ($spInfo) {
        Write-Host "  [DELETE] Deleting: $($spInfo.displayName)..." -ForegroundColor Yellow
        
        try {
            # Delete the Service Principal (this also deletes federated credentials and app registration)
            az ad sp delete --id $spAppId
            Write-Host "     [OK] Service Principal deleted successfully" -ForegroundColor Green
            Write-Host "     (All federated credentials and role assignments removed)" -ForegroundColor Gray
        } catch {
            Write-Host "     [ERROR] Failed to delete Service Principal: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [INFO] Service Principal not found (may already be deleted)" -ForegroundColor Gray
    }
} else {
    Write-Host "`n[SERVICE PRINCIPAL] No Service Principal to delete" -ForegroundColor Gray
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  CLEANUP COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green

Write-Host "`n[CLEANUP SUMMARY]:" -ForegroundColor Cyan

if ($resourceGroups.Count -gt 0) {
    Write-Host "  [RESOURCE GROUPS] $($resourceGroups.Count) deletion(s) initiated" -ForegroundColor Gray
    Write-Host "     (Deleting resources in background - may take 5-10 minutes)" -ForegroundColor DarkGray
} else {
    Write-Host "  [RESOURCE GROUPS] None found" -ForegroundColor Gray
}

if ($spAppId -and $spInfo) {
    Write-Host "  [SERVICE PRINCIPAL] Deleted" -ForegroundColor Gray
} else {
    Write-Host "  [SERVICE PRINCIPAL] None found or already deleted" -ForegroundColor Gray
}

Write-Host "`n[NEXT STEPS]:" -ForegroundColor Cyan
Write-Host "  1. Verify deletion in Azure Portal:" -ForegroundColor Gray
Write-Host "     https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. Check for any orphaned resources:" -ForegroundColor Gray
Write-Host "     az resource list --subscription $subscriptionId" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. (Optional) Clean up Azure DevOps resources:" -ForegroundColor Gray
Write-Host "     - Delete repository: azure-ai-foundry-app" -ForegroundColor DarkGray
Write-Host "     - Delete service connections: azure-foundry-dev/test/prod" -ForegroundColor DarkGray
Write-Host "     - Delete variable groups: foundry-dev/test/prod-vars" -ForegroundColor DarkGray
Write-Host "     - Delete pipelines" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  4. (Optional) Reset configuration file:" -ForegroundColor Gray
Write-Host "     Remove or reset starter-config.json" -ForegroundColor DarkGray

Write-Host "`n[SUCCESS] All Azure resources have been cleaned up!" -ForegroundColor Green
Write-Host ""
