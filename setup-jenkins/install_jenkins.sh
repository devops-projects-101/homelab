#!/bin/bash

# --- Script for Jenkins Master and Agent Docker Installation on Ubuntu ---
# This script installs Docker, prepares Jenkins master and agent data directories,
# and runs both Jenkins master and a Jenkins agent as Docker containers.
# It ensures data persistence, auto-restart, and provides immediate access details.

echo "--- Starting Jenkins Master and Agent Docker Installation Script ---"

# Step 1: Update Ubuntu Server
echo "
--------------------------------------------------
[STEP 1/5]: Updating Ubuntu Server
--------------------------------------------------"
sudo apt update -y
sudo apt upgrade -y
echo "Ubuntu update complete."

# Step 2: Install Docker Engine
echo "
--------------------------------------------------
[STEP 2/5]: Installing Docker Engine
--------------------------------------------------"
# Install necessary packages for Docker
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common

# Add Docker's official GPG key using the recommended method for newer Ubuntu versions
echo "Adding Docker's official GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add the Docker repository to APT sources, referencing the new .gpg key file
echo "Setting up Docker APT repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt package index with Docker repository
echo "Updating apt package index after adding Docker repository..."
sudo apt update -y

# Install Docker Engine and related components
echo "Installing Docker Engine, CLI, Containerd, and Docker Compose plugins..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo "Docker Engine installation complete."

# Add current user to the docker group
echo "Adding current user '$USER' to the 'docker' group for rootless Docker commands."
sudo usermod -aG docker "$USER"
echo "User '$USER' added to 'docker' group. IMPORTANT: You must log out and log back in, or run 'newgrp docker', for this change to take effect in new terminals."
# Force a newgrp docker for the current session to allow immediate non-sudo docker commands
newgrp docker 2>/dev/null || echo "Could not run 'newgrp docker'. Please log out and log back in manually."

# Step 3: Prepare for Jenkins Master Docker Container
JENKINS_HOME_DIR="/var/jenkins_home"
echo "
--------------------------------------------------
[STEP 3/5]: Preparing Jenkins Master Data Directory
--------------------------------------------------"
echo "Creating Jenkins master data directory: ${JENKINS_HOME_DIR}"
sudo mkdir -p "$JENKINS_HOME_DIR"

# Set ownership to 1000:1000 (Jenkins user ID inside the container)
echo "Setting ownership of ${JENKINS_HOME_DIR} to 1000:1000 (Jenkins user ID)..."
sudo chown 1000:1000 "$JENKINS_HOME_DIR"
echo "Jenkins master data directory prepared."

# Step 4: Run Jenkins Master as a Docker Container
MASTER_CONTAINER_NAME="jenkins-master"
MASTER_HOST_PORT_HTTP=80
MASTER_CONTAINER_PORT_HTTP=8080
MASTER_HOST_PORT_AGENT=50000
MASTER_CONTAINER_PORT_AGENT=50000
JENKINS_MASTER_IMAGE="jenkins/jenkins:lts"

echo "
--------------------------------------------------
[STEP 4/5]: Running Jenkins Master Container
--------------------------------------------------"
echo "Running Jenkins Master Docker container..."
echo "  Container Name: ${MASTER_CONTAINER_NAME}"
echo "  Access on Host Port: ${MASTER_HOST_PORT_HTTP} (maps to container port ${MASTER_CONTAINER_PORT_HTTP})"
echo "  Agent Port: ${MASTER_HOST_PORT_AGENT} (maps to container port ${MASTER_CONTAINER_PORT_AGENT})"
echo "  Persistent Data Path: ${JENKINS_HOME_DIR}"
echo "  Docker Image: ${JENKINS_MASTER_IMAGE}"

# Stop and remove any existing Jenkins master container with the same name
if docker ps -a --format '{{.Names}}' | grep -q "$MASTER_CONTAINER_NAME"; then
    echo "Existing container '${MASTER_CONTAINER_NAME}' found. Stopping and removing it..."
    docker stop "$MASTER_CONTAINER_NAME" || true # Use || true to prevent script from exiting if stop fails
    docker rm "$MASTER_CONTAINER_NAME" || true   # Use || true to prevent script from exiting if rm fails
fi

