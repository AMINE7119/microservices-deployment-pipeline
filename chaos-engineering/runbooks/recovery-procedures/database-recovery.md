# Database Recovery Procedures

## Overview
This runbook covers database recovery procedures for PostgreSQL, MongoDB, and Redis in chaos engineering scenarios.

## PostgreSQL Recovery

### Scenario 1: Primary Database Pod Failure

#### Detection
```bash
# Check PostgreSQL pods
kubectl get pods -n microservices -l app=postgresql

# Check database connectivity
kubectl run psql-test --image=postgres:13 -it --rm --restart=Never -n microservices -- \
  psql -h postgresql.microservices -U postgres -c "SELECT 1;"
```

#### Recovery Steps
1. **Check Pod Status**
   ```bash
   kubectl describe pod -l app=postgresql -n microservices
   kubectl logs -l app=postgresql -n microservices --tail=100
   ```

2. **Verify StatefulSet Status**
   ```bash
   kubectl get statefulset postgresql -n microservices
   kubectl describe statefulset postgresql -n microservices
   ```

3. **Check Persistent Volume**
   ```bash
   kubectl get pv,pvc -n microservices | grep postgresql
   ```

4. **Force Pod Recreation if Stuck**
   ```bash
   kubectl delete pod postgresql-0 -n microservices --force --grace-period=0
   ```

5. **Verify Recovery**
   ```bash
   kubectl wait --for=condition=ready pod -l app=postgresql -n microservices --timeout=300s
   
   # Test database connection
   kubectl exec -it postgresql-0 -n microservices -- psql -U postgres -c "\l"
   ```

### Scenario 2: Database Corruption

#### Detection
```bash
# Check for corruption errors in logs
kubectl logs postgresql-0 -n microservices | grep -i "corrupt\|error\|panic"

# Run database integrity check
kubectl exec -it postgresql-0 -n microservices -- \
  psql -U postgres -c "SELECT datname, pg_database_size(datname) FROM pg_database;"
```

#### Recovery Steps
1. **Create Emergency Backup**
   ```bash
   kubectl exec postgresql-0 -n microservices -- \
     pg_dumpall -U postgres > emergency-backup-$(date +%Y%m%d-%H%M%S).sql
   ```

2. **Restore from Latest Velero Backup**
   ```bash
   # List available backups
   velero backup get
   
   # Restore database
   velero restore create postgresql-recovery-$(date +%Y%m%d-%H%M%S) \
     --from-backup [BACKUP_NAME] \
     --include-resources persistentvolumeclaims,persistentvolumes \
     --selector app=postgresql
   ```

3. **If Velero Restore Fails, Restore from SQL Backup**
   ```bash
   # Scale down applications
   kubectl scale deployment api-gateway user-service order-service -n microservices --replicas=0
   
   # Connect to database
   kubectl exec -it postgresql-0 -n microservices -- psql -U postgres
   
   # Drop and recreate database
   DROP DATABASE IF EXISTS microservices;
   CREATE DATABASE microservices;
   \q
   
   # Restore from backup
   kubectl exec -i postgresql-0 -n microservices -- \
     psql -U postgres microservices < postgresql-backup.sql
   ```

### Scenario 3: Replica Lag Issues

#### Detection
```bash
# Check replication status
kubectl exec postgresql-0 -n microservices -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check replica lag
kubectl exec postgresql-replica-0 -n microservices -- \
  psql -U postgres -c "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()));"
```

#### Recovery Steps
1. **Restart Replica**
   ```bash
   kubectl delete pod postgresql-replica-0 -n microservices
   ```

2. **If Lag Persists, Force Resync**
   ```bash
   # Stop replica
   kubectl scale statefulset postgresql-replica -n microservices --replicas=0
   
   # Clear replica data
   kubectl delete pvc postgresql-data-postgresql-replica-0 -n microservices
   
   # Restart replica (will trigger full resync)
   kubectl scale statefulset postgresql-replica -n microservices --replicas=1
   ```

## MongoDB Recovery

### Scenario 1: MongoDB Pod Failure

#### Detection
```bash
# Check MongoDB pods
kubectl get pods -n microservices -l app=mongodb

# Test connection
kubectl run mongo-test --image=mongo:5.0 -it --rm --restart=Never -n microservices -- \
  mongo --host mongodb.microservices --eval "db.adminCommand('hello')"
```

#### Recovery Steps
1. **Check Replica Set Status**
   ```bash
   kubectl exec -it mongodb-0 -n microservices -- \
     mongo --eval "rs.status()"
   ```

2. **Force Primary Election if Needed**
   ```bash
   kubectl exec -it mongodb-1 -n microservices -- \
     mongo --eval "rs.stepDown(60)"
   ```

3. **Add Failed Node Back to Replica Set**
   ```bash
   kubectl exec -it mongodb-0 -n microservices -- \
     mongo --eval "rs.add('mongodb-2.mongodb.microservices.svc.cluster.local:27017')"
   ```

### Scenario 2: MongoDB Data Corruption

#### Recovery Steps
1. **Stop All Application Connections**
   ```bash
   kubectl scale deployment api-gateway product-service -n microservices --replicas=0
   ```

2. **Restore from Backup**
   ```bash
   # List backups
   kubectl exec mongodb-0 -n microservices -- ls -la /backup/
   
   # Restore from specific backup
   kubectl exec -it mongodb-0 -n microservices -- \
     mongorestore --drop --host localhost:27017 /backup/mongodb-backup-20240101/
   ```

3. **Verify Data Integrity**
   ```bash
   kubectl exec -it mongodb-0 -n microservices -- \
     mongo --eval "db.runCommand({validate: 'products'})"
   ```

## Redis Recovery

### Scenario 1: Redis Pod Failure

