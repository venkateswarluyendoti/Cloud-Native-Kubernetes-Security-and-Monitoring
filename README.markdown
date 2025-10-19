# Cloud-Native Kubernetes Security and Monitoring with Kyverno and GitOps
**Overview**
- This project demonstrates Kubernetes security governance using Kyverno for policy enforcement, managed via Argo CD for GitOps. It includes multi-environment support (dev, prod, staging), Prometheus/Grafana monitoring, policy testing, and comprehensive troubleshooting. The setup runs on a single-node Minikube cluster within AWS EC2 resource constraints (2 vCPUs, ~3.8GB memory).

<img width="1917" height="723" alt="image" src="https://github.com/user-attachments/assets/14d4a722-5978-47d8-a785-6efea3d62a87" />

<img width="1915" height="689" alt="Screenshot 2025-10-19 092455" src="https://github.com/user-attachments/assets/a1da5994-1936-4207-97dc-eaa6564c8ada" />
<img width="1919" height="722" alt="Screenshot 2025-10-19 092527" src="https://github.com/user-attachments/assets/9cc018df-c1f9-4cd9-b781-395e72543eac" />

<img width="1913" height="732" alt="image" src="https://github.com/user-attachments/assets/b2d5c15d-206b-478d-b896-83fae07d6709" />

<img width="1916" height="705" alt="Screenshot 2025-10-18 121336" src="https://github.com/user-attachments/assets/7507210c-a947-4bef-acdc-beff29a1303a" />


**Goals**:

- Enforce security policies (e.g., resource limits, no "latest" image tags).
- Manage policies declaratively using Argo CD GitOps.
- Test policy compliance and troubleshoot issues (e.g., webhook failures, resource exhaustion).
- Integrate Prometheus/Grafana for monitoring Kyverno metrics.

Repo Structure:
```bash
Cloud-Native-Kubernetes-Security-and-Monitoring/
├── Docker Compose/
│   ├── docker-compose.yaml
│   └── prometheus.yaml
├── Existing/
│   ├── Project/
│   │   ├── Block-latest-tag.sh
│   │   ├── Block-latest-tag.yaml
│   │   ├── Create an Argo CD Application for Kyverno Policies
│   │   │   ├── argo-kyverno-app.yaml
│   │   │   └── argo.sh
│   │   ├── Generate → Auto-create a Default Network Policy.yaml
│   │   ├── Invalid-pods/
│   │   │   ├── Block-Latest-tag.yaml
│   │   │   ├── First Policy-SecondPolicy.yaml
│   │   │   ├── Invalid-Values-For-Resources.yaml
│   │   │   ├── Missing-Only-Limits.yaml
│   │   │   ├── Missing-Requests-Limits.yaml
│   │   │   ├── Violating Policies.yaml
│   │   │   └── verify-container-images.yaml
│   │   ├── Mutate → Auto-Inject Pod Security Context.yaml
│   │   ├── Validate → Block Usage of latest Tag in Deployments.yaml
│   │   ├── Verify Images → Ensure Container Images are Signed.yaml
│   │   ├── enforce-network-policy.yaml
│   │   ├── enforce-pod-requests-limits.yml
│   │   └── valid-pods/
│   │       ├── Corrected-invalid-pod.yaml
│   │       ├── secure-nginx-deployment.yaml
│   │       ├── test-deployment-4-policies.yaml
│   │       └── valid-pod-with-resources.yaml
│   └── kyverno-Implement-steps
│       └── README.markdown
├── Policies/
│   ├── disallow-latest-tag.yaml
│   ├── multi-environment.yaml
│   └── require-requests-limits.yaml
├── README.markdown
├── kyverno-Implement-steps
│   └── README.md
├── monitoring/
│   ├── kyverno-servicemonitor.yaml
│   └── prometheus-values.yaml
└── tests/
    ├── compliant-pod.yaml
    └── non-compliant-pod.yaml

12 directories, 33 files

```


## Phase 1: Prerequisites and Environment Setup

