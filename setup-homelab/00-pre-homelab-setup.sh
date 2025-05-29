#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Pre-Homelab Setup...${NC}"

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please use sudo.${NC}"
    exit 1
fi

# Update system packages
echo -e "${BLUE}Updating system packages...${NC}"
apt-get update && apt-get upgrade -y

# Install Git
echo -e "${BLUE}Installing Git...${NC}"
apt-get install -y git

# Define installation directory
INSTALL_DIR="/opt/homelab"

# Clone the repository
echo -e "${BLUE}Cloning homelab repository...${NC}"
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    git clone https://github.com/Kabilarajah/homelab.git "$INSTALL_DIR"
    
    # Check if clone was successful
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to clone repository. Please check your internet connection and try again.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Directory $INSTALL_DIR already exists.${NC}"
    echo -e "${BLUE}Updating repository...${NC}"
    cd "$INSTALL_DIR"
    git pull
fi

# Make the next script executable
chmod +x "$INSTALL_DIR/setup-homelab/01-homelab-setup.sh"

echo -e "${GREEN}Pre-setup complete!${NC}"
echo -e "${BLUE}Running main setup script...${NC}"

# Run the main setup script
"$INSTALL_DIR/setup-homelab/01-homelab-setup.sh"