#### Detection
```bash
# Check Redis pods
kubectl get pods -n microservices -l app=redis

# Test connection
kubectl run redis-test --image=redis:7 -it --rm --restart=Never -n microservices -- \
  redis-cli -h redis.microservices ping
```

#### Recovery Steps
1. **Check if Master/Slave Setup**
   ```bash
   kubectl exec -it redis-0 -n microservices -- redis-cli INFO replication
   ```

2. **Promote Slave to Master if Needed**
   ```bash
   kubectl exec -it redis-slave-0 -n microservices -- redis-cli SLAVEOF NO ONE
   
   # Update applications to point to new master
   kubectl patch configmap redis-config -n microservices \
     --patch '{"data":{"redis-host":"redis-slave-0.redis.microservices.svc.cluster.local"}}'
   ```

3. **Restore Data from RDB Backup**
   ```bash
   # Copy backup to pod
   kubectl cp redis-backup.rdb microservices/redis-0:/data/dump.rdb
   
   # Restart Redis to load backup
   kubectl delete pod redis-0 -n microservices
   ```

## Cross-Database Consistency Recovery

### Scenario: Distributed Transaction Failure

#### Detection
```bash
# Check for orphaned transactions
kubectl exec postgresql-0 -n microservices -- \
  psql -U postgres -c "SELECT * FROM pg_prepared_xacts;"

kubectl exec mongodb-0 -n microservices -- \
  mongo --eval "db.runCommand('currentOp')"
```

#### Recovery Steps
1. **Manual Transaction Rollback**
   ```bash
   # PostgreSQL
   kubectl exec postgresql-0 -n microservices -- \
     psql -U postgres -c "ROLLBACK PREPARED '[transaction_id]';"
   
   # MongoDB - abort running operations
   kubectl exec mongodb-0 -n microservices -- \
     mongo --eval "db.killOp([opid])"
   ```

2. **Data Consistency Check**
   ```bash
   # Run consistency verification script
   ./scripts/verify-data-consistency.sh
   ```

3. **Reconcile Inconsistencies**
   ```bash
   # Use application-specific reconciliation
   kubectl run data-reconcile --image=microservices/reconcile:latest \
     --restart=Never -n microservices -- reconcile-data --from-backup
   ```

## Automated Recovery Scripts

### PostgreSQL Auto-Recovery
```bash
#!/bin/bash
# postgres-auto-recovery.sh

set -e

NAMESPACE="microservices"
BACKUP_RETENTION="7d"

# Function to check PostgreSQL health
check_postgres_health() {
    kubectl run pg-health-check --image=postgres:13 -it --rm --restart=Never -n $NAMESPACE -- \
        psql -h postgresql.$NAMESPACE -U postgres -c "SELECT 1;" &> /dev/null
    return $?
}

# Function to restore from backup
restore_postgres() {
    echo "Starting PostgreSQL recovery..."
    
    # Scale down applications
    kubectl scale deployment --all -n $NAMESPACE --replicas=0
    
    # Find latest backup
    LATEST_BACKUP=$(velero backup get --output json | jq -r '.items[] | select(.metadata.labels.app == "postgresql") | .metadata.name' | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        echo "No PostgreSQL backup found"
        exit 1
    fi
    
    # Restore from backup
    velero restore create postgres-auto-recovery-$(date +%Y%m%d-%H%M%S) \
        --from-backup $LATEST_BACKUP \
        --wait
    
    # Wait for database to be ready
    kubectl wait --for=condition=ready pod -l app=postgresql -n $NAMESPACE --timeout=300s
    
    # Scale up applications
    kubectl scale deployment api-gateway -n $NAMESPACE --replicas=3
    kubectl scale deployment user-service -n $NAMESPACE --replicas=2
    kubectl scale deployment order-service -n $NAMESPACE --replicas=2
    
    echo "PostgreSQL recovery completed"
}

# Main logic
if ! check_postgres_health; then
    echo "PostgreSQL health check failed, initiating recovery..."
    restore_postgres
else
    echo "PostgreSQL is healthy"
fi
```

## Recovery Validation

### Health Check Script
```bash
#!/bin/bash
# validate-database-recovery.sh

NAMESPACE="microservices"
FAILED=0

# PostgreSQL validation
echo "Validating PostgreSQL..."
if kubectl exec postgresql-0 -n $NAMESPACE -- psql -U postgres -c "SELECT 1;" &> /dev/null; then
    echo "✅ PostgreSQL is accessible"
else
    echo "❌ PostgreSQL is not accessible"
    FAILED=1
fi

# MongoDB validation
echo "Validating MongoDB..."
if kubectl exec mongodb-0 -n $NAMESPACE -- mongo --eval "db.adminCommand('hello')" &> /dev/null; then
    echo "✅ MongoDB is accessible"
else
    echo "❌ MongoDB is not accessible"
    FAILED=1
fi

# Redis validation
echo "Validating Redis..."
if kubectl exec redis-0 -n $NAMESPACE -- redis-cli ping | grep -q PONG; then
    echo "✅ Redis is accessible"
else
    echo "❌ Redis is not accessible"
    FAILED=1
fi

# Data consistency check
echo "Checking data consistency..."
# Add application-specific consistency checks here

if [ $FAILED -eq 0 ]; then
    echo "✅ All databases recovered successfully"
    exit 0
else
    echo "❌ Database recovery validation failed"
    exit 1
fi
```

## Monitoring and Alerts

### Database Health Monitoring
- Set up alerts for database connection failures
- Monitor replication lag
- Track backup success/failure
- Alert on data inconsistencies

### Key Metrics to Track
- Database uptime
- Connection pool utilization
- Query performance
- Backup completion status
- Recovery time objectives (RTO)
- Recovery point objectives (RPO)