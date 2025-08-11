#!/bin/bash

# Blue-Green Deployment Script for API Gateway
# Usage: ./blue-green-deploy.sh [deploy|switch|rollback]

set -e

NAMESPACE="default"
APP="api-gateway"
NEW_IMAGE="ghcr.io/amine7119/microservices-pipeline/api-gateway:phase4-v2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Get current active version
get_active_version() {
    kubectl get service api-gateway-blue-green -n $NAMESPACE -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "blue"
}

# Get inactive version
get_inactive_version() {
    local active=$(get_active_version)
    if [[ "$active" == "blue" ]]; then
        echo "green"
    else
        echo "blue"
    fi
}

# Deploy new version to inactive environment
deploy() {
    log "Starting Blue-Green deployment..."
    
    local active=$(get_active_version)
    local inactive=$(get_inactive_version)
    
    success "Current active version: $active"
    log "Deploying new version to $inactive environment..."
    
    # Apply blue-green deployments
    kubectl apply -f kubernetes/blue-green/api-gateway-blue.yaml -n $NAMESPACE
    kubectl apply -f kubernetes/blue-green/api-gateway-green.yaml -n $NAMESPACE
    kubectl apply -f kubernetes/blue-green/api-gateway-service-blue-green.yaml -n $NAMESPACE
    
    # Update the inactive deployment with new image
    if [[ "$inactive" == "green" ]]; then
        kubectl patch deployment api-gateway-green -n $NAMESPACE -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-gateway","image":"'$NEW_IMAGE'"}]}}}}'
        kubectl scale deployment api-gateway-green --replicas=2 -n $NAMESPACE
    else
        kubectl patch deployment api-gateway-blue -n $NAMESPACE -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-gateway","image":"'$NEW_IMAGE'"}]}}}}'
        kubectl scale deployment api-gateway-blue --replicas=2 -n $NAMESPACE
    fi
    
    log "Waiting for $inactive deployment to be ready..."
    kubectl rollout status deployment/api-gateway-$inactive -n $NAMESPACE --timeout=300s
    
    success "$inactive environment is ready with new version!"
    success "Preview URL: kubectl port-forward service/api-gateway-preview 8081:8080"
    
    log "To switch traffic to $inactive, run: $0 switch"
    log "To rollback, run: $0 rollback"
}

# Switch traffic to the inactive (newly deployed) version
switch() {
    log "Switching traffic to new version..."
    
    local active=$(get_active_version)
    local inactive=$(get_inactive_version)
    
    log "Current active: $active, switching to: $inactive"
    
    # Switch the main service selector
    kubectl patch service api-gateway-blue-green -n $NAMESPACE -p '{"spec":{"selector":{"version":"'$inactive'"}}}'
    
    success "Traffic switched to $inactive version!"
    
    # Wait a bit, then scale down the old version
    log "Waiting 30 seconds before scaling down old version..."
    sleep 30
    
    kubectl scale deployment api-gateway-$active --replicas=0 -n $NAMESPACE
    
    success "Old version ($active) scaled down"
    success "Blue-Green deployment completed successfully!"
}

# Rollback to previous version
rollback() {
    log "Rolling back to previous version..."
    
    local active=$(get_active_version)
    local inactive=$(get_inactive_version)
    
    log "Current active: $active, rolling back to: $inactive"
    
    # Scale up the inactive (previous) version
    kubectl scale deployment api-gateway-$inactive --replicas=2 -n $NAMESPACE
    kubectl rollout status deployment/api-gateway-$inactive -n $NAMESPACE --timeout=300s
    
    # Switch traffic back
    kubectl patch service api-gateway-blue-green -n $NAMESPACE -p '{"spec":{"selector":{"version":"'$inactive'"}}}'
    
    # Scale down the problematic version
    kubectl scale deployment api-gateway-$active --replicas=0 -n $NAMESPACE
    
    success "Rollback completed! Traffic restored to $inactive version"
}

# Show status
status() {
    local active=$(get_active_version)
    local inactive=$(get_inactive_version)
    
    echo "=== Blue-Green Deployment Status ==="
    echo "Active version: $active"
    echo "Inactive version: $inactive"
    echo ""
    echo "=== Deployments ==="
    kubectl get deployments -l app=api-gateway -n $NAMESPACE
    echo ""
    echo "=== Services ==="
    kubectl get services -l app=api-gateway -n $NAMESPACE
    echo ""
    echo "=== Pods ==="
    kubectl get pods -l app=api-gateway -n $NAMESPACE
}

# Main script logic
case "${1:-status}" in
    deploy)
        deploy
        ;;
    switch)
        switch
        ;;
    rollback)
        rollback
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {deploy|switch|rollback|status}"
        echo "  deploy  - Deploy new version to inactive environment"
        echo "  switch  - Switch traffic to newly deployed version"
        echo "  rollback - Rollback to previous version"
        echo "  status  - Show current deployment status"
        exit 1
        ;;
esac