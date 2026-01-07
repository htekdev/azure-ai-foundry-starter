# Environment Validation Skill

This Agent Skill validates the environment prerequisites for Azure DevOps repository migration following the [Agent Skills standard](https://agentskills.io).

## Quick Start

### Using with GitHub Copilot in VS Code

1. Enable Agent Skills in VS Code Insiders (Settings > `chat.useAgentSkills`)
2. Use natural language to invoke the skill:

```
@workspace Validate my Azure DevOps migration environment
```

or

```
Check if my environment is ready for migration to Azure DevOps
```

GitHub Copilot will automatically detect and use this skill based on your request.

### Running the validation script directly

```powershell
# Basic validation (tools and authentication only)
./.github/skills/environment-validation/validation-script.ps1

# Full validation with Azure DevOps connectivity
./.github/skills/environment-validation/validation-script.ps1 `
  -OrganizationUrl "https://dev.azure.com/YOUR_ORG" `
  -ProjectName "YOUR_PROJECT"

# Complete validation including Azure resources
./.github/skills/environment-validation/validation-script.ps1 `
  -OrganizationUrl "https://dev.azure.com/YOUR_ORG" `
  -ProjectName "YOUR_PROJECT" `
  -ResourceGroup "YOUR_RG" `
  -MLWorkspace "YOUR_WORKSPACE" `
  -OpenAIService "YOUR_OPENAI_SERVICE"

# JSON output for automation
./.github/skills/environment-validation/validation-script.ps1 `
  -OrganizationUrl "https://dev.azure.com/YOUR_ORG" `
  -ProjectName "YOUR_PROJECT" `
  -OutputFormat json
```

## What gets validated

### ✅ Required Tools
- Git 2.30+
- Azure CLI 2.50+
- PowerShell 7.0+
- Python 3.11+
- Azure DevOps CLI extension

### 🔐 Authentication
- Azure CLI login status
- Bearer token validity (30+ minutes remaining)
- Token resource ID verification

### 🌐 Connectivity (optional parameters)
- Azure DevOps organization access
- Project access
- Repository listing
- Pipeline listing

### ☁️ Resources (optional parameters)
- Resource group existence
- ML workspace availability
- OpenAI service availability

## Files in this skill

- `SKILL.md` - Main skill definition and instructions
- `validation-script.ps1` - PowerShell validation script
- `examples/validation-report.json` - Sample JSON output
- `README.md` - This file

## Integration with GitHub Copilot

This skill uses the Agent Skills standard and is automatically discovered by GitHub Copilot when:
- Located in `.github/skills/` directory
- Contains a `SKILL.md` file with proper frontmatter
- User requests environment validation or troubleshooting

The skill provides:
- **Progressive disclosure**: Only loads when needed
- **Tool integration**: Can execute validation scripts via Copilot
- **Contextual help**: Provides troubleshooting guidance
- **Portability**: Works across VS Code, Copilot CLI, and Copilot coding agent

## Exit codes

When running the script directly:
- `0` - All validations passed
- `1` - One or more validations failed
- `2` - Script error

## Examples

### Example: Successful validation
```
=== Environment Validation Report ===
Generated: 2026-01-07 10:30:00

[Tools]
✅ Git: 2.43.0 (Required: 2.30+)
✅ Azure CLI: 2.55.0 (Required: 2.50+)
✅ PowerShell: 7.4.1 (Required: 7.0+)
✅ Python: 3.12.1 (Required: 3.11+)
✅ Azure DevOps Extension: 1.0.1 (Required: Latest)

[Summary]
Status: READY ✅
Passes: 5
Warnings: 0
Failures: 0

✅ You can proceed with the migration process.
```

### Example: Validation with warnings
```
[Authentication]
✅ Azure Login: Authenticated as user@domain.com
⚠️  Bearer Token: Valid (expires in 12 minutes) (Required: 30+ minutes) - Token will expire soon

[Summary]
Status: READY WITH WARNINGS ⚠️
Passes: 4
Warnings: 1
Failures: 0

✅ You can proceed with the migration process.
```

### Example: Failed validation
```
[Tools]
❌ Git: Not found (Required: 2.30+) - Not installed

[Summary]
Status: NOT READY ❌
Passes: 3
Warnings: 0
Failures: 1

❌ Please address the failures above before proceeding.
See SKILL.md for troubleshooting guidance.
```

## Related documentation

- [COPILOT_EXECUTION_GUIDE.md](../../../COPILOT_EXECUTION_GUIDE.md) - Complete migration guide
- [AZ_DEVOPS_CLI_REFERENCE.md](../../../AZ_DEVOPS_CLI_REFERENCE.md) - Azure DevOps CLI reference
- [Agent Skills Standard](https://agentskills.io) - Open standard specification
- [VS Code Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills) - VS Code documentation

## Contributing

To improve this skill:
1. Test the validation script with different environments
2. Add additional validation checks as needed
3. Improve troubleshooting guidance
4. Submit feedback or pull requests

## License

Part of the Northwind Systems repository migration project.
