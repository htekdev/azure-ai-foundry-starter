"""
Security evaluation criteria and red team testing utilities.
"""

from typing import Dict, List, Any, Optional

try:
    from azure.ai.projects.models import RiskCategory
except ImportError:
    # Fallback if azure packages not installed
    class RiskCategory:
        PROHIBITED_ACTIONS = "prohibited_actions"
        VIOLENCE = "violence"
        SEXUAL = "sexual"
        SELF_HARM = "self_harm"
        HATE_UNFAIRNESS = "hate_unfairness"


class SecurityCriteria:
    """Builder for security and red team evaluation criteria."""
    
    @staticmethod
    def get_prohibited_actions(evaluator_version: str = "1") -> Dict[str, Any]:
        """Get prohibited actions evaluator configuration."""
        return {
            "type": "azure_ai_evaluator",
            "name": "Prohibited Actions",
            "evaluator_name": "builtin.prohibited_actions",
            "evaluator_version": evaluator_version,
        }
    
    @staticmethod
    def get_task_adherence_security(evaluator_version: str = "1") -> Dict[str, Any]:
        """Get task adherence evaluator for security testing."""
        return {
            "type": "azure_ai_evaluator",
            "name": "Task Adherence",
            "evaluator_name": "builtin.task_adherence",
            "evaluator_version": evaluator_version,
        }
    
    @staticmethod
    def get_sensitive_data_leakage(evaluator_version: str = "1") -> Dict[str, Any]:
        """Get sensitive data leakage evaluator configuration."""
        return {
            "type": "azure_ai_evaluator",
            "name": "Sensitive Data Leakage",
            "evaluator_name": "builtin.sensitive_data_leakage",
            "evaluator_version": evaluator_version,
        }
    
    @staticmethod
    def get_self_harm(evaluator_version: str = "1") -> Dict[str, Any]:
        """Get self harm content evaluator configuration."""
        return {
            "type": "azure_ai_evaluator",
            "name": "Self Harm",
            "evaluator_name": "builtin.self_harm",
            "evaluator_version": evaluator_version,
        }
    
    @staticmethod
    def get_violence(evaluator_version: str = "1") -> Dict[str, Any]:
        """Get violence content evaluator configuration."""
        return {
            "type": "azure_ai_evaluator",
            "name": "Violence",
            "evaluator_name": "builtin.violence",
            "evaluator_version": evaluator_version,
        }
    
    @staticmethod
    def get_sexual(evaluator_version: str = "1") -> Dict[str, Any]:
        """Get sexual content evaluator configuration."""
        return {
            "type": "azure_ai_evaluator",
            "name": "Sexual",
            "evaluator_name": "builtin.sexual",
            "evaluator_version": evaluator_version,
        }
    
    @staticmethod
    def get_hate_unfairness(evaluator_version: str = "1") -> Dict[str, Any]:
        """Get hate and unfairness evaluator configuration."""
        return {
            "type": "azure_ai_evaluator",
            "name": "Hate Unfairness",
            "evaluator_name": "builtin.hate_unfairness",
            "evaluator_version": evaluator_version,
        }
    
    @staticmethod
    def get_agent_safety_criteria(evaluator_version: str = "1") -> List[Dict[str, Any]]:
        """
        Get comprehensive agent safety evaluation criteria.
        
        Args:
            evaluator_version: Version of evaluators to use
            
        Returns:
            List of security evaluation criteria
        """
        return [
            SecurityCriteria.get_prohibited_actions(evaluator_version),
            SecurityCriteria.get_task_adherence_security(evaluator_version),
            SecurityCriteria.get_sensitive_data_leakage(evaluator_version),
            SecurityCriteria.get_self_harm(evaluator_version),
            SecurityCriteria.get_violence(evaluator_version),
            SecurityCriteria.get_sexual(evaluator_version),
            SecurityCriteria.get_hate_unfairness(evaluator_version),
        ]


