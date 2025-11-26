#!/bin/bash
# SSH Tunnel Script - Run this on your LOCAL machine
# Creates a secure tunnel to access vLLM server running on remote GPU

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}vLLM Server SSH Tunnel Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if config file exists
if [ -f ".tunnel_config" ]; then
    echo -e "${YELLOW}Found saved configuration${NC}"
    source .tunnel_config
    echo "  SSH Host: $SSH_HOST"
    echo "  Remote Port: $REMOTE_PORT"
    echo "  Local Port: $LOCAL_PORT"
    echo ""
    read -p "Use saved config? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm .tunnel_config
    fi
fi

# Get connection details if not saved
if [ ! -f ".tunnel_config" ]; then
    echo "Enter your GPU server SSH details:"
    echo ""

    # Get SSH host
    echo -e "${BLUE}SSH Host:${NC}"
    echo "  For RunPod: Look for 'SSH over exposed TCP' command"
    echo "  For Vast.ai: Use the SSH command from instance details"
    echo "  Example: root@123.456.789.0 -p 12345"
    echo ""
    read -p "SSH host (user@ip -p port): " SSH_HOST

    # Get ports
    echo ""
    read -p "Remote vLLM port (default: 8000): " REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-8000}

    read -p "Local port to use (default: 8000): " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-8000}

    # Save configuration
    echo "SSH_HOST=\"$SSH_HOST\"" > .tunnel_config
    echo "REMOTE_PORT=$REMOTE_PORT" >> .tunnel_config
    echo "LOCAL_PORT=$LOCAL_PORT" >> .tunnel_config

    echo ""
    echo -e "${GREEN}Configuration saved to .tunnel_config${NC}"
fi

# Build SSH command
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting SSH Tunnel${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Tunnel: localhost:${LOCAL_PORT} → GPU:${REMOTE_PORT}"
echo ""
echo -e "${YELLOW}Keep this terminal open while using the server${NC}"
echo -e "${YELLOW}Press Ctrl+C to close the tunnel${NC}"
echo ""

# Check if port is already in use
if lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Port $LOCAL_PORT is already in use${NC}"
    read -p "Kill existing process and continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lsof -ti:$LOCAL_PORT | xargs kill -9 2>/dev/null || true
        sleep 1
    else
        exit 1
    fi
fi

echo -e "${GREEN}Connecting...${NC}"
echo ""

# Create tunnel
# -L = Local port forwarding
# -N = Don't execute remote command
# -o ServerAliveInterval=60 = Keep connection alive
ssh -L ${LOCAL_PORT}:localhost:${REMOTE_PORT} ${SSH_HOST} -N -o ServerAliveInterval=60 -o ServerAliveCountMax=3
