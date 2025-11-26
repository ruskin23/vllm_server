#!/usr/bin/env python3
"""
Example client for vLLM server

This script demonstrates how to use the vLLM server from your local machine
after setting up an SSH tunnel.

Usage:
    # Make sure SSH tunnel is running first:
    # ./connect.sh

    # Then run this script:
    python3 client_example.py

    # Or use as a module:
    from client_example import VLLMClient
    client = VLLMClient("http://localhost:8000/v1")
    response = client.chat("Hello!")
"""

import requests
from typing import List, Dict, Optional


class VLLMClient:
    """Simple client for vLLM OpenAI-compatible API"""

    def __init__(self, base_url: str = "http://localhost:8000/v1"):
        """
        Initialize client

        Args:
            base_url: Base URL of vLLM server (default: http://localhost:8000/v1)
        """
        self.base_url = base_url.rstrip('/')
        self.model_name = self._get_model_name()

    def _get_model_name(self) -> str:
        """Get the first available model name from server"""
        try:
            response = requests.get(f"{self.base_url}/models", timeout=5)
            if response.status_code == 200:
                models = response.json().get("data", [])
                if models:
                    return models[0]["id"]
            return "default"
        except Exception:
            return "default"

    def chat(
        self,
        message: str,
        max_tokens: int = 512,
        temperature: float = 0.7,
        system_prompt: Optional[str] = None
    ) -> str:
        """
        Send a chat message and get response

        Args:
            message: User message
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature (0.0 = deterministic, 1.0 = creative)
            system_prompt: Optional system prompt

        Returns:
            Model's response text
        """
        messages = []

        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})

        messages.append({"role": "user", "content": message})

        response = requests.post(
            f"{self.base_url}/chat/completions",
            json={
                "model": self.model_name,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
            timeout=60
        )

        response.raise_for_status()
        data = response.json()

        return data["choices"][0]["message"]["content"]

    def stream_chat(
        self,
        message: str,
        max_tokens: int = 512,
        temperature: float = 0.7,
        system_prompt: Optional[str] = None
    ):
        """
        Stream chat response token by token

        Args:
            message: User message
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            system_prompt: Optional system prompt

        Yields:
            Response text chunks as they arrive
        """
        messages = []

        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})

        messages.append({"role": "user", "content": message})

        response = requests.post(
            f"{self.base_url}/chat/completions",
            json={
                "model": self.model_name,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
                "stream": True,
            },
            stream=True,
            timeout=60
        )

        response.raise_for_status()

        for line in response.iter_lines():
            if line:
                line = line.decode('utf-8')
                if line.startswith('data: '):
                    data = line[6:]  # Remove 'data: ' prefix
                    if data != '[DONE]':
                        import json
                        chunk = json.loads(data)
                        if chunk["choices"][0].get("delta", {}).get("content"):
                            yield chunk["choices"][0]["delta"]["content"]


def main():
    """Example usage"""
    import sys

    # Initialize client
    print("Connecting to vLLM server...")
    try:
        client = VLLMClient("http://localhost:8000/v1")
        print(f"✓ Connected! Using model: {client.model_name}")
        print()
    except Exception as e:
        print(f"✗ Failed to connect: {e}")
        print()
        print("Make sure:")
        print("  1. vLLM server is running on GPU server")
        print("  2. SSH tunnel is active (run ./connect.sh)")
        sys.exit(1)

    # Example 1: Simple chat
    print("Example 1: Simple chat")
    print("-" * 50)
    prompt = "Explain what a neural network is in one sentence."
    print(f"User: {prompt}")

    try:
        response = client.chat(prompt, max_tokens=100, temperature=0.7)
        print(f"Assistant: {response}")
    except Exception as e:
        print(f"Error: {e}")

    print()

    # Example 2: With system prompt
    print("Example 2: With system prompt")
    print("-" * 50)
    system_prompt = "You are a helpful assistant that speaks like a pirate."
    prompt = "What's the weather like today?"
    print(f"System: {system_prompt}")
    print(f"User: {prompt}")

    try:
        response = client.chat(
            prompt,
            max_tokens=100,
            temperature=0.9,
            system_prompt=system_prompt
        )
        print(f"Assistant: {response}")
    except Exception as e:
        print(f"Error: {e}")

    print()

    # Example 3: Streaming response
    print("Example 3: Streaming response")
    print("-" * 50)
    prompt = "Write a haiku about coding."
    print(f"User: {prompt}")
    print("Assistant: ", end="", flush=True)

    try:
        for chunk in client.stream_chat(prompt, max_tokens=100, temperature=0.8):
            print(chunk, end="", flush=True)
        print()  # New line after streaming
    except Exception as e:
        print(f"Error: {e}")

    print()
    print("Done! See client_example.py for more details.")


if __name__ == "__main__":
    main()
