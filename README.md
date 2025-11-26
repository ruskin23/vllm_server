# vLLM Server Deployment

Quick deployment setup for running vLLM inference servers on rented GPUs. Clone this repo, configure, and start serving.

## Features

- Single configuration file for all settings
- Simple startup script with foreground/background modes
- Health check and testing utilities
- GPU memory optimization presets
- OpenAI-compatible API

## Quick Start

### 1. Clone and Setup

```bash
# Clone this repo
git clone <your-repo-url>
cd vllm_server

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure

```bash
# Copy example config
cp vllm_config.example.yaml vllm_config.yaml

# Edit configuration
nano vllm_config.yaml
```

Key settings to adjust:
- `server.model`: HuggingFace model name or local path
- `server.port`: Server port (default: 8000)
- `gpu.memory_utilization`: GPU VRAM usage (0.75-0.95)
- `gpu.max_model_len`: Max sequence length

**GPU Presets:**
- 8 GB GPU: `memory_utilization: 0.75`, `max_model_len: 4096`
- 16 GB GPU: `memory_utilization: 0.85`, `max_model_len: 8192`
- 24 GB GPU: `memory_utilization: 0.90`, `max_model_len: 16384`
- 40+ GB GPU: `memory_utilization: 0.95`, `max_model_len: 32768`

### 3. Start Server

```bash
# Make script executable
chmod +x start_vllm.sh

# Run in foreground (Ctrl+C to stop)
./start_vllm.sh

# Or run in background
./start_vllm.sh --background
```

### 4. Verify Server

```bash
# Check if server is running
python vllm_server.py --server http://localhost:8000/v1 --check

# Get server status
python vllm_server.py --server http://localhost:8000/v1 --status

# Test inference
python vllm_server.py --server http://localhost:8000/v1 --test
```

## Usage Examples

### Using the Server

Once running, the server exposes an OpenAI-compatible API at `http://localhost:8000/v1`.

**Test with curl:**
```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model-name",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

**Test with Python:**
```python
import requests

response = requests.post(
    "http://localhost:8000/v1/chat/completions",
    json={
        "model": "your-model-name",
        "messages": [{"role": "user", "content": "Hello!"}],
        "max_tokens": 100,
        "temperature": 0.7
    }
)

print(response.json()["choices"][0]["message"]["content"])
```

**Use with OpenAI Python library:**
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="dummy"  # vLLM doesn't require auth by default
)

response = client.chat.completions.create(
    model="your-model-name",
    messages=[{"role": "user", "content": "Hello!"}],
    max_tokens=100
)

print(response.choices[0].message.content)
```

### Management Commands

```bash
# Monitor server logs (if running in background)
tail -f logs/vllm_server.log

# Stop background server
# Find PID from logs or:
lsof -ti:8000 | xargs kill

# Monitor GPU usage
watch -n 1 nvidia-smi
```

## Configuration Reference

### vllm_config.yaml

```yaml
server:
  port: 8000                    # Server port
  host: "0.0.0.0"              # Bind address
  model: "model-name"          # HuggingFace model or path

gpu:
  memory_utilization: 0.90     # GPU VRAM fraction (0.0-1.0)
  max_model_len: 8192          # Max sequence length
  tensor_parallel_size: 1      # Number of GPUs
```

### Start Script Options

```bash
./start_vllm.sh [OPTIONS]

Options:
  --port PORT                  Override server port
  --model MODEL                Override model name
  --memory-utilization FLOAT   Override GPU memory utilization
  --max-model-len INT          Override max sequence length
  --tensor-parallel-size INT   Override tensor parallelism
  --background, -b             Run server in background
  --help, -h                   Show help message
```

## Server Utilities

The `vllm_server.py` script provides utilities for managing the server:

```bash
# Check if server is responding
python vllm_server.py --server http://localhost:8000/v1 --check

# Wait for server to become ready (useful in scripts)
python vllm_server.py --server http://localhost:8000/v1 --wait --timeout 120

# Get server status and model info
python vllm_server.py --server http://localhost:8000/v1 --status

# Test inference with simple prompt
python vllm_server.py --server http://localhost:8000/v1 --test
```

**Use as Python library:**
```python
from vllm_server import check_server_health, wait_for_server_ready

# Check if server is up
if check_server_health("http://localhost:8000/v1"):
    print("Server is ready!")

# Wait for server startup
if wait_for_server_ready("http://localhost:8000/v1", timeout=120, verbose=True):
    print("Server started successfully!")
```

## Configuration Management

The `config.py` module provides a Python interface to the YAML configuration:

```python
from config import VLLMConfig

# Load configuration
config = VLLMConfig()

# Access settings
print(f"Model: {config.model_name}")
print(f"Server URL: {config.server_url}")
print(f"Memory Utilization: {config.memory_utilization}")

# Get all vLLM arguments as dict
vllm_args = config.get_vllm_args()
```

## Troubleshooting

### Server won't start

**Check GPU availability:**
```bash
nvidia-smi
```

**Check if port is in use:**
```bash
lsof -i :8000
```

**View server logs:**
```bash
tail -f logs/vllm_server.log
```

### Out of memory errors

Reduce GPU memory usage:
1. Lower `memory_utilization` (e.g., from 0.90 to 0.85)
2. Lower `max_model_len` (e.g., from 8192 to 4096)
3. Use a smaller model or quantized version

### Slow inference

Increase GPU utilization:
1. Raise `memory_utilization` (if you have VRAM headroom)
2. Monitor GPU with `nvidia-smi` to check utilization
3. Ensure model fits in VRAM without swapping

### Server not responding

```bash
# Check if process is running
ps aux | grep vllm

# Check if port is listening
netstat -tulpn | grep 8000

# Test with curl
curl http://localhost:8000/v1/models
```

## Common Scenarios

### Running on a rented GPU

```bash
# SSH into the server
ssh user@gpu-server

# Clone repo
git clone <your-repo-url>
cd vllm_server

# Install dependencies
pip install -r requirements.txt

# Configure
cp vllm_config.example.yaml vllm_config.yaml
nano vllm_config.yaml  # Set your model and GPU settings

# Start server in background
./start_vllm.sh --background

# Verify
python vllm_server.py --server http://localhost:8000/v1 --test
```

### Switching models

```bash
# Stop current server
lsof -ti:8000 | xargs kill

# Edit config
nano vllm_config.yaml  # Change server.model

# Start with new model
./start_vllm.sh --background
```

### Running multiple models

Use different ports:
```bash
# Start first model on port 8000
./start_vllm.sh --port 8000 --model "model-1" --background

# Start second model on port 8001
./start_vllm.sh --port 8001 --model "model-2" --background
```

## Files

- `vllm_config.example.yaml` - Example configuration file
- `start_vllm.sh` - Server startup script
- `vllm_server.py` - Server utilities (health checks, testing)
- `config.py` - Configuration loader Python module
- `requirements.txt` - Python dependencies

## Requirements

- Python 3.8+
- NVIDIA GPU with CUDA support
- vLLM 0.6.0+
- 8GB+ VRAM (depends on model)

## Tips

1. **Always test after configuration changes** - Use `--test` flag to verify
2. **Monitor GPU usage** - Use `watch -n 1 nvidia-smi` to optimize settings
3. **Start with conservative settings** - Increase `memory_utilization` gradually
4. **Use background mode for production** - Easier to manage and monitor
5. **Keep logs** - The `logs/` directory contains valuable debugging info

## License

MIT (or your preferred license)
