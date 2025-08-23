#!/bin/bash

# Automated Backup Script for Disaster Recovery
set -e

NAMESPACE="microservices"
BACKUP_NAME="chaos-backup-$(date +%Y%m%d-%H%M%S)"
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

# Function to check if Velero is installed
check_velero() {
    if ! command -v velero &> /dev/null; then
        log_error "Velero CLI not found. Installing..."
        wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
        tar -xvf velero-v1.12.0-linux-amd64.tar.gz
        sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/
        rm -rf velero-v1.12.0-linux-amd64*
    fi
    
    # Check if Velero is running in cluster
    if ! kubectl get deployment -n velero velero &> /dev/null; then
        log_error "Velero not found in cluster. Please install Velero first."
        exit 1
    fi
}

# Function to perform database backups
backup_databases() {
    log_info "Starting database backups..."
    
    # PostgreSQL backup
    if kubectl get pods -n $NAMESPACE -l app=postgresql &> /dev/null; then
        log_info "Backing up PostgreSQL..."
        POD=$(kubectl get pods -n $NAMESPACE -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -n $NAMESPACE $POD -- pg_dumpall -U postgres > postgres-backup-$(date +%Y%m%d-%H%M%S).sql
    fi
    
    # MongoDB backup
    if kubectl get pods -n $NAMESPACE -l app=mongodb &> /dev/null; then
        log_info "Backing up MongoDB..."
        POD=$(kubectl get pods -n $NAMESPACE -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -n $NAMESPACE $POD -- mongodump --out=/tmp/mongodb-backup
        kubectl cp $NAMESPACE/$POD:/tmp/mongodb-backup ./mongodb-backup-$(date +%Y%m%d-%H%M%S)
    fi
    
    # Redis backup
    if kubectl get pods -n $NAMESPACE -l app=redis &> /dev/null; then
        log_info "Backing up Redis..."
        POD=$(kubectl get pods -n $NAMESPACE -l app=redis -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -n $NAMESPACE $POD -- redis-cli BGSAVE
        sleep 5
        kubectl cp $NAMESPACE/$POD:/data/dump.rdb ./redis-backup-$(date +%Y%m%d-%H%M%S).rdb
    fi
}

# Function to create Velero backup
create_velero_backup() {
    log_info "Creating Velero backup: $BACKUP_NAME"
    
    velero backup create $BACKUP_NAME \
        --include-namespaces $NAMESPACE,monitoring,chaos-mesh \
        --exclude-resources events,events.events.k8s.io \
        --storage-location aws-backup \
        --volume-snapshot-locations aws-volume-snapshots \
        --wait
    
    # Check backup status
    STATUS=$(velero backup get $BACKUP_NAME -o json | jq -r '.status.phase')
    if [ "$STATUS" == "Completed" ]; then
        log_info "Backup completed successfully"
    else
        log_error "Backup failed with status: $STATUS"
        exit 1
    fi
}

# Function to verify backup
verify_backup() {
    log_info "Verifying backup..."
    
    # List backup contents
    velero backup describe $BACKUP_NAME --details
    
    # Check backup size and items
    ITEMS=$(velero backup describe $BACKUP_NAME -o json | jq '.status.itemsBackedUp')
    log_info "Backed up $ITEMS items"
}

# Function to create backup report
create_backup_report() {
    log_info "Creating backup report..."
    
    cat > backup-report-$(date +%Y%m%d-%H%M%S).json <<EOF
{
    "backup_name": "$BACKUP_NAME",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "namespace": "$NAMESPACE",
    "status": "$(velero backup get $BACKUP_NAME -o json | jq -r '.status.phase')",
    "items_backed_up": $(velero backup get $BACKUP_NAME -o json | jq '.status.itemsBackedUp'),
    "warnings": $(velero backup get $BACKUP_NAME -o json | jq '.status.warnings // 0'),
    "errors": $(velero backup get $BACKUP_NAME -o json | jq '.status.errors // 0'),
    "storage_location": "aws-backup"
}
EOF
}

# Main execution
main() {
    log_info "Starting automated backup process..."
    
    # Check prerequisites
    check_velero
    
    # Perform database backups
    backup_databases
    
    # Create Velero backup
    create_velero_backup
    
    # Verify backup
    verify_backup
    
    # Create report
    create_backup_report
    
    log_info "Backup process completed successfully"
}

# Run main function
main "$@"