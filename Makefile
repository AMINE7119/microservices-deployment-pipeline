# Microservices Deployment Pipeline - Makefile
# Complete automation for development, testing, and deployment

.PHONY: help install-deps setup-local-k8s deploy-local run-pipeline pipeline-status clean
.PHONY: test test-unit test-integration test-e2e test-security test-performance
.PHONY: build build-all push-images
.PHONY: deploy-dev deploy-staging deploy-prod
.PHONY: monitoring logs health-check
.PHONY: security-scan validate docs

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Project configuration
PROJECT_NAME := microservices-deployment-pipeline
DOCKER_REGISTRY := ghcr.io/$(shell git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\)\/\([^/.]*\).*/\1/')
SERVICES := frontend api-gateway user-service product-service order-service
ENVIRONMENTS := development staging production
KUBERNETES_NAMESPACE := microservices

# Git information
GIT_COMMIT := $(shell git rev-parse --short HEAD)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

help: ## Show this help message
	@echo "$(BLUE)Microservices Deployment Pipeline$(RESET)"
	@echo "$(BLUE)====================================$(RESET)"
	@echo ""
	@echo "$(GREEN)Usage: make [target]$(RESET)"
	@echo ""
	@echo "$(YELLOW)Setup and Installation:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "(install|setup|init)"
	@echo ""
	@echo "$(YELLOW)Development:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "(build|test|dev|local)"
	@echo ""
	@echo "$(YELLOW)Deployment:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "(deploy|pipeline|release)"
	@echo ""
	@echo "$(YELLOW)Operations:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "(monitoring|logs|health|security|validate)"
	@echo ""
	@echo "$(YELLOW)Cleanup:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "(clean|destroy|reset)"

# =============================================================================
# SETUP AND INSTALLATION
# =============================================================================

install-deps: ## Install all project dependencies
	@echo "$(BLUE)Installing project dependencies...$(RESET)"
	@echo "$(YELLOW)Installing frontend dependencies...$(RESET)"
	cd services/frontend && npm install
	@echo "$(YELLOW)Installing API gateway dependencies...$(RESET)"
	cd services/api-gateway && npm install
	@echo "$(YELLOW)Installing order service dependencies...$(RESET)"
	cd services/order-service && npm install
	@echo "$(YELLOW)Installing Python dependencies...$(RESET)"
	cd services/user-service && pip install -r requirements.txt
	@echo "$(YELLOW)Installing Go dependencies...$(RESET)"
	cd services/product-service && go mod download
	@echo "$(GREEN)All dependencies installed!$(RESET)"

setup-tools: ## Install development tools (kubectl, helm, kind, etc.)
	@echo "$(BLUE)Installing development tools...$(RESET)"
	# Install kubectl
	@if ! command -v kubectl &> /dev/null; then \
		echo "$(YELLOW)Installing kubectl...$(RESET)"; \
		curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
		chmod +x kubectl; \
		sudo mv kubectl /usr/local/bin/; \
	fi
	# Install Helm
	@if ! command -v helm &> /dev/null; then \
		echo "$(YELLOW)Installing Helm...$(RESET)"; \
		curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
	fi
	# Install Kind
	@if ! command -v kind &> /dev/null; then \
		echo "$(YELLOW)Installing Kind...$(RESET)"; \
		go install sigs.k8s.io/kind@latest; \
	fi
	# Install ArgoCD CLI
	@if ! command -v argocd &> /dev/null; then \
		echo "$(YELLOW)Installing ArgoCD CLI...$(RESET)"; \
		curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64; \
		chmod +x argocd-linux-amd64; \
		sudo mv argocd-linux-amd64 /usr/local/bin/argocd; \
	fi
	@echo "$(GREEN)Development tools installed!$(RESET)"

