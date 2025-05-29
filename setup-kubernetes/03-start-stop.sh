

#!/bin/bash

# Script for managing Kind Homelab Kubernetes cluster
# This script can be used directly or via the 'kind-homelab' alias

# Default nodes for the homelab cluster
DEFAULT_NODES=(
  "kind-homelab-cluster-control-plane"
  "kind-homelab-cluster-worker"
  "kind-homelab-cluster-worker2"
)

# Function to check if Docker is running
check_docker() {
  if ! docker info &>/dev/null; then
    echo "Docker is not running. Please start Docker first."
    exit 1
  fi
}

# Function to get active cluster nodes
get_nodes() {
  NODES=$(docker ps -a --format "{{.Names}}" | grep kind-homelab-cluster)
  
  # If no nodes found, use default nodes
  if [ -z "$NODES" ]; then
    echo "No running or stopped kind-homelab-cluster nodes found."
    echo "Using default node names..."
    # Convert array to space-separated string
    NODES="${DEFAULT_NODES[*]}"
  fi
}

# Function to start the cluster
start_cluster() {
  echo "Starting Kind Homelab cluster..."
  get_nodes
  
  local started=0
  for node in $NODES; do
    if docker inspect --format='{{.State.Status}}' "$node" &>/dev/null; then
      echo "Starting node: $node"
      docker start "$node"
      started=$((started+1))
    else
      echo "Node $node does not exist, skipping."
    fi
  done
  
  if [ $started -gt 0 ]; then
    echo "Started $started nodes."
    echo "You can now access the cluster with:"
    echo "kubectl cluster-info --context kind-kind-homelab-cluster"
  else
    echo "No nodes were started. You may need to create the cluster first with:"
    echo "./02-create_cluster.sh"
  fi
}

# Function to stop the cluster
stop_cluster() {
  echo "Stopping Kind Homelab cluster..."
  get_nodes
  
  local stopped=0
  for node in $NODES; do
    if docker inspect --format='{{.State.Status}}' "$node" &>/dev/null; then
      if [ "$(docker inspect --format='{{.State.Status}}' "$node")" = "running" ]; then
        echo "Stopping node: $node"
        docker stop "$node"
        stopped=$((stopped+1))
      else
        echo "Node $node is already stopped."
      fi
    else
      echo "Node $node does not exist, skipping."
    fi
  done
  
  if [ $stopped -gt 0 ]; then
    echo "Stopped $stopped nodes."
  else
    echo "No running nodes were found to stop."
  fi
}

# Function to show usage information
usage() {
  echo "Usage: $0 [start|stop|status|install-alias]"
  echo "  start         - Start the Kind Homelab cluster"
  echo "  stop          - Stop the Kind Homelab cluster"
  echo "  status        - Show the status of the Kind Homelab cluster"
  echo "  install-alias - Install the 'kind-homelab' alias command"
  exit 1
}

# Function to install kind-homelab alias
install_alias() {
  echo "Installing 'kind-homelab' alias..."
  
  # Create .kube directory if it doesn't exist
  mkdir -p ~/.kube
  
  # Full path to this script
  SCRIPT_PATH=$(realpath "$0")
  
  # Create the alias script
  cat > ~/.kube/kind-homelab << EOF
#!/bin/bash
# This file was automatically created by the homelab setup
# It's a wrapper for the Kind Homelab cluster management script
"$SCRIPT_PATH" "\$@"
EOF

  # Make the script executable
  chmod +x ~/.kube/kind-homelab
  
  # Add to PATH if not already in path
  if ! grep -q "PATH=\$PATH:~/.kube" ~/.bashrc; then
    echo "Adding ~/.kube to PATH in ~/.bashrc"
    echo "# Added by homelab setup" >> ~/.bashrc
    echo "export PATH=\$PATH:~/.kube" >> ~/.bashrc
    echo "You need to run 'source ~/.bashrc' or start a new terminal to use the kind-homelab command"
  fi
  
  # Check if using zsh
  if [ -f ~/.zshrc ]; then
    if ! grep -q "PATH=\$PATH:~/.kube" ~/.zshrc; then
      echo "Adding ~/.kube to PATH in ~/.zshrc"
      echo "# Added by homelab setup" >> ~/.zshrc
      echo "export PATH=\$PATH:~/.kube" >> ~/.zshrc
      echo "You need to run 'source ~/.zshrc' or start a new terminal to use the kind-homelab command"
    fi
  fi
  
  echo "Alias 'kind-homelab' has been installed."
  echo "You can now use 'kind-homelab start', 'kind-homelab stop', etc."
}

# Function to check if alias exists
check_alias() {
  if ! command -v kind-homelab &> /dev/null; then
    echo "The 'kind-homelab' command is not installed."
    echo "Would you like to install it? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      install_alias
    fi
  fi
}

# Main script execution

# Check if Docker is running
check_docker

# If this is the first argument and it's not install-alias, check for the alias
if [ "$1" != "install-alias" ] && [ "$(basename "$0")" != "kind-homelab" ]; then
  check_alias
fi

# Process command line arguments
if [ $# -eq 0 ]; then
  usage
fi

case "$1" in
  start)
    start_cluster
    ;;
  stop)
    stop_cluster
    ;;
  status)
    echo "Kind Homelab cluster status:"
    get_nodes
    for node in $NODES; do
      if docker inspect --format='{{.State.Status}}' "$node" &>/dev/null; then
        status=$(docker inspect --format='{{.State.Status}}' "$node")
        echo "$node: $status"
      else
        echo "$node: does not exist"
      fi
    done
    ;;
  install-alias)
    install_alias
    ;;
  *)
    usage
    ;;
esac
