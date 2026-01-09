---
name: starter-execution
description: Orchestrates complete Azure AI Foundry deployment to Azure DevOps. Coordinates repository-setup, service-connection-setup, environment-setup, pipeline-setup, and deployment-validation skills. Use when deploying the complete Azure AI Foundry starter template end-to-end.
license: Apache-2.0
---

# Azure AI Foundry Starter Execution Orchestrator

Orchestrates the complete deployment of the Azure AI Foundry starter template to Azure DevOps by coordinating five specialized skills.

## Overview

End-to-end orchestration skill that coordinates five specialized skills to deploy the Azure AI Foundry starter template from `template-app/` to Azure DevOps.

### Prerequisites

Before using this orchestrator:
1. ✅ **[configuration-management](../configuration-management)** - Configuration must be set up FIRST
2. ✅ **[resource-creation](../resource-creation)** - Azure resources and Service Principal must exist
3. ✅ **[environment-validation](../environment-validation)** - Environment prerequisites validated
4. ✅ **Bearer token valid** - 30+ minutes remaining for deployment
5. ✅ **Azure DevOps permissions** - Contributor access to target project

### What Gets Created

- **1 Repository**: `azure-ai-foundry-app` with template application code
- **3 Service Connections**: dev/test/prod with Workload Identity Federation (no secrets!)
- **3 Variable Groups**: `{projectName}-{env}-vars` with environment-specific configuration (projectName from config)
- **3 Environments**: dev, test, production with approval gates
- **3+ Pipelines**: Agent creation, evaluation, and red team testing

### Orchestration Flow

This orchestrator executes five specialized skills in sequence:

1. **[repository-setup](../repository-setup)** - Create Azure DevOps repository and push template code
2. **[service-connection-setup](../service-connection-setup)** - Configure service connections with federated credentials
3. **[environment-setup](../environment-setup)** - Create variable groups and environments
4. **[pipeline-setup](../pipeline-setup)** - Create CI/CD pipelines from YAML templates
5. **[deployment-validation](../deployment-validation)** - Validate complete deployment

## Usage

```powershell
# Complete deployment (all phases)
cd .github/skills/starter-execution
# Follow Phase 1-6 commands below

# Or execute individual skills as needed
cd .github/skills/repository-setup
# See individual skill documentation
```

## Deployment Workflow

Execute these six phases in sequence for successful deployment:

### Phase 1: Authentication & Configuration

```powershell
# Load configuration
. ./.github/skills/configuration-management/config-functions.ps1
$config = Get-StarterConfig

# Extract values
$org = $config.azureDevOps.organizationUrl
$project = $config.azureDevOps.projectName

# Login to Azure
az login

# Set subscription
az account set --subscription $config.azure.subscriptionId

# Get bearer token (valid for ~1 hour)
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN

# Configure Azure DevOps CLI
az devops configure --defaults organization=$org project=$project

Write-Host "✅ Authentication complete"
```

### Phase 2: Repository Setup

**Skill**: [repository-setup](../repository-setup)

**Purpose**: Create Azure DevOps repository and push template application code

**Key Actions**:
- Create repository `azure-ai-foundry-app`
- Initialize git and push template code from `template-app/`
- Create `.env` file from `sample.env`

**Direct Usage**:
```powershell
cd .github/skills/repository-setup
# Follow skill documentation for detailed steps
```

**Quick Validation**:
```powershell
az repos show --repository "azure-ai-foundry-app" -o table
```

**Troubleshooting**: See [repository-setup/SKILL.md](../repository-setup/SKILL.md)

### Phase 3: Service Connection Setup

**Skill**: [service-connection-setup](../service-connection-setup)

**Purpose**: Create service connections with Workload Identity Federation (passwordless, no secrets!)

**Key Actions**:
- Create 3 service connections: `azure-foundry-dev`, `azure-foundry-test`, `azure-foundry-prod`
- Configure federated credentials on Service Principal
- Authorize connections for all pipelines
- Verify RBAC roles (Contributor + Cognitive Services User)

**Critical**: Federated credential issuer/subject format must match Azure DevOps exactly!

**Direct Usage**:
```powershell
cd .github/skills/service-connection-setup
# Follow skill documentation for detailed steps
```

**Quick Validation**:
```powershell
az devops service-endpoint list -o table
az ad app federated-credential list --id $config.servicePrincipal.appId -o table
```

**Troubleshooting**: See [service-connection-setup/SKILL.md](../service-connection-setup/SKILL.md)

### Phase 4: Environment Setup

