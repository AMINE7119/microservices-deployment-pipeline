#!/bin/bash

# Phase 8 Chaos Engineering Validation Script (Offline)
# This script validates the chaos engineering setup without running actual experiments

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_CHECKS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to check if file exists
check_file() {
    local file_path=$1
    local description=$2
    
    ((TOTAL_CHECKS++))
    if [ -f "$file_path" ]; then
        log_success "$description exists: $file_path"
        return 0
    else
        log_error "$description missing: $file_path"
        return 1
    fi
}

# Function to check if directory exists
check_directory() {
    local dir_path=$1
    local description=$2
    
    ((TOTAL_CHECKS++))
    if [ -d "$dir_path" ]; then
        log_success "$description exists: $dir_path"
        return 0
    else
        log_error "$description missing: $dir_path"
        return 1
    fi
}

# Function to validate YAML syntax
validate_yaml() {
    local yaml_file=$1
    local description=$2
    
    ((TOTAL_CHECKS++))
    if command -v yq &> /dev/null; then
        if yq eval '.' "$yaml_file" &> /dev/null; then
            log_success "$description has valid YAML syntax"
            return 0
        else
            log_error "$description has invalid YAML syntax"
            return 1
        fi
    else
        if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" &> /dev/null; then
            log_success "$description has valid YAML syntax"
            return 0
        else
            log_error "$description has invalid YAML syntax"
            return 1
        fi
    fi
}

# Function to check script permissions
check_script_permissions() {
    local script_path=$1
    local description=$2
    
    ((TOTAL_CHECKS++))
    if [ -x "$script_path" ]; then
        log_success "$description is executable"
        return 0
    else
        log_error "$description is not executable"
        return 1
    fi
}

echo "============================================="
echo "Phase 8: Chaos Engineering Validation"
echo "============================================="
echo ""

# 1. Directory Structure Validation
log_info "Validating directory structure..."
check_directory "chaos-engineering" "Chaos engineering root directory"
check_directory "chaos-engineering/chaos-mesh" "Chaos Mesh directory"
check_directory "chaos-engineering/litmus" "Litmus directory"
check_directory "chaos-engineering/disaster-recovery" "Disaster recovery directory"
check_directory "chaos-engineering/runbooks" "Runbooks directory"
check_directory "chaos-engineering/monitoring" "Monitoring directory"
check_directory "chaos-engineering/scripts" "Scripts directory"

# 2. Chaos Mesh Components Validation
log_info "Validating Chaos Mesh components..."
check_file "chaos-engineering/chaos-mesh/installation/chaos-mesh-install.yaml" "Chaos Mesh installation manifest"
check_file "chaos-engineering/chaos-mesh/installation/install.sh" "Chaos Mesh installation script"
check_script_permissions "chaos-engineering/chaos-mesh/installation/install.sh" "Chaos Mesh installation script"

# Validate experiment files
log_info "Validating Chaos Mesh experiment files..."
check_file "chaos-engineering/chaos-mesh/experiments/pod/pod-failure.yaml" "Pod failure experiments"
check_file "chaos-engineering/chaos-mesh/experiments/network/network-chaos.yaml" "Network chaos experiments"
check_file "chaos-engineering/chaos-mesh/experiments/stress/stress-chaos.yaml" "Stress chaos experiments"
check_file "chaos-engineering/chaos-mesh/experiments/io/io-chaos.yaml" "IO chaos experiments"
check_file "chaos-engineering/chaos-mesh/experiments/time/time-chaos.yaml" "Time chaos experiments"
check_file "chaos-engineering/chaos-mesh/experiments/http/http-chaos.yaml" "HTTP chaos experiments"
check_file "chaos-engineering/chaos-mesh/experiments/workflow-experiments.yaml" "Workflow experiments"

