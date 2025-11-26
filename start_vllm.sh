#!/bin/bash
# Start vLLM server with configuration from vllm_config.yaml
#
# Usage:
#   ./start_vllm.sh              # Start in foreground
#   ./start_vllm.sh --background # Start in background

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/vllm_config.yaml"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Please create vllm_config.yaml:${NC}"
    echo "  cp vllm_config.example.yaml vllm_config.yaml"
    echo "  # Edit vllm_config.yaml based on your GPU"
    exit 1
fi

# Function to parse YAML (simple key extraction)
parse_yaml() {
    local key=$1
    local value=$(grep -E "^\s*$key:" "$CONFIG_FILE" | sed 's/.*: //' | tr -d '"' | tr -d "'")
    echo "$value"
}

# Read configuration from YAML
PORT=$(parse_yaml "port")
HOST=$(parse_yaml "host")
MODEL=$(parse_yaml "model")
MEMORY_UTIL=$(parse_yaml "memory_utilization")
MAX_MODEL_LEN=$(parse_yaml "max_model_len")
TENSOR_PARALLEL=$(parse_yaml "tensor_parallel_size")

# Read quantization settings (optional)
QUANT_METHOD=$(grep -E "^\s*method:" "$CONFIG_FILE" | grep -v "^#" | sed 's/.*: //' | tr -d '"' | tr -d "'" || echo "")
QUANT_LOAD_FORMAT=$(grep -E "^\s*load_format:" "$CONFIG_FILE" | grep -v "^#" | sed 's/.*: //' | tr -d '"' | tr -d "'" || echo "")

# Defaults if parsing failed
PORT=${PORT:-8000}
HOST=${HOST:-0.0.0.0}
MODEL=${MODEL:-mistralai/Mistral-7B-Instruct-v0.2}
MEMORY_UTIL=${MEMORY_UTIL:-0.85}
MAX_MODEL_LEN=${MAX_MODEL_LEN:-8192}
TENSOR_PARALLEL=${TENSOR_PARALLEL:-1}

# Parse command-line arguments (override config)
BACKGROUND=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --memory-utilization)
            MEMORY_UTIL="$2"
            shift 2
            ;;
        --max-model-len)
            MAX_MODEL_LEN="$2"
            shift 2
            ;;
        --tensor-parallel-size)
            TENSOR_PARALLEL="$2"
            shift 2
            ;;
        --background|-b)
            BACKGROUND=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Start vLLM server for OCR batch processing"
            echo "Configuration is read from vllm_config.yaml"
            echo ""
            echo "Options:"
            echo "  --port PORT                  Override server port (default from config)"
            echo "  --model MODEL                Override model name (default from config)"
            echo "  --memory-utilization FLOAT   Override GPU memory utilization (default from config)"
            echo "  --max-model-len INT          Override max sequence length (default from config)"
            echo "  --tensor-parallel-size INT   Override tensor parallelism (default from config)"
            echo "  --background, -b             Run server in background"
            echo "  --help, -h                   Show this help message"
            echo ""
            echo "Examples:"
            echo "  # Start with config file settings"
            echo "  ./start_vllm.sh"
            echo ""
            echo "  # Override concurrency"
            echo "  ./start_vllm.sh --memory-utilization 0.9"
            echo ""
            echo "  # Run in background"
            echo "  ./start_vllm.sh --background"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Display configuration
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}vLLM Server Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Model:                ${GREEN}${MODEL}${NC}"
echo -e "Port:                 ${GREEN}${PORT}${NC}"
echo -e "Host:                 ${GREEN}${HOST}${NC}"
echo -e "Memory Utilization:   ${GREEN}${MEMORY_UTIL}${NC}"
echo -e "Max Model Length:     ${GREEN}${MAX_MODEL_LEN}${NC}"
echo -e "Tensor Parallel Size: ${GREEN}${TENSOR_PARALLEL}${NC}"
if [ -n "$QUANT_METHOD" ]; then
    echo -e "Quantization:         ${GREEN}${QUANT_METHOD}${NC}"
    if [ -n "$QUANT_LOAD_FORMAT" ]; then
        echo -e "Load Format:          ${GREEN}${QUANT_LOAD_FORMAT}${NC}"
    fi
else
    echo -e "Quantization:         ${GREEN}None (or pre-quantized model)${NC}"
fi
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if vLLM is installed
if ! python -c "import vllm" 2>/dev/null; then
    echo -e "${RED}Error: vLLM is not installed${NC}"
    echo -e "${YELLOW}Please install vLLM:${NC}"
    echo "  pip install vllm==0.11.0"
    exit 1
fi

# Check if port is already in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Port $PORT is already in use${NC}"
    echo "A vLLM server may already be running."
    echo ""
    read -p "Kill existing process and restart? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Killing process on port $PORT..."
        lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
        sleep 2
    else
        echo "Exiting..."
        exit 1
    fi
fi

# Build vLLM command
VLLM_CMD="vllm serve ${MODEL}"
VLLM_CMD="${VLLM_CMD} --port ${PORT}"
VLLM_CMD="${VLLM_CMD} --host ${HOST}"
VLLM_CMD="${VLLM_CMD} --gpu-memory-utilization ${MEMORY_UTIL}"
VLLM_CMD="${VLLM_CMD} --max-model-len ${MAX_MODEL_LEN}"
VLLM_CMD="${VLLM_CMD} --tensor-parallel-size ${TENSOR_PARALLEL}"
VLLM_CMD="${VLLM_CMD} --disable-log-requests"

# Add quantization flags if specified
if [ -n "$QUANT_METHOD" ]; then
    VLLM_CMD="${VLLM_CMD} --quantization ${QUANT_METHOD}"
fi

if [ -n "$QUANT_LOAD_FORMAT" ]; then
    VLLM_CMD="${VLLM_CMD} --load-format ${QUANT_LOAD_FORMAT}"
fi

echo -e "${GREEN}Starting vLLM server...${NC}"
echo "Command: $VLLM_CMD"
echo ""

if [ "$BACKGROUND" = true ]; then
    # Run in background
    LOG_FILE="$SCRIPT_DIR/logs/vllm_server.log"
    mkdir -p "$SCRIPT_DIR/logs"

    echo -e "${YELLOW}Starting server in background...${NC}"
    echo "Logs will be written to: $LOG_FILE"

    # Start server in background
    nohup $VLLM_CMD > "$LOG_FILE" 2>&1 &
    SERVER_PID=$!

    echo "Server started with PID: $SERVER_PID"
    echo ""
    echo "Waiting for server to become ready..."

    # Wait for server to be ready
    if python vllm_server.py --server "http://localhost:${PORT}/v1" --wait --timeout 120; then
        echo -e "${GREEN}✓ Server is ready!${NC}"
        echo ""
        echo "To monitor logs:"
        echo "  tail -f $LOG_FILE"
        echo ""
        echo "To stop server:"
        echo "  kill $SERVER_PID"
        echo ""
        echo "To test server:"
        echo "  python vllm_server.py --server http://localhost:${PORT}/v1 --status"
        echo "  python vllm_server.py --server http://localhost:${PORT}/v1 --test"
    else
        echo -e "${RED}✗ Server failed to start${NC}"
        echo "Check logs at: $LOG_FILE"
        exit 1
    fi
else
    # Run in foreground
    echo -e "${YELLOW}Starting server in foreground (Ctrl+C to stop)...${NC}"
    echo ""
    exec $VLLM_CMD
fi
