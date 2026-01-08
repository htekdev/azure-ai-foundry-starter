---
name: pipeline-monitor
description: Monitors Azure DevOps pipeline execution status, retrieves logs, parses errors, and determines success/failure. Polls pipeline runs until completion and provides detailed error analysis. Use for automated pipeline monitoring and debugging.
---

# Pipeline Monitor Skill

## Overview

Monitors Azure DevOps pipeline execution, tracks status changes, and analyzes failures. Provides real-time feedback on pipeline progress and detailed error information.

## When to Use

- Monitor pipeline execution until completion
- Get current pipeline status without waiting
- Analyze pipeline failures for debugging
- Track pipeline status in automation workflows
- Retrieve detailed failure information for troubleshooting

## Prerequisites

- Azure DevOps CLI installed and configured
- Valid Azure authentication (`az login`)
- Pipeline run ID from pipeline-runner skill
- Access to Azure DevOps organization and project

## Available Scripts

### 1. monitor-pipeline.ps1

Polls pipeline status until completion with progress updates.

**Parameters:**
- `-RunId` (required): Pipeline run ID
- `-Project` (optional): Project name (reads from config if not provided)
- `-Organization` (optional): Org URL (reads from config if not provided)
- `-MaxWaitTime` (optional): Timeout in seconds (default: 1800)
- `-PollInterval` (optional): Polling interval in seconds (default: 10)
- `-Quiet` (optional): Suppress progress messages

**Returns:** JSON with `runId`, `status`, `result`, `duration`, `url`, `succeeded`

### 2. get-pipeline-status.ps1

Quick status check without waiting.

**Parameters:**
- `-RunId` (required): Pipeline run ID
- `-Project` (optional): Project name
- `-Organization` (optional): Org URL

**Returns:** JSON with `runId`, `status`, `result`, `url`, `createdDate`, `finishedDate`

### 3. analyze-failure.ps1

Analyzes failures and provides troubleshooting guidance.

**Parameters:**
- `-RunId` (required): Pipeline run ID
- `-Project` (optional): Project name
- `-Organization` (optional): Org URL

**Returns:** JSON with `runId`, `result`, `url`, `succeeded`, `timestamp`

## Usage Examples

### Monitor Pipeline Until Completion

```powershell
# Basic usage (reads config from starter-config.json)
$result = .\scripts\monitor-pipeline.ps1 -RunId 123 | ConvertFrom-Json

if ($result.succeeded) {
    Write-Host "✅ Pipeline succeeded!"
} else {
    Write-Host "❌ Pipeline failed: $($result.result)"
}
```

### Custom Timeout and Polling

```powershell
# Wait max 10 minutes, poll every 5 seconds
.\scripts\monitor-pipeline.ps1 -RunId 123 -MaxWaitTime 600 -PollInterval 5
```

### Quick Status Check

```powershell
# Get current status without waiting
$status = .\scripts\get-pipeline-status.ps1 -RunId 123 | ConvertFrom-Json

Write-Host "Current status: $($status.status)"
Write-Host "Result: $($status.result)"
```

### Analyze Failure

```powershell
# Get detailed failure analysis
.\scripts\analyze-failure.ps1 -RunId 123
```

### Integrated Workflow

```powershell
# Run pipeline, monitor, and analyze if failed
$runId = 123  # From pipeline-runner

# Monitor until completion
$result = .\scripts\monitor-pipeline.ps1 -RunId $runId | ConvertFrom-Json

if (-not $result.succeeded) {
    # Analyze failure
    .\scripts\analyze-failure.ps1 -RunId $runId
}
```

## Output Format

All scripts return structured JSON:

```json
{
  "runId": 123,
  "status": "completed",
  "result": "succeeded",
  "duration": 245,
  "url": "https://dev.azure.com/org/project/_build/results?buildId=123",
  "succeeded": true
}
```

**Status values:** `inProgress`, `completed`, `canceling`, `notStarted`, `timeout`

**Result values:** `succeeded`, `failed`, `canceled`, `partiallySucceeded`

## Common Error Patterns

Scripts automatically check for these patterns:

| Category | Patterns | Solutions |
|----------|----------|-----------|
| **Service Connection** | "service connection", "not authorized" | Verify connection exists, check federated credentials, verify RBAC |
| **Variable Group** | "variable group", "Access denied" | Check group exists, verify permissions, ensure variables set |
| **RBAC** | "Authorization failed", "Insufficient permissions" | Check role assignments, verify resource group permissions |
| **Federated Credential** | "AADSTS70021", "Invalid issuer" | Verify credentials exist, check issuer/subject match |

## Configuration

Scripts automatically read from `starter-config.json`:

```json
{
  "azureDevOps": {
    "organizationUrl": "https://dev.azure.com/yourorg",
    "projectName": "your-project"
  }
}
```

You can override with explicit parameters if needed.

## Integration Points

- **pipeline-runner**: Monitor pipelines started by runner
- **deployment-validation**: Validate pipeline execution results  
- **pipeline-debugger agent**: Automated debugging loops

## Best Practices

✅ **DO:**
- Use default timeout (30 minutes) for most pipelines
- Return structured JSON for downstream processing
- Check both `status` and `result` fields
- Include pipeline URL in output
- Handle authentication before calling scripts

❌ **DON'T:**
- Set very short timeouts (< 5 minutes)
- Poll too frequently (< 5 seconds)
- Ignore the `succeeded` field in results
- Forget to analyze failures for troubleshooting
