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

- ### vim setup.sh
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


## Phase 2: Install Kyverno (Without Policies)

- Deploy Kyverno to prepare for policy enforcement, avoiding premature conflicts.

```bash
#!/bin/bash
# Create Kyverno namespace
kubectl create namespace kyverno

# Install Kyverno with Helm
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --set admissionController.replicas=1 --set cleanupController.enabled=true
```

- ### vim install-kyverno.sh
#### Steps:

- Run Kyverno Installation Script

```bash
chmod +x install-kyverno.sh
./install-kyverno.sh
```
**Verify**:

- kubectl get namespace kyverno (Active).
- kubectl get pods -n kyverno (Running).
- kubectl logs -n kyverno deployment/kyverno-admission-controller (no errors).

## Phase 3: Install Prometheus and Grafana

- Deploy monitoring tools with resource limits to comply with future Kyverno policies.

#### Steps

1. Add Helm Repository


```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```
- **Verify**: helm search repo prometheus-community (lists charts).

2. Create Prometheus Values File

- ### vim prometheus-values.yaml

```bash
prometheus:
  prometheusSpec:
    resources:
      requests:
        memory: "128Mi"
        cpu: "250m"
      limits:
        memory: "256Mi"
        cpu: "500m"
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
kubeStateMetrics:
  resources:
    requests:
      memory: "64Mi"
      cpu: "100m"
    limits:
      memory: "128Mi"
      cpu: "200m"
nodeExporter:
  resources:
    requests:
      memory: "32Mi"
      cpu: "50m"
    limits:
      memory: "64Mi"
      cpu: "100m"
pushgateway:
  resources:
    requests:
      memory: "32Mi"
      cpu: "50m"
    limits:
      memory: "64Mi"
      cpu: "100m"

```


3. Install Prometheus/Grafana

```bash
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f prometheus-values.yaml
```
**Verify**:

- kubectl get pods -n monitoring (Running).
- Port-forward: kubectl port-forward --address 0.0.0.0 service/prometheus-grafana 31509:80 -n monitoring
- Access Grafana: http://localhost:31509 (admin password: kubectl get secret -n monitoring prometheus-grafana -o - jsonpath="{.data.admin-password}" | base64 -d).

## Phase 4: Install and Configure Argo CD

- Deploy Argo CD to manage policies via GitOps.

#### Steps

1. Create Namespace

```bash
kubectl create namespace argocd
```

2. Install Argo CD
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Verify**: kubectl get pods -n argocd (Running).

3. Expose API Server

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
```
**Verify**: Access http://<EC2-IP>:<NodePort> (e.g., 32679).
**Port-Forward** : kubectl port-forward --address 0.0.0.0 service/argocd-server 31545:80 -n argocd
4. Get Admin Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

5. Install Argo CD CLI
```bash
sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd
```

## Phase 5: Apply Kyverno Policies

- Define and apply policies to enforce resource limits and disallow "latest" tags, with exclusions for monitoring and argocd.

1. Create Policy Files

- #### vim policies/disallow-latest-tag.yaml

```bash
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-image-tag
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Policy Violation: Using 'latest' tag is disallowed."
        pattern:
          spec:
            containers:
              - image: "!*:latest"
      exclude:
        resources:
          namespaces:
            - monitoring
            - argocd
```
- #### vim multi-environment.yaml
```bash
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-requests-limits
  annotations:
    policies.kyverno.io/title: Require Requests and Limits
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      Containers without resource requests and limits can burst and starve other pods.
spec:
  validationFailureAction: Enforce  # Blocks non-compliant resources
  background: true
  rules:

  # Rule 1: General rule for all namespaces (base rule)
  - name: check-for-requests-and-limits
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Policy Violation: container resources requests and limits are required!"
      pattern:
        spec:
          containers:
          - resources:
              requests:
                memory: "?*"
                cpu: "?*"
              limits:
                memory: "?*"
                cpu: "?*"

  # Rule 2: Stricter requirements for prod namespace
  - name: check-for-prod-stricter-limits
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - prod
    validate:
      message: "Production requires stricter limits."
      pattern:
        spec:
          containers:
          - resources:
              requests:
                memory: ">=64Mi"
                cpu: ">=250m"
              limits:
                memory: ">=128Mi"
                cpu: ">=500m"

  # Rule 3: Basic limits for dev and staging namespaces
  - name: dev-staging-limits
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - dev
          - staging
    validate:
      message: "Dev/Staging require basic limits."
      pattern:
        spec:
          containers:
          - resources:
              requests:
                memory: "?*"
                cpu: "?*"
              limits:
                memory: "?*"
                cpu: "?*"
```


- #### vim policies/require-requests-limits.yaml

```bash
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-requests-limits
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-for-requests-and-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
      exclude:
        resources:
          namespaces:
            - monitoring
            - argocd
      validate:
        message: "Policy Violation: container resources requests and limits are required!"
        pattern:
          spec:
            containers:
              - resources:
                  requests:
                    cpu: "?*"
                    memory: "?*"
                  limits:
                    cpu: "?*"
                    memory: "?*"
    - name: prod-minimum-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - prod
      exclude:
        resources:
          namespaces:
            - monitoring
            - argocd
      validate:
        message: "Production Pods must have at least 250m CPU, 64Mi memory requests, and 500m CPU, 128Mi memory limits."
        anyPattern:
          - spec:
              containers:
                - resources:
                    requests:
                      cpu: "250m"
                      memory: "64Mi"
                    limits:
                      cpu: "500m"
                      memory: "128Mi"
    - name: dev-staging-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - dev
                - staging
      exclude:
        resources:
          namespaces:
            - monitoring
            - argocd
      validate:
        message: "Dev/Staging Pods must have resource requests and limits."
        pattern:
          spec:
            containers:
              - resources:
                  requests:
                    cpu: "?*"
                    memory: "?*"
                  limits:
                    cpu: "?*"
                    memory: "?*"
