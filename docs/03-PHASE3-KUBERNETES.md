# Phase 3: Kubernetes & GitOps

## 🎯 Phase Objective
Deploy the secured microservices to Kubernetes clusters with GitOps workflows, implementing declarative deployments, automated configuration management, and progressive delivery capabilities. This phase establishes the foundation for production-grade container orchestration.

## ⏱️ Timeline
**Estimated Duration**: 2-3 weeks
**Prerequisites**: Phase 1 (Foundation) and Phase 2 (Security) completed successfully

## 🏗️ Kubernetes & GitOps Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GITOPS WORKFLOW ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Source Code → CI Pipeline → Image Registry → GitOps Repository → K8s      │
│       │             │              │               │              │         │
│   Developer     Build & Test    Container      Config Repo     ArgoCD       │
│   Commits       Security Scan    Images        (Helm Charts)   Sync         │
│       │             │              │               │              │         │
│   Code Repo     GitHub Actions   DockerHub      Git Repo     Kubernetes     │
│   (Services)    (Workflows)      (Images)       (Manifests)   (Clusters)    │
│                                                      │              │         │
│                                                 Declarative   Actual State  │
│                                                 Desired State  Reconciliation│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        KUBERNETES CLUSTER LAYOUT                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │    Namespace:       │  │    Namespace:       │  │    Namespace:       │ │
│  │   microservices     │  │     monitoring      │  │      security       │ │
│  │ ┌─────────────────┐ │  │ ┌─────────────────┐ │  │ ┌─────────────────┐ │ │
│  │ │   Frontend      │ │  │ │   Prometheus    │ │  │ │   Vault         │ │ │
│  │ │   API Gateway   │ │  │ │   Grafana       │ │  │ │   OPA           │ │ │
│  │ │   User Service  │ │  │ │   Jaeger        │ │  │ │   Falco         │ │ │
│  │ │ Product Service │ │  │ │   Loki          │ │  │ │                 │ │ │
│  │ │  Order Service  │ │  │ └─────────────────┘ │  │ └─────────────────┘ │ │
│  │ └─────────────────┘ │  └─────────────────────┘  └─────────────────────┘ │
│  └─────────────────────┘                                                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         Ingress Controller                              │ │
│  │              Load Balancer → SSL Termination → Routing                 │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        Persistent Storage                               │ │
│  │            PostgreSQL → MongoDB → Redis → ArgoCD Data                  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📋 Detailed Implementation Checklist

### 1. Kubernetes Cluster Setup

#### 1.1 Local Development Cluster (Kind)
- [ ] **Kind cluster configuration**
```yaml
# infrastructure/kubernetes/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: microservices-dev
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
- role: worker
- role: worker
```

- [ ] **Cluster creation script**
```bash
#!/bin/bash
# scripts/k8s/create-cluster.sh

set -e

echo "Creating Kind cluster..."
kind create cluster --config=infrastructure/kubernetes/kind-config.yaml

echo "Installing Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

echo "Waiting for cert-manager..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app=cert-manager \
  --timeout=90s

echo "Cluster setup complete!"
kubectl cluster-info
```

#### 1.2 Production-Ready Cluster Configuration
- [ ] **Cluster hardening checklist**
```yaml
# security/cluster-hardening.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-hardening-checklist
  namespace: kube-system
data:
  checklist: |
    ✓ RBAC enabled
    ✓ Pod Security Standards enforced
    ✓ Network policies configured
    ✓ Admission controllers enabled
    ✓ Audit logging configured
    ✓ etcd encryption enabled
    ✓ API server secured
    ✓ Node security configured
```

### 2. Namespace and RBAC Setup

#### 2.1 Namespace Configuration
- [ ] **Namespace definitions**
```yaml
# infrastructure/kubernetes/base/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
  labels:
    name: microservices
    tier: application
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    tier: observability
---
apiVersion: v1
kind: Namespace
metadata:
  name: security
  labels:
    name: security
    tier: security
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
    tier: gitops
```

