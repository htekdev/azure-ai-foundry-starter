#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates environment prerequisites for Azure DevOps repository migration.

.DESCRIPTION
    This script validates that all required tools, authentication, connectivity,
    and resources are properly configured for executing the Azure DevOps migration
    process defined in COPILOT_EXECUTION_GUIDE.md.
    
    Can load configuration from migration-config.json or accept parameters directly.

.PARAMETER UseConfig
    Load configuration from migration-config.json file

.PARAMETER OrganizationUrl
    Azure DevOps organization URL (e.g., https://dev.azure.com/YOUR_ORG)

.PARAMETER ProjectName
    Azure DevOps project name

.PARAMETER ResourceGroup
    Azure resource group name (optional, for resource validation)

.PARAMETER MLWorkspace
    Azure Machine Learning workspace name (optional, for resource validation)

.PARAMETER OpenAIService
    Azure OpenAI service name (optional, for resource validation)

.PARAMETER OutputFormat
    Output format: 'text' (default) or 'json'

.PARAMETER MinimumTokenMinutes
    Minimum required token validity in minutes (default: 30)

.EXAMPLE
    ./validation-script.ps1 -OrganizationUrl "https://dev.azure.com/northwind" -ProjectName "migration-project"

.EXAMPLE
    ./validation-script.ps1 -OrganizationUrl "https://dev.azure.com/northwind" -ProjectName "migration-project" -OutputFormat json

.NOTES
    Exit codes:
    0 = All validations passed
    1 = One or more validations failed
    2 = Script error
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$UseConfig,

    [Parameter(Mandatory = $false)]
    [string]$OrganizationUrl,

    [Parameter(Mandatory = $false)]
    [string]$ProjectName,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$MLWorkspace,

    [Parameter(Mandatory = $false)]
    [string]$OpenAIService,

    [Parameter(Mandatory = $false)]
    [ValidateSet('text', 'json')]
    [string]$OutputFormat = 'text',

    [Parameter(Mandatory = $false)]
    [int]$MinimumTokenMinutes = 30
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'

# Ensure Azure CLI is in PATH
$azCliPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
if ((Test-Path $azCliPath) -and ($env:Path -notlike "*$azCliPath*")) {
    $env:Path += ";$azCliPath"
    Write-Verbose "Added Azure CLI to PATH"
}

# Ensure Git is in PATH
$gitPath = "C:\Program Files\Git\cmd"
if ((Test-Path $gitPath) -and ($env:Path -notlike "*$gitPath*")) {
    $env:Path += ";$gitPath"
    Write-Verbose "Added Git to PATH"
}

# Load configuration if UseConfig is specified
if ($UseConfig) {
    . "$PSScriptRoot/../configuration-management/config-functions.ps1"
    $config = Get-MigrationConfig
    
    if ($config) {
        $OrganizationUrl = $config.azureDevOps.organizationUrl
        $ProjectName = $config.azureDevOps.projectName
        $ResourceGroup = $config.azure.resourceGroupName
        $MLWorkspace = $config.azure.mlWorkspaceName
        $OpenAIService = $config.azure.openAIServiceName
        
        Write-Host "✅ Loaded configuration from migration-config.json" -ForegroundColor Green
    }
    else {
        Write-Warning "Could not load configuration. Run: ../configuration-management/configure-migration.ps1 -Interactive"
        Write-Host "Continuing with provided parameters..." -ForegroundColor Yellow
    }
}

# Validation results
$results = @{
    Timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Tools          = @{}
    Authentication = @{}
    Connectivity   = @{}
    Resources      = @{}
    Summary        = @{
        Status   = 'UNKNOWN'
        Passes   = 0
        Warnings = 0
        Failures = 0
    }
}

# Helper function to add validation result
function Add-ValidationResult {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Status,  # PASS, WARNING, FAIL
        [string]$Value,
        [string]$Expected,
        [string]$Message
    )

    $results[$Category][$Name] = @{
        Status   = $Status
        Value    = $Value
        Expected = $Expected
        Message  = $Message
    }

    switch ($Status) {
        'PASS' { $results.Summary.Passes++ }
        'WARNING' { $results.Summary.Warnings++ }
        'FAIL' { $results.Summary.Failures++ }
    }
}

