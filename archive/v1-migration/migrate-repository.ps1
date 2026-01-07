<# 
.SYNOPSIS
    Complete repository migration script for foundrycicdbasic to Azure DevOps

.DESCRIPTION
    This PowerShell script automates the entire migration process:
    1. Clones source repository from GitHub
    2. Reorganizes directory structure
    3. Creates Azure DevOps repository via REST API
    4. Pushes reorganized code
    5. Configures service connections, variable groups, and pipelines

.PARAMETER Organization
    Azure DevOps organization name

.PARAMETER Project
    Azure DevOps project name

.PARAMETER RepositoryName
    Name for the new repository (default: foundry-cicd)

.PARAMETER SourceRepoUrl
    GitHub repository URL to clone (default: https://github.com/balakreshnan/foundrycicdbasic.git)

.PARAMETER WorkspacePath
    Local workspace path for migration (default: C:\Repos\northwind-systems\migration-workspace)

.PARAMETER DryRun
    If specified, performs validation only without making changes

.EXAMPLE
    .\migrate-repository.ps1 -Organization "myorg" -Project "myproject"

.EXAMPLE
    .\migrate-repository.ps1 -Organization "myorg" -Project "myproject" -DryRun

.NOTES
    Version: 1.0
    Author: DevOps Migration Team
    Date: January 7, 2026
    Requires: PowerShell 7+, Git, Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Organization,
    
    [Parameter(Mandatory=$true)]
    [string]$Project,
    
    [Parameter(Mandatory=$false)]
    [string]$RepositoryName = "foundry-cicd",
    
    [Parameter(Mandatory=$false)]
    [string]$SourceRepoUrl = "https://github.com/balakreshnan/foundrycicdbasic.git",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkspacePath = "C:\Repos\northwind-systems\migration-workspace",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# ===========================
# SCRIPT CONFIGURATION
# ===========================

$ErrorActionPreference = "Stop"
$script:LogFile = Join-Path $WorkspacePath "migration-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:ErrorCount = 0
$script:WarningCount = 0

# ===========================
# LOGGING FUNCTIONS
# ===========================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console with colors
    switch ($Level) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { 
            Write-Host $logMessage -ForegroundColor Yellow
            $script:WarningCount++
        }
        "ERROR" { 
            Write-Host $logMessage -ForegroundColor Red
            $script:ErrorCount++
        }
        default { Write-Host $logMessage }
    }
    
    # Write to log file
    Add-Content -Path $script:LogFile -Value $logMessage
}

function Write-Progress-Custom {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    Write-Log "Progress: $Status ($PercentComplete%)"
}

# ===========================
# PREREQUISITE CHECKS
# ===========================

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    $allGood = $true
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "PowerShell 7+ is required. Current version: $($PSVersionTable.PSVersion)" -Level ERROR
        $allGood = $false
    } else {
        Write-Log "✓ PowerShell version: $($PSVersionTable.PSVersion)" -Level SUCCESS
    }
    
    # Check Git
    try {
        $gitVersion = git --version
        Write-Log "✓ Git installed: $gitVersion" -Level SUCCESS
    } catch {
        Write-Log "Git is not installed or not in PATH" -Level ERROR
        $allGood = $false
    }
    
    # Check Azure CLI
    try {
        $azVersion = az --version 2>&1 | Select-Object -First 1
        Write-Log "✓ Azure CLI installed" -Level SUCCESS
    } catch {
        Write-Log "Azure CLI is not installed or not in PATH" -Level ERROR
        $allGood = $false
    }
    
    # Check environment variables
    $requiredEnvVars = @(
        "AZURE_DEVOPS_PAT",
        "AZURE_CLIENT_ID",
        "AZURE_CLIENT_SECRET",
        "AZURE_TENANT_ID",
        "AZURE_SUBSCRIPTION_ID"
    )
    
    foreach ($envVar in $requiredEnvVars) {
        if ([string]::IsNullOrEmpty((Get-Item -Path "Env:$envVar" -ErrorAction SilentlyContinue).Value)) {
            Write-Log "$envVar environment variable is not set" -Level WARNING
        } else {
            Write-Log "✓ $envVar is set" -Level SUCCESS
        }
    }
    
    return $allGood
}

# ===========================
# API HELPER FUNCTIONS
# ===========================

