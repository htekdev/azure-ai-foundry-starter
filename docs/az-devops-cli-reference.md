# Azure DevOps CLI (az devops) Complete Reference
## Command-Line Interface for Azure DevOps Operations

**Last Updated**: January 7, 2026  
**Purpose**: Complete reference for `az devops` CLI commands for repository migration and management

---

## 📋 Table of Contents

1. [Installation & Setup](#installation--setup)
2. [Authentication](#authentication)
3. [Configuration](#configuration)
4. [Repository Commands](#repository-commands)
5. [Pipeline Commands](#pipeline-commands)
6. [Service Endpoint Commands](#service-endpoint-commands)
7. [Variable Group Commands](#variable-group-commands)
8. [Build Commands](#build-commands)
9. [User & Security Commands](#user--security-commands)
10. [Project Commands](#project-commands)
11. [Complete Examples](#complete-examples)

---

## Installation & Setup

### Install Azure CLI

```powershell
# Windows (via winget)
winget install Microsoft.AzureCLI

# Or download installer from:
# https://aka.ms/installazurecliwindows
```

```bash
# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# macOS
brew install azure-cli
```

### Install Azure DevOps Extension

```powershell
# Install extension
az extension add --name azure-devops

# Update to latest version
az extension update --name azure-devops

# Show extension info
az extension show --name azure-devops

# List all extensions
az extension list --output table
```

### Verify Installation

```powershell
# Check Azure CLI version
az --version

# Check Azure DevOps extension version
az extension show --name azure-devops --query version
```

---

## Authentication

### Method 1: Bearer Token (Recommended)

```powershell
# Login to Azure
az login

# Get bearer token for Azure DevOps
$token = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

# Set environment variable for az devops
$env:AZURE_DEVOPS_EXT_PAT = $token
```

### Method 2: Service Principal

```powershell
# Login with service principal
az login --service-principal `
    -u $env:AZURE_CLIENT_ID `
    -p $env:AZURE_CLIENT_SECRET `
    --tenant $env:AZURE_TENANT_ID

# Get token
$token = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

$env:AZURE_DEVOPS_EXT_PAT = $token
```

### Method 3: PAT Token

```powershell
# Interactive login
az devops login --organization https://dev.azure.com/myorg

# Or pipe PAT
echo "your-pat-token" | az devops login --organization https://dev.azure.com/myorg

# Or set environment variable
$env:AZURE_DEVOPS_EXT_PAT = "your-pat-token"
```

### Logout

```powershell
az devops logout
```

---

## Configuration

### Set Default Organization and Project

```powershell
# Configure defaults
az devops configure --defaults `
    organization=https://dev.azure.com/myorg `
    project=myproject

# List current configuration
az devops configure --list

# Use organization/project in specific command
az repos list --organization https://dev.azure.com/myorg --project myproject
```

---

## Repository Commands

### List Repositories

```powershell
# List all repositories in project
az repos list

# List with specific output
az repos list --output table

# List specific fields
az repos list --query "[].{Name:name, ID:id, URL:remoteUrl}"
```

### Create Repository

```powershell
# Create new repository
az repos create --name "my-new-repo"

# Create with detection disabled
az repos create --name "my-new-repo" --detect false

# Create and get details
$repo = az repos create --name "my-new-repo" --output json | ConvertFrom-Json
Write-Host "Repository created: $($repo.remoteUrl)"
```

### Show Repository Details

```powershell
# Show repository by name
az repos show --repository "my-repo"

# Show repository by ID
az repos show --repository "repo-guid"

# Get specific properties
az repos show --repository "my-repo" --query "defaultBranch"
```

### Delete Repository

```powershell
# Delete repository
az repos delete --id "repo-guid" --yes

# Delete by name (requires project context)
az repos delete --repository "my-repo" --yes
```

### Import Repository

```powershell
# Import from Git URL
az repos import create `
    --git-url "https://github.com/user/repo.git" `
    --repository "target-repo"

# Import with authentication
az repos import create `
    --git-url "https://github.com/user/repo.git" `
    --repository "target-repo" `
    --git-source-url "https://github.com/user/repo.git" `
    --requires-authorization
```

### Update Repository

```powershell
# Update repository (rename)
az repos update --repository "old-name" --name "new-name"

# Disable repository
az repos update --repository "my-repo" --disabled true
```

### Policy Commands

```powershell
# List policies on repository
az repos policy list --repository-id "repo-guid"

# Create branch policy
az repos policy create --policy-configuration policy.json
```

---

## Pipeline Commands

### List Pipelines

```powershell
# List all pipelines
az pipelines list

# List with table output
az pipelines list --output table

# List specific pipeline
az pipelines show --name "My Pipeline"
az pipelines show --id 123
```

### Create Pipeline

```powershell
# Create pipeline from YAML
az pipelines create `
    --name "My Pipeline" `
    --description "Pipeline description" `
    --repository "my-repo" `
    --repository-type tfsgit `
    --branch main `
    --yml-path ".azure-pipelines/pipeline.yml" `
    --skip-first-run

# Create and run immediately
az pipelines create `
    --name "My Pipeline" `
    --repository "my-repo" `
    --repository-type tfsgit `
    --branch main `
    --yml-path ".azure-pipelines/pipeline.yml"
```

### Run Pipeline

```powershell
# Run pipeline by ID
az pipelines run --id 123

# Run with branch
az pipelines run --id 123 --branch "feature/new-feature"

# Run with parameters
az pipelines run --id 123 --parameters "param1=value1" "param2=value2"

# Run and open in browser
az pipelines run --id 123 --open
```

### Update Pipeline

```powershell
# Update pipeline
az pipelines update --id 123 --new-name "Updated Pipeline"

# Update YAML path
az pipelines update --id 123 --yml-path "new-path/pipeline.yml"
```

### Delete Pipeline

```powershell
# Delete pipeline
az pipelines delete --id 123 --yes
```

### Pipeline Runs

```powershell
# List pipeline runs
az pipelines runs list

# List runs for specific pipeline
az pipelines runs list --pipeline-ids 123

# List recent runs
az pipelines runs list --top 10

# Show specific run
az pipelines runs show --id 456

# Get run logs
az pipelines runs show --id 456 --open

# List run artifacts
az pipelines runs artifact list --run-id 456

# Download artifacts
az pipelines runs artifact download --run-id 456 --artifact-name "drop" --path ./artifacts
```

### Pipeline Variables

```powershell
# List pipeline variables
az pipelines variable list --pipeline-id 123

# Create variable
az pipelines variable create `
    --pipeline-id 123 `
    --name "MyVariable" `
    --value "MyValue"

# Create secret variable
az pipelines variable create `
    --pipeline-id 123 `
    --name "MySecret" `
    --value "SecretValue" `
    --secret true

# Update variable
az pipelines variable update `
    --pipeline-id 123 `
    --name "MyVariable" `
    --value "NewValue"

# Delete variable
az pipelines variable delete `
    --pipeline-id 123 `
    --name "MyVariable" `
    --yes
```

---

## Service Endpoint Commands

### List Service Endpoints

```powershell
# List all service endpoints
az devops service-endpoint list

# List with table output
az devops service-endpoint list --output table

# Show specific endpoint
az devops service-endpoint show --id "endpoint-guid"
```

### Create Azure RM Service Endpoint

```powershell
# Create Azure RM service endpoint (service principal)
az devops service-endpoint azurerm create `
    --azure-rm-service-principal-id $env:AZURE_CLIENT_ID `
    --azure-rm-subscription-id $env:AZURE_SUBSCRIPTION_ID `
    --azure-rm-subscription-name "My Subscription" `
    --azure-rm-tenant-id $env:AZURE_TENANT_ID `
    --name "azure-connection-dev"

# Create with key/secret from environment variable
$env:AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY = $env:AZURE_CLIENT_SECRET
az devops service-endpoint azurerm create `
    --azure-rm-service-principal-id $env:AZURE_CLIENT_ID `
    --azure-rm-subscription-id $env:AZURE_SUBSCRIPTION_ID `
    --azure-rm-subscription-name "My Subscription" `
    --azure-rm-tenant-id $env:AZURE_TENANT_ID `
    --name "azure-connection-dev"
```

### Create GitHub Service Endpoint

```powershell
# Create GitHub service endpoint
az devops service-endpoint github create `
    --github-url "https://github.com" `
    --name "github-connection"
```

### Update Service Endpoint

```powershell
# Update service endpoint
az devops service-endpoint update `
    --id "endpoint-guid" `
    --enable-for-all true

# Update name
az devops service-endpoint update `
    --id "endpoint-guid" `
    --name "new-name"
```

### Delete Service Endpoint

```powershell
# Delete service endpoint
az devops service-endpoint delete --id "endpoint-guid" --yes
```

---

## Variable Group Commands

### List Variable Groups

```powershell
# List all variable groups
az pipelines variable-group list

# List with table output
az pipelines variable-group list --output table

# Show specific variable group
az pipelines variable-group show --group-id 123

# List variables in group
az pipelines variable-group variable list --group-id 123
```

### Create Variable Group

```powershell
# Create variable group
az pipelines variable-group create `
    --name "my-variable-group" `
    --variables `
        VAR1="value1" `
        VAR2="value2" `
        VAR3="value3"

# Create with authorization for all pipelines
az pipelines variable-group create `
    --name "my-variable-group" `
    --variables VAR1="value1" `
    --authorize true

# Create with description
az pipelines variable-group create `
    --name "my-variable-group" `
    --description "My variable group description" `
    --variables VAR1="value1"
```

### Update Variable Group

```powershell
# Update variable group name
az pipelines variable-group update `
    --group-id 123 `
    --name "new-name"

# Update description
az pipelines variable-group update `
    --group-id 123 `
    --description "Updated description"
```

### Variable Group Variables

```powershell
# Add variable to group
az pipelines variable-group variable create `
    --group-id 123 `
    --name "NEW_VAR" `
    --value "new value"

# Add secret variable
az pipelines variable-group variable create `
    --group-id 123 `
    --name "SECRET_VAR" `
    --value "secret value" `
    --secret true

# Update variable
az pipelines variable-group variable update `
    --group-id 123 `
    --name "VAR1" `
    --value "updated value"

# Delete variable
az pipelines variable-group variable delete `
    --group-id 123 `
    --name "VAR1" `
    --yes
```

### Delete Variable Group

```powershell
# Delete variable group
az pipelines variable-group delete --group-id 123 --yes
```

---

## Build Commands

### List Builds

```powershell
# List all builds
az pipelines build list

# List recent builds
az pipelines build list --top 10

# List builds for specific definition
az pipelines build list --definition-ids 123

# List builds for specific branch
az pipelines build list --branch "main"

# List builds with specific result
az pipelines build list --result "succeeded"

# List with table output
az pipelines build list --output table
```

### Show Build

```powershell
# Show build details
az pipelines build show --id 456

# Open build in browser
az pipelines build show --id 456 --open
```

### Queue Build

```powershell
# Queue build
az pipelines build queue --definition-id 123

# Queue with branch
az pipelines build queue --definition-id 123 --branch "feature/new"

# Queue with parameters
az pipelines build queue --definition-id 123 --variables "var1=value1" "var2=value2"

# Queue and open in browser
az pipelines build queue --definition-id 123 --open
```

### Build Tags

```powershell
# Add tag to build
az pipelines build tag add --build-id 456 --tags "release" "production"

# List build tags
az pipelines build tag list --build-id 456

# Delete tag
az pipelines build tag delete --build-id 456 --tag "release"
```

### Build Definitions

```powershell
# List build definitions
az pipelines build definition list

# Show build definition
az pipelines build definition show --id 123

# List with table output
az pipelines build definition list --output table
```

---

## User & Security Commands

### User Commands

```powershell
# List users
az devops user list

# List with table output
az devops user list --output table

# Show specific user
az devops user show --user "user@example.com"

# Add user
az devops user add --email-id "newuser@example.com" --license-type express

# Update user license
az devops user update --user "user@example.com" --license-type stakeholder

# Remove user
az devops user remove --user "user@example.com" --yes
```

### Team Commands

```powershell
# List teams
az devops team list

# Show team
az devops team show --team "My Team"

# Create team
az devops team create --name "New Team" --description "Team description"

# Update team
az devops team update --team "My Team" --name "Updated Team"

# Delete team
az devops team delete --id "team-guid" --yes
```

### Security Commands

```powershell
# List security groups
az devops security group list

# Show group
az devops security group show --id "group-descriptor"

# Create group
az devops security group create --name "My Group" --description "Group description"

# Add member to group
az devops security group membership add `
    --group-id "group-descriptor" `
    --member-id "member-descriptor"

# Remove member from group
az devops security group membership remove `
    --group-id "group-descriptor" `
    --member-id "member-descriptor" `
    --yes

# List group memberships
az devops security group membership list --id "group-descriptor"
```

### Permission Commands

```powershell
# List permissions
az devops security permission list --id "security-namespace-id"

# Show permission
az devops security permission show `
    --id "security-namespace-id" `
    --subject "user-or-group-descriptor"

# Update permission
az devops security permission update `
    --id "security-namespace-id" `
    --subject "user-or-group-descriptor" `
    --allow-bit 1 `
    --deny-bit 0

# Reset permissions
az devops security permission reset `
    --id "security-namespace-id" `
    --subject "user-or-group-descriptor" `
    --yes
```

---

## Project Commands

### List Projects

```powershell
# List all projects
az devops project list

# List with table output
az devops project list --output table

# Show specific project
az devops project show --project "My Project"
```

### Create Project

```powershell
# Create project
az devops project create `
    --name "My New Project" `
    --description "Project description" `
    --source-control git `
    --visibility private

# Create with specific process template
az devops project create `
    --name "My New Project" `
    --process "Agile" `
    --source-control git
```

### Update Project

```powershell
# Update project
az devops project update `
    --project "My Project" `
    --name "Updated Project" `
    --description "Updated description"

# Update visibility
az devops project update `
    --project "My Project" `
    --visibility public
```

### Delete Project

```powershell
# Delete project
az devops project delete --id "project-guid" --yes
```

---

## Complete Examples

### Example 1: Full Repository Setup

```powershell
# Authenticate
az login
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

# Configure
az devops configure --defaults organization=https://dev.azure.com/myorg project=myproject

# Create repository
$repo = az repos create --name "my-new-repo" --output json | ConvertFrom-Json
Write-Host "Repository URL: $($repo.remoteUrl)"

# Create pipeline
az pipelines create `
    --name "CI Pipeline" `
    --repository $repo.name `
    --repository-type tfsgit `
    --branch main `
    --yml-path "azure-pipelines.yml"

# Create variable group
az pipelines variable-group create `
    --name "build-vars" `
    --variables `
        BUILD_NUMBER="1.0.0" `
        ENVIRONMENT="dev" `
    --authorize true

Write-Host "Setup complete!"
```

### Example 2: Service Connection & Variable Group for Multiple Environments

```powershell
$environments = @("dev", "test", "prod")

foreach ($env in $environments) {
    # Create service connection
    az devops service-endpoint azurerm create `
        --azure-rm-service-principal-id $env:AZURE_CLIENT_ID `
        --azure-rm-subscription-id $env:AZURE_SUBSCRIPTION_ID `
        --azure-rm-subscription-name "My Subscription" `
        --azure-rm-tenant-id $env:AZURE_TENANT_ID `
        --name "azure-$env"
    
    # Create variable group
    az pipelines variable-group create `
        --name "$env-vars" `
        --variables `
            ENVIRONMENT="$env" `
            SERVICE_CONNECTION="azure-$env" `
        --authorize true
    
    Write-Host "✓ Created resources for $env"
}
```

### Example 3: Pipeline Run with Artifact Download

```powershell
# Run pipeline
$run = az pipelines run --id 123 --output json | ConvertFrom-Json
Write-Host "Pipeline run started: $($run.id)"

# Wait for completion (simple poll)
do {
    Start-Sleep -Seconds 10
    $status = az pipelines runs show --id $run.id --query "status" --output tsv
    Write-Host "Status: $status"
} while ($status -eq "inProgress")

# Download artifacts
if ($status -eq "completed") {
    az pipelines runs artifact download `
        --run-id $run.id `
        --artifact-name "drop" `
        --path "./artifacts"
    
    Write-Host "✓ Artifacts downloaded"
}
```

### Example 4: Bulk User Management

```powershell
# CSV with users
$users = @(
    @{Email="user1@example.com"; License="express"}
    @{Email="user2@example.com"; License="stakeholder"}
    @{Email="user3@example.com"; License="express"}
)

foreach ($user in $users) {
    # Add user
    az devops user add `
        --email-id $user.Email `
        --license-type $user.License
    
    Write-Host "✓ Added $($user.Email)"
    
    # Add to team (optional)
    $userDescriptor = az devops user show --user $user.Email --query "descriptor" --output tsv
    az devops security group membership add `
        --group-id "team-descriptor" `
        --member-id $userDescriptor
}
```

### Example 5: Export All Repositories

```powershell
# Get all repositories
$repos = az repos list --output json | ConvertFrom-Json

# Export info
$export = $repos | Select-Object name, id, remoteUrl, defaultBranch, size

# Save to CSV
$export | Export-Csv -Path "repositories.csv" -NoTypeInformation

# Clone all repositories
foreach ($repo in $repos) {
    Write-Host "Cloning $($repo.name)..."
    git clone $repo.remoteUrl
}

Write-Host "✓ All repositories cloned"
```

---

## Output Formats

### Available Output Formats

```powershell
# JSON (default)
az repos list --output json

# JSON (compact)
az repos list --output jsonc

# Table
az repos list --output table

# TSV (tab-separated values)
az repos list --output tsv

# YAML
az repos list --output yaml

# None (no output)
az repos list --output none
```

### Query Results with JMESPath

```powershell
# Get specific fields
az repos list --query "[].{Name:name, URL:remoteUrl}"

# Filter results
az repos list --query "[?name=='my-repo']"

# Get first item
az repos list --query "[0]"

# Get count
az repos list --query "length(@)"
```

---

## Troubleshooting

### Common Issues

**Issue: "Please run 'az login' to set up account"**
```powershell
# Solution: Authenticate
az login
$env:AZURE_DEVOPS_EXT_PAT = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
```

**Issue: "TF401019: The Git repository with name or identifier ... does not exist"**
```powershell
# Solution: Set default project
az devops configure --defaults project=myproject
```

**Issue: Token expired**
```powershell
# Solution: Refresh token
$env:AZURE_DEVOPS_EXT_PAT = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
```

### Enable Debug Logging

```powershell
# Enable debug output
$env:AZURE_DEVOPS_EXT_DEBUG = "true"

# Run command
az repos list

# Disable debug
$env:AZURE_DEVOPS_EXT_DEBUG = "false"
```

---

## Additional Resources

- [Official az devops documentation](https://learn.microsoft.com/en-us/cli/azure/devops)
- [Azure DevOps REST API](https://learn.microsoft.com/en-us/rest/api/azure/devops/)
- [JMESPath query syntax](http://jmespath.org/)
- [Azure CLI documentation](https://learn.microsoft.com/en-us/cli/azure/)

---

**Document Version**: 1.0  
**Last Updated**: January 7, 2026  
**Maintained by**: DevOps Team
