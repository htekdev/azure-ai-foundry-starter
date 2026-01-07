# Proposed New Repository Structure

## Overview
This document outlines the reorganized structure for the foundry-cicd project with improved organization, discoverability, and maintainability.

## New Structure

```
foundry-cicd/
├── .github/
│   └── workflows/
│       ├── agent-creation.yml
│       ├── agent-testing.yml
│       └── README.md
├── .azure-pipelines/
│   ├── create-agent-pipeline.yml
│   ├── test-agent-pipeline.yml
│   ├── templates/
│   │   ├── build-stage.yml
│   │   ├── deploy-stage.yml
│   │   └── test-stage.yml
│   └── README.md
├── config/
│   ├── .env.template
│   ├── dev.yaml
│   ├── test.yaml
│   ├── prod.yaml
│   └── README.md
├── docs/
│   ├── README.md
│   ├── getting-started/
│   │   ├── prerequisites.md
│   │   ├── quick-start.md
│   │   └── local-development.md
│   ├── architecture/
│   │   ├── overview.md
│   │   ├── deployment-flow.md
│   │   ├── agent-lifecycle.md
│   │   └── decision-records.md
│   ├── guides/
│   │   ├── agent-creation.md
│   │   ├── agent-testing.md
│   │   ├── agent-evaluation.md
│   │   ├── security-testing.md
│   │   └── troubleshooting.md
│   ├── cicd/
│   │   ├── azure-devops-setup.md
│   │   ├── github-actions-setup.md
│   │   ├── pipeline-configuration.md
│   │   └── best-practices.md
│   └── api/
│       ├── azure-devops-api-reference.md
│       └── code-documentation.md
├── src/
│   ├── agents/
│   │   ├── __init__.py
│   │   ├── create_agent.py
│   │   ├── test_agent.py
│   │   └── agent_config.py
│   ├── evaluation/
│   │   ├── __init__.py
│   │   ├── evaluate_agent.py
│   │   └── metrics.py
│   ├── security/
│   │   ├── __init__.py
│   │   ├── redteam_scan.py
│   │   ├── redteam_advanced.py
│   │   └── attack_strategies.py
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── azure_auth.py
│   │   ├── config_loader.py
│   │   ├── logging_config.py
│   │   └── telemetry.py
│   └── __init__.py
├── scripts/
│   ├── setup/
│   │   ├── install-dependencies.sh
│   │   ├── install-dependencies.ps1
│   │   ├── setup-azure-resources.sh
│   │   └── setup-azure-resources.ps1
│   ├── deployment/
│   │   ├── deploy-dev.sh
│   │   ├── deploy-dev.ps1
│   │   ├── deploy-all-environments.sh
│   │   └── deploy-all-environments.ps1
│   └── utilities/
│       ├── validate-config.py
│       ├── check-health.py
│       └── cleanup-resources.py
├── tests/
│   ├── unit/
│   │   ├── test_agent_creation.py
│   │   ├── test_evaluation.py
│   │   └── test_security.py
│   ├── integration/
│   │   ├── test_e2e_workflow.py
│   │   └── test_azure_integration.py
│   ├── fixtures/
│   │   ├── sample_agents.py
│   │   └── mock_responses.py
│   └── conftest.py
├── examples/
│   ├── basic-agent/
│   │   ├── README.md
│   │   ├── create_financial_advisor.py
│   │   └── test_financial_advisor.py
│   ├── advanced-agent/
│   │   ├── README.md
│   │   ├── multi_tool_agent.py
│   │   └── custom_evaluation.py
│   └── ci-cd-samples/
│       ├── azure-devops-example/
│       └── github-actions-example/
├── tools/
│   ├── migration/
│   │   ├── migrate-from-old-structure.py
│   │   └── validate-migration.py
│   └── dev/
│       ├── local-test-runner.py
│       └── mock-azure-services.py
├── .gitignore
├── .dockerignore
├── Dockerfile
├── requirements.txt
├── requirements-dev.txt
├── setup.py
├── pyproject.toml
├── README.md
├── CONTRIBUTING.md
├── LICENSE
└── CHANGELOG.md
```

## Key Improvements

### 1. **Organized Source Code** (`src/`)
- Modular structure with clear separation of concerns
- Agents, evaluation, security, and utilities in separate modules
- Follows Python package best practices

### 2. **Separate CI/CD Configurations** (`.azure-pipelines/` and `.github/`)
- Dedicated directories for each platform
- Template-based pipeline structure for reusability
- Clear naming conventions

### 3. **Configuration Management** (`config/`)
- Environment-specific configuration files
- Template for local development
- Clear documentation for each config option

### 4. **Enhanced Documentation** (`docs/`)
- Structured by purpose (getting-started, architecture, guides, cicd)
- Progressive disclosure (beginner → advanced)
- Separate API reference section

### 5. **Dedicated Scripts** (`scripts/`)
- Setup scripts for initial configuration
- Deployment scripts for different scenarios
- Utility scripts for common operations

