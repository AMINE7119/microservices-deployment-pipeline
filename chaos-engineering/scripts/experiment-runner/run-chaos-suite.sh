#!/bin/bash

# Automated Chaos Experiment Suite Runner
set -e

# Configuration
NAMESPACE="microservices"
CHAOS_NAMESPACE="chaos-mesh"
LITMUS_NAMESPACE="litmus"
REPORT_DIR="./chaos-reports"
EXPERIMENT_TIMEOUT=600

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Create report directory
mkdir -p $REPORT_DIR

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi
    
    # Check Chaos Mesh
    if ! kubectl get ns $CHAOS_NAMESPACE &> /dev/null; then
        log_error "Chaos Mesh namespace not found"
        exit 1
    fi
    
    # Check Litmus
    if ! kubectl get ns $LITMUS_NAMESPACE &> /dev/null; then
        log_warn "Litmus namespace not found, some experiments will be skipped"
    fi
    
    # Check target namespace
    if ! kubectl get ns $NAMESPACE &> /dev/null; then
        log_error "Target namespace $NAMESPACE not found"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Function to create pre-chaos snapshot
create_snapshot() {
    log_info "Creating pre-chaos snapshot..."
    
    # Get current state
    kubectl get all -n $NAMESPACE -o yaml > $REPORT_DIR/pre-chaos-state.yaml
    
    # Get metrics
    if kubectl get service prometheus -n monitoring &> /dev/null; then
        curl -s http://prometheus.monitoring:9090/api/v1/query?query=up | jq > $REPORT_DIR/pre-chaos-metrics.json
    fi
    
    log_info "Snapshot created"
}

# Function to run Chaos Mesh experiments
run_chaos_mesh_experiments() {
    log_test "Running Chaos Mesh experiments..."
    
    local experiments=(
        "pod-failure"
        "network-delay"
        "cpu-stress"
        "memory-stress"
        "io-delay"
    )
    
    for experiment in "${experiments[@]}"; do
        log_test "Running $experiment experiment..."
        
        case $experiment in
            "pod-failure")
                cat <<EOF | kubectl apply -f -
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: test-pod-failure
  namespace: $CHAOS_NAMESPACE
spec:
  action: pod-failure
  mode: random-max-percent
  value: "30"
  duration: "60s"
  selector:
    namespaces:
      - $NAMESPACE
    labelSelectors:
      "tier": "application"
EOF
                ;;
            
            "network-delay")
                cat <<EOF | kubectl apply -f -
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: test-network-delay
  namespace: $CHAOS_NAMESPACE
spec:
  action: delay
  mode: all
  selector:
    namespaces:
      - $NAMESPACE
  delay:
    latency: "100ms"
    jitter: "10ms"
  duration: "60s"
EOF
                ;;
            
            "cpu-stress")
                cat <<EOF | kubectl apply -f -
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: test-cpu-stress
  namespace: $CHAOS_NAMESPACE
spec:
  mode: random-max-percent
  value: "50"
  selector:
    namespaces:
      - $NAMESPACE
  stressors:
    cpu:
      workers: 2
      load: 70
  duration: "60s"
EOF
                ;;
            
            "memory-stress")
                cat <<EOF | kubectl apply -f -
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: test-memory-stress
  namespace: $CHAOS_NAMESPACE
spec:
  mode: all
  selector:
    namespaces:
      - $NAMESPACE
  stressors:
    memory:
      workers: 1
      size: "256MB"
  duration: "60s"
EOF
                ;;
            
            "io-delay")
                cat <<EOF | kubectl apply -f -
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: test-io-delay
  namespace: $CHAOS_NAMESPACE
spec:
  action: latency
  mode: all
  selector:
    namespaces:
      - $NAMESPACE
  volumePath: /data
  path: "/data/*"
  delay: "50ms"
  percent: 50
  duration: "60s"
EOF
                ;;
        esac
        
        # Wait for experiment to complete
        sleep 70
        
        # Collect metrics during chaos
        collect_chaos_metrics $experiment
        
        # Clean up experiment
        kubectl delete ${experiment%%-*}chaos test-$experiment -n $CHAOS_NAMESPACE || true
        
        # Recovery time
        sleep 30
        
        # Verify recovery
        verify_recovery $experiment
    done
    
    log_info "Chaos Mesh experiments completed"
}

# Function to collect metrics during chaos
collect_chaos_metrics() {
    local experiment=$1
    log_info "Collecting metrics for $experiment..."
    
    # Get pod status
    kubectl get pods -n $NAMESPACE -o wide > $REPORT_DIR/${experiment}-pods.txt
    
    # Get events
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' > $REPORT_DIR/${experiment}-events.txt
    
    # Get metrics if Prometheus is available
    if kubectl get service prometheus -n monitoring &> /dev/null; then
        # Error rate
        curl -s "http://prometheus.monitoring:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[1m])" | \
            jq > $REPORT_DIR/${experiment}-error-rate.json
        
        # Response time
        curl -s "http://prometheus.monitoring:9090/api/v1/query?query=histogram_quantile(0.99,rate(http_request_duration_seconds_bucket[1m]))" | \
            jq > $REPORT_DIR/${experiment}-response-time.json
        
        # Resource usage
        curl -s "http://prometheus.monitoring:9090/api/v1/query?query=container_memory_usage_bytes" | \
            jq > $REPORT_DIR/${experiment}-memory.json
    fi
}

