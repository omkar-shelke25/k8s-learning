#!/bin/bash

# Script to install kubectl, bat, kube-linter, k9s, and trivy on Ubuntu
set -e

# Function to print usage
usage() {
    echo "Usage: $0"
    echo "This script installs kubectl, bat, kube-linter, k9s, and trivy on Ubuntu."
    exit 1
}


# Update and install prerequisites
echo "Updating system and installing prerequisites..."
sudo apt update -y
sudo apt install -y curl wget tar unzip git

# Install kubectl (Kubernetes CLI)
echo "Installing kubectl..."
K8S_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install bat
echo "Installing bat..."
sudo apt install -y bat

# Install kube-linter
#go install golang.stackrox.io/kube-linter/cmd/kube-linter@latest

# Install k9s
echo "Installing k9s..."
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -LO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
tar -xvf "k9s_Linux_amd64.tar.gz"
sudo mv k9s /usr/local/bin/
rm "k9s_Linux_amd64.tar.gz"

# Install Trivy
echo "Installing Trivy..."
curl -sfL https://github.com/aquasecurity/trivy/releases/download/v0.34.0/trivy_0.34.0_Linux-64bit.tar.gz -o trivy.tar.gz
tar -xvf trivy.tar.gz
sudo mv trivy /usr/local/bin/
rm trivy.tar.gz

# Verify installations
echo "Verifying installations..."
kubectl version --client
#bat --version
batcat --version
#kube-linter version
k9s version
trivy --version
alias bat="batcat"


sudo apt install fzf
source /usr/share/doc/fzf/examples/key-bindings.bash
source ~/.bashrc

echo "All tools installed successfully!"