### 6. **Comprehensive Testing** (`tests/`)
- Unit tests for individual components
- Integration tests for workflows
- Fixtures and test data

### 7. **Examples Directory** (`examples/`)
- Quick-start examples
- Real-world use cases
- Sample CI/CD configurations

### 8. **Development Tools** (`tools/`)
- Migration utilities
- Local development helpers
- Mocking utilities

## File Mapping: Old → New

### Root Level Python Scripts
```
OLD: createagent.py → NEW: src/agents/create_agent.py
OLD: exagent.py → NEW: src/agents/test_agent.py
OLD: agenteval.py → NEW: src/evaluation/evaluate_agent.py
OLD: redteam.py → NEW: src/security/redteam_scan.py
OLD: redteam1.py → NEW: src/security/redteam_advanced.py
```

**Reason**: Better organization, Python package structure, clear module boundaries

### CI/CD Files
```
OLD: cicd/createagentpipeline.yml → NEW: .azure-pipelines/create-agent-pipeline.yml
OLD: cicd/agentconsumptionpipeline.yml → NEW: .azure-pipelines/test-agent-pipeline.yml
OLD: cicd/README.md → NEW: .azure-pipelines/README.md + docs/cicd/azure-devops-setup.md
```

**Reason**: Standard naming convention (.azure-pipelines), split documentation

### GitHub Workflows
```
OLD: .github/workflows/*.yml → NEW: .github/workflows/*.yml (renamed for clarity)
```

**Reason**: More descriptive names, consolidated documentation

### Documentation
```
OLD: docs/README.md → NEW: docs/README.md (enhanced)
OLD: docs/architecture.md → NEW: docs/architecture/overview.md + docs/architecture/deployment-flow.md
OLD: docs/createagent.md → NEW: docs/guides/agent-creation.md
OLD: docs/exagent.md → NEW: docs/guides/agent-testing.md
OLD: docs/agenteval.md → NEW: docs/guides/agent-evaluation.md
OLD: docs/redteam.md → NEW: docs/guides/security-testing.md
OLD: docs/deployment.md → NEW: docs/cicd/azure-devops-setup.md + docs/cicd/github-actions-setup.md
```

**Reason**: Better categorization, easier navigation, separation of concerns

### Configuration
```
NEW: config/.env.template (extracted from documentation)
NEW: config/dev.yaml (extracted from pipeline variables)
NEW: config/test.yaml (extracted from pipeline variables)
NEW: config/prod.yaml (extracted from pipeline variables)
```

**Reason**: Centralized configuration, environment-specific settings

### Dependencies
```
OLD: requirements.txt → NEW: requirements.txt (production dependencies)
NEW: requirements-dev.txt (development/testing dependencies)
NEW: setup.py (package metadata and installation)
NEW: pyproject.toml (modern Python project configuration)
```

**Reason**: Clearer dependency management, support for package installation

## Benefits of New Structure

### Developer Experience
✅ **Clear Entry Points**: README and getting-started guide
✅ **Logical Organization**: Related files grouped together
✅ **Easy Navigation**: Intuitive directory structure
✅ **Better IDE Support**: Python package structure

### Maintainability
✅ **Modular Code**: Easier to test and modify
✅ **Separated Concerns**: CI/CD separate from source code
✅ **Configuration Management**: Environment-specific configs
✅ **Documentation**: Organized by topic and skill level

### Scalability
✅ **Room to Grow**: Clear places to add new features
✅ **Reusable Components**: Utilities and templates
✅ **Testing Framework**: Structure for comprehensive tests
✅ **Examples**: Easy to add new examples

### Collaboration
✅ **Clear Contributions**: CONTRIBUTING.md and structure
✅ **Code Review**: Smaller, focused modules
✅ **Onboarding**: Progressive documentation
✅ **Standards**: Consistent naming and organization

## Migration Considerations

### Breaking Changes
- Import statements will change (e.g., `from createagent import ...` → `from src.agents.create_agent import ...`)
- Environment variable loading may need updates
- Pipeline references will need updating

### Backward Compatibility
- Can provide migration script to update references
- Can maintain legacy entry points temporarily
- Documentation will include migration guide

### Rollback Strategy
- Git tags before migration
- Feature branch for new structure
- Parallel testing before merging
- Comprehensive validation tests

## Implementation Priority

### Phase 1: Structure Only
1. Create new directory structure
2. Move files to new locations
3. Update import statements
4. Test locally

### Phase 2: Enhancements
1. Split large files into modules
2. Add utility functions
3. Create configuration management
4. Add migration scripts

### Phase 3: Documentation & Examples
1. Reorganize documentation
2. Create getting-started guides
3. Add example projects
4. Update pipeline documentation

### Phase 4: Testing & CI/CD
1. Add unit tests
2. Add integration tests
3. Update CI/CD pipelines
4. Test all environments
