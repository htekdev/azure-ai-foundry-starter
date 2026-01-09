# ============================================================================
# Azure AI Foundry Starter - Complete Cleanup Script
# ============================================================================
# This script performs a complete cleanup of all Azure AI Foundry resources.
#
# What this script does:
# 1. Cleans up Azure Resources (Resource Groups, Service Principal)
# 2. Cleans up Azure DevOps (Repository, Pipelines, Service Connections)
# 3. Resets Configuration File (starter-config.json)
#
# WARNING: This is IRREVERSIBLE. All resources and configurations will be
#          permanently deleted.
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$PSScriptRoot\..\starter-config.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipAzureResources,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDevOps,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipConfigReset
)

# Error handling
$ErrorActionPreference = "Stop"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "`n[$Text]" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "  [INFO] $Text" -ForegroundColor Gray
}

function Write-Warning {
    param([string]$Text)
    Write-Host "  [WARNING] $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "  [ERROR] $Text" -ForegroundColor Red
}

# ============================================================================
# Main Script
# ============================================================================

Write-Host ""
Write-Header "AZURE AI FOUNDRY COMPLETE CLEANUP"

# Load configuration
if (Test-Path $ConfigPath) {
    Write-Info "Loading configuration from: $ConfigPath"
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    Write-Success "Configuration loaded successfully"
} else {
    Write-Error "Configuration file not found: $ConfigPath"
    Write-Info "Please provide a valid configuration file path"
    exit 1
}

# Display cleanup plan
Write-Step "CLEANUP PLAN"

$cleanupSteps = @()
if (-not $SkipAzureResources) {
    $cleanupSteps += "1. Azure Resources (Resource Groups, Service Principal)"
}
if (-not $SkipDevOps) {
    $cleanupSteps += "2. Azure DevOps (Repository, Pipelines, Service Connections, Variable Groups)"
}
if (-not $SkipConfigReset) {
    $cleanupSteps += "3. Configuration File (Reset to template)"
}

if ($cleanupSteps.Count -eq 0) {
    Write-Warning "All cleanup steps are skipped. Nothing to do."
    exit 0
}

foreach ($step in $cleanupSteps) {
    Write-Host "  $step" -ForegroundColor White
}

# Show dry run banner
if ($DryRun) {
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  DRY RUN MODE - No resources will be deleted" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
}

# Confirmation
if (-not $Force -and -not $DryRun) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  WARNING: COMPLETE SYSTEM CLEANUP" -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "This will PERMANENTLY DELETE:" -ForegroundColor Red
    Write-Host "  - All Azure resource groups (dev, test, prod)" -ForegroundColor Red
    Write-Host "  - Service Principal and federated credentials" -ForegroundColor Red
    Write-Host "  - Azure DevOps repository and pipelines" -ForegroundColor Red
    Write-Host "  - All variable groups and service connections" -ForegroundColor Red
    Write-Host "  - Configuration file (will be reset)" -ForegroundColor Red
    Write-Host ""
    Write-Host "This action is IRREVERSIBLE!" -ForegroundColor Red
    Write-Host ""
    
    $confirmation = Read-Host "Type 'DELETE ALL' (uppercase) to confirm complete cleanup"
    
    if ($confirmation -ne "DELETE ALL") {
        Write-Warning "Cleanup cancelled by user"
        exit 0
    }
}

# Define script paths
$cleanupResourcesScript = "$PSScriptRoot\..\\.github\skills\cleanup-resources\scripts\cleanup-resources.ps1"
$cleanupDevOpsScript = "$PSScriptRoot\..\\.github\skills\cleanup-devops\scripts\cleanup-devops.ps1"
$resetConfigScript = "$PSScriptRoot\..\\.github\skills\config-reset\scripts\reset-config.ps1"

# ============================================================================
# Step 1: Clean up Azure Resources
# ============================================================================

if (-not $SkipAzureResources) {
    Write-Header "STEP 1: CLEANING AZURE RESOURCES"
    
    if (Test-Path $cleanupResourcesScript) {
        Write-Info "Executing Azure resource cleanup..."
        
        $params = @{
            ConfigPath = $ConfigPath
        }
        if ($Force) { $params['Force'] = $true }
        if ($DryRun) { $params['DryRun'] = $true }
        
        try {
            & $cleanupResourcesScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Azure resources cleanup completed"
            } else {
                Write-Warning "Azure resources cleanup completed with warnings"
            }
        } catch {
            Write-Error "Azure resources cleanup failed: $($_.Exception.Message)"
            Write-Info "Continuing with remaining cleanup steps..."
        }
    } else {
        Write-Error "Cleanup script not found: $cleanupResourcesScript"
        Write-Info "Skipping Azure resources cleanup"
    }
} else {
    Write-Step "STEP 1: SKIPPED - Azure Resources"
    Write-Info "Azure resources cleanup was skipped"
}

