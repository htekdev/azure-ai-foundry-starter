# Azure AI Foundry Starter - Architecture

## Overview

The Azure AI Foundry Starter Template provides a complete, production-ready application for deploying AI agents to Azure AI Foundry with CI/CD automation through Azure DevOps.

## Repository Structure

```
azure-ai-foundry-starter/
├── template-app/           # Complete AI agent application
│   ├── .azure-pipelines/   # Multi-stage CI/CD pipelines
│   ├── src/                # Application source code
│   │   ├── agents/         # Agent creation and management
│   │   ├── evaluation/     # Agent evaluation scripts
│   │   ├── security/       # Security and compliance
│   │   └── utils/          # Utility functions
│   ├── tests/              # Unit and integration tests
│   ├── requirements.txt    # Python dependencies
│   ├── sample.env          # Environment configuration template
│   ├── README.md           # Template application documentation
│   └── FEEDBACK.md         # User feedback mechanism
│
├── docs/                   # Complete documentation
│   ├── README.md           # Documentation index
│   ├── starter-guide.md    # Complete deployment guide
│   ├── quick-start.md      # 30-minute fast track
│   ├── execution-guide.md  # GitHub Copilot usage
│   ├── architecture.md     # This file
│   ├── deployment-guide.md # Detailed Azure DevOps setup
│   ├── troubleshooting.md  # All 12 critical lessons
│   └── *.md                # Additional references
│
├── .github/                # GitHub Copilot integration
│   ├── agents/             # Agent definitions
│   │   └── azure-ai-foundry-starter-agent.agent.md
│   └── skills/             # Copilot skills
│       ├── starter-execution/
│       ├── configuration-management/
│       ├── environment-validation/
│       └── resource-creation/
│
├── archive/                # Backward compatibility
│   ├── CHANGELOG.md        # v1 → v2 changes
│   └── v1-migration/       # Original migration scripts
│
├── README.md               # Repository overview
└── starter-config.json     # Configuration template
```

## Application Architecture

### AI Agent Application (`template-app/`)

**Purpose**: Production-ready Python application for Azure AI Foundry agent deployment.

**Key Components**:

1. **Agent Creation** (`src/agents/createagent.py`)
   - Uses Azure AI SDK (agent-framework)
   - Creates persistent agents in Azure AI Foundry
   - Configurable instructions and model selection
   - Full error handling and logging

2. **Agent Evaluation** (`src/agents/agenteval.py`)
   - Quality assessment framework
   - Performance metrics collection
   - Response validation

3. **Security Layer** (`src/security/`)
   - Credential management
   - RBAC validation
   - Compliance checks

4. **Utilities** (`src/utils/`)
   - Logging configuration
   - Common helper functions
   - Configuration loading

### CI/CD Architecture

**Multi-Stage Pipeline** (`.azure-pipelines/createagentpipeline.yml`):

```
┌─────────────────────────────────────────────────────────────┐
│                        DEV Stage                             │
│  - Build application                                         │
│  - Install dependencies                                      │
│  - Run tests                                                 │
│  - Deploy agent to DEV environment                           │
│  - Validate deployment                                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       TEST Stage                             │
│  - Deploy to TEST environment                                │
│  - Run integration tests                                     │
│  - Validate against TEST data                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       PROD Stage                             │
│  - Manual approval gate                                      │
│  - Deploy to PROD environment                                │
│  - Run smoke tests                                           │
│  - Monitor deployment                                        │
└─────────────────────────────────────────────────────────────┘
```

**Per-Environment Resources**:
- Service Connection (with federated credentials)
- Variable Group (environment-specific values)
- Environment (with approval gates)

## Authentication Architecture

### Workload Identity Federation

**Zero Secrets Approach**:
```
Azure DevOps Pipeline
        ↓
Service Connection (federated)
        ↓
Federated Credential on Service Principal
        ↓
Azure AD Token Exchange
        ↓
Azure AI Foundry (with RBAC)
```

**Critical Components**:
1. **Service Principal**: Created with proper RBAC
   - Contributor role (resource group)
   - Cognitive Services User role (AI Foundry)

2. **Federated Credential**: Links Azure DevOps to Service Principal
   - Issuer: `{org}/{project}/_apis/serviceconnections/{scId}`
   - Subject: `sc://{org}/{project}/{scName}`
   - Audience: `api://AzureADTokenExchange`

