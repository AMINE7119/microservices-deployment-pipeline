# Microservices Deployment Pipeline

> Pipeline CI/CD de niveau production pour une architecture microservices — déploiement multi-cloud, sécurité intégrée, observabilité complète et ingénierie du chaos.

![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=github-actions)
![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-326CE5?logo=kubernetes)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D)
![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Aperçu

Ce projet implémente un pipeline de déploiement complet pour une application microservices, couvrant l'intégralité du cycle DevSecOps : du commit au déploiement production sur plusieurs clouds, avec sécurité automatisée, observabilité distribuée et tests de résilience par chaos engineering.

Le projet est structuré en **8 phases progressives**, chacune ajoutant une couche d'expertise DevOps.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GITHUB ACTIONS CI/CD                     │
│   Code → Lint → Test → Security Scan → Build → Push → Deploy   │
└───────────────────────────────┬─────────────────────────────────┘
                                │ GitOps (ArgoCD)
                ┌───────────────┼───────────────┐
                │               │               │
         ┌──────▼──────┐ ┌──────▼──────┐ ┌─────▼──────┐
         │   AWS EKS   │ │  GCP GKE    │ │   Edge     │
         └──────┬──────┘ └──────┬──────┘ └─────┬──────┘
                └───────────────┼───────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│                         KUBERNETES CLUSTER                       │
│                                                                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                 │
│  │  Frontend  │  │API Gateway │  │User Service│                 │
│  │ (Node.js)  │  │ (Node.js)  │  │  (Python)  │                 │
│  └────────────┘  └────────────┘  └────────────┘                 │
│                                                                  │
│  ┌────────────┐  ┌────────────┐                                  │
│  │  Product   │  │   Order    │                                  │
│  │ Service    │  │  Service   │                                  │
│  │   (Go)     │  │ (Node.js)  │                                  │
│  └────────────┘  └────────────┘                                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  PostgreSQL │ MongoDB │ Redis │ RabbitMQ                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phases d'implémentation

| Phase | Contenu | Statut |
|---|---|---|
| **1 — Foundation** | CI/CD de base, Docker, tests unitaires | Complete |
| **2 — Security** | SAST/DAST, Trivy, Vault, secrets management | Complete |
| **3 — Kubernetes & GitOps** | K8s, Helm, ArgoCD, Kustomize | Complete |
| **4 — Advanced Deployment** | Blue-green, canary, feature flags, rollback automatique | Complete |
| **5 — Observability** | Prometheus, Grafana, Jaeger, Loki, alerting | Complete |
| **6 — Multi-Cloud** | AWS EKS + GCP GKE, cross-cloud networking, edge | Complete |
| **7 — Optimization** | FinOps, spot instances, autoscaling, performance | Complete |
| **8 — Chaos Engineering** | Chaos Mesh, Litmus, disaster recovery automatisé | Complete |

---

## Services

| Service | Langage | Port | Rôle |
|---|---|---|---|
| **Frontend** | Node.js / Express | 3000 | Interface utilisateur |
| **API Gateway** | Node.js / Express | 8080 | Routage et authentification |
| **User Service** | Python / FastAPI | 8000 | Gestion des utilisateurs |
| **Product Service** | Go / Gin | 8001 | Catalogue produits |
| **Order Service** | Node.js / NestJS | 8002 | Gestion des commandes |

---

## Stack technique

### CI/CD & GitOps
| Outil | Usage |
|---|---|
| **GitHub Actions** | Pipelines CI/CD (11 workflows) |
| **ArgoCD** | Déploiements GitOps |
| **Docker / GHCR** | Build et registre d'images |
| **Kustomize / Helm** | Gestion des manifests K8s |

### Infrastructure & Cloud
| Outil | Usage |
|---|---|
| **Terraform** | Infrastructure as Code (AWS + GCP) |
| **AWS EKS** | Cluster Kubernetes managé AWS |
| **GCP GKE** | Cluster Kubernetes managé GCP |
| **Kubernetes** | Orchestration des conteneurs |

### Sécurité (DevSecOps)
| Outil | Usage |
|---|---|
| **Trivy** | Scan de vulnérabilités des images |
| **OWASP ZAP** | Tests DAST |
| **Semgrep / SonarQube** | Analyse statique (SAST) |
| **HashiCorp Vault** | Gestion des secrets |
| **Sealed Secrets** | Secrets chiffrés en git |

### Observabilité
| Outil | Usage |
|---|---|
| **Prometheus** | Collecte de métriques |
| **Grafana** | Dashboards et visualisation |
| **Jaeger** | Tracing distribué |
| **Loki** | Agrégation de logs |
| **AlertManager** | Alerting |

### Chaos Engineering
| Outil | Usage |
|---|---|
| **Chaos Mesh** | Injection de pannes réseau/CPU/mémoire |
| **Litmus** | Scénarios de chaos déclaratifs |
| **k6** | Tests de charge et performance |

---

## Prérequis

- Docker 24+
- Kubernetes 1.27+ (ou minikube / kind pour le local)
- kubectl
- Helm 3+
- Terraform 1.5+
- ArgoCD CLI

---

## Démarrage rapide

### 1. Cloner le projet

```bash
git clone https://github.com/AMINEYANI/microservices-deployment-pipeline.git
cd microservices-deployment-pipeline
```

### 2. Configurer les secrets

Générer les valeurs base64 et renseigner les manifests Kubernetes :

```bash
# Exemple d'encodage
echo -n 'votre-valeur' | base64

# Appliquer les secrets après les avoir renseignés
kubectl apply -f kubernetes/base/user-service/secrets.yaml
kubectl apply -f kubernetes/base/order-service/secrets.yaml
kubectl apply -f kubernetes/base/product-service/secrets.yaml
```

### 3. Déploiement local (Docker Compose)

```bash
docker-compose up -d
```

| Service | URL |
|---|---|
| Frontend | http://localhost:3000 |
| API Gateway | http://localhost:8080 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3001 |

### 4. Déploiement Kubernetes

```bash
kubectl create namespace microservices-dev
kubectl apply -f databases/ -n microservices-dev
kubectl apply -f kubernetes/base/ -n microservices-dev
kubectl get pods -n microservices-dev
```

### 5. Déploiement via ArgoCD (GitOps)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/app-of-apps/
```

### 6. Infrastructure multi-cloud (Terraform)

```bash
# AWS EKS
cd infrastructure/terraform/environments/aws
terraform init && terraform apply

# GCP GKE
cd infrastructure/terraform/environments/gcp
terraform init && terraform apply
```

---

## CI/CD Pipeline

```
Push → Code Quality → Unit Tests → Security Scan (SAST/DAST/Trivy)
     → Build Images → Push to GHCR → Deploy to Staging
     → Integration Tests → Blue-Green Deploy to Production
     → Smoke Tests → Rollback automatique si échec
```

Secrets GitHub Actions à configurer :

```
GHCR_TOKEN               # Token GitHub Container Registry
GCP_SERVICE_ACCOUNT_KEY  # Clé service account GCP (base64)
KUBECONFIG               # kubeconfig encodé en base64
SLACK_WEBHOOK_URL        # Notifications Slack (optionnel)
```

---

## Stratégies de déploiement

### Blue-Green
```bash
kubectl apply -f kubernetes/blue-green/
```

### Canary
```bash
kubectl apply -f kubernetes/canary/
```

Le canary démarre à 10% du trafic et progresse automatiquement selon les métriques Prometheus.

---

## Observabilité

| Dashboard | URL locale | Description |
|---|---|---|
| Grafana | http://localhost:3001 | Dashboards métriques |
| Prometheus | http://localhost:9090 | Métriques brutes |
| Jaeger | http://localhost:16686 | Tracing distribué |
| ArgoCD | http://localhost:8090 | Statut GitOps |

---

## Chaos Engineering

```bash
# Test de panne réseau
kubectl apply -f chaos-engineering/chaos-mesh/network-failure.yaml

# Test de pression mémoire
kubectl apply -f chaos-engineering/chaos-mesh/memory-pressure.yaml

# Disaster recovery automatisé
bash chaos-engineering/disaster-recovery/auto-recovery.sh
```

---

## Structure du projet

```
microservices-deployment-pipeline/
├── .github/
│   ├── workflows/          # 11 pipelines CI/CD
│   └── SECURITY.md
├── argocd/                 # Configuration GitOps
├── chaos-engineering/      # Tests de résilience
├── databases/              # PostgreSQL, MongoDB, Redis, RabbitMQ
├── infrastructure/
│   └── terraform/          # IaC AWS + GCP
├── kubernetes/
│   ├── base/               # Déploiements de base (5 services)
│   ├── blue-green/         # Déploiement blue-green
│   ├── canary/             # Déploiement canary
│   ├── monitoring/         # Stack observabilité
│   └── multi-cloud/        # Config multi-cloud
├── monitoring/             # Prometheus, Grafana, Jaeger, Loki
├── optimization/           # FinOps, performance
├── scripts/                # Scripts d'automatisation
├── security/               # Vault, OWASP ZAP
├── services/
│   ├── frontend/           # Node.js
│   ├── api-gateway/        # Node.js
│   ├── user-service/       # Python / FastAPI
│   ├── product-service/    # Go / Gin
│   └── order-service/      # Node.js / NestJS
└── tests/                  # Tests unitaires, intégration, e2e
```

---

## Métriques cibles

| Indicateur | Objectif |
|---|---|
| Fréquence de déploiement | 50+ déploiements / jour |
| Lead time commit → production | < 15 minutes |
| MTTR (temps de récupération) | < 10 minutes |
| Taux d'échec des déploiements | < 1% |
| Couverture de tests | > 90% |
| Disponibilité | 99.99% |

---

## Auteur

**Amine YANI** — [GitHub](https://github.com/AMINEYANI)

---

## Licence

Ce projet est sous licence [MIT](LICENSE).
