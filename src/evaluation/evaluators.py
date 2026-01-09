"""
Evaluation utilities for running and monitoring Azure AI agent evaluations.
"""

import time
from typing import Any, Dict, List, Optional
from pprint import pprint


class EvaluationRunner:
    """Utilities for running and monitoring evaluations."""
    
    @staticmethod
    def wait_for_completion(client, eval_id: str, run_id: str, 
                           poll_interval: int = 5, 
                           verbose: bool = True) -> Dict[str, Any]:
        """
        Wait for an evaluation run to complete.
        
        Args:
            client: Azure AI OpenAI client
            eval_id: Evaluation ID
            run_id: Evaluation run ID
            poll_interval: Seconds between status checks
            verbose: Print status updates
            
        Returns:
            Dictionary containing run status and results
        """
        while True:
            run = client.evals.runs.retrieve(run_id=run_id, eval_id=eval_id)
            
            if run.status == "completed":
                if verbose:
                    print(f"✅ Eval Run completed successfully")
                output_items = list(client.evals.runs.output_items.list(run_id=run.id, eval_id=eval_id))
                return {
                    "status": run.status,
                    "output_items": output_items,
                    "report_url": getattr(run, 'report_url', None)
                }
            elif run.status == "failed":
                if verbose:
                    print(f"❌ Eval Run failed")
                return {
                    "status": run.status,
                    "error": getattr(run, 'error', 'Unknown error'),
                    "report_url": getattr(run, 'report_url', None)
                }
            
            if verbose:
                print(f"⏳ Waiting for eval run to complete... Status: {run.status}")
            time.sleep(poll_interval)
    
    @staticmethod
    def print_results(results: Dict[str, Any], detailed: bool = False) -> None:
        """
        Print evaluation results in a readable format.
        
        Args:
            results: Results dictionary from wait_for_completion
            detailed: Show detailed output items
        """
        print("\n" + "="*60)
        print("EVALUATION RESULTS")
        print("="*60)
        print(f"Status: {results['status']}")
        
        if results.get('report_url'):
            print(f"Report URL: {results['report_url']}")
        
        if results['status'] == 'completed':
            output_items = results.get('output_items', [])
            print(f"Number of output items: {len(output_items)}")
            
            if detailed and output_items:
                print("\nDetailed Output Items:")
                print("-"*60)
                pprint(output_items)
        elif results['status'] == 'failed':
            print(f"Error: {results.get('error', 'Unknown error')}")
        
        print("="*60 + "\n")
    
    @staticmethod
    def aggregate_scores(output_items: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Aggregate scores from evaluation output items.
        
        Args:
            output_items: List of evaluation output items
            
        Returns:
            Dictionary with aggregated scores by evaluator
        """
        aggregated = {}
        
        for item in output_items:
            # Extract scores from each item
            # This structure may vary based on Azure AI evaluation output format
            if isinstance(item, dict):
                for key, value in item.items():
                    if 'score' in str(key).lower():
                        evaluator_name = key.replace('_score', '')
                        if evaluator_name not in aggregated:
                            aggregated[evaluator_name] = []
                        if isinstance(value, (int, float)):
                            aggregated[evaluator_name].append(value)
        
        # Calculate averages
        summary = {}
        for evaluator, scores in aggregated.items():
            if scores:
                summary[evaluator] = {
                    'average': sum(scores) / len(scores),
                    'min': min(scores),
                    'max': max(scores),
                    'count': len(scores)
                }
        
        return summary


class EvaluationDataBuilder:
    """Builder for evaluation test data."""
    
    @staticmethod
    def create_conversation_item(
        query: List[Dict[str, Any]],
        response: List[Dict[str, Any]],
        tool_definitions: List[Dict[str, Any]],
        tool_calls: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        """
        Create a conversation item for evaluation.
        
        Args:
            query: List of conversation messages (including system message)
            response: Agent's response with tool calls and results
            tool_definitions: Available tool schemas
            tool_calls: Optional separate tool calls (if not in response)
            
        Returns:
            Formatted conversation item for evaluation
        """
        return {
            "query": query,
            "tool_definitions": tool_definitions,
            "response": response,
            "tool_calls": tool_calls,
        }
    
    @staticmethod
    def create_sample_weather_agent_data() -> Dict[str, Any]:
        """
        Create sample evaluation data for a weather agent.
        
        Returns:
            Sample conversation item for testing
        """
        query = [
            {"role": "system", "content": "You are a weather report agent."},
            {
                "createdAt": "2025-03-14T08:00:00Z",
                "role": "user",
                "content": [{
                    "type": "text",
                    "text": "Can you send me an email at test@example.com with weather information for Seattle?"
                }],
            },
        ]
        
        response = [
            {
                "createdAt": "2025-03-26T17:27:35Z",
                "run_id": "run_sample_001",
                "role": "assistant",
                "content": [{
                    "type": "tool_call",
                    "tool_call_id": "call_fetch_weather_001",
                    "name": "fetch_weather",
                    "arguments": {"location": "Seattle"},
                }],
            },
            {
                "createdAt": "2025-03-26T17:27:37Z",
                "run_id": "run_sample_001",
                "tool_call_id": "call_fetch_weather_001",
                "role": "tool",
                "content": [{"type": "tool_result", "tool_result": {"weather": "Rainy, 14°C"}}],
            },
            {
                "createdAt": "2025-03-26T17:27:38Z",
                "run_id": "run_sample_001",
                "role": "assistant",
                "content": [{
                    "type": "tool_call",
                    "tool_call_id": "call_send_email_001",
                    "name": "send_email",
                    "arguments": {
                        "recipient": "test@example.com",
                        "subject": "Weather Information for Seattle",
                        "body": "The current weather in Seattle is rainy with a temperature of 14°C.",
                    },
                }],
            },
            {
                "createdAt": "2025-03-26T17:27:41Z",
                "run_id": "run_sample_001",
                "tool_call_id": "call_send_email_001",
                "role": "tool",
                "content": [{
                    "type": "tool_result",
                    "tool_result": {"message": "Email successfully sent to test@example.com."},
                }],
            },
            {
                "createdAt": "2025-03-26T17:27:42Z",
                "run_id": "run_sample_001",
                "role": "assistant",
                "content": [{
                    "type": "text",
                    "text": "I have successfully sent you an email with the weather information for Seattle. The current weather is rainy with a temperature of 14°C.",
                }],
            },
        ]
        
        tool_definitions = [
            {
                "name": "fetch_weather",
                "description": "Fetches the weather information for the specified location.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "location": {"type": "string", "description": "The location to fetch weather for."}
                    },
                },
            },
            {
                "name": "send_email",
                "description": "Sends an email with the specified subject and body to the recipient.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "recipient": {"type": "string", "description": "Email address of the recipient."},
                        "subject": {"type": "string", "description": "Subject of the email."},
                        "body": {"type": "string", "description": "Body content of the email."},
                    },
                },
            }
        ]
        
        return EvaluationDataBuilder.create_conversation_item(
            query=query,
            response=response,
            tool_definitions=tool_definitions,
            tool_calls=None
        )
