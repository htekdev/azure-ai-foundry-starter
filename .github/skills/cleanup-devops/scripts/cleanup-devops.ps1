# ============================================================================
# Azure AI Foundry Starter - Azure DevOps Cleanup
# ============================================================================
# This script deletes Azure DevOps resources and resets configuration files.
# 
# WARNING: This action is IRREVERSIBLE for Azure DevOps resources.
#
# What gets deleted:
# - Repository: azure-ai-foundry-app
# - Service Connections: {projectName}-dev/test/prod
# - Variable Groups: {projectName}-dev/test/prod-vars
# - Pipelines: All associated pipelines
# - Configuration: starter-config.json (reset to template)
#
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = ".\starter-config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipConfig,
    
    [Parameter(Mandatory=$false)]
    [switch]$OnlyConfig
)

# ============================================================================
# Helper Functions
# ============================================================================

function Test-AzDevOpsLogin {
    try {
        $null = az devops project list 2>$null
        return $true
    } catch {
        return $false
    }
}

# ============================================================================
# Load Configuration
# ============================================================================

if (Test-Path $ConfigPath) {
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    Write-Host "[OK] Loaded configuration from $ConfigPath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Configuration file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

# Extract values
$organization = $config.azureDevOps.organization
$project = $config.azureDevOps.project
$repository = $config.azureDevOps.repository
$projectName = $config.naming.projectName

# ============================================================================
# Check Azure DevOps Login
# ============================================================================

if (-not $OnlyConfig) {
    Write-Host "`n[PROCESSING] Checking Azure DevOps authentication..." -ForegroundColor Cyan
    
    if (-not (Test-AzDevOpsLogin)) {
        Write-Host "[ERROR] Not logged in to Azure DevOps. Please run: az devops login" -ForegroundColor Red
        exit 1
    }
    
    # Set default organization and project
    az devops configure --defaults organization=$organization project=$project
    Write-Host "  Organization: $organization" -ForegroundColor Gray
    Write-Host "  Project: $project" -ForegroundColor Gray
}

# ============================================================================
# Display what will be deleted
# ============================================================================

Write-Host "`n" -NoNewline
Write-Host "===============================================================" -ForegroundColor Yellow
Write-Host "  WARNING: AZURE DEVOPS RESOURCE DELETION" -ForegroundColor Yellow
Write-Host "===============================================================" -ForegroundColor Yellow

Write-Host "`nThe following resources will be PERMANENTLY DELETED:" -ForegroundColor Red

# Check Repository
if (-not $OnlyConfig) {
    Write-Host "`n[REPOSITORY]:" -ForegroundColor Cyan
    try {
        $repos = az repos list --query "[?name=='$repository'].{Name:name, Id:id}" -o json | ConvertFrom-Json
        if ($repos -and $repos.Count -gt 0) {
            foreach ($repo in $repos) {
                Write-Host "  [X] $($repo.Name)" -ForegroundColor Red
            }
        } else {
            Write-Host "  [INFO] Repository '$repository' not found" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [WARNING] Could not check repositories: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Check Service Connections
    Write-Host "`n[SERVICE CONNECTIONS]:" -ForegroundColor Cyan
    try {
        $serviceEndpoints = az devops service-endpoint list --query "[?contains(name, '$projectName')].{Name:name, Id:id}" -o json | ConvertFrom-Json
        if ($serviceEndpoints -and $serviceEndpoints.Count -gt 0) {
            foreach ($endpoint in $serviceEndpoints) {
                Write-Host "  [X] $($endpoint.Name)" -ForegroundColor Red
            }
        } else {
            Write-Host "  [INFO] No service connections found matching pattern" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [WARNING] Could not check service connections: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Check Variable Groups
    Write-Host "`n[VARIABLE GROUPS]:" -ForegroundColor Cyan
    try {
        $variableGroups = az pipelines variable-group list --query "[?contains(name, '$projectName')].{Name:name, Id:id}" -o json | ConvertFrom-Json
        if ($variableGroups -and $variableGroups.Count -gt 0) {
            foreach ($vg in $variableGroups) {
                Write-Host "  [X] $($vg.Name)" -ForegroundColor Red
            }
        } else {
            Write-Host "  [INFO] No variable groups found matching pattern" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [WARNING] Could not check variable groups: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Check Pipelines
    Write-Host "`n[PIPELINES]:" -ForegroundColor Cyan
    try {
        $pipelines = az pipelines list --query "[?contains(name, '$projectName')].{Name:name, Id:id}" -o json | ConvertFrom-Json
        if ($pipelines -and $pipelines.Count -gt 0) {
            foreach ($pipeline in $pipelines) {
                Write-Host "  [X] $($pipeline.Name)" -ForegroundColor Red
            }
        } else {
            Write-Host "  [INFO] No pipelines found matching pattern" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [WARNING] Could not check pipelines: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Check Configuration File
if (-not $SkipConfig) {
    Write-Host "`n[CONFIGURATION]:" -ForegroundColor Cyan
    if (Test-Path $ConfigPath) {
        Write-Host "  [RESET] $ConfigPath will be reset to template" -ForegroundColor Yellow
    } else {
        Write-Host "  [INFO] Config file not found" -ForegroundColor Gray
    }
}

Write-Host "`n===============================================================" -ForegroundColor Yellow

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
    Write-Host "   All Azure DevOps configurations and history will be permanently lost." -ForegroundColor Red
    Write-Host ""
    $confirmation = Read-Host "Type 'DELETE' (in uppercase) to confirm deletion"
    
    if ($confirmation -ne "DELETE") {
        Write-Host "`n[CANCELLED] Deletion cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`n[DELETE] Starting resource deletion..." -ForegroundColor Red

# ============================================================================
# Delete Azure DevOps Resources
# ============================================================================

if (-not $OnlyConfig) {
    # Delete Pipelines
    Write-Host "`n[PIPELINES] Deleting Pipelines..." -ForegroundColor Cyan
    try {
        $pipelines = az pipelines list --query "[?contains(name, '$projectName')].{Name:name, Id:id}" -o json | ConvertFrom-Json
        if ($pipelines -and $pipelines.Count -gt 0) {
            foreach ($pipeline in $pipelines) {
                Write-Host "  [DELETE] Deleting: $($pipeline.Name)..." -ForegroundColor Yellow
                try {
                    az pipelines delete --id $pipeline.Id --yes 2>$null
                    Write-Host "     [OK] Pipeline deleted" -ForegroundColor Green
                } catch {
                    Write-Host "     [ERROR] Failed to delete: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  [INFO] No pipelines to delete" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [ERROR] Could not delete pipelines: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Delete Variable Groups
    Write-Host "`n[VARIABLE GROUPS] Deleting Variable Groups..." -ForegroundColor Cyan
    try {
        $variableGroups = az pipelines variable-group list --query "[?contains(name, '$projectName')].{Name:name, Id:id}" -o json | ConvertFrom-Json
        if ($variableGroups -and $variableGroups.Count -gt 0) {
            foreach ($vg in $variableGroups) {
                Write-Host "  [DELETE] Deleting: $($vg.Name)..." -ForegroundColor Yellow
                try {
                    az pipelines variable-group delete --id $vg.Id --yes 2>$null
                    Write-Host "     [OK] Variable group deleted" -ForegroundColor Green
                } catch {
                    Write-Host "     [ERROR] Failed to delete: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  [INFO] No variable groups to delete" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [ERROR] Could not delete variable groups: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Delete Service Connections
    Write-Host "`n[SERVICE CONNECTIONS] Deleting Service Connections..." -ForegroundColor Cyan
    try {
        $serviceEndpoints = az devops service-endpoint list --query "[?contains(name, '$projectName')].{Name:name, Id:id}" -o json | ConvertFrom-Json
        if ($serviceEndpoints -and $serviceEndpoints.Count -gt 0) {
            foreach ($endpoint in $serviceEndpoints) {
                Write-Host "  [DELETE] Deleting: $($endpoint.Name)..." -ForegroundColor Yellow
                try {
                    az devops service-endpoint delete --id $endpoint.Id --yes 2>$null
                    Write-Host "     [OK] Service connection deleted" -ForegroundColor Green
                } catch {
                    Write-Host "     [ERROR] Failed to delete: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  [INFO] No service connections to delete" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [ERROR] Could not delete service connections: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Delete Repository (Note: Cannot delete if running from within it)
    Write-Host "`n[REPOSITORY] Deleting Repository..." -ForegroundColor Cyan
    try {
        $repos = az repos list --query "[?name=='$repository'].{Name:name, Id:id}" -o json | ConvertFrom-Json
        if ($repos -and $repos.Count -gt 0) {
            foreach ($repo in $repos) {
                Write-Host "  [DELETE] Deleting: $($repo.Name)..." -ForegroundColor Yellow
                Write-Host "     [WARNING] Repository deletion may fail if script is running from within it" -ForegroundColor Yellow
                Write-Host "     [INFO] If deletion fails, manually delete from Azure DevOps portal" -ForegroundColor Gray
                try {
                    az repos delete --id $repo.Id --yes 2>$null
                    Write-Host "     [OK] Repository deleted" -ForegroundColor Green
                } catch {
                    Write-Host "     [ERROR] Failed to delete: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "     [INFO] Manually delete from: https://dev.azure.com/$organization/$project/_settings/repositories" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  [INFO] Repository not found" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [ERROR] Could not delete repository: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================================
# Reset Configuration File
# ============================================================================

if (-not $SkipConfig) {
    Write-Host "`n[CONFIGURATION] Resetting Configuration File..." -ForegroundColor Cyan
    
    if (Test-Path $ConfigPath) {
        # Backup current config
        $backupPath = "$ConfigPath.backup"
        Copy-Item $ConfigPath $backupPath -Force
        Write-Host "  [BACKUP] Current config backed up to: $backupPath" -ForegroundColor Gray
        
        # Create template config
        $templateConfig = @{
            azure = @{
                subscriptionId = ""
                tenantId = ""
                location = "eastus"
            }
            azureDevOps = @{
                organization = ""
                project = ""
                repository = "azure-ai-foundry-app"
            }
            servicePrincipal = @{
                appId = ""
                displayName = "sp-rg-ai-foundry-starter"
            }
            naming = @{
                projectName = ""
            }
            resources = @{
                resourceGroupPrefix = "rg-ai-foundry-starter"
                aiHubPrefix = "aif-hub"
                aiProjectPrefix = "aif-project"
                aiServicesPrefix = "aif-foundry"
            }
            environments = @("dev", "test", "prod")
        }
        
        # Save template config
        $templateConfig | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
        Write-Host "  [OK] Configuration file reset to template" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Configuration file not found, nothing to reset" -ForegroundColor Gray
    }
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n" -NoNewline
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "  CLEANUP COMPLETE" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green

Write-Host "`n[CLEANUP SUMMARY]:" -ForegroundColor Cyan

if (-not $OnlyConfig) {
    Write-Host "  [PIPELINES] Deleted" -ForegroundColor Gray
    Write-Host "  [VARIABLE GROUPS] Deleted" -ForegroundColor Gray
    Write-Host "  [SERVICE CONNECTIONS] Deleted" -ForegroundColor Gray
    Write-Host "  [REPOSITORY] Deletion attempted (verify manually)" -ForegroundColor Gray
}

if (-not $SkipConfig) {
    Write-Host "  [CONFIGURATION] Reset to template" -ForegroundColor Gray
}

Write-Host "`n[NEXT STEPS]:" -ForegroundColor Cyan
Write-Host "  1. Verify deletion in Azure DevOps:" -ForegroundColor Gray
Write-Host "     https://dev.azure.com/$organization/$project" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. If repository deletion failed, manually delete from:" -ForegroundColor Gray
Write-Host "     Project Settings > Repositories > $repository > ... > Delete" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. Review backup configuration file:" -ForegroundColor Gray
Write-Host "     $ConfigPath.backup" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  4. Repository is now ready for a fresh deployment" -ForegroundColor Gray

Write-Host "`n[SUCCESS] All Azure DevOps resources have been cleaned up!" -ForegroundColor Green
Write-Host ""
