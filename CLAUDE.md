# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a microservices deployment pipeline project that demonstrates enterprise-grade CI/CD practices with multi-cloud deployment, DevSecOps integration, and comprehensive observability. The project is designed as a portfolio centerpiece showcasing production-ready DevOps skills.

## Architecture

The project follows a microservices architecture with:
- **Frontend**: React/Vue.js application
- **API Gateway**: Node.js (Express) service 
- **User Service**: Python (FastAPI)
- **Product Service**: Go (Gin)
- **Order Service**: Node.js (NestJS)
- **Infrastructure**: PostgreSQL, MongoDB, Redis, RabbitMQ

The deployment pipeline uses GitHub Actions → Build & Test → Security Scan → Container Registry → GitOps (ArgoCD) → Progressive Deployment with monitoring and automated rollback capabilities.

## Implementation Phases

The project is organized into 8 distinct implementation phases:

1. **Foundation Setup**: Basic CI/CD pipeline, Docker containerization, testing
2. **Security Integration**: SAST/DAST tools, vulnerability scanning, secrets management
3. **Kubernetes & GitOps**: K8s deployment, Helm charts, ArgoCD setup
4. **Advanced Deployment**: Blue-green deployments, canary releases, feature flags
5. **Observability**: Prometheus, Grafana, distributed tracing, log aggregation
6. **Multi-Cloud Deployment**: AWS EKS, Google GKE, cross-cloud networking
7. **Performance & Cost Optimization**: Resource tuning, spot instances, FinOps
8. **Chaos Engineering**: Resilience testing, disaster recovery automation

## Expected Directory Structure

Based on the project documentation, the repository should eventually contain:

```
microservices-deployment-pipeline/
├── .github/workflows/           # GitHub Actions CI/CD workflows
├── services/                    # Microservice implementations
│   ├── frontend/               # React/Vue application
│   ├── api-gateway/            # Node.js API Gateway
│   ├── user-service/           # Python User Service  
│   ├── product-service/        # Go Product Service
│   └── order-service/          # Node.js Order Service
├── infrastructure/
│   ├── terraform/              # Infrastructure as Code
│   ├── kubernetes/             # K8s manifests and Helm charts
│   └── helm/                   # Helm chart configurations
├── security/                   # Security policies and scanning configs
├── monitoring/                 # Prometheus, Grafana configurations
├── scripts/                    # CI/CD and deployment scripts
└── tests/                      # Unit, integration, e2e tests
```

## Development Commands

Based on the README, the following commands should be available:

### Local Development Setup
```bash
make install-deps        # Install project dependencies
make setup-local-k8s     # Start local Kubernetes cluster
make deploy-local        # Deploy services locally
```

### Pipeline Operations
```bash
make run-pipeline        # Trigger CI/CD pipeline
make pipeline-status     # View pipeline execution status
```

### Key URLs (when services are running)
- Frontend: http://localhost:3000
- API Gateway: http://localhost:8080  
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

## Technology Stack

### Core Technologies
- **Containerization**: Docker
- **Orchestration**: Kubernetes  
- **CI/CD**: GitHub Actions
- **GitOps**: ArgoCD/Flux
- **IaC**: Terraform
- **Configuration**: Helm/Kustomize

### Security Tools
- **SAST**: SonarQube, Semgrep
- **Container Scanning**: Trivy, Grype
- **DAST**: OWASP ZAP
- **Secret Management**: HashiCorp Vault

### Monitoring Stack
- **Metrics**: Prometheus
- **Visualization**: Grafana  
- **Tracing**: Jaeger/Tempo
- **Logging**: ELK Stack/Loki

## Success Metrics & Goals

The project aims to achieve:
- **Deployment Frequency**: 50+ deployments per day
- **Lead Time**: < 15 minutes from commit to production
- **MTTR**: < 10 minutes mean time to recovery
- **Change Failure Rate**: < 1% of deployments cause failures
- **Test Coverage**: > 90% across all services
- **Availability**: 99.99% uptime with multi-region deployment

## Development Notes

- This is primarily a portfolio/demonstration project showcasing DevOps best practices
- The focus is on implementing enterprise-grade CI/CD patterns rather than business logic
- Security is integrated from day one (DevSecOps approach)  
- Multi-cloud deployment across AWS, GCP, and edge locations is a key feature
- All infrastructure should be defined as code using Terraform
- GitOps workflows should be used for deployments with ArgoCD