"""vLLM Server Configuration Loader"""

import yaml
from pathlib import Path
from typing import Dict, Any


class VLLMConfig:
    """Load and manage vLLM server configuration from YAML file"""

    def __init__(self, config_path: str = "vllm_config.yaml"):
        self.config_path = Path(config_path)
        self._config = self._load_config()

    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file

        Returns:
            dict: Configuration dictionary

        Raises:
            FileNotFoundError: If config file doesn't exist
            yaml.YAMLError: If YAML is malformed
        """
        if not self.config_path.exists():
            raise FileNotFoundError(
                f"Configuration file not found: {self.config_path}\n"
                f"Please create it from the example:\n"
                f"  cp vllm_config.example.yaml vllm_config.yaml\n"
                f"  # Then edit vllm_config.yaml with your settings"
            )

        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)

        return config

    @property
    def server_port(self) -> int:
        """Get server port"""
        return self._config['server']['port']

    @property
    def server_host(self) -> str:
        """Get server host"""
        return self._config['server']['host']

    @property
    def model_name(self) -> str:
        """Get model name/path"""
        return self._config['server']['model']

    @property
    def server_url(self) -> str:
        """Get full server URL"""
        return f"http://localhost:{self.server_port}/v1"

    @property
    def memory_utilization(self) -> float:
        """Get GPU memory utilization"""
        return self._config['gpu']['memory_utilization']

    @property
    def max_model_len(self) -> int:
        """Get maximum model length"""
        return self._config['gpu']['max_model_len']

    @property
    def tensor_parallel_size(self) -> int:
        """Get tensor parallel size"""
        return self._config['gpu']['tensor_parallel_size']

    def get_vllm_args(self) -> Dict[str, Any]:
        """Get all vLLM arguments as dict

        Returns:
            dict: vLLM server arguments
        """
        return {
            'model': self.model_name,
            'port': self.server_port,
            'host': self.server_host,
            'gpu_memory_utilization': self.memory_utilization,
            'max_model_len': self.max_model_len,
            'tensor_parallel_size': self.tensor_parallel_size,
        }


if __name__ == "__main__":
    """Test configuration loading"""
    try:
        config = VLLMConfig()
        print("Configuration loaded successfully:")
        print(f"  Model: {config.model_name}")
        print(f"  Server: {config.server_url}")
        print(f"  Memory Utilization: {config.memory_utilization}")
        print(f"  Max Model Length: {config.max_model_len}")
        print(f"  Tensor Parallel: {config.tensor_parallel_size}")
    except FileNotFoundError as e:
        print(f"Error: {e}")