function Get-AzureDevOpsHeaders {
    $pat = $env:AZURE_DEVOPS_PAT
    if ([string]::IsNullOrEmpty($pat)) {
        throw "AZURE_DEVOPS_PAT environment variable is not set"
    }
    
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
    return @{
        Authorization = "Basic $base64AuthInfo"
        "Content-Type" = "application/json"
    }
}

function Invoke-AzureDevOpsApi {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [object]$Body = $null
    )
    
    try {
        $headers = Get-AzureDevOpsHeaders
        
        $params = @{
            Uri = $Uri
            Method = $Method
            Headers = $headers
        }
        
        if ($Body -and $Method -ne "GET") {
            $params["Body"] = ($Body | ConvertTo-Json -Depth 10)
            $params["ContentType"] = "application/json"
        }
        
        if ($DryRun) {
            Write-Log "[DRY RUN] Would call API: $Method $Uri" -Level INFO
            return $null
        }
        
        $response = Invoke-RestMethod @params
        return $response
    } catch {
        Write-Log "API call failed: $($_.Exception.Message)" -Level ERROR
        Write-Log "Response: $($_.ErrorDetails.Message)" -Level ERROR
        throw
    }
}

# ===========================
# PHASE 1: PREPARATION
# ===========================

function Initialize-Workspace {
    Write-Progress-Custom -Activity "Migration" -Status "Initializing workspace" -PercentComplete 5
    
    Write-Log "Creating workspace directory: $WorkspacePath"
    if (-not (Test-Path $WorkspacePath)) {
        New-Item -ItemType Directory -Path $WorkspacePath -Force | Out-Null
    }
    
    Set-Location $WorkspacePath
    Write-Log "✓ Workspace initialized" -Level SUCCESS
}

function Backup-ExistingRepository {
    param([string]$RepoPath)
    
    Write-Progress-Custom -Activity "Migration" -Status "Creating backup" -PercentComplete 10
    
    if (Test-Path $RepoPath) {
        $backupName = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        $backupPath = Join-Path $WorkspacePath $backupName
        
        Write-Log "Creating backup: $backupPath"
        Copy-Item -Path $RepoPath -Destination $backupPath -Recurse
        
        # Create archive
        $archivePath = "$backupPath.zip"
        Compress-Archive -Path $backupPath -DestinationPath $archivePath
        
        Write-Log "✓ Backup created: $archivePath" -Level SUCCESS
    }
}

function Clone-SourceRepository {
    Write-Progress-Custom -Activity "Migration" -Status "Cloning source repository" -PercentComplete 15
    
    $repoPath = Join-Path $WorkspacePath "source-repo"
    
    if (Test-Path $repoPath) {
        Write-Log "Source repository already exists. Backing up..." -Level WARNING
        Backup-ExistingRepository -RepoPath $repoPath
        Remove-Item -Path $repoPath -Recurse -Force
    }
    
    Write-Log "Cloning from: $SourceRepoUrl"
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would clone repository" -Level INFO
        return $repoPath
    }
    
    git clone $SourceRepoUrl $repoPath 2>&1 | ForEach-Object { Write-Log $_ }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Git clone failed with exit code $LASTEXITCODE"
    }
    
    Write-Log "✓ Repository cloned successfully" -Level SUCCESS
    return $repoPath
}

# ===========================
# PHASE 2: REORGANIZATION
# ===========================

function New-DirectoryStructure {
    param([string]$RepoPath)
    
    Write-Progress-Custom -Activity "Migration" -Status "Creating new directory structure" -PercentComplete 25
    
    $directories = @(
        ".azure-pipelines",
        ".azure-pipelines/templates",
        "config",
        "docs/getting-started",
        "docs/architecture",
        "docs/guides",
        "docs/cicd",
        "docs/api",
        "src",
        "src/agents",
        "src/evaluation",
        "src/security",
        "src/utils",
        "scripts/setup",
        "scripts/deployment",
        "scripts/utilities",
        "tests/unit",
        "tests/integration",
        "tests/fixtures",
        "examples/basic-agent",
        "examples/advanced-agent",
        "tools/migration"
    )
    
    Set-Location $RepoPath
    
    foreach ($dir in $directories) {
        $fullPath = Join-Path $RepoPath $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            Write-Log "Created directory: $dir"
        }
    }
    
    Write-Log "✓ Directory structure created" -Level SUCCESS
}

