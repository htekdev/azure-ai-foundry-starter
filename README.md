# Azure AI Foundry Starter

> **Production-ready template for deploying AI agents to Azure AI Foundry with automated CI/CD pipelines through Azure DevOps**

## 🎯 What is This?

This starter template provides everything you need to deploy AI agents to **Azure AI Foundry** with full **Azure DevOps CI/CD automation**. It includes:

- ✅ **Complete AI agent application** ready to deploy
- ✅ **Multi-environment pipelines** (DEV → TEST → PROD)
- ✅ **Zero-secrets architecture** using Workload Identity Federation
- ✅ **Automated infrastructure** with Azure CLI scripts
- ✅ **Comprehensive documentation** and troubleshooting guides
- ✅ **GitHub Copilot agent integration** for guided setup

Deploy your first AI agent in **under 30 minutes** with automated resource provisioning, service principal setup, and CI/CD pipeline configuration.

---

## 🚀 Getting Started

Choose your preferred setup method:

### Option 1: Automated Setup Script (Recommended)

Run the automated setup script with your deployment details:

```powershell
.\scripts\setup.ps1 `
    -ProjectName "foundrycicd" `
    -ADOProjectName "foundrycicd" `
    -OrganizationUrl "https://dev.azure.com/your-org" `
    -TenantId "YOUR_TENANT_ID" `
    -SubscriptionId "YOUR_SUBSCRIPTION_ID"
```

**Parameters:**
- **ProjectName**: Azure resource naming prefix (e.g., `foundrycicd` creates `rg-foundrycicd-dev`, `sp-foundrycicd-cicd`, `foundrycicd-dev-aiservices`)
  - Must be lowercase, alphanumeric, and hyphens only (8-15 characters recommended)
- **ADOProjectName**: Azure DevOps project name (can be same as ProjectName or different)
  - If omitted, defaults to ProjectName value
- **OrganizationUrl**: Your Azure DevOps organization URL
- **TenantId**: Azure Active Directory tenant ID
- **SubscriptionId**: Azure subscription ID

**What it does:**
- Creates all Azure resources (resource groups, service principal, AI Foundry projects)
- Sets up Azure DevOps project, service connections, variable groups, environments, and pipelines
- Configures Workload Identity Federation (no secrets!)
- Validates the complete deployment

**Time:** ~10-15 minutes

---

### Option 2: GitHub Copilot Custom Agent (Interactive)

Ask the Azure AI Foundry Deployment Agent for help:

```
@workspace I want to deploy the Azure AI Foundry starter
```

The agent will:
- Guide you through each step interactively
- Explain what's happening at each phase
- Help troubleshoot any issues
- Validate your deployment

**Perfect for:** Learning the process, understanding the architecture, customizing the setup

---

### Option 3: Manual Setup Guide (Step-by-Step)

Follow the comprehensive setup guide with detailed explanations:

📖 **[SETUP_GUIDE.md](SETUP_GUIDE.md)**

**Includes:**
- Prerequisites checklist
- Phase-by-phase instructions (Configuration → Azure Resources → Azure DevOps → Validation)
- Both automated scripts and manual portal steps
- Troubleshooting for common issues
- Verification commands at each step

**Perfect for:** Understanding every detail, manual control, learning Azure DevOps

---

## 📋 Prerequisites

Before starting, ensure you have:

### Required Tools
- **Azure CLI** (2.50+) - [Install](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **PowerShell** (7.0+) - [Install](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- **Git** (2.30+) - [Install](https://git-scm.com/downloads)
- **Azure DevOps CLI extension** - Install: `az extension add --name azure-devops`

### Required Permissions
- **Azure Subscription**: Contributor role + ability to create service principals
- **Azure DevOps**: Project Administrator role

### Information You'll Need
- **ProjectName** (e.g., `foundrycicd`) - Azure resource naming prefix
  - Used to name Azure resources: `rg-foundrycicd-dev`, `sp-foundrycicd-cicd`, etc.
  - Must be lowercase, alphanumeric, and hyphens only
  - Recommended: 8-15 characters
  - Examples: `foundrycicd`, `myai-project`, `ai-demo-01`
- **ADOProjectName** (optional) - Azure DevOps project name
  - Can be same as ProjectName or different (e.g., more descriptive name)
  - If omitted, defaults to ProjectName value
- **Azure subscription ID** - Found in Azure Portal → Subscriptions
- **Azure tenant ID** - Found in Azure Portal → Azure Active Directory → Properties
- **Azure DevOps organization URL** - Your organization URL (e.g., `https://dev.azure.com/your-org`)

**Quick verification:**
```powershell
az --version          # Check Azure CLI
az login              # Login to Azure
az account show       # Verify subscription
```

---

## 💡 What Gets Created

The `ProjectName` parameter is used for Azure resource naming (as prefix), and `ADOProjectName` (or ProjectName if not specified) is used for the Azure DevOps project name.

For example, with `ProjectName="foundrycicd"` and `ADOProjectName="foundrycicd"`:

### Azure Resources
(Named using ProjectName as **prefix**)
- **3 Resource Groups**:
  - `rg-foundrycicd-dev`
  - `rg-foundrycicd-test`
  - `rg-foundrycicd-prod`
- **Service Principal**: `sp-foundrycicd-cicd` with Workload Identity Federation
- **AI Services** resources (kind: AIServices):
  - `foundrycicd-dev-aiservices`
  - `foundrycicd-test-aiservices`
  - `foundrycicd-prod-aiservices`
- **AI Foundry Projects** for each environment
- **RBAC role assignments** (Contributor, Cognitive Services User)

