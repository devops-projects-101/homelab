#!/bin/bash

echo "Starting Pre-Homelab Setup..."

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Update system packages
echo "Updating system packages..."
apt-get update && apt-get upgrade -y

# Install Git
echo "Installing Git..."
apt-get install -y git

# Define installation directory
INSTALL_DIR="/opt/homelab"

# Clone the repository
echo "Cloning homelab repository..."
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    git clone https://github.com/devops-projects-101/homelab.git "$INSTALL_DIR"
    
    # Check if clone was successful
    if [ $? -ne 0 ]; then
        echo "Failed to clone repository. Please check your internet connection and try again."
        exit 1
    fi
else
    echo "Directory $INSTALL_DIR already exists. Updating repository..."
    cd "$INSTALL_DIR"
    git pull
fi

# Make the next script executable
chmod +x "$INSTALL_DIR/setup-homelab/01-homelab-setup.sh"

echo "Pre-setup complete! Running main setup script..."

# Run the main setup script
"$INSTALL_DIR/setup-homelab/01-homelab-setup.sh"