function Move-Files {
    param([string]$RepoPath)
    
    Write-Progress-Custom -Activity "Migration" -Status "Reorganizing files" -PercentComplete 35
    
    Set-Location $RepoPath
    
    # File moves mapping
    $fileMoves = @(
        @{Source="createagent.py"; Destination="src/agents/create_agent.py"},
        @{Source="exagent.py"; Destination="src/agents/test_agent.py"},
        @{Source="agenteval.py"; Destination="src/evaluation/evaluate_agent.py"},
        @{Source="redteam.py"; Destination="src/security/redteam_scan.py"},
        @{Source="redteam1.py"; Destination="src/security/redteam_advanced.py"}
    )
    
    foreach ($move in $fileMoves) {
        if (Test-Path $move.Source) {
            Move-Item -Path $move.Source -Destination $move.Destination -Force
            Write-Log "Moved: $($move.Source) → $($move.Destination)"
        } else {
            Write-Log "File not found: $($move.Source)" -Level WARNING
        }
    }
    
    # Move CI/CD files
    if (Test-Path "cicd") {
        if (Test-Path "cicd/createagentpipeline.yml") {
            Move-Item "cicd/createagentpipeline.yml" ".azure-pipelines/create-agent-pipeline.yml" -Force
        }
        if (Test-Path "cicd/agentconsumptionpipeline.yml") {
            Move-Item "cicd/agentconsumptionpipeline.yml" ".azure-pipelines/test-agent-pipeline.yml" -Force
        }
        if (Test-Path "cicd/README.md") {
            Move-Item "cicd/README.md" ".azure-pipelines/README.md" -Force
        }
        
        # Remove old cicd directory
        Remove-Item "cicd" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Reorganize docs
    $docMoves = @(
        @{Source="docs/architecture.md"; Destination="docs/architecture/overview.md"},
        @{Source="docs/createagent.md"; Destination="docs/guides/agent-creation.md"},
        @{Source="docs/exagent.md"; Destination="docs/guides/agent-testing.md"},
        @{Source="docs/agenteval.md"; Destination="docs/guides/agent-evaluation.md"},
        @{Source="docs/redteam.md"; Destination="docs/guides/security-testing.md"},
        @{Source="docs/deployment.md"; Destination="docs/cicd/deployment-overview.md"}
    )
    
    foreach ($move in $docMoves) {
        if (Test-Path $move.Source) {
            Move-Item -Path $move.Source -Destination $move.Destination -Force
            Write-Log "Moved doc: $($move.Source) → $($move.Destination)"
        }
    }
    
    Write-Log "✓ Files reorganized" -Level SUCCESS
}

function New-PythonPackageFiles {
    param([string]$RepoPath)
    
    Write-Progress-Custom -Activity "Migration" -Status "Creating Python package files" -PercentComplete 45
    
    Set-Location $RepoPath
    
    $initFiles = @(
        "src/__init__.py",
        "src/agents/__init__.py",
        "src/evaluation/__init__.py",
        "src/security/__init__.py",
        "src/utils/__init__.py",
        "tests/__init__.py",
        "tests/unit/__init__.py",
        "tests/integration/__init__.py"
    )
    
    foreach ($file in $initFiles) {
        if (-not (Test-Path $file)) {
            New-Item -ItemType File -Path $file -Force | Out-Null
            Set-Content -Path $file -Value "# Auto-generated package file"
            Write-Log "Created: $file"
        }
    }
    
    Write-Log "✓ Python package files created" -Level SUCCESS
}

function Update-ImportStatements {
    param([string]$RepoPath)
    
    Write-Progress-Custom -Activity "Migration" -Status "Updating import statements" -PercentComplete 50
    
    Set-Location $RepoPath
    
    $pythonFiles = Get-ChildItem -Path "src" -Recurse -Filter "*.py"
    
    foreach ($file in $pythonFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        $originalContent = $content
        
        # Update imports (basic patterns - may need adjustment)
        $content = $content -replace 'from createagent import', 'from src.agents.create_agent import'
        $content = $content -replace 'from exagent import', 'from src.agents.test_agent import'
        $content = $content -replace 'from agenteval import', 'from src.evaluation.evaluate_agent import'
        $content = $content -replace 'from redteam import', 'from src.security.redteam_scan import'
        
        if ($content -ne $originalContent) {
            if (-not $DryRun) {
                Set-Content -Path $file.FullName -Value $content
            }
            Write-Log "Updated imports in: $($file.Name)"
        }
    }
    
    Write-Log "✓ Import statements updated" -Level SUCCESS
}

function Update-PipelineReferences {
    param([string]$RepoPath)
    
    Write-Progress-Custom -Activity "Migration" -Status "Updating pipeline references" -PercentComplete 55
    
    Set-Location $RepoPath
    
    $pipelineFiles = Get-ChildItem -Path ".azure-pipelines" -Filter "*.yml"
    
    foreach ($file in $pipelineFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        $originalContent = $content
        
        # Update script paths
        $content = $content -replace 'createagent\.py', 'src/agents/create_agent.py'
        $content = $content -replace 'exagent\.py', 'src/agents/test_agent.py'
        $content = $content -replace 'agenteval\.py', 'src/evaluation/evaluate_agent.py'
        $content = $content -replace 'redteam\.py', 'src/security/redteam_scan.py'
        
        if ($content -ne $originalContent) {
            if (-not $DryRun) {
                Set-Content -Path $file.FullName -Value $content
            }
            Write-Log "Updated pipeline: $($file.Name)"
        }
    }
    
    Write-Log "✓ Pipeline references updated" -Level SUCCESS
}

function New-ConfigurationTemplate {
    param([string]$RepoPath)
    
    Write-Progress-Custom -Activity "Migration" -Status "Creating configuration template" -PercentComplete 60
    
    Set-Location $RepoPath
    
    $envTemplate = @"
# Azure AI Project Configuration
AZURE_AI_PROJECT=https://your-project.api.azureml.ms
AZURE_AI_PROJECT_ENDPOINT=https://your-project.api.azureml.ms

# Azure Authentication
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret

# Azure OpenAI Configuration
AZURE_OPENAI_ENDPOINT=https://your-openai.openai.azure.com/
AZURE_OPENAI_KEY=your-api-key
AZURE_OPENAI_API_VERSION=2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT=gpt-4o

# Environment
ENVIRONMENT=dev
"@

    if (-not $DryRun) {
        Set-Content -Path "config/.env.template" -Value $envTemplate
    }
    Write-Log "✓ Configuration template created" -Level SUCCESS
}

function Save-Changes {
    param([string]$RepoPath)
    
    Write-Progress-Custom -Activity "Migration" -Status "Committing changes" -PercentComplete 65
    
    Set-Location $RepoPath
    
    # Create migration branch
    git checkout -b migration/reorganize-structure 2>&1 | ForEach-Object { Write-Log $_ }
    
    # Stage all changes
    git add -A 2>&1 | ForEach-Object { Write-Log $_ }
    
    # Commit
    $commitMessage = @"
Reorganize repository structure

- Move Python scripts to src/ directory with module structure
- Reorganize CI/CD files to .azure-pipelines/
- Restructure documentation by category
- Add configuration templates
- Update import statements and pipeline references
- Create proper Python package structure
"@

    if ($DryRun) {
        Write-Log "[DRY RUN] Would commit changes" -Level INFO
    } else {
        git commit -m $commitMessage 2>&1 | ForEach-Object { Write-Log $_ }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Git commit failed"
        }
    }
    
    Write-Log "✓ Changes committed" -Level SUCCESS
}