```
**Verify**:

- kubectl get clusterpolicy -o wide (Active policies).
- kubectl logs -n kyverno deployment/kyverno-admission-controller (policy application logs).

## Phase 6: Test Policies

- Validate policy enforcement with compliant and non-compliant pods.

1. Create Test Files

- #### vim tests/non-compliant-pod.yaml
```bash
apiVersion: v1
kind: Pod
metadata:
  name: non-compliant-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
```
- #### vim tests/compliant-pod.yaml
```bash
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

2. Test Deployment
```bash
kubectl apply -f tests/non-compliant-pod.yaml
kubectl apply -f tests/compliant-pod.yaml -n prod
```

- **Expected**:

- Non-compliant pod fails (Kyverno violation: "Using 'latest' tag").
- Compliant pod succeeds in prod.
- **Verify**:
    - kubectl get pods -n prod (compliant-pod Running).
    - kubectl describe pod non-compliant-pod (Kyverno denial in events).


## Phase 7: Troubleshoot and Document

- Address common issues and document solutions for professionalism.

1. Check Logs

```bash
kubectl logs -n kyverno deployment/kyverno-admission-controller | grep "Policy Violation"
```
**Note**: If monitoring/argocd pods are blocked, verify exclude rules in policies.

2. Create Troubleshooting Guide
- ### Troubleshooting and Solutions
- ### Common Issues and Fixes

| **Issue** | **Cause** | **Solution** |
|------------|------------|--------------|
| **SyncError: failed calling webhook "mutate-policy.kyverno.svc": connection refused** | Kyverno webhook unreachable (pod crash, service/DNS issue). | 1. Check pods/services: `kubectl get pods,svc -n kyverno`<br>2. Restart: `kubectl rollout restart deployment -n kyverno`<br>3. Test: `kubectl exec -n argocd <pod> -- curl -vk https://kyverno-svc.kyverno.svc:443`<br>4. Reapply Kyverno: `kubectl apply -f https://raw.githubusercontent.com/kyverno/kyverno/main/config/release/install.yaml` |
| **CrashLoopBackOff in kyverno-cleanup-controller or kyverno-reports-controller** | Leader election failure (context deadline). | 1. Check logs: `kubectl logs -n kyverno <pod>`<br>2. Verify leases: `kubectl get lease -n kyverno`<br>3. Test API server: `curl -k https://kubernetes.default.svc:443/healthz`<br>4. Scale Minikube: `minikube stop; minikube delete; minikube start --cpus=4 --memory=8192` |
| **Pod Pending: Insufficient CPU** | Node resource exhaustion (100% CPU allocated). | 1. Check usage: `kubectl top nodes`, `kubectl top pods -A`<br>2. Delete low-priority pods: `kubectl delete pod compliant-pod -n dev`<br>3. Scale Minikube: `minikube stop; minikube delete; minikube start --cpus=4 --memory=8192` |
| **Invalid value: 0: must be specified for update** | Missing resource version for policy update. | 1. Delete/reapply: `kubectl delete clusterpolicy <name> && kubectl apply -f <policy.yaml>`<br>2. Force apply: `kubectl apply -f <policy.yaml> --force` |
| **Kyverno blocks monitoring/argocd pods** | Missing namespace exclusions. | Add exclude section in policies:<br>```yaml<br>namespaces:<br>  - monitoring<br>  - argocd<br>``` |
| **Minikube resource errors** | EC2 resource limits exceeded. | Reduce resources: `--memory=2048m` or scale to higher specs: `--cpus=4 --memory=8192` |



## Phase 8: Extend with Multi-Environment Support

- Add namespace-based policies for dev, prod, and staging.

1. Create Namespaces

```bash
kubectl create namespace dev
kubectl create namespace prod
kubectl create namespace staging
```
**Verify**: kubectl get namespaces (dev, prod, staging listed).

2. Update Policy for Multi-Environment

- The require-requests-limits.yaml (above) already includes rules for prod and dev/staging. Reapply if modified:

```bash
kubectl apply -f policies/require-requests-limits.yaml
```
3. Test in Prod
```bash
kubectl apply -f tests/compliant-pod.yaml -n prod
```
**Verify**: kubectl get pods -n prod (compliant-pod Running).

## Phase 9: Integrate Monitoring with Kyverno

- Visualize Kyverno metrics in Prometheus/Grafana.

1. Create ServiceMonitor

- #### vim monitoring/kyverno-servicemonitor.yaml
```bash
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kyverno-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kyverno
  endpoints:
  - port: metrics
    path: /metrics
```
2. Apply ServiceMonitor
```bash
kubectl apply -f monitoring/kyverno-servicemonitor.yaml
```

**Verify**: kubectl get servicemonitor -n monitoring (kyverno-metrics listed).

3. Configure Grafana Dashboard
```bash
kubectl port-forward --address 0.0.0.0 service/prometheus-grafana 31509:80 -n monitoring
```

- Access http://localhost:31509.
- Log in (admin password: kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d).
- Add Prometheus data source: 
    - **ex**: http://10.108.46.119:9090
- Create dashboard with query: rate(kyverno_policy_violations_total[5m]).
- **Note**: If metrics fail, verify Kyverno’s metrics port (default 8000).





































































