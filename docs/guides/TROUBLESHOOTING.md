# Troubleshooting Guide

## 🚨 Quick Reference

### Emergency Response Checklist
```bash
# 1. Check overall system health
kubectl get pods --all-namespaces | grep -v Running
docker ps --filter "status=exited"

# 2. Check recent deployments
kubectl get events --sort-by='.lastTimestamp' | head -20
argocd app list

# 3. Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# 4. Check logs for errors
kubectl logs -l app=api-gateway --tail=100 | grep ERROR
kubectl logs -l app=frontend --tail=100 | grep ERROR

# 5. Check service connectivity
kubectl exec -it deploy/api-gateway -- wget -qO- http://user-service:8000/health
kubectl exec -it deploy/api-gateway -- wget -qO- http://product-service:8080/health
```

## 🔍 Phase-by-Phase Troubleshooting

### Phase 1: Foundation Issues

#### Problem: Docker Build Failures
```bash
# Symptoms
ERROR: failed to solve: process "/bin/sh -c npm install" did not complete successfully

# Diagnosis
docker build --no-cache services/frontend/
docker system df  # Check disk space

# Solutions
# 1. Clean Docker system
docker system prune -af
docker volume prune -f

# 2. Check .dockerignore
cat services/frontend/.dockerignore
# Should contain: node_modules, .git, *.log

# 3. Multi-stage build optimization
# Ensure package.json is copied before source code
COPY package*.json ./
RUN npm ci --only=production
COPY . .
```

#### Problem: Service Communication Failures
```bash
# Symptoms
ECONNREFUSED connecting to user-service:8000
502 Bad Gateway from API Gateway

# Diagnosis
docker-compose ps
docker-compose logs api-gateway
docker-compose logs user-service

# Solutions
# 1. Check service names in docker-compose.yml match environment variables
# 2. Verify port mappings
# 3. Check health endpoints
curl http://localhost:8000/health
curl http://localhost:8080/health
```

#### Problem: GitHub Actions Build Failures
```bash
# Symptoms
Error: Process completed with exit code 1
npm ERR! Test failed

# Diagnosis
# Check workflow logs in GitHub Actions tab
# Look for specific error messages

# Solutions
# 1. Ensure tests pass locally
npm test -- --watchAll=false

# 2. Check environment differences
# Add debugging to workflow:
- name: Debug Environment
  run: |
    node --version
    npm --version
    ls -la

# 3. Cache issues
- name: Clear npm cache
  run: npm cache clean --force
```

### Phase 2: Security Issues

#### Problem: Security Scans Failing Pipeline
```bash
# Symptoms
✗ High severity vulnerabilities found
✗ Secrets detected in code
✗ Container scan failed

# Diagnosis
# Check specific security tool outputs
trivy image myapp:latest
semgrep --config=auto services/
bandit -r services/user-service/

# Solutions
# 1. Fix vulnerabilities
npm audit fix
pip install --upgrade package-name

# 2. Suppress false positives
# .trivyignore
CVE-2021-44228  # Not applicable - Go service

# 3. Remove secrets
git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch config.env'
```

#### Problem: Secret Management Issues
```bash
# Symptoms
Error: secret "vault-token" not found
Vault seal status: sealed

# Diagnosis
kubectl get secrets -n security
vault status

# Solutions
# 1. Unseal Vault
vault operator unseal <unseal-key>

# 2. Create missing secrets
kubectl create secret generic vault-token \
  --from-literal=token=<vault-token> \
  -n security

# 3. Check service account permissions
kubectl auth can-i get secrets --as=system:serviceaccount:security:vault-sa
```

### Phase 3: Kubernetes Issues

#### Problem: Pods Stuck in Pending State
```bash
# Symptoms
NAME                          READY   STATUS    RESTARTS   AGE
frontend-5d6b8c7f8d-xyz       0/1     Pending   0          5m

# Diagnosis
kubectl describe pod frontend-5d6b8c7f8d-xyz
kubectl get events --sort-by='.lastTimestamp'
kubectl top nodes

# Solutions
# 1. Resource constraints
kubectl patch deployment frontend -p '{"spec":{"template":{"spec":{"containers":[{"name":"frontend","resources":{"requests":{"memory":"64Mi","cpu":"50m"}}}]}}}}'

# 2. Node issues
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets

# 3. Persistent volume issues
kubectl get pv,pvc
kubectl describe pvc postgres-storage
```

