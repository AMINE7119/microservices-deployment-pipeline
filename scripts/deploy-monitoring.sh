#!/bin/bash

# Phase 5: Deploy Observability Stack
# This script deploys Prometheus, Grafana, Jaeger, Loki, and AlertManager

set -e

echo "🚀 Starting Phase 5: Observability Stack Deployment"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

print_status "Deploying Prometheus..."
kubectl apply -f monitoring/prometheus/prometheus-config.yaml
kubectl apply -f monitoring/prometheus/prometheus-rules.yaml  
kubectl apply -f monitoring/prometheus/prometheus-deployment.yaml

print_status "Deploying Grafana..."
kubectl apply -f monitoring/grafana/grafana-datasources.yaml
kubectl apply -f monitoring/grafana/grafana-dashboards-config.yaml
kubectl apply -f monitoring/grafana/grafana-deployment.yaml

print_status "Deploying Jaeger..."
kubectl apply -f monitoring/jaeger/jaeger-deployment.yaml

print_status "Deploying Loki and Promtail..."
kubectl apply -f monitoring/loki/loki-deployment.yaml
kubectl apply -f monitoring/loki/promtail-deployment.yaml

print_status "Deploying AlertManager..."
kubectl apply -f monitoring/alertmanager/alertmanager-deployment.yaml

print_status "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/loki -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/alertmanager -n monitoring

# Wait for DaemonSet
kubectl rollout status daemonset/promtail -n monitoring

print_status "Checking pod status..."
kubectl get pods -n monitoring

print_status "✅ Phase 5 Observability Stack deployed successfully!"

echo ""
echo "🎯 Access URLs (use kubectl port-forward):"
echo "  Grafana:      kubectl port-forward svc/grafana 3000:3000 -n monitoring"
echo "  Prometheus:   kubectl port-forward svc/prometheus 9090:9090 -n monitoring" 
echo "  Jaeger:       kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring"
echo "  AlertManager: kubectl port-forward svc/alertmanager 9093:9093 -n monitoring"

echo ""
echo "🔐 Grafana Login:"
echo "  Username: admin"
echo "  Password: admin123"

echo ""
echo "📊 Available Dashboards:"
echo "  - Microservices Overview"
echo "  - SLO/SLI Dashboard"
echo "  - Resource Utilization"

echo ""
echo "⚡ Next Steps:"
echo "  1. Update service deployments with metrics endpoints"
echo "  2. Configure alerting notifications (Slack, Email)" 
echo "  3. Add custom business metrics to services"
echo "  4. Set up log correlation with trace IDs"

print_status "Phase 5 deployment completed!"