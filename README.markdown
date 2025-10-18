# Enforcing Kubernetes Security with Kyverno using Argo CD GitOps
**Overview**
- This project demonstrates Kubernetes security governance using Kyverno for policy enforcement, managed via Argo CD for GitOps. It includes multi-environment support (dev, prod, staging), Prometheus/Grafana monitoring, policy testing, and comprehensive troubleshooting. The setup runs on a single-node Minikube cluster within AWS EC2 resource constraints (2 vCPUs, ~3.8GB memory). The goal is to create a professional, resume-ready GitHub repository.

**Goals**:

- Enforce security policies (e.g., resource limits, no "latest" image tags).
- Manage policies declaratively using Argo CD GitOps.
- Test policy compliance and troubleshoot issues (e.g., webhook failures, resource exhaustion).
- Integrate Prometheus/Grafana for monitoring Kyverno metrics.

Repo Structure:
```bash
Enforce-kubernetes-security-with-kyverno/
├── policies/
│   ├── disallow-latest-tag.yaml
│   └── require-requests-limits.yaml
├── tests/
│   ├── compliant-pod.yaml
│   └── non-compliant-pod.yaml
├── monitoring/
│   ├── kyverno-servicemonitor.yaml
│   └── prometheus-values.yaml
├── setup.sh
├── install-kyverno.sh
├── troubleshooting.md
├── README.md
```


## Phase 1: Prerequisites and Environment Setup
- Set up the base environment with Docker, Minikube, kubectl, Helm, and Git, ensuring Docker permissions for non-root users.

# vim setup.sh
```bash
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
minikube start --driver=docker --memory=3072m --cpus=2

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Initialize repository
git clone https://github.com/venkateswarluyendoti/Enforce-kubernetes-security-with-kyverno.git
cd Enforce-kubernetes-security-with-kyverno
mkdir policies tests monitoring
```

- **Esc + Shift : wq**

#### Steps:
     ------

1. **Run Setup Script**

```bash
chmod +x setup.sh
./setup.sh
```
**Verify**:

- git --version (e.g., Git 2.x).
- docker --version (e.g., 20.10.x), docker run hello-world (success).
- kubectl version --client (e.g., v1.30.x).
- minikube status (host/kubelet running), kubectl get nodes (minikube Ready).
- helm version (e.g., v3.14.x).
- ls -l (confirm directories: policies, tests, monitoring).






