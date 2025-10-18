# 🧭 Enforce Kubernetes Security with Kyverno

---

## 📘 Overview

As a **DevOps Engineer**, one of your key responsibilities is to **manage the Kubernetes cluster** according to your organization’s **compliance policies and rules**.  
This process of ensuring that every deployed resource adheres to these standards is called **_governance_**.

---

## 🔍 What is Governance?

Every organization defines a set of **rules or compliance policies** that must be followed.  

**Example rule:**  
> Every Pod created inside the Kubernetes cluster should have proper resource requests and limits.

This ensures resource optimization and prevents over-consumption or starvation.  
But how do you **define**, **enforce**, and **automate** such governance rules?  
👉 That’s where **Admission Controllers** and **Kyverno** come into play.

---

## ⚙️ Admission Controllers in Kubernetes

When a user performs actions like creating a Pod, Deployment, or Service, the request first goes through the **Kubernetes API Server**.  

An **Admission Controller** is a built-in mechanism that intercepts such requests **before they are saved** in Kubernetes.  
It can:
- ✅ Validate resources  
- 🧩 Mutate (modify) resources  
- 🚫 Reject invalid requests  

**Example:**  
When a Pod is created, the admission controller can check whether resource requests and limits are defined. If not, it can reject the request.

However, maintaining multiple custom controllers for governance across hundreds of clusters is difficult.  
To simplify this — we use **Kyverno**.

---

# 🚀 What is Kyverno?

**Kyverno** (Greek for “govern”) is a **cloud-native policy engine** built specifically for Kubernetes.  
It allows platform and DevOps engineers to automate **security**, **compliance**, and **best-practice validation** seamlessly.

Originally designed for Kubernetes, Kyverno can now also operate **outside Kubernetes** as a **unified policy language**.

---

## ✨ Key Features

- 📜 **Policies as YAML-based declarative resources** — no new language to learn  
- 🔐 **Policy enforcement** via:
  - Kubernetes **Admission Controller**
  - **CLI-based scanner**
  - **Runtime enforcement**
- 🔄 **Validate**, **mutate**, **generate**, or **cleanup** Kubernetes resources  
- 🧩 **Verify container images and metadata** for software supply-chain security  
- 🌍 **Support for any JSON payload**, including Terraform and cloud resources  
- ⚙️ **Flexible exception management**  
- 🧠 **Manage policies as code** with **Git** and **Kustomize**

---

# 🧩 How Kyverno Works

Kyverno operates as a **Dynamic Admission Controller** within a Kubernetes cluster.

1. The **Kubernetes API Server** sends admission requests (validating/mutating webhooks) to Kyverno.  
2. Kyverno compares these requests against the **defined policies**.  
3. Based on rules, Kyverno **enforces**, **mutates**, or **rejects** the request.  
4. The decision and compliance status are logged via **Kubernetes events** and **policy reports**.

---

## 🔧 Policy Matching

Kyverno policies can match Kubernetes resources using:
- Resource **kind**, **name**, or **namespace**
- **Labels** and **selectors**
- Complex **conditions** and **patterns**

---

## 🧱 Policy Types

### 🌀 Mutating Policies
- Modify or add fields automatically (like Kustomize overlays)  
- Support **RFC 6902 JSON patches**

### ✅ Validating Policies
- Verify resources using overlay-style YAML patterns  
- Support **conditional logic (if-then-else)**

---

## 🪶 Policy Reporting

- Policy results are captured as **Kubernetes events**  
- Existing resources are analyzed via **Policy Reports**  
- Reports display:
  - Matched resources  
  - Compliance status  
  - Violations and recommendations  

---

## 📊 Kyverno Architecture

```mermaid
flowchart LR
    A[Developer / DevOps] -->|Creates Pod / Deployment| B[Kubernetes API Server]
    B -->|Admission Request| C[Kyverno Admission Webhook]
    C -->|Applies Matching Policies| D[Validate / Mutate / Reject]
    D -->|Response| B
    B -->|Persist Valid Resources| E[etcd / Cluster]
    C --> F[Policy Reports & Events]
```
⚙️ Implementation Steps