# 3. Litmus Components Validation
log_info "Validating Litmus components..."
check_file "chaos-engineering/litmus/installation/litmus-install.yaml" "Litmus installation manifest"
check_file "chaos-engineering/litmus/experiments/pod-experiments.yaml" "Litmus pod experiments"
check_file "chaos-engineering/litmus/experiments/network-experiments.yaml" "Litmus network experiments"

# 4. Disaster Recovery Validation
log_info "Validating disaster recovery components..."
check_file "chaos-engineering/disaster-recovery/backup/velero-backup-config.yaml" "Velero backup configuration"
check_file "chaos-engineering/disaster-recovery/backup/backup-automation.sh" "Backup automation script"
check_file "chaos-engineering/disaster-recovery/restore/restore-automation.sh" "Restore automation script"
check_file "chaos-engineering/disaster-recovery/failover/multi-region-failover.yaml" "Multi-region failover configuration"

check_script_permissions "chaos-engineering/disaster-recovery/backup/backup-automation.sh" "Backup automation script"
check_script_permissions "chaos-engineering/disaster-recovery/restore/restore-automation.sh" "Restore automation script"

# 5. Monitoring and Dashboards Validation
log_info "Validating monitoring components..."
check_file "chaos-engineering/monitoring/dashboards/chaos-experiments-dashboard.json" "Chaos experiments dashboard"
check_file "chaos-engineering/monitoring/alerts/chaos-alerts.yaml" "Chaos alerts configuration"

# 6. Runbooks Validation
log_info "Validating runbooks..."
check_file "chaos-engineering/runbooks/incident-response/chaos-incident-response.md" "Incident response runbook"
check_file "chaos-engineering/runbooks/recovery-procedures/database-recovery.md" "Database recovery procedures"

# 7. Scripts Validation
log_info "Validating automation scripts..."
check_file "chaos-engineering/scripts/experiment-runner/run-chaos-suite.sh" "Chaos suite runner"
check_script_permissions "chaos-engineering/scripts/experiment-runner/run-chaos-suite.sh" "Chaos suite runner"

# 8. GitHub Actions Workflow Validation
log_info "Validating CI/CD integration..."
check_file ".github/workflows/chaos-engineering.yml" "Chaos engineering workflow"

# 9. YAML Syntax Validation
log_info "Validating YAML syntax..."
yaml_files=(
    "chaos-engineering/chaos-mesh/installation/chaos-mesh-install.yaml"
    "chaos-engineering/chaos-mesh/experiments/pod/pod-failure.yaml"
    "chaos-engineering/chaos-mesh/experiments/network/network-chaos.yaml"
    "chaos-engineering/chaos-mesh/experiments/stress/stress-chaos.yaml"
    "chaos-engineering/chaos-mesh/experiments/io/io-chaos.yaml"
    "chaos-engineering/chaos-mesh/experiments/time/time-chaos.yaml"
    "chaos-engineering/chaos-mesh/experiments/http/http-chaos.yaml"
    "chaos-engineering/chaos-mesh/experiments/workflow-experiments.yaml"
    "chaos-engineering/litmus/installation/litmus-install.yaml"
    "chaos-engineering/litmus/experiments/pod-experiments.yaml"
    "chaos-engineering/litmus/experiments/network-experiments.yaml"
    "chaos-engineering/disaster-recovery/backup/velero-backup-config.yaml"
    "chaos-engineering/disaster-recovery/failover/multi-region-failover.yaml"
    "chaos-engineering/monitoring/alerts/chaos-alerts.yaml"
    ".github/workflows/chaos-engineering.yml"
)

for yaml_file in "${yaml_files[@]}"; do
    if [ -f "$yaml_file" ]; then
        validate_yaml "$yaml_file" "$(basename $yaml_file)"
    fi
done

# 10. Validate Documentation Structure
log_info "Validating documentation..."
check_file "PHASE8_CHAOS_ENGINEERING_PLAN.md" "Phase 8 plan document"