#### 2.2 RBAC Configuration
- [ ] **Service accounts and roles**
```yaml
# infrastructure/kubernetes/base/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: microservices-sa
  namespace: microservices
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: microservices
  name: microservices-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: microservices-binding
  namespace: microservices
subjects:
- kind: ServiceAccount
  name: microservices-sa
  namespace: microservices
roleRef:
  kind: Role
  name: microservices-role
  apiGroup: rbac.authorization.k8s.io
```

#### 2.3 Pod Security Standards
- [ ] **Pod security policies**
```yaml
# security/pod-security-standards.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 3. Kubernetes Manifests

#### 3.1 Frontend Deployment
- [ ] **Frontend Kubernetes manifests**
```yaml
# infrastructure/kubernetes/base/frontend/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: microservices
  labels:
    app: frontend
    tier: presentation
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: presentation
    spec:
      serviceAccountName: microservices-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: frontend
        image: microservices/frontend:latest
        ports:
        - containerPort: 80
          name: http
        env:
        - name: REACT_APP_API_URL
          value: "http://api-gateway:8080"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi" 
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: microservices
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: http
    name: http
  type: ClusterIP
```

#### 3.2 API Gateway Deployment
```yaml
# infrastructure/kubernetes/base/api-gateway/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: microservices
  labels:
    app: api-gateway
    tier: gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
        tier: gateway
    spec:
      serviceAccountName: microservices-sa
      containers:
      - name: api-gateway
        image: microservices/api-gateway:latest
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: USER_SERVICE_URL
          value: "http://user-service:8000"
        - name: PRODUCT_SERVICE_URL
          value: "http://product-service:8080"
        - name: ORDER_SERVICE_URL
          value: "http://order-service:3000"
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: microservices
spec:
  selector:
    app: api-gateway
  ports:
  - port: 8080
    targetPort: http
    name: http
  type: ClusterIP
```

#### 3.3 Database StatefulSet
```yaml
# infrastructure/kubernetes/base/database/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: microservices
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          value: microservices
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: microservices
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: postgres
    name: postgres
  clusterIP: None
```

### 4. Helm Charts

#### 4.1 Helm Chart Structure
- [ ] **Create Helm chart structure**
```bash
# Create Helm charts for each service
mkdir -p infrastructure/helm/microservices
cd infrastructure/helm/microservices
helm create frontend
helm create api-gateway
helm create user-service
helm create product-service
helm create order-service
```

#### 4.2 Main Chart.yaml
```yaml
# infrastructure/helm/microservices/Chart.yaml
apiVersion: v2
name: microservices
description: A Helm chart for microservices deployment pipeline
type: application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  - name: postgresql
    version: "12.1.6"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
    tags:
      - database
  
  - name: redis
    version: "17.4.3"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
    tags:
      - cache
```

#### 4.3 Values Configuration
```yaml
# infrastructure/helm/microservices/values.yaml
global:
  imageRegistry: ghcr.io
  imagePullSecrets:
    - name: regcred
  storageClass: "standard"

frontend:
  enabled: true
  replicaCount: 3
  image:
    repository: microservices/frontend
    tag: "latest"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - host: microservices.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: microservices-tls
        hosts:
          - microservices.example.com
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

apiGateway:
  enabled: true
  replicaCount: 2
  image:
    repository: microservices/api-gateway
    tag: "latest"
  service:
    type: ClusterIP
    port: 8080
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi

userService:
  enabled: true
  replicaCount: 2
  image:
    repository: microservices/user-service
    tag: "latest"
  database:
    host: postgres
    name: userdb

productService:
  enabled: true
  replicaCount: 2
  image:
    repository: microservices/product-service
    tag: "latest"

orderService:
  enabled: true
  replicaCount: 2
  image:
    repository: microservices/order-service
    tag: "latest"

