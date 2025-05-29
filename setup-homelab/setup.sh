#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Homelab Setup...${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please use sudo.${NC}"
    exit 1
fi

# Set hostname to 'homelab'
echo -e "${BLUE}Setting hostname to 'homelab'...${NC}"
hostnamectl set-hostname homelab
echo "127.0.0.1 homelab" >> /etc/hosts

# Update system packages
echo -e "${BLUE}Updating system packages...${NC}"
apt-get update && apt-get upgrade -y

# Install prerequisites
echo -e "${BLUE}Installing required packages...${NC}"
apt-get install -y \
    curl \
    wget \
    git \
    ssh \
    sudo \
    ufw

# Check if 'homelab' user exists, create if it doesn't
echo -e "${BLUE}Checking for 'homelab' user...${NC}"
if id "homelab" &>/dev/null; then
    echo -e "${GREEN}User 'homelab' already exists.${NC}"
else
    echo -e "${YELLOW}Creating 'homelab' user...${NC}"
    useradd -m -s /bin/bash -G sudo homelab
    echo -e "${YELLOW}Please set password for 'homelab' user:${NC}"
    passwd homelab
fi

# Configure SSH
echo -e "${BLUE}Configuring SSH...${NC}"
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
echo -e "${BLUE}Disabling firewall...${NC}"
ufw disable

# Clone the repository
echo -e "${BLUE}Cloning homelab repository...${NC}"
if [ ! -d "/opt/homelab" ]; then
    mkdir -p /opt/homelab
    git clone https://github.com/Kabilarajah/homelab.git /opt/homelab
    chown -R homelab:homelab /opt/homelab
else
    echo -e "${YELLOW}Homelab repository directory already exists. Updating...${NC}"
    cd /opt/homelab
    git pull
fi

# Install CasaOS
echo -e "${BLUE}Installing CasaOS...${NC}"
curl -fsSL https://get.casaos.io | sudo bash

echo -e "${GREEN}Setup complete!${NC}"
echo -e "${GREEN}Your homelab system has been configured with:${NC}"
echo -e "  - Hostname: homelab"
echo -e "  - User: homelab"
echo -e "  - CasaOS installed"
echo -e "  - SSH configured"
echo -e "  - Firewall disabled"
echo -e "${YELLOW}You can access CasaOS at http://homelab:80${NC}"
echo -e "${YELLOW}or http://$(hostname -I | awk '{print $1}'):80${NC}"
