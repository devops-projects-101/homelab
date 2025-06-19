#!/bin/bash

# --- Script for Jenkins Docker Installation on Ubuntu ---
# This script installs Docker, prepares the Jenkins data directory,
# and runs the Jenkins container with persistence, auto-restart, and
# exposed on host port 80.

echo "--- Starting Jenkins Docker Installation Script ---"

# Step 1: Update Ubuntu Server
echo "Updating Ubuntu server..."
sudo apt update -y
sudo apt upgrade -y
echo "Ubuntu update complete."

# Step 2: Install Docker Engine
echo "Installing Docker Engine..."
# Install necessary packages for Docker
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common

# Add Docker's official GPG key using the recommended method for newer Ubuntu versions
# Ensure the keyrings directory exists with correct permissions
echo "Adding Docker's official GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings

# Download the GPG key and dearmor it directly into the keyrings directory
# The `chmod a+r` is usually handled by the `install -m 0755` on the directory
# and then `sudo gpg --dearmor -o` will write with appropriate permissions.
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

# Optional: Add current user to the docker group to run docker commands without sudo
if ! getent group docker | grep -qw "$USER"; then
    echo "Adding current user '$USER' to the 'docker' group..."
    sudo usermod -aG docker "$USER"
    echo "Please log out and log back in (or run 'newgrp docker') for Docker commands to work without sudo."
else
    echo "User '$USER' is already in the 'docker' group."
fi

# Step 3: Prepare for Jenkins Docker Container
JENKINS_HOME_DIR="/var/jenkins_home"
echo "Creating Jenkins data directory: $JENKINS_HOME_DIR"
sudo mkdir -p "$JENKINS_HOME_DIR"

# Set ownership to 1000:1000 (Jenkins user ID inside the container)
echo "Setting ownership of $JENKINS_HOME_DIR to 1000:1000 (Jenkins user ID)..."
sudo chown 1000:1000 "$JENKINS_HOME_DIR"
echo "Jenkins data directory prepared."

# Step 4: Run Jenkins as a Docker Container
CONTAINER_NAME="jenkins"
HOST_PORT_HTTP=80
CONTAINER_PORT_HTTP=8080
HOST_PORT_AGENT=50000
CONTAINER_PORT_AGENT=50000
JENKINS_IMAGE="jenkins/jenkins:lts"

echo "Running Jenkins Docker container..."
echo "Container Name: $CONTAINER_NAME"
echo "Access on Host Port: $HOST_PORT_HTTP (maps to container port $CONTAINER_PORT_HTTP)"
echo "Agent Port: $HOST_PORT_AGENT (maps to container port $CONTAINER_PORT_AGENT)"
echo "Persistent Data Path: $JENKINS_HOME_DIR"
echo "Docker Image: $JENKINS_IMAGE"

# Stop and remove any existing Jenkins container with the same name
if sudo docker ps -a --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
    echo "Existing container '$CONTAINER_NAME' found. Stopping and removing it..."
    sudo docker stop "$CONTAINER_NAME" || true # Use || true to prevent script from exiting if stop fails
    sudo docker rm "$CONTAINER_NAME" || true   # Use || true to prevent script from exiting if rm fails
fi

sudo docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$HOST_PORT_HTTP":"$CONTAINER_PORT_HTTP" \
  -p "$HOST_PORT_AGENT":"$CONTAINER_PORT_AGENT" \
  -v "$JENKINS_HOME_DIR":"/var/jenkins_home" \
  --restart=unless-stopped \
  "$JENKINS_IMAGE"

if [ $? -eq 0 ]; then
    echo "Jenkins container '$CONTAINER_NAME' started successfully!"
    echo "Jenkins should be accessible on http://YOUR_SERVER_IP_OR_DOMAIN"
    echo "It might take a few minutes for Jenkins to fully initialize."
    echo "To get the initial admin password, run: sudo docker exec $CONTAINER_NAME cat /var/jenkins_home/secrets/initialAdminPassword"
    echo "Remember to open port $HOST_PORT_HTTP (and $HOST_PORT_AGENT if using agents) in your firewall."
else
    echo "Failed to start Jenkins container. Please check the logs for errors using: sudo docker logs $CONTAINER_NAME"
fi

echo "--- Jenkins Docker Installation Script Finished ---"