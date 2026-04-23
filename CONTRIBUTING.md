# Contributing to Azure AI Foundry Starter

Thank you for your interest in contributing to Azure AI Foundry Starter! This guide outlines the conventions and policies you should follow when contributing.

## Licensing Policy

All files in this repository—including Agent Skills—are licensed under the **Apache-2.0** license. See [LICENSE](LICENSE) for the full license text.

### Skill Frontmatter

Every skill (`SKILL.md`) must include a `license` field in its YAML frontmatter set to `Apache-2.0`:

```yaml
---
name: my-skill
description: A brief description of what the skill does.
license: Apache-2.0
---
```

This ensures clarity for all consumers of the skills and compliance with the agentskills.io spec recommendations.

## Contributing Skills

When adding a new skill:

1. Create a new directory under `.github/skills/<skill-name>/`.
2. Add a `SKILL.md` file with valid YAML frontmatter that includes the `license: Apache-2.0` field.
3. Follow the existing skill structure for consistency.

## Code of Conduct

Please be respectful and constructive in all interactions. We follow the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.

## Getting Help

- Open an [issue](../../issues) for bugs or feature requests.
- See [docs/](docs/) for detailed documentation.
