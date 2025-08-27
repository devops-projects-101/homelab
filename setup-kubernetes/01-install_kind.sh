#!/bin/bash
# Update system and install dependencies
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    jq \
    gnupg \
    lsb-release \
    git
# Add Docker's official GPG key and repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
# Install Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
# Add homelab user to docker group
usermod -aG docker homelab
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
# Install kind
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
cp ./kind /usr/local/bin/kind
rm -rf kind

# Create kind cluster config
cat <<EOF > /home/homelab/config.yml
# 4 node (3 workers) cluster config
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.28.0
- role: worker
  image: kindest/node:v1.28.0
EOF
chown homelab:homelab /home/homelab/config.yml
# Start kind cluster as homelab user
su - homelab -c "kind create cluster --config=/home/homelab/config.yml"
# Wait for kind cluster to be ready
su - homelab -c "timeout 180 bash -c 'until kubectl cluster-info; do sleep 10; done'"

