#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Resets starter-config.json to template state with proper backups

.DESCRIPTION
    This script resets the starter-config.json file to its default template state.
    It creates a timestamped backup before resetting, ensuring no data is lost.
    Useful for starting fresh after testing or when the config becomes corrupted.

.PARAMETER ConfigPath
    Path to the starter-config.json file. Default: ./starter-config.json

.PARAMETER BackupPath
    Optional custom backup location. Default: {ConfigPath}.backup.{timestamp}

.PARAMETER Force
    Skip confirmation prompt

.PARAMETER DryRun
    Preview the reset without making changes

.EXAMPLE
    .\reset-config.ps1
    Interactive reset with confirmation

.EXAMPLE
    .\reset-config.ps1 -Force
    Reset without confirmation

.EXAMPLE
    .\reset-config.ps1 -DryRun
    Preview the reset operation
#>

param(
    [string]$ConfigPath = ".\starter-config.json",
    [string]$BackupPath = "",
    [switch]$Force,
    [switch]$DryRun
)

# Error handling
$ErrorActionPreference = "Stop"

# Template configuration (default state)
$templateConfig = @{
    naming = @{
        projectName = ""
    }
    azureDevOps = @{
        organizationUrl = ""
        projectName = ""
    }
    azure = @{
        subscriptionId = ""
        subscriptionName = ""
        tenantId = ""
        location = "eastus"
        aiFoundry = @{
            dev = @{
                projectEndpoint = ""
            }
            test = @{
                projectEndpoint = ""
            }
            prod = @{
                projectEndpoint = ""
            }
        }
    }
    servicePrincipal = @{
        appId = ""
        tenantId = ""
    }
    metadata = @{
        version = "2.0"
        description = "Azure AI Foundry Starter Template Configuration"
        lastModified = (Get-Date -Format "yyyy-MM-dd")
    }
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Show-Summary {
    param(
        [string]$ConfigPath,
        [string]$BackupPath,
        [bool]$ConfigExists
    )
    
    Write-Host "`n=== RESET CONFIGURATION SUMMARY ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Config File:" -ForegroundColor Yellow
    Write-Host "  Path: $ConfigPath"
    Write-Host "  Exists: $ConfigExists"
    
    if ($ConfigExists) {
        Write-Host "  Backup: $BackupPath" -ForegroundColor Green
    }
    
    Write-Host "`nTemplate Structure:" -ForegroundColor Yellow
    Write-Host "  - Azure DevOps: organizationUrl, projectName"
    Write-Host "  - Azure: subscriptionId, subscriptionName, tenantId, location"
    Write-Host "  - AI Foundry: dev/test/prod projectEndpoints"
    Write-Host "  - Service Principal: appId, tenantId"
    Write-Host "  - Metadata: version, description, lastModified"
    Write-Host ""
}

function Backup-ConfigFile {
    param(
        [string]$ConfigPath,
        [string]$BackupPath
    )
    
    if (Test-Path $ConfigPath) {
        Write-ColorOutput "Creating backup: $BackupPath" "Yellow"
        Copy-Item -Path $ConfigPath -Destination $BackupPath -Force
        Write-ColorOutput "Backup created successfully" "Green"
        return $true
    }
    return $false
}

function Reset-ConfigFile {
    param(
        [string]$ConfigPath,
        [hashtable]$Template
    )
    
    Write-ColorOutput "Resetting config to template state..." "Yellow"
    $jsonContent = $Template | ConvertTo-Json -Depth 10
    Set-Content -Path $ConfigPath -Value $jsonContent -Encoding UTF8
    Write-ColorOutput "Config reset successfully" "Green"
}

# Main execution
try {
    Write-Host ""
    Write-ColorOutput "=== Azure AI Foundry Config Reset ===" "Cyan"
    Write-Host ""
    
    # Resolve full path
    $ConfigPath = Resolve-Path $ConfigPath -ErrorAction SilentlyContinue
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path (Get-Location) "starter-config.json"
    }
    
    $configExists = Test-Path $ConfigPath
    
    # Set backup path with timestamp
    if (-not $BackupPath) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $BackupPath = "$ConfigPath.backup.$timestamp"
    }
    
    # Show summary
    Show-Summary -ConfigPath $ConfigPath -BackupPath $BackupPath -ConfigExists $configExists
    
    # Dry run mode
    if ($DryRun) {
        Write-ColorOutput "DRY RUN MODE - No changes will be made" "Cyan"
        Write-Host ""
        Write-Host "Would perform:" -ForegroundColor Yellow
        if ($configExists) {
            Write-Host "  1. Backup current config to: $BackupPath"
        }
        Write-Host "  2. Reset config to template state"
        Write-Host "  3. All values set to empty strings (except metadata)"
        Write-Host ""
        return
    }
    
    # Confirmation
    if (-not $Force) {
        Write-Host ""
        Write-ColorOutput "WARNING: This will reset starter-config.json to template state" "Yellow"
        if ($configExists) {
            Write-ColorOutput "A backup will be created before resetting" "Green"
        }
        Write-Host ""
        $confirmation = Read-Host "Type 'RESET' to continue"
        
        if ($confirmation -ne "RESET") {
            Write-ColorOutput "Reset cancelled" "Yellow"
            return
        }
    }
    
    Write-Host ""
    
    # Create backup if file exists
    if ($configExists) {
        $backupSuccess = Backup-ConfigFile -ConfigPath $ConfigPath -BackupPath $BackupPath
        if (-not $backupSuccess) {
            Write-ColorOutput "Warning: Could not create backup (file may not exist)" "Yellow"
        }
    } else {
        Write-ColorOutput "No existing config file found - creating new template" "Yellow"
    }
    
    # Reset config file
    Reset-ConfigFile -ConfigPath $ConfigPath -Template $templateConfig
    
    Write-Host ""
    Write-ColorOutput "=== RESET COMPLETE ===" "Green"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Edit starter-config.json with your configuration values"
    Write-Host "  2. Run deployment scripts or use configuration-management skill"
    Write-Host ""
    
    if ($configExists) {
        Write-Host "Backup location: $BackupPath" -ForegroundColor Gray
        Write-Host ""
    }
    
} catch {
    Write-ColorOutput "Error during reset: $_" "Red"
    exit 1
}
