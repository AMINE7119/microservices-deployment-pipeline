# Complete Makefile Usage Guide - All Phases

This comprehensive guide provides step-by-step instructions for using the Makefile throughout all 8 phases of the microservices deployment pipeline project.

## 🚀 Quick Reference

```bash
make help        # Show all available commands
make examples    # Show usage examples
make env         # Check environment setup
make version     # Show project information
```

---

## 📋 Phase-by-Phase Makefile Usage

### Phase 0: Initial Project Setup

#### Step 1: Environment Verification
```bash
# Check if all dependencies are installed
make env

# Check specific dependencies
make check-deps
```

#### Step 2: Complete Project Initialization
```bash
# This command does EVERYTHING needed to start:
# - Installs all dependencies (Node.js, Python, Go)
# - Installs development tools (kubectl, helm, kind, argocd)
# - Creates local Kubernetes cluster
make init-project

# Expected output: ✅ Project initialization complete!
```

**🔍 What happens during init-project:**
1. `install-deps`: Installs dependencies for all 5 microservices
2. `setup-tools`: Installs kubectl, Helm, Kind, ArgoCD CLI
3. `setup-local-k8s`: Creates Kind cluster with ingress controller

#### Step 3: Verify Setup
```bash
# Show project information
make version

# Check environment status
make env
```

---

## 🏗️ Phase 1: Foundation Development

### Step 1: Development Environment
```bash
# Start development environment (hot reload)
make dev

# Or deploy locally with Docker Compose
make deploy-local
```

### Step 2: Building Services
```bash
# Build all microservices at once
make build-all

# Build specific service
make build SERVICE=frontend
make build SERVICE=api-gateway
make build SERVICE=user-service
make build SERVICE=product-service
make build SERVICE=order-service
```

### Step 3: Testing Phase 1
```bash
# Run all tests (unit + integration + security)
make test

# Run specific test types
make test-unit           # Unit tests for all services
make test-integration    # Integration tests
make test-security       # Security scans
```

### Step 4: Local Deployment Verification
```bash
# Check service health
make health-check

# View service logs
make logs                      # All services
make logs SERVICE=frontend     # Specific service

# Check service status
make pipeline-status
```

### Step 5: Phase 1 Validation
```bash
# Run Phase 1 validation
make validate

# Expected output: ✅ Phase 1 validation passed
```

---

## 🔒 Phase 2: Security Implementation

### Step 1: Security Scanning
```bash
# Run comprehensive security tests
make test-security

# This includes:
# - SAST scans with Semgrep
# - Dependency vulnerability scans
# - Container image scanning with Trivy
```

### Step 2: Security Audit
```bash
# Run comprehensive security audit
make security-audit

# This executes the complete security assessment
```

### Step 3: Build with Security
```bash
# Build all services with security scanning
make build-all

# Push images to registry (includes security scan)
make push-images
```

### Step 4: Validate Security Implementation
```bash
# Run validation for Phase 2
make validate

# Expected output: ✅ Phase 2 security validation passed
```

---

## ☸️ Phase 3: Kubernetes & GitOps

### Step 1: Kubernetes Deployment
```bash
# Deploy to local Kubernetes cluster
make deploy-k8s-local

# This will:
# - Create microservices namespace
# - Apply Kubernetes manifests
# - Wait for deployments to be ready
```

### Step 2: Install ArgoCD
```bash
# Install ArgoCD for GitOps
make install-argocd

# Get ArgoCD password and access info
make argocd-port-forward

# Access ArgoCD at: http://localhost:8080
# Username: admin
# Password: (shown in terminal)
```

### Step 3: Setup GitOps Workflow
```bash
# Setup complete GitOps with ArgoCD
make setup-gitops

# This installs ArgoCD and applies application configurations
```

### Step 4: Kubernetes Operations
```bash
# View Kubernetes logs
make logs-k8s                    # All services
make logs-k8s SERVICE=frontend   # Specific service

# Check Kubernetes status
make pipeline-status
```

### Step 5: Phase 3 Validation
```bash
# Validate Kubernetes deployment
make validate

# Expected output: ✅ Phase 3 Kubernetes validation passed
```

---

## 🚢 Phase 4: Advanced Deployment Strategies

### Step 1: Environment-Specific Deployments
```bash
# Deploy to development environment
make deploy-dev

# Deploy to staging environment
make deploy-staging

# Deploy to production (with confirmation prompt)
make deploy-prod
```

### Step 2: Blue-Green Deployment
```bash
# Execute blue-green deployment
./scripts/deployment/blue-green-deploy.sh microservices/frontend:v2.0.0

# Or use make target (after implementing in Phase 4)
make deploy-blue-green IMAGE=microservices/frontend:v2.0.0
```

### Step 3: Canary Deployment
```bash
# Deploy canary release (managed by Flagger)
# This is automated through GitOps - just push changes
git push origin main

# Monitor canary progress
kubectl get canary microservices-canary -n microservices -w
```

### Step 4: Rollback Operations
```bash
# Manual rollback if needed
kubectl rollout undo deployment/microservices -n microservices

# Or use automated rollback monitoring
./scripts/deployment/auto-rollback.sh
```

---

## 📊 Phase 5: Observability & Monitoring

### Step 1: Setup Monitoring Stack
```bash
# Install Prometheus, Grafana, Jaeger
make setup-monitoring

# This installs the complete observability stack
```

### Step 2: Access Monitoring Dashboards
```bash
# Show monitoring dashboard URLs
make monitoring

# Port forward to access:
# Prometheus: kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
# Grafana: kubectl port-forward svc/grafana 3000:80 -n monitoring
# Jaeger: kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring
```

