# vLLM Server Deployment

Quick deployment setup for running vLLM inference servers on rented GPUs. Clone this repo, configure, and start serving.

## Features

- Single configuration file for all settings
- Simple startup script with foreground/background modes
- Quantization support (AWQ, GPTQ, FP8, bitsandbytes)
- Run 7B models on 6GB GPUs with quantization
- SSH tunnel setup for remote access
- Health check and testing utilities
- GPU memory optimization presets
- OpenAI-compatible API

## Quick Start

Two scenarios: **Local GPU** (you have a GPU on your machine) or **Remote GPU** (rented GPU server).

### Local GPU Setup

```bash
# Clone this repo
git clone <your-repo-url>
cd vllm_server

# Install dependencies
pip install -r requirements.txt

# Configure and start (see sections below)
```

### Remote GPU Setup (RunPod, Vast.ai, etc.)

**On the GPU server:**
```bash
# Clone repo
git clone <your-repo-url>
cd vllm_server

# One-command setup
./setup_remote.sh
# This installs dependencies and helps configure

# Start server
./start_vllm.sh --background
```

**On your local machine:**
```bash
# In the same repo directory
./connect.sh
# Enter SSH details when prompted
# Keep this running to maintain the tunnel
```

Now use `http://localhost:8000` from your local machine!