#### Problem: Service Not Accessible
```bash
# Symptoms
curl: (7) Failed to connect to frontend:80: Connection refused
504 Gateway Timeout

# Diagnosis
kubectl get svc,endpoints
kubectl describe service frontend
kubectl logs -l app=frontend

# Solutions
# 1. Check service selector
kubectl get pods --show-labels
# Ensure service selector matches pod labels

# 2. Check port configuration
kubectl port-forward service/frontend 8080:80

# 3. Check ingress configuration
kubectl get ingress
kubectl describe ingress microservices-ingress
```

#### Problem: ArgoCD Sync Issues
```bash
# Symptoms
Application Status: OutOfSync
Last Sync: Failed

# Diagnosis
argocd app get microservices
argocd app diff microservices
kubectl logs deployment/argocd-application-controller -n argocd

# Solutions
# 1. Manual sync
argocd app sync microservices

# 2. Fix manifest issues
kubectl apply --dry-run=client -f infrastructure/kubernetes/

# 3. Refresh repository
argocd app refresh microservices
argocd repo get https://github.com/your-org/microservices-config
```

### Phase 4: Advanced Deployment Issues

#### Problem: Blue-Green Deployment Stuck
```bash
# Symptoms
Blue environment still receiving traffic
Green environment not ready

# Diagnosis
kubectl get pods -l version=blue
kubectl get pods -l version=green
kubectl describe service microservices

# Solutions
# 1. Check readiness probes
kubectl describe pod -l version=green
kubectl logs -l version=green

# 2. Manual traffic switch
kubectl patch service microservices -p '{"spec":{"selector":{"version":"green"}}}'

# 3. Rollback if needed
kubectl patch service microservices -p '{"spec":{"selector":{"version":"blue"}}}'
```

#### Problem: Canary Deployment Not Progressing
```bash
# Symptoms
Canary weight stuck at 10%
Error rate above threshold

# Diagnosis
kubectl get canary microservices
kubectl describe canary microservices
kubectl logs -n flagger deploy/flagger

# Solutions
# 1. Check metrics
kubectl logs -l app=microservices | grep ERROR
curl -s http://prometheus:9090/api/v1/query?query=rate(http_requests_total[5m])

# 2. Adjust canary configuration
kubectl patch canary microservices --type merge -p '{"spec":{"canaryAnalysis":{"threshold":10}}}'

# 3. Manual promotion
kubectl patch canary microservices --type merge -p '{"spec":{"skipAnalysis":true}}'
```

### Phase 5: Observability Issues

#### Problem: Prometheus Not Scraping Metrics
```bash
# Symptoms
No metrics appearing in Grafana
Prometheus targets showing as down

# Diagnosis
kubectl port-forward svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Solutions
# 1. Check service monitor
kubectl get servicemonitor
kubectl describe servicemonitor microservices

# 2. Verify metrics endpoints
kubectl exec -it deploy/api-gateway -- curl localhost:8080/metrics

# 3. Check prometheus config
kubectl get configmap prometheus-config -o yaml
```

#### Problem: Logs Not Appearing in Elasticsearch
```bash
# Symptoms
No logs in Kibana
Fluentd pods crashing

# Diagnosis
kubectl logs daemonset/fluentd -n logging
kubectl get pods -n logging

# Solutions
# 1. Check fluentd configuration
kubectl describe configmap fluentd-config

# 2. Verify elasticsearch connection
kubectl exec -it deploy/fluentd -- curl elasticsearch:9200/_cluster/health

# 3. Check log format
kubectl logs deploy/api-gateway --tail=10
```

#### Problem: Distributed Tracing Not Working
```bash
# Symptoms
No traces in Jaeger UI
Services not connected in service map

# Diagnosis
kubectl port-forward svc/jaeger-query 16686:16686
kubectl logs deploy/jaeger-collector

# Solutions
# 1. Check instrumentation
# Verify OpenTelemetry/Jaeger client in applications

# 2. Check agent configuration
kubectl get daemonset jaeger-agent
kubectl logs daemonset/jaeger-agent

# 3. Verify sampling rate
# Update application config to increase sampling rate
```

## 🔧 Database Troubleshooting

### PostgreSQL Issues
```bash
# Connection problems
kubectl exec -it statefulset/postgres -- psql -U postgres -d microservices -c "\l"

# Performance issues
kubectl exec -it statefulset/postgres -- psql -U postgres -d microservices -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC LIMIT 10;"

# Storage issues
kubectl exec -it statefulset/postgres -- df -h
kubectl get pvc postgres-storage
```