- **Set up the base environment with Docker, Minikube, kubectl, Helm, and Git, ensuring Docker permissions for "non-root users"**.

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
minikube start --driver=docker --memory=4096m --cpus=2

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Initialize repository
git clone https://github.com/venkateswarluyendoti/Cloud-Native-Kubernetes-Security-and-Monitoring.git
cd Cloud-Native-Kubernetes-Security-and-Monitoring
```

- **Esc + Shift : wq**

#### Steps:

1. **Run Setup Script**

```bash
chmod +x setup.sh
./setup.sh
```
<img width="1920" height="1080" alt="Screenshot (290)" src="https://github.com/user-attachments/assets/af38fe91-da96-4928-8995-ee2618a4f5cb" />
<img width="1916" height="495" alt="image" src="https://github.com/user-attachments/assets/75de85ca-1d7f-4102-bddb-e899236c5cd7" />

**Verify**:

- git --version (e.g., Git 2.x).
- docker --version (e.g., 20.10.x), docker run hello-world (success).
- kubectl version --client (e.g., v1.30.x).
- minikube status (host/kubelet running), kubectl get nodes (minikube Ready).
- helm version (e.g., v3.14.x).
- ls -l (confirm directories: policies, tests, monitoring).

<img width="1915" height="815" alt="image" src="https://github.com/user-attachments/assets/e0c1023e-8051-416b-80a9-9a1181fedc36" />

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

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/2764104e-8e04-4f15-8f42-be09ff13f57a" />

<img width="1910" height="372" alt="image" src="https://github.com/user-attachments/assets/7869b266-5530-447c-89cc-4358df09c07e" />



<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/0bd6e201-a1fd-436f-b6ec-ad4c7840b3d5" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/bfbec7f0-12bb-40b3-9da8-22abcd8d6c57" />




## Phase 3: Install Prometheus and Grafana

- Deploy monitoring tools with resource limits to comply with future Kyverno policies.

#### Steps

1. Add Helm Repository


```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

<img width="1912" height="426" alt="image" src="https://github.com/user-attachments/assets/26ee41f6-cd34-4bdc-93e4-323afc418aef" />

- **Verify**: helm search repo prometheus-community (lists charts).

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/532c97d7-bc77-444b-9cfb-99228ddbc303" />


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

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/e31b45c9-a9e5-4bcd-87e9-7616f295220f" />



**Verify**:

- kubectl get pods -n monitoring (Running).

<img width="1914" height="353" alt="image" src="https://github.com/user-attachments/assets/0fed8da5-c981-4e07-87a8-3f9016ac2fae" />
  
- Change Service Type to NodePort

```bash
kubectl patch svc prometheus-grafana -n monitoring -p '{"spec": {"type": "NodePort"}}'
```

<img width="1545" height="291" alt="image" src="https://github.com/user-attachments/assets/97b3f587-395c-40ea-9860-66c36d7eafdd" />

- Then verify:

```bash
kubectl get svc prometheus-grafana -n monitoring
```
- You should now see something like:

```bash
NAME                 TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
prometheus-grafana   NodePort   10.105.141.176  <none>        80:3xxxx/TCP     5m
```

- Port-forward: kubectl port-forward --address 0.0.0.0 service/prometheus-grafana 31509:80 -n monitoring

- ### 🌐 Access Grafana from Browser

- Use your EC2 public IP or DNS:
```bash
http://<ec2-public-ip>:<nodeport>
```

- Example:
```bash
http://3.90.246.106:30977
```

- Access Grafana: http://localhost:31509 
- Get Grafana Admin Username:

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-user}" | base64 --decode; echo
```

- Get Grafana Admin Password:

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```
<img width="1919" height="277" alt="image" src="https://github.com/user-attachments/assets/f5ef13fe-fa22-432d-b193-38cbeb177a4a" />

<img width="1919" height="897" alt="image" src="https://github.com/user-attachments/assets/67f75178-2be1-425d-b488-d4b64bccd4a1" />


<img width="1919" height="793" alt="image" src="https://github.com/user-attachments/assets/0319ea46-d8d4-4a6f-b3b5-e5ce895c683a" />

```bash
kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring
```
<img width="1544" height="81" alt="image" src="https://github.com/user-attachments/assets/10e9f66c-9737-4554-a0e6-ba5db2bfe6e0" />

- **Optional**: Change Service Type to NodePort (for external access)
  
