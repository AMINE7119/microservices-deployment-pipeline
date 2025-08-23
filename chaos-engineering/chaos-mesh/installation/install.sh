#!/bin/bash

# Chaos Mesh Installation Script
set -e

echo "Installing Chaos Mesh for Kubernetes Chaos Engineering..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if Helm is available
if ! command -v helm &> /dev/null; then
    echo "Helm is not installed. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

# Add Chaos Mesh Helm repository
echo "Adding Chaos Mesh Helm repository..."
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Install cert-manager (required for Chaos Mesh)
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s || true

# Create namespace
kubectl create namespace chaos-mesh --dry-run=client -o yaml | kubectl apply -f -

# Install Chaos Mesh using Helm
echo "Installing Chaos Mesh..."
helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-mesh \
  --version 2.6.3 \
  --set dashboard.enabled=true \
  --set dashboard.securityMode=true \
  --set controllerManager.replicaCount=3 \
  --set prometheus.enabled=true \
  --set webhook.certManager.enabled=true \
  --wait

# Check installation status
echo "Checking Chaos Mesh installation status..."
kubectl get pods -n chaos-mesh

# Get dashboard access information
echo ""
echo "Chaos Mesh installation complete!"
echo "Dashboard access:"
echo "1. Port-forward: kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333"
echo "2. Access: http://localhost:2333"
echo ""
echo "To create a dashboard user:"
echo "kubectl create serviceaccount chaos-dashboard-viewer -n chaos-mesh"
echo "kubectl create clusterrolebinding chaos-dashboard-viewer --clusterrole=chaos-mesh-viewer --serviceaccount=chaos-mesh:chaos-dashboard-viewer"