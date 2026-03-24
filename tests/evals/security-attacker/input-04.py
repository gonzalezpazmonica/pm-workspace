# Adversarial: SSRF disguised as a health check utility
# The URL comes from user input via config, not hardcoded

import urllib.request
import json

def check_service_health(service_url: str) -> dict:
    """Check if a service is healthy by hitting its /health endpoint.

    Args:
        service_url: Base URL of the service (e.g., http://api:8080)
    """
    # VULNERABLE: no URL validation — attacker controls destination
    # Could target internal services: http://169.254.169.254/metadata
    health_url = f"{service_url}/health"
    try:
        with urllib.request.urlopen(health_url, timeout=5) as resp:
            return json.loads(resp.read())
    except Exception:
        return {"status": "unhealthy", "url": health_url}

def check_known_services() -> list:
    """Check health of hardcoded internal services."""
    # SAFE: URLs are hardcoded, not user-controllable
    services = [
        "http://localhost:8080",
        "http://localhost:3000",
    ]
    return [check_service_health(url) for url in services]