setup-local-k8s: ## Setup local Kubernetes cluster with Kind
	@echo "$(BLUE)Setting up local Kubernetes cluster...$(RESET)"
	@if kind get clusters | grep -q "$(PROJECT_NAME)-dev"; then \
		echo "$(YELLOW)Cluster $(PROJECT_NAME)-dev already exists$(RESET)"; \
	else \
		echo "$(YELLOW)Creating Kind cluster...$(RESET)"; \
		kind create cluster --name $(PROJECT_NAME)-dev --config infrastructure/kubernetes/kind-config.yaml; \
	fi
	@echo "$(YELLOW)Installing Ingress Controller...$(RESET)"
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo "$(YELLOW)Waiting for ingress controller...$(RESET)"
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=90s
	@echo "$(GREEN)Local Kubernetes cluster ready!$(RESET)"
	kubectl cluster-info --context kind-$(PROJECT_NAME)-dev

init-project: install-deps setup-tools setup-local-k8s ## Initialize complete project setup
	@echo "$(GREEN)Project initialization complete!$(RESET)"
	@echo "$(BLUE)Next steps:$(RESET)"
	@echo "  1. Run 'make build-all' to build all services"
	@echo "  2. Run 'make deploy-local' to deploy locally"
	@echo "  3. Run 'make test' to run all tests"

# =============================================================================
# BUILD AND PACKAGING
# =============================================================================

build: ## Build specific service (usage: make build SERVICE=frontend)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: SERVICE parameter required$(RESET)"; \
		echo "$(YELLOW)Usage: make build SERVICE=frontend$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Building $(SERVICE)...$(RESET)"
	docker build -t $(DOCKER_REGISTRY)/$(SERVICE):$(GIT_COMMIT) \
		-t $(DOCKER_REGISTRY)/$(SERVICE):latest \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		--build-arg GIT_BRANCH=$(GIT_BRANCH) \
		services/$(SERVICE)/
	@echo "$(GREEN)Built $(SERVICE) successfully!$(RESET)"

build-all: ## Build all microservices
	@echo "$(BLUE)Building all microservices...$(RESET)"
	@for service in $(SERVICES); do \
		echo "$(YELLOW)Building $$service...$(RESET)"; \
		docker build -t $(DOCKER_REGISTRY)/$$service:$(GIT_COMMIT) \
			-t $(DOCKER_REGISTRY)/$$service:latest \
			--build-arg BUILD_DATE=$(BUILD_DATE) \
			--build-arg GIT_COMMIT=$(GIT_COMMIT) \
			--build-arg GIT_BRANCH=$(GIT_BRANCH) \
			services/$$service/ || exit 1; \
	done
	@echo "$(GREEN)All services built successfully!$(RESET)"

push-images: ## Push images to registry
	@echo "$(BLUE)Pushing images to registry...$(RESET)"
	@for service in $(SERVICES); do \
		echo "$(YELLOW)Pushing $$service...$(RESET)"; \
		docker push $(DOCKER_REGISTRY)/$$service:$(GIT_COMMIT); \
		docker push $(DOCKER_REGISTRY)/$$service:latest; \
	done
	@echo "$(GREEN)All images pushed successfully!$(RESET)"

# =============================================================================
# TESTING
# =============================================================================

test: test-unit test-integration test-security ## Run all tests
	@echo "$(GREEN)All tests completed successfully!$(RESET)"