postgresql:
  enabled: true
  auth:
    postgresPassword: "securepassword"
    database: "microservices"
  persistence:
    enabled: true
    size: 10Gi

redis:
  enabled: true
  auth:
    enabled: false
  persistence:
    enabled: true
    size: 5Gi
```

### 5. ArgoCD Setup and Configuration

#### 5.1 ArgoCD Installation
- [ ] **Install ArgoCD**
```bash
#!/bin/bash
# scripts/gitops/install-argocd.sh

# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get initial password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward to access ArgoCD UI
echo "Access ArgoCD at: http://localhost:8080"
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

#### 5.2 ArgoCD Configuration
```yaml
# infrastructure/gitops/argocd-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  repositories: |
    - type: git
      url: https://github.com/your-org/microservices-config
    - type: helm
      name: bitnami
      url: https://charts.bitnami.com/bitnami
  application.instanceLabelKey: argocd.argoproj.io/instance
  server.rbac.log.enforce.enable: "true"
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, certificates, *, *, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    g, microservices-team, role:admin
```

#### 5.3 ArgoCD Applications
```yaml
# infrastructure/gitops/applications/microservices-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: microservices
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/microservices-config
    path: environments/development
    targetRevision: HEAD
    helm:
      valueFiles:
        - values.yaml
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: microservices
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 6. GitOps Repository Structure

#### 6.1 Config Repository Layout
```
microservices-config/
├── applications/
│   ├── microservices.yaml
│   ├── monitoring.yaml
│   └── security.yaml
├── environments/
│   ├── development/
│   │   ├── values.yaml
│   │   └── values-dev.yaml
│   ├── staging/
│   │   ├── values.yaml
│   │   └── values-staging.yaml
│   └── production/
│       ├── values.yaml
│       └── values-prod.yaml
├── manifests/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── resources/
│   └── overlays/
│       ├── development/
│       ├── staging/
│       └── production/
└── policies/
    ├── network-policies.yaml
    ├── pod-security-policies.yaml
    └── resource-quotas.yaml
```

#### 6.2 Environment-specific Values
```yaml
# environments/development/values-dev.yaml
global:
  environment: development
  logLevel: debug

frontend:
  replicaCount: 1
  image:
    tag: "dev-latest"
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi

apiGateway:
  replicaCount: 1
  image:
    tag: "dev-latest"

postgresql:
  persistence:
    size: 5Gi
  resources:
    limits:
      cpu: 200m
      memory: 256Mi

ingress:
  hosts:
    - host: microservices-dev.example.com
```

### 7. Kustomize Configuration

#### 7.1 Base Kustomization
```yaml
# infrastructure/kubernetes/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: microservices

resources:
  - namespaces.yaml
  - rbac.yaml
  - frontend/
  - api-gateway/
  - user-service/
  - product-service/
  - order-service/
  - database/

commonLabels:
  app.kubernetes.io/part-of: microservices
  app.kubernetes.io/managed-by: kustomize

images:
  - name: microservices/frontend
    newTag: latest
  - name: microservices/api-gateway
    newTag: latest
  - name: microservices/user-service
    newTag: latest
  - name: microservices/product-service
    newTag: latest
  - name: microservices/order-service
    newTag: latest
```

#### 7.2 Environment Overlays
```yaml
# infrastructure/kubernetes/overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: microservices-dev

resources:
  - ../../base

patchesStrategicMerge:
  - replica-count.yaml
  - resource-limits.yaml

images:
  - name: microservices/frontend
    newTag: dev-latest
  - name: microservices/api-gateway  
    newTag: dev-latest

commonLabels:
  environment: development

configMapGenerator:
  - name: app-config
    literals:
      - LOG_LEVEL=debug
      - ENVIRONMENT=development
```

### 8. CI/CD Integration with GitOps

#### 8.1 Updated GitHub Actions Workflow
```yaml
# .github/workflows/gitops-deploy.yml
name: GitOps Deployment

