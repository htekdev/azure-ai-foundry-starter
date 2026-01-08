#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitors Azure DevOps pipeline execution until completion
.DESCRIPTION
    Polls pipeline status, provides progress updates, and returns detailed results
.PARAMETER RunId
    Pipeline run ID to monitor
.PARAMETER Project
    Azure DevOps project name (optional, reads from config)
.PARAMETER Organization
    Azure DevOps organization URL (optional, reads from config)
.PARAMETER MaxWaitTime
    Maximum time to wait in seconds (default: 1800 = 30 minutes)
.PARAMETER PollInterval
    Polling interval in seconds (default: 10)
.PARAMETER Quiet
    Suppress progress messages
.EXAMPLE
    .\monitor-pipeline.ps1 -RunId 123
.EXAMPLE
    .\monitor-pipeline.ps1 -RunId 123 -MaxWaitTime 600 -PollInterval 5
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$RunId,
    
    [Parameter(Mandatory = $false)]
    [string]$Project,
    
    [Parameter(Mandatory = $false)]
    [string]$Organization,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxWaitTime = 1800,
    
    [Parameter(Mandatory = $false)]
    [int]$PollInterval = 10,
    
    [Parameter(Mandatory = $false)]
    [switch]$Quiet
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

if (-not $Quiet) {
    Write-Host "`n🔄 Monitoring pipeline run $RunId..." -ForegroundColor Cyan
    Write-Host "   Project: $Project" -ForegroundColor Gray
    Write-Host "   Max wait: $MaxWaitTime seconds" -ForegroundColor Gray
}

$completed = $false
$startTime = Get-Date

while (-not $completed) {
    # Get current status
    try {
        $run = az pipelines runs show --id $RunId --project $Project --org $Organization --output json 2>&1 | ConvertFrom-Json
    } catch {
        Write-Error "❌ Failed to get pipeline status: $_"
        exit 1
    }
    
    $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
    
    if ($run.status -eq "completed") {
        $completed = $true
        
        if (-not $Quiet) {
            Write-Host "`n✅ Pipeline completed!" -ForegroundColor Green
            Write-Host "   Result: $($run.result)" -ForegroundColor $(if ($run.result -eq "succeeded") { "Green" } else { "Red" })
            Write-Host "   Duration: $elapsed seconds" -ForegroundColor Gray
            Write-Host "   URL: $($run._links.web.href)" -ForegroundColor Gray
        }
        
        # Return structured result as JSON
        $result = @{
            runId = $RunId
            status = $run.status
            result = $run.result
            duration = $elapsed
            url = $run._links.web.href
            succeeded = ($run.result -eq "succeeded")
        } | ConvertTo-Json -Compress
        
        Write-Output $result
        exit $(if ($run.result -eq "succeeded") { 0 } else { 1 })
        
    } else {
        # Check timeout
        if ($elapsed -gt $MaxWaitTime) {
            if (-not $Quiet) {
                Write-Host "`n⚠️ Timeout: Pipeline still running after $MaxWaitTime seconds" -ForegroundColor Yellow
                Write-Host "   URL: $($run._links.web.href)" -ForegroundColor Gray
            }
            
            $result = @{
                runId = $RunId
                status = "timeout"
                duration = $elapsed
                url = $run._links.web.href
                succeeded = $false
            } | ConvertTo-Json -Compress
            
            Write-Output $result
            exit 1
        }
        
        # Show progress
        if (-not $Quiet) {
            Write-Host "🔄 Status: $($run.status) | Elapsed: ${elapsed}s" -ForegroundColor Cyan
        }
        
        Start-Sleep -Seconds $PollInterval
    }
}