### Redis Issues
```bash
# Connection problems
kubectl exec -it deploy/redis -- redis-cli ping

# Memory issues
kubectl exec -it deploy/redis -- redis-cli info memory

# Key analysis
kubectl exec -it deploy/redis -- redis-cli --bigkeys
```

### MongoDB Issues
```bash
# Connection problems
kubectl exec -it statefulset/mongodb -- mongosh --eval "db.adminCommand('ping')"

# Performance monitoring
kubectl exec -it statefulset/mongodb -- mongosh --eval "db.runCommand({serverStatus: 1})"

# Collection stats
kubectl exec -it statefulset/mongodb -- mongosh --eval "db.products.stats()"
```

## 🌐 Network Troubleshooting

### DNS Resolution Issues
```bash
# Test DNS within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test service discovery
kubectl exec -it deploy/api-gateway -- nslookup user-service.microservices.svc.cluster.local
```

### Network Policy Issues
```bash
# Test connectivity
kubectl exec -it deploy/frontend -- wget -qO- --timeout=5 http://api-gateway:8080/health

# Check network policies
kubectl get networkpolicy
kubectl describe networkpolicy microservices-network-policy

# Debug network policy
kubectl exec -it deploy/frontend -- nc -zv api-gateway 8080
```

### Ingress Issues
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller

# Test ingress rules
kubectl get ingress
kubectl describe ingress microservices-ingress

# Check SSL/TLS
openssl s_client -connect microservices.example.com:443 -servername microservices.example.com
```

## 📊 Performance Troubleshooting

### High Memory Usage
```bash
# Identify memory-hungry pods
kubectl top pods --all-namespaces --sort-by=memory

# Check resource limits
kubectl describe pod <pod-name> | grep -A 5 Limits

# Get detailed resource usage
kubectl exec -it <pod-name> -- ps aux | head -10
kubectl exec -it <pod-name> -- free -h
```

### High CPU Usage
```bash
# Identify CPU-hungry pods
kubectl top pods --all-namespaces --sort-by=cpu

# Check for CPU throttling
kubectl describe pod <pod-name> | grep -i throttl

# Profile application
kubectl exec -it <pod-name> -- top
kubectl logs <pod-name> | grep -i performance
```

### Storage Issues
```bash
# Check disk usage
kubectl exec -it <pod-name> -- df -h

# Check persistent volumes
kubectl get pv,pvc
kubectl describe pv <pv-name>

# Check storage classes
kubectl get storageclass
kubectl describe storageclass standard
```

## 🔄 CI/CD Troubleshooting

### GitHub Actions Issues
```bash
# Workflow not triggering
# Check webhook in repository settings
# Verify branch protection rules
# Check workflow file syntax

# Build failures
# Check runner logs
# Verify secrets are set
# Test locally with act: act -j test

# Deployment failures
# Check kubeconfig in secrets
# Verify RBAC permissions
# Test kubectl commands locally
```

### ArgoCD Issues
```bash
# Application not syncing
argocd login <argocd-server>
argocd app get <app-name>
argocd app sync <app-name> --dry-run

# Repository connection issues
argocd repo list
argocd repo get <repo-url>
argocd account get-user-info