### Step 3: Log Analysis
```bash
# View aggregated logs
make logs                    # Docker Compose logs
make logs-k8s               # Kubernetes logs

# Service-specific logs
make logs SERVICE=api-gateway
make logs-k8s SERVICE=user-service
```

---

## ⚡ Phase 6: Performance Optimization

### Step 1: Performance Testing
```bash
# Run performance tests
make test-performance

# Run load tests specifically
make load-test

# This includes:
# - Load testing with k6
# - Stress testing scenarios
# - Performance benchmark validation
```

### Step 2: Resource Analysis
```bash
# Check resource usage
make cost-analysis

# Monitor resource utilization
kubectl top nodes
kubectl top pods --all-namespaces
```

---

## 🧪 Phase 7: Chaos Engineering

### Step 1: Chaos Testing
```bash
# Run chaos engineering tests
make chaos-test

# This installs Chaos Monkey and runs failure scenarios
```

---

## ☁️ Phase 8: Multi-Cloud & Production

### Step 1: Production Deployment Pipeline
```bash
# Run complete CI/CD pipeline simulation
make run-pipeline

# This executes:
# 1. Code quality checks
# 2. Security scans
# 3. Build images
# 4. Integration tests
# 5. Performance tests
```

### Step 2: Production Health Checks
```bash
# Comprehensive health check
make health-check

# Full project validation
make validate
```

---

## 🛠️ Daily Development Workflow

### Morning Setup
```bash
# Check environment
make env

# Start development environment
make dev
```

### During Development
```bash
# Build specific service you're working on
make build SERVICE=frontend

# Run unit tests
make test-unit

# Check logs
make logs SERVICE=frontend
```

### Before Committing
```bash
# Run all tests
make test

# Run security scan
make test-security

# Validate changes
make validate
```

### Deployment Workflow
```bash
# Build all services
make build-all

# Deploy to development
make deploy-dev

# Run integration tests
make test-integration

# Deploy to staging
make deploy-staging

# Deploy to production
make deploy-prod
```

---

## 🔧 Maintenance & Operations

### Regular Maintenance
```bash
# Update all dependencies
make update-deps

# Clean up Docker resources
make clean

# Clean up Kubernetes resources
make clean-k8s
```

### Backup & Recovery
```bash
# Create backup
make backup

# Restore from backup
make restore BACKUP_DIR=20240101_120000
```

### Documentation
```bash
# Generate and serve documentation
make docs

# Build API documentation
make docs-build
```

---

## 🆘 Troubleshooting Commands

### When Services Are Down
```bash
# Check service health
make health-check

# View logs
make logs
make logs-k8s

# Check pipeline status
make pipeline-status
```

### When Kubernetes Issues Occur
```bash
# Check cluster status
kubectl cluster-info

# View pod status
kubectl get pods -n microservices

# Describe problematic pods
kubectl describe pod <pod-name> -n microservices
```

### Complete Environment Reset
```bash
# Nuclear option - complete reset
make reset

# This will:
# 1. Clean up all Docker resources
# 2. Clean up Kubernetes resources  
# 3. Delete Kind cluster
# 4. Remove Docker images
# 5. Re-initialize project
```

---

## 🎯 Phase-Specific Validation Commands

### Validate Each Phase
```bash
# Phase 1: Foundation
make validate  # Runs phase1-validation.sh

# Phase 2: Security
make test-security && make validate

# Phase 3: Kubernetes
make deploy-k8s-local && make validate

# Phase 4: Advanced Deployments
make deploy-dev && make validate

# Phase 5: Monitoring
make setup-monitoring && make validate

# Phase 6: Performance
make test-performance && make validate

# Phase 7: Chaos Testing
make chaos-test && make validate

# Phase 8: Production
make run-pipeline && make validate
```

---

## ⚡ Power User Commands

### Advanced Operations
```bash
# Run comprehensive load test with metrics
make load-test

# Execute security audit
make security-audit

# Chaos engineering tests
make chaos-test

# Cost analysis
make cost-analysis
```

### Batch Operations
```bash
# Build and test everything
make build-all && make test && make deploy-local

# Complete deployment pipeline
make test && make build-all && make push-images && make deploy-prod

# Full validation suite
make validate && make health-check && make test-security
```

---

## 📋 Command Reference Summary

| Phase | Key Commands | Purpose |
|-------|-------------|---------|
| **Setup** | `make init-project` | Complete project initialization |
| **Phase 1** | `make build-all && make test && make deploy-local` | Foundation development |
| **Phase 2** | `make test-security && make security-audit` | Security implementation |
| **Phase 3** | `make deploy-k8s-local && make setup-gitops` | Kubernetes & GitOps |
| **Phase 4** | `make deploy-dev && make deploy-staging && make deploy-prod` | Advanced deployments |
| **Phase 5** | `make setup-monitoring && make monitoring` | Observability |
| **Phase 6** | `make test-performance && make load-test` | Performance optimization |
| **Phase 7** | `make chaos-test` | Chaos engineering |
| **Phase 8** | `make run-pipeline && make validate` | Production readiness |

---

## 🎉 Success Indicators

After each phase, you should see these success indicators:

- ✅ All tests passing
- ✅ Services healthy and responding
- ✅ No security vulnerabilities
- ✅ Deployments successful
- ✅ Monitoring active
- ✅ Performance benchmarks met

**Remember**: Always run `make validate` after completing each phase to ensure everything is working correctly!

---

**🚀 You now have the complete roadmap for using the Makefile throughout all 8 phases of your microservices deployment pipeline project. Each command is designed to guide you through professional-grade DevOps practices that will make your portfolio stand out!**