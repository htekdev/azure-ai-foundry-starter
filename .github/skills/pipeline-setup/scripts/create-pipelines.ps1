#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates Azure DevOps CI/CD pipelines

.DESCRIPTION
    This script creates pipelines from template YAML files in the repository.
    It creates pipelines for agent creation, testing, and deployment automation.

.PARAMETER UseConfig
    Load configuration from starter-config.json file

.PARAMETER SkipFirstRun
    Skip the first run of created pipelines (default: true)

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./create-pipelines.ps1 -UseConfig

.EXAMPLE
    ./create-pipelines.ps1 -UseConfig -SkipFirstRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$UseConfig,

    [Parameter(Mandatory = $false)]
    [bool]$SkipFirstRun = $true,

    [Parameter(Mandatory = $false)]
    [ValidateSet('text', 'json')]
    [string]$OutputFormat = 'text'
)

$ErrorActionPreference = 'Stop'

# Load configuration if UseConfig is specified
if ($UseConfig) {
    . "$PSScriptRoot/../../configuration-management/config-functions.ps1"
    $config = Get-StarterConfig
    
    if ($config) {
        Write-Host "[OK] Loaded configuration from starter-config.json" -ForegroundColor Green
    }
    else {
        Write-Error "Could not load configuration"
        exit 1
    }
}

Write-Host "=== Azure DevOps Pipeline Setup ===" -ForegroundColor Cyan
Write-Host "Organization: $($config.azureDevOps.organizationUrl)" -ForegroundColor Gray
Write-Host "Project: $($config.azureDevOps.projectName)" -ForegroundColor Gray
Write-Host ""

$orgUrl = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
$projectName = $config.naming.projectName

# Check if repository exists
Write-Host "[Checking Repository]" -ForegroundColor Yellow
$repo = az repos list --org $orgUrl --project $project --query "[?name=='$project'].name" -o tsv 2>$null

if (-not $repo) {
    Write-Host "  [ERROR] Repository '$project' not found" -ForegroundColor Red
    Write-Host "  Please create the repository first using repository-setup skill" -ForegroundColor Yellow
    exit 1
}

Write-Host "  [OK] Repository found: $repo" -ForegroundColor Green
Write-Host ""

# Define pipelines to create
$pipelines = @(
    @{
        Name = "CreateAgent-Pipeline"
        YamlPath = ".azure-pipelines/createagentpipeline.yml"
        Description = "Pipeline for creating and deploying AI agents"
    },
    @{
        Name = "AgentConsumption-Pipeline"
        YamlPath = ".azure-pipelines/agentconsumptionpipeline.yml"
        Description = "Pipeline for agent evaluation and red teaming"
    }
)

Write-Host "[Creating Pipelines]" -ForegroundColor Yellow

foreach ($pipeline in $pipelines) {
    # Check if pipeline already exists
    $existingPipeline = az pipelines list `
        --org $orgUrl `
        --project $project `
        --query "[?name=='$($pipeline.Name)'].name" `
        -o tsv 2>$null
    
    if ($existingPipeline) {
        Write-Host "  [OK] Pipeline already exists: $($pipeline.Name)" -ForegroundColor Green
        continue
    }
    
    Write-Host "  [INFO] Creating pipeline: $($pipeline.Name)" -ForegroundColor Blue
    
    # Create pipeline
    $createArgs = @(
        "--org", $orgUrl
        "--project", $project
        "--name", $pipeline.Name
        "--repository", $repo
        "--repository-type", "tfsgit"
        "--branch", "main"
        "--yml-path", $pipeline.YamlPath
        "--description", $pipeline.Description
    )
    
    if ($SkipFirstRun) {
        $createArgs += "--skip-first-run"
    }
    
    $result = az pipelines create @createArgs 2>&1
    
    # Check if pipeline was created (look for success indicators in output)
    if ($result -match "(Successfully created|Id: \d+)" -or $LASTEXITCODE -eq 0) {
        # Extract pipeline ID if present
        if ($result -match "Id: (\d+)") {
            $pipelineId = $matches[1]
            Write-Host "  [OK] Created pipeline: $($pipeline.Name) (ID: $pipelineId)" -ForegroundColor Green
        } else {
            Write-Host "  [OK] Created pipeline: $($pipeline.Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "  [WARN] Failed to create pipeline: $($pipeline.Name)" -ForegroundColor Yellow
        Write-Host "  This may be because the YAML file doesn't exist in the repository yet" -ForegroundColor Yellow
        Write-Host "  You can create it manually after pushing the code" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[OK] Pipeline setup completed" -ForegroundColor Green
exit 0
