"""
Security validation and input sanitization utilities.
"""

import re
from typing import Optional, List, Dict, Any


class InputValidator:
    """Validates and sanitizes user inputs."""
    
    # Common patterns for detecting malicious inputs
    INJECTION_PATTERNS = [
        r'<script[^>]*>.*?</script>',  # XSS scripts
        r'javascript:',                 # JavaScript protocol
        r'on\w+\s*=',                  # Event handlers
        r'eval\s*\(',                  # Eval function calls
        r'exec\s*\(',                  # Exec function calls
        r'\bSELECT\b.*\bFROM\b',       # SQL injection
        r'\bDROP\b.*\bTABLE\b',        # SQL DROP
        r'\bINSERT\b.*\bINTO\b',       # SQL INSERT
        r'\bDELETE\b.*\bFROM\b',       # SQL DELETE
        r'\bUPDATE\b.*\bSET\b',        # SQL UPDATE
    ]
    
    @staticmethod
    def sanitize_input(text: str, max_length: Optional[int] = None) -> str:
        """
        Sanitize user input by removing potentially harmful content.
        
        Note: This is basic sanitization. For production use with HTML content,
        consider using a dedicated library like bleach or html5lib.
        
        Args:
            text: Input text to sanitize
            max_length: Optional maximum length to enforce
            
        Returns:
            Sanitized text
        """
        if not isinstance(text, str):
            return str(text)
        
        # Remove null bytes
        text = text.replace('\x00', '')
        
        # Limit length if specified
        if max_length and len(text) > max_length:
            text = text[:max_length]
        
        # Basic HTML tag removal (for production, use a proper HTML sanitization library)
        # This is a simple filter and may not catch all XSS vectors
        text = re.sub(r'<[^>]*>', '', text)
        
        return text.strip()
    
    @staticmethod
    def detect_injection_attempt(text: str) -> bool:
        """
        Detect potential injection attempts in input.
        
        Args:
            text: Input text to check
            
        Returns:
            True if potential injection detected, False otherwise
        """
        if not isinstance(text, str):
            return False
        
        text_lower = text.lower()
        
        for pattern in InputValidator.INJECTION_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return True
        
        return False
    
    @staticmethod
    def validate_email(email: str) -> bool:
        """
        Validate email format.
        
        Args:
            email: Email address to validate
            
        Returns:
            True if valid email format, False otherwise
        """
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))
    
    @staticmethod
    def validate_url(url: str, allowed_schemes: Optional[List[str]] = None) -> bool:
        """
        Validate URL format and scheme.
        
        Args:
            url: URL to validate
            allowed_schemes: List of allowed URL schemes (default: http, https)
            
        Returns:
            True if valid URL, False otherwise
        """
        if allowed_schemes is None:
            allowed_schemes = ['http', 'https']
        
        # Pattern allows http, https, and ftp - but scheme check will enforce allowed_schemes
        pattern = r'^[a-zA-Z][a-zA-Z0-9+.-]*://[^\s/$.?#].[^\s]*$'
        if not re.match(pattern, url, re.IGNORECASE):
            return False
        
        scheme = url.split('://')[0].lower()
        return scheme in allowed_schemes


class PromptValidator:
    """Validates prompts for jailbreak attempts and unsafe content."""
    
    # Jailbreak attempt indicators
    JAILBREAK_INDICATORS = [
        'ignore previous instructions',
        'ignore all previous',
        'disregard previous',
        'forget everything',
        'you are no longer',
        'new instructions',
        'roleplay as',
        'pretend you are',
        'act as if',
        'simulate',
        'bypass',
        'override',
    ]
    
    @staticmethod
    def detect_jailbreak_attempt(prompt: str) -> bool:
        """
        Detect potential jailbreak attempts in prompts.
        
        Args:
            prompt: Prompt text to check
            
        Returns:
            True if potential jailbreak detected, False otherwise
        """
        if not isinstance(prompt, str):
            return False
        
        prompt_lower = prompt.lower()
        
        for indicator in PromptValidator.JAILBREAK_INDICATORS:
            if indicator in prompt_lower:
                return True
        
        return False
    
    @staticmethod
    def validate_prompt_length(prompt: str, min_length: int = 1, max_length: int = 10000) -> bool:
        """
        Validate prompt length is within acceptable range.
        
        Args:
            prompt: Prompt text to check
            min_length: Minimum acceptable length
            max_length: Maximum acceptable length
            
        Returns:
            True if length is valid, False otherwise
        """
        if not isinstance(prompt, str):
            return False
        
        length = len(prompt)
        return min_length <= length <= max_length


class OutputValidator:
    """Validates agent outputs for sensitive information leakage."""
    
    # Patterns for sensitive information
    SENSITIVE_PATTERNS = {
        'credit_card': r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
        'ssn': r'\b\d{3}-\d{2}-\d{4}\b',
        # More specific API key patterns to reduce false positives
        'api_key': r'\b[A-Za-z0-9]{40,}\b',  # Increased minimum length
        'password': r'password\s*[:=]\s*[^\s]+',
        'bearer_token': r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
        'private_key': r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----',
    }
    
    @staticmethod
    def detect_sensitive_data(text: str) -> Dict[str, List[str]]:
        """
        Detect potential sensitive data in output.
        
        Args:
            text: Output text to check
            
        Returns:
            Dictionary mapping data type to list of matches found
        """
        if not isinstance(text, str):
            return {}
        
        findings = {}
        
        for data_type, pattern in OutputValidator.SENSITIVE_PATTERNS.items():
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                findings[data_type] = matches
        
        return findings
    
    @staticmethod
    def mask_sensitive_data(text: str) -> str:
        """
        Mask sensitive data in output text.
        
        Args:
            text: Output text to mask
            
        Returns:
            Text with sensitive data masked
        """
        if not isinstance(text, str):
            return str(text)
        
        masked = text
        
        # Mask credit cards
        masked = re.sub(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b', 
                       'XXXX-XXXX-XXXX-XXXX', masked)
        
        # Mask SSN
        masked = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', 
                       'XXX-XX-XXXX', masked)
        
        # Mask API keys (long alphanumeric strings - 40+ chars to reduce false positives)
        masked = re.sub(r'\b[A-Za-z0-9]{40,}\b', 
                       'XXXXXXXXXXXX', masked)
        
        # Mask passwords
        masked = re.sub(r'(password\s*[:=]\s*)[^\s]+', 
                       r'\1********', masked, flags=re.IGNORECASE)
        
        # Mask bearer tokens
        masked = re.sub(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', 
                       'Bearer XXXXXXXXXXXX', masked)
        
        return masked


class SecurityPolicy:
    """Define and check security policies for agent behavior."""
    
    @staticmethod
    def check_output_policy(output: str, policy: Dict[str, Any]) -> Dict[str, Any]:
        """
        Check if output complies with security policy.
        
        Args:
            output: Agent output to check
            policy: Security policy configuration
            
        Returns:
            Dictionary with compliance status and violations
        """
        violations = []
        
        # Check for sensitive data if policy requires it
        if policy.get('block_sensitive_data', True):
            sensitive = OutputValidator.detect_sensitive_data(output)
            if sensitive:
                violations.append({
                    'type': 'sensitive_data_leak',
                    'details': sensitive
                })
        
        # Check output length limits
        max_length = policy.get('max_output_length')
        if max_length and len(output) > max_length:
            violations.append({
                'type': 'output_too_long',
                'details': f'Output length {len(output)} exceeds limit {max_length}'
            })
        
        return {
            'compliant': len(violations) == 0,
            'violations': violations
        }