# ============================================================================
# Step 2: Clean up Azure DevOps
# ============================================================================

if (-not $SkipDevOps) {
    Write-Header "STEP 2: CLEANING AZURE DEVOPS"
    
    if (Test-Path $cleanupDevOpsScript) {
        Write-Info "Executing Azure DevOps cleanup..."
        
        $params = @{
            ConfigPath = $ConfigPath
            SkipConfig = $true  # We'll reset config separately
        }
        if ($Force) { $params['Force'] = $true }
        if ($DryRun) { $params['DryRun'] = $true }
        
        try {
            & $cleanupDevOpsScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Azure DevOps cleanup completed"
            } else {
                Write-Warning "Azure DevOps cleanup completed with warnings"
            }
        } catch {
            Write-Error "Azure DevOps cleanup failed: $($_.Exception.Message)"
            Write-Info "Continuing with remaining cleanup steps..."
        }
    } else {
        Write-Error "Cleanup script not found: $cleanupDevOpsScript"
        Write-Info "Skipping Azure DevOps cleanup"
    }
} else {
    Write-Step "STEP 2: SKIPPED - Azure DevOps"
    Write-Info "Azure DevOps cleanup was skipped"
}

# ============================================================================
# Step 3: Reset Configuration File
# ============================================================================

if (-not $SkipConfigReset) {
    Write-Header "STEP 3: RESETTING CONFIGURATION"
    
    if (Test-Path $resetConfigScript) {
        Write-Info "Executing configuration reset..."
        
        $params = @{
            ConfigPath = $ConfigPath
        }
        if ($Force) { $params['Force'] = $true }
        if ($DryRun) { $params['DryRun'] = $true }
        
        try {
            & $resetConfigScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Configuration reset completed"
            } else {
                Write-Warning "Configuration reset completed with warnings"
            }
        } catch {
            Write-Error "Configuration reset failed: $($_.Exception.Message)"
        }
    } else {
        Write-Error "Reset script not found: $resetConfigScript"
        Write-Info "Skipping configuration reset"
    }
} else {
    Write-Step "STEP 3: SKIPPED - Configuration Reset"
    Write-Info "Configuration reset was skipped"
}

# ============================================================================
# Final Summary
# ============================================================================

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  COMPLETE CLEANUP FINISHED" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN COMPLETE]" -ForegroundColor Yellow
    Write-Host "  No resources were actually deleted" -ForegroundColor Gray
    Write-Host "  Run without the DryRun flag to perform actual cleanup" -ForegroundColor Gray
} else {
    Write-Host "[CLEANUP SUMMARY]" -ForegroundColor Cyan
    
    if (-not $SkipAzureResources) {
        Write-Host "  [OK] Azure Resources" -ForegroundColor Green
    } else {
        Write-Host "  [ ] Azure Resources (skipped)" -ForegroundColor Gray
    }
    
    if (-not $SkipDevOps) {
        Write-Host "  [OK] Azure DevOps" -ForegroundColor Green
    } else {
        Write-Host "  [ ] Azure DevOps (skipped)" -ForegroundColor Gray
    }
    
    if (-not $SkipConfigReset) {
        Write-Host "  [OK] Configuration File" -ForegroundColor Green
    } else {
        Write-Host "  [ ] Configuration File (skipped)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "  1. Verify Azure resources are deleted:" -ForegroundColor Gray
Write-Host "     https://portal.azure.com" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. Verify Azure DevOps cleanup:" -ForegroundColor Gray
Write-Host "     $($config.azureDevOps.organizationUrl)/$($config.azureDevOps.projectName)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. Review backup files:" -ForegroundColor Gray
Write-Host "     - starter-config.json.backup.*" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  4. Ready for fresh deployment:" -ForegroundColor Gray
Write-Host "     - Use starter-execution skill or manual deployment" -ForegroundColor DarkGray
Write-Host ""

if (-not $DryRun) {
    Write-Host "[SUCCESS] Complete cleanup finished successfully!" -ForegroundColor Green
} else {
    Write-Host "[DRY RUN] Preview completed. Run without the DryRun flag to execute." -ForegroundColor Yellow
}

Write-Host ""