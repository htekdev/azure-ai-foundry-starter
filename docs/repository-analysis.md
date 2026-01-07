# Repository Analysis: balakreshnan/foundrycicdbasic

## Current Repository Structure

Based on analysis of the repository, here's the complete structure:

```
foundrycicdbasic/
├── .github/
│   └── workflows/
│       └── [GitHub Actions workflows]
├── cicd/
│   ├── README.md (Azure DevOps pipeline documentation)
│   ├── createagentpipeline.yml
│   └── agentconsumptionpipeline.yml
├── docs/
│   ├── README.md (Documentation index)
│   ├── architecture.md
│   ├── createagent.md
│   ├── deployment.md
│   ├── exagent.md
│   ├── agenteval.md
│   └── redteam.md
├── createagent.py (Agent creation script)
├── exagent.py (Agent consumption/testing script)
├── agenteval.py (Agent evaluation script)
├── redteam.py (Security testing script)
├── redteam1.py (Alternative security testing script)
├── requirements.txt
├── README.md (Main repository readme)
└── .gitignore

```

## Component Analysis

### 1. **Python Scripts (Root Level)**
- **createagent.py**: Creates and deploys AI agents to Azure AI Foundry
- **exagent.py**: Tests and consumes existing agents
- **agenteval.py**: Evaluates agent performance with metrics
- **redteam.py**: Security testing and red team evaluation
- **redteam1.py**: Alternative red team implementation
- **requirements.txt**: Python dependencies

**Purpose**: Core execution scripts for agent lifecycle management

### 2. **CI/CD Directory**
- **createagentpipeline.yml**: Azure DevOps pipeline for agent creation
- **agentconsumptionpipeline.yml**: Azure DevOps pipeline for testing/evaluation
- **README.md**: Detailed pipeline setup documentation

**Purpose**: Automated deployment and testing pipelines

### 3. **Documentation Directory**
- Comprehensive documentation for each component
- Architecture diagrams and decision records
- Deployment guides for both Azure DevOps and GitHub Actions
- Step-by-step tutorials

**Purpose**: Complete technical documentation

### 4. **GitHub Workflows**
- GitHub Actions alternative to Azure DevOps pipelines
- Similar functionality with GitHub-specific implementation

**Purpose**: CI/CD for GitHub-hosted repositories

## Key Dependencies

### Azure Resources
- Azure AI Foundry (AI Projects)
- Azure OpenAI Service
- Azure Monitor (Observability)
- Azure Key Vault (Secrets management)

### Python Packages
- azure-ai-projects
- azure-identity (DefaultAzureCredential)
- azure-ai-evaluation
- opentelemetry-sdk
- python-dotenv

### Authentication
- Service Principal (Client ID, Secret, Tenant ID)
- Personal Access Tokens (for CI/CD)
- DefaultAzureCredential pattern

## Configuration Files

### Environment Variables Required
```bash
# Azure AI Project
AZURE_AI_PROJECT=https://your-project.api.azureml.ms
AZURE_AI_PROJECT_ENDPOINT=https://your-project.api.azureml.ms

# Azure Authentication
AZURE_SUBSCRIPTION_ID=xxx
AZURE_TENANT_ID=xxx
AZURE_CLIENT_ID=xxx
AZURE_CLIENT_SECRET=xxx (for service principal)

# Azure OpenAI (for evaluation/red team)
AZURE_OPENAI_ENDPOINT=https://your-openai.openai.azure.com/
AZURE_OPENAI_KEY=xxx
AZURE_OPENAI_API_VERSION=2024-02-15-preview
AZURE_OPENAI_DEPLOYMENT=gpt-4o

# Service Connections (Azure DevOps)
AZURE_SERVICE_CONNECTION_DEV=name
AZURE_SERVICE_CONNECTION_TEST=name
AZURE_SERVICE_CONNECTION_PROD=name
```

## Pipeline Features

### Multi-Environment Support
- **Dev**: Development environment for initial testing
- **Test**: Testing environment with evaluation and security testing
- **Prod**: Production environment with approval gates

### Pipeline Stages
1. **Build**: Validate Python, install dependencies, create artifacts
2. **Dev Deployment**: Deploy to development
3. **Test Deployment**: Deploy to test with evaluations
4. **Prod Deployment**: Deploy to production (requires approval)

### Artifacts Generated
- agent-scripts (Python source files)
- redteam-results (Security evaluation JSON)
- evaluation-results (Performance metrics)

## Relationships Between Components

### Agent Creation Flow
```
createagent.py → createagentpipeline.yml → Dev → Test → Prod
```

### Agent Testing Flow
```
exagent.py → agenteval.py → redteam.py → agentconsumptionpipeline.yml
```

### Documentation Structure
```
README.md (index)
├── architecture.md (system design)
├── createagent.md (creation details)
├── exagent.md (consumption details)
├── agenteval.md (evaluation details)
├── redteam.md (security details)
└── deployment.md (CI/CD setup)
```

## Current Issues/Improvements Needed

1. **Organization**: Scripts at root level could be better organized
2. **Configuration**: No centralized config directory
3. **Tests**: No dedicated tests directory
4. **Examples**: No examples directory for quick starts
5. **Scripts**: Utility scripts mixed with main application scripts
6. **Docs**: Documentation could be more discoverable

## Technology Stack

- **Language**: Python 3.11+
- **Cloud Platform**: Microsoft Azure
- **AI Framework**: Azure AI Foundry / Azure AI Agent Service
- **CI/CD**: Azure DevOps Pipelines + GitHub Actions
- **Observability**: OpenTelemetry, Azure Monitor
- **Security**: Azure AI Red Team Service
- **Evaluation**: Azure AI Evaluation SDK
