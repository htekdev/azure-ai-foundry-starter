# Naming Convention

## Overview

All resource names in the Azure AI Foundry Starter are controlled by a single configuration value: **`naming.projectName`** in `starter-config.json`.

This ensures consistent naming across all Azure and Azure DevOps resources, making them easy to identify and manage.

## Configuration

### starter-config.json

```json
{
    "naming": {
        "projectName": "aifoundrycicd"
    }
}
```

The `projectName` value is used as a prefix for all resource names. **Resource groups are automatically derived** using the pattern `rg-{projectName}`.

## Resource Naming Patterns

### Azure Resources

| Resource Type | Pattern | Example |
|---------------|---------|---------|
| Resource Groups | `rg-{projectName}-{env}` | `rg-aifoundrycicd-dev` |
| AI Services | `aif-{env}-{random}` | `aif-dev-1764` |
| AI Projects | `project-{env}` | `project-dev` |

**Note:** Resource groups are automatically derived from `naming.projectName` using the pattern `rg-{projectName}`.

### Azure DevOps Resources

| Resource Type | Pattern | Example |
|---------------|---------|---------|
| Service Connections | `{projectName}-{env}` | `aifoundrycicd-dev` |
| Variable Groups | `{projectName}-{env}-vars` | `aifoundrycicd-dev-vars` |
| Pipelines | `{projectName}-*` | `aifoundrycicd-create-agent` |

### Environments

| Environment | Suffix | Usage |
|-------------|--------|-------|
| Development | `-dev` | Development and testing |
| Test | `-test` | Pre-production validation |
| Production | `-prod` | Production deployment |

## Examples

### Full Resource Set

With `projectName: "aifoundrycicd"`:

**Azure Resources:**
- `rg-aifoundrycicd-dev`
- `rg-aifoundrycicd-test`
- `rg-aifoundrycicd-prod`

**Azure DevOps:**
- Service Connections: `aifoundrycicd-dev`, `aifoundrycicd-test`, `aifoundrycicd-prod`
- Variable Groups: `aifoundrycicd-dev-vars`, `aifoundrycicd-test-vars`, `aifoundrycicd-prod-vars`

## Pipeline References

### Service Connections in YAML

```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'aifoundrycicd-dev'  # {projectName}-dev
```

### Variable Groups in YAML

```yaml
variables:
  - group: 'aifoundrycicd-dev-vars'  # {projectName}-dev-vars
```

## Best Practices

### Naming Rules

1. **Use lowercase**: All names use lowercase letters
2. **Use hyphens**: Separate words with hyphens, not underscores
3. **Be consistent**: Follow the pattern across all resources
4. **Keep it short**: Shorter names are easier to work with (10-15 characters)
5. **Make it meaningful**: Use names that indicate the project purpose

### Good Examples

✅ `aifoundrycicd`  
✅ `myproject`  
✅ `teamai`  

### Bad Examples

❌ `azure-ai-foundry-starter-project-v2` (too long)  
❌ `My_Project` (underscores, mixed case)  
❌ `temp` (not meaningful)  

## Changing the Project Name

If you need to change the project name:

1. **Update starter-config.json**:
   ```json
   {
       "naming": {
           "projectName": "newname"
       }
   }
   ```

2. **Clean up existing resources**:
   ```powershell
   .\scripts\clean.ps1 -Force
   ```

3. **Redeploy with new name**:
   ```powershell
   .\scripts\setup.ps1
   ```

**Warning:** This will delete and recreate all resources. Make sure to backup any important data first.

## Script References

All cleanup and creation scripts respect the `naming.projectName` configuration:

- [`cleanup-devops.ps1`](.github/skills/cleanup-devops/scripts/cleanup-devops.ps1) - Uses `$projectName` for queries
- [`cleanup-resources.ps1`](.github/skills/cleanup-resources/scripts/cleanup-resources.ps1) - Derives RG pattern from `naming.projectName`
- [`config-reset.ps1`](.github/skills/config-reset/scripts/reset-config.ps1) - Resets to template with empty projectName

## Troubleshooting

### Resource Not Found

If scripts can't find resources, verify:

1. **Check config file**:
   ```powershell
   Get-Content .\starter-config.json | ConvertFrom-Json | Select-Object -ExpandProperty naming
   ```

2. **Verify actual resource names** in Azure Portal and Azure DevOps

3. **Ensure consistency**: All resources should follow the naming pattern

### Name Conflicts

If you get naming conflicts:

1. Choose a unique `projectName`
2. Check existing resources in your subscription
3. Clean up old resources with `.\scripts\clean.ps1`

## Related Documentation

- [Configuration Management Skill](.github/skills/configuration-management/SKILL.md)
- [Cleanup Resources Skill](.github/skills/cleanup-resources/SKILL.md)
- [Cleanup DevOps Skill](.github/skills/cleanup-devops/SKILL.md)
