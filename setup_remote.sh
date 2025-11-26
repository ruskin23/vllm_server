#!/bin/bash
# Remote GPU Server Setup Script
# Run this on the GPU server after cloning the repo
#
# Usage:
#   chmod +x setup_remote.sh
#   ./setup_remote.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_header "vLLM Server Remote Setup"

# Check if running on a system with GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Warning: nvidia-smi not found${NC}"
    echo "This script is meant for GPU servers"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}GPU detected:${NC}"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    echo ""
fi

# Step 1: Install dependencies
print_header "Step 1: Installing Dependencies"

echo "Checking Python version..."
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python version: $python_version"
echo ""

echo "Installing Python packages..."
pip install -q -r requirements.txt

echo -e "${GREEN}✓ Dependencies installed${NC}"

# Step 2: Configure
print_header "Step 2: Configuration"

if [ -f "vllm_config.yaml" ]; then
    echo -e "${YELLOW}Configuration file already exists${NC}"
    read -p "Overwrite with new configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing configuration"
    else
        rm vllm_config.yaml
    fi
fi

if [ ! -f "vllm_config.yaml" ]; then
    echo "Creating configuration file..."
    cp vllm_config.example.yaml vllm_config.yaml

    echo ""
    echo -e "${YELLOW}Please edit vllm_config.yaml with your settings:${NC}"
    echo "  1. Set your model name"
    echo "  2. Adjust GPU memory settings based on your GPU"
    echo ""
    read -p "Open editor now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} vllm_config.yaml
    else
        echo "You can edit it later with: nano vllm_config.yaml"
    fi
fi

echo -e "${GREEN}✓ Configuration ready${NC}"

# Step 3: Test configuration
print_header "Step 3: Testing Configuration"

echo "Validating configuration..."
if python3 config.py; then
    echo -e "${GREEN}✓ Configuration is valid${NC}"
else
    echo -e "${RED}✗ Configuration has errors${NC}"
    echo "Please fix the errors and run this script again"
    exit 1
fi

# Step 4: Ready to start
print_header "Setup Complete!"

echo -e "${GREEN}Your vLLM server is ready to start!${NC}"
echo ""
echo "To start the server:"
echo "  ${BLUE}./start_vllm.sh --background${NC}  # Run in background"
echo "  ${BLUE}./start_vllm.sh${NC}               # Run in foreground"
echo ""
echo "To verify it's running:"
echo "  ${BLUE}python3 vllm_server.py --check${NC}"
echo ""
echo "To test inference:"
echo "  ${BLUE}python3 vllm_server.py --test${NC}"
echo ""
echo -e "${YELLOW}Next: Set up SSH tunnel from your local machine${NC}"
echo "  See README.md 'Remote Access' section"
echo ""
