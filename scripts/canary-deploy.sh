#!/bin/bash

# Canary Deployment Script for Product Service
# Usage: ./canary-deploy.sh [deploy|promote|rollback|status|scale]

set -e

NAMESPACE="default"
APP="product-service"
NEW_IMAGE="ghcr.io/amine7119/microservices-pipeline/product-service:phase4-v2"

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

# Get current canary percentage
get_canary_percentage() {
    local stable_replicas=$(kubectl get deployment product-service-stable -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    local canary_replicas=$(kubectl get deployment product-service-canary -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    local total=$((stable_replicas + canary_replicas))
    
    if [[ $total -eq 0 ]]; then
        echo "0"
    else
        echo $((canary_replicas * 100 / total))
    fi
}

# Deploy canary version
deploy() {
    log "Starting Canary deployment..."
    
    # First, build and push the new version
    log "Building new product-service image..."
    cd services/product-service
    docker build -t $NEW_IMAGE .
    docker push $NEW_IMAGE
    cd ../..
    
    log "Deploying stable and canary versions..."
    
    # Apply canary deployments
    kubectl apply -f kubernetes/canary/product-service-stable.yaml -n $NAMESPACE
    kubectl apply -f kubernetes/canary/product-service-canary.yaml -n $NAMESPACE
    kubectl apply -f kubernetes/canary/product-service-canary-service.yaml -n $NAMESPACE
    
    log "Waiting for deployments to be ready..."
    kubectl rollout status deployment/product-service-stable -n $NAMESPACE --timeout=300s
    kubectl rollout status deployment/product-service-canary -n $NAMESPACE --timeout=300s
    
    local percentage=$(get_canary_percentage)
    success "Canary deployment ready! $percentage% traffic going to canary version"
    success "Monitor canary metrics, then run: $0 promote"
    success "If issues occur, run: $0 rollback"
}

# Promote canary to full production
promote() {
    log "Promoting canary to full production..."
    
    local percentage=$(get_canary_percentage)
    log "Current canary traffic: $percentage%"
    
    if [[ $percentage -eq 0 ]]; then
        error "No canary deployment found to promote"
        exit 1
    fi
    
    # Gradually increase canary traffic
    log "Phase 1: Scaling canary to 50% traffic..."
    kubectl scale deployment product-service-stable --replicas=2 -n $NAMESPACE
    kubectl scale deployment product-service-canary --replicas=2 -n $NAMESPACE
    kubectl rollout status deployment/product-service-canary -n $NAMESPACE --timeout=60s
    
    sleep 30
    success "Canary at 50% - monitoring for 30 seconds..."
    
    log "Phase 2: Scaling canary to 75% traffic..."
    kubectl scale deployment product-service-stable --replicas=1 -n $NAMESPACE
    kubectl scale deployment product-service-canary --replicas=3 -n $NAMESPACE
    kubectl rollout status deployment/product-service-canary -n $NAMESPACE --timeout=60s
    
    sleep 30
    success "Canary at 75% - monitoring for 30 seconds..."
    
    log "Phase 3: Full promotion - 100% traffic to canary..."
    kubectl scale deployment product-service-stable --replicas=0 -n $NAMESPACE
    kubectl scale deployment product-service-canary --replicas=4 -n $NAMESPACE
    kubectl rollout status deployment/product-service-canary -n $NAMESPACE --timeout=60s
    
    success "Canary promotion completed! 100% traffic on new version"
    
    # Update the stable deployment with the new image
    log "Updating stable deployment with new image..."
    kubectl patch deployment product-service-stable -n $NAMESPACE -p '{"spec":{"template":{"spec":{"containers":[{"name":"product-service","image":"'$NEW_IMAGE'"}]}}}}'
    kubectl scale deployment product-service-stable --replicas=3 -n $NAMESPACE
    kubectl scale deployment product-service-canary --replicas=0 -n $NAMESPACE
    
    success "Promotion complete! Stable deployment updated with new version"
}

# Rollback canary deployment
rollback() {
    log "Rolling back canary deployment..."
    
    local percentage=$(get_canary_percentage)
    log "Current canary traffic: $percentage%"
    
    if [[ $percentage -eq 0 ]]; then
        warning "No canary deployment to rollback"
        return
    fi
    
    # Scale canary to 0 and stable to handle all traffic
    kubectl scale deployment product-service-canary --replicas=0 -n $NAMESPACE
    kubectl scale deployment product-service-stable --replicas=4 -n $NAMESPACE
    kubectl rollout status deployment/product-service-stable -n $NAMESPACE --timeout=60s
    
    success "Rollback completed! All traffic restored to stable version"
}

# Scale canary traffic
scale() {
    local target_percentage=${2:-25}
    log "Scaling canary to $target_percentage% traffic..."
    
    # Calculate replica distribution
    local total_replicas=4
    local canary_replicas=$((target_percentage * total_replicas / 100))
    local stable_replicas=$((total_replicas - canary_replicas))
    
    # Ensure at least 1 replica if percentage > 0
    if [[ $target_percentage -gt 0 && $canary_replicas -eq 0 ]]; then
        canary_replicas=1
        stable_replicas=$((total_replicas - 1))
    fi
    
    log "Setting stable: $stable_replicas replicas, canary: $canary_replicas replicas"
    
    kubectl scale deployment product-service-stable --replicas=$stable_replicas -n $NAMESPACE
    kubectl scale deployment product-service-canary --replicas=$canary_replicas -n $NAMESPACE
    
    if [[ $canary_replicas -gt 0 ]]; then
        kubectl rollout status deployment/product-service-canary -n $NAMESPACE --timeout=60s
    fi
    kubectl rollout status deployment/product-service-stable -n $NAMESPACE --timeout=60s
    
    local actual_percentage=$(get_canary_percentage)
    success "Canary scaled to $actual_percentage% traffic"
}

# Show status
status() {
    local percentage=$(get_canary_percentage)
    
    echo "=== Canary Deployment Status ==="
    echo "Canary traffic percentage: $percentage%"
    echo ""
    echo "=== Deployments ==="
    kubectl get deployments -l app=product-service -n $NAMESPACE
    echo ""
    echo "=== Services ==="
    kubectl get services -l app=product-service -n $NAMESPACE
    echo ""
    echo "=== Pods ==="
    kubectl get pods -l app=product-service -n $NAMESPACE
    echo ""
    echo "=== Traffic Distribution ==="
    echo "Stable pods: $(kubectl get deployment product-service-stable -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo '0')"
    echo "Canary pods: $(kubectl get deployment product-service-canary -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo '0')"
}

# Test canary endpoint
test() {
    log "Testing canary endpoints..."
    
    # Test stable-only endpoint
    echo "Testing stable endpoint..."
    kubectl port-forward service/product-service-stable-only 8001:8000 -n $NAMESPACE &
    sleep 2
    curl -s http://localhost:8001/health | jq .
    kill %1
    
    # Test canary-only endpoint  
    echo "Testing canary endpoint..."
    kubectl port-forward service/product-service-canary-only 8002:8000 -n $NAMESPACE &
    sleep 2
    curl -s http://localhost:8002/health | jq .
    kill %1
    
    success "Endpoint tests completed"
}

# Main script logic
case "${1:-status}" in
    deploy)
        deploy
        ;;
    promote)
        promote
        ;;
    rollback)
        rollback
        ;;
    scale)
        scale "$@"
        ;;
    status)
        status
        ;;
    test)
        test
        ;;
    *)
        echo "Usage: $0 {deploy|promote|rollback|scale [percentage]|status|test}"
        echo "  deploy   - Deploy new version as canary (25% traffic)"
        echo "  promote  - Gradually promote canary to 100%"
        echo "  rollback - Rollback canary, restore all traffic to stable"
        echo "  scale    - Scale canary to specific percentage (default 25%)"
        echo "  status   - Show current deployment status"
        echo "  test     - Test stable and canary endpoints"
        exit 1
        ;;
esac