# Check if documentation has required sections
((TOTAL_CHECKS++))
if [ -f "PHASE8_CHAOS_ENGINEERING_PLAN.md" ]; then
    required_sections=("Overview" "Goals" "Key Components" "Implementation Phases" "Success Criteria")
    missing_sections=()
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "## $section" "PHASE8_CHAOS_ENGINEERING_PLAN.md"; then
            missing_sections+=("$section")
        fi
    done
    
    if [ ${#missing_sections[@]} -eq 0 ]; then
        log_success "Phase 8 documentation has all required sections"
    else
        log_error "Phase 8 documentation missing sections: ${missing_sections[*]}"
    fi
else
    log_error "Phase 8 documentation file not found"
fi

# 11. Validate Script Dependencies
log_info "Validating script dependencies..."

# Check if required tools are documented
((TOTAL_CHECKS++))
required_tools=("kubectl" "helm" "curl" "jq")
missing_tools=()

for tool in "${required_tools[@]}"; do
    if ! grep -r "$tool" chaos-engineering/scripts/ &> /dev/null && ! grep -r "$tool" .github/workflows/chaos-engineering.yml &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -eq 0 ]; then
    log_success "All required tools are referenced in scripts"
else
    log_warning "Some tools may not be properly referenced: ${missing_tools[*]}"
fi

# 12. Validate Chaos Experiment Configurations
log_info "Validating chaos experiment configurations..."

# Check for proper namespace usage
((TOTAL_CHECKS++))
if grep -r "namespace.*microservices" chaos-engineering/chaos-mesh/experiments/ &> /dev/null; then
    log_success "Chaos experiments target correct namespace"
else
    log_error "Chaos experiments may not target correct namespace"
fi

# Check for experiment duration settings
((TOTAL_CHECKS++))
if grep -r "duration.*[0-9]" chaos-engineering/chaos-mesh/experiments/ &> /dev/null; then
    log_success "Chaos experiments have duration settings"
else
    log_error "Chaos experiments may be missing duration settings"
fi

# 13. Validate Monitoring Integration
log_info "Validating monitoring integration..."

# Check for Prometheus metrics
((TOTAL_CHECKS++))
if grep -r "prometheus" chaos-engineering/monitoring/ &> /dev/null; then
    log_success "Prometheus integration configured"
else
    log_error "Prometheus integration may be missing"
fi

# Check for Grafana dashboards
((TOTAL_CHECKS++))
if [ -f "chaos-engineering/monitoring/dashboards/chaos-experiments-dashboard.json" ]; then
    if jq empty "chaos-engineering/monitoring/dashboards/chaos-experiments-dashboard.json" &> /dev/null; then
        log_success "Grafana dashboard has valid JSON"
    else
        log_error "Grafana dashboard has invalid JSON"
    fi
else
    log_error "Grafana dashboard file not found"
fi

# 14. Validate GitHub Actions Workflow
log_info "Validating GitHub Actions workflow..."

# Check for required workflow triggers
((TOTAL_CHECKS++))
if grep -q "schedule:" .github/workflows/chaos-engineering.yml && grep -q "workflow_dispatch:" .github/workflows/chaos-engineering.yml; then
    log_success "GitHub Actions workflow has proper triggers"
else
    log_error "GitHub Actions workflow may be missing required triggers"
fi

# Check for proper job dependencies
((TOTAL_CHECKS++))
if grep -q "needs:" .github/workflows/chaos-engineering.yml; then
    log_success "GitHub Actions workflow has job dependencies"
else
    log_error "GitHub Actions workflow may be missing job dependencies"
fi

echo ""
echo "============================================="
echo "Validation Summary"
echo "============================================="
echo "Total Checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "\n${GREEN}✅ Phase 8 chaos engineering setup validation PASSED!${NC}"
    echo -e "${GREEN}All components are properly configured and ready for chaos experiments.${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Phase 8 chaos engineering setup validation FAILED!${NC}"
    echo -e "${RED}Please fix the above issues before proceeding with chaos experiments.${NC}"
    exit 1
fi