# Function to verify recovery
verify_recovery() {
    local experiment=$1
    log_info "Verifying recovery from $experiment..."
    
    local recovery_start=$(date +%s)
    local max_recovery_time=300  # 5 minutes
    local all_healthy=false
    
    while [ $(($(date +%s) - recovery_start)) -lt $max_recovery_time ]; do
        # Check if all pods are running
        local not_running=$(kubectl get pods -n $NAMESPACE --no-headers | grep -v "Running" | wc -l)
        
        if [ "$not_running" -eq 0 ]; then
            all_healthy=true
            break
        fi
        
        sleep 10
    done
    
    local recovery_time=$(($(date +%s) - recovery_start))
    
    if [ "$all_healthy" = true ]; then
        log_info "Recovery successful in ${recovery_time}s"
        echo "{\"experiment\": \"$experiment\", \"recovery_time\": $recovery_time, \"status\": \"success\"}" >> $REPORT_DIR/recovery-times.jsonl
    else
        log_error "Recovery failed for $experiment"
        echo "{\"experiment\": \"$experiment\", \"recovery_time\": $recovery_time, \"status\": \"failed\"}" >> $REPORT_DIR/recovery-times.jsonl
    fi
}

# Function to run health checks
run_health_checks() {
    log_info "Running health checks..."
    
    local services=("api-gateway" "user-service" "product-service" "order-service" "frontend")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if kubectl get service $service -n $NAMESPACE &> /dev/null; then
            # Try to get service endpoint
            local endpoint=$(kubectl get service $service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
            local port=$(kubectl get service $service -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
            
            # Create a test pod to check connectivity
            kubectl run health-check-$service --image=curlimages/curl:latest \
                --rm -i --restart=Never -n $NAMESPACE -- \
                curl -s -o /dev/null -w "%{http_code}" http://$endpoint:$port/health &> /dev/null || true
            
            local status=$?
            if [ $status -eq 0 ]; then
                log_info "$service is healthy"
            else
                log_warn "$service health check failed"
                all_healthy=false
            fi
        fi
    done
    
    if [ "$all_healthy" = true ]; then
        log_info "All services are healthy"
        return 0
    else
        log_warn "Some services are unhealthy"
        return 1
    fi
}

# Function to generate report
generate_report() {
    log_info "Generating chaos test report..."
    
    cat > $REPORT_DIR/chaos-test-report.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Chaos Engineering Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .success { color: green; }
        .failure { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .metric { font-family: monospace; }
    </style>
</head>
<body>
    <h1>Chaos Engineering Test Report</h1>
    <p>Generated: $(date)</p>
    
    <h2>Test Summary</h2>
    <table>
        <tr>
            <th>Namespace</th>
            <td>$NAMESPACE</td>
        </tr>
        <tr>
            <th>Chaos Framework</th>
            <td>Chaos Mesh + Litmus</td>
        </tr>
        <tr>
            <th>Test Duration</th>
            <td>$(date -d@$(($(date +%s) - START_TIME)) -u +%H:%M:%S)</td>
        </tr>
    </table>
    
    <h2>Experiment Results</h2>
    <table>
        <tr>
            <th>Experiment</th>
            <th>Recovery Time</th>
            <th>Status</th>
        </tr>
EOF
    
    # Add recovery times to report
    if [ -f $REPORT_DIR/recovery-times.jsonl ]; then
        while IFS= read -r line; do
            experiment=$(echo $line | jq -r '.experiment')
            recovery_time=$(echo $line | jq -r '.recovery_time')
            status=$(echo $line | jq -r '.status')
            
            if [ "$status" == "success" ]; then
                status_class="success"
            else
                status_class="failure"
            fi
            
            cat >> $REPORT_DIR/chaos-test-report.html <<EOF
        <tr>
            <td>$experiment</td>
            <td>${recovery_time}s</td>
            <td class="$status_class">$status</td>
        </tr>
EOF
        done < $REPORT_DIR/recovery-times.jsonl
    fi
    
    cat >> $REPORT_DIR/chaos-test-report.html <<EOF
    </table>
    
    <h2>Recommendations</h2>
    <ul>
        <li>Review experiments with recovery time > 60s</li>
        <li>Investigate any failed recoveries</li>
        <li>Consider implementing circuit breakers for network issues</li>
        <li>Improve auto-scaling policies based on stress test results</li>
    </ul>
</body>
</html>
EOF
    
    log_info "Report generated: $REPORT_DIR/chaos-test-report.html"
}

# Main execution
main() {
    START_TIME=$(date +%s)
    
    log_info "Starting chaos engineering test suite..."
    
    # Check prerequisites
    check_prerequisites
    
    # Create snapshot
    create_snapshot
    
    # Run initial health checks
    log_info "Running initial health checks..."
    run_health_checks
    
    # Run Chaos Mesh experiments
    run_chaos_mesh_experiments
    
    # Final health checks
    log_info "Running final health checks..."
    run_health_checks
    
    # Generate report
    generate_report
    
    log_info "Chaos engineering test suite completed"
    log_info "Reports available in: $REPORT_DIR"
}

# Run main function
main "$@"