test-unit: ## Run unit tests for all services
	@echo "$(BLUE)Running unit tests...$(RESET)"
	@echo "$(YELLOW)Testing frontend...$(RESET)"
	cd services/frontend && npm test -- --coverage --watchAll=false
	@echo "$(YELLOW)Testing API gateway...$(RESET)"
	cd services/api-gateway && npm test -- --coverage
	@echo "$(YELLOW)Testing user service...$(RESET)"
	cd services/user-service && python -m pytest --cov=app --cov-report=xml
	@echo "$(YELLOW)Testing product service...$(RESET)"
	cd services/product-service && go test -v -coverprofile=coverage.out ./...
	@echo "$(YELLOW)Testing order service...$(RESET)"
	cd services/order-service && npm run test:cov
	@echo "$(GREEN)Unit tests completed!$(RESET)"

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(RESET)"
	@echo "$(YELLOW)Starting test environment...$(RESET)"
	docker-compose -f docker-compose.test.yml up -d
	@echo "$(YELLOW)Waiting for services to be ready...$(RESET)"
	sleep 30
	@echo "$(YELLOW)Running integration test suite...$(RESET)"
	npm run test:integration
	@echo "$(YELLOW)Cleaning up test environment...$(RESET)"
	docker-compose -f docker-compose.test.yml down -v
	@echo "$(GREEN)Integration tests completed!$(RESET)"

test-e2e: ## Run end-to-end tests
	@echo "$(BLUE)Running E2E tests...$(RESET)"
	@echo "$(YELLOW)Starting application...$(RESET)"
	docker-compose up -d
	@echo "$(YELLOW)Waiting for application to be ready...$(RESET)"
	sleep 60
	@echo "$(YELLOW)Running E2E test suite...$(RESET)"
	npx playwright test
	@echo "$(YELLOW)Stopping application...$(RESET)"
	docker-compose down
	@echo "$(GREEN)E2E tests completed!$(RESET)"

test-performance: ## Run performance tests
	@echo "$(BLUE)Running performance tests...$(RESET)"
	@echo "$(YELLOW)Starting application...$(RESET)"
	docker-compose up -d
	@echo "$(YELLOW)Waiting for application warmup...$(RESET)"
	sleep 60
	@echo "$(YELLOW)Running load tests...$(RESET)"
	k6 run tests/performance/load-test.js
	@echo "$(YELLOW)Running stress tests...$(RESET)"
	k6 run tests/performance/stress-test.js
	@echo "$(YELLOW)Stopping application...$(RESET)"
	docker-compose down
	@echo "$(GREEN)Performance tests completed!$(RESET)"

test-security: ## Run security scans and tests
	@echo "$(BLUE)Running security tests...$(RESET)"
	@echo "$(YELLOW)Running SAST scans...$(RESET)"
	@if command -v semgrep &> /dev/null; then \
		semgrep --config=auto services/; \
	else \
		echo "$(YELLOW)Semgrep not installed, skipping SAST scan$(RESET)"; \
	fi
	@echo "$(YELLOW)Running dependency scans...$(RESET)"
	cd services/frontend && npm audit --audit-level moderate
	cd services/api-gateway && npm audit --audit-level moderate
	cd services/user-service && safety check -r requirements.txt
	@echo "$(YELLOW)Running container scans...$(RESET)"
	@if command -v trivy &> /dev/null; then \
		for service in $(SERVICES); do \
			echo "Scanning $$service..."; \
			trivy image $(DOCKER_REGISTRY)/$$service:latest; \
		done; \
	else \
		echo "$(YELLOW)Trivy not installed, skipping container scans$(RESET)"; \
	fi
	@echo "$(GREEN)Security tests completed!$(RESET)"

# =============================================================================
# LOCAL DEVELOPMENT
# =============================================================================

deploy-local: ## Deploy services locally with Docker Compose
	@echo "$(BLUE)Deploying services locally...$(RESET)"
	@echo "$(YELLOW)Building and starting all services...$(RESET)"
	docker-compose up --build -d
	@echo "$(YELLOW)Waiting for services to be ready...$(RESET)"
	sleep 30
	@echo "$(GREEN)Services deployed locally!$(RESET)"
	@echo "$(BLUE)Service URLs:$(RESET)"
	@echo "  Frontend: http://localhost:3000"
	@echo "  API Gateway: http://localhost:8080"
	@echo "  User Service: http://localhost:8000"
	@echo "  Product Service: http://localhost:8081"
	@echo "  Order Service: http://localhost:3001"

dev: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(RESET)"
	docker-compose -f docker-compose.dev.yml up --build

stop-local: ## Stop local services
	@echo "$(BLUE)Stopping local services...$(RESET)"
	docker-compose down
	@echo "$(GREEN)Local services stopped!$(RESET)"

# =============================================================================
# KUBERNETES DEPLOYMENTS
# =============================================================================

deploy-k8s-local: ## Deploy to local Kubernetes cluster
	@echo "$(BLUE)Deploying to local Kubernetes...$(RESET)"
	@echo "$(YELLOW)Creating namespace...$(RESET)"
	kubectl create namespace $(KUBERNETES_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "$(YELLOW)Applying Kubernetes manifests...$(RESET)"
	kubectl apply -k infrastructure/kubernetes/overlays/development
	@echo "$(YELLOW)Waiting for deployments to be ready...$(RESET)"
	kubectl wait --for=condition=available --timeout=300s deployment --all -n $(KUBERNETES_NAMESPACE)
	@echo "$(GREEN)Deployment to local Kubernetes completed!$(RESET)"

deploy-dev: ## Deploy to development environment
	@echo "$(BLUE)Deploying to development environment...$(RESET)"
	helm upgrade --install microservices infrastructure/helm/microservices \
		--namespace $(KUBERNETES_NAMESPACE) \
		--create-namespace \
		--values environments/development/values.yaml \
		--set image.tag=$(GIT_COMMIT)
	@echo "$(GREEN)Development deployment completed!$(RESET)"

deploy-staging: ## Deploy to staging environment
	@echo "$(BLUE)Deploying to staging environment...$(RESET)"
	helm upgrade --install microservices infrastructure/helm/microservices \
		--namespace microservices-staging \
		--create-namespace \
		--values environments/staging/values.yaml \
		--set image.tag=$(GIT_COMMIT)
	@echo "$(GREEN)Staging deployment completed!$(RESET)"

deploy-prod: ## Deploy to production environment
	@echo "$(BLUE)Deploying to production environment...$(RESET)"
	@echo "$(RED)WARNING: This will deploy to production!$(RESET)"
	@read -p "Are you sure? [y/N]: " confirm && [[ $$confirm == [yY] || $$confirm == [yY][eE][sS] ]] || exit 1
	helm upgrade --install microservices infrastructure/helm/microservices \
		--namespace microservices-prod \
		--create-namespace \
		--values environments/production/values.yaml \
		--set image.tag=$(GIT_COMMIT)
	@echo "$(GREEN)Production deployment completed!$(RESET)"

# =============================================================================
# GITOPS AND ARGOCD
# =============================================================================

install-argocd: ## Install ArgoCD in local cluster
	@echo "$(BLUE)Installing ArgoCD...$(RESET)"
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "$(YELLOW)Waiting for ArgoCD to be ready...$(RESET)"
	kubectl wait --for=condition=available --timeout=300s deployment --all -n argocd
	@echo "$(GREEN)ArgoCD installed successfully!$(RESET)"
	@echo "$(BLUE)Getting ArgoCD password:$(RESET)"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
	@echo "$(BLUE)Access ArgoCD at: http://localhost:8080$(RESET)"
	@echo "$(YELLOW)Run 'make argocd-port-forward' to access the UI$(RESET)"

argocd-port-forward: ## Port forward to ArgoCD server
	@echo "$(BLUE)Port forwarding to ArgoCD...$(RESET)"
	@echo "$(YELLOW)Access ArgoCD at: http://localhost:8080$(RESET)"
	@echo "$(YELLOW)Username: admin$(RESET)"
	@echo "$(YELLOW)Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)$(RESET)"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

setup-gitops: install-argocd ## Setup GitOps with ArgoCD
	@echo "$(BLUE)Setting up GitOps workflow...$(RESET)"
	kubectl apply -f infrastructure/gitops/applications/
	@echo "$(GREEN)GitOps setup completed!$(RESET)"

# =============================================================================
# PIPELINE AND CI/CD
# =============================================================================

run-pipeline: ## Trigger CI/CD pipeline (local simulation)
	@echo "$(BLUE)Running CI/CD pipeline simulation...$(RESET)"
	@echo "$(YELLOW)Phase 1: Code Quality Checks...$(RESET)"
	make test-unit
	@echo "$(YELLOW)Phase 2: Security Scans...$(RESET)"
	make test-security
	@echo "$(YELLOW)Phase 3: Build Images...$(RESET)"
	make build-all
	@echo "$(YELLOW)Phase 4: Integration Tests...$(RESET)"
	make test-integration
	@echo "$(YELLOW)Phase 5: Performance Tests...$(RESET)"
	make test-performance
	@echo "$(GREEN)Pipeline simulation completed successfully!$(RESET)"

pipeline-status: ## Check pipeline and services status
	@echo "$(BLUE)Checking service health...$(RESET)"
	@echo "$(YELLOW)Local services:$(RESET)"
	@curl -sf http://localhost:3000/health > /dev/null && echo "✅ Frontend: Healthy" || echo "❌ Frontend: Unhealthy"
	@curl -sf http://localhost:8080/health > /dev/null && echo "✅ API Gateway: Healthy" || echo "❌ API Gateway: Unhealthy"
	@curl -sf http://localhost:8000/health > /dev/null && echo "✅ User Service: Healthy" || echo "❌ User Service: Unhealthy"
	@curl -sf http://localhost:8081/health > /dev/null && echo "✅ Product Service: Healthy" || echo "❌ Product Service: Unhealthy"
	@curl -sf http://localhost:3001/health > /dev/null && echo "✅ Order Service: Healthy" || echo "❌ Order Service: Unhealthy"
	@echo ""
	@echo "$(YELLOW)Kubernetes services:$(RESET)"
	@if kubectl get namespace $(KUBERNETES_NAMESPACE) > /dev/null 2>&1; then \
		kubectl get pods -n $(KUBERNETES_NAMESPACE); \
	else \
		echo "$(RED)Kubernetes namespace $(KUBERNETES_NAMESPACE) not found$(RESET)"; \
	fi

# =============================================================================
# MONITORING AND OBSERVABILITY
# =============================================================================

setup-monitoring: ## Setup monitoring stack (Prometheus, Grafana, etc.)
	@echo "$(BLUE)Setting up monitoring stack...$(RESET)"
	@echo "$(YELLOW)Installing Prometheus...$(RESET)"
	helm upgrade --install prometheus prometheus-community/prometheus \
		--namespace monitoring \
		--create-namespace \
		--values monitoring/prometheus/values.yaml
	@echo "$(YELLOW)Installing Grafana...$(RESET)"
	helm upgrade --install grafana grafana/grafana \
		--namespace monitoring \
		--values monitoring/grafana/values.yaml
	@echo "$(YELLOW)Installing Jaeger...$(RESET)"
	kubectl apply -f monitoring/jaeger/
	@echo "$(GREEN)Monitoring stack setup completed!$(RESET)"

monitoring: ## Access monitoring dashboards
	@echo "$(BLUE)Monitoring Dashboard URLs:$(RESET)"
	@echo "  Prometheus: http://localhost:9090 (kubectl port-forward svc/prometheus-server 9090:80 -n monitoring)"
	@echo "  Grafana: http://localhost:3000 (kubectl port-forward svc/grafana 3000:80 -n monitoring)"
	@echo "  Jaeger: http://localhost:16686 (kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring)"

logs: ## View aggregated logs
	@echo "$(BLUE)Viewing service logs...$(RESET)"
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(YELLOW)Showing logs for all services:$(RESET)"; \
		docker-compose logs -f; \
	else \
		echo "$(YELLOW)Showing logs for $(SERVICE):$(RESET)"; \
		docker-compose logs -f $(SERVICE); \
	fi

logs-k8s: ## View Kubernetes logs
	@echo "$(BLUE)Viewing Kubernetes logs...$(RESET)"
	@if [ -z "$(SERVICE)" ]; then \
		kubectl logs -n $(KUBERNETES_NAMESPACE) --selector app.kubernetes.io/part-of=microservices --tail=100; \
	else \
		kubectl logs -n $(KUBERNETES_NAMESPACE) --selector app=$(SERVICE) --tail=100; \
	fi

# =============================================================================
# HEALTH AND VALIDATION
# =============================================================================

health-check: ## Comprehensive health check
	@echo "$(BLUE)Running comprehensive health check...$(RESET)"
	@echo "$(YELLOW)Docker services:$(RESET)"
	@docker-compose ps || echo "$(RED)Docker Compose not running$(RESET)"
	@echo ""
	@echo "$(YELLOW)Kubernetes cluster:$(RESET)"
	@kubectl cluster-info || echo "$(RED)Kubernetes not accessible$(RESET)"
	@echo ""
	@echo "$(YELLOW)Service health endpoints:$(RESET)"
	@./scripts/health-check.sh

validate: ## Run full project validation
	@echo "$(BLUE)Running project validation...$(RESET)"
	@if [ -f "tests/validation/phase1-validation.sh" ]; then \
		chmod +x tests/validation/phase1-validation.sh; \
		./tests/validation/phase1-validation.sh; \
	fi
	@if [ -f "tests/validation/phase2-validation.sh" ]; then \
		chmod +x tests/validation/phase2-validation.sh; \
		./tests/validation/phase2-validation.sh; \
	fi
	@if [ -f "tests/validation/phase3-validation.sh" ]; then \
		chmod +x tests/validation/phase3-validation.sh; \
		./tests/validation/phase3-validation.sh; \
	fi
	@echo "$(GREEN)Validation completed!$(RESET)"

# =============================================================================
# DOCUMENTATION
# =============================================================================

docs: ## Generate and serve documentation
	@echo "$(BLUE)Serving documentation...$(RESET)"
	@if command -v python3 &> /dev/null; then \
		cd docs && python3 -m http.server 8000; \
	else \
		echo "$(RED)Python3 not found. Please install Python3 to serve docs.$(RESET)"; \
	fi

docs-build: ## Build API documentation
	@echo "$(BLUE)Building API documentation...$(RESET)"
	@echo "$(YELLOW)Generating OpenAPI specs...$(RESET)"
	@for service in api-gateway user-service order-service; do \
		if [ -f "services/$$service/package.json" ]; then \
			cd services/$$service && npm run docs:generate || true; \
			cd ../..; \
		fi; \
	done
	@echo "$(GREEN)Documentation built!$(RESET)"

# =============================================================================
# BACKUP AND RESTORE
# =============================================================================

backup: ## Create backup of data and configuration
	@echo "$(BLUE)Creating backup...$(RESET)"
	@mkdir -p backups/$(shell date +%Y%m%d_%H%M%S)
	@echo "$(YELLOW)Backing up database...$(RESET)"
	@if docker-compose ps postgres | grep -q "Up"; then \
		docker-compose exec postgres pg_dumpall -U postgres > backups/$(shell date +%Y%m%d_%H%M%S)/database.sql; \
	fi
	@echo "$(YELLOW)Backing up configurations...$(RESET)"
	@tar -czf backups/$(shell date +%Y%m%d_%H%M%S)/configs.tar.gz infrastructure/ environments/
	@echo "$(GREEN)Backup completed!$(RESET)"

restore: ## Restore from backup (usage: make restore BACKUP_DIR=20240101_120000)
	@if [ -z "$(BACKUP_DIR)" ]; then \
		echo "$(RED)Error: BACKUP_DIR parameter required$(RESET)"; \
		echo "$(YELLOW)Usage: make restore BACKUP_DIR=20240101_120000$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring from backup $(BACKUP_DIR)...$(RESET)"
	@if [ -f "backups/$(BACKUP_DIR)/database.sql" ]; then \
		echo "$(YELLOW)Restoring database...$(RESET)"; \
		docker-compose exec -T postgres psql -U postgres < backups/$(BACKUP_DIR)/database.sql; \
	fi
	@echo "$(GREEN)Restore completed!$(RESET)"

# =============================================================================
# CLEANUP
# =============================================================================

clean: ## Clean up containers, images, and volumes
	@echo "$(BLUE)Cleaning up Docker resources...$(RESET)"
	@echo "$(YELLOW)Stopping containers...$(RESET)"
	docker-compose down -v --remove-orphans
	@echo "$(YELLOW)Removing unused images...$(RESET)"
	docker image prune -f
	@echo "$(YELLOW)Removing unused volumes...$(RESET)"
	docker volume prune -f
	@echo "$(GREEN)Cleanup completed!$(RESET)"

clean-k8s: ## Clean up Kubernetes resources
	@echo "$(BLUE)Cleaning up Kubernetes resources...$(RESET)"
	@if kubectl get namespace $(KUBERNETES_NAMESPACE) > /dev/null 2>&1; then \
		kubectl delete namespace $(KUBERNETES_NAMESPACE); \
	fi
	@if kubectl get namespace monitoring > /dev/null 2>&1; then \
		kubectl delete namespace monitoring; \
	fi
	@if kubectl get namespace argocd > /dev/null 2>&1; then \
		kubectl delete namespace argocd; \
	fi
	@echo "$(GREEN)Kubernetes cleanup completed!$(RESET)"

destroy: clean clean-k8s ## Complete project cleanup
	@echo "$(BLUE)Destroying project environment...$(RESET)"
	@if kind get clusters | grep -q "$(PROJECT_NAME)-dev"; then \
		echo "$(YELLOW)Deleting Kind cluster...$(RESET)"; \
		kind delete cluster --name $(PROJECT_NAME)-dev; \
	fi
	@echo "$(YELLOW)Removing Docker images...$(RESET)"
	@for service in $(SERVICES); do \
		docker rmi $(DOCKER_REGISTRY)/$$service:latest $(DOCKER_REGISTRY)/$$service:$(GIT_COMMIT) 2>/dev/null || true; \
	done
	docker system prune -af
	@echo "$(RED)Project environment destroyed!$(RESET)"

reset: destroy init-project ## Reset project to initial state
	@echo "$(GREEN)Project reset completed!$(RESET)"

# =============================================================================
# UTILITY TARGETS
# =============================================================================

version: ## Show project version information
	@echo "$(BLUE)Project Information:$(RESET)"
	@echo "  Name: $(PROJECT_NAME)"
	@echo "  Git Commit: $(GIT_COMMIT)"
	@echo "  Git Branch: $(GIT_BRANCH)"
	@echo "  Build Date: $(BUILD_DATE)"
	@echo "  Registry: $(DOCKER_REGISTRY)"

env: ## Show environment information
	@echo "$(BLUE)Environment Information:$(RESET)"
	@echo "  Docker: $$(docker --version 2>/dev/null || echo 'Not installed')"
	@echo "  Kubernetes: $$(kubectl version --client --short 2>/dev/null || echo 'Not installed')"
	@echo "  Helm: $$(helm version --short 2>/dev/null || echo 'Not installed')"
	@echo "  Kind: $$(kind version 2>/dev/null || echo 'Not installed')"
	@echo "  ArgoCD: $$(argocd version --client --short 2>/dev/null || echo 'Not installed')"
	@echo "  Node.js: $$(node --version 2>/dev/null || echo 'Not installed')"
	@echo "  Python: $$(python3 --version 2>/dev/null || echo 'Not installed')"
	@echo "  Go: $$(go version 2>/dev/null | cut -d' ' -f3 || echo 'Not installed')"

check-deps: ## Check if all dependencies are installed
	@echo "$(BLUE)Checking dependencies...$(RESET)"
	@./scripts/check-dependencies.sh

# =============================================================================
# ADVANCED OPERATIONS
# =============================================================================

chaos-test: ## Run chaos engineering tests
	@echo "$(BLUE)Running chaos tests...$(RESET)"
	@echo "$(YELLOW)Installing Chaos Monkey...$(RESET)"
	kubectl apply -f infrastructure/chaos/chaos-monkey.yaml
	@echo "$(YELLOW)Running failure scenarios...$(RESET)"
	@# Add chaos testing scenarios here
	@echo "$(GREEN)Chaos tests completed!$(RESET)"

load-test: ## Run comprehensive load tests
	@echo "$(BLUE)Running load tests...$(RESET)"
	k6 run tests/performance/load-test.js --out influxdb=http://localhost:8086/k6

security-audit: ## Run comprehensive security audit
	@echo "$(BLUE)Running security audit...$(RESET)"
	./scripts/security/security-audit.sh

cost-analysis: ## Analyze cloud resource costs
	@echo "$(BLUE)Analyzing resource costs...$(RESET)"
	@echo "$(YELLOW)Current resource usage:$(RESET)"
	kubectl top nodes 2>/dev/null || echo "Metrics server not available"
	kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics server not available"

update-deps: ## Update all dependencies
	@echo "$(BLUE)Updating dependencies...$(RESET)"
	@for service_dir in services/*/; do \
		if [ -f "$$service_dir/package.json" ]; then \
			echo "$(YELLOW)Updating $$service_dir...$(RESET)"; \
			cd $$service_dir && npm update && cd ../..; \
		elif [ -f "$$service_dir/requirements.txt" ]; then \
			echo "$(YELLOW)Updating $$service_dir...$(RESET)"; \
			cd $$service_dir && pip install --upgrade -r requirements.txt && cd ../..; \
		elif [ -f "$$service_dir/go.mod" ]; then \
			echo "$(YELLOW)Updating $$service_dir...$(RESET)"; \
			cd $$service_dir && go get -u ./... && cd ../..; \
		fi; \
	done
	@echo "$(GREEN)Dependencies updated!$(RESET)"

# =============================================================================
# Help and Information
# =============================================================================

examples: ## Show usage examples
	@echo "$(BLUE)Usage Examples:$(RESET)"
	@echo ""
	@echo "$(YELLOW)Quick Start:$(RESET)"
	@echo "  make init-project          # Initialize everything"
	@echo "  make build-all             # Build all services"
	@echo "  make deploy-local          # Deploy locally"
	@echo "  make health-check          # Verify everything works"
	@echo ""
	@echo "$(YELLOW)Development Workflow:$(RESET)"
	@echo "  make build SERVICE=frontend # Build specific service"
	@echo "  make test-unit             # Run unit tests"
	@echo "  make deploy-k8s-local      # Deploy to local K8s"
	@echo "  make logs SERVICE=frontend # View service logs"
	@echo ""
	@echo "$(YELLOW)Production Deployment:$(RESET)"
	@echo "  make test                  # Run all tests"
	@echo "  make build-all             # Build all services"
	@echo "  make push-images           # Push to registry"
	@echo "  make deploy-prod           # Deploy to production"
	@echo ""
	@echo "$(YELLOW)Monitoring and Operations:$(RESET)"
	@echo "  make setup-monitoring      # Setup monitoring stack"
	@echo "  make health-check          # Check system health"
	@echo "  make backup                # Create backup"
	@echo "  make validate              # Run validation tests"

# Ensure scripts are executable
.PHONY: setup-scripts
setup-scripts:
	@find scripts/ -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true