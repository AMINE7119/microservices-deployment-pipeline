# Chaos Engineering Incident Response Runbook

## Overview
This runbook provides step-by-step procedures for responding to incidents during chaos engineering experiments.

## Severity Levels

### P0 - Critical (Complete System Failure)
- **SLA**: 5 minutes response, 15 minutes resolution
- **Escalation**: Immediate pager duty alert
- **Actions**: Stop all chaos experiments, initiate disaster recovery

### P1 - High (Service Degradation)
- **SLA**: 15 minutes response, 1 hour resolution  
- **Escalation**: On-call engineer notification
- **Actions**: Assess impact, stop related experiments

### P2 - Medium (Performance Issues)
- **SLA**: 1 hour response, 4 hours resolution
- **Escalation**: Slack notification
- **Actions**: Monitor and adjust experiments

### P3 - Low (Minor Issues)
- **SLA**: 4 hours response, 24 hours resolution
- **Escalation**: Email notification
- **Actions**: Document for analysis

## Common Incident Scenarios

### 1. Service Completely Down

#### Symptoms
- All health checks failing
- 100% error rate
- No response from service endpoints

#### Immediate Actions (< 5 minutes)
1. **Stop All Chaos Experiments**
   ```bash
   kubectl delete podchaos --all -n chaos-mesh
   kubectl delete networkchaos --all -n chaos-mesh
   kubectl delete stresschaos --all -n chaos-mesh
   kubectl delete iochaos --all -n chaos-mesh
   kubectl delete timechaos --all -n chaos-mesh
   ```

2. **Check Cluster Status**
   ```bash
   kubectl get nodes
   kubectl get pods -n microservices --sort-by='.status.phase'
   kubectl get events -n microservices --sort-by='.lastTimestamp'
   ```

3. **Initiate Emergency Restore**
   ```bash
   cd chaos-engineering/disaster-recovery/restore
   ./restore-automation.sh
   ```

#### Investigation Steps
1. Check Grafana dashboards for timeline of events
2. Review chaos experiment logs
3. Analyze Kubernetes events
4. Check resource utilization patterns

### 2. High Error Rate (>10%)

#### Symptoms
- Error rate above normal thresholds
- Increased response times
- User complaints

#### Immediate Actions (< 15 minutes)
1. **Identify Active Experiments**
   ```bash
   kubectl get podchaos,networkchaos,stresschaos -n chaos-mesh
   ```

2. **Scale Up Resources**
   ```bash
   kubectl scale deployment api-gateway -n microservices --replicas=5
   kubectl scale deployment user-service -n microservices --replicas=3
   kubectl scale deployment product-service -n microservices --replicas=3
   kubectl scale deployment order-service -n microservices --replicas=3
   ```

3. **Check Circuit Breakers**
   ```bash
   # Check if circuit breakers are open
   curl -s http://api-gateway.microservices:8080/actuator/circuitbreakers
   ```

### 3. Memory/CPU Resource Exhaustion

#### Symptoms
- OOMKilled pods
- CPU throttling
- Slow response times

#### Immediate Actions
1. **Stop Resource Stress Experiments**
   ```bash
   kubectl delete stresschaos --all -n chaos-mesh
   ```

2. **Increase Resource Limits**
   ```bash
   kubectl patch deployment api-gateway -n microservices -p='{"spec":{"template":{"spec":{"containers":[{"name":"api-gateway","resources":{"limits":{"memory":"2Gi","cpu":"1"}}}]}}}}'
   ```

3. **Restart Affected Pods**
   ```bash
   kubectl delete pods -l app=api-gateway -n microservices
   ```

### 4. Network Partition/Connectivity Issues

#### Symptoms
- Intermittent failures
- Timeout errors
- Split-brain scenarios

#### Immediate Actions
1. **Stop Network Chaos**
   ```bash
   kubectl delete networkchaos --all -n chaos-mesh
   ```

2. **Check DNS Resolution**
   ```bash
   kubectl run debug --image=busybox -it --rm -- nslookup api-gateway.microservices
   ```

