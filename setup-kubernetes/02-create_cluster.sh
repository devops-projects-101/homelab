#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONFIG_FILE="00-config.yml"
CLUSTER_NAME="kind-homelab-cluster"

echo -e "${BLUE}Checking if Docker is running...${NC}"
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

echo -e "${BLUE}Deleting existing cluster if it exists...${NC}"
kind delete cluster --name "$CLUSTER_NAME"

# Function to check for port conflicts
check_port_conflict() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 0 # Port is in use
    else
        return 1 # Port is free
    fi
}

# Check if port is in use
PORT=$(grep -A5 'extraPortMappings' "$CONFIG_FILE" | grep 'hostPort' | head -n1 | awk '{print $2}')
if check_port_conflict "$PORT"; then
    echo -e "${YELLOW}Port $PORT is already in use. Would you like to use a different port? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        NEW_PORT=$((PORT + 1000)) # Try port + 1000 as an alternative
        # Keep incrementing until we find a free port
        while check_port_conflict "$NEW_PORT"; do
            NEW_PORT=$((NEW_PORT + 1))
        done
        echo -e "${BLUE}Using port $NEW_PORT instead...${NC}"
        # Update the config file with the new port
        sed -i "s/hostPort: $PORT/hostPort: $NEW_PORT/g" "$CONFIG_FILE"
    else
        echo -e "${RED}Port conflict detected. Please free up port $PORT or edit $CONFIG_FILE manually.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}Creating cluster $CLUSTER_NAME...${NC}"
kind create cluster --config="$CONFIG_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Cluster created successfully!${NC}"
    kubectl cluster-info --context "kind-$CLUSTER_NAME"
else
    echo -e "${RED}Failed to create cluster. See error message above.${NC}"
    exit 1
fi