docker run -d \
  --name "$MASTER_CONTAINER_NAME" \
  -p "$MASTER_HOST_PORT_HTTP":"$MASTER_CONTAINER_PORT_HTTP" \
  -p "$MASTER_HOST_PORT_AGENT":"$MASTER_CONTAINER_PORT_AGENT" \
  -v "$JENKINS_HOME_DIR":"/var/jenkins_home" \
  --restart=unless-stopped \
  "$JENKINS_MASTER_IMAGE"

if [ $? -eq 0 ]; then
    echo "Jenkins Master container '${MASTER_CONTAINER_NAME}' started successfully!"
else
    echo "ERROR: Failed to start Jenkins Master container. Please check the logs for errors."
    echo "--- Jenkins Docker Installation Script Finished (with errors) ---"
    exit 1
fi

# Step 5: Run Jenkins Agent as a Docker Container
echo "
--------------------------------------------------
[STEP 5/5]: Running Jenkins Agent Container
--------------------------------------------------"
AGENT_CONTAINER_NAME="jenkins-agent-1"
JENKINS_AGENT_IMAGE="jenkins/agent:latest" # Using the official Jenkins agent image (JDK17 by default)
AGENT_HOME_DIR="/var/jenkins_agent_home" # New directory for agent's persistent data

echo "Creating Jenkins agent data directory: ${AGENT_HOME_DIR}"
sudo mkdir -p "$AGENT_HOME_DIR"
sudo chown 1000:1000 "$AGENT_HOME_DIR" # Agent user inside container is also typically 1000

echo "Running Jenkins Agent Docker container..."
echo "  Agent Container Name: ${AGENT_CONTAINER_NAME}"
echo "  Agent Docker Image: ${JENKINS_AGENT_IMAGE}"
echo "  Agent Persistent Data Path: ${AGENT_HOME_DIR}"

# Stop and remove any existing Jenkins agent container with the same name
if docker ps -a --format '{{.Names}}' | grep -q "$AGENT_CONTAINER_NAME"; then
    echo "Existing agent container '${AGENT_CONTAINER_NAME}' found. Stopping and removing it..."
    docker stop "$AGENT_CONTAINER_NAME" || true
    docker rm "$AGENT_CONTAINER_NAME" || true
fi

docker run -d \
  --name "$AGENT_CONTAINER_NAME" \
  -v "$AGENT_HOME_DIR":"/home/jenkins/agent" \
  --restart=unless-stopped \
  "$JENKINS_AGENT_IMAGE"

if [ $? -eq 0 ]; then
    echo "Jenkins Agent container '${AGENT_CONTAINER_NAME}' started successfully!"
    echo "Agent is running. You will need to configure it in Jenkins UI."
else
    echo "ERROR: Failed to start Jenkins Agent container. Please check the logs for errors."
fi

echo "
--------------------------------------------------
[POST-INSTALLATION INFORMATION]
--------------------------------------------------"

# Attempt to get server Public IP (more reliable for cloud VMs)
echo "Attempting to retrieve public IP address..."
PUBLIC_IP=$(curl -s ifconfig.me)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP="YOUR_PUBLIC_SERVER_IP_OR_DOMAIN"
    echo "WARNING: Could not automatically determine public IP. Please replace 'YOUR_PUBLIC_SERVER_IP_OR_DOMAIN' below."
else
    echo "Public IP detected: ${PUBLIC_IP}"
fi

# Jenkins Access URL
JENKINS_URL="http://${PUBLIC_IP}:${MASTER_HOST_PORT_HTTP}"
echo "Jenkins Master Access URL: ${JENKINS_URL}"

# Retrieve Initial Admin Password
echo "Retrieving initial Jenkins master admin password (this may take a minute for Jenkins to generate)..."
ATTEMPTS=0
MAX_ATTEMPTS=15 # Increased attempts for larger images/slower network
PASSWORD_FILE_PATH="/var/jenkins_home/secrets/initialAdminPassword"
ADMIN_PASSWORD=""

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    ADMIN_PASSWORD=$(docker exec "$MASTER_CONTAINER_NAME" cat "$PASSWORD_FILE_PATH" 2>/dev/null)
    if [ -n "$ADMIN_PASSWORD" ]; then
        echo "Jenkins Initial Admin Password: ${ADMIN_PASSWORD}"
        break
    fi
    echo "Waiting for Jenkins master to generate admin password... (Attempt $((ATTEMPTS+1))/${MAX_ATTEMPTS})"
    sleep 10 # Wait for 10 seconds
    ATTEMPTS=$((ATTEMPTS+1))