# ===========================
# PHASE 3: AZURE DEVOPS SETUP
# ===========================

function New-AzureDevOpsRepository {
    Write-Progress-Custom -Activity "Migration" -Status "Creating Azure DevOps repository" -PercentComplete 70
    
    $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.1"
    $body = @{
        name = $RepositoryName
        project = @{
            name = $Project
        }
    }
    
    try {
        $repo = Invoke-AzureDevOpsApi -Uri $uri -Method Post -Body $body
        
        if ($repo) {
            Write-Log "✓ Repository created: $($repo.remoteUrl)" -Level SUCCESS
            return $repo
        } elseif ($DryRun) {
            Write-Log "[DRY RUN] Repository would be created" -Level INFO
            return @{ id = "dry-run-id"; remoteUrl = "https://dry-run-url" }
        }
    } catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Log "Repository already exists, retrieving..." -Level WARNING
            $getUri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryName?api-version=7.1"
            return Invoke-AzureDevOpsApi -Uri $getUri -Method Get
        }
        throw
    }
}

function Push-ToAzureDevOps {
    param(
        [string]$RepoPath,
        [string]$RemoteUrl
    )
    
    Write-Progress-Custom -Activity "Migration" -Status "Pushing to Azure DevOps" -PercentComplete 75
    
    Set-Location $RepoPath
    
    # Add Azure DevOps remote
    git remote add azure $RemoteUrl 2>&1 | ForEach-Object { Write-Log $_ }
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would push to Azure DevOps" -Level INFO
        return
    }
    
    # Push main branch
    git checkout main 2>&1 | ForEach-Object { Write-Log $_ }
    git push azure main 2>&1 | ForEach-Object { Write-Log $_ }
    
    # Push migration branch
    git checkout migration/reorganize-structure 2>&1 | ForEach-Object { Write-Log $_ }
    git push azure migration/reorganize-structure 2>&1 | ForEach-Object { Write-Log $_ }
    
    Write-Log "✓ Code pushed to Azure DevOps" -Level SUCCESS
}

