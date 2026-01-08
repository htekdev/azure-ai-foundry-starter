#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Orchestrates creation of Azure resources for Azure AI Foundry multi-environment deployment.

.DESCRIPTION
    This orchestration script coordinates specialized skills to create a complete Azure AI Foundry infrastructure:
    - Resource Groups (via ../resource-groups skill)
    - Service Principal with RBAC (via ../service-principal skill)
    - AI Foundry Resources and Projects (via ../ai-foundry-resources skill)
    
    Each specialized skill can also be run independently for targeted resource creation.
    
    IMPORTANT: This script creates AI Services resources (kind: AIServices) with custom domains,
    NOT ML Workspace hubs. Projects are created using 'az cognitiveservices account project create'.
    
    NOTE: Federated credentials are NOT created here. They must be created AFTER
    Azure DevOps service connections are set up, using the actual issuer/subject
    values from the service connection. See starter-execution/LESSONS_LEARNED.md #1.

.PARAMETER UseConfig
    Load configuration from starter-config.json file

.PARAMETER ResourceGroupBaseName
    Base name for Azure resource groups (will be appended with -dev, -test, -prod)

.PARAMETER Location
    Azure region for resources

.PARAMETER ServicePrincipalName
    Name for the Service Principal

.PARAMETER AIProjectBaseName
    Base name for AI Services resources and projects

.PARAMETER Environment
    Which environment(s) to create: 'dev', 'test', 'prod', or 'all' (default: all)

.PARAMETER CreateServicePrincipal
    Create Service Principal if true

.PARAMETER CreateAIProjects
    Create AI Foundry resources and projects if true

.PARAMETER CreateAll
    Create all resources

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.EXAMPLE
    ./create-resources.ps1 -UseConfig -CreateAll

.EXAMPLE
    ./create-resources.ps1 -ResourceGroupBaseName "rg-aif-demo" -Location "eastus" -CreateAIProjects
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$UseConfig,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupBaseName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalName,

    [Parameter(Mandatory = $false)]
    [string]$AIProjectBaseName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'test', 'prod', 'all')]
    [string]$Environment = 'all',

    [Parameter(Mandatory = $false)]
    [bool]$CreateServicePrincipal = $false,

    [Parameter(Mandatory = $false)]
    [bool]$CreateAIProjects = $false,

    [Parameter(Mandatory = $false)]
    [switch]$CreateAll,

    [Parameter(Mandatory = $false)]
    [ValidateSet('text', 'json')]
    [string]$OutputFormat = 'text'
)

$ErrorActionPreference = 'Stop'

# Initialize Azure CLI
$azCliPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
if ((Test-Path $azCliPath) -and ($env:Path -notlike "*$azCliPath*")) {
    $env:Path += ";$azCliPath"
}

# Simple result tracker
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Skills    = @()
    Summary   = @{
        Succeeded = 0
        Failed    = 0
    }
}

# Load configuration if UseConfig is specified
if ($UseConfig) {
    . "$PSScriptRoot/../configuration-management/config-functions.ps1"
    $config = Get-StarterConfig
    
    if ($config) {
        $ResourceGroupBaseName = $config.azure.resourceGroup
        $Location = $config.azure.location
        $ServicePrincipalName = "sp-$ResourceGroupBaseName"
        $AIProjectBaseName = $ResourceGroupBaseName
        
        Write-Host "✅ Loaded configuration from starter-config.json" -ForegroundColor Green
    }
    else {
        Write-Error "Could not load configuration. Run: ../configuration-management/configure-starter.ps1 -Interactive"
        exit 1
    }
}

