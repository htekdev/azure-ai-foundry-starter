---
name: pipeline-runner
description: Triggers and runs Azure DevOps pipelines via Azure DevOps CLI. Queues pipelines with parameters, monitors initial start status, and returns run ID for tracking. Use when you need to execute ADO pipelines programmatically.
---

# Pipeline Runner Skill

## Overview

This skill enables programmatic execution of Azure DevOps pipelines using the Azure DevOps CLI. It handles pipeline queuing, parameter passing, and returns run identifiers for monitoring.

## When to Use

- Triggering CI/CD pipelines from automation
- Running pipelines with specific parameters or variables
- Executing pipelines as part of validation workflows
- Starting deployment pipelines programmatically

## Prerequisites

- Azure DevOps CLI installed and configured
- Valid Azure DevOps authentication token
- Access to the target Azure DevOps organization and project
- Pipeline name or ID

## Core Operations

### 1. Queue Pipeline

```powershell
# Queue a pipeline by name
az pipelines run --name "pipeline-name" --project "project-name" --org "https://dev.azure.com/orgname"

# Queue with parameters
az pipelines run --name "pipeline-name" --parameters key1=value1 key2=value2

# Queue with variables
az pipelines run --name "pipeline-name" --variables var1=value1 var2=value2

# Queue specific branch
az pipelines run --name "pipeline-name" --branch "main"
```

### 2. Get Run ID

The `az pipelines run` command returns JSON with the run details:

```json
{
  "id": 123,
  "name": "pipeline-name",
  "status": "inProgress",
  "url": "https://dev.azure.com/org/project/_build/results?buildId=123"
}
```

Parse the `id` field for monitoring.

### 3. List Available Pipelines

```powershell
# List all pipelines in project
az pipelines list --project "project-name" --org "https://dev.azure.com/orgname"

# Get pipeline details
az pipelines show --name "pipeline-name" --project "project-name"
```

## Configuration

### Using starter-config.json

Load configuration values from `starter-config.json`:

```powershell
$config = Get-Content -Path "starter-config.json" | ConvertFrom-Json
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName
```

### Authentication

Ensure Azure DevOps CLI is authenticated:

```powershell
# Check authentication
az devops user show --org $org

# Refresh token if needed
$env:AZURE_DEVOPS_EXT_PAT = (az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
```

## Usage Examples

### Basic Pipeline Execution

```powershell
# Load config
$config = Get-Content -Path "starter-config.json" | ConvertFrom-Json
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName

# Queue pipeline
$result = az pipelines run `
    --name "agent-deployment-pipeline" `
    --project $project `
    --org $org `
    --output json | ConvertFrom-Json

$runId = $result.id
$runUrl = $result.url

Write-Host "✅ Pipeline queued: Run ID $runId"
Write-Host "🔗 View: $runUrl"
```

### Pipeline with Parameters

```powershell
# Queue with environment parameter
$result = az pipelines run `
    --name "deployment-pipeline" `
    --parameters environment=dev agentName=test-agent `
    --project $project `
    --org $org `
    --output json | ConvertFrom-Json
```

### Error Handling

```powershell
try {
    $result = az pipelines run --name "pipeline-name" --project $project --org $org --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to queue pipeline: $result" -ForegroundColor Red
        exit 1
    }
    
    $runInfo = $result | ConvertFrom-Json
    Write-Host "✅ Pipeline queued: Run ID $($runInfo.id)"
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
```

## Output Format

Returns pipeline run information:

```powershell
@{
    runId = 123
    status = "inProgress"
    url = "https://dev.azure.com/org/project/_build/results?buildId=123"
    pipelineName = "agent-deployment-pipeline"
}
```

## Common Scenarios

### CI/CD Pipeline Execution

1. Load configuration from `starter-config.json`
2. Verify authentication is valid
3. Queue the pipeline with `az pipelines run`
4. Capture and return the run ID
5. Return URL for user to view progress

### Validation Workflow

1. Queue validation pipeline
2. Get run ID for monitoring
3. Hand off to pipeline-monitor skill for status tracking

## Error Recovery

**Authentication Expired**: Refresh Azure DevOps token
```powershell
$env:AZURE_DEVOPS_EXT_PAT = (az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
```

**Pipeline Not Found**: List available pipelines
```powershell
az pipelines list --project $project --org $org
```

**Insufficient Permissions**: Verify user has pipeline execute permissions in Azure DevOps

## Integration

Works with:
- **pipeline-monitor**: Pass run ID to monitor execution
- **deployment-validation**: Queue and track validation pipelines
- **starter-execution**: Trigger deployment pipelines

## Best Practices

- Always capture run ID for monitoring
- Provide clear feedback to user (run ID, URL)
- Handle authentication errors gracefully
- Use configuration file for consistency
- Return structured data for downstream processing
