# Contributing to Azure AI Foundry Starter

Thank you for your interest in contributing to the Azure AI Foundry Starter template! This document provides guidelines and information for contributors.

## 📋 Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [How Can I Contribute?](#how-can-i-contribute)
3. [Development Setup](#development-setup)
4. [Contribution Workflow](#contribution-workflow)
5. [Style Guidelines](#style-guidelines)
6. [Testing Guidelines](#testing-guidelines)
7. [Documentation Guidelines](#documentation-guidelines)
8. [Submitting Changes](#submitting-changes)

---

## Code of Conduct

This project adheres to a code of conduct that ensures a welcoming and inclusive environment for all contributors. By participating, you are expected to uphold this code.

**Expected Behavior:**
- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Respect differing viewpoints and experiences

**Unacceptable Behavior:**
- Harassment, discrimination, or offensive comments
- Personal attacks or trolling
- Spam or off-topic discussions

---

## How Can I Contribute?

### Reporting Issues

Found a bug or have a feature request? Please [open an issue](../../issues/new) with:

**For Bugs:**
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, tool versions, Azure region)
- Error messages or screenshots
- Pipeline run logs (if applicable)

**For Feature Requests:**
- Use case description
- Proposed solution or approach
- Alternative solutions considered
- Potential impact on existing functionality

### Improving Documentation

Documentation improvements are always welcome! You can help by:

- Fixing typos or clarifying confusing sections
- Adding examples or tutorials
- Improving troubleshooting guides
- Translating documentation
- Adding diagrams or visualizations

See [Documentation Guidelines](#documentation-guidelines) for more details.

### Contributing Code

Code contributions are welcome for:

- Bug fixes
- New features
- Performance improvements
- Test coverage improvements
- Refactoring for better maintainability

See [Contribution Workflow](#contribution-workflow) for the process.

### Sharing Your Experience

Help others by:

- Sharing deployment experiences and lessons learned
- Providing feedback on the template via [FEEDBACK.md](FEEDBACK.md)
- Answering questions in issues or discussions
- Writing blog posts or tutorials (let us know so we can link them!)

---

## Development Setup

### Prerequisites

**Required Tools:**
- Git 2.30+
- PowerShell 7.0+
- Azure CLI 2.50+
- Azure DevOps CLI extension
- Python 3.11+ (for testing agent code)

**Installation:**
```powershell
# Azure CLI
winget install Microsoft.AzureCLI

# Azure DevOps extension
az extension add --name azure-devops

# Python
winget install Python.Python.3.11

# PowerShell (if needed)
winget install Microsoft.PowerShell
```

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/azure-ai-foundry-starter.git
   cd azure-ai-foundry-starter
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/htekdev/azure-ai-foundry-starter.git
   ```

### Development Environment

```powershell
# Create Python virtual environment (optional, for testing agent code)
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Install development dependencies
pip install -r requirements.txt
```

---

## Contribution Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number-description
```

**Branch Naming Conventions:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation improvements
- `refactor/` - Code refactoring
- `test/` - Test improvements

### 2. Make Your Changes

- Write clear, maintainable code
- Follow the [Style Guidelines](#style-guidelines)
- Add or update tests as needed
- Update documentation to reflect your changes

### 3. Test Your Changes

```powershell
# Test scripts
.\scripts\setup.ps1 -WhatIf  # Dry run

# Test skills
.\.github\skills\YOUR_SKILL\scripts\test-skill.ps1

# Validate YAML
az pipelines validate --yaml-path .azure-pipelines/createagentpipeline.yml

# Test Python code (if applicable)
python -m pytest tests/
```

### 4. Commit Your Changes

```bash
git add .
git commit -m "type: brief description

Detailed explanation of changes (if needed)"
```

**Commit Message Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring
- `test:` - Test additions or changes
- `chore:` - Maintenance tasks

**Example:**
```
feat: add support for custom AI model deployments

- Added configuration option for custom model names
- Updated variable groups to support model selection
- Added validation for model deployment names
- Updated documentation with examples

Closes #123
```

### 5. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub with:
- Clear title describing the change
- Description of what changed and why
- Link to related issues
- Screenshots (for UI/documentation changes)
- Test results or validation output

---

## Style Guidelines

### PowerShell Scripts

```powershell
# Use approved verbs
Get-Configuration  # ✅
Retrieve-Configuration  # ❌

# Use PascalCase for functions
function Get-AzureResource { ... }

# Use clear parameter names with validation
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment = 'dev'
)

# Add help documentation
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER ProjectName
    Description of parameter
.EXAMPLE
    Get-AzureResource -ProjectName "myproject"
#>

# Use Write-Host for user-facing messages with colors
Write-Host "✓ Resource created successfully" -ForegroundColor Green
Write-Host "⚠ Warning: Resource exists" -ForegroundColor Yellow
Write-Host "✗ Error: Operation failed" -ForegroundColor Red
```

### Python Code

```python
# Follow PEP 8
# Use type hints
def create_agent(name: str, instructions: str) -> dict:
    """
    Create an AI agent with the specified configuration.
    
    Args:
        name: Agent name
        instructions: Agent instructions
        
    Returns:
        dict: Agent details including ID and configuration
    """
    pass

# Use meaningful variable names
agent_config = {...}  # ✅
cfg = {...}  # ❌

# Add docstrings to all public functions
# Use logging instead of print
import logging
logger = logging.getLogger(__name__)
logger.info("Agent created successfully")
```

### YAML Pipelines

```yaml
# Use clear stage and job names
- stage: Dev
  displayName: 'Deploy to Development'
  
# Add comments for complex logic
# This task exports required environment variables for the agent SDK
- task: AzureCLI@2
  displayName: 'Deploy AI Agent'
  inputs:
    azureSubscription: 'foundrycicd-dev'
    
# Use consistent indentation (2 spaces)
# Group related tasks together
```

### Markdown Documentation

```markdown
# Use clear heading hierarchy
## Main Section
### Subsection

# Use code blocks with language specification
```powershell
# PowerShell code
```

```yaml
# YAML code
```

# Use emoji sparingly for visual organization
## 🚀 Getting Started
## ⚠️ Important Notes

# Use tables for structured data
| Column 1 | Column 2 |
|----------|----------|
| Data 1   | Data 2   |

# Use callouts for important information
> **Note:** This is important information
> 
> **Warning:** This requires caution
```

---

## Testing Guidelines

### Script Testing

```powershell
# Use WhatIf support for potentially destructive operations
[CmdletBinding(SupportsShouldProcess)]
param()

if ($PSCmdlet.ShouldProcess("Resource", "Create")) {
    # Perform operation
}

# Test with -WhatIf
.\script.ps1 -WhatIf
```

### Integration Testing

For changes that affect Azure resources or Azure DevOps:

1. Create a test environment
2. Run the full deployment process
3. Validate all stages complete successfully
4. Verify agents are created and functional
5. Clean up test resources

```powershell
# Deploy to test environment
.\scripts\setup.ps1 -ProjectName "test-deployment" -SubscriptionId "..."

# Run validation
.\.github\skills\deployment-validation\scripts\validate-deployment.ps1 -UseConfig

# Clean up
.\.github\skills\cleanup-resources\scripts\cleanup-resources.ps1 -UseConfig
```

### Documentation Testing

- Verify all links work
- Test all code examples
- Ensure commands run successfully
- Check for typos and grammar

---

## Documentation Guidelines

### Structure

- Start with a clear title and brief description
- Add a table of contents for long documents
- Use consistent heading levels
- Include code examples
- Add troubleshooting section where appropriate

### Writing Style

- Use clear, concise language
- Write in active voice ("Run this command" not "This command should be run")
- Use "you" to address the reader
- Explain the "why" not just the "what"
- Include expected output for commands

### Code Examples

- Provide complete, working examples
- Use realistic placeholder values
- Comment complex sections
- Show both successful and error cases
- Include validation steps

### Cross-References

- Link to related documentation
- Reference prerequisite sections
- Link to troubleshooting for known issues

**Example:**
```markdown
See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete setup instructions.

If you encounter errors, check [troubleshooting.md](docs/troubleshooting.md).
```

---

## Submitting Changes

### Pull Request Checklist

Before submitting your pull request:

- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] Branch is up to date with main
- [ ] No merge conflicts
- [ ] Screenshots included (if UI changes)
- [ ] Related issues referenced

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (describe)

## Testing
Describe how you tested these changes

## Related Issues
Closes #123
Relates to #456

## Screenshots
(if applicable)

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
```

### Review Process

1. Maintainer will review your PR
2. Address any feedback or requested changes
3. Once approved, maintainer will merge
4. Your contribution will be included in the next release!

---

## Recognition

Contributors will be:
- Listed in release notes
- Credited in documentation (where appropriate)
- Acknowledged in the project

---

## Getting Help

**Need help with your contribution?**

- [Open a discussion](../../discussions)
- [Ask in an issue](../../issues)
- Check [troubleshooting.md](docs/troubleshooting.md)
- Review [LESSONS_LEARNED.md](.github/skills/starter-execution/LESSONS_LEARNED.md)

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to Azure AI Foundry Starter! Your efforts help make this template better for everyone.** 🙏

**Last Updated:** January 2026
