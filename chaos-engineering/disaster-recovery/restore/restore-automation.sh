#!/bin/bash

# Automated Restore Script for Disaster Recovery
set -e

NAMESPACE="microservices"
VELERO_NAMESPACE="velero"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to list available backups
list_backups() {
    log_info "Available backups:"
    velero backup get
}

# Function to validate backup
validate_backup() {
    local backup_name=$1
    
    if ! velero backup get $backup_name &> /dev/null; then
        log_error "Backup $backup_name not found"
        return 1
    fi
    
    STATUS=$(velero backup get $backup_name -o json | jq -r '.status.phase')
    if [ "$STATUS" != "Completed" ]; then
        log_error "Backup $backup_name is not in Completed state. Status: $STATUS"
        return 1
    fi
    
    return 0
}

# Function to prepare for restore
prepare_restore() {
    log_info "Preparing for restore..."
    
    # Scale down deployments to prevent conflicts
    log_info "Scaling down existing deployments..."
    kubectl scale deployment --all -n $NAMESPACE --replicas=0 || true
    
    # Delete existing resources (optional, based on restore strategy)
    read -p "Delete existing resources before restore? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Deleting existing resources..."
        kubectl delete all --all -n $NAMESPACE || true
    fi
}

# Function to perform restore
perform_restore() {
    local backup_name=$1
    local restore_name="restore-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Starting restore from backup: $backup_name"
    
    velero restore create $restore_name \
        --from-backup $backup_name \
        --include-namespaces $NAMESPACE \
        --wait
    
    # Check restore status
    STATUS=$(velero restore get $restore_name -o json | jq -r '.status.phase')
    if [ "$STATUS" == "Completed" ]; then
        log_info "Restore completed successfully"
    else
        log_error "Restore failed with status: $STATUS"
        velero restore describe $restore_name
        return 1
    fi
    
    echo $restore_name
}

# Function to restore databases
restore_databases() {
    log_info "Restoring database data..."
    
    # Wait for database pods to be ready
    kubectl wait --for=condition=ready pod -l app=postgresql -n $NAMESPACE --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=mongodb -n $NAMESPACE --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=300s || true
    
    # PostgreSQL restore
    if [ -f postgres-backup-*.sql ]; then
        log_info "Restoring PostgreSQL..."
        POD=$(kubectl get pods -n $NAMESPACE -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
        kubectl cp postgres-backup-*.sql $NAMESPACE/$POD:/tmp/restore.sql
        kubectl exec -n $NAMESPACE $POD -- psql -U postgres -f /tmp/restore.sql
    fi
    
    # MongoDB restore
    if [ -d mongodb-backup-* ]; then
        log_info "Restoring MongoDB..."
        POD=$(kubectl get pods -n $NAMESPACE -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
        kubectl cp mongodb-backup-* $NAMESPACE/$POD:/tmp/mongodb-restore
        kubectl exec -n $NAMESPACE $POD -- mongorestore /tmp/mongodb-restore
    fi
    
    # Redis restore
    if [ -f redis-backup-*.rdb ]; then
        log_info "Restoring Redis..."
        POD=$(kubectl get pods -n $NAMESPACE -l app=redis -o jsonpath='{.items[0].metadata.name}')
        kubectl cp redis-backup-*.rdb $NAMESPACE/$POD:/data/dump.rdb
        kubectl exec -n $NAMESPACE $POD -- redis-cli SHUTDOWN NOSAVE
        kubectl delete pod $POD -n $NAMESPACE
        kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=300s
    fi
}

# Function to verify restore
verify_restore() {
    log_info "Verifying restored resources..."
    
    # Check deployments
    log_info "Checking deployments..."
    kubectl get deployments -n $NAMESPACE
    
    # Check services
    log_info "Checking services..."
    kubectl get services -n $NAMESPACE
    
    # Check PVCs
    log_info "Checking persistent volume claims..."
    kubectl get pvc -n $NAMESPACE
    
    # Check pod status
    log_info "Checking pod status..."
    kubectl get pods -n $NAMESPACE
    
    # Wait for all pods to be ready
    log_info "Waiting for all pods to be ready..."
    kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=600s || true
}

# Function to perform health checks
health_check() {
    log_info "Performing health checks..."
    
    # Check API Gateway
    if kubectl get service api-gateway -n $NAMESPACE &> /dev/null; then
        GATEWAY_URL=$(kubectl get service api-gateway -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ ! -z "$GATEWAY_URL" ]; then
            curl -s -o /dev/null -w "API Gateway HTTP Status: %{http_code}\n" http://$GATEWAY_URL/health || true
        fi
    fi
    
    # Check each service
    for service in api-gateway user-service product-service order-service frontend; do
        POD=$(kubectl get pods -n $NAMESPACE -l app=$service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ ! -z "$POD" ]; then
            log_info "Checking $service health..."
            kubectl exec -n $NAMESPACE $POD -- curl -s http://localhost:8080/health || true
        fi
    done
}

# Function to create restore report
create_restore_report() {
    local restore_name=$1
    
    log_info "Creating restore report..."
    
    cat > restore-report-$(date +%Y%m%d-%H%M%S).json <<EOF
{
    "restore_name": "$restore_name",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "namespace": "$NAMESPACE",
    "status": "$(velero restore get $restore_name -o json | jq -r '.status.phase')",
    "items_restored": $(velero restore get $restore_name -o json | jq '.status.itemsRestored // 0'),
    "warnings": $(velero restore get $restore_name -o json | jq '.status.warnings // 0'),
    "errors": $(velero restore get $restore_name -o json | jq '.status.errors // 0')
}
EOF
}

# Main execution
main() {
    log_info "Starting automated restore process..."
    
    # List available backups
    list_backups
    
    # Get backup name from user
    read -p "Enter backup name to restore from: " BACKUP_NAME
    
    # Validate backup
    if ! validate_backup $BACKUP_NAME; then
        log_error "Invalid backup selected"
        exit 1
    fi
    
    # Prepare for restore
    prepare_restore
    
    # Perform restore
    RESTORE_NAME=$(perform_restore $BACKUP_NAME)
    
    # Restore databases
    restore_databases
    
    # Verify restore
    verify_restore
    
    # Health check
    health_check
    
    # Create report
    create_restore_report $RESTORE_NAME
    
    log_info "Restore process completed successfully"
}

# Run main function
main "$@"