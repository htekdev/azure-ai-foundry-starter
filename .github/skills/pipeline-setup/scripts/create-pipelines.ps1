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

# Update pipeline YAML files with actual projectName
Write-Host "[Updating Pipeline YAML Files]" -ForegroundColor Yellow

# Get repository clone URL
$repoDetails = az repos show --repository $repo --org $orgUrl --project $project 2>$null | ConvertFrom-Json
if (-not $repoDetails) {
    Write-Host "  [ERROR] Could not get repository details" -ForegroundColor Red
    exit 1
}

$remoteUrl = $repoDetails.remoteUrl

# Create temporary directory for repository
$tempDir = Join-Path $env:TEMP "ado-pipeline-update-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Clone repository
    Write-Host "  [INFO] Cloning repository to update YAML files..." -ForegroundColor Blue
    Push-Location $tempDir
    
    # Clone with authentication
    git clone $remoteUrl . 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Failed to clone repository" -ForegroundColor Red
        exit 1
    }
    
    # Check if placeholder exists in YAML files
    $yamlFiles = @(
        ".azure-pipelines/createagentpipeline.yml",
        ".azure-pipelines/agentconsumptionpipeline.yml"
    )
    
    $filesUpdated = 0
    foreach ($yamlFile in $yamlFiles) {
        if (Test-Path $yamlFile) {
            $content = Get-Content $yamlFile -Raw
            
            # Check if placeholder exists
            if ($content -match "REPLACE_WITH_YOUR_PROJECTNAME") {
                Write-Host "  [INFO] Updating $yamlFile with projectName: $projectName" -ForegroundColor Blue
                
                # Replace placeholder with actual projectName
                $updatedContent = $content -replace "REPLACE_WITH_YOUR_PROJECTNAME", $projectName
                Set-Content -Path $yamlFile -Value $updatedContent -NoNewline
                
                $filesUpdated++
            } else {
                Write-Host "  [OK] $yamlFile already updated (no placeholder found)" -ForegroundColor Green
            }
        } else {
            Write-Host "  [WARN] $yamlFile not found in repository" -ForegroundColor Yellow
        }
    }
    
    # Commit and push changes if any files were updated
    if ($filesUpdated -gt 0) {
        Write-Host "  [INFO] Committing changes..." -ForegroundColor Blue
        
        git config user.email "azuredevops@automation.local"
        git config user.name "Azure DevOps Automation"
        git add -A
        git commit -m "Update pipeline YAML files with projectName: $projectName" 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [INFO] Pushing changes to repository..." -ForegroundColor Blue
            git push origin main 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Updated $filesUpdated pipeline YAML file(s) with projectName: $projectName" -ForegroundColor Green
            } else {
                Write-Host "  [ERROR] Failed to push changes to repository" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "  [WARN] No changes to commit (files may already be updated)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [OK] All pipeline YAML files are already up to date" -ForegroundColor Green
    }
    
    Pop-Location
} finally {
    # Clean up temporary directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

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