```bash
kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring -p '{"spec": {"type": "NodePort"}}'
kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring
```
<img width="1548" height="163" alt="image" src="https://github.com/user-attachments/assets/81ac3bad-1ed1-4ee1-b40b-82881a5b308d" />



- **Note**:
- ### Dashboard of Grafana under "Connection"
  - In the Prometheus server URL field, we must add http:// before the IP address..
    - Ex: http://10.108.199.33:9090


<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/1a51474a-7d8c-4945-b407-096334851acd" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/fc2c8edc-3dab-4003-8679-822cdbc1f464" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/383ecf23-c244-4672-9b2b-2583b2fd523d" />

<img width="1920" height="1080" alt="Screenshot (309)" src="https://github.com/user-attachments/assets/29269ed4-3458-458c-9868-fedec367d9a1" />

<img width="1920" height="1080" alt="Screenshot (310)" src="https://github.com/user-attachments/assets/4258f3fb-2a03-46a4-af4c-6b086dd69c69" />

<img width="1920" height="1080" alt="Screenshot (312)" src="https://github.com/user-attachments/assets/8c15ce39-622d-4894-a7fa-3e1f97ca496c" />

<img width="1919" height="786" alt="image" src="https://github.com/user-attachments/assets/0c4d0773-e96f-405b-ae31-29e03e4283d1" />

<img width="1920" height="1080" alt="Screenshot (313)" src="https://github.com/user-attachments/assets/24054d83-a48f-4a2c-a8e4-7b29890ad8ac" />


## Phase 4: Install and Configure Argo CD

- Deploy Argo CD to manage policies via GitOps.

#### Steps

1. **Create Namespace**

```bash
kubectl create namespace argocd
```

2. **Install Argo CD**
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/950c5ef8-3b9f-4556-84ce-d92b3824324d" />


**Verify**: kubectl get pods -n argocd (Running).

<img width="1916" height="348" alt="image" src="https://github.com/user-attachments/assets/af0aecb2-64d7-4cc9-b1ce-81b5b66819e4" />



