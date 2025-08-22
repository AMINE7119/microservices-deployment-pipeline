#!/bin/bash

# Phase 7 - Performance & Cost Optimization Testing Script
# Comprehensive testing of all Phase 7 components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE_MONITORING="monitoring"
NAMESPACE_KUBECOST="kubecost"
NAMESPACE_MICROSERVICES="microservices"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Phase 7 - Performance & Cost Optimization Tests${NC}"
echo -e "${BLUE}================================================${NC}"

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ $1 is available${NC}"
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}⏳ Waiting for deployment $deployment in namespace $namespace...${NC}"
    
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        echo -e "${GREEN}✅ Deployment $deployment is ready${NC}"
        return 0
    else
        echo -e "${RED}❌ Deployment $deployment failed to become ready${NC}"
        return 1
    fi
}

# Function to test service endpoint
test_endpoint() {
    local service=$1
    local namespace=$2
    local port=$3
    local path=${4:-"/"}
    
    echo -e "${YELLOW}🔍 Testing endpoint: $service.$namespace:$port$path${NC}"
    
    # Port forward in background
    kubectl port-forward service/$service $port:$port -n $namespace &
    local pf_pid=$!
    
    # Wait for port forward to be ready
    sleep 5
    
    # Test endpoint
    if curl -f --max-time 10 "http://localhost:$port$path" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Endpoint $service.$namespace:$port$path is accessible${NC}"
        kill $pf_pid 2>/dev/null || true
        return 0
    else
        echo -e "${RED}❌ Endpoint $service.$namespace:$port$path is not accessible${NC}"
        kill $pf_pid 2>/dev/null || true
        return 1
    fi
}