# Helper function to format output
function Format-Output {
    param([hashtable]$Data)

    if ($OutputFormat -eq 'json') {
        return $Data | ConvertTo-Json -Depth 10
    }

    # Text format
    $output = @()
    $output += "=== Environment Validation Report ==="
    $output += "Generated: $($Data.Timestamp)"
    $output += ""

    foreach ($category in @('Tools', 'Authentication', 'Connectivity', 'Resources')) {
        if ($Data[$category].Count -gt 0) {
            $output += "[$category]"
            foreach ($item in $Data[$category].GetEnumerator()) {
                $icon = switch ($item.Value.Status) {
                    'PASS' { '✅' }
                    'WARNING' { '⚠️ ' }
                    'FAIL' { '❌' }
                    default { '⚪' }
                }
                $line = "$icon $($item.Key): $($item.Value.Value)"
                if ($item.Value.Expected) {
                    $line += " (Required: $($item.Value.Expected))"
                }
                if ($item.Value.Message) {
                    $line += " - $($item.Value.Message)"
                }
                $output += $line
            }
            $output += ""
        }
    }

    $output += "[Summary]"
    $statusIcon = if ($Data.Summary.Failures -eq 0) { '✅' } else { '❌' }
    $output += "Status: $($Data.Summary.Status) $statusIcon"
    $output += "Passes: $($Data.Summary.Passes)"
    $output += "Warnings: $($Data.Summary.Warnings)"
    $output += "Failures: $($Data.Summary.Failures)"
    $output += ""

    if ($Data.Summary.Failures -eq 0) {
        $output += "✅ You can proceed with the migration process."
        $output += "For detailed instructions, see COPILOT_EXECUTION_GUIDE.md"
    }
    else {
        $output += "❌ Please address the failures above before proceeding."
        $output += "See SKILL.md for troubleshooting guidance."
    }

    return $output -join "`n"
}

# Start validation
Write-Host "Starting environment validation..." -ForegroundColor Cyan
Write-Host ""

