#!/bin/bash
# Create Kyverno namespace
kubectl create namespace kyverno

# Install Kyverno with Helm
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --set admissionController.replicas=1 --set cleanupController.enabled=true