"""
Evaluation utilities for Azure AI agent quality assessment.

This package provides reusable evaluation configurations, criteria builders,
and utilities for running and monitoring agent evaluations.
"""

from .config import EvaluationCriteria, DataSourceConfig
from .evaluators import EvaluationRunner, EvaluationDataBuilder

__all__ = [
    'EvaluationCriteria',
    'DataSourceConfig',
    'EvaluationRunner',
    'EvaluationDataBuilder',
]
