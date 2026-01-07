# Repository Migration Project - Command-Line Driven Approach

## 🎯 Overview

This project provides a **completely command-line driven** approach to migrating repositories from GitHub to Azure DevOps. No browser interactions, no manual clicking - everything is executable via CLI commands, making it perfect for automation and AI assistants like GitHub Copilot.

## 📚 Documentation Structure

### Core Execution Guides

1. **[COPILOT_EXECUTION_GUIDE.md](COPILOT_EXECUTION_GUIDE.md)** - **START HERE**
   - Step-by-step command-line process
   - Complete with resource discovery
   - Automatic resource creation
   - Bearer token authentication
   - Self-sufficient execution flow

2. **[AZ_DEVOPS_CLI_REFERENCE.md](AZ_DEVOPS_CLI_REFERENCE.md)**
   - Complete `az devops` CLI command reference
   - All repository, pipeline, and configuration commands
   - Real-world examples and patterns
   - Troubleshooting guide

3. **[API_REFERENCE.md](API_REFERENCE.md)**
   - Azure DevOps REST API documentation
   - Bearer token and PAT authentication
   - Complete API endpoint reference
   - PowerShell, Bash, and Python examples

### Reference Documentation

4. **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)**
   - Original comprehensive migration guide
   - Background information and planning
   - Detailed explanations of each phase

5. **[MANUAL_CHECKLIST.md](MANUAL_CHECKLIST.md)**
   - Manual step-by-step checklist
   - For verification and tracking
   - Timeline tracking

6. **[REPOSITORY_ANALYSIS.md](REPOSITORY_ANALYSIS.md)**
   - Analysis of source repository structure
   - Migration strategy details

7. **[PROPOSED_STRUCTURE.md](PROPOSED_STRUCTURE.md)**
   - Target repository structure
   - Reorganization plan

8. **[STRUCTURE_COMPARISON.md](STRUCTURE_COMPARISON.md)**
   - Before/after comparison
   - File mapping details

## 🚀 Quick Start

### For GitHub Copilot or AI Assistants

Give Copilot this prompt:

```
Please execute the repository migration using COPILOT_EXECUTION_GUIDE.md. 
Discover all resources automatically and create any that are missing. 
Use bearer token authentication from az CLI.
```

### For Manual Execution

```powershell
# 1. Open COPILOT_EXECUTION_GUIDE.md
# 2. Follow steps 1-20 sequentially
# 3. All commands are ready to copy-paste
```

## 🔐 Authentication Methods

This project supports **two authentication methods**:

### 1. Bearer Token (Recommended) ⭐

```powershell
# Login to Azure
az login

# Get bearer token
$token = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv

# Use with az devops
$env:AZURE_DEVOPS_EXT_PAT = $token
```

**Benefits:**
- ✅ More secure (1-hour expiration)
- ✅ No PAT management needed
- ✅ Works with service principals
- ✅ Perfect for automation

### 2. Personal Access Token (PAT)

```powershell
# Set PAT
$env:AZURE_DEVOPS_EXT_PAT = "your-pat-token"
```

## 🔍 Key Features

### Automatic Resource Discovery

The guide includes commands to automatically discover:
- ✅ Existing Azure DevOps repositories
- ✅ Pipelines and builds
- ✅ Service connections
- ✅ Variable groups
- ✅ Azure AI/ML workspaces
- ✅ Azure OpenAI services
- ✅ Resource groups
- ✅ Service principals

### Automatic Resource Creation

If resources are missing, the guide provides commands to create:
- ✅ Service principals
- ✅ Azure ML workspaces
- ✅ Azure OpenAI services
- ✅ OpenAI deployments
- ✅ Resource groups
- ✅ Role assignments

### Complete CLI Operations

Every operation has a CLI command:
- ✅ Repository creation
- ✅ Code push with bearer token
- ✅ Service connection creation
- ✅ Variable group management
- ✅ Pipeline creation
- ✅ Environment configuration
- ✅ Permission management

## 📂 What Changed from Original Approach

### Old Approach (migrate-repository.ps1)

- ❌ Monolithic PowerShell script
- ❌ Required running entire script
- ❌ Hard to debug individual steps
- ❌ Only PAT authentication
- ❌ Manual resource setup

### New Approach (COPILOT_EXECUTION_GUIDE.md)

- ✅ Step-by-step CLI commands
- ✅ Execute one step at a time
- ✅ Easy to debug and retry
- ✅ Bearer token support
- ✅ Automatic resource discovery and creation
- ✅ Perfect for AI assistant execution

## 🎓 Learning Path

### For Beginners

