# Azure DevOps CI/CD Pipeline for AI Agent Deployment

This directory contains Azure DevOps pipelines for deploying and testing AI agents across multiple environments (dev, test, production).

## 🚀 Quick Start

**New to Azure DevOps Pipelines?** Follow these steps:

1. **Prerequisites**: Ensure you have Azure AI Project and OpenAI resources for each environment
2. **Setup**: Complete Steps 1-3 in [Setting Up Pipelines](#3-setting-up-pipelines-in-azure-devops) section
3. **Create Pipeline**: Follow Step 4 to create your first pipeline
4. **Run**: Execute the pipeline and monitor results

**Estimated Setup Time**: 30-45 minutes for first-time setup

---

## Pipeline Files

### 1. `createagentpipeline.yml`
**Purpose**: Agent creation and deployment pipeline across dev, test, and production environments.

**Stages**:
- **Build**: Validates Python syntax, installs dependencies, publishes artifacts
- **Dev**: Creates agent in development environment using `createagent.py`
- **Test**: Creates agent in test environment
- **Prod**: Creates agent in production environment (requires approval)

**Use this when**: You need to create or update agents across all environments.

### 2. `agentconsumptionpipeline.yml`
**Purpose**: Comprehensive testing and evaluation pipeline for existing agents.

**Stages**:
- **Build**: Validates all Python scripts (createagent.py, exagent.py, agenteval.py, redteam.py)
- **Dev**: Tests existing agent with `exagent.py`
- **Test**: Runs agent evaluation (`agenteval.py`) and red team security testing (`redteam.py`)
- **Prod**: Verifies production agent functionality

**Use this when**: You want to test, evaluate, and security-test existing deployed agents without creating new ones.

## Prerequisites

### 1. Azure Resources
Create the following resources for each environment (dev, test, prod):
- Azure AI Project
- Azure OpenAI resource with deployments
- Service Principal for authentication

### 2. Azure DevOps Setup

#### A. Service Connections
Create Azure Resource Manager service connections for each environment:
1. Go to Project Settings → Service Connections
2. Create service connections named:
   - `AZURE_SERVICE_CONNECTION_DEV`
   - `AZURE_SERVICE_CONNECTION_TEST`
   - `AZURE_SERVICE_CONNECTION_PROD`

#### B. Variable Groups
Create three variable groups with the following variables:

**Variable Group: `agent-dev-vars`**
```
AZURE_AI_PROJECT_DEV=<your-dev-ai-project-endpoint>
AZURE_OPENAI_ENDPOINT_DEV=<your-dev-openai-endpoint>
AZURE_OPENAI_KEY_DEV=<your-dev-openai-key>
AZURE_OPENAI_API_VERSION_DEV=2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT_DEV=gpt-4o
AZURE_AI_PROJECT_ENDPOINT_DEV=<your-dev-project-endpoint>
AZURE_SERVICE_CONNECTION_DEV=<your-dev-service-connection-name>
```

**Variable Group: `agent-test-vars`**
```
AZURE_AI_PROJECT_TEST=<your-test-ai-project-endpoint>
AZURE_OPENAI_ENDPOINT_TEST=<your-test-openai-endpoint>
AZURE_OPENAI_KEY_TEST=<your-test-openai-key>
AZURE_OPENAI_API_VERSION_TEST=2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT_TEST=gpt-4o
AZURE_AI_PROJECT_ENDPOINT_TEST=<your-test-project-endpoint>
AZURE_SERVICE_CONNECTION_TEST=<your-test-service-connection-name>
```

**Variable Group: `agent-prod-vars`**
```
AZURE_AI_PROJECT_PROD=<your-prod-ai-project-endpoint>
AZURE_OPENAI_ENDPOINT_PROD=<your-prod-openai-endpoint>
AZURE_OPENAI_KEY_PROD=<your-prod-openai-key>
AZURE_OPENAI_API_VERSION_PROD=2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT_PROD=gpt-4o
AZURE_AI_PROJECT_ENDPOINT_PROD=<your-prod-project-endpoint>
AZURE_SERVICE_CONNECTION_PROD=<your-prod-service-connection-name>
```

**Global Variables** (add to pipeline or variable group):
```
AZURE_CLIENT_ID=<service-principal-client-id>
AZURE_TENANT_ID=<azure-tenant-id>
AZURE_SUBSCRIPTION_ID=<azure-subscription-id>
```

#### C. Environments
Create three environments with approval gates:
1. Go to Pipelines → Environments
2. Create environments:
   - `dev` (no approvals required)
   - `test` (optional: add approvals)
   - `production` (recommended: add approvals and checks)

To add approval gates:
1. Select the environment
2. Click on "Approvals and checks"
3. Add "Approvals" and specify required approvers

---

## CRITICAL VARIABLE COMPARISON

### ⚠️ Variables from sample.env (Source Truth)
From the source repository's `sample.env`:
```
AZURE_AI_PROJECT=""
AZURE_OPENAI_KEY=""
AZURE_OPENAI_ENDPOINT="https://aoaoresource.openai.azure.com/"
AZURE_OPENAI_DEPLOYMENT="gpt-4.1"
AZURE_AI_MODEL_DEPLOYMENT_NAME="gpt-4.1"                     ⚠️ IMPORTANT!
AZURE_AI_PROJECT_ENDPOINT="https://aoaoresource.services.ai.azure.com/api/projects/projectname"
ENABLE_SENSITIVE_DATA=true
ENABLE_OTEL=true
AZURE_AI_SEARCH_INDEX_NAME="<indexname>"
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME="gpt-4.1"
AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME="gpt-5.2"
AZURE_OPENAI_API_VERSION="2025-01-01-preview"
```

### 🔍 Variable Discrepancies

**MISSING from Official Guide but REQUIRED by code:**
1. `AZURE_AI_MODEL_DEPLOYMENT_NAME` - Code uses this for model_id parameter
2. `AZURE_OPENAI_CHAT_DEPLOYMENT_NAME` - May be used for chat-specific operations
3. `AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME` - May be used for response generation
4. `AZURE_AI_SEARCH_INDEX_NAME` - If using search capabilities
5. `ENABLE_SENSITIVE_DATA` - Feature flag for sensitive data handling
6. `ENABLE_OTEL` - OpenTelemetry configuration

**DIFFERENT NAMING PATTERNS:**
- Official guide uses suffix pattern: `AZURE_OPENAI_ENDPOINT_DEV`
- Code expects base names: `AZURE_OPENAI_ENDPOINT`
- Pipeline must map: `$(AZURE_OPENAI_ENDPOINT_DEV)` → `export AZURE_OPENAI_ENDPOINT="$(AZURE_OPENAI_ENDPOINT_DEV)"`

**KEY INSIGHT:**
The agent-framework library looks for `AZURE_AI_MODEL_DEPLOYMENT_NAME` environment variable to populate the `model_id` parameter. This is NOT documented in the official Azure DevOps guide but IS required in sample.env.

---

## Variable Mapping Strategy

### In Variable Groups (suffixed with _DEV/_TEST/_PROD):
```
AZURE_AI_PROJECT_DEV
AZURE_OPENAI_ENDPOINT_DEV
AZURE_OPENAI_DEPLOYMENT_DEV
AZURE_AI_MODEL_DEPLOYMENT_NAME_DEV        ⚠️ ADD THIS!
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME_DEV     ⚠️ ADD THIS if needed
AZURE_AI_PROJECT_ENDPOINT_DEV
AZURE_OPENAI_API_VERSION_DEV
```

### In Pipeline (export without suffix for code):
```yaml
export AZURE_AI_PROJECT="$(AZURE_AI_PROJECT_DEV)"
export AZURE_OPENAI_ENDPOINT="$(AZURE_OPENAI_ENDPOINT_DEV)"
export AZURE_OPENAI_DEPLOYMENT="$(AZURE_OPENAI_DEPLOYMENT_DEV)"
export AZURE_AI_MODEL_DEPLOYMENT_NAME="$(AZURE_AI_MODEL_DEPLOYMENT_NAME_DEV)"  ⚠️ CRITICAL!
export AZURE_AI_PROJECT_ENDPOINT="$(AZURE_AI_PROJECT_ENDPOINT_DEV)"
export AZURE_OPENAI_API_VERSION="$(AZURE_OPENAI_API_VERSION_DEV)"
```

---

## Setting Up Pipelines in Azure DevOps

[Rest of the original documentation continues...]