### Azure DevOps Resources
(Named using ProjectName as **base name**)
- **Azure DevOps Project**: `foundrycicd` (exact ProjectName value)
- **3 Service Connections** with federated credentials:
  - `foundrycicd-dev`
  - `foundrycicd-test`
  - `foundrycicd-prod`
- **3 Variable Groups**: `foundrycicd-dev-vars`, `foundrycicd-test-vars`, `foundrycicd-prod-vars`
- **3 Environments**: `dev`, `test`, `production` (with approval gates)
- **CI/CD Pipelines** for agent deployment, testing, and security

---

## ✨ Key Features

### 🔐 Zero-Secrets Architecture
Uses **Workload Identity Federation** for authentication between Azure DevOps and Azure - no passwords or secrets stored anywhere.

### 🚀 Multi-Stage Pipelines
Automated deployments through DEV → TEST → PROD with approval gates and environment-specific configurations.

### 🤖 GitHub Copilot Integration
Custom agents and skills provide intelligent, context-aware guidance throughout the deployment process.

### 📊 Battle-Tested
Refined through 22+ real pipeline iterations with all critical issues documented and resolved.

### 🎯 Production-Ready
Includes agent evaluation, red teaming, and security best practices built into the CI/CD pipeline.

---

## 📚 Documentation

### Getting Started
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Complete setup walkthrough
- [docs/quick-start.md](docs/quick-start.md) - Quick start guide
- [docs/execution-guide.md](docs/execution-guide.md) - Using with GitHub Copilot

### Understanding the System
- [docs/architecture.md](docs/architecture.md) - System architecture and design
- [docs/deployment-guide.md](docs/deployment-guide.md) - Detailed deployment information
- [docs/naming-convention.md](docs/naming-convention.md) - Resource naming patterns

### Reference
- [docs/api-reference.md](docs/api-reference.md) - Azure AI SDK documentation
- [docs/az-devops-cli-reference.md](docs/az-devops-cli-reference.md) - Azure DevOps CLI
- [docs/troubleshooting.md](docs/troubleshooting.md) - Common issues and solutions
- [docs/README.md](docs/README.md) - Full documentation index

---

## 🏗️ Repository Structure

```
├── scripts/              # Automated setup scripts
│   └── setup.ps1        # Main setup script
├── .github/
│   ├── agents/          # GitHub Copilot custom agents
│   └── skills/          # Deployment skills (modular scripts)
│       ├── configuration-management/
│       ├── resource-creation/
│       ├── service-connection-setup/
│       ├── environment-setup/
│       ├── pipeline-setup/
│       └── deployment-validation/
├── .azure-pipelines/    # Azure DevOps pipeline YAML
│   ├── createagentpipeline.yml
│   └── agentconsumptionpipeline.yml
├── src/                 # AI agent application code
│   ├── agents/          # Agent implementations
│   ├── evaluation/      # Evaluation logic
│   └── security/        # Security scanning
├── docs/                # Documentation
├── starter-config.json  # Deployment configuration
└── README.md            # This file
```

---

## 🎯 Next Steps After Setup

1. **Review your configuration**: Check `starter-config.json`
2. **Visit Azure DevOps**: See your pipelines and environments
3. **Run your first deployment**: Trigger the "Create Agent" pipeline
4. **Monitor in Azure AI Foundry**: View your deployed agent at [ai.azure.com](https://ai.azure.com)
5. **Customize**: Modify agent code in [src/agents/createagent.py](src/agents/createagent.py)

---

## 🔧 Common Commands

```powershell
# Re-run setup (replace with your details)
.\scripts\setup.ps1 -ProjectName "foundrycicd" -ADOProjectName "foundrycicd" -OrganizationUrl "https://dev.azure.com/myorg" -TenantId "..." -SubscriptionId "..."

# Validate deployment
.\.github\skills\deployment-validation\scripts\validate-deployment.ps1 -UseConfig -Environment 'all'

# Run a pipeline
az pipelines run --name "Azure AI Foundry - Create Agent"

# Check pipeline status
az pipelines runs list --top 5

# Clean up resources
.\.github\skills\cleanup-resources\scripts\cleanup-resources.ps1 -UseConfig
```

---

## 📊 Success Metrics

| Metric | Without Template | With Template |
|--------|-----------------|---------------|
| **Time to first agent** | 4-8 hours | < 30 minutes |
| **Pipeline setup** | 20+ iterations | 1-3 iterations |
| **Secrets stored** | 3-6 | 0 (federated!) |
| **Documentation** | Scattered | Complete |

---

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and [FEEDBACK.md](FEEDBACK.md) for ways to provide feedback.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. Customize and use it according to your organization's policies.

---

## 🆘 Troubleshooting

**Issue: Script fails with authentication error**
```powershell
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

**Issue: Service connection fails**
- Check that federated credentials are correctly configured
- Verify issuer and subject match your Azure DevOps organization

**Issue: Pipeline fails with 403 Forbidden**
- Verify RBAC roles are assigned to the service principal
- Check service connection authorization in Azure DevOps

**More help:** See [docs/troubleshooting.md](docs/troubleshooting.md) for detailed troubleshooting

---

## 🔗 Resources

- **Azure AI Foundry**: https://ai.azure.com
- **Azure Portal**: https://portal.azure.com
- **Azure DevOps**: https://dev.azure.com
- **Azure AI Documentation**: https://learn.microsoft.com/azure/ai-studio/
- **Azure DevOps Documentation**: https://learn.microsoft.com/azure/devops/

---

**Ready to deploy?** Start with the [automated setup script](#option-1-automated-setup-script-recommended) or explore the [setup guide](SETUP_GUIDE.md)!