1. Read [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Understand the concepts
2. Follow [MANUAL_CHECKLIST.md](MANUAL_CHECKLIST.md) - Step-by-step verification
3. Reference [COPILOT_EXECUTION_GUIDE.md](COPILOT_EXECUTION_GUIDE.md) - Get the commands

### For Experienced Users

1. Start with [COPILOT_EXECUTION_GUIDE.md](COPILOT_EXECUTION_GUIDE.md)
2. Reference [AZ_DEVOPS_CLI_REFERENCE.md](AZ_DEVOPS_CLI_REFERENCE.md) as needed
3. Use [API_REFERENCE.md](API_REFERENCE.md) for advanced scenarios

### For Automation

1. Study [COPILOT_EXECUTION_GUIDE.md](COPILOT_EXECUTION_GUIDE.md)
2. Extract commands for your automation tool
3. Use bearer token authentication
4. Implement error handling from troubleshooting sections

## 🔧 Prerequisites

### Required Tools

```powershell
# Check installations
git --version        # 2.30+
az --version         # 2.50+
python --version     # 3.11+
$PSVersionTable.PSVersion  # 7.0+

# Install Azure DevOps extension
az extension add --name azure-devops
```

### Required Access

- Azure subscription with appropriate permissions
- Azure DevOps organization access
- Project Administrator or Build Administrator role
- Service Principal or user account with Contributor role

## 📋 Execution Checklist

- [ ] Review [COPILOT_EXECUTION_GUIDE.md](COPILOT_EXECUTION_GUIDE.md)
- [ ] Verify prerequisites (tools and access)
- [ ] Authenticate with bearer token
- [ ] Execute Step 3: Discover existing resources
- [ ] Execute Step 5-7: Create missing Azure resources
- [ ] Execute Step 8-11: Clone and reorganize repository
- [ ] Execute Step 12-17: Configure Azure DevOps
- [ ] Execute Step 18-19: Validate and test

## 🤝 Using with GitHub Copilot

### Example Prompts

**Initial Migration:**
```
Execute the repository migration from the COPILOT_EXECUTION_GUIDE.md. 
Use bearer token authentication and discover all resources first.
If any Azure resources are missing, create them automatically.
```

**Resource Discovery:**
```
Using the commands in COPILOT_EXECUTION_GUIDE.md Step 3-4, 
discover all existing Azure DevOps and Azure resources.
```

**Create Missing Resources:**
```
Check if Azure AI/ML workspace and OpenAI service exist.
If not, create them using the commands in COPILOT_EXECUTION_GUIDE.md Step 6-7.
```

**Pipeline Setup:**
```
Create the Azure DevOps pipelines using the commands in 
COPILOT_EXECUTION_GUIDE.md Step 17. Use the repository created earlier.
```

## 🔒 Security Best Practices

### Bearer Token

✅ **Do:**
- Use bearer tokens for automation
- Refresh tokens before expiration
- Use service principals for production

❌ **Don't:**
- Store bearer tokens in files
- Share tokens across systems
- Use user accounts for automation

### PAT Tokens

✅ **Do:**
- Set minimum required scopes
- Set expiration dates
- Rotate regularly
- Store in secure vault

❌ **Don't:**
- Commit PATs to git
- Use full-access PATs
- Share PATs
- Use PATs without expiration

### Git Operations

```powershell
# Use bearer token for push
git config --local http.extraheader "AUTHORIZATION: bearer $token"
git push azure main

# Remove after use
git config --local --unset http.extraheader
```

## 📊 Success Metrics

Migration is successful when:

- ✅ All commands execute without errors
- ✅ Repository created in Azure DevOps
- ✅ Code pushed successfully
- ✅ Service connections working
- ✅ Variable groups created
- ✅ Pipelines created and runnable
- ✅ No manual browser interactions needed

## 🐛 Troubleshooting

### Token Expired

```powershell
# Refresh bearer token
$env:AZURE_DEVOPS_EXT_PAT = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 `
    --query "accessToken" `
    --output tsv
```

### Command Not Found

```powershell
# Install/update Azure DevOps extension
az extension add --name azure-devops
az extension update --name azure-devops
```

### Permission Denied

```powershell
# Check current user
az devops user show --user "your-email@example.com"

# Verify service principal roles
az role assignment list --assignee $env:AZURE_CLIENT_ID
```

See [COPILOT_EXECUTION_GUIDE.md](COPILOT_EXECUTION_GUIDE.md#troubleshooting) for more troubleshooting steps.

## 📞 Support

For issues or questions:

1. Check the troubleshooting section in relevant guide
2. Verify authentication is working
3. Ensure all prerequisites are met
4. Review Azure DevOps service health

## 🎉 Summary

This project transforms repository migration from a manual, click-intensive process to a fully automated, command-line driven workflow. Perfect for:

- ✅ AI assistants (GitHub Copilot, ChatGPT, etc.)
- ✅ DevOps automation
- ✅ CI/CD pipelines
- ✅ Bulk migrations
- ✅ Repeatable processes

**Start with [COPILOT_EXECUTION_GUIDE.md](COPILOT_EXECUTION_GUIDE.md) and let automation handle the rest!**

---

**Project Version**: 2.0 (Command-Line Driven)  
**Last Updated**: January 7, 2026  
**Maintained by**: DevOps Team