class RedTeamConfig:
    """Configuration builder for red team testing."""
    
    # Available attack strategies
    ATTACK_STRATEGIES = [
        "Flip",           # Flip the attack to the opposite
        "Base64",         # Encode attack in base64
        "Jailbreak",      # Attempt to bypass safety guardrails
        "Persuasion",     # Use persuasive language
        "RolePlay",       # Pretend to be someone else
    ]
    
    @staticmethod
    def get_risk_categories() -> Dict[str, RiskCategory]:
        """
        Get available risk categories for red team testing.
        
        Returns:
            Dictionary mapping category names to RiskCategory enums
        """
        return {
            "prohibited_actions": RiskCategory.PROHIBITED_ACTIONS,
            "violence": RiskCategory.VIOLENCE,
            "sexual": RiskCategory.SEXUAL,
            "self_harm": RiskCategory.SELF_HARM,
            "hate_unfairness": RiskCategory.HATE_UNFAIRNESS,
        }
    
    @staticmethod
    def create_red_team_data_source(
        taxonomy_id: str,
        target: Dict[str, Any],
        attack_strategies: Optional[List[str]] = None,
        num_turns: int = 1
    ) -> Dict[str, Any]:
        """
        Create red team data source configuration.
        
        Args:
            taxonomy_id: ID of the taxonomy file
            target: Agent target configuration
            attack_strategies: List of attack strategies to use
            num_turns: Number of conversation turns
            
        Returns:
            Red team data source configuration
        """
        if attack_strategies is None:
            attack_strategies = ["Flip", "Base64"]
        
        return {
            "type": "azure_ai_red_team",
            "item_generation_params": {
                "type": "red_team_taxonomy",
                "attack_strategies": attack_strategies,
                "num_turns": num_turns,
                "source": {"type": "file_id", "id": taxonomy_id},
            },
            "target": target,
        }


class ToolDescriptionExtractor:
    """Utility for extracting tool descriptions from agent versions."""
    
    @staticmethod
    def extract_tool_descriptions(agent_version) -> List[Dict[str, str]]:
        """
        Extract tool descriptions from an agent version object.
        
        Args:
            agent_version: Agent version object from Azure AI
            
        Returns:
            List of tool descriptions with name and description
        """
        tools = agent_version.definition.get("tools", [])
        tool_descriptions = []
        
        for tool in tools:
            if tool["type"] == "openapi":
                tool_descriptions.append({
                    "name": tool["openapi"]["name"],
                    "description": (
                        tool["openapi"]["description"]
                        if "description" in tool["openapi"]
                        else "No description provided"
                    ),
                })
            else:
                tool_descriptions.append({
                    "name": tool["name"] if "name" in tool else "Unnamed Tool",
                    "description": tool["description"] if "description" in tool else "No description provided",
                })
        
        return tool_descriptions


def to_json_primitive(obj: Any) -> Any:
    """
    Convert Azure AI objects to JSON-serializable primitives.
    
    Note: Uses vars() to extract object attributes. Be cautious with objects
    that may contain sensitive data. The function filters out private attributes
    (starting with '_') but sensitive public attributes will be included.
    
    Args:
        obj: Object to convert
        
    Returns:
        JSON-serializable representation of the object
    """
    if obj is None or isinstance(obj, (str, int, float, bool)):
        return obj
    
    if isinstance(obj, (list, tuple)):
        return [to_json_primitive(i) for i in obj]
    
    if isinstance(obj, dict):
        return {k: to_json_primitive(v) for k, v in obj.items()}
    
    # Try common serialization methods
    for method in ("to_dict", "as_dict", "dict", "serialize"):
        if hasattr(obj, method):
            try:
                return to_json_primitive(getattr(obj, method)())
            except Exception:
                pass
    
    # Extract __dict__ but filter out private attributes (starting with '_')
    # Note: This may still expose sensitive public attributes
    if hasattr(obj, "__dict__"):
        return to_json_primitive({k: v for k, v in vars(obj).items() if not k.startswith("_")})
    
    # Fallback to string representation
    return str(obj)