See **[Remote Access](#remote-access)** section for details.

---

## Configuration

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
- `quantization.method`: (Optional) Quantization method for low VRAM

**GPU Presets (Without Quantization):**
- 8 GB GPU: `memory_utilization: 0.75`, `max_model_len: 4096`
- 16 GB GPU: `memory_utilization: 0.85`, `max_model_len: 8192`
- 24 GB GPU: `memory_utilization: 0.90`, `max_model_len: 16384`
- 40+ GB GPU: `memory_utilization: 0.95`, `max_model_len: 32768`

**With Quantization (Run 7B models on smaller GPUs):**
- 6 GB GPU: Use AWQ quantized model
- 8 GB GPU: Use AWQ quantized model
- 12 GB GPU: Run quantized 7B or standard 3B models

See [Quantization](#quantization) section for details.

## Starting the Server

```bash
# Make script executable
chmod +x start_vllm.sh

# Run in foreground (Ctrl+C to stop)
./start_vllm.sh

# Or run in background
./start_vllm.sh --background
```

## Verify Server

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

## Quantization

Quantization reduces model memory usage by 3-4x with minimal quality loss, allowing you to run larger models on smaller GPUs or rent cheaper hardware.

### Why Use Quantization?

**Benefits:**
- Run 7B models on 6-8GB GPUs
- Rent cheaper GPUs (12GB instead of 24GB)
- More concurrent requests (more VRAM for KV-cache)
- Save $300+/month on GPU costs

**Quality:**
- AWQ/GPTQ 4-bit: ~0.1% perplexity increase
- Nearly identical outputs for most tasks
- Minimal impact on generation quality

### Quick Start with Quantization

**Option 1: Use pre-quantized model (Easiest)**

```yaml
server:
  model: "TheBloke/Mistral-7B-Instruct-v0.2-AWQ"

gpu:
  memory_utilization: 0.80
  max_model_len: 4096

# No quantization section needed - model is already quantized!
```

**Option 2: Dynamic quantization**

```yaml
server:
  model: "mistralai/Mistral-7B-Instruct-v0.2"

gpu:
  memory_utilization: 0.75
  max_model_len: 4096

quantization:
  method: "bitsandbytes"
  load_format: "bitsandbytes-4bit"
```

### Quantization Methods

| Method | Bits | Quality | Speed | Notes |
|--------|------|---------|-------|-------|
| **AWQ** | 4-bit | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Best overall, use pre-quantized models |
| **GPTQ** | 4-bit | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Good compatibility |
| **FP8** | 8-bit | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Requires newer GPUs (H100, Ada) |
| **bitsandbytes** | 4-bit | ⭐⭐⭐⭐ | ⭐⭐⭐ | Works with any model, no pre-quantization |

### Popular Pre-Quantized Models

All available on HuggingFace from TheBloke:

```yaml
# 7B models (need ~4GB VRAM quantized)
- "TheBloke/Mistral-7B-Instruct-v0.2-AWQ"
- "TheBloke/Llama-2-7B-Chat-AWQ"
- "TheBloke/zephyr-7B-beta-AWQ"
- "TheBloke/OpenHermes-2.5-Mistral-7B-AWQ"

# 13B models (need ~8GB VRAM quantized)
- "TheBloke/Llama-2-13B-Chat-AWQ"
- "TheBloke/Vicuna-13B-v1.5-AWQ"

# Mixtral 8x7B (need ~24GB VRAM even quantized)
- "TheBloke/Mixtral-8x7B-Instruct-v0.1-AWQ"
```

### Cost Comparison

**Without quantization:**
```
Mistral-7B (FP16): 14GB VRAM needed
GPU: RTX 4090 (24GB) @ $0.79/hour
Cost: $18.96/day = $570/month
```

**With quantization:**
```
Mistral-7B (AWQ 4-bit): 4GB VRAM needed
GPU: RTX 4070 Ti (12GB) @ $0.34/hour
Cost: $8.16/day = $245/month
Savings: $325/month!
```

## Low VRAM Setup (6-8GB GPUs)

Running vLLM on consumer GPUs or budget cloud instances.

### For 6GB GPU (RTX 3060, RTX 4060)

**Recommended config:**
```yaml
server:
  port: 8000
  host: "127.0.0.1"  # localhost for local use
  model: "TheBloke/Mistral-7B-Instruct-v0.2-AWQ"

gpu:
  memory_utilization: 0.70  # Conservative
  max_model_len: 4096       # 4K context
  tensor_parallel_size: 1
```

**Alternative: Smaller non-quantized models**
```yaml
server:
  model: "microsoft/Phi-3-mini-4k-instruct"  # 3B model, ~3GB

gpu:
  memory_utilization: 0.75
  max_model_len: 4096
```

### For 8GB GPU (RTX 3070, RTX 4060 Ti)

```yaml
server:
  model: "TheBloke/Mistral-7B-Instruct-v0.2-AWQ"

gpu:
  memory_utilization: 0.75
  max_model_len: 6144  # 6K context
  tensor_parallel_size: 1
```

### Small Models (No Quantization Needed)

Perfect for 6GB GPUs without quantization:

| Model | VRAM | Context | Best For |
|-------|------|---------|----------|
| Phi-3-mini | ~3GB | 4K | General chat, reasoning |
| Qwen2.5-3B | ~3GB | 8K | Multilingual, long context |
| Gemma-2-2B | ~2GB | 8K | Efficient, good quality |
| TinyLlama-1.1B | ~1GB | 2K | Testing, very fast |

### Tips for Low VRAM

1. **Start conservative** - Use lower `memory_utilization` (0.70-0.75)
2. **Reduce context** - Lower `max_model_len` if you don't need long context
3. **Use AWQ models** - Best quality for 4-bit quantization
4. **Monitor GPU** - Use `watch -n 1 nvidia-smi` to check VRAM usage
5. **Increase gradually** - If stable, increase `memory_utilization` by 0.05

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

## Remote Access

### How It Works

When running vLLM on a remote GPU server, you need to access it from your local machine. The secure way is using **SSH tunneling** (port forwarding).

**The Flow:**
```
Your Laptop                SSH Tunnel              GPU Server
┌──────────┐              ┌──────────┐            ┌──────────┐
│          │              │          │            │          │
│  Python  │─────────────▶│localhost │───────────▶│  vLLM    │
│  script  │  HTTP to     │   :8000  │  Forwarded │  :8000   │
│          │  localhost   │          │  via SSH   │          │
└──────────┘              └──────────┘            └──────────┘
```

### Setup SSH Tunnel

**Step 1: Start vLLM on GPU server**
```bash
# SSH into your GPU server
ssh user@gpu-server-ip

# Clone and setup
git clone <your-repo-url>
cd vllm_server
./setup_remote.sh

# Start server
./start_vllm.sh --background
```

**Step 2: Create tunnel from your laptop**
```bash
# On your local machine, in the repo directory
./connect.sh

# You'll be prompted for:
# - SSH connection details (user@ip -p port)
# - Remote port (default: 8000)
# - Local port (default: 8000)

# Settings are saved in .tunnel_config for next time
```

**Step 3: Use from your laptop**
```python
# On your laptop - talk to localhost!
import requests

response = requests.post(
    "http://localhost:8000/v1/chat/completions",
    json={
        "model": "your-model",
        "messages": [{"role": "user", "content": "Hello!"}]
    }
)
print(response.json()["choices"][0]["message"]["content"])
```

### Provider-Specific Instructions

**RunPod:**
1. Go to your pod's connection info
2. Copy the "SSH over exposed TCP" command
3. Example: `ssh root@123.456.789.0 -p 12345 -i ~/.ssh/id_ed25519`
4. When running `./connect.sh`, paste: `root@123.456.789.0 -p 12345 -i ~/.ssh/id_ed25519`

**Vast.ai:**
1. Click on your instance
2. Copy the SSH command from "Connect" section
3. Example: `ssh -p 41234 root@ssh5.vast.ai`
4. When running `./connect.sh`, paste: `-p 41234 root@ssh5.vast.ai`

**AWS/GCP/Azure:**
1. Use your instance's public IP
2. Ensure security group allows SSH (port 22)
3. Use your SSH key path
4. Example: `ubuntu@54.123.45.67 -i ~/.ssh/aws-key.pem`

### Manual SSH Tunnel (Alternative)

If you prefer not to use the script:
```bash
# On your laptop
ssh -L 8000:localhost:8000 user@gpu-server-ip -N

# Keep this terminal open
# Access server at http://localhost:8000
```

### Troubleshooting Remote Access

**Tunnel disconnects frequently:**
```bash
# Edit connect.sh or use manual tunnel with keep-alive:
ssh -L 8000:localhost:8000 user@gpu-server-ip -N \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3
```

**"Port already in use":**
```bash
# Kill process using the port
lsof -ti:8000 | xargs kill -9

# Or use a different local port
./connect.sh  # Choose different local port when prompted
```

**Can't connect to GPU server:**
- Verify SSH works: `ssh user@gpu-server-ip`
- Check firewall allows SSH (port 22)
- Confirm SSH credentials are correct

**Tunnel works but server not responding:**
```bash
# SSH into GPU server and check if vLLM is running
ssh user@gpu-server-ip
python3 vllm_server.py --check
```

## Common Scenarios

### Running on a rented GPU (Complete Workflow)

**On GPU server:**
```bash
# Clone and setup
git clone <your-repo-url>
cd vllm_server
./setup_remote.sh

# Edit configuration if needed
nano vllm_config.yaml

# Start server
./start_vllm.sh --background
```

**On your laptop:**
```bash
# Create SSH tunnel
cd vllm_server  # Same repo
./connect.sh

# In another terminal, test it
python3 client_example.py
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

**Core:**
- `vllm_config.example.yaml` - Example configuration file
- `start_vllm.sh` - Server startup script
- `config.py` - Configuration loader Python module
- `requirements.txt` - Python dependencies

**Utilities:**
- `vllm_server.py` - Server utilities (health checks, testing)
- `client_example.py` - Example Python client with streaming support

**Remote Access:**
- `connect.sh` - SSH tunnel setup (run on local machine)
- `setup_remote.sh` - One-command GPU server setup

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