**Skill**: [environment-setup](../environment-setup)

**Purpose**: Create variable groups and environments for all deployment stages

**Key Actions**:
- Create 3 variable groups: `{projectName}-dev-vars`, `{projectName}-test-vars`, `{projectName}-prod-vars` (using config.naming.projectName)
- Configure environment-specific variables (endpoints, model names, connection strings)
- Create 3 environments: `dev`, `test`, `production`
- Authorize variable groups for pipeline access

**Critical**: Variable group names must match pipeline YAML exactly!

**Direct Usage**:
```powershell
cd .github/skills/environment-setup
# Follow skill documentation for detailed steps
```

**Quick Validation**:
```powershell
az pipelines variable-group list -o table
az pipelines environment list -o table
```

**Troubleshooting**: See [environment-setup/SKILL.md](../environment-setup/SKILL.md)

### Phase 5: Pipeline Setup

**Skill**: [pipeline-setup](../pipeline-setup)

**Purpose**: Create CI/CD pipelines from template YAML files

**Key Actions**:
- **Update pipeline YAML files** - Automatically replaces `REPLACE_WITH_YOUR_PROJECTNAME` with `config.naming.projectName`
- **Commit and push changes** - Updates YAML files in repository with correct variable group names
- Create pipeline: `Azure AI Foundry - Create Agent`
- Create pipeline: `Azure AI Foundry - Agent Evaluation`
- Create pipeline: `Azure AI Foundry - Red Team`
- Link pipelines to repository branch
- Configure with `--skip-first-run` flag

**Critical**: Automated script updates YAML files to match variable group names created in Phase 4!

**Direct Usage**:
```powershell
cd .github/skills/pipeline-setup
./scripts/create-pipelines.ps1 -UseConfig
```
# Follow skill documentation for detailed steps
```

**Quick Validation**:
```powershell
az pipelines list -o table
```

**Troubleshooting**: See [pipeline-setup/SKILL.md](../pipeline-setup/SKILL.md)

### Phase 6: Deployment Validation

**Skill**: [deployment-validation](../deployment-validation)

**Purpose**: Validate complete deployment and readiness for pipeline execution

**Key Actions**:
- Validate repository exists and has code
- Validate service connections and federated credentials
- Validate variable groups and environments
- Validate pipelines are configured correctly
- Verify RBAC permissions (Contributor + Cognitive Services User)
- (Optional) Execute first pipeline run

**Direct Usage**:
```powershell
cd .github/skills/deployment-validation
# Follow skill documentation for detailed steps
```

**Quick Validation**:
```powershell
# Comprehensive validation
az repos list -o table
az devops service-endpoint list -o table
az pipelines variable-group list -o table
az pipelines environment list -o table
az pipelines list -o table
```

**First Pipeline Run**:
```powershell
# Run Create Agent pipeline
$pipelineId = az pipelines list --query "[?name=='Azure AI Foundry - Create Agent'].id" -o tsv
az pipelines run --id $pipelineId