function New-ServiceConnections {
    Write-Progress-Custom -Activity "Migration" -Status "Creating service connections" -PercentComplete 80
    
    $environments = @("dev", "test", "prod")
    
    foreach ($env in $environments) {
        $uri = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
        $body = @{
            name = "azure-foundry-$env"
            type = "azurerm"
            url = "https://management.azure.com/"
            description = "Azure service connection for $env environment"
            authorization = @{
                parameters = @{
                    serviceprincipalid = $env:AZURE_CLIENT_ID
                    serviceprincipalkey = $env:AZURE_CLIENT_SECRET
                    tenantid = $env:AZURE_TENANT_ID
                }
                scheme = "ServicePrincipal"
            }
            data = @{
                subscriptionId = $env:AZURE_SUBSCRIPTION_ID
                subscriptionName = "Azure Subscription"
                environment = "AzureCloud"
                scopeLevel = "Subscription"
                creationMode = "Manual"
            }
            isShared = $false
            isReady = $true
        }
        
        try {
            $sc = Invoke-AzureDevOpsApi -Uri $uri -Method Post -Body $body
            Write-Log "✓ Service connection created: azure-foundry-$env" -Level SUCCESS
        } catch {
            Write-Log "Failed to create service connection for $env : $($_.Exception.Message)" -Level WARNING
        }
    }
}

function New-VariableGroups {
    Write-Progress-Custom -Activity "Migration" -Status "Creating variable groups" -PercentComplete 85
    
    $environments = @{
        "dev" = "https://dev-project.api.azureml.ms"
        "test" = "https://test-project.api.azureml.ms"
        "prod" = "https://prod-project.api.azureml.ms"
    }
    
    foreach ($env in $environments.Keys) {
        $uri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
        $body = @{
            name = "foundry-$env-vars"
            description = "Variables for $env environment"
            type = "Vsts"
            variables = @{
                "AZURE_AI_PROJECT_$($env.ToUpper())" = @{
                    value = $environments[$env]
                    isSecret = $false
                }
                "AZURE_SERVICE_CONNECTION_$($env.ToUpper())" = @{
                    value = "azure-foundry-$env"
                    isSecret = $false
                }
                "AZURE_OPENAI_API_VERSION_$($env.ToUpper())" = @{
                    value = "2024-02-15-preview"
                    isSecret = $false
                }
                "AZURE_OPENAI_DEPLOYMENT_$($env.ToUpper())" = @{
                    value = "gpt-4o"
                    isSecret = $false
                }
            }
        }
        
        try {
            $vg = Invoke-AzureDevOpsApi -Uri $uri -Method Post -Body $body
            Write-Log "✓ Variable group created: foundry-$env-vars" -Level SUCCESS
        } catch {
            Write-Log "Failed to create variable group for $env : $($_.Exception.Message)" -Level WARNING
        }
    }
}

function New-Environments {
    Write-Progress-Custom -Activity "Migration" -Status "Creating environments" -PercentComplete 90
    
    $environments = @("dev", "test", "production")
    
    foreach ($env in $environments) {
        $uri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/environments?api-version=7.1-preview.1"
        $body = @{
            name = $env
            description = "$env environment for $RepositoryName"
        }
        
        try {
            $environment = Invoke-AzureDevOpsApi -Uri $uri -Method Post -Body $body
            Write-Log "✓ Environment created: $env" -Level SUCCESS
        } catch {
            Write-Log "Environment may already exist: $env" -Level WARNING
        }
    }
}

