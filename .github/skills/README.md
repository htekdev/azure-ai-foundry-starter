# GitHub Copilot Agent Skills - Quick Reference

This directory contains Agent Skills that extend GitHub Copilot's capabilities for Azure DevOps repository migration.

## What are Agent Skills?

Agent Skills are specialized capabilities that GitHub Copilot can use to perform complex tasks. They follow the [Agent Skills standard](https://agentskills.io) and work across VS Code, Copilot CLI, and Copilot coding agent.

## Available Skills

### ⚙️ configuration-management (USE THIS FIRST!)
**When to use**: Before starting migration, when setting up or updating configuration

Manages all configurable values including:
- Azure DevOps organization and project names
- Azure resource names (resource groups, ML workspaces, OpenAI services)
- Service Principal configuration
- Pipeline and variable group names
- Migration settings

**Usage**:
```
@workspace Set up my migration configuration
```

or run directly:
```powershell
# Interactive setup
./.github/skills/configuration-management/configure-migration.ps1 -Interactive

# Auto-discover from environment
./.github/skills/configuration-management/configure-migration.ps1 -AutoDiscover

# Validate configuration
./.github/skills/configuration-management/configure-migration.ps1 -Validate
```

**Why use this skill first?**
- ✅ Eliminates hardcoded values
- ✅ Ensures consistency across all operations
- ✅ Makes configuration reusable and portable
- ✅ Simplifies troubleshooting
- ✅ All other skills can load from this central configuration

[📖 Full Documentation](configuration-management/SKILL.md)

---

### 🔍 environment-validation
**When to use**: After configuration setup, before starting migration, troubleshooting environment issues

Validates all prerequisites including:
- Tool versions (Git, Azure CLI, PowerShell, Python)
- Authentication status and token validity
- Azure DevOps connectivity
- Azure resource availability

**Usage**:
```
@workspace Validate my Azure DevOps migration environment
```

or run directly:
```powershell
# With configuration (recommended)
./.github/skills/environment-validation/validation-script.ps1 -UseConfig

# Or with explicit parameters
./.github/skills/environment-validation/validation-script.ps1 `
  -OrganizationUrl "https://dev.azure.com/YOUR_ORG" `
  -ProjectName "YOUR_PROJECT"
```

[📖 Full Documentation](environment-validation/SKILL.md)

---

### 🏗️ resource-creation
**When to use**: Setting up Azure infrastructure, creating missing resources

Creates and configures:
- Service Principals with RBAC permissions
- Azure Machine Learning workspaces
- Azure OpenAI services and deployments
- Supporting resources (storage, key vault)

**Usage**:
**Note**: Automatically loads configuration to use consistent naming. C
@workspace Create Azure resources needed for migration
```

Automatically checks for existing resources before creating new ones.

[📖 Full Documentation](resource-creation/SKILL.md)

---

### 🚀 starter-execution
**When to use**: Deploying the Azure AI Foundry starter template

Performs:
- Repository creation in Azure DevOps
- Service connection setup with Workload Identity Federation
- Variable group creation
- Environment configuration
- CI/CD pipeline deployment
- Initial agent deployment

**Usage**:
```powershell
# Follows step-by-step instructions from SKILL.md
./.github/skills/starter-execution/
```

**Note**: Loads configuration for consistent naming and settings throughout deployment.

[📖 Full Documentation](starter-execution/SKILL.md)

---

### 🔐 federated-credentials
**When to use**: Fixing authentication issues, updating service connection credentials

Manages:
- Retrieving actual issuer/subject from Azure DevOps service connections
- Deleting old federated credentials with incorrect format
- Creating new credentials with correct values
- Adding required RBAC permissions (Cognitive Services User)

**Usage**:
```powershell
# Fix all federated credentials
./.github/skills/federated-credentials/fix-federated-credentials.ps1

# Fix specific environments
./.github/skills/federated-credentials/fix-federated-credentials.ps1 -Environments @("dev", "test")
```

**Critical**: Never guess issuer/subject format. Always retrieve from Azure DevOps REST API.

[📖 Full Documentation](federated-credentials/SKILL.md)

---

## Workflow Order

**IMPORTANT**: Always follow this order for successful deployment:

```
1. configuration-management    → Set up centralized configuration
   ↓
2. environment-validation      → Validate prerequisites using config
   ↓
3. resource-creation          → Create Azure resources using config
   ↓
4. starter-execution          → Deploy template application using config
   ↓
5. federated-credentials      → Fix authentication credentials (if needed)
   ↓
6. environment-validation     → Validate success
```

### Progressive Disclosure
Skills use a three-level loading system:

1. **Level 1 - Discovery**: Copilot always knows which skills are available
2. **Level 2 - Instructions**: Loads when user request matches skill description
3. **Level 3 - Resources**: Accesses scripts/files only when referenced

This means you can install many skills without consuming context—only relevant ones load when needed.

### Automatic Activationfour
Skills activate automatically based on your prompt. You don't need to manually select them. Just describe what you want to do, and Copilot will use the appropriate skill.

Examples:
- "Validate my environment" → Uses `environment-validation`
- "Create Azure resources" → Uses `resource-creation`
- "Execute the migration" → Uses `migration-execution`

## Using with Custom Agent

For a guided migration experience, use the custom agent:

```
@azure-devops-migration-agent I want to migrate my repository to Azure DevOps
```

The agent orchestrates all three skills and provides: (if applicable)
├── config-template.json        # Configuration template (for configuration-management)
├── config-functions.ps1        # Helper functions (for configuration-management)
├── examples/                   # Sample outputs and configurations
│   └── example-output.json
└── README.md                   # Quick reference (optional)
- Validation at each phase
- Rollback support

[📖 Custom Agent Documentation](../.github/agents/azure-devops-migration-agent.agent.md)

## File Structure

Each skill follows this structure:

```
skill-name/
├── SKILL.md                    # Main skill definition (YAML + instructions)
├── script.ps1                  # PowerShell automation script
├── examples/                   # Sample outputs and configurations
│   └── example-output.json
└── README.md                   # Quick reference
```

## Skill Configuration

All skills use the Agent Skills standard format:

```markdown
---
name: skill-name
description: What the skill does and when to use it
---

# Skill Instructions
Detailed instructions, guidelines, and examples...
```

The YAML frontmatter helps Copilot decide when to load the skill.

## VS Code Setup

To use Agent Skills in VS Code:

1. **Use VS Code Insiders** (Agent Skills are in preview)
2. **Enable the setting**: `chat.useAgentSkills`
3. **Restart VS Code**
4. Skills in `.github/skills/` are automatically discovered

## Resource Naming Conventions

All Azure resources follow a consistent naming pattern derived from `config.naming.projectName` in `starter-config.json`:

### Resource Groups
**Pattern**: `rg-{projectName}-{env}`

**Example**: If `config.naming.projectName = "ai-foundry-starter"`:
- Development: `rg-ai-foundry-starter-dev`
- Test: `rg-ai-foundry-starter-test`
- Production: `rg-ai-foundry-starter-prod`

### Service Principal
**Pattern**: `sp-{projectName}`

**Example**: `sp-ai-foundry-starter`

### Service Connections
**Pattern**: `{projectName}-{env}`

**Example**: 
- `ai-foundry-starter-dev`
- `ai-foundry-starter-test`
- `ai-foundry-starter-prod`

### Variable Groups
**Pattern**: `{projectName}-{env}-vars` (where projectName is from config.naming.projectName)

**Example with projectName="aifoundrycicd"**:
- `aifoundrycicd-dev-vars`
- `aifoundrycicd-test-vars`
- `aifoundrycicd-prod-vars`

**Important**: 
- ✅ All resource names are derived from configuration
- ✅ Never hardcode resource names like `rg-ai-foundry-starter-{env}`
- ✅ Always use `config.naming.projectName` to build resource names
- ✅ This ensures consistency when deploying with custom project names

## Best Practices

### When creating new skills:
- ✅ Write clear, specific descriptions
- ✅ Include both "what" and "when to use"
- ✅ Provide troubleshooting guidance
- ✅ **Load configuration instead of hardcoding values**

### When using skills:
- ✅ **Start with configuration-management** (most important!)
- ✅ Validate environment after configur
### When using skills:
- ✅ Start with environment validation
- ✅ Create resources before migration
- ✅ Follow the recommended workflow order
- ✅ Review validation results before proceeding
- ✅ Keep backups of important data

## Troubleshooting

### Skill not loading
- Verify you're using VS Code Insiders
- ChConfiguration not loading
- Check file exists: `.github/skills/migration-config.json`
- Verify JSON syntax is valid
- Run: `./configure-migration.ps1 -Validate`
- If corrupted, restore from `.backup` file

### eck `chat.useAgentSkills` is enabled
- Ensure `SKILL.md` has valid YAML frontmatter
- Restart VS Code

- Try using the custom agent instead
- Load configuration first if using migration skills

## Migration Workflow

Recommended order for using skills:

```
1. configuration-management  → Set up centralized configuration
   ↓                          (Interactive prompts or auto-discovery)
2. environment-validation    → Validate prerequisites
   ↓                          (Use -UseConfig flag)
3. resource-creation         → Set up Azure infrastructure
   ↓                          (Automatically loads configuration)
4. migration-execution       → Execute migration
   ↓                          (Loads config for all operations)
5. environment-validation    → Validate success
                              (Verify everything works)
Recommended order for using skills:

```
1. environment-validation    → Validate prerequisites
   ↓
2. resource-creation         → Set up Azure infrastructure
   ↓
3. migration-execution       → Execute migration
   ↓
4. environment-validation    → Validate success
```

## Additional Resources

- [Agent Skills Standard](https://agentskills.io) - Open standard specification
- [VS Code Documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills) - VS Code-specific docs
- [COPILOT_EXECUTION_GUIDE.md](../../COPILOT_EXECUTION_GUIDE.md) - Detailed migration guide
- [AZ_DEVOPS_CLI_REFERENCE.md](../../AZ_DEVOPS_CLI_REFERENCE.md) - Azure DevOps CLI reference

## Contributing

To add a new skill:

1. Create a directory in `.github/skills/`
2. Add `SKILL.md` with proper YAML frontmatter
3. Include supporting scripts/files as needed
4. Add `README.md` for quick reference
5. Test with GitHub Copilot

## Support

For issues or questions:
- Check individual skill documentation
- Review the main [COPILOT_EXECUTION_GUIDE.md](../../COPILOT_EXECUTION_GUIDE.md)
- Ask the custom agent: `@azure-devops-migration-agent help with [issue]`
