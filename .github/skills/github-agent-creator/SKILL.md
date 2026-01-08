---
name: github-agent-creator
description: Creates custom GitHub Copilot agents (.github/agents/*.agent.md) that define specialized personas, responsibilities, and tool orchestration. Use when you need agents for testing, documentation, security, or deployment. Teaches separation of concerns - agents define WHO/WHAT/WHY, skills define HOW.
---

# GitHub Agent Creator

## Overview

This skill guides you through creating **Custom Agents** for GitHub Copilot based on modern architectural patterns. Custom Agents define personas, responsibilities, and tool orchestration—they are the **"WHO"** that decides what to do and when. For detailed procedural knowledge (the **"HOW"**), agents reference **Agent Skills**.

**Key Architectural Separation:**
- **Custom Agents** (`.github/agents/*.agent.md`) = Identity + Responsibilities + Tool Orchestration + Success Criteria
- **Agent Skills** (`.github/skills/*/SKILL.md`) = Detailed procedures + Step-by-step workflows + Scripts

## When to Use This Skill

Use this skill when you need to:
- Create custom GitHub Copilot agents with specialized personas
- Define agent responsibilities and boundaries
- Configure which tools/skills an agent can access
- Set up agent orchestration and handoffs
- Create testing, documentation, security, or deployment agents
- Design agent success criteria and behavioral guidelines

## Understanding Custom Agents vs Agent Skills

### Custom Agents: The "WHO/WHAT/WHY"

Custom agents are **personas** that define:
- **Identity**: "You are a testing specialist focused on..."
- **Responsibilities**: What the agent cares about and owns
- **Tool Access**: Which skills and tools the agent can use
- **Success Criteria**: What good outcomes look like
- **Boundaries**: What the agent should/shouldn't do
- **Orchestration**: How to delegate to other agents

**Custom agents DON'T contain:**
- ❌ Step-by-step procedures (that's in skills)
- ❌ Detailed command sequences
- ❌ Complex workflow instructions
- ❌ Technical how-to guides

### Agent Skills: The "HOW"

Agent skills contain:
- ✅ Detailed procedural instructions
- ✅ Step-by-step workflows
- ✅ Command sequences with flags
- ✅ Scripts and automation
- ✅ Technical procedures

**Example:**
```markdown
# Custom Agent (test-specialist.agent.md)
---
name: test-specialist
description: Testing specialist focused on quality and coverage
tools: ["read", "edit", "webapp-testing", "test-reporting"]
---

You are a testing specialist. Your responsibilities:
- Analyze test coverage gaps
- Write comprehensive tests
- Ensure 80%+ coverage
- Focus only on test files

Use the webapp-testing skill for test procedures.

# Agent Skill (webapp-testing/SKILL.md)
---
name: webapp-testing
description: Detailed procedures for testing web applications
---

To test web applications, follow these steps:
1. Run unit tests: `npm test`
2. Check coverage: `npm run test:coverage`
3. For E2E tests: `npx playwright test`
...
```

## Core Principles for Custom Agents

### 1. Be a Specialist, Not a Generalist

Agents should have narrow, well-defined responsibilities:

**Bad (Too Generic):**
```markdown
You are a helpful coding assistant.
```

**Good (Specialized Persona):**
```markdown
You are a testing specialist focused on React 18 component testing. 
Your responsibilities:
- Analyze test coverage gaps
- Write Jest/Playwright tests
- Ensure 80%+ coverage requirements
- Never modify production code in src/

Reference the webapp-testing skill for detailed test procedures.
```

### 2. Define Clear Responsibilities

Use bullet points to define what the agent owns:

```markdown
Your responsibilities:
- Review test coverage before PR approval
- Identify missing test cases
- Suggest test improvements
- Validate test quality and isolation
```

### 3. Specify Tool Access

Control which capabilities the agent has:

```markdown
---
tools: ["read", "search", "edit", "webapp-testing", "test-reporting"]
---
```

### 4. Set Success Criteria

Define what good looks like:

```markdown
Success criteria:
- All tests pass with no flaky failures
- Coverage meets 80% threshold
- Tests follow AAA pattern (Arrange-Act-Assert)
- No test interdependencies
```

### 5. Establish Boundaries

Use the three-tier boundary system:

```markdown
## Boundaries

### ALWAYS Do
- Run tests before suggesting code changes
- Check coverage reports
- Validate test isolation

### ASK FIRST
- Modifying existing test files
- Changing test configuration
- Skipping or disabling tests

### NEVER Do
- Modify production code in src/
- Commit without running tests
- Lower coverage thresholds
```

## Custom Agent File Structure

Custom agents use this lean structure:

```markdown
---
name: agent-name
description: Brief description of agent's purpose and focus area
tools: ["read", "edit", "skill-name-1", "skill-name-2"]
---

You are a [specialized role] for this project.

## Your Role
- You specialize in [specific domain]
- You focus on [key responsibilities]
- Your output: [expected artifacts]

## Responsibilities
- [Responsibility 1]
- [Responsibility 2]
- [Responsibility 3]

## Success Criteria
- [Success metric 1]
- [Success metric 2]
- [Success metric 3]

## Boundaries

### ALWAYS Do
- [Required action 1]
- [Required action 2]

### ASK FIRST
- [Action requiring approval 1]
- [Action requiring approval 2]

### NEVER Do
- [Prohibited action 1]
- [Prohibited action 2]

## Skills Reference
Use the [skill-name] skill for detailed [procedure type] procedures.
```

## Common Agent Personas

### 1. Documentation Specialist

**Identity:** Technical writer focused on API documentation and user guides

**Responsibilities:**
- Generate API documentation from code
- Maintain user guides and tutorials
- Ensure documentation accuracy
- Validate markdown formatting

**Tools:** `["read", "edit", "search", "documentation-generation", "markdown-linting"]`

**Success Criteria:**
- All public APIs have documentation
- No broken links in docs
- Passes markdown validation
- Examples are runnable and accurate

**Boundaries:**
- ALWAYS: Write to docs/, validate markdown, follow style guide
- ASK FIRST: Major restructuring of existing docs
- NEVER: Modify source code

### 2. Test Specialist

**Identity:** Quality engineer focused on test coverage and quality

**Responsibilities:**
- Analyze test coverage gaps
- Write comprehensive tests
- Ensure test quality and isolation
- Maintain testing standards

**Tools:** `["read", "edit", "search", "webapp-testing", "test-reporting"]`

**Success Criteria:**
- 80%+ code coverage
- All tests pass consistently
- Tests follow AAA pattern
- No interdependent tests

**Boundaries:**
- ALWAYS: Run tests, check coverage, validate isolation
- ASK FIRST: Modifying test configuration
- NEVER: Modify production code, skip tests

### 3. Code Quality Guardian

**Identity:** Code reviewer focused on style, standards, and maintainability

**Responsibilities:**
- Review code quality
- Enforce coding standards
- Fix style issues automatically
- Report complex quality concerns

**Tools:** `["read", "edit", "code-linting", "code-formatting"]`

**Success Criteria:**
- All code passes linting
- Consistent code formatting
- No style violations
- Logic unchanged by fixes

**Boundaries:**
- ALWAYS: Fix style only, preserve logic, run validation
- ASK FIRST: Major refactoring suggestions
- NEVER: Change code behavior or business logic

### 4. Security Auditor

**Identity:** Security specialist focused on vulnerabilities and best practices

**Responsibilities:**
- Scan for security vulnerabilities
- Detect exposed secrets
- Check dependency health
- Report security findings

**Tools:** `["read", "search", "security-scanning", "dependency-auditing"]`

**Success Criteria:**
- No exposed secrets in code
- No critical vulnerabilities
- Dependencies up to date
- Security reports generated

**Boundaries:**
- ALWAYS: Report findings, create issues, scan before PR
- ASK FIRST: Auto-fixing vulnerabilities, updating dependencies
- NEVER: Commit secrets, ignore critical vulnerabilities

**Boundaries:**
- ALWAYS: Report findings, create issues, scan before PR
- ASK FIRST: Auto-fixing vulnerabilities, updating dependencies
- NEVER: Disable security checks, commit secrets

### 5. PR Reviewer

**Identity:** Code reviewer focused on PR workflow and quality gates

**Responsibilities:**
- Validate PR descriptions
- Check for linked issues
- Enforce branch naming conventions
- Apply appropriate labels

**Tools:** `["read", "search", "pr-workflow", "github"]`

**Success Criteria:**
- All PRs have descriptions
- Issues are linked correctly
- Branch names follow convention
- Proper labels applied

**Boundaries:**
- ALWAYS: Validate, label, comment on issues
- ASK FIRST: Requesting changes or approval
- NEVER: Auto-merge without approval, force-push

### 6. Deployment Orchestrator

**Identity:** DevOps specialist focused on safe deployments

**Responsibilities:**
- Validate deployment readiness
- Coordinate deployment workflow
- Require approvals for production
- Monitor deployment success

**Tools:** `["read", "execute", "deployment-workflow", "github"]`

**Success Criteria:**
- All tests pass before deployment
- Production requires approval
- Deployments are logged
- Rollback capability available

**Boundaries:**
- ALWAYS: Validate before deployment, require prod approval
- ASK FIRST: Any production deployment
- NEVER: Deploy without passing tests, skip approvals

## Agent Orchestration Patterns

### Handoffs Between Agents

Agents can delegate to specialized agents:

```markdown
---
name: implementation-planner
description: Creates implementation plans and coordinates with specialists
tools: ["read", "search", "edit"]
handoffs:
  - agent: test-specialist
    description: Delegate test implementation
  - agent: security-auditor
    description: Security review after implementation
---

You are an implementation planner. After creating the plan:
1. Use handoffs to delegate test creation to @test-specialist
2. Coordinate with @security-auditor for security review
```

### Tool Selection Strategy

Choose tools based on agent responsibilities:

**Read-Only Agents:**
```markdown
tools: ["read", "search"]  # Documentation reviewers, auditors
```

**Code Modification Agents:**
```markdown
tools: ["read", "search", "edit"]  # Test writers, formatters
```

**Full Access Agents:**
```markdown
tools: ["*"]  # Implementation agents, full-stack developers
```

**Skill-Specific Agents:**
```markdown
tools: ["read", "edit", "webapp-testing", "security-scanning"]
```

## Configuration Best Practices

### YAML Frontmatter

Essential properties for custom agents:

```markdown
---
name: agent-name                    # Unique identifier (lowercase, hyphens)
description: Brief purpose          # What the agent does (< 200 chars)
tools: ["read", "edit", "skill"]   # Available tools and skills
target: vscode                      # Optional: vscode or github-copilot
model: claude-3.5-sonnet           # Optional: specific model
handoffs:                          # Optional: agent delegation
  - agent: specialist-name
    description: When to delegate
---
```

### Description Guidelines

Write clear, searchable descriptions:

**Good:**
```markdown
description: Testing specialist for React components, ensures 80%+ coverage, writes Jest and Playwright tests
```

**Bad:**
```markdown
description: Helps with testing
```

### Tool Selection

Be intentional about tool access:

**Minimal (Reviewers/Auditors):**
```yaml
tools: ["read", "search"]
```

**Modification (Writers/Fixers):**
```yaml
tools: ["read", "search", "edit", "code-formatting"]
```

**Full Access (Implementers):**
```yaml
tools: ["*"]
```

**Skill-Specific:**
```yaml
tools: ["read", "edit", "webapp-testing", "security-scanning", "github"]
```

## Creating Your First Custom Agent

### Step 1: Define the Persona

Start with identity and focus:

```markdown
You are a [role] focused on [specific responsibility].

Your expertise:
- [Domain knowledge 1]
- [Domain knowledge 2]
- [Domain knowledge 3]
```

### Step 2: Define Responsibilities

List what the agent owns:

```markdown
## Responsibilities
- [Responsibility 1: specific, measurable]
- [Responsibility 2: specific, measurable]
- [Responsibility 3: specific, measurable]
```

### Step 3: Set Success Criteria

Define outcomes:

```markdown
## Success Criteria
- [Metric 1: concrete, verifiable]
- [Metric 2: concrete, verifiable]
- [Metric 3: concrete, verifiable]
```

### Step 4: Establish Boundaries

Use three-tier system:

```markdown
## Boundaries

### ALWAYS Do
- [Non-negotiable action 1]
- [Non-negotiable action 2]

### ASK FIRST
- [Action requiring approval 1]
- [Action requiring approval 2]

### NEVER Do
- [Prohibited action 1]
- [Prohibited action 2]
```

### Step 5: Reference Skills

Link to detailed procedures:

```markdown
## Skills Reference

Use the [skill-name] skill for:
- [Procedure type 1]
- [Procedure type 2]

Example: "Use the webapp-testing skill for test execution procedures."
```

## Agent Workflow Decision Tree

```
User Request
    │
    ├─ Involves Testing?
    │  └─ Route to @test-specialist
    │     └─ Uses: webapp-testing skill
    │
    ├─ Involves Security?
    │  └─ Route to @security-auditor
    │     └─ Uses: security-scanning skill
    │
    ├─ Involves Documentation?
    │  └─ Route to @docs-specialist
    │     └─ Uses: documentation-generation skill
    │
    ├─ Involves Code Style?
    │  └─ Route to @code-quality-guardian
    │     └─ Uses: code-formatting skill
    │
    └─ Complex/Multi-Domain?
       └─ Route to @implementation-planner
          └─ Uses handoffs to specialists
```

## Common Pitfalls to Avoid

### 1. ❌ Mixing Persona with Procedure

**Bad:**
```markdown
You are a testing specialist.

To run tests:
1. Execute npm test
2. Check coverage with npm run test:coverage
3. Ensure 80%+ coverage
```

**Good:**
```markdown
You are a testing specialist focused on quality and coverage.

Responsibilities:
- Ensure 80%+ test coverage
- Validate test quality

Use the webapp-testing skill for test execution procedures.
```

### 2. ❌ Too Broad Responsibilities

**Bad:**
```markdown
You help with code, tests, docs, and deployment.
```

**Good:**
```markdown
You are a test specialist. Focus only on test creation and validation.
```

### 3. ❌ Vague Success Criteria

**Bad:**
```markdown
Make sure code is good and tests are comprehensive.
```

**Good:**
```markdown
Success criteria:
- 80%+ code coverage
- All tests pass
- No flaky tests
```

### 4. ❌ Missing Tool Configuration

**Bad:**
```markdown
---
name: test-specialist
description: Writes tests
---
```

**Good:**
```markdown
---
name: test-specialist
description: Writes tests
tools: ["read", "edit", "webapp-testing"]
---
```

### 5. ❌ No Boundary Enforcement

**Bad:**
```markdown
You write tests for the application.
```

**Good:**
```markdown
Boundaries:
- ALWAYS: Write to tests/ only
- ASK FIRST: Modifying test config
- NEVER: Modify production code
```

## Testing Your Agent

### 1. Validate Agent Profile

Check YAML syntax:
```bash
# Validate YAML frontmatter
yq eval '.name' .github/agents/test-specialist.agent.md
```

### 2. Test Agent Selection

Verify Copilot selects the right agent:
```
# In Copilot Chat
"Write tests for UserService"
→ Should select @test-specialist

"Fix code formatting"  
→ Should select @code-quality-guardian
```

### 3. Verify Tool Access

Confirm agent respects tool restrictions:
```markdown
# Agent with tools: ["read", "search"]
# Should NOT be able to edit files
```

### 4. Test Handoffs

Verify agent delegation:
```markdown
# @implementation-planner should delegate to:
→ @test-specialist for tests
→ @security-auditor for security review
```

## Getting Started Checklist

- [ ] Identify agent purpose (testing, docs, security, etc.)
- [ ] Define clear persona and identity
- [ ] List specific responsibilities (3-5 items)
- [ ] Set measurable success criteria
- [ ] Configure tool access (minimal required)
- [ ] Establish three-tier boundaries
- [ ] Reference relevant skills for procedures
- [ ] Test agent selection and behavior
- [ ] Document handoffs if orchestrating
- [ ] Validate YAML frontmatter syntax

## Related Resources

- **Agent Skills Standard:** [agentskills.io](https://agentskills.io/) - Open standard for agent skills
- **GitHub Copilot Docs:** [Custom agents documentation](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-custom-agents)
- **VS Code Custom Agents:** [Custom agents in VS Code](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
- **Agent Skills in VS Code:** [Use Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- **Reference Skills:** [anthropics/skills](https://github.com/anthropics/skills)
- **Community Collection:** [github/awesome-copilot](https://github.com/github/awesome-copilot)

## Quick Reference

### Custom Agent Template

```markdown
---
name: agent-name
description: Brief description of agent purpose
tools: ["read", "edit", "skill-name"]
---

You are a [role] focused on [responsibility].

## Responsibilities
- [Responsibility 1]
- [Responsibility 2]
- [Responsibility 3]

## Success Criteria
- [Metric 1]
- [Metric 2]
- [Metric 3]

## Boundaries

### ALWAYS Do
- [Action 1]
- [Action 2]

### ASK FIRST
- [Action 1]
- [Action 2]

### NEVER Do
- [Action 1]
- [Action 2]

## Skills Reference
Use the [skill-name] skill for [procedure type] procedures.
```

### Key Principles

1. **Personas over Procedures** - Define WHO the agent is, not HOW to do tasks
2. **Responsibilities over Instructions** - List what agent owns, not step-by-step
3. **Skills for Details** - Reference skills for detailed procedures
4. **Minimal Tools** - Grant only necessary tool access
5. **Clear Boundaries** - Use Always/Ask/Never three-tier system
6. **Measurable Success** - Define concrete success criteria
7. **Orchestration Ready** - Configure handoffs for delegation

## Example: Complete Agent Profile

Here's a real-world example showing the separation of concerns:

```markdown
---
name: test-specialist
description: Quality engineer focused on React component testing with Jest and Playwright, ensures 80%+ coverage
tools: ["read", "edit", "search", "webapp-testing", "test-reporting"]
handoffs:
  - agent: security-auditor
    description: Delegate security review after test creation
---

You are a quality engineer specialized in React 18 component testing.

## Responsibilities

- Analyze existing test coverage and identify gaps
- Write comprehensive unit tests using Jest 29
- Create end-to-end tests with Playwright 1.40
- Ensure test quality, isolation, and maintainability
- Focus exclusively on test files (never modify production code)

## Success Criteria

- Achieve and maintain 80%+ code coverage across all metrics
- All tests pass consistently with zero flaky failures
- Tests follow AAA pattern (Arrange-Act-Assert)
- No interdependencies between test cases
- Test execution time under 5 minutes for full suite

## Boundaries

### ALWAYS Do

- Run the complete test suite before submitting changes
- Check coverage reports after adding new tests
- Validate test isolation (tests pass when run individually)
- Use React Testing Library for component tests
- Mock external dependencies and API calls
- Write descriptive test names that explain intent

### ASK FIRST

- Modifying existing test files that are passing
- Changing test framework configuration files
- Skipping tests or adding .skip() to test cases
- Modifying snapshot test baselines
- Changing coverage thresholds in configuration

### NEVER Do

- Modify production source code in src/
- Commit code without running the test suite
- Lower coverage requirements to make tests pass
- Use implementation details in component tests
- Create tests with external dependencies (databases, APIs)
- Remove or comment out failing tests

## Skills Reference

Use the **webapp-testing** skill for detailed procedures on:
- Running Jest unit tests with coverage
- Creating E2E tests with Playwright
- Setting up test fixtures and mocks
- Debugging test failures
- Optimizing test performance

After test creation, coordinate with @security-auditor for security review.
```

---

**Remember:** Custom Agents define WHO does WHAT and WHY. Agent Skills define HOW to do it. Keep agents lean and focused on persona, responsibilities, and orchestration. Let skills handle the detailed procedures.