3. **Service Connection**: Uses federated auth (no password/secret)
   - Type: AzureRM
   - Scheme: WorkloadIdentityFederation

## Configuration Management

### Configuration Flow

```
starter-config.json (template)
        ↓
User customizes values
        ↓
Skills load configuration
        ↓
Consistent deployment
```

**Configuration Sections**:
- Azure subscription and resource group
- Azure DevOps organization and project
- AI Foundry project endpoints (per environment)
- Service Principal details
- Variable group settings

## GitHub Copilot Integration

### Agent Skills Architecture

```
User: "@workspace I want to start a new AI Foundry project"
        ↓
GitHub Copilot invokes azure-ai-foundry-starter-agent
        ↓
Agent orchestrates skills in sequence:
  1. configuration-management (gather settings)
  2. environment-validation (check prerequisites)
  3. resource-creation (create Azure resources)
  4. starter-execution (deploy application)
        ↓
Complete working deployment
```

**Skill Hierarchy**:
- **Level 0**: configuration-management (foundation)
- **Level 1**: environment-validation, resource-creation
- **Level 2**: starter-execution (uses all above)

## Deployment Flow

### Complete Deployment Sequence

1. **Configuration** (5-10 min)
   - Run configuration-management skill
   - Define all resource names and settings
   - Validate configuration completeness

2. **Environment Validation** (5 min)
   - Check tool versions
   - Verify authentication
   - Test connectivity

3. **Resource Provisioning** (10-15 min)
   - Create Service Principal
   - Assign RBAC roles
   - Create AI Foundry project (if needed)

4. **Azure DevOps Setup** (15-20 min)
   - Create repository and push code
   - Create 3 service connections
   - Configure 3 variable groups
   - Set up 3 environments

5. **Pipeline Creation** (5 min)
   - Create pipeline from YAML
   - Authorize service connections

6. **First Deployment** (5-10 min)
   - Run pipeline (DEV stage)
   - Agent created in AI Foundry
   - Validation complete

**Total Time**: 45-60 minutes (vs 20+ iterations without template!)

## Design Decisions

### Why Template Approach?

**Problem**: Original migration helper required:
- Cloning external repository
- Manual file copying
- Structure reorganization
- 20+ pipeline iterations to debug

**Solution**: Include all working code in template
- Fork and customize immediately
- Zero external dependencies
- Battle-tested through 22 iterations
- All lessons learned integrated

### Why Federated Credentials?

**Benefits**:
- Zero secrets stored anywhere
- Automatic token rotation
- Better security posture
- Azure AD managed authentication

**Trade-off**: More complex setup, but scripts handle it.

### Why Multi-Stage Pipeline?

**Benefits**:
- Environment isolation
- Progressive deployment
- Manual approval gates
- Rollback capability

**Trade-off**: Longer deployment time, but safer.

## Extensibility

### Customizing the Template

**Add New Agent Type**:
1. Create new file in `template-app/src/agents/`
2. Follow `createagent.py` pattern
3. Add pipeline stage or new pipeline YAML
4. Update variable groups with required values

**Add New Environment**:
1. Create 4th service connection
2. Create 4th variable group
3. Create 4th environment
4. Add stage to pipeline YAML

**Add Evaluation**:
1. Extend `src/evaluation/` modules
2. Add evaluation stage to pipeline
3. Configure quality gates

### Integration Points

- **Azure Monitor**: Add Application Insights instrumentation
- **Key Vault**: Store secrets for external APIs
- **Azure Functions**: Trigger agents from events
- **Power Platform**: Connect agents to Power Apps

## Success Metrics

Template designed to achieve:
- ✅ Time to first agent: < 1 hour
- ✅ Pipeline iterations to success: 1-3 (vs 20+)
- ✅ Security posture: Zero secrets
- ✅ Environment parity: 100% (DEV=TEST=PROD config)
- ✅ Documentation coverage: 100%
- ✅ Troubleshooting: All 12 critical issues documented

## Next Steps

After understanding architecture:
1. Read [docs/quick-start.md](quick-start.md) to deploy
2. Review [docs/deployment-guide.md](deployment-guide.md) for details
3. Check [docs/troubleshooting.md](troubleshooting.md) for known issues
4. Customize `template-app/` for your use case

---

**Last Updated**: January 2026  
**Version**: 2.0.0