3. **Verify Service Mesh**
   ```bash
   # If using Istio
   kubectl get virtualservices,destinationrules -n microservices
   ```

## Recovery Procedures

### Automated Recovery
1. **Health Check Based Recovery**
   - Monitor service health endpoints
   - Automatic scaling based on failure detection
   - Circuit breaker activation

2. **Prometheus Alert Based Recovery**
   - Automated experiment termination on critical alerts
   - Resource scaling triggers
   - Failover to secondary regions

### Manual Recovery Steps

1. **Assessment Phase (5 minutes)**
   ```bash
   # Quick cluster health check
   ./scripts/health-check.sh
   
   # Check ongoing experiments
   kubectl get chaosengine -A
   kubectl get workflow -n litmus
   ```

2. **Stabilization Phase (10 minutes)**
   ```bash
   # Stop all chaos
   ./scripts/stop-all-chaos.sh
   
   # Scale services to safe levels
   ./scripts/emergency-scale.sh
   ```

3. **Recovery Phase (15 minutes)**
   ```bash
   # Restore from backup if needed
   cd disaster-recovery/restore
   ./restore-automation.sh [BACKUP_NAME]
   
   # Validate recovery
   ./scripts/validate-recovery.sh
   ```

## Communication Templates

### Internal Notification
```
🚨 CHAOS INCIDENT - P[SEVERITY]

Incident: [Brief description]
Services Affected: [List services]
Start Time: [Timestamp]
Current Status: [Investigating/Mitigating/Resolved]
ETA: [Expected resolution time]

Actions Taken:
- [Action 1]
- [Action 2]

Next Update: [Time]
```

### Stakeholder Update
```
Subject: Service Impact Notification - [Brief Description]

We are experiencing [brief description of impact] affecting [services].

What happened: [Explanation suitable for business audience]
Impact: [User-facing impact description]
Current status: [What we're doing]
Expected resolution: [Timeline]

We will provide updates every [frequency].
```

## Post-Incident Procedures

### 1. Immediate Cleanup
- Stop all chaos experiments
- Restore normal resource levels
- Clear temporary configurations

### 2. Data Collection
- Export Grafana dashboards for incident timeline
- Collect application logs
- Save Kubernetes events
- Document experiment configurations

### 3. Root Cause Analysis
- Timeline reconstruction
- Experiment impact assessment
- System behavior analysis
- Improvement identification

### 4. Report Generation
```bash
# Generate incident report
./scripts/generate-incident-report.sh --incident-id [ID] --start-time [TIME] --end-time [TIME]
```

## Prevention Strategies

### Pre-Chaos Checks
- Validate system health baseline
- Ensure backup completion
- Check resource availability
- Verify monitoring systems

### Experiment Design
- Start with low-impact experiments
- Implement blast radius limits
- Use canary deployments for chaos
- Set experiment duration limits

### Safety Mechanisms
- Automated experiment termination
- Circuit breaker integration
- Rate limiting on experiments
- Multi-region failover

## Emergency Contacts

| Role | Primary | Secondary | Escalation Path |
|------|---------|-----------|-----------------|
| On-Call Engineer | [Contact] | [Contact] | Team Lead |
| Team Lead | [Contact] | [Contact] | Engineering Manager |
| SRE Team | [Contact] | [Contact] | SRE Manager |
| Engineering Manager | [Contact] | [Contact] | CTO |

## Tools and Resources

### Monitoring
- Grafana: http://grafana.monitoring:3000
- Prometheus: http://prometheus.monitoring:9090
- Chaos Mesh Dashboard: http://chaos-dashboard.chaos-mesh:2333
- Litmus Portal: http://litmus-frontend.litmus:9091

### Documentation
- Runbooks: `/chaos-engineering/runbooks/`
- Architecture Diagrams: `/docs/architecture/`
- API Documentation: `/docs/api/`

### Scripts
- Emergency Scripts: `/chaos-engineering/scripts/emergency/`
- Recovery Scripts: `/chaos-engineering/disaster-recovery/`
- Validation Scripts: `/chaos-engineering/scripts/validation/`