try {
    # ===== TOOL VALIDATION =====
    Write-Host "Validating tools..." -ForegroundColor Yellow

    # Git
    try {
        $gitVersion = (git --version 2>$null) -replace 'git version ', ''
        $gitVersionParts = $gitVersion.Split('.')
        $gitMajor = [int]$gitVersionParts[0]
        $gitMinor = [int]$gitVersionParts[1]
        
        if ($gitMajor -gt 2 -or ($gitMajor -eq 2 -and $gitMinor -ge 30)) {
            Add-ValidationResult -Category 'Tools' -Name 'Git' -Status 'PASS' -Value $gitVersion -Expected '2.30+' -Message 'OK'
        }
        else {
            Add-ValidationResult -Category 'Tools' -Name 'Git' -Status 'FAIL' -Value $gitVersion -Expected '2.30+' -Message 'Version too old'
        }
    }
    catch {
        Add-ValidationResult -Category 'Tools' -Name 'Git' -Status 'FAIL' -Value 'Not found' -Expected '2.30+' -Message 'Not installed'
    }

    # Azure CLI
    try {
        $azVersion = (az version --only-show-errors 2>$null | ConvertFrom-Json).'azure-cli'
        $azVersionParts = $azVersion.Split('.')
        $azMajor = [int]$azVersionParts[0]
        $azMinor = [int]$azVersionParts[1]
        
        if ($azMajor -gt 2 -or ($azMajor -eq 2 -and $azMinor -ge 50)) {
            Add-ValidationResult -Category 'Tools' -Name 'Azure CLI' -Status 'PASS' -Value $azVersion -Expected '2.50+' -Message 'OK'
        }
        else {
            Add-ValidationResult -Category 'Tools' -Name 'Azure CLI' -Status 'FAIL' -Value $azVersion -Expected '2.50+' -Message 'Version too old'
        }
    }
    catch {
        Add-ValidationResult -Category 'Tools' -Name 'Azure CLI' -Status 'FAIL' -Value 'Not found' -Expected '2.50+' -Message 'Not installed'
    }

    # PowerShell
    try {
        $psVersion = $PSVersionTable.PSVersion.ToString()
        $psMajor = $PSVersionTable.PSVersion.Major
        $psMinor = $PSVersionTable.PSVersion.Minor
        
        if ($psMajor -gt 5 -or ($psMajor -eq 5 -and $psMinor -ge 1)) {
            Add-ValidationResult -Category 'Tools' -Name 'PowerShell' -Status 'PASS' -Value $psVersion -Expected '5.1+' -Message 'OK'
        }
        else {
            Add-ValidationResult -Category 'Tools' -Name 'PowerShell' -Status 'FAIL' -Value $psVersion -Expected '5.1+' -Message 'Version too old'
        }
    }
    catch {
        Add-ValidationResult -Category 'Tools' -Name 'PowerShell' -Status 'FAIL' -Value 'Unknown' -Expected '5.1+' -Message 'Cannot determine version'
    }

    # Python
    try {
        $pythonVersion = (python --version 2>$null) -replace 'Python ', ''
        $pythonVersionParts = $pythonVersion.Split('.')
        $pythonMajor = [int]$pythonVersionParts[0]
        $pythonMinor = [int]$pythonVersionParts[1]
        
        if ($pythonMajor -gt 3 -or ($pythonMajor -eq 3 -and $pythonMinor -ge 8)) {
            Add-ValidationResult -Category 'Tools' -Name 'Python' -Status 'PASS' -Value $pythonVersion -Expected '3.8+' -Message 'OK'
        }
        else {
            Add-ValidationResult -Category 'Tools' -Name 'Python' -Status 'WARNING' -Value $pythonVersion -Expected '3.8+' -Message 'Version too old (optional for basic migration)'
        }
    }
    catch {
        Add-ValidationResult -Category 'Tools' -Name 'Python' -Status 'WARNING' -Value 'Not found' -Expected '3.8+' -Message 'Optional for basic migration'
    }

    # Azure DevOps Extension
    try {
        $extensions = az extension list --only-show-errors 2>$null | ConvertFrom-Json
        $devopsExt = $extensions | Where-Object { $_.name -eq 'azure-devops' }
        
        if ($devopsExt) {
            Add-ValidationResult -Category 'Tools' -Name 'Azure DevOps Extension' -Status 'PASS' -Value $devopsExt.version -Expected 'Latest' -Message 'Installed'
        }
        else {
            Add-ValidationResult -Category 'Tools' -Name 'Azure DevOps Extension' -Status 'FAIL' -Value 'Not found' -Expected 'Latest' -Message 'Not installed'
        }
    }
    catch {
        Add-ValidationResult -Category 'Tools' -Name 'Azure DevOps Extension' -Status 'FAIL' -Value 'Unknown' -Expected 'Latest' -Message 'Cannot verify'
    }

    # ===== AUTHENTICATION VALIDATION =====
    Write-Host "Validating authentication..." -ForegroundColor Yellow

    # Azure Login Status
    try {
        $accountJson = az account show --only-show-errors 2>&1
        if ($LASTEXITCODE -eq 0) {
            $account = $accountJson | ConvertFrom-Json
            if ($account) {
                Add-ValidationResult -Category 'Authentication' -Name 'Azure Login' -Status 'PASS' -Value $account.user.name -Expected 'Authenticated' -Message "Subscription: $($account.name)"
            }
            else {
                Add-ValidationResult -Category 'Authentication' -Name 'Azure Login' -Status 'FAIL' -Value 'Not authenticated' -Expected 'Authenticated' -Message 'Run: az login'
            }
        }
        else {
            Add-ValidationResult -Category 'Authentication' -Name 'Azure Login' -Status 'FAIL' -Value 'Not authenticated' -Expected 'Authenticated' -Message 'Run: az login'
        }
    }
    catch {
        Add-ValidationResult -Category 'Authentication' -Name 'Azure Login' -Status 'FAIL' -Value 'Not authenticated' -Expected 'Authenticated' -Message 'Run: az login'
    }

    # Bearer Token
    try {
        $tokenJson = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --only-show-errors 2>&1
        if ($LASTEXITCODE -eq 0) {
            $token = $tokenJson | ConvertFrom-Json
            # Set as environment variable for Azure DevOps CLI
            $env:AZURE_DEVOPS_EXT_PAT = $token.accessToken
            Write-Verbose "Set AZURE_DEVOPS_EXT_PAT environment variable"
            $expiresOn = [DateTime]::Parse($token.expiresOn)
            $minutesRemaining = [math]::Round(($expiresOn - (Get-Date)).TotalMinutes)
            
            if ($minutesRemaining -ge $MinimumTokenMinutes) {
                Add-ValidationResult -Category 'Authentication' -Name 'Bearer Token' -Status 'PASS' -Value "Valid (expires in $minutesRemaining minutes)" -Expected "$MinimumTokenMinutes+ minutes" -Message 'OK'
            }
            elseif ($minutesRemaining -gt 0) {
                Add-ValidationResult -Category 'Authentication' -Name 'Bearer Token' -Status 'WARNING' -Value "Valid (expires in $minutesRemaining minutes)" -Expected "$MinimumTokenMinutes+ minutes" -Message 'Token will expire soon'
            }
            else {
                Add-ValidationResult -Category 'Authentication' -Name 'Bearer Token' -Status 'FAIL' -Value 'Expired' -Expected "$MinimumTokenMinutes+ minutes" -Message 'Refresh token'
            }
        }
        else {
            Add-ValidationResult -Category 'Authentication' -Name 'Bearer Token' -Status 'FAIL' -Value 'Not available' -Expected "$MinimumTokenMinutes+ minutes" -Message 'Cannot obtain token'
        }
    }
    catch {
        Add-ValidationResult -Category 'Authentication' -Name 'Bearer Token' -Status 'FAIL' -Value 'Error' -Expected "$MinimumTokenMinutes+ minutes" -Message $_.Exception.Message
    }

    # ===== CONNECTIVITY VALIDATION =====
    if ($OrganizationUrl -and $ProjectName) {
        Write-Host "Validating Azure DevOps connectivity..." -ForegroundColor Yellow

        # Organization Access
        try {
            Write-Verbose "Testing connection to $OrganizationUrl"
            $projectsJson = az devops project list --organization $OrganizationUrl --only-show-errors 2>&1
            if ($LASTEXITCODE -eq 0) {
                $projects = $projectsJson | ConvertFrom-Json
                if ($projects) {
                    Add-ValidationResult -Category 'Connectivity' -Name 'Organization Access' -Status 'PASS' -Value $OrganizationUrl -Expected 'Accessible' -Message "$($projects.Count) projects found"
                }
                else {
                    Add-ValidationResult -Category 'Connectivity' -Name 'Organization Access' -Status 'FAIL' -Value $OrganizationUrl -Expected 'Accessible' -Message 'Cannot list projects'
                }
            }
            else {
                Add-ValidationResult -Category 'Connectivity' -Name 'Organization Access' -Status 'FAIL' -Value $OrganizationUrl -Expected 'Accessible' -Message 'Cannot connect to organization'
            }
        }
        catch {
            Add-ValidationResult -Category 'Connectivity' -Name 'Organization Access' -Status 'FAIL' -Value $OrganizationUrl -Expected 'Accessible' -Message $_.Exception.Message
        }

        # Project Access
        try {
            $project = az devops project show --project $ProjectName --organization $OrganizationUrl --only-show-errors 2>$null | ConvertFrom-Json
            if ($project) {
                Add-ValidationResult -Category 'Connectivity' -Name 'Project Access' -Status 'PASS' -Value $ProjectName -Expected 'Accessible' -Message "ID: $($project.id)"
            }
            else {
                Add-ValidationResult -Category 'Connectivity' -Name 'Project Access' -Status 'FAIL' -Value $ProjectName -Expected 'Accessible' -Message 'Project not found'
            }
        }
        catch {
            Add-ValidationResult -Category 'Connectivity' -Name 'Project Access' -Status 'FAIL' -Value $ProjectName -Expected 'Accessible' -Message $_.Exception.Message
        }

        # Repository List
        try {
            $repos = az repos list --organization $OrganizationUrl --project $ProjectName --only-show-errors 2>$null | ConvertFrom-Json
            if ($repos) {
                Add-ValidationResult -Category 'Connectivity' -Name 'Repository List' -Status 'PASS' -Value "$($repos.Count) repositories" -Expected 'Accessible' -Message 'OK'
            }
            else {
                Add-ValidationResult -Category 'Connectivity' -Name 'Repository List' -Status 'WARNING' -Value '0 repositories' -Expected 'Accessible' -Message 'No repositories found'
            }
        }
        catch {
            Add-ValidationResult -Category 'Connectivity' -Name 'Repository List' -Status 'FAIL' -Value 'Error' -Expected 'Accessible' -Message $_.Exception.Message
        }

        # Pipeline List
        try {
            $pipelines = az pipelines list --organization $OrganizationUrl --project $ProjectName --only-show-errors 2>$null | ConvertFrom-Json
            if ($pipelines) {
                Add-ValidationResult -Category 'Connectivity' -Name 'Pipeline List' -Status 'PASS' -Value "$($pipelines.Count) pipelines" -Expected 'Accessible' -Message 'OK'
            }
            else {
                Add-ValidationResult -Category 'Connectivity' -Name 'Pipeline List' -Status 'WARNING' -Value '0 pipelines' -Expected 'Accessible' -Message 'No pipelines found'
            }
        }
        catch {
            Add-ValidationResult -Category 'Connectivity' -Name 'Pipeline List' -Status 'FAIL' -Value 'Error' -Expected 'Accessible' -Message $_.Exception.Message
        }
    }
    else {
        Write-Host "Skipping connectivity validation (OrganizationUrl and ProjectName not provided)" -ForegroundColor Gray
    }

    # ===== RESOURCE VALIDATION =====
    if ($ResourceGroup) {
        Write-Host "Validating Azure resources..." -ForegroundColor Yellow

        # Resource Group
        try {
            $rg = az group show --name $ResourceGroup --only-show-errors 2>$null | ConvertFrom-Json
            if ($rg) {
                Add-ValidationResult -Category 'Resources' -Name 'Resource Group' -Status 'PASS' -Value "$ResourceGroup ($($rg.location))" -Expected 'Exists' -Message 'OK'
            }
            else {
                Add-ValidationResult -Category 'Resources' -Name 'Resource Group' -Status 'FAIL' -Value $ResourceGroup -Expected 'Exists' -Message 'Not found'
            }
        }
        catch {
            Add-ValidationResult -Category 'Resources' -Name 'Resource Group' -Status 'FAIL' -Value $ResourceGroup -Expected 'Exists' -Message $_.Exception.Message
        }

        # ML Workspace
        if ($MLWorkspace) {
            try {
                # Check if ML extension is installed
                $extensions = az extension list --only-show-errors 2>$null | ConvertFrom-Json
                $mlExt = $extensions | Where-Object { $_.name -eq 'ml' }
                
                if ($mlExt) {
                    # Use resource list to check if workspace exists (faster than show)
                    $workspaceJson = az resource list --resource-group $ResourceGroup --resource-type "Microsoft.MachineLearningServices/workspaces" --name $MLWorkspace --only-show-errors 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $workspace = $workspaceJson | ConvertFrom-Json
                        if ($workspace -and $workspace.Count -gt 0) {
                            Add-ValidationResult -Category 'Resources' -Name 'ML Workspace' -Status 'PASS' -Value $MLWorkspace -Expected 'Exists' -Message 'OK'
                        }
                        else {
                            Add-ValidationResult -Category 'Resources' -Name 'ML Workspace' -Status 'WARNING' -Value $MLWorkspace -Expected 'Exists' -Message 'Not found (will be created)'
                        }
                    }
                    else {
                        Add-ValidationResult -Category 'Resources' -Name 'ML Workspace' -Status 'WARNING' -Value $MLWorkspace -Expected 'Exists' -Message 'Cannot verify (will be created)'
                    }
                }
                else {
                    Add-ValidationResult -Category 'Resources' -Name 'ML Workspace' -Status 'WARNING' -Value $MLWorkspace -Expected 'Exists' -Message 'ML extension not installed (will be created)'
                }
            }
            catch {
                Add-ValidationResult -Category 'Resources' -Name 'ML Workspace' -Status 'WARNING' -Value $MLWorkspace -Expected 'Exists' -Message 'Cannot verify (will be created)'
            }
        }

        # OpenAI Service
        if ($OpenAIService) {
            try {
                # Use resource list (faster and doesn't hang)
                $openaiJson = az resource list --resource-group $ResourceGroup --resource-type "Microsoft.CognitiveServices/accounts" --name $OpenAIService --only-show-errors 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $openai = $openaiJson | ConvertFrom-Json
                    if ($openai -and $openai.Count -gt 0) {
                        Add-ValidationResult -Category 'Resources' -Name 'OpenAI Service' -Status 'PASS' -Value $OpenAIService -Expected 'Exists' -Message 'OK'
                    }
                    else {
                        Add-ValidationResult -Category 'Resources' -Name 'OpenAI Service' -Status 'WARNING' -Value $OpenAIService -Expected 'Exists' -Message 'Not found (will be created)'
                    }
                }
                else {
                    Add-ValidationResult -Category 'Resources' -Name 'OpenAI Service' -Status 'WARNING' -Value $OpenAIService -Expected 'Exists' -Message 'Cannot verify (will be created)'
                }
            }
            catch {
                Add-ValidationResult -Category 'Resources' -Name 'OpenAI Service' -Status 'WARNING' -Value $OpenAIService -Expected 'Exists' -Message 'Cannot verify (will be created)'
            }
        }
    }
    else {
        Write-Host "Skipping resource validation (ResourceGroup not provided)" -ForegroundColor Gray
    }

    # ===== SUMMARY =====
    if ($results.Summary.Failures -eq 0 -and $results.Summary.Warnings -eq 0) {
        $results.Summary.Status = 'READY'
    }
    elseif ($results.Summary.Failures -eq 0) {
        $results.Summary.Status = 'READY WITH WARNINGS'
    }
    else {
        $results.Summary.Status = 'NOT READY'
    }

    # Output results
    Write-Host ""
    Write-Host (Format-Output -Data $results)

    # Exit with appropriate code
    if ($results.Summary.Failures -gt 0) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-Error "Validation script error: $_"
    exit 2
}
