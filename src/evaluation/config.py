"""
Evaluation configuration and criteria builders for Azure AI agent evaluations.
"""

from typing import Dict, List, Any, Optional


class EvaluationCriteria:
    """Builder for Azure AI evaluation criteria."""
    
    @staticmethod
    def get_task_completion(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get task completion evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "task_completion",
            "evaluator_name": "builtin.task_completion",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_task_adherence(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get task adherence evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "task_adherence",
            "evaluator_name": "builtin.task_adherence",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_intent_resolution(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get intent resolution evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "intent_resolution",
            "evaluator_name": "builtin.intent_resolution",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_groundedness(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get groundedness evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "groundedness",
            "evaluator_name": "builtin.groundedness",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "tool_definitions": "{{item.tool_definitions}}",
                "response": "{{item.response}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_relevance(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get relevance evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "relevance",
            "evaluator_name": "builtin.relevance",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_tool_call_accuracy(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get tool call accuracy evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "tool_call_accuracy",
            "evaluator_name": "builtin.tool_call_accuracy",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "tool_definitions": "{{item.tool_definitions}}",
                "tool_calls": "{{item.tool_calls}}",
                "response": "{{item.response}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_tool_selection(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get tool selection evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "tool_selection",
            "evaluator_name": "builtin.tool_selection",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_calls": "{{item.tool_calls}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_tool_input_accuracy(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get tool input accuracy evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "tool_input_accuracy",
            "evaluator_name": "builtin.tool_input_accuracy",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_tool_output_utilization(deployment_name: str, is_reasoning_model: bool = False) -> Dict[str, Any]:
        """Get tool output utilization evaluator configuration."""
        config = {
            "type": "azure_ai_evaluator",
            "name": "tool_output_utilization",
            "evaluator_name": "builtin.tool_output_utilization",
            "initialization_parameters": {
                "deployment_name": deployment_name,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        }
        if is_reasoning_model:
            config["initialization_parameters"]["is_reasoning_model"] = True
        return config
    
    @staticmethod
    def get_standard_criteria(deployment_name: str, is_reasoning_model: bool = False) -> List[Dict[str, Any]]:
        """Get standard evaluation criteria including system, RAG, and process evaluators."""
        return [
            # System Evaluation
            EvaluationCriteria.get_task_completion(deployment_name, is_reasoning_model),
            EvaluationCriteria.get_task_adherence(deployment_name, is_reasoning_model),
            EvaluationCriteria.get_intent_resolution(deployment_name, is_reasoning_model),
            # RAG Evaluation
            EvaluationCriteria.get_groundedness(deployment_name, is_reasoning_model),
            EvaluationCriteria.get_relevance(deployment_name, is_reasoning_model),
            # Process Evaluation
            EvaluationCriteria.get_tool_call_accuracy(deployment_name, is_reasoning_model),
            EvaluationCriteria.get_tool_selection(deployment_name, is_reasoning_model),
            EvaluationCriteria.get_tool_input_accuracy(deployment_name, is_reasoning_model),
            EvaluationCriteria.get_tool_output_utilization(deployment_name, is_reasoning_model),
        ]


class DataSourceConfig:
    """Builder for evaluation data source configurations."""
    
    @staticmethod
    def get_custom_schema() -> Dict[str, Any]:
        """Get custom data source schema for agent evaluations."""
        return {
            "type": "custom",
            "item_schema": {
                "type": "object",
                "properties": {
                    "query": {
                        "anyOf": [
                            {"type": "string"},
                            {"type": "array", "items": {"type": "object"}}
                        ]
                    },
                    "tool_definitions": {
                        "anyOf": [
                            {"type": "object"},
                            {"type": "array", "items": {"type": "object"}}
                        ]
                    },
                    "tool_calls": {
                        "anyOf": [
                            {"type": "object"},
                            {"type": "array", "items": {"type": "object"}}
                        ]
                    },
                    "response": {
                        "anyOf": [
                            {"type": "string"},
                            {"type": "array", "items": {"type": "object"}}
                        ]
                    },
                },
                "required": ["query", "response", "tool_definitions"],
            },
            "include_sample_schema": True,
        }
    
    @staticmethod
    def get_red_team_schema() -> Dict[str, Any]:
        """Get red team data source schema."""
        return {
            "type": "azure_ai_source",
            "scenario": "red_team"
        }
