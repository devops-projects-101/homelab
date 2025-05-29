#!/bin/bash

CONFIG_FILE="00-config.yml"
CLUSTER_NAME="kind-homelab-cluster"

echo "Checking if Docker is running..."
if ! docker info &> /dev/null; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "Deleting existing cluster if it exists..."
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
    echo "Port $PORT is already in use. Finding another available port..."
    NEW_PORT=10443 # Try a completely different port
    # Keep incrementing until we find a free port
    while check_port_conflict "$NEW_PORT"; do
        NEW_PORT=$((NEW_PORT + 1))
    done
    echo "Using port $NEW_PORT instead..."
    # Update the config file with the new port
    sed -i "s/hostPort: $PORT/hostPort: $NEW_PORT/g" "$CONFIG_FILE"
fi

echo "Creating cluster $CLUSTER_NAME..."
kind create cluster --config="$CONFIG_FILE"

if [ $? -eq 0 ]; then
    echo "Cluster created successfully!"
    kubectl cluster-info --context "kind-$CLUSTER_NAME"
else
    echo "Failed to create cluster. See error message above."
    exit 1
fi