3. **Expose API Server**

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
```

<img width="1916" height="189" alt="image" src="https://github.com/user-attachments/assets/d69c1ff5-5057-49e0-8d61-80edf17dd87f" />



- **Verify**: Access http://<EC2-IP>:<NodePort> (e.g., 32679).

- **Port-Forward** : kubectl port-forward --address 0.0.0.0 service/argocd-server 31545:80 -n argocd

4. **Get Admin Password**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/ba544929-bc0f-47b9-b255-6b96693d8936" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/57562ccb-68af-45e0-ac4a-150c160cd431" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/ab003f9d-c3f7-48a2-b770-34698ed0fd93" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/e198a3d4-1f61-4abb-9df3-c294d7d4b121" />


5. **Install Argo CD CLI**
```bash
sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd
```
<img width="1920" height="1080" alt="Screenshot (293)" src="https://github.com/user-attachments/assets/31b1d088-5495-475b-9d0a-7a3d8f024ff0" />


## Phase 5: Apply Kyverno Policies

- Define and apply policies to enforce resource limits and disallow "latest" tags, with exclusions for monitoring and argocd.

1. **Create Policy Files**

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

1. **Create Test Files**

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

<img width="1557" height="314" alt="image" src="https://github.com/user-attachments/assets/198682d6-a6c2-4d1b-8833-822883f995ae" />


<img width="1920" height="1080" alt="Screenshot (295)" src="https://github.com/user-attachments/assets/7c3aca32-d188-462f-abdb-22ed088ee8a6" />


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
<img width="1559" height="212" alt="image" src="https://github.com/user-attachments/assets/fcd24d53-0263-4927-be14-4ca4728c6c80" />


<img width="1920" height="1080" alt="Screenshot (300)" src="https://github.com/user-attachments/assets/28def25e-1966-4c15-8333-69b0f784a72d" />
<img width="1549" height="605" alt="Screenshot 2025-10-18 115251" src="https://github.com/user-attachments/assets/40e6eacf-41a1-4251-a4e5-59970a3806b0" />

2. **Test Deployment**
```bash
kubectl apply -f tests/non-compliant-pod.yaml
kubectl apply -f tests/compliant-pod.yaml -n prod
```
<img width="1920" height="1080" alt="Screenshot (299)" src="https://github.com/user-attachments/assets/0a081531-205d-456f-8f8d-1147e103a1f6" />
<img width="1561" height="251" alt="Screenshot 2025-10-18 115156" src="https://github.com/user-attachments/assets/19074a36-598c-4206-833f-162885f6ce75" />

<img width="1551" height="232" alt="Screenshot 2025-10-18 120728" src="https://github.com/user-attachments/assets/ae210df6-6d34-4292-bcf9-1359f689cff6" />
<img width="1920" height="1080" alt="Screenshot (301)" src="https://github.com/user-attachments/assets/311c37f4-f58b-4b6f-ab40-2ea78b30c446" />
<img width="1570" height="583" alt="Screenshot 2025-10-18 121002" src="https://github.com/user-attachments/assets/ee1111ea-089a-4411-b9cf-58e4c55a31c5" />

- **Expected**:

- Non-compliant pod fails (Kyverno violation: "Using 'latest' tag").
- Compliant pod succeeds in prod.
- **Verify**:
    - kubectl get pods -n prod (compliant-pod Running).
    - kubectl describe pod non-compliant-pod (Kyverno denial in events).


## Phase 7: Extend with Multi-Environment Support

- Add namespace-based policies for dev, prod, and staging.

1. **Create Namespaces**

```bash
kubectl create namespace dev
kubectl create namespace prod
kubectl create namespace staging
```
- **Verify**: kubectl get namespaces (dev, prod, staging listed).
<img width="1546" height="160" alt="image" src="https://github.com/user-attachments/assets/dcae253a-8bec-498f-a1d5-fa07d34b5fd1" />

<img width="1559" height="309" alt="image" src="https://github.com/user-attachments/assets/1fa35605-9264-4efa-962b-6d3e86801ae9" />


2. **Update Policy for Multi-Environment**

- The require-requests-limits.yaml (above) already includes rules for prod and dev/staging. Reapply if modified:

```bash
kubectl apply -f policies/require-requests-limits.yaml
```
3. **Test in Prod**
```bash
kubectl apply -f tests/compliant-pod.yaml -n prod
```
- **Verify**: kubectl get pods -n prod (compliant-pod Running).

## Phase 8: Integrate Monitoring with Kyverno

- Visualize Kyverno metrics in Prometheus/Grafana.

1. **Create ServiceMonitor**

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
2. **Apply ServiceMonitor**
```bash
kubectl apply -f monitoring/kyverno-servicemonitor.yaml
```

- **Verify**: **kubectl get servicemonitor -n monitoring** (kyverno-metrics listed).

<img width="1557" height="424" alt="image" src="https://github.com/user-attachments/assets/008755c0-edf0-4543-bbc1-e64579c810ca" />


3. **Configure Grafana Dashboard**
```bash
kubectl port-forward --address 0.0.0.0 service/prometheus-grafana 31509:80 -n monitoring
```

- Access http://localhost:31509.
- Log in (admin password): kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo
- Add Prometheus data source: 
    - **ex**: http://10.108.46.119:9090

<img width="1920" height="1080" alt="Screenshot (305)" src="https://github.com/user-attachments/assets/83d2219f-ff30-4e09-bd57-d15506665660" />

<img width="1920" height="1080" alt="Screenshot (308)" src="https://github.com/user-attachments/assets/e9762865-1b9a-4c8e-8754-d3de6bfeacfa" />

- Create dashboard with query: rate(kyverno_policy_violations_total[5m]).
  
- **Note**: If metrics fail, verify Kyverno’s metrics port (default 8000).

## Phase 9: Troubleshoot and Document

1. **Check Logs**

```bash
kubectl logs -n kyverno deployment/kyverno-admission-controller | grep "Policy Violation"
```
**Note**: If monitoring/argocd pods are blocked, verify the exclude rules in policies.

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


### Project Cleanup 

- **Stop and delete the Minikube cluster**
```bash
minikube stop
minikube delete
rm -rf ~/.minikube
```
- **Remove local project files**
```bash
cd ~
rm -rf Enforce-kubernetes-security-with-kyverno
```
- **Remove Argo CD CLI**
```bash
sudo rm /usr/local/bin/argocd
```































































