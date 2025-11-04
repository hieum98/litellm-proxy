from litellm.integrations.custom_logger import CustomLogger
import litellm
from datetime import datetime
import json

class ProxyCustomHandler(CustomLogger):
    """
    Custom handler for additional logging and monitoring.
    This gets called for every request to the proxy.
    """
    
    def log_pre_api_call(self, model, messages, kwargs):
        """Called before making the LLM API call"""
        print(f"[{datetime.now()}] Pre-API Call to model: {model}")
        # You can add custom logic here, e.g., additional validation
        
    def log_post_api_call(self, kwargs, response_obj, start_time, end_time):
        """Called after receiving response from LLM API"""
        duration = (end_time - start_time).total_seconds()
        print(f"[{datetime.now()}] Post-API Call completed in {duration}s")
        
    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        """Called on successful API call (async)"""
        # Extract request metadata
        litellm_params = kwargs.get("litellm_params", {})
        metadata = litellm_params.get("metadata", {})
        
        # Get user information
        user_id = metadata.get("user_api_key_user_id", "unknown")
        team_id = metadata.get("user_api_key_team_id", "unknown")
        
        # Calculate metrics
        duration = (end_time - start_time).total_seconds()
        
        # Log success event
        log_data = {
            "event": "success",
            "timestamp": datetime.now().isoformat(),
            "model": kwargs.get("model", "unknown"),
            "user_id": user_id,
            "team_id": team_id,
            "duration_seconds": duration,
            "tokens_used": getattr(response_obj, "usage", {}).get("total_tokens", 0) if hasattr(response_obj, "usage") else 0
        }
        
        print(f"[SUCCESS] {json.dumps(log_data)}")
        
        # You can send to external logging service here
        # await send_to_external_service(log_data)
        
    async def async_log_failure_event(self, kwargs, response_obj, start_time, end_time):
        """Called on failed API call (async)"""
        litellm_params = kwargs.get("litellm_params", {})
        metadata = litellm_params.get("metadata", {})
        
        log_data = {
            "event": "failure",
            "timestamp": datetime.now().isoformat(),
            "model": kwargs.get("model", "unknown"),
            "user_id": metadata.get("user_api_key_user_id", "unknown"),
            "error": str(response_obj),
        }
        
        print(f"[FAILURE] {json.dumps(log_data)}")
        
    def log_success_event(self, kwargs, response_obj, start_time, end_time):
        """Sync version of success logging"""
        print(f"[{datetime.now()}] Request completed successfully")
        
    def log_failure_event(self, kwargs, response_obj, start_time, end_time):
        """Sync version of failure logging"""
        print(f"[{datetime.now()}] Request failed: {response_obj}")

# Create instance for LiteLLM to use
proxy_handler_instance = ProxyCustomHandler()