# Monitor at: $config.azureDevOps.organizationUrl/$config.azureDevOps.projectName/_build
```

**Troubleshooting**: See [deployment-validation/SKILL.md](../deployment-validation/SKILL.md)

## Specialized Skills

This orchestrator delegates to five specialized skills:

### 1. Repository Setup Skill
**Location**: [../repository-setup](../repository-setup)  
**Purpose**: Create Azure DevOps repository and push template application code  
**When to Use**: Initial deployment or repository recreation

### 2. Service Connection Setup Skill
**Location**: [../service-connection-setup](../service-connection-setup)  
**Purpose**: Configure service connections with Workload Identity Federation  
**When to Use**: Initial deployment, fix federated credentials, add new environments

### 3. Environment Setup Skill
**Location**: [../environment-setup](../environment-setup)  
**Purpose**: Create variable groups and environments  
**When to Use**: Initial deployment, update variables, add new environments

### 4. Pipeline Setup Skill
**Location**: [../pipeline-setup](../pipeline-setup)  
**Purpose**: Create CI/CD pipelines from YAML templates  
**When to Use**: Initial deployment, add new pipelines, fix pipeline configuration

### 5. Deployment Validation Skill
**Location**: [../deployment-validation](../deployment-validation)  
**Purpose**: Validate complete deployment readiness  
**When to Use**: After each phase, troubleshooting, pre-deployment verification

## Troubleshooting

For detailed troubleshooting, refer to the specific skill documentation:

- **Repository Issues** → [repository-setup/SKILL.md](../repository-setup/SKILL.md#troubleshooting)
- **Service Connection Issues** → [service-connection-setup/SKILL.md](../service-connection-setup/SKILL.md#troubleshooting)
- **Variable/Environment Issues** → [environment-setup/SKILL.md](../environment-setup/SKILL.md#troubleshooting)
- **Pipeline Issues** → [pipeline-setup/SKILL.md](../pipeline-setup/SKILL.md#troubleshooting)
- **Validation Issues** → [deployment-validation/SKILL.md](../deployment-validation/SKILL.md#troubleshooting)

### Common Issues

**Symptom**: `AADSTS70021: No matching federated identity record found`  
**Cause**: Federated credential issuer/subject mismatch  
**Solution**: See [service-connection-setup troubleshooting](../service-connection-setup/SKILL.md#1-federated-credential-issuersubject-mismatch)

**Symptom**: `The pipeline is not valid. Could not find service connection`  
**Cause**: Service connection not authorized for pipeline use  
**Solution**: See [service-connection-setup troubleshooting](../service-connection-setup/SKILL.md#2-service-connection-not-authorized)

**Symptom**: `Variable group name contains invalid characters`  
**Cause**: Invalid characters in variable group name  
**Solution**: See [environment-setup troubleshooting](../environment-setup/SKILL.md#1-variable-group-name-contains-invalid-characters)

**Symptom**: `401 Unauthorized` errors  
**Cause**: Bearer token expired (valid for ~1 hour)  
**Solution**:
```powershell
$env:ADO_TOKEN = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" -o tsv
$env:AZURE_DEVOPS_EXT_PAT = $env:ADO_TOKEN
```

**Complete Troubleshooting Guide**: [docs/troubleshooting.md](../../../docs/troubleshooting.md)

## Best Practices

### Execution Strategy
- **Follow the phase order**: Always execute phases 1-6 in sequence
- **One environment at a time**: Test dev thoroughly before test/prod
- **Use modular skills**: Run individual skills for easier troubleshooting
- **Validate early and often**: Use deployment-validation after each phase

### Security
- **Workload Identity Federation**: Zero secrets stored - use federated credentials
- **RBAC principle**: Contributor + Cognitive Services User roles only (least privilege)
- **Configuration management**: Store starter-config.json securely (add to .gitignore)
- **Token management**: Refresh bearer token every 30-45 minutes

### Configuration
- **Use starter-config.json**: Centralized configuration for consistency
- **Variable group naming**: Must match pipeline YAML exactly
- **Federated credential format**: Must match Azure DevOps issuer/subject precisely
- **Document customizations**: Track any template modifications

### Deployment
- **Skip first run**: Use `--skip-first-run` when creating pipelines for control
- **Test incrementally**: Validate each phase before proceeding
- **Monitor first execution**: Watch logs for the initial Create Agent pipeline run
- **Use feedback mechanism**: Report issues via [template-app/FEEDBACK.md](../../../template-app/FEEDBACK.md)

## Related Skills

### Prerequisite Skills (Run Before This Orchestrator)
- **[configuration-management](../configuration-management)** - Set up centralized configuration (REQUIRED FIRST)
- **[resource-creation](../resource-creation)** - Create Azure resources and Service Principal (REQUIRED)
- **[environment-validation](../environment-validation)** - Validate prerequisites (RECOMMENDED)

### Orchestrated Skills (Called By This Orchestrator)
- **[repository-setup](../repository-setup)** - Create repository and push template code
- **[service-connection-setup](../service-connection-setup)** - Configure service connections with federated credentials
- **[environment-setup](../environment-setup)** - Create variable groups and environments
- **[pipeline-setup](../pipeline-setup)** - Create CI/CD pipelines
- **[deployment-validation](../deployment-validation)** - Validate complete deployment

## Documentation

- **[docs/starter-guide.md](../../../docs/starter-guide.md)** - Complete deployment guide with screenshots
- **[docs/quick-start.md](../../../docs/quick-start.md)** - Fast track deployment guide
- **[docs/execution-guide.md](../../../docs/execution-guide.md)** - GitHub Copilot usage patterns
- **[docs/troubleshooting.md](../../../docs/troubleshooting.md)** - All 12 critical lessons learned
- **[docs/az-devops-cli-reference.md](../../../docs/az-devops-cli-reference.md)** - Azure DevOps CLI command reference
- **[template-app/README.md](../../../template-app/README.md)** - Template application documentation
- **[template-app/FEEDBACK.md](../../../template-app/FEEDBACK.md)** - Submit feedback and issues
