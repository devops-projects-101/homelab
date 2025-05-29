#!/bin/bash

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="kind-homelab-cluster"
CONTROL_PLANE_NAME="$CLUSTER_NAME-control-plane"

# Check if the control-plane container is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTROL_PLANE_NAME}$"; then
    echo -e "${GREEN}Kubernetes control plane (${CONTROL_PLANE_NAME}) found and running.${NC}"

    # Extract the HostPort for the Kubernetes API server (6443/tcp inside container)
    HOST_PORT=$(docker inspect ${CONTROL_PLANE_NAME} | \
                jq -r '.[].NetworkSettings.Ports."6443/tcp"[0].HostPort')

    if [ -n "$HOST_PORT" ]; then
        echo -e "${BLUE}Kubernetes API server HostPort: ${HOST_PORT}${NC}"
        echo -e "${BLUE}Setting up kubectl configuration...${NC}"
        
        # Create kubectl config directory if it doesn't exist
        mkdir -p ~/.kube

        # Note: 'kind get kubeconfig' is the recommended way to get the kubeconfig
        # and it handles merging it into your ~/.kube/config.
        # This script won't actually modify your ~/.kube/config unless you add
        # specific 'kubectl config set-cluster' commands, which can be complex
        # and might override kind's well-formed config.
        # This part is more of a confirmation/demonstration.

        echo "If you need to manually configure kubectl, use the following:"
        echo "  kubectl config set-cluster kind-kind --server=https://127.0.0.1:${HOST_PORT} --embed-certs=true --certificate-authority=<path_to_ca_cert>"
        echo "  kubectl config set-credentials kind-kind --client-certificate=<path_to_client_cert> --client-key=<path_to_client_key>"
        echo "  kubectl config set-context kind-kind --cluster=kind-kind --user=kind-kind"
        echo "  kubectl config use-context kind-kind"
        echo ""
        echo "However, 'kind' usually handles this automatically for you upon cluster creation."
        echo "You can verify your current configuration with: kubectl config view --minify --context kind-kind"
    else
        echo "Could not extract HostPort for Kubernetes API server from ${CONTROL_PLANE_NAME}."
    fi
else
    echo -e "${AMBER}No Kubernetes control plane (${CONTROL_PLANE_NAME}) found running.${NC}"
fi
