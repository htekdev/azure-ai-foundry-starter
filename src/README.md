# Evaluation and Security Utilities

This directory contains reusable utility modules for Azure AI agent quality assessment and safety validation.

## Overview

The implementation provides two main module groups:

### 1. Evaluation Utilities (`src/evaluation/`)

Reusable components for running and configuring Azure AI agent evaluations.

**Modules:**
- `config.py` - Evaluation criteria and data source configuration builders
- `evaluators.py` - Evaluation runners, result aggregators, and test data builders

**Key Features:**
- Pre-configured evaluation criteria (task completion, adherence, groundedness, etc.)
- Standard data source schemas for custom evaluations
- Evaluation run monitoring with polling and result formatting
- Sample test data builders

### 2. Security Utilities (`src/security/`)

Components for agent security validation and red team testing.

**Modules:**
- `evaluators.py` - Security evaluation criteria and red team configuration
- `validators.py` - Input/output validation and sanitization

**Key Features:**
- Comprehensive safety criteria (prohibited actions, sensitive data, violence, etc.)
- Red team attack strategies and risk categories
- Input sanitization and injection detection
- Output validation for sensitive data leakage
- Prompt jailbreak attempt detection
- Security policy compliance checking

## Quick Start

### Evaluation Example

```python
from src.evaluation import EvaluationCriteria, EvaluationRunner

# Get standard evaluation criteria
deployment_name = "gpt-4o-mini"
criteria = EvaluationCriteria.get_standard_criteria(deployment_name)

# Run evaluation (with Azure AI client)
result = EvaluationRunner.wait_for_completion(client, eval_id, run_id)
EvaluationRunner.print_results(result)
```

### Security Example

```python
from src.security import InputValidator, OutputValidator, SecurityCriteria

# Validate and sanitize user input
user_input = InputValidator.sanitize_input(raw_input)

# Check for malicious patterns
if InputValidator.detect_injection_attempt(user_input):
    # Handle malicious input
    pass

# Check agent output for sensitive data
sensitive = OutputValidator.detect_sensitive_data(agent_output)
if sensitive:
    agent_output = OutputValidator.mask_sensitive_data(agent_output)

# Get security evaluation criteria
safety_criteria = SecurityCriteria.get_agent_safety_criteria()
```

## Complete Examples

Run the comprehensive example script:

```bash
python src/examples/module_usage_examples.py
```

This demonstrates:
- Building evaluation criteria
- Creating test data
- Security validation
- Input sanitization
- Output checking
- Policy compliance

## Module Documentation

### Evaluation Modules

#### EvaluationCriteria

Static builder methods for evaluation criteria:

- `get_task_completion(deployment_name)` - Task completion evaluator
- `get_task_adherence(deployment_name)` - Task adherence evaluator
- `get_intent_resolution(deployment_name)` - Intent resolution evaluator
- `get_groundedness(deployment_name)` - RAG groundedness evaluator
- `get_relevance(deployment_name)` - Response relevance evaluator
- `get_tool_call_accuracy(deployment_name)` - Tool call accuracy evaluator
- `get_tool_selection(deployment_name)` - Tool selection evaluator
- `get_tool_input_accuracy(deployment_name)` - Tool input accuracy evaluator
- `get_tool_output_utilization(deployment_name)` - Tool output utilization evaluator
- `get_standard_criteria(deployment_name)` - All standard criteria

#### DataSourceConfig

- `get_custom_schema()` - Custom data source schema for agent evaluations
- `get_red_team_schema()` - Red team data source schema

#### EvaluationRunner

- `wait_for_completion(client, eval_id, run_id, ...)` - Poll until evaluation completes
- `print_results(results, detailed=False)` - Format and print results
- `aggregate_scores(output_items)` - Aggregate scores by evaluator

#### EvaluationDataBuilder

- `create_conversation_item(query, response, tool_definitions, tool_calls)` - Build test item
- `create_sample_weather_agent_data()` - Sample test data for weather agent

### Security Modules

#### SecurityCriteria

Static builder methods for security criteria:

- `get_prohibited_actions()` - Prohibited actions evaluator
- `get_task_adherence_security()` - Task adherence for security
- `get_sensitive_data_leakage()` - Sensitive data leakage evaluator
- `get_self_harm()` - Self harm content evaluator
- `get_violence()` - Violence content evaluator
- `get_sexual()` - Sexual content evaluator
- `get_hate_unfairness()` - Hate and unfairness evaluator
- `get_agent_safety_criteria()` - All safety criteria

#### RedTeamConfig