done

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "WARNING: Could not retrieve initial admin password automatically. You can try manually with:"
    echo "  docker exec ${MASTER_CONTAINER_NAME} cat ${PASSWORD_FILE_PATH}"
fi

echo "
--------------------------------------------------
[JENKINS MASTER LOGS (LAST 50 LINES)]
--------------------------------------------------"
echo "(It might take a few moments for the 'Jenkins is fully up and running' message to appear)"
docker logs "$MASTER_CONTAINER_NAME" --tail 50
echo "For full Jenkins master logs, run: docker logs -f ${MASTER_CONTAINER_NAME}"

echo "
--------------------------------------------------
[INSTALLATION SUMMARY]
--------------------------------------------------"
echo "  - Ubuntu packages updated."
echo "  - Docker Engine installed and configured for rootless use (requires relogin/newgrp)."
echo "  - Dedicated Jenkins master data directory '${JENKINS_HOME_DIR}' created and permissioned."
echo "  - Jenkins LTS Master Docker container '${MASTER_CONTAINER_NAME}' is running in detached mode."
echo "    - Accessible on host port ${MASTER_HOST_PORT_HTTP}."
echo "    - Data is persistent in '${JENKINS_HOME_DIR}'."
echo "    - Configured for auto-restart ('unless-stopped')."
echo "  - Dedicated Jenkins agent data directory '${AGENT_HOME_DIR}' created and permissioned."
echo "  - Jenkins Agent Docker container '${AGENT_CONTAINER_NAME}' is running in detached mode."
echo "    - Data is persistent in '${AGENT_HOME_DIR}'."
echo "    - Configured for auto-restart ('unless-stopped')."

echo "
--------------------------------------------------
[IMPORTANT NEXT STEPS]
--------------------------------------------------"
echo "1. Current terminal session: To run Docker commands without 'sudo', please type 'newgrp docker' now."
echo "   For future sessions, you will need to log out and log back into your server."
echo ""
echo "2. Access Jenkins Master in your web browser:"
echo "   ${JENKINS_URL}"
echo "   - Use the Initial Admin Password (provided above) to unlock Jenkins."
echo "   - Follow the on-screen prompts to install suggested plugins and create your first admin user."
echo ""
echo "3. Configure your firewall (UFW) to allow access to Jenkins (and agents):"
echo "   sudo ufw allow ${MASTER_HOST_PORT_HTTP}/tcp"
echo "   sudo ufw allow ${MASTER_HOST_PORT_AGENT}/tcp # For Jenkins agents"
echo "   sudo ufw status # To check current firewall status"
echo ""
echo "4. Connect the Jenkins Agent to the Master (after Jenkins UI setup):"
echo "   a. In Jenkins Master UI, go to 'Manage Jenkins' -> 'Nodes' -> 'New Node'."
echo "   b. Give it a name (e.g., 'docker-agent-1') and select 'Permanent Agent'. Click 'Create'."
echo "   c. For 'Remote root directory', use '/home/jenkins/agent'."
echo "   d. For 'Launch method', select 'Launch agent by connecting it to the controller'."
echo "   e. Jenkins will provide a 'Launch command' (e.g., java -jar agent.jar -secret <SECRET> ...)."
echo "      You will need to run this command inside your agent container. Example:"
echo "      docker exec -d ${AGENT_CONTAINER_NAME} java -jar /usr/share/jenkins/agent.jar -secret <SECRET> -name docker-agent-1 -url ${JENKINS_URL}/"
echo "      - Copy the exact secret from the Jenkins UI and replace '<SECRET>'."
echo "      - Run this command in your server's terminal to connect the agent."
echo "   f. Alternatively, for more robust connection, use the 'Inbound Agents' method where Jenkins UI provides clearer instructions and handles the connection from the master side after you provide the secret and agent name."
echo ""
echo "--------------------------------------------------
[END OF SCRIPT]
--------------------------------------------------"