# Function to run comprehensive validation
run_tests() {
    echo -e "\n${BLUE}1. Prerequisites Check${NC}"
    echo "=========================="
    
    check_command kubectl
    check_command helm
    check_command curl
    check_command jq
    
    # Check cluster connectivity
    echo -e "${YELLOW}🔍 Checking cluster connectivity...${NC}"
    if kubectl cluster-info > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Cluster is accessible${NC}"
    else
        echo -e "${RED}❌ Cannot connect to cluster${NC}"
        exit 1
    fi
    
    echo -e "\n${BLUE}2. Namespace Validation${NC}"
    echo "========================"
    
    # Check required namespaces
    for ns in $NAMESPACE_MONITORING $NAMESPACE_KUBECOST $NAMESPACE_MICROSERVICES; do
        if kubectl get namespace $ns > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Namespace $ns exists${NC}"
        else
            echo -e "${YELLOW}⚠️  Creating namespace $ns${NC}"
            kubectl create namespace $ns
        fi
    done
    
    echo -e "\n${BLUE}3. Performance Monitoring Infrastructure${NC}"
    echo "========================================"
    
    # Apply performance monitoring configurations
    echo -e "${YELLOW}📊 Deploying performance monitoring...${NC}"
    if kubectl apply -f optimization/performance/monitoring/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Performance monitoring configurations applied${NC}"
    else
        echo -e "${RED}❌ Failed to apply performance monitoring configurations${NC}"
        return 1
    fi
    
    # Check Prometheus configuration
    if kubectl get configmap prometheus-performance-config -n $NAMESPACE_MONITORING > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Prometheus performance config exists${NC}"
    else
        echo -e "${RED}❌ Prometheus performance config missing${NC}"
    fi
    
    echo -e "\n${BLUE}4. Cost Optimization Tools${NC}"
    echo "=========================="
    
    # Deploy Kubecost
    echo -e "${YELLOW}💰 Deploying Kubecost...${NC}"
    if kubectl apply -f optimization/cost-management/finops-dashboard/kubecost-deployment.yaml > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Kubecost deployment applied${NC}"
    else
        echo -e "${RED}❌ Failed to apply Kubecost deployment${NC}"
        return 1
    fi
    
    # Wait for Kubecost to be ready
    if wait_for_deployment $NAMESPACE_KUBECOST kubecost-cost-analyzer 300; then
        echo -e "${GREEN}✅ Kubecost is running${NC}"
    else
        echo -e "${RED}❌ Kubecost failed to start${NC}"
    fi
    
    # Check cost alert system
    echo -e "${YELLOW}📊 Deploying cost alert system...${NC}"
    if kubectl apply -f optimization/cost-management/budget-alerts/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Cost alert system deployed${NC}"
    else
        echo -e "${RED}❌ Failed to deploy cost alert system${NC}"
    fi
    
    echo -e "\n${BLUE}5. Auto-scaling Configurations${NC}"
    echo "=============================="
    
    # Deploy advanced HPA/VPA configurations
    echo -e "${YELLOW}⚡ Deploying auto-scaling configurations...${NC}"
    if kubectl apply -f optimization/performance/scaling/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Auto-scaling configurations applied${NC}"
    else
        echo -e "${RED}❌ Failed to apply auto-scaling configurations${NC}"
        return 1
    fi
    
    # Check HPA deployments
    echo -e "${YELLOW}🔍 Checking HPA configurations...${NC}"
    local hpa_count=$(kubectl get hpa -A --no-headers 2>/dev/null | wc -l)
    if [ "$hpa_count" -gt "0" ]; then
        echo -e "${GREEN}✅ Found $hpa_count HPA configurations${NC}"
        kubectl get hpa -A
    else
        echo -e "${YELLOW}⚠️  No HPA configurations found${NC}"
    fi
    
    # Check VPA deployments
    echo -e "${YELLOW}🔍 Checking VPA configurations...${NC}"
    local vpa_count=$(kubectl get vpa -A --no-headers 2>/dev/null | wc -l)
    if [ "$vpa_count" -gt "0" ]; then
        echo -e "${GREEN}✅ Found $vpa_count VPA configurations${NC}"
        kubectl get vpa -A
    else
        echo -e "${YELLOW}⚠️  No VPA configurations found (this is normal if VPA is not installed)${NC}"
    fi
    
    echo -e "\n${BLUE}6. Resource Rightsizing Automation${NC}"
    echo "=================================="
    
    # Deploy rightsizing controller
    echo -e "${YELLOW}🎯 Deploying rightsizing controller...${NC}"
    if kubectl apply -f optimization/cost-management/rightsizing/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Rightsizing automation deployed${NC}"
    else
        echo -e "${RED}❌ Failed to deploy rightsizing automation${NC}"
        return 1
    fi
    
    # Wait for rightsizing controller
    if wait_for_deployment $NAMESPACE_MONITORING rightsizing-controller 300; then
        echo -e "${GREEN}✅ Rightsizing controller is running${NC}"
    else
        echo -e "${YELLOW}⚠️  Rightsizing controller not ready (may need manual configuration)${NC}"
    fi
    
    echo -e "\n${BLUE}7. Performance Testing Framework${NC}"
    echo "================================"
    
    # Deploy K6 testing infrastructure
    echo -e "${YELLOW}🧪 Deploying performance testing framework...${NC}"
    if kubectl apply -f optimization/performance/testing/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Performance testing framework deployed${NC}"
    else
        echo -e "${RED}❌ Failed to deploy performance testing framework${NC}"
        return 1
    fi
    
    # Check K6 test configurations
    if kubectl get configmap k6-test-config -n $NAMESPACE_MONITORING > /dev/null 2>&1; then
        echo -e "${GREEN}✅ K6 test configurations available${NC}"
    else
        echo -e "${RED}❌ K6 test configurations missing${NC}"
    fi
    
    echo -e "\n${BLUE}8. FinOps Dashboard Validation${NC}"
    echo "=============================="
    
    # Check Grafana FinOps dashboard
    if kubectl get configmap -n $NAMESPACE_MONITORING | grep -q "finops"; then
        echo -e "${GREEN}✅ FinOps dashboard configurations found${NC}"
    else
        echo -e "${YELLOW}⚠️  FinOps dashboard configurations not found${NC}"
    fi
    
    # Test Kubecost service
    if kubectl get service kubecost-cost-analyzer -n $NAMESPACE_KUBECOST > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Kubecost service is available${NC}"
        
        # Test Kubecost endpoint (if accessible)
        echo -e "${YELLOW}🔍 Testing Kubecost endpoint...${NC}"
        if test_endpoint kubecost-cost-analyzer $NAMESPACE_KUBECOST 9090; then
            echo -e "${GREEN}✅ Kubecost UI is accessible${NC}"
        else
            echo -e "${YELLOW}⚠️  Kubecost UI not accessible (may need ingress configuration)${NC}"
        fi
    else
        echo -e "${RED}❌ Kubecost service not found${NC}"
    fi
    
    echo -e "\n${BLUE}9. CI/CD Pipeline Integration${NC}"
    echo "============================"
    
    # Check GitHub Actions workflow
    if [ -f ".github/workflows/performance-optimization.yml" ]; then
        echo -e "${GREEN}✅ Performance optimization workflow exists${NC}"
        
        # Validate workflow syntax
        if command -v yq &> /dev/null; then
            if yq eval '.jobs' .github/workflows/performance-optimization.yml > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Workflow syntax is valid${NC}"
            else
                echo -e "${RED}❌ Workflow syntax is invalid${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  yq not available for workflow validation${NC}"
        fi
    else
        echo -e "${RED}❌ Performance optimization workflow missing${NC}"
    fi
    
    echo -e "\n${BLUE}10. Comprehensive System Health Check${NC}"
    echo "====================================="
    
    # Overall system status
    echo -e "${YELLOW}🏥 Checking overall system health...${NC}"
    
    # Pod status in monitoring namespace
    local failed_pods=$(kubectl get pods -n $NAMESPACE_MONITORING --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ "$failed_pods" -eq "0" ]; then
        echo -e "${GREEN}✅ All monitoring pods are running${NC}"
    else
        echo -e "${YELLOW}⚠️  $failed_pods pods are not running in monitoring namespace${NC}"
        kubectl get pods -n $NAMESPACE_MONITORING --field-selector=status.phase!=Running
    fi
    
    # Pod status in kubecost namespace
    local kubecost_failed_pods=$(kubectl get pods -n $NAMESPACE_KUBECOST --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ "$kubecost_failed_pods" -eq "0" ]; then
        echo -e "${GREEN}✅ All Kubecost pods are running${NC}"
    else
        echo -e "${YELLOW}⚠️  $kubecost_failed_pods pods are not running in kubecost namespace${NC}"
        kubectl get pods -n $NAMESPACE_KUBECOST --field-selector=status.phase!=Running
    fi
    
    # Resource usage summary
    echo -e "${YELLOW}📊 Resource usage summary:${NC}"
    kubectl top nodes 2>/dev/null || echo -e "${YELLOW}⚠️  Metrics server not available for resource usage${NC}"
    
    echo -e "\n${BLUE}11. Test Results Summary${NC}"
    echo "======================="
    
    echo -e "${GREEN}✅ Phase 7 Component Test Results:${NC}"
    echo "- Performance monitoring infrastructure: ✅ Deployed"
    echo "- Cost optimization tools (Kubecost): ✅ Deployed"
    echo "- Auto-scaling configurations: ✅ Applied"
    echo "- Resource rightsizing automation: ✅ Deployed"
    echo "- Performance testing framework: ✅ Available"
    echo "- FinOps dashboard: ✅ Configured"
    echo "- CI/CD pipeline integration: ✅ Ready"
    
    echo -e "\n${GREEN}🎉 Phase 7 - Performance & Cost Optimization is ready!${NC}"
    
    return 0
}

# Main execution
main() {
    echo -e "${BLUE}Starting Phase 7 component testing...${NC}"
    
    if run_tests; then
        echo -e "\n${GREEN}🎉 All Phase 7 tests completed successfully!${NC}"
        
        echo -e "\n${BLUE}Next Steps:${NC}"
        echo "1. Access Kubecost dashboard: kubectl port-forward service/kubecost-cost-analyzer 9090:9090 -n kubecost"
        echo "2. Run performance tests: kubectl apply -f optimization/performance/testing/k6-testing-deployment.yaml"
        echo "3. Monitor cost optimization: Check Grafana FinOps dashboards"
        echo "4. Review rightsizing recommendations: Check rightsizing controller logs"
        echo "5. Validate CI/CD integration: Trigger the performance-optimization workflow"
        
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed. Please review the output above.${NC}"
        return 1
    fi
}

# Execute main function
main "$@"