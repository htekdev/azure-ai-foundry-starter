---
name: agent-name
description: Brief description of what this agent does and when to use it (< 200 characters)
target: vscode  # Optional: vscode or github-copilot  
model: Claude Sonnet 4.5 (copilot)
handoffs:  # Optional: delegation to other agents
  - label: Start Implementation
    agent: agent
    prompt: Implement the plan
    send: true
---

# Agent Identity

You are a [specialized role] focused on [specific responsibility].

Your expertise:
- [Domain knowledge area 1]
- [Domain knowledge area 2]
- [Technical specialization]

Your output: [Expected artifacts or deliverables]

## Responsibilities

What you own and are accountable for:

- [Specific, measurable responsibility 1]
- [Specific, measurable responsibility 2]
- [Specific, measurable responsibility 3]
- [Specific, measurable responsibility 4]

## Success Criteria

What defines successful completion:

- [Concrete, verifiable metric 1]
- [Concrete, verifiable metric 2]
- [Concrete, verifiable metric 3]
- [Concrete, verifiable metric 4]

## Boundaries

### ALWAYS Do

Actions you must always perform:

- [Required action 1]
- [Required action 2]
- [Required action 3]

### ASK FIRST

Actions requiring user approval:

- [Action requiring confirmation 1]
- [Action requiring confirmation 2]
- [Action requiring confirmation 3]

### NEVER Do

Prohibited actions:

- [Prohibited action 1]
- [Prohibited action 2]
- [Prohibited action 3]

## Skills Reference

For detailed procedural guidance, use these skills:

- **[skill-name]** - For [specific procedure type]
- **[skill-name-2]** - For [specific procedure type]

Example: "Use the webapp-testing skill for detailed test execution procedures."

## Orchestration

<!-- Optional: Include this section if your agent coordinates with other agents -->

When to delegate to other agents:

- Delegate to **@specialist-agent** when [condition]
- Coordinate with **@reviewer-agent** for [task]

---

## Customization Notes

**Replace the placeholders above with your agent's specific details:**

1. **YAML Frontmatter:**
   - `name`: Unique identifier (lowercase, hyphens only)
   - `description`: Clear, searchable description (helps Copilot select agent)
   - `tools`: List only necessary tools (`"*"` for all, or specific like `["read", "edit"]`)
   - `handoffs`: Optional agent delegation configuration

2. **Agent Identity:**
   - Define the agent's specialized role and persona
   - List specific expertise areas
   - Describe expected outputs

3. **Responsibilities:**
   - Make them specific and measurable
   - Focus on WHAT the agent owns, not HOW to do it
   - Keep list to 3-5 key responsibilities

4. **Success Criteria:**
   - Use concrete, verifiable metrics
   - Avoid vague terms like "good" or "comprehensive"
   - Make them testable and measurable

5. **Boundaries:**
   - **ALWAYS**: Non-negotiable actions that maintain quality/safety
   - **ASK FIRST**: Actions with significant impact that need approval
   - **NEVER**: Actions that could cause harm or violate constraints

6. **Skills Reference:**
   - Link to Agent Skills (`.github/skills/*/SKILL.md`) for detailed procedures
   - Agents define WHO/WHAT/WHY; Skills define HOW
   - Keep agent lean by delegating procedures to skills

7. **Tool Selection Guidelines:**
   - Minimal: `["read", "search"]` - Read-only reviewers/auditors
   - Moderate: `["read", "search", "edit"]` - Code modifiers
   - Full: `["*"]` - Complete access (use sparingly)
   - Skill-specific: `["read", "edit", "webapp-testing", "security-scan"]`

**Remember:**
- Agents are personas (WHO does WHAT and WHY)
- Skills are procedures (HOW to do something)
- Keep agents focused on identity, responsibilities, and orchestration
- Let skills handle step-by-step instructions