on:
  push:
    branches: [ main, develop ]

jobs:
  build-and-update-manifests:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout source code
        uses: actions/checkout@v3
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and push images
        run: |
          # Build and push images (from previous phases)
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          
          for service in frontend api-gateway user-service product-service order-service; do
            docker build -t ${{ secrets.DOCKER_USERNAME }}/$service:${{ github.sha }} services/$service/
            docker push ${{ secrets.DOCKER_USERNAME }}/$service:${{ github.sha }}
          done
      
      - name: Checkout GitOps repository
        uses: actions/checkout@v3
        with:
          repository: your-org/microservices-config
          token: ${{ secrets.GITOPS_TOKEN }}
          path: gitops-repo
      
      - name: Update image tags
        run: |
          cd gitops-repo
          
          # Update image tags in values files
          yq eval '.frontend.image.tag = "${{ github.sha }}"' -i environments/development/values.yaml
          yq eval '.apiGateway.image.tag = "${{ github.sha }}"' -i environments/development/values.yaml
          yq eval '.userService.image.tag = "${{ github.sha }}"' -i environments/development/values.yaml
          yq eval '.productService.image.tag = "${{ github.sha }}"' -i environments/development/values.yaml
          yq eval '.orderService.image.tag = "${{ github.sha }}"' -i environments/development/values.yaml
      
      - name: Commit and push changes
        run: |
          cd gitops-repo
          git config --global user.name 'GitOps Bot'
          git config --global user.email 'gitops@example.com'
          git add .
          git commit -m "Update image tags to ${{ github.sha }}"
          git push
```

### 9. Monitoring and Observability Setup

#### 9.1 Prometheus Configuration
```yaml
# monitoring/prometheus/prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "rules/*.yml"
    
    scrape_configs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
      
      - job_name: 'microservices'
        static_configs:
          - targets:
            - 'frontend:80'
            - 'api-gateway:8080'
            - 'user-service:8000'
            - 'product-service:8080'
            - 'order-service:3000'
```

#### 9.2 Grafana Dashboards
```json
{
  "dashboard": {
    "title": "Microservices Overview",
    "panels": [
      {
        "title": "Service Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"microservices\"}",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{service}}"
          }
        ]
      }
    ]
  }
}
```

### 10. Network Policies and Security

#### 10.1 Network Policies
```yaml
# security/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: microservices-network-policy
  namespace: microservices
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 8080
    - from:
        - podSelector:
            matchLabels:
              app: api-gateway
      ports:
        - protocol: TCP
          port: 8000
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 3000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    - to:
        - podSelector:
            matchLabels:
              app: redis
      ports:
        - protocol: TCP
          port: 6379
    - to: []
      ports:
        - protocol: TCP
          port: 53
        - protocol: UDP
          port: 53
```

## 🧪 Testing Strategy for Kubernetes

### 1. Kubernetes Manifest Testing
- [ ] **kubeval for manifest validation**
```bash
# Install kubeval
curl -L https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz | tar xz
sudo mv kubeval /usr/local/bin

# Test manifests
find infrastructure/kubernetes -name "*.yaml" -exec kubeval {} \;
```

- [ ] **Conftest for policy testing**
```bash
# Install conftest
curl -L https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_linux_x86_64.tar.gz | tar xz
sudo mv conftest /usr/local/bin

# Test policies
conftest test infrastructure/kubernetes/base/
```

### 2. End-to-End Testing
- [ ] **E2E test suite**
```javascript
// tests/e2e/kubernetes.test.js
const kubectl = require('./utils/kubectl');
const { expect } = require('chai');