- `get_risk_categories()` - Available risk categories (violence, self harm, etc.)
- `create_red_team_data_source(taxonomy_id, target, ...)` - Red team data source
- `ATTACK_STRATEGIES` - Available attack strategies (Flip, Base64, Jailbreak, etc.)

#### InputValidator

- `sanitize_input(text, max_length)` - Remove harmful content
- `detect_injection_attempt(text)` - Detect SQL/XSS injection
- `validate_email(email)` - Validate email format
- `validate_url(url, allowed_schemes)` - Validate URL format

#### PromptValidator

- `detect_jailbreak_attempt(prompt)` - Detect jailbreak patterns
- `validate_prompt_length(prompt, min_length, max_length)` - Check length

#### OutputValidator

- `detect_sensitive_data(text)` - Find credit cards, SSNs, API keys, etc.
- `mask_sensitive_data(text)` - Mask detected sensitive information

#### SecurityPolicy

- `check_output_policy(output, policy)` - Check compliance with security policy

#### Utility Functions

- `to_json_primitive(obj)` - Convert Azure AI objects to JSON
- `ToolDescriptionExtractor.extract_tool_descriptions(agent_version)` - Extract tool info

## Integration with Existing Agents

The existing agent scripts can be refactored to use these utilities:

### Before (agenteval.py)

```python
# Inline criteria definition
testing_criteria = [
    {
        "type": "azure_ai_evaluator",
        "name": "task_completion",
        # ... lots of configuration ...
    },
    # ... repeated for each evaluator
]
```

### After (using utilities)

```python
from src.evaluation import EvaluationCriteria, EvaluationRunner

# Use pre-built criteria
testing_criteria = EvaluationCriteria.get_standard_criteria(model_deployment_name)

# Use evaluation runner
result = EvaluationRunner.wait_for_completion(client, eval_id, run_id)
EvaluationRunner.print_results(result, detailed=True)
```

### Before (redteam.py)

```python
# Inline security criteria
def _get_agent_safety_evaluation_criteria():
    return [
        {
            "type": "azure_ai_evaluator",
            "name": "Prohibited Actions",
            # ... configuration
        },
        # ... repeated
    ]
```

### After (using utilities)

```python
from src.security import SecurityCriteria, to_json_primitive

# Use pre-built security criteria
testing_criteria = SecurityCriteria.get_agent_safety_criteria()

# Use utility for JSON conversion
with open(output_path, "w") as f:
    f.write(json.dumps(to_json_primitive(results), indent=2))
```

## Benefits

1. **Reduced Code Duplication** - Common evaluation and security logic is centralized
2. **Consistency** - All agents use the same evaluation criteria and security checks
3. **Maintainability** - Update criteria in one place, all agents benefit
4. **Reusability** - Easy to add new agents with proper evaluation and security
5. **Testing** - Utilities can be unit tested independently
6. **Documentation** - Clear API with docstrings and examples

## Best Practices

1. **Always sanitize user inputs** before processing:
   ```python
   clean_input = InputValidator.sanitize_input(user_input)
   ```

2. **Check for malicious patterns**:
   ```python
   if InputValidator.detect_injection_attempt(input):
       raise ValueError("Malicious input detected")
   ```

3. **Validate outputs before returning**:
   ```python
   sensitive = OutputValidator.detect_sensitive_data(output)
   if sensitive:
       output = OutputValidator.mask_sensitive_data(output)
   ```

4. **Use standard criteria for consistency**:
   ```python
   criteria = EvaluationCriteria.get_standard_criteria(deployment)
   ```

5. **Monitor evaluation runs**:
   ```python
   result = EvaluationRunner.wait_for_completion(client, eval_id, run_id, verbose=True)
   ```

## Testing

The modules include defensive checks and handle edge cases:

- Null/None inputs
- Non-string inputs (converts to string)
- Missing optional parameters (uses defaults)
- Azure SDK import errors (provides fallbacks)

Run the example script to validate functionality:

```bash
python src/examples/module_usage_examples.py
```

## Future Enhancements

Potential improvements for these utilities:

1. **Custom evaluators** - Support for user-defined evaluation criteria
2. **Evaluation caching** - Cache evaluation results to avoid re-running
3. **Advanced security** - More sophisticated pattern matching for threats
4. **Performance metrics** - Add latency and token usage tracking
5. **Reporting** - Generate evaluation and security reports
6. **Configuration** - Load criteria from configuration files
7. **Async support** - Async versions of runners and validators

## License

These utilities are part of the Azure AI Foundry Starter template.
