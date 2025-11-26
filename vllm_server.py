"""vLLM Server Utilities

Helper functions to check server health, wait for startup, and test inference.
Compatible with any vLLM server running OpenAI-compatible API.
"""

import requests
import time
from typing import Optional, Dict, Any


def check_server_health(server_url: str, timeout: int = 5) -> bool:
    """Check if vLLM server is responding

    Args:
        server_url: Base URL of vLLM server (e.g., "http://localhost:30024/v1")
        timeout: Request timeout in seconds

    Returns:
        True if server is healthy, False otherwise
    """
    try:
        # Try to get models endpoint (standard OpenAI-compatible endpoint)
        response = requests.get(f"{server_url}/models", timeout=timeout)
        return response.status_code == 200
    except (requests.ConnectionError, requests.Timeout, requests.RequestException):
        return False


def wait_for_server_ready(
    server_url: str, timeout: int = 120, check_interval: int = 2, verbose: bool = False
) -> bool:
    """Wait for vLLM server to become ready

    Args:
        server_url: Base URL of vLLM server
        timeout: Maximum time to wait in seconds
        check_interval: Time between health checks in seconds
        verbose: Print status messages

    Returns:
        True if server became ready, False if timeout

    Example:
        >>> if wait_for_server_ready("http://localhost:30024/v1", verbose=True):
        ...     print("Server ready!")
        ... else:
        ...     print("Server failed to start")
    """
    start_time = time.time()
    elapsed = 0

    if verbose:
        print(f"Waiting for vLLM server at {server_url}...")

    while elapsed < timeout:
        if check_server_health(server_url):
            if verbose:
                print(f"✓ Server ready after {elapsed:.1f}s")
            return True

        time.sleep(check_interval)
        elapsed = time.time() - start_time

        if verbose and int(elapsed) % 10 == 0:
            print(f"  Still waiting... ({elapsed:.0f}s / {timeout}s)")

    if verbose:
        print(f"✗ Server failed to start within {timeout}s")

    return False


def get_server_status(server_url: str, timeout: int = 5) -> Optional[Dict[str, Any]]:
    """Get vLLM server status and model information

    Args:
        server_url: Base URL of vLLM server
        timeout: Request timeout in seconds

    Returns:
        Dictionary with server status information, or None if server not responding

    Example:
        >>> status = get_server_status("http://localhost:30024/v1")
        >>> if status:
        ...     print(f"Model: {status['model']}")
    """
    try:
        # Get list of models
        response = requests.get(f"{server_url}/models", timeout=timeout)

        if response.status_code == 200:
            data = response.json()

            # Extract model info
            models = data.get("data", [])
            if models:
                model_info = models[0]
                return {
                    "status": "online",
                    "model": model_info.get("id", "unknown"),
                    "created": model_info.get("created", 0),
                    "owned_by": model_info.get("owned_by", "unknown"),
                }

        return {
            "status": "unknown",
            "error": f"Unexpected response: {response.status_code}",
        }

    except (requests.ConnectionError, requests.Timeout) as e:
        return {"status": "offline", "error": str(e)}
    except Exception as e:
        return {"status": "error", "error": str(e)}


def test_inference(
    server_url: str,
    test_prompt: str = "Hello! How are you?",
    timeout: int = 30,
    model_name: str = None
) -> Optional[Dict[str, Any]]:
    """Test vLLM server with a simple inference request

    Args:
        server_url: Base URL of vLLM server
        test_prompt: Simple text prompt to test with
        timeout: Request timeout in seconds
        model_name: Model name (if None, uses first available model)

    Returns:
        Dictionary with test results, or None if request failed

    Example:
        >>> result = test_inference("http://localhost:8000/v1")
        >>> if result and result['success']:
        ...     print(f"Inference working! Response: {result['response']}")
    """
    try:
        # If model name not provided, get first available model
        if model_name is None:
            models_response = requests.get(f"{server_url}/models", timeout=5)
            if models_response.status_code == 200:
                models = models_response.json().get("data", [])
                if models:
                    model_name = models[0]["id"]
                else:
                    model_name = "default"
            else:
                model_name = "default"

        response = requests.post(
            f"{server_url}/chat/completions",
            json={
                "model": model_name,
                "messages": [{"role": "user", "content": test_prompt}],
                "max_tokens": 100,
                "temperature": 0.1,
            },
            timeout=timeout,
        )

        if response.status_code == 200:
            data = response.json()
            return {
                "success": True,
                "response": data["choices"][0]["message"]["content"],
                "usage": data.get("usage", {}),
            }
        else:
            return {
                "success": False,
                "error": f"HTTP {response.status_code}: {response.text}",
            }

    except Exception as e:
        return {"success": False, "error": str(e)}


if __name__ == "__main__":
    """Command-line interface for server utilities"""
    import argparse

    parser = argparse.ArgumentParser(description="vLLM server utilities")
    parser.add_argument(
        "--server", default="http://localhost:8000/v1", help="vLLM server URL"
    )
    parser.add_argument(
        "--check", action="store_true", help="Check if server is running"
    )
    parser.add_argument(
        "--wait", action="store_true", help="Wait for server to become ready"
    )
    parser.add_argument(
        "--status", action="store_true", help="Get server status and model info"
    )
    parser.add_argument(
        "--test", action="store_true", help="Test inference with simple prompt"
    )
    parser.add_argument(
        "--timeout", type=int, default=120, help="Timeout in seconds (for --wait)"
    )

    args = parser.parse_args()

    if args.check:
        print(f"Checking server at {args.server}...")
        if check_server_health(args.server):
            print("✓ Server is responding")
            exit(0)
        else:
            print("✗ Server not responding")
            exit(1)

    if args.wait:
        print(f"Waiting for server at {args.server}...")
        if wait_for_server_ready(args.server, timeout=args.timeout, verbose=True):
            print("✓ Server ready")
            exit(0)
        else:
            print("✗ Server failed to start")
            exit(1)

    if args.status:
        print(f"Getting status from {args.server}...")
        status = get_server_status(args.server)
        if status:
            print(f"Status: {status['status']}")
            if status["status"] == "online":
                print(f"Model: {status.get('model', 'unknown')}")
            elif "error" in status:
                print(f"Error: {status['error']}")
        else:
            print("Failed to get status")
            exit(1)

    if args.test:
        print(f"Testing inference at {args.server}...")
        result = test_inference(args.server)
        if result and result["success"]:
            print("✓ Inference test successful")
            print(f"Response: {result['response'][:100]}...")
            print(f"Usage: {result['usage']}")
            exit(0)
        else:
            print("✗ Inference test failed")
            if result:
                print(f"Error: {result['error']}")
            exit(1)

    parser.print_help()
