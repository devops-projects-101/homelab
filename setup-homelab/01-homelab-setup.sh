#!/bin/bash

echo "Starting Homelab Setup..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Set hostname to 'homelab'
echo "Setting hostname to 'homelab'..."
hostnamectl set-hostname homelab
echo "127.0.0.1 homelab" >> /etc/hosts

# Update system packages
echo "Updating system packages..."
apt-get update && apt-get upgrade -y

# Install prerequisites
echo "Installing required packages..."
apt-get install -y \
    curl \
    wget \
    git \
    ssh \
    sudo \
    ufw

# Check if 'homelab' user exists, create if it doesn't
echo "Checking for 'homelab' user..."
if id "homelab" &>/dev/null; then
    echo "User 'homelab' already exists."
else
    echo "Creating 'homelab' user..."
    useradd -m -s /bin/bash -G sudo homelab
    echo "Please set password for 'homelab' user:"
    passwd homelab
fi

# Configure SSH
echo "Configuring SSH..."
# Backup the original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Set secure SSH options
cat > /etc/ssh/sshd_config << EOL
# SSH Server Configuration
Port 22
AddressFamily any
ListenAddress 0.0.0.0

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no

# Security
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding yes
PrintMotd no

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# Override default of no subsystems
Subsystem sftp /usr/lib/openssh/sftp-server
EOL

# Restart SSH service
systemctl restart sshd

# Disable UFW (firewall)
echo "Disabling firewall..."
ufw disable

# Install CasaOS
echo "Installing CasaOS..."
curl -fsSL https://get.casaos.io | sudo bash

# Define paths
HOMELAB_DIR="/opt/homelab"
K8S_SETUP_DIR="$HOMELAB_DIR/setup-kubernetes"

# Ensure proper ownership of homelab directory
echo "Setting proper ownership for homelab directory..."
chown -R homelab:homelab "$HOMELAB_DIR"

# Run Kubernetes setup
echo "Starting Kubernetes setup..."
if [ -d "$K8S_SETUP_DIR" ]; then
    # Make Kubernetes setup scripts executable
    chmod +x "$K8S_SETUP_DIR"/*.sh
    
    # Run Kubernetes setup scripts in order
    "$K8S_SETUP_DIR/01-install_kind.sh"
    if [ $? -eq 0 ]; then
        "$K8S_SETUP_DIR/02-create_cluster.sh"
        if [ $? -eq 0 ]; then
            "$K8S_SETUP_DIR/kubectl_configure.sh"
        else
            echo "Failed to create Kubernetes cluster. Continuing with setup..."
        fi
    else
        echo "Failed to install Kind. Continuing with setup..."
    fi
else
    echo "Kubernetes setup directory not found at $K8S_SETUP_DIR. Skipping Kubernetes setup..."
fi

echo "Setup complete!"
echo "Your homelab system has been configured with:"
echo "  - Hostname: homelab"
echo "  - User: homelab"
echo "  - CasaOS installed"
echo "  - SSH configured"
echo "  - Firewall disabled"
if [ -d "$K8S_SETUP_DIR" ]; then
    echo "  - Kubernetes setup (if successful)"
fi
echo "You can access CasaOS at http://homelab:80"
echo "or http://$(hostname -I | awk '{print $1}'):80"
