# Azure DevOps REST API Reference Guide
## Complete API Endpoint Documentation for Migration

---

## Table of Contents

1. [Authentication](#authentication)
2. [Git Repositories API](#git-repositories-api)
3. [Pipelines API](#pipelines-api)
4. [Service Endpoints API](#service-endpoints-api)
5. [Variable Groups API](#variable-groups-api)
6. [Environments API](#environments-api)
7. [Build API](#build-api)
8. [Complete Examples](#complete-examples)

---

## Authentication

Azure DevOps REST API supports **two primary authentication methods**:

1. **Bearer Token (Recommended)** - Using Microsoft Entra ID tokens
2. **Personal Access Token (PAT)** - Traditional method

### Method 1: Bearer Token Authentication (Recommended)

**Why use Bearer tokens?**
- More secure (1-hour expiration)
- Works with service principals and managed identities
- No need to create/manage PATs
- Perfect for automation

**Azure DevOps Resource ID**: `499b84ac-1321-427f-aa17-267ca6975798`

#### Get Bearer Token with Azure CLI

**For User Authentication**:

```powershell
# PowerShell
az login
az account set --subscription "<subscription-id>"

# Get bearer token
$token = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

# Create headers
$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}
```

```bash
# Bash
az login
az account set --subscription "<subscription-id>"

# Get bearer token
TOKEN=$(az account get-access-token \
    --resource 499b84ac-1321-427f-aa17-267ca6975798 \
    --query "accessToken" \
    --output tsv)

# Use in curl
curl -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     "https://dev.azure.com/{org}/_apis/projects?api-version=7.1"
```

**For Service Principal Authentication**:

```powershell
# PowerShell
az login --service-principal `
    -u $env:AZURE_CLIENT_ID `
    -p $env:AZURE_CLIENT_SECRET `
    --tenant $env:AZURE_TENANT_ID

az account set --subscription $env:AZURE_SUBSCRIPTION_ID

$token = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}
```

```bash
# Bash
az login --service-principal \
    -u "$AZURE_CLIENT_ID" \
    -p "$AZURE_CLIENT_SECRET" \
    --tenant "$AZURE_TENANT_ID"

az account set --subscription "$AZURE_SUBSCRIPTION_ID"

TOKEN=$(az account get-access-token \
    --resource 499b84ac-1321-427f-aa17-267ca6975798 \
    --query "accessToken" \
    --output tsv)
```

#### Using Bearer Token with Git

```powershell
# Clone with bearer token
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
git -c http.extraheader="AUTHORIZATION: bearer $token" clone https://dev.azure.com/{org}/{project}/_git/{repo}

# Configure for existing repo
git config --local http.extraheader "AUTHORIZATION: bearer $token"

# Remove after use (security best practice)
git config --local --unset http.extraheader
```

### Method 2: Personal Access Token (PAT)

**Format**: Basic Authentication with PAT

```http
Authorization: Basic <base64-encoded-pat>
```

**Encoding PAT**:

```powershell
# PowerShell
$pat = "your-pat-token"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}
```

```bash
# Bash
PAT="your-pat-token"
B64_PAT=$(echo -n ":$PAT" | base64)
```

```python
# Python
import base64
pat = "your-pat-token"
b64_pat = base64.b64encode(f":{pat}".encode()).decode()
headers = {
    "Authorization": f"Basic {b64_pat}",
    "Content-Type": "application/json"
}
```

### Token Expiration & Refresh

**Bearer Tokens**:
- Expire after 1 hour
- Automatically refresh by calling `az account get-access-token` again
- No manual cleanup required

**Personal Access Tokens**:
- Expire based on configuration (default: 90 days)
- Must be manually recreated when expired
- Should be revoked when no longer needed

---

## Git Repositories API

### Base URL
```
https://dev.azure.com/{organization}/{project}/_apis/git/repositories
```

### API Version
- **Current**: 7.1
- **Preview**: 7.1-preview.1

---

### 1. List Repositories

**Endpoint**: `GET /_apis/git/repositories`

**Description**: Get all repositories in a project

**Example Request**:

**With Bearer Token**:
```bash
# Get token
TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv)

# Make request
curl -X GET \
  "https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=7.1" \
  -H "Authorization: Bearer $TOKEN"
```

```powershell
# Get token
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
$headers = @{ Authorization = "Bearer $token" }

# Make request
$uri = "https://dev.azure.com/$organization/$project/_apis/git/repositories?api-version=7.1"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
```

**With PAT**:
```bash
curl -X GET \
  "https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=7.1" \
  -H "Authorization: Basic $B64_PAT"
```

```powershell
$pat = "your-pat-token"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{ Authorization = "Basic $base64AuthInfo" }

$uri = "https://dev.azure.com/$organization/$project/_apis/git/repositories?api-version=7.1"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
```

```python
import requests
url = f"https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=7.1"
response = requests.get(url, headers=headers)
```

**Response** (200 OK):
```json
{
  "value": [
    {
      "id": "repository-guid",
      "name": "repository-name",
      "url": "https://dev.azure.com/org/project/_apis/git/repositories/repo-id",
      "project": {
        "id": "project-guid",
        "name": "project-name"
      },
      "defaultBranch": "refs/heads/main",
      "size": 1024,
      "remoteUrl": "https://dev.azure.com/org/project/_git/repo-name",
      "sshUrl": "git@ssh.dev.azure.com:v3/org/project/repo-name"
    }
  ],
  "count": 1
}
```

---

### 2. Create Repository

**Endpoint**: `POST /_apis/git/repositories`

**Description**: Create a new Git repository

**Request Body**:
```json
{
  "name": "repository-name",
  "project": {
    "id": "project-guid"  // Optional if project in URL
  }
}
```

**Example Request**:

```bash
curl -X POST \
  "https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=7.1" \
  -H "Authorization: Basic $B64_PAT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "foundry-cicd",
    "project": {
      "name": "YourProject"
    }
  }'
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/git/repositories?api-version=7.1"
$body = @{
    name = "foundry-cicd"
    project = @{
        name = $project
    }
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
```

```python
url = f"https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=7.1"
body = {
    "name": "foundry-cicd",
    "project": {
        "name": project
    }
}
response = requests.post(url, headers=headers, json=body)
```

**Response** (201 Created):
```json
{
  "id": "new-repo-guid",
  "name": "foundry-cicd",
  "url": "https://dev.azure.com/org/project/_apis/git/repositories/repo-id",
  "project": {
    "id": "project-guid",
    "name": "YourProject"
  },
  "defaultBranch": "refs/heads/main",
  "remoteUrl": "https://dev.azure.com/org/project/_git/foundry-cicd",
  "sshUrl": "git@ssh.dev.azure.com:v3/org/project/foundry-cicd"
}
```

---

### 3. Get Repository

**Endpoint**: `GET /_apis/git/repositories/{repositoryId}`

**Description**: Get details of a specific repository

**Example Request**:

```bash
curl -X GET \
  "https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}?api-version=7.1" \
  -H "Authorization: Basic $B64_PAT"
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repositoryId?api-version=7.1"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
```

---

### 4. Delete Repository

**Endpoint**: `DELETE /_apis/git/repositories/{repositoryId}`

**Description**: Delete a repository (moves to recycle bin)

**Example Request**:

```bash
curl -X DELETE \
  "https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}?api-version=7.1" \
  -H "Authorization: Basic $B64_PAT"
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repositoryId?api-version=7.1"
Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers
```

**Response**: 204 No Content

---

## Pipelines API

### Base URL
```
https://dev.azure.com/{organization}/{project}/_apis/pipelines
```

### API Version
- **Current**: 7.1-preview.1

---

### 1. List Pipelines

**Endpoint**: `GET /_apis/pipelines`

**Description**: Get all pipelines in a project

**Example Request**:

```bash
curl -X GET \
  "https://dev.azure.com/{organization}/{project}/_apis/pipelines?api-version=7.1-preview.1" \
  -H "Authorization: Basic $B64_PAT"
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/pipelines?api-version=7.1-preview.1"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
```

**Response** (200 OK):
```json
{
  "value": [
    {
      "id": 123,
      "name": "Pipeline Name",
      "folder": "\\",
      "revision": 1
    }
  ],
  "count": 1
}
```

---

### 2. Create Pipeline

**Endpoint**: `POST /_apis/pipelines`

**Description**: Create a new pipeline from YAML file

**Request Body**:
```json
{
  "name": "Pipeline Name",
  "folder": "\\",
  "configuration": {
    "type": "yaml",
    "path": "/path/to/pipeline.yml",
    "repository": {
      "id": "repository-guid",
      "name": "repository-name",
      "type": "azureReposGit"
    }
  }
}
```

**Example Request**:

```bash
curl -X POST \
  "https://dev.azure.com/{organization}/{project}/_apis/pipelines?api-version=7.1-preview.1" \
  -H "Authorization: Basic $B64_PAT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Foundry Agent Creation",
    "folder": "\\",
    "configuration": {
      "type": "yaml",
      "path": "/.azure-pipelines/create-agent-pipeline.yml",
      "repository": {
        "id": "repo-guid",
        "name": "foundry-cicd",
        "type": "azureReposGit"
      }
    }
  }'
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/pipelines?api-version=7.1-preview.1"
$body = @{
    name = "Foundry Agent Creation"
    folder = "\"
    configuration = @{
        type = "yaml"
        path = ".azure-pipelines/create-agent-pipeline.yml"
        repository = @{
            id = $repositoryId
            name = "foundry-cicd"
            type = "azureReposGit"
        }
    }
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
```

**Response** (200 OK):
```json
{
  "id": 456,
  "name": "Foundry Agent Creation",
  "folder": "\\",
  "revision": 1,
  "configuration": {
    "type": "yaml",
    "path": "/.azure-pipelines/create-agent-pipeline.yml"
  }
}
```

---

### 3. Run Pipeline

**Endpoint**: `POST /_apis/pipelines/{pipelineId}/runs`

**Description**: Queue a new run of a pipeline

**Request Body**:
```json
{
  "resources": {
    "repositories": {
      "self": {
        "refName": "refs/heads/main"
      }
    }
  },
  "templateParameters": {},
  "variables": {}
}
```

**Example Request**:

```bash
curl -X POST \
  "https://dev.azure.com/{organization}/{project}/_apis/pipelines/{pipelineId}/runs?api-version=7.1-preview.1" \
  -H "Authorization: Basic $B64_PAT" \
  -H "Content-Type: application/json" \
  -d '{
    "resources": {
      "repositories": {
        "self": {
          "refName": "refs/heads/main"
        }
      }
    }
  }'
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/pipelines/$pipelineId/runs?api-version=7.1-preview.1"
$body = @{
    resources = @{
        repositories = @{
            self = @{
                refName = "refs/heads/main"
            }
        }
    }
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
```

**Response** (200 OK):
```json
{
  "id": 789,
  "name": "20260107.1",
  "state": "inProgress",
  "result": null,
  "createdDate": "2026-01-07T12:00:00Z",
  "finishedDate": null,
  "url": "https://dev.azure.com/org/project/_apis/pipelines/456/runs/789"
}
```

---

## Service Endpoints API

### Base URL
```
https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpoints
```

### API Version
- **Current**: 7.1-preview.4

---

### 1. List Service Endpoints

**Endpoint**: `GET /_apis/serviceendpoint/endpoints`

**Example Request**:

```bash
curl -X GET \
  "https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" \
  -H "Authorization: Basic $B64_PAT"
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
```

---

### 2. Create Service Endpoint (Azure Resource Manager)

**Endpoint**: `POST /_apis/serviceendpoint/endpoints`

**Description**: Create a service connection to Azure

**Request Body**:
```json
{
  "name": "azure-foundry-dev",
  "type": "azurerm",
  "url": "https://management.azure.com/",
  "description": "Azure service connection for dev environment",
  "authorization": {
    "parameters": {
      "serviceprincipalid": "client-id-guid",
      "serviceprincipalkey": "client-secret",
      "tenantid": "tenant-id-guid"
    },
    "scheme": "ServicePrincipal"
  },
  "data": {
    "subscriptionId": "subscription-id-guid",
    "subscriptionName": "Subscription Name",
    "environment": "AzureCloud",
    "scopeLevel": "Subscription",
    "creationMode": "Manual"
  },
  "isShared": false,
  "isReady": true,
  "serviceEndpointProjectReferences": [
    {
      "projectReference": {
        "id": "project-guid",
        "name": "project-name"
      },
      "name": "azure-foundry-dev"
    }
  ]
}
```

**Example Request**:

```bash
curl -X POST \
  "https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" \
  -H "Authorization: Basic $B64_PAT" \
  -H "Content-Type: application/json" \
  -d @service-connection.json
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
$body = @{
    name = "azure-foundry-dev"
    type = "azurerm"
    url = "https://management.azure.com/"
    description = "Azure service connection for dev environment"
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
        subscriptionName = "Your Subscription"
        environment = "AzureCloud"
        scopeLevel = "Subscription"
        creationMode = "Manual"
    }
    isShared = $false
    isReady = $true
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"
```

**Response** (200 OK):
```json
{
  "id": "endpoint-guid",
  "name": "azure-foundry-dev",
  "type": "azurerm",
  "url": "https://management.azure.com/",
  "isReady": true,
  "isShared": false
}
```

---

### 3. Delete Service Endpoint

**Endpoint**: `DELETE /_apis/serviceendpoint/endpoints/{endpointId}`

**Example Request**:

```bash
curl -X DELETE \
  "https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpoints/{endpointId}?api-version=7.1-preview.4" \
  -H "Authorization: Basic $B64_PAT"
```

---

## Variable Groups API

### Base URL
```
https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups
```

### API Version
- **Current**: 7.1-preview.2

---

### 1. List Variable Groups

**Endpoint**: `GET /_apis/distributedtask/variablegroups`

**Example Request**:

```bash
curl -X GET \
  "https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?api-version=7.1-preview.2" \
  -H "Authorization: Basic $B64_PAT"
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
```

---

### 2. Create Variable Group

**Endpoint**: `POST /_apis/distributedtask/variablegroups`

**Description**: Create a new variable group

> **Note**: Variable group names follow the pattern `{projectName}-{env}-vars` where `projectName` comes from `config.naming.projectName`. Examples below use `aifoundrycicd` as the project name.

**Request Body**:
```json
{
  "name": "aifoundrycicd-dev-vars",
  "description": "Variables for dev environment (name pattern: {projectName}-dev-vars)",
  "type": "Vsts",
  "variables": {
    "AZURE_AI_PROJECT_DEV": {
      "value": "https://dev-project.api.azureml.ms",
      "isSecret": false
    },
    "AZURE_OPENAI_KEY_DEV": {
      "value": "secret-key",
      "isSecret": true
    }
  }
}
```

**Example Request**:

```bash
curl -X POST \
  "https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?api-version=7.1-preview.2" \
  -H "Authorization: Basic $B64_PAT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "aifoundrycicd-dev-vars",
    "description": "Variables for dev environment (pattern: {projectName}-dev-vars)",
    "type": "Vsts",
    "variables": {
      "AZURE_AI_PROJECT_DEV": {
        "value": "https://dev-project.api.azureml.ms",
        "isSecret": false
      }
    }
  }'
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
$body = @{
    name = "aifoundrycicd-dev-vars"  # Pattern: {projectName}-dev-vars
    description = "Variables for dev environment"
    type = "Vsts"
    variables = @{
        "AZURE_AI_PROJECT_DEV" = @{
            value = "https://dev-project.api.azureml.ms"
            isSecret = $false
        }
        "AZURE_OPENAI_KEY_DEV" = @{
            value = "your-secret-key"
            isSecret = $true
        }
        "AZURE_OPENAI_API_VERSION_DEV" = @{
            value = "2024-02-15-preview"
            isSecret = $false
        }
    }
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"
```

**Response** (200 OK):
```json
{
  "id": 123,
  "name": "aifoundrycicd-dev-vars",
  "description": "Variables for dev environment",
  "type": "Vsts",
  "variables": {
    "AZURE_AI_PROJECT_DEV": {
      "value": "https://dev-project.api.azureml.ms",
      "isSecret": false
    },
    "AZURE_OPENAI_KEY_DEV": {
      "value": null,
      "isSecret": true
    }
  }
}
```

---

### 3. Update Variable Group

**Endpoint**: `PUT /_apis/distributedtask/variablegroups/{groupId}`

**Example Request**:

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/variablegroups/$groupId?api-version=7.1-preview.2"

# Get current variable group first
$currentGroup = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

# Modify variables
$currentGroup.variables["NEW_VARIABLE"] = @{
    value = "new-value"
    isSecret = $false
}

# Update
$body = $currentGroup | ConvertTo-Json -Depth 10
$response = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $body -ContentType "application/json"
```

---

## Environments API

### Base URL
```
https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments
```

### API Version
- **Current**: 7.1-preview.1

---

### 1. List Environments

**Endpoint**: `GET /_apis/distributedtask/environments`

**Example Request**:

```bash
curl -X GET \
  "https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments?api-version=7.1-preview.1" \
  -H "Authorization: Basic $B64_PAT"
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
```

---

### 2. Create Environment

**Endpoint**: `POST /_apis/distributedtask/environments`

**Description**: Create a new environment

**Request Body**:
```json
{
  "name": "dev",
  "description": "Development environment for foundry-cicd"
}
```

**Example Request**:

```bash
curl -X POST \
  "https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments?api-version=7.1-preview.1" \
  -H "Authorization: Basic $B64_PAT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "dev",
    "description": "Development environment"
  }'
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"
$body = @{
    name = "dev"
    description = "Development environment for foundry-cicd"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"
```

**Response** (200 OK):
```json
{
  "id": 456,
  "name": "dev",
  "description": "Development environment for foundry-cicd",
  "createdBy": {
    "displayName": "User Name",
    "id": "user-guid"
  },
  "createdOn": "2026-01-07T12:00:00Z"
}
```

**Note**: Environment approvals and checks must be configured via the Azure DevOps portal. The API has limited support for approval configuration.

---

## Build API

### Base URL
```
https://dev.azure.com/{organization}/{project}/_apis/build
```

### API Version
- **Current**: 7.1

---

### 1. Queue Build

**Endpoint**: `POST /_apis/build/builds`

**Description**: Queue a new build

**Request Body**:
```json
{
  "definition": {
    "id": 123
  },
  "sourceBranch": "refs/heads/main",
  "parameters": "{}"
}
```

**Example Request**:

```bash
curl -X POST \
  "https://dev.azure.com/{organization}/{project}/_apis/build/builds?api-version=7.1" \
  -H "Authorization: Basic $B64_PAT" \
  -H "Content-Type: application/json" \
  -d '{
    "definition": {
      "id": 123
    },
    "sourceBranch": "refs/heads/main"
  }'
```

```powershell
$uri = "https://dev.azure.com/$organization/$project/_apis/build/builds?api-version=7.1"
$body = @{
    definition = @{
        id = $pipelineId
    }
    sourceBranch = "refs/heads/main"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"
```

---

## Complete Examples

### Example 1: Complete Repository Creation and Pipeline Setup

```powershell
# Configuration
$organization = "your-organization"
$project = "your-project"
$pat = $env:AZURE_DEVOPS_PAT

# Encode PAT
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

# 1. Create Repository
$repoUri = "https://dev.azure.com/$organization/$project/_apis/git/repositories?api-version=7.1"
$repoBody = @{
    name = "foundry-cicd"
    project = @{ name = $project }
} | ConvertTo-Json

$repo = Invoke-RestMethod -Uri $repoUri -Method Post -Headers $headers -Body $repoBody
Write-Host "✓ Repository created: $($repo.remoteUrl)"

# 2. Create Service Connection
$scUri = "https://dev.azure.com/$organization/$project/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
$scBody = @{
    name = "azure-foundry-dev"
    type = "azurerm"
    url = "https://management.azure.com/"
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
        subscriptionName = "Your Subscription"
        environment = "AzureCloud"
    }
} | ConvertTo-Json -Depth 10

$sc = Invoke-RestMethod -Uri $scUri -Method Post -Headers $headers -Body $scBody -ContentType "application/json"
Write-Host "✓ Service connection created: $($sc.name)"

# 3. Create Variable Group
$vgUri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
$vgBody = @{
    name = "aifoundrycicd-dev-vars"  # Pattern: {projectName}-dev-vars
    type = "Vsts"
    variables = @{
        "AZURE_AI_PROJECT_DEV" = @{ value = "https://dev-project.api.azureml.ms"; isSecret = $false }
        "AZURE_SERVICE_CONNECTION_DEV" = @{ value = "azure-foundry-dev"; isSecret = $false }
    }
} | ConvertTo-Json -Depth 10

$vg = Invoke-RestMethod -Uri $vgUri -Method Post -Headers $headers -Body $vgBody -ContentType "application/json"
Write-Host "✓ Variable group created: $($vg.name)"

# 4. Create Pipeline
$pipelineUri = "https://dev.azure.com/$organization/$project/_apis/pipelines?api-version=7.1-preview.1"
$pipelineBody = @{
    name = "Foundry Agent Creation"
    folder = "\"
    configuration = @{
        type = "yaml"
        path = ".azure-pipelines/create-agent-pipeline.yml"
        repository = @{
            id = $repo.id
            name = "foundry-cicd"
            type = "azureReposGit"
        }
    }
} | ConvertTo-Json -Depth 10

$pipeline = Invoke-RestMethod -Uri $pipelineUri -Method Post -Headers $headers -Body $pipelineBody -ContentType "application/json"
Write-Host "✓ Pipeline created: $($pipeline.name)"

Write-Host "`n✅ All resources created successfully!"
```

---

### Example 2: Python Complete Migration Script

```python
import requests
import base64
import json
import os

# Configuration
ORGANIZATION = "your-organization"
PROJECT = "your-project"
PAT = os.environ.get("AZURE_DEVOPS_PAT")

# Encode PAT
b64_pat = base64.b64encode(f":{PAT}".encode()).decode()
headers = {
    "Authorization": f"Basic {b64_pat}",
    "Content-Type": "application/json"
}

def create_repository(name):
    url = f"https://dev.azure.com/{ORGANIZATION}/{PROJECT}/_apis/git/repositories?api-version=7.1"
    body = {
        "name": name,
        "project": {"name": PROJECT}
    }
    response = requests.post(url, headers=headers, json=body)
    response.raise_for_status()
    return response.json()

def create_service_connection(name, env):
    url = f"https://dev.azure.com/{ORGANIZATION}/{PROJECT}/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
    body = {
        "name": f"azure-foundry-{env}",
        "type": "azurerm",
        "url": "https://management.azure.com/",
        "authorization": {
            "parameters": {
                "serviceprincipalid": os.environ["AZURE_CLIENT_ID"],
                "serviceprincipalkey": os.environ["AZURE_CLIENT_SECRET"],
                "tenantid": os.environ["AZURE_TENANT_ID"]
            },
            "scheme": "ServicePrincipal"
        },
        "data": {
            "subscriptionId": os.environ["AZURE_SUBSCRIPTION_ID"],
            "subscriptionName": "Your Subscription",
            "environment": "AzureCloud"
        }
    }
    response = requests.post(url, headers=headers, json=body)
    response.raise_for_status()
    return response.json()

def create_variable_group(name, env, variables):
    url = f"https://dev.azure.com/{ORGANIZATION}/{PROJECT}/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
    body = {
        "name": f"foundry-{env}-vars",
        "type": "Vsts",
        "variables": variables
    }
    response = requests.post(url, headers=headers, json=body)
    response.raise_for_status()
    return response.json()

def create_pipeline(name, yaml_path, repo_id):
    url = f"https://dev.azure.com/{ORGANIZATION}/{PROJECT}/_apis/pipelines?api-version=7.1-preview.1"
    body = {
        "name": name,
        "folder": "\\",
        "configuration": {
            "type": "yaml",
            "path": yaml_path,
            "repository": {
                "id": repo_id,
                "name": "foundry-cicd",
                "type": "azureReposGit"
            }
        }
    }
    response = requests.post(url, headers=headers, json=body)
    response.raise_for_status()
    return response.json()

# Execute migration
if __name__ == "__main__":
    print("Starting migration...")
    
    # Create repository
    repo = create_repository("foundry-cicd")
    print(f"✓ Repository created: {repo['name']}")
    
    # Create service connections
    for env in ["dev", "test", "prod"]:
        sc = create_service_connection("azure-foundry", env)
        print(f"✓ Service connection created: {sc['name']}")
    
    # Create variable groups
    for env in ["dev", "test", "prod"]:
        variables = {
            f"AZURE_AI_PROJECT_{env.upper()}": {
                "value": f"https://{env}-project.api.azureml.ms",
                "isSecret": False
            }
        }
        vg = create_variable_group("foundry", env, variables)
        print(f"✓ Variable group created: {vg['name']}")
    
    # Create pipelines
    pipeline1 = create_pipeline(
        "Foundry Agent Creation",
        ".azure-pipelines/create-agent-pipeline.yml",
        repo["id"]
    )
    print(f"✓ Pipeline created: {pipeline1['name']}")
    
    print("\n✅ Migration completed successfully!")
```

---

## Rate Limits

Azure DevOps Services has rate limits:

- **API Calls**: 200 requests per minute per user
- **TSTUs (Team Services ThroughputUnits)**: Complex calculation based on operations

**Best Practices**:
- Implement exponential backoff
- Cache responses when possible
- Batch operations where supported
- Monitor rate limit headers

---

## Error Codes

Common HTTP status codes:

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 200 | OK | Request succeeded |
| 201 | Created | Resource created successfully |
| 204 | No Content | Delete/update succeeded |
| 400 | Bad Request | Invalid request body or parameters |
| 401 | Unauthorized | PAT invalid or expired |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Resource already exists |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Azure DevOps service error |

---

## Additional Resources

### Official Documentation
- [Azure DevOps REST API Overview](https://learn.microsoft.com/en-us/rest/api/azure/devops/)
- [Git API Reference](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/)
- [Pipelines API Reference](https://learn.microsoft.com/en-us/rest/api/azure/devops/pipelines/)
- [Service Endpoints API](https://learn.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/)

### Tools
- [Postman Collection for Azure DevOps](https://www.postman.com/microsoft-azure)
- [Azure DevOps CLI](https://learn.microsoft.com/en-us/azure/devops/cli/)
- [REST API Explorer](https://docs.microsoft.com/en-us/rest/api/azure/devops/)

---

**Document Version**: 1.0  
**API Version**: 7.1  
**Last Updated**: January 7, 2026
