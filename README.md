# Azure AI Foundry Starter Template

## 🎯 Overview

**Fork, customize, and deploy your Azure AI Foundry agent in under an hour!**

This is a complete, production-ready starter template for deploying AI agents to Azure AI Foundry with automated CI/CD through Azure DevOps. Everything you need is included - no external cloning required.

**✨ What's Included**:
- Complete AI agent application (`template-app/`)
- Multi-stage CI/CD pipeline (DEV/TEST/PROD)
- Workload Identity Federation (zero secrets!)
- Comprehensive documentation
- GitHub Copilot integration
- All lessons learned from 22 pipeline iterations

## 🚀 Quick Start

**New to Azure AI Foundry?** Get started in 3 steps:

1. **Configure your deployment**:
   ```powershell
   ./.github/skills/configuration-management/configure-starter.ps1 -Interactive
   ```

2. **Deploy the template**:
   ```powershell
   ./.github/skills/starter-execution/SKILL.md  # Follow step-by-step guide
   ```

3. **Customize and iterate**:
   - Modify `template-app/src/agents/createagent.py`
   - Push changes and pipeline auto-deploys

**Full guide**: [docs/quick-start.md](docs/quick-start.md)

## 📚 Documentation

**Getting Started**:
- [Quick Start](docs/quick-start.md) - Deploy in 30 minutes
- [Starter Guide](docs/starter-guide.md) - Complete step-by-step
- [Execution Guide](docs/execution-guide.md) - Using with GitHub Copilot

**Understanding the System**:
- [Architecture](docs/architecture.md) - System design and components
- [Deployment Guide](docs/deployment-guide.md) - Detailed Azure DevOps setup
- [Troubleshooting](docs/troubleshooting.md) - All 12 critical lessons learned

**Reference**:
- [API Reference](docs/api-reference.md) - Azure AI SDK documentation
- [CLI Reference](docs/az-devops-cli-reference.md) - Azure DevOps CLI commands
- [Full Documentation Index](docs/README.md)
   - File mapping details

## 🚀 Quick Start

## ✨ What Makes This Special

### Battle-Tested Through 22 Iterations
- Refined through 22 real pipeline runs
- All 12 critical issues documented and solved
- Best practices baked into every step

### Zero Secrets Architecture
- Workload Identity Federation (federated credentials)
- No passwords or secrets stored anywhere
- Azure AD managed authentication

### Complete Application Included
- Ready-to-deploy Python application
- Multi-stage pipeline (DEV/TEST/PROD)
- Tests, evaluation, security layers
- Full source code - customize anything

### GitHub Copilot Native
- Natural language deployment: `@workspace start new AI Foundry project`
- Intelligent guidance through agent skills
- Context-aware troubleshooting

## 📊 Success Metrics

| Metric | Without Template | With Template |
|--------|-----------------|---------------|
| Time to first agent | 4-8 hours | < 1 hour |
| Pipeline iterations | 20+ typical | 1-3 typical |
| Secrets stored | 3-6 | 0 |
| Documentation | Scattered | Complete |
| Troubleshooting | Trial & error | All issues documented |

## 🏗️ Template Structure
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

