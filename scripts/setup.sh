#!/bin/bash
# Update system and install dependencies
sudo apt update -y && sudo apt upgrade -y
sudo apt install curl unzip git -y

# Install Docker
sudo apt install docker.io -y
sudo systemctl start docker && sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube start --driver=docker --memory=4096m --cpus=2

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Initialize repository
git clone https://github.com/venkateswarluyendoti/Cloud-Native-Kubernetes-Security-and-Monitoring.git
cd Cloud-Native-Kubernetes-Security-and-Monitoring