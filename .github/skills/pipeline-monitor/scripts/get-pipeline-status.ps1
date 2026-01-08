#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Gets current status of an Azure DevOps pipeline run
.DESCRIPTION
    Retrieves current status and result without waiting
.PARAMETER RunId
    Pipeline run ID to check
.PARAMETER Project
    Azure DevOps project name (optional, reads from config)
.PARAMETER Organization
    Azure DevOps organization URL (optional, reads from config)
.EXAMPLE
    .\get-pipeline-status.ps1 -RunId 123
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

# Get run details
try {
    $run = az pipelines runs show --id $RunId --project $Project --org $Organization --output json | ConvertFrom-Json
} catch {
    Write-Error "❌ Failed to get pipeline status: $_"
    exit 1
}

# Return structured result
$result = @{
    runId = $RunId
    status = $run.status
    result = $run.result
    url = $run._links.web.href
    createdDate = $run.createdDate
    finishedDate = $run.finishedDate
} | ConvertTo-Json -Compress

Write-Output $result
