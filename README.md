# Homelab Project

A comprehensive solution for setting up a personal homelab environment with CasaOS, Docker, Kubernetes, and Jenkins. This project aims to provide an easy-to-deploy home server solution for self-hosting applications and experimenting with DevOps tools.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
  - [Quick Start](#quick-start)
  - [Detailed Setup Process](#detailed-setup-process)
    - [Pre-Homelab Setup](#pre-homelab-setup)
    - [Main Homelab Setup](#main-homelab-setup)
    - [Kubernetes Setup](#kubernetes-setup)
    - [Jenkins Setup](#jenkins-setup)
- [Managing Your Homelab](#managing-your-homelab)
  - [CasaOS](#casaos)
  - [Kubernetes Cluster](#kubernetes-cluster)
  - [Jenkins](#jenkins)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

This homelab project sets up:

- **CasaOS** - A simple, elegant home cloud system
- **Kubernetes** - Local cluster using Kind (Kubernetes IN Docker)
- **Jenkins** - CI/CD server for automation

All components are installed in Docker containers for easy management and isolation.

## Prerequisites

- Ubuntu/Debian-based server or VM
- Root/sudo access
- Internet connection
- At least 4GB RAM (8GB+ recommended)
- 30GB+ free disk space

## Setup Instructions

### Quick Start

For a complete homelab setup with all components:

```bash
# Clone the repository
git clone https://github.com/Kabilarajah/homelab.git
cd homelab

# Start the setup
sudo ./setup-homelab/setup.sh
```

### Detailed Setup Process

#### Pre-Homelab Setup

The pre-setup script (`00-pre-homelab-setup.sh`) performs the following:

1. Updates your system packages
2. Installs Git
3. Creates installation directory at `/opt/homelab`
4. Clones the repository
5. Sets proper permissions for the next script
6. Automatically launches the main setup script

To run only the pre-setup:

```bash
sudo ./setup-homelab/00-pre-homelab-setup.sh
```

#### Main Homelab Setup

The main setup script (`01-homelab-setup.sh` or `setup.sh`) configures:

1. Sets hostname to 'homelab'
2. Updates system packages
3. Installs required dependencies
4. Creates a 'homelab' user if it doesn't exist
5. Configures secure SSH settings
6. Disables UFW firewall
7. Installs CasaOS
8. Sets up Kubernetes components (if enabled)

To run only the main setup:

```bash
sudo ./setup-homelab/01-homelab-setup.sh
```

#### Kubernetes Setup

The Kubernetes setup consists of multiple steps:

1. **Install Kind** (`01-install_kind.sh`):
   - Installs Docker and dependencies
   - Installs kubectl and Kind
   - Prepares configuration for the cluster

2. **Create Cluster** (`02-create_cluster.sh`):
   - Creates a Kind cluster with custom configuration
   - Sets up multiple worker nodes
   - Configures port mappings

3. **Configure kubectl** (`kubectl_configure.sh`):
   - Sets up kubectl configuration
   - Provides information about API server access

4. **Manage Cluster** (`03-start-stop.sh`):
   - Provides commands to start and stop the cluster
   - Creates a convenient alias for management

To set up Kubernetes manually:

```bash
cd setup-kubernetes
sudo ./01-install_kind.sh
./02-create_cluster.sh
./kubectl_configure.sh
```

To manage your Kubernetes cluster after installation:

```bash
# Start cluster
./03-start-stop.sh start

# Stop cluster
./03-start-stop.sh stop

# Check status
./03-start-stop.sh status

# Install convenient alias
./03-start-stop.sh install-alias
```

After installing the alias, you can use:

```bash
kind-homelab start
kind-homelab stop
kind-homelab status
```

#### Jenkins Setup

The Jenkins setup script (`install_jenkins.sh`) performs:

1. Installs Docker if not already installed
2. Creates a persistent Jenkins data directory
3. Runs Jenkins as a Docker container
4. Maps ports and sets auto-restart

To set up Jenkins:

```bash
cd setup-jenkins
sudo ./install_jenkins.sh
```

## Managing Your Homelab

### CasaOS

Access the CasaOS dashboard at:
- http://homelab:80
- http://YOUR_SERVER_IP:80

Login with credentials created during setup.

### Kubernetes Cluster

Interact with your Kind Kubernetes cluster using:

```bash
# Get cluster info
kubectl cluster-info --context kind-kind-homelab-cluster

# Get nodes
kubectl get nodes

# Get all resources
kubectl get all --all-namespaces
```

### Jenkins

Access the Jenkins dashboard at:
- http://YOUR_SERVER_IP:80

To get the initial admin password:

```bash
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## Troubleshooting

### Common Issues:

1. **Docker fails to start**
   - Check if Docker service is running: `sudo systemctl status docker`
   - Restart Docker: `sudo systemctl restart docker`

2. **Kubernetes cluster creation fails**
   - Verify Docker is working correctly
   - Check for port conflicts with the API server
   - Ensure you have enough resources available

3. **CasaOS is not accessible**
   - Check if CasaOS container is running: `docker ps | grep casaos`
   - Verify network settings and port availability

4. **Jenkins fails to start**
   - Check if port 80 is already in use
   - Check Jenkins container logs: `sudo docker logs jenkins`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