# Set flags if CreateAll is specified
if ($CreateAll) {
    $CreateServicePrincipal = $true
    $CreateAIProjects = $true
Write-Host ""
Write-Host "=== Azure AI Foundry Multi-Environment Resource Creation ===" -ForegroundColor Cyan
Write-Host "Base Name: $ResourceGroupBaseName" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host "Environment: $Environment" -ForegroundColor Gray
Write-Host ""
Write-Host "This orchestration coordinates these specialized skills:" -ForegroundColor Cyan
Write-Host "  1. resource-groups skill - Creates resource groups" -ForegroundColor Gray
if ($CreateServicePrincipal) {
    Write-Host "  2. service-principal skill - Creates Service Principal with RBAC" -ForegroundColor Gray
}
if ($CreateAIProjects) {
    Write-Host "  3. ai-foundry-resources skilllor Gray
Write-Host ""
Write-Host "This orchestration script will execute specialized skills:" -ForegroundColor Cyan
Write-Host "  1. create-resource-groups.ps1 - Creates resource groups" -ForegroundColor Gray
if ($CreateServicePrincipal) {
    Write-Host "  2. create-service-principal.ps1 - Creates Service Principal with RBAC" -ForegroundColor Gray
}
if ($CreateAIProjects) {
    Write-Host "[Step 1: Resource Groups Skill]" -ForegroundColor Yellow
    Write-Host ""
    
    $rgParams = @{
        ResourceGroupBaseName = $ResourceGroupBaseName
        Location              = $Location
        Environment           = $Environment
        OutputFormat          = 'text'
    }
    
    if ($UseConfig) {
        $rgParams.UseConfig = $true
    }
    
    try {
        & "$PSScriptRoot/../resource-groups/scripts/create-resource-groups.ps1" @rgParams
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Resource Groups skill completed successfully" -ForegroundColor Green
            $results.Skills += @{ Name = "resource-groups"; Status = "Success" }
            $results.Summary.Succeeded++
        }
        else {
            Write-Host "  ❌ Resource Groups skill failed" -ForegroundColor Red
            $results.Skills += @{ Name = "resource-groups"; Status = "Failed" }
            $results.Summary.Failed++
        }
    }
    catch {
        Write-Host "  ❌ Resource Groups skill error: $_" -ForegroundColor Red
        $results.Skills += @{ Name = "resource-groups"; Status = "Failed"; Error = $_.Exception.Message }
        $results.Summary.Failed++
            Add-ResourceResult -Tracker $results -ResourceType "Orchestration" -ResourceName "Resource Groups" -Status "Failed" -Message "Resource group creation failed with exit code $LASTEXITCODE"
        }Host "[Step 2: Service Principal Skill]" -ForegroundColor Yellow
        Write-Host ""
        
        $spParams = @{
            ServicePrincipalName  = $ServicePrincipalName
            ResourceGroupBaseName = $ResourceGroupBaseName
            Environment           = $Environment
            UpdateConfig          = $true
            OutputFormat          = 'text'
        }
        
        if ($UseConfig) {
            $spParams.UseConfig = $true
        }
        
        try {
            & "$PSScriptRoot/../service-principal/scripts/create-service-principal.ps1" @spParams
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Service Principal skill completed successfully" -ForegroundColor Green
                $results.Skills += @{ Name = "service-principal"; Status = "Success" }
                $results.Summary.Succeeded++
            }
            else {
                Write-Host "  ⚠️  Service Principal skill completed with warnings" -ForegroundColor Yellow
                $results.Skills += @{ Name = "service-principal"; Status = "Warning" }
            }
        }
        catch {
            Write-Host "  ⚠️  Service Principal skill error: $_" -ForegroundColor Yellow
            $results.Skills += @{ Name = "service-principal"; Status = "Warning"; Error = $_.Exception.Message }
            & "$PSScriptRoot/create-service-principal.ps1" @spParams
            if ($LASTEXITCODE -eq 0) {
                Add-ResourceResult -Tracker $results -ResourceType "Orchestration" -ResourceName "Service Principal" -Status "Created" -Message "Service Principal created successfully"
            }
            elHost "[Step 3: AI Foundry Resources Skill]" -ForegroundColor Yellow
        Write-Host ""
        
        # Get Service Principal AppId if available
        $spAppId = $null
        if ($config -and $config.servicePrincipal.appId -and $config.servicePrincipal.appId -ne '00000000-0000-0000-0000-000000000000') {
            $spAppId = $config.servicePrincipal.appId
        }
        
        $aifParams = @{
            ResourceGroupBaseName = $ResourceGroupBaseName
            AIProjectBaseName     = $AIProjectBaseName
            Location              = $Location
            Environment           = $Environment
            UpdateConfig          = $true
            OutputFormat          = 'text'
        }
        
        if ($UseConfig) {
            $aifParams.UseConfig = $true
        }
        
        if ($spAppId) {
            $aifParams.ServicePrincipalAppId = $spAppId
        }
        
        try {
            & "$PSScriptRoot/../ai-foundry-resources/scripts/create-ai-foundry-resources.ps1" @aifParams
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ AI Foundry Resources skill completed successfully" -ForegroundColor Green
                $results.Skills += @{ Name = "ai-foundry-resources"; Status = "Success" }
                $results.Summary.Succeeded++
            }
            else {
                Write-Host "  ❌ AI Foundry Resources skill failed" -ForegroundColor Red
                $results.Skills += @{ Name = "ai-foundry-resources"; Status = "Failed" }
                $results.Summary.Failed++
            }
        }
        catch {
            Write-Host "  ❌ AI Foundry Resources skill error: $_" -ForegroundColor Red
            $results.Skills += @{ Name = "ai-foundry-resources"; Status = "Failed"; Error = $_.Exception.Message }
            $results.Summary.Failed++
        }
        
        try {
          Host "=== Orchestration Summary ===" -ForegroundColor Cyan
    Write-Host "Skills Succeeded: $($results.Summary.Succeeded)" -ForegroundColor Green
    Write-Host "Skills Failed: $($results.Summary.Failed)" -ForegroundColor $(if ($results.Summary.Failed -gt 0) { "Red" } else { "Gray" })
    Write-Host ""
    
    if ($results.Skills.Count -gt 0) {
        Write-Host "Skill Execution Details:" -ForegroundColor Gray
        foreach ($skill in $results.Skills) {
            $icon = switch ($skill.Status) {
                'Success' { "✅" }
                'Warning' { "⚠️ " }
                'Failed'  { "❌" }
            }
            $color = switch ($skill.Status) {
                'Success' { "Green" }
                'Warning' { "Yellow" }
                'Failed'  { "Red" }
            }
            Write-Host "  $icon $($skill.Name): $($skill.Status)" -ForegroundColor $color
        }
        Write-Host ""
    }

    # Output in requested format
    if ($OutputFormat -eq 'json') {
        $results | ConvertTo-Json -Depth 10
    }

    # Exit with appropriate code
    if ($results.Summary.Failed -gt 0) {
        Write-Host "❌ Resource creation orchestration completed with failures" -ForegroundColor Red
        exit 1
    }
    elseif ($results.Summary.Succeeded -gt 0) {
        Write-Host "✅ Resource creation orchestration completed successfully" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "✅ All operations completed" -ForegroundColor Green
    # ===== SUMMARY =====
    Write-ResultSummary -Tracker $results -ShowDetails

    # Output in requested format
    if ($OutputFormat -eq 'json') {
        ConvertTo-JsonOutput -Object $results
    }

    # Exit with appropriate code
    if ($results.Summary.Failed -gt 0 -and $results.Summary.Created -eq 0) {
        Write-StatusMessage "Resource creation orchestration failed" -Status Error -Indent 0
        exit 1
    }
    elseif ($results.Summary.Created -gt 0) {
        Write-StatusMessage "Resource creation orchestration completed successfully" -Status Success -Indent 0
        exit 0
    }
    else {
        Write-StatusMessage "All resources already exist or operations were skipped" -Status Info -Indent 0
        exit 0
    }
}
catch {
    Write-Error "Resource creation orchestration error: $_"
    exit 2
}