This section demonstrates how to enforce Kubernetes security using Kyverno on an AWS EC2 instance with Minikube.

🚀 1. Launch an EC2 Instance

Open the AWS Console.

Launch an EC2 instance (recommended type: t2.medium or t2.large).

💻 2. Setup Local Environment
Open VS Code and Terminal

Open VS Code.

Click on the '+' icon beside the terminal tab → choose Git Bash (Default).

Create Project Folder and Clone Repository
$ cd ~/OneDrive/Desktop
$ mkdir Enforce-Kubernetes-Security-with-Kyverno
$ cd Enforce-Kubernetes-Security-with-Kyverno/
$ git clone <github-repository-URL>

🔗 3. Connect to EC2 Server
$ chmod 400 "abc.pem"
$ ssh -i "abc.pem" ubuntu@ec2-3-84-245-107.compute-1.amazonaws.com


You’ll see a prompt like:

ubuntu@ip-172-31-36-141:~$

☸️ 4. Install Minikube and kubectl

Follow one of the official guides below:

Install ArgoCD on Minikube (Ubuntu 24.04) – Fosstechnix

Alternative Guide

🐳 5. Install and Configure Docker

Follow Docker’s post-installation steps:

Docker Post-Install Docs

$ mkdir -p /home/ubuntu/.docker
$ sudo chown "$USER":"$USER" /home/ubuntu/.docker -R
$ sudo chmod g+rwx "$HOME/.docker" -R
$ sudo systemctl restart docker
$ sudo usermod -aG docker $USER
$ newgrp docker

🔐 6. Install Kyverno

Follow Kyverno’s official installation guide.

You can also install Argo CD if required.

ubuntu@ip-172-31-36-141:~$ git clone <repository-URL>

🧭 7. Apply Kyverno Policy

Navigate to the project in VS Code → open:

enforce-pod-requests-limits.yaml

Install the Policy
vi enforce-pod-requests-limits.yaml
kubectl apply -f enforce-pod-requests-limits.yaml


✅ Kyverno policy created successfully.

pod/nginx created

🧹 8. Managing Pods and Policies
# Delete a pod
kubectl delete pod <pod-name>

# Check pods
kubectl get pods

# Check Kyverno pods
kubectl get pods -A | grep kyverno

# View Kyverno logs
kubectl logs kyverno-68c8744f8b-58xrz -n kyverno

🔄 9. Editing and Updating Kyverno Policy

If a pod creation fails due to enforcement, modify the policy:

kubectl edit clusterpolicy require-requests-limits


Change:

ValidationFailureAction: audit


to:

ValidationFailureAction: enforce

🧠 10. Observing Kyverno Behavior
kubectl logs kyverno-68c8744f86-58xrz -n kyverno


Output:

"updating policy"


Then test again:

kubectl create deployment nginx --image=nginx


Kyverno will block this request because it enforces resource validation through its admission webhook.

🧹 11. Cleaning Up
kubectl delete deploy nginx
kubectl get clusterpolicy
kubectl delete clusterpolicy enforce-requests-limits
kubectl logs kyverno-68c8744f84b-58xrz -n kyverno


Inside logs, you’ll see that the policy was deleted.

Re-test deployment:

kubectl create deployment nginx --image=nginx


✅ This time, it deploys successfully because the Kyverno policy was removed.

🧩 Summary

Kyverno allows DevOps engineers to enforce governance and compliance in Kubernetes using declarative YAML policies.
It ensures every workload adheres to security and organisational standards automatically.

🔒 Kyverno = Kubernetes Governance + Policy-as-Code + Security Automation

📚 References

🌐 Kyverno Official Website

📘 Kyverno Policy Library

🧰 Kyverno GitHub Repository