function New-Pipelines {
    param([string]$RepositoryId)
    
    Write-Progress-Custom -Activity "Migration" -Status "Creating pipelines" -PercentComplete 95
    
    $pipelines = @(
        @{
            name = "Foundry Agent Creation"
            path = ".azure-pipelines/create-agent-pipeline.yml"
        },
        @{
            name = "Foundry Agent Testing"
            path = ".azure-pipelines/test-agent-pipeline.yml"
        }
    )
    
    foreach ($pipeline in $pipelines) {
        $uri = "https://dev.azure.com/$Organization/$Project/_apis/pipelines?api-version=7.1-preview.1"
        $body = @{
            name = $pipeline.name
            folder = "\"
            configuration = @{
                type = "yaml"
                path = $pipeline.path
                repository = @{
                    id = $RepositoryId
                    name = $RepositoryName
                    type = "azureReposGit"
                }
            }
        }
        
        try {
            $p = Invoke-AzureDevOpsApi -Uri $uri -Method Post -Body $body
            Write-Log "✓ Pipeline created: $($pipeline.name)" -Level SUCCESS
        } catch {
            Write-Log "Failed to create pipeline $($pipeline.name): $($_.Exception.Message)" -Level WARNING
        }
    }
}

# ===========================
# MAIN EXECUTION
# ===========================

function Start-Migration {
    try {
        Write-Log "========================================" -Level INFO
        Write-Log "Repository Migration Script Starting" -Level INFO
        Write-Log "Organization: $Organization" -Level INFO
        Write-Log "Project: $Project" -Level INFO
        Write-Log "Repository: $RepositoryName" -Level INFO
        Write-Log "Dry Run: $DryRun" -Level INFO
        Write-Log "========================================" -Level INFO
        
        # Prerequisites
        if (-not (Test-Prerequisites)) {
            throw "Prerequisites check failed. Please resolve issues before continuing."
        }
        
        # Phase 1: Preparation
        Initialize-Workspace
        $repoPath = Clone-SourceRepository
        
        # Phase 2: Reorganization
        New-DirectoryStructure -RepoPath $repoPath
        Move-Files -RepoPath $repoPath
        New-PythonPackageFiles -RepoPath $repoPath
        Update-ImportStatements -RepoPath $repoPath
        Update-PipelineReferences -RepoPath $repoPath
        New-ConfigurationTemplate -RepoPath $repoPath
        Save-Changes -RepoPath $repoPath
        
        # Phase 3: Azure DevOps Setup
        $newRepo = New-AzureDevOpsRepository
        
        if (-not $DryRun) {
            Push-ToAzureDevOps -RepoPath $repoPath -RemoteUrl $newRepo.remoteUrl
            New-ServiceConnections
            New-VariableGroups
            New-Environments
            New-Pipelines -RepositoryId $newRepo.id
        }
        
        Write-Progress-Custom -Activity "Migration" -Status "Complete" -PercentComplete 100
        
        # Summary
        Write-Log "========================================" -Level SUCCESS
        Write-Log "MIGRATION COMPLETED SUCCESSFULLY!" -Level SUCCESS
        Write-Log "========================================" -Level SUCCESS
        Write-Log "Repository URL: $($newRepo.remoteUrl)" -Level SUCCESS
        Write-Log "Warnings: $script:WarningCount" -Level WARNING
        Write-Log "Errors: $script:ErrorCount" -Level ERROR
        Write-Log "Log file: $script:LogFile" -Level INFO
        Write-Log "========================================" -Level SUCCESS
        
        if ($DryRun) {
            Write-Log "This was a DRY RUN - no changes were made to Azure DevOps" -Level INFO
        }
        
        Write-Log "Next Steps:" -Level INFO
        Write-Log "1. Review the migrated repository in Azure DevOps" -Level INFO
        Write-Log "2. Configure environment-specific variables (OpenAI endpoints, keys)" -Level INFO
        Write-Log "3. Set up approval gates for production environment" -Level INFO
        Write-Log "4. Test pipelines with a manual run" -Level INFO
        Write-Log "5. Merge the migration branch to main" -Level INFO
        
    } catch {
        Write-Log "========================================" -Level ERROR
        Write-Log "MIGRATION FAILED!" -Level ERROR
        Write-Log "Error: $($_.Exception.Message)" -Level ERROR
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
        Write-Log "========================================" -Level ERROR
        throw
    }
}

# ===========================
# SCRIPT ENTRY POINT
# ===========================

Start-Migration