# RBAC issues
kubectl get rolebinding,clusterrolebinding | grep argocd
kubectl auth can-i create pods --as=system:serviceaccount:argocd:argocd-server
```

## 🚨 Incident Response Procedures

### Critical Service Down
1. **Immediate Response (0-5 minutes)**
   ```bash
   # Check service status
   kubectl get pods -l app=<service>
   kubectl logs -l app=<service> --tail=50
   
   # Quick restart if needed
   kubectl rollout restart deployment/<service>
   ```

2. **Investigation (5-15 minutes)**
   ```bash
   # Check recent changes
   kubectl rollout history deployment/<service>
   argocd app history <app-name>
   
   # Check dependencies
   kubectl exec -it deploy/<service> -- wget -qO- http://dependency-service/health
   ```

3. **Resolution (15-30 minutes)**
   ```bash
   # Rollback if needed
   kubectl rollout undo deployment/<service>
   argocd app rollback <app-name> <revision>
   
   # Scale up if performance issue
   kubectl scale deployment <service> --replicas=5
   ```

### Database Issues
1. **Check connectivity**
   ```bash
   kubectl exec -it deploy/api-gateway -- nc -zv postgres 5432
   ```

2. **Check database health**
   ```bash
   kubectl exec -it statefulset/postgres -- psql -U postgres -c "SELECT 1"
   ```

3. **Backup and restore if needed**
   ```bash
   kubectl exec -it statefulset/postgres -- pg_dump -U postgres microservices > backup.sql
   ```

### Security Incidents
1. **Isolate affected services**
   ```bash
   kubectl scale deployment <compromised-service> --replicas=0
   kubectl patch networkpolicy <policy> -p '{"spec":{"ingress":[]}}'
   ```

2. **Collect evidence**
   ```bash
   kubectl logs <pod> --previous > incident-logs.txt
   kubectl describe pod <pod> > pod-details.txt
   ```

3. **Rotate secrets**
   ```bash
   kubectl delete secret <secret-name>
   kubectl create secret generic <secret-name> --from-literal=key=new-value
   kubectl rollout restart deployment/<service>
   ```

## 📋 Health Check Scripts

### Overall System Health
```bash
#!/bin/bash
# scripts/health-check.sh

echo "=== Kubernetes Cluster Health ==="
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

echo "=== Service Health ==="
services=("frontend" "api-gateway" "user-service" "product-service" "order-service")
for service in "${services[@]}"; do
  status=$(kubectl exec -it deploy/$service -- wget -qO- --timeout=5 http://localhost/health 2>/dev/null | jq -r .status 2>/dev/null || echo "failed")
  echo "$service: $status"
done

echo "=== Database Health ==="
kubectl exec -it statefulset/postgres -- psql -U postgres -c "SELECT 1" >/dev/null 2>&1 && echo "PostgreSQL: healthy" || echo "PostgreSQL: unhealthy"
kubectl exec -it deploy/redis -- redis-cli ping >/dev/null 2>&1 && echo "Redis: healthy" || echo "Redis: unhealthy"

echo "=== Resource Usage ==="
kubectl top nodes
kubectl top pods -n microservices
```

### Performance Check
```bash
#!/bin/bash
# scripts/performance-check.sh

echo "=== Response Time Check ==="
services=("http://localhost:3000" "http://localhost:8080/health")
for url in "${services[@]}"; do
  response_time=$(curl -w "%{time_total}" -s -o /dev/null "$url" 2>/dev/null || echo "failed")
  echo "$url: ${response_time}s"
done

echo "=== Error Rate Check ==="
kubectl logs -l app=api-gateway --since=1h | grep ERROR | wc -l | xargs echo "API Gateway errors in last hour:"
kubectl logs -l app=user-service --since=1h | grep ERROR | wc -l | xargs echo "User Service errors in last hour:"
```

## 📖 Debugging Best Practices

### 1. Systematic Approach
- Start with the error message
- Check recent changes
- Verify configuration
- Test dependencies
- Isolate the problem
- Apply minimal fix
- Verify resolution

### 2. Information Gathering
```bash
# Always collect these for debugging
kubectl get all -n <namespace>
kubectl describe <resource-type> <resource-name>
kubectl logs <pod-name> --previous
kubectl get events --sort-by='.lastTimestamp'
kubectl top pods
```

### 3. Common Commands
```bash
# Port forwarding for local testing
kubectl port-forward svc/<service-name> <local-port>:<remote-port>

# Execute commands in pods
kubectl exec -it deploy/<deployment-name> -- /bin/bash

# Copy files from/to pods
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file

# Watch resource changes
kubectl get pods -w
kubectl get events -w
```

### 4. Documentation
- Always document the problem and solution
- Update runbooks with new issues
- Share knowledge with team
- Create preventive measures

Remember: The best debugging approach is prevention through good monitoring, logging, and testing practices!

## 🆘 Emergency Contacts

### On-Call Procedures
1. **Severity 1 (Critical)**: Service completely down
   - Response time: 15 minutes
   - Escalation: Team lead after 30 minutes

2. **Severity 2 (High)**: Degraded performance
   - Response time: 1 hour
   - Escalation: Next business day

3. **Severity 3 (Medium)**: Minor issues
   - Response time: Next business day
   - Escalation: Weekly review

### Communication Channels
- **Slack**: #microservices-alerts
- **PagerDuty**: Microservices team
- **Email**: microservices-oncall@company.com
- **Documentation**: Internal wiki and runbooks