describe('Kubernetes Deployment Tests', () => {
  before(async () => {
    // Deploy to test namespace
    await kubectl.apply('infrastructure/kubernetes/overlays/test');
  });

  it('should have all pods running', async () => {
    const pods = await kubectl.get('pods -n microservices-test');
    const runningPods = pods.filter(pod => pod.status === 'Running');
    expect(runningPods.length).to.equal(7); // 5 services + postgres + redis
  });

  it('should have all services accessible', async () => {
    const services = ['frontend', 'api-gateway', 'user-service', 'product-service', 'order-service'];
    
    for (const service of services) {
      const response = await kubectl.exec(`pod/${service} -- curl localhost/health`);
      expect(response.status).to.equal('healthy');
    }
  });

  after(async () => {
    // Cleanup
    await kubectl.delete('namespace microservices-test');
  });
});
```

## 📊 Success Metrics for Phase 3

### Technical Metrics
- [ ] **Deployment Success Rate**: 100% of deployments complete successfully
- [ ] **Pod Startup Time**: < 60 seconds for all services
- [ ] **GitOps Sync Time**: < 5 minutes from commit to deployment
- [ ] **Resource Utilization**: < 70% CPU and memory usage
- [ ] **Health Check Response**: < 100ms for all services

### Operational Metrics
- [ ] **Zero Downtime Deployments**: 100% of deployments with zero downtime
- [ ] **Rollback Time**: < 2 minutes for failed deployments
- [ ] **Configuration Drift**: 0% (GitOps ensures consistency)
- [ ] **Security Policy Compliance**: 100% of policies enforced

## 🔧 Troubleshooting Guide

### Common Issues and Solutions

#### 1. Pod Startup Issues
```bash
# Problem: Pods stuck in pending state
kubectl describe pod <pod-name> -n microservices

# Common causes and solutions:
# - Resource constraints: Check node capacity
kubectl top nodes

# - Image pull errors: Check image exists and secrets
kubectl get events -n microservices --sort-by='.lastTimestamp'

# - Security context issues: Check pod security policies
kubectl get psp
```

#### 2. Service Communication Issues
```bash
# Problem: Services can't communicate
# Test service connectivity
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- sh

# Inside the pod:
curl frontend:80/health
curl api-gateway:8080/health

# Check DNS resolution
nslookup frontend
nslookup api-gateway
```

#### 3. GitOps Sync Issues
```bash
# Problem: ArgoCD not syncing
# Check application status
kubectl get applications -n argocd

# Check ArgoCD server logs
kubectl logs deployment/argocd-server -n argocd

# Force sync
argocd app sync microservices
```

## 📚 Key Learnings

### Kubernetes Best Practices
- **Resource Limits**: Always set resource requests and limits
- **Health Checks**: Implement liveness and readiness probes
- **Security Context**: Use non-root users and read-only filesystems
- **Labels and Selectors**: Use consistent labeling strategy

### GitOps Benefits
- **Declarative Configuration**: Infrastructure and applications as code
- **Version Control**: All changes tracked and auditable
- **Automated Deployment**: Continuous deployment without manual intervention
- **Disaster Recovery**: Easy rollback and recovery from git history

## 🎯 Phase 3 Success Criteria

### Technical Achievement
- [ ] Kubernetes cluster operational with proper RBAC
- [ ] All microservices deployed and healthy
- [ ] ArgoCD managing deployments via GitOps
- [ ] Helm charts configured for all services
- [ ] Network policies enforcing security
- [ ] Monitoring and logging operational
- [ ] E2E tests passing

### Portfolio Impact
- [ ] Demonstrated Kubernetes expertise
- [ ] GitOps workflow implemented
- [ ] Production-ready container orchestration
- [ ] Security policies enforced
- [ ] Scalable and maintainable deployment system

---

**Congratulations!** 🚀 You've successfully implemented Kubernetes and GitOps! Your microservices are now running in a production-grade container orchestration platform with automated deployments.

**Next Step**: Proceed to [Phase 4: Advanced Deployment Strategies](04-PHASE4-DEPLOYMENT.md) to implement blue-green deployments, canary releases, and feature flags.