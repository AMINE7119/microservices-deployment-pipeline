# Phase 2: Security Integration (DevSecOps)

## 🎯 Phase Objective
Implement comprehensive security scanning and compliance throughout the entire CI/CD pipeline. This phase transforms your basic pipeline into a DevSecOps pipeline with shift-left security practices, automated vulnerability detection, secrets management, and security policy enforcement.

## ⏱️ Timeline
**Estimated Duration**: 1-2 weeks
**Prerequisites**: Phase 1 (Foundation Setup) completed successfully

## 🏗️ Security Architecture for This Phase

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DEVSECOPS PIPELINE ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Developer → GitHub → Pre-commit → GitHub Actions → Security Gates → Deploy│
│      │          │         │             │              │            │       │
│   Git Push   Triggers  Git Hooks    Build & Test   Security Scans  Registry │
│              Workflow  (Secrets)    Each Service   (Multi-layer)   (Signed) │
│                           │             │              │            │       │
│                      Secret Scan    Unit Tests     SAST/DAST    Vuln Report │
│                      Commit Block   Integration    Container     Dashboard   │
│                                     Tests          Scanning                  │
│                                                       │                     │
│                                                  Policy Gates               │
│                                                  (OPA/Gatekeeper)           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY SCANNING LAYERS                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Layer 1: Source Code (SAST)                                              │
│  ├── SonarQube: Code quality, security hotspots, vulnerabilities          │
│  ├── Semgrep: Custom security rules, OWASP Top 10 detection              │
│  ├── CodeQL: Advanced semantic analysis                                   │
│  └── Bandit/ESLint Security: Language-specific security linting          │
│                                                                             │
│  Layer 2: Dependencies (SCA)                                              │
│  ├── Snyk: Vulnerability database, license compliance                     │
│  ├── Safety (Python): Python package vulnerabilities                     │
│  ├── npm audit: Node.js dependency scanning                              │
│  └── Go modules: Go dependency vulnerability checking                     │
│                                                                             │
│  Layer 3: Container Images                                                │
│  ├── Trivy: Comprehensive container scanning                              │
│  ├── Grype: Fast vulnerability scanner                                    │
│  ├── Docker Scout: Docker native scanning                                │
│  └── Clair: Container vulnerability analysis                             │
│                                                                             │
│  Layer 4: Infrastructure (IaC)                                           │
│  ├── Checkov: Terraform/CloudFormation scanning                          │
│  ├── tfsec: Terraform security scanner                                   │
│  ├── Terrascan: IaC security scanner                                     │
│  └── kube-score: Kubernetes manifest scoring                             │
│                                                                             │
│  Layer 5: Runtime (DAST)                                                 │
│  ├── OWASP ZAP: Dynamic application security testing                     │
│  ├── Nikto: Web server scanner                                           │
│  └── Custom security tests                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📋 Detailed Implementation Checklist

### 1. Pre-commit Security Hooks

#### 1.1 Install and Configure Pre-commit
- [ ] **Install pre-commit framework**
```bash
# Install pre-commit
pip install pre-commit

# Create pre-commit configuration
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: detect-private-key
      - id: detect-aws-credentials

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint-docker

  - repo: https://github.com/bridgecrewio/checkov
    rev: 2.3.228
    hooks:
      - id: checkov
        args: [--framework, terraform, --framework, dockerfile]

  - repo: local
    hooks:
      - id: gitleaks
        name: Detect hardcoded secrets
        entry: gitleaks
        language: system
        args: ['detect', '--source', '.', '-v']
EOF

# Install hooks
pre-commit install
```

#### 1.2 Configure Secret Detection Baseline
- [ ] **Create secrets baseline**
```bash
# Generate baseline for existing secrets (if any)
detect-secrets scan --baseline .secrets.baseline

# Add to .gitignore
echo ".secrets.baseline" >> .gitignore
```

#### 1.3 Set up Git Hooks
- [ ] **Configure commit-msg hook**
```bash
#!/bin/sh
# .git/hooks/commit-msg

# Check commit message format
commit_regex='^(feat|fix|docs|style|refactor|test|chore|security)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Invalid commit message format!"
    echo "Format: type(scope): description"
    echo "Types: feat, fix, docs, style, refactor, test, chore, security"
    exit 1
fi
```

### 2. Static Application Security Testing (SAST)

#### 2.1 SonarQube Setup
- [ ] **SonarQube configuration**
```yaml
# .github/workflows/sonarqube.yml
name: SonarQube Analysis

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  sonarqube:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: SonarQube Scan
        uses: sonarqube-quality-gate-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        with:
          args: >
            -Dsonar.projectKey=microservices-pipeline
            -Dsonar.sources=services/
            -Dsonar.tests=services/
            -Dsonar.test.inclusions=**/*test*/**,**/*spec*/**
            -Dsonar.exclusions=**/node_modules/**,**/vendor/**
            -Dsonar.javascript.lcov.reportPaths=services/*/coverage/lcov.info
            -Dsonar.python.coverage.reportPaths=services/*/coverage.xml
            -Dsonar.go.coverage.reportPaths=services/*/coverage.out
```

- [ ] **SonarQube properties file**
```properties
# sonar-project.properties
sonar.projectKey=microservices-deployment-pipeline
sonar.projectName=Microservices Deployment Pipeline
sonar.projectVersion=1.0

# Source and test directories
sonar.sources=services/
sonar.tests=services/
sonar.test.inclusions=**/*test*/**,**/*spec*/**

# Exclusions
sonar.exclusions=**/node_modules/**,**/vendor/**,**/*.pb.go,**/mock_*.go

# Language-specific settings
sonar.javascript.lcov.reportPaths=services/frontend/coverage/lcov.info,services/api-gateway/coverage/lcov.info
sonar.python.coverage.reportPaths=services/user-service/coverage.xml
sonar.go.coverage.reportPaths=services/product-service/coverage.out

# Security settings
sonar.security.hotspots.failMergeRequestOnOpen=true
```

#### 2.2 Semgrep Configuration
- [ ] **Semgrep rules setup**
```yaml
# .semgrep.yml
rules:
  - id: hardcoded-secret
    patterns:
      - pattern-either:
          - pattern: password = "..."
          - pattern: api_key = "..."
          - pattern: secret = "..."
          - pattern: token = "..."
    message: "Potential hardcoded secret detected"
    languages: [python, javascript, typescript, go]
    severity: ERROR

  - id: sql-injection
    patterns:
      - pattern: $DB.execute($QUERY + $INPUT)
      - pattern: $DB.query($QUERY + $INPUT)
    message: "Potential SQL injection vulnerability"
    languages: [python, javascript, go]
    severity: ERROR

  - id: xss-vulnerability
    patterns:
      - pattern: innerHTML = $INPUT
      - pattern: document.write($INPUT)
    message: "Potential XSS vulnerability"
    languages: [javascript, typescript]
    severity: ERROR

  - id: insecure-random
    patterns:
      - pattern: Math.random()
      - pattern: random.random()
    message: "Use cryptographically secure random number generator"
    languages: [javascript, python]
    severity: WARNING
```

#### 2.3 Language-Specific Security Linting

**Python (Bandit)**
```bash
# services/user-service/.bandit
[bandit]
exclude_dirs = tests,venv
skips = B101,B601

# Add to requirements-dev.txt
bandit==1.7.5
safety==2.3.4
```

**JavaScript/TypeScript (ESLint Security)**
```json
// services/frontend/.eslintrc.js
module.exports = {
  extends: [
    '@eslint/js/recommended',
    'plugin:security/recommended',
    'plugin:react-hooks/recommended'
  ],
  plugins: ['security'],
  rules: {
    'security/detect-object-injection': 'error',
    'security/detect-non-literal-fs-filename': 'error',
    'security/detect-eval-with-expression': 'error',
    'security/detect-non-literal-regexp': 'error'
  }
}
```

**Go (gosec)**
```bash
# Install gosec
go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest

# Configuration file: .gosec.json
{
  "severity": "medium",
  "confidence": "medium",
  "exclude": ["G101", "G104"],
  "include": ["G201", "G202", "G203", "G204"]
}
```

### 3. Software Composition Analysis (SCA)

#### 3.1 Dependency Vulnerability Scanning
- [ ] **Node.js projects**
```json
// package.json security scripts
{
  "scripts": {
    "security:audit": "npm audit --audit-level moderate",
    "security:fix": "npm audit fix",
    "security:snyk": "snyk test",
    "security:all": "npm run security:audit && npm run security:snyk"
  },
  "devDependencies": {
    "snyk": "^1.1200.0"
  }
}
```

- [ ] **Python projects**
```bash
# services/user-service/requirements-security.txt
safety==2.3.4
pip-audit==2.6.1

# Add to CI pipeline
pip-audit --requirement requirements.txt --format json --output security-report.json
safety check --requirement requirements.txt --json --output safety-report.json
```

- [ ] **Go projects**
```bash
# Install govulncheck
go install golang.org/x/vuln/cmd/govulncheck@latest

# Add to CI pipeline
govulncheck ./...
```

#### 3.2 License Compliance
- [ ] **License scanning configuration**
```yaml
# .github/workflows/license-check.yml
name: License Compliance

on:
  push:
    branches: [ main, develop ]

jobs:
  license-check:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Check Node.js Licenses
        run: |
          cd services/frontend
          npx license-checker --onlyAllow "MIT;Apache-2.0;BSD-2-Clause;BSD-3-Clause;ISC"
          
      - name: Check Python Licenses
        run: |
          cd services/user-service
          pip install pip-licenses
          pip-licenses --allow-only="MIT;Apache Software License;BSD License"
```

### 4. Container Security

#### 4.1 Trivy Container Scanning
- [ ] **Trivy configuration**
```yaml
# .github/workflows/container-security.yml
name: Container Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  container-scan:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        service: [frontend, api-gateway, user-service, product-service, order-service]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: |
          docker build -t ${{ matrix.service }}:${{ github.sha }} services/${{ matrix.service }}
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: '${{ matrix.service }}:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results-${{ matrix.service }}.sarif'
          severity: 'CRITICAL,HIGH,MEDIUM'
      
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results-${{ matrix.service }}.sarif'
      
      - name: Check for vulnerabilities
        run: |
          trivy image --exit-code 1 --severity CRITICAL,HIGH ${{ matrix.service }}:${{ github.sha }}
```

#### 4.2 Dockerfile Security Best Practices
- [ ] **Secure Dockerfile template**
```dockerfile
# Security-hardened Dockerfile template
FROM node:18-alpine AS builder

# Create non-root user early
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory with proper permissions
WORKDIR /app
RUN chown -R nodejs:nodejs /app

# Install dependencies as non-root
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force && \
    rm -rf /tmp/*

# Copy source code
COPY --chown=nodejs:nodejs . .

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

# Security updates and minimal packages
RUN apk update && \
    apk upgrade && \
    apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app
RUN chown -R nodejs:nodejs /app

# Copy only necessary files
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Switch to non-root user
USER nodejs

# Use specific port
EXPOSE 3000

# Use exec form for signal handling
CMD ["node", "dist/server.js"]
```

#### 4.3 Docker Bench Security
- [ ] **Docker security benchmarking**
```bash
# Add Docker Bench Security to CI
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
docker-compose run --rm docker-bench-security
```

### 5. Infrastructure as Code Security

#### 5.1 Terraform Security Scanning
- [ ] **tfsec configuration**
```yaml
# .github/workflows/terraform-security.yml
name: Terraform Security

on:
  push:
    paths:
      - 'infrastructure/terraform/**'
  pull_request:
    paths:
      - 'infrastructure/terraform/**'

jobs:
  terraform-security:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: infrastructure/terraform
          format: sarif
          sarif_file: tfsec.sarif
      
      - name: Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: infrastructure/terraform
          framework: terraform
          output_format: sarif
          output_file_path: checkov.sarif
      
      - name: Upload results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: tfsec.sarif
```

#### 5.2 Kubernetes Security Policies
- [ ] **Pod Security Standards**
```yaml
# security/policies/pod-security-policy.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

- [ ] **Network Policies**
```yaml
# security/policies/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: microservices-network-policy
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
```

### 6. Secret Management

#### 6.1 HashiCorp Vault Setup
- [ ] **Vault configuration for development**
```yaml
# docker-compose.vault.yml
version: '3.8'

services:
  vault:
    image: vault:latest
    container_name: vault
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: myroot
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    command: vault server -dev
    volumes:
      - vault-data:/vault/data

  vault-init:
    image: vault:latest
    depends_on:
      - vault
    environment:
      VAULT_ADDR: http://vault:8200
      VAULT_TOKEN: myroot
    volumes:
      - ./security/vault-init.sh:/vault-init.sh
    command: /vault-init.sh

volumes:
  vault-data:
```

- [ ] **Vault initialization script**
```bash
#!/bin/bash
# security/vault-init.sh

# Wait for Vault to be ready
sleep 5

# Enable KV engine
vault secrets enable -path=microservices kv-v2

# Create secrets
vault kv put microservices/database \
  username="dbuser" \
  password="securepassword"

vault kv put microservices/jwt \
  secret="jwt-secret-key"

# Create policy
vault policy write microservices-policy - <<EOF
path "microservices/*" {
  capabilities = ["read", "list"]
}
EOF

# Create token with policy
vault token create -policy=microservices-policy -ttl=1h
```

#### 6.2 Kubernetes Secret Management
- [ ] **External Secrets Operator**
```yaml
# security/external-secrets-operator.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault:8200"
      path: "microservices"
      version: "v2"
      auth:
        tokenSecretRef:
          name: "vault-token"
          key: "token"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: database
      property: username
  - secretKey: password
    remoteRef:
      key: database
      property: password
```

### 7. Dynamic Application Security Testing (DAST)

#### 7.1 OWASP ZAP Integration
- [ ] **ZAP baseline scan**
```yaml
# .github/workflows/dast.yml
name: DAST Security Testing

on:
  push:
    branches: [ main, develop ]
  schedule:
    - cron: '0 2 * * *'  # Run nightly

jobs:
  dast-scan:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Start services
        run: |
          docker-compose up -d
          sleep 60  # Wait for services to be ready
      
      - name: ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.7.0
        with:
          target: 'http://localhost:3000'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
      
      - name: ZAP Full Scan
        uses: zaproxy/action-full-scan@v0.4.0
        with:
          target: 'http://localhost:8080'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
```

- [ ] **ZAP rules configuration**
```tsv
# .zap/rules.tsv
10003	IGNORE	(Vulnerable JS Library)
10010	IGNORE	(Cookie No HttpOnly Flag)
10011	IGNORE	(Cookie Without Secure Flag)
```

#### 7.2 Custom Security Tests
- [ ] **API security tests**
```javascript
// tests/security/api-security.test.js
const request = require('supertest');
const app = require('../../services/api-gateway/src/app');

describe('API Security Tests', () => {
  test('should prevent SQL injection', async () => {
    const maliciousInput = "'; DROP TABLE users; --";
    
    const response = await request(app)
      .get(`/api/users?search=${encodeURIComponent(maliciousInput)}`)
      .expect(400);
      
    expect(response.body.error).toMatch(/invalid input/i);
  });
  
  test('should rate limit requests', async () => {
    const requests = Array(110).fill().map(() =>
      request(app).get('/api/health')
    );
    
    const responses = await Promise.all(requests);
    const rateLimitedResponses = responses.filter(r => r.status === 429);
    
    expect(rateLimitedResponses.length).toBeGreaterThan(0);
  });
  
  test('should validate JWT tokens', async () => {
    const response = await request(app)
      .get('/api/users/profile')
      .expect(401);
      
    expect(response.body.error).toMatch(/unauthorized/i);
  });
});
```

### 8. Compliance and Reporting

#### 8.1 Security Dashboard
- [ ] **Security metrics dashboard**
```python
# scripts/security/security-dashboard.py
import json
import requests
from datetime import datetime

class SecurityDashboard:
    def __init__(self):
        self.metrics = {
            'vulnerabilities': {'critical': 0, 'high': 0, 'medium': 0, 'low': 0},
            'dependencies': {'total': 0, 'vulnerable': 0},
            'containers': {'scanned': 0, 'vulnerable': 0},
            'compliance': {'score': 0, 'checks_passed': 0, 'total_checks': 0}
        }
    
    def collect_sonarqube_metrics(self):
        """Collect metrics from SonarQube API"""
        url = f"{SONAR_URL}/api/measures/component"
        params = {
            'component': 'microservices-pipeline',
            'metricKeys': 'vulnerabilities,security_hotspots,reliability_rating'
        }
        response = requests.get(url, params=params, auth=(SONAR_TOKEN, ''))
        return response.json()
    
    def collect_trivy_metrics(self):
        """Parse Trivy scan results"""
        with open('trivy-results.json', 'r') as f:
            results = json.load(f)
            
        for result in results:
            for vuln in result.get('Vulnerabilities', []):
                severity = vuln.get('Severity', '').lower()
                if severity in self.metrics['vulnerabilities']:
                    self.metrics['vulnerabilities'][severity] += 1
    
    def generate_report(self):
        """Generate security report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'metrics': self.metrics,
            'recommendations': self.get_recommendations()
        }
        
        with open('security-report.json', 'w') as f:
            json.dump(report, f, indent=2)
    
    def get_recommendations(self):
        """Generate security recommendations"""
        recommendations = []
        
        if self.metrics['vulnerabilities']['critical'] > 0:
            recommendations.append("Address critical vulnerabilities immediately")
            
        if self.metrics['vulnerabilities']['high'] > 5:
            recommendations.append("High vulnerability count needs attention")
            
        return recommendations

if __name__ == '__main__':
    dashboard = SecurityDashboard()
    dashboard.collect_sonarqube_metrics()
    dashboard.collect_trivy_metrics()
    dashboard.generate_report()
```

#### 8.2 Compliance Checks
- [ ] **OWASP compliance checking**
```bash
#!/bin/bash
# scripts/security/compliance-check.sh

echo "Running OWASP Top 10 compliance checks..."

# A1 - Injection
echo "Checking for injection vulnerabilities..."
semgrep --config=r/owasp-top-ten.sql-injection services/

# A2 - Broken Authentication
echo "Checking authentication implementation..."
semgrep --config=r/owasp-top-ten.broken-authn services/

# A3 - Sensitive Data Exposure
echo "Checking for sensitive data exposure..."
semgrep --config=r/owasp-top-ten.sensitive-data services/

# A4 - XML External Entities
echo "Checking for XXE vulnerabilities..."
semgrep --config=r/owasp-top-ten.xxe services/

# A5 - Broken Access Control
echo "Checking access controls..."
semgrep --config=r/owasp-top-ten.broken-access services/

# A6 - Security Misconfiguration
echo "Checking for misconfigurations..."
checkov -d infrastructure/ --framework terraform

# A7 - Cross-Site Scripting
echo "Checking for XSS vulnerabilities..."
semgrep --config=r/owasp-top-ten.xss services/

# A8 - Insecure Deserialization
echo "Checking deserialization..."
semgrep --config=r/owasp-top-ten.insecure-deserialization services/

# A9 - Using Components with Known Vulnerabilities
echo "Checking vulnerable dependencies..."
npm audit --audit-level high
pip-audit
govulncheck ./...

# A10 - Insufficient Logging & Monitoring
echo "Checking logging implementation..."
grep -r "logger\|log\|console.log" services/ | wc -l
```

### 9. Security Pipeline Integration

#### 9.1 Enhanced CI/CD with Security Gates
- [ ] **Complete security pipeline**
```yaml
# .github/workflows/security-pipeline.yml
name: Security Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  security-scan:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      # Secret scanning
      - name: Run secret scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: main
          head: HEAD
      
      # SAST scanning
      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            r/owasp-top-ten
            r/security-audit
            .semgrep.yml
      
      # Dependency scanning
      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high
      
      # Code quality and security
      - name: SonarQube Scan
        uses: sonarqube-quality-gate-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      
      # Container scanning
      - name: Build and scan images
        run: |
          for service in frontend api-gateway user-service product-service order-service; do
            docker build -t $service:latest services/$service/
            trivy image --exit-code 1 --severity HIGH,CRITICAL $service:latest
          done
      
      # Infrastructure scanning
      - name: Terraform security scan
        run: |
          if [ -d "infrastructure/terraform" ]; then
            tfsec infrastructure/terraform/
            checkov -d infrastructure/terraform/
          fi
      
      # Compliance check
      - name: Run compliance checks
        run: |
          chmod +x scripts/security/compliance-check.sh
          ./scripts/security/compliance-check.sh
      
      # Generate security report
      - name: Generate security report
        run: |
          python scripts/security/security-dashboard.py
      
      - name: Upload security report
        uses: actions/upload-artifact@v3
        with:
          name: security-report
          path: security-report.json

  dast-scan:
    needs: security-scan
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Start application
        run: |
          docker-compose up -d
          sleep 60
      
      - name: Wait for services
        run: |
          curl --retry 10 --retry-delay 5 http://localhost:3000/health
          curl --retry 10 --retry-delay 5 http://localhost:8080/health
      
      - name: OWASP ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.7.0
        with:
          target: 'http://localhost:3000'
      
      - name: OWASP ZAP API Scan
        uses: zaproxy/action-api-scan@v0.1.0
        with:
          target: 'http://localhost:8080'
          format: openapi
          api_definition: 'api-spec.json'

  security-gate:
    needs: [security-scan, dast-scan]
    runs-on: ubuntu-latest
    
    steps:
      - name: Security Gate Check
        run: |
          echo "All security scans completed successfully!"
          echo "Security gate passed ✅"
```

#### 9.2 Security Quality Gates
- [ ] **Quality gate configuration**
```yaml
# .github/security-gate.yml
quality_gates:
  vulnerabilities:
    critical: 0    # No critical vulnerabilities allowed
    high: 2        # Max 2 high severity vulnerabilities
    medium: 10     # Max 10 medium severity vulnerabilities
    
  dependencies:
    vulnerable_threshold: 5%  # Max 5% vulnerable dependencies
    
  code_coverage:
    minimum: 80%   # Minimum 80% test coverage
    
  sonarqube:
    quality_gate: "Passed"
    security_rating: "A"
    reliability_rating: "A"
    
  containers:
    critical_vulns: 0
    high_vulns: 1
    
  compliance:
    owasp_score: 85%   # Minimum OWASP compliance score
```

## 🧪 Security Testing Strategy

### 1. Security Test Pyramid
```
┌─────────────────────────────────────────────────────────────┐
│                    Security Test Pyramid                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🔺 Manual Penetration Testing                             │
│     ├── Red team exercises                                 │
│     ├── Social engineering tests                           │
│     └── Physical security audits                           │
│                                                             │
│  🔸 Dynamic Testing (DAST)                                 │
│     ├── OWASP ZAP scans                                   │
│     ├── API security testing                              │
│     ├── Authentication bypass tests                       │
│     └── Input validation testing                          │
│                                                             │
│  🔹 Static Testing (SAST)                                 │
│     ├── Code analysis (SonarQube, Semgrep)               │
│     ├── Dependency scanning (Snyk, Safety)               │
│     ├── Container scanning (Trivy, Grype)                │
│     └── Infrastructure scanning (Checkov, tfsec)         │
│                                                             │
│  🔻 Unit Security Tests                                   │
│     ├── Input validation tests                            │
│     ├── Authentication unit tests                         │
│     ├── Authorization unit tests                          │
│     └── Encryption/decryption tests                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Security Test Cases
- [ ] **Authentication tests**
- [ ] **Authorization tests** 
- [ ] **Input validation tests**
- [ ] **SQL injection prevention tests**
- [ ] **XSS prevention tests**
- [ ] **CSRF protection tests**
- [ ] **Rate limiting tests**
- [ ] **Encryption tests**

## 📊 Security Metrics and KPIs

### Technical Security Metrics
- [ ] **Vulnerability Metrics**
  - Critical vulnerabilities: 0
  - High vulnerabilities: < 2
  - Medium vulnerabilities: < 10
  - Vulnerability remediation time: < 24 hours for critical

- [ ] **Dependency Health**
  - Vulnerable dependencies: < 5%
  - Dependency freshness: > 80% up-to-date
  - License compliance: 100%

- [ ] **Container Security**
  - Base image vulnerabilities: 0 critical
  - Secret detection: 100% coverage
  - Image signing: 100% of production images

- [ ] **Code Quality Security**
  - SonarQube security rating: A
  - Security test coverage: > 90%
  - Security hotspots: 0

### Process Security Metrics
- [ ] **Pipeline Security**
  - Security scan coverage: 100% of commits
  - Security gate pass rate: > 95%
  - False positive rate: < 10%

- [ ] **Compliance Metrics**
  - OWASP Top 10 coverage: 100%
  - Policy compliance: 100%
  - Audit findings: 0 critical

## 🔧 Troubleshooting Security Issues

### Common Security Issues and Solutions

#### 1. High Number of Vulnerabilities
```bash
# Problem: Too many vulnerabilities failing the build
# Solution: Implement gradual improvement

# Create baseline
trivy image --format json --output baseline.json myapp:latest

# Compare against baseline
trivy image --format json myapp:latest | jq '.Results[].Vulnerabilities | length'
```

#### 2. False Positive Management
```yaml
# Problem: False positives blocking pipeline
# Solution: Configure suppression rules

# .trivyignore
CVE-2021-44228  # Log4j - not applicable to our Go service
CVE-2022-1234   # False positive in dev dependency
```

#### 3. Secrets Detection Issues
```bash
# Problem: Secrets detected in code
# Solution: Implement proper secret management

# Remove secrets from history
git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch path/to/secret-file' --prune-empty --tag-name-filter cat -- --all

# Update .gitignore
echo "*.key\n*.pem\n*.env" >> .gitignore
```

## 📚 Key Security Learnings

### Security Architecture Decisions
- **Defense in Depth**: Multiple layers of security controls
- **Shift-Left Security**: Integrate security early in development
- **Zero Trust**: Never trust, always verify
- **Principle of Least Privilege**: Minimal necessary permissions

### DevSecOps Best Practices
- **Automate Security**: Make security checks automatic
- **Security as Code**: Version control security policies
- **Continuous Monitoring**: Security is ongoing, not one-time
- **Security Training**: Educate development team

## 🎯 Phase 2 Success Criteria

### Technical Achievement
- [ ] All security scans integrated into CI/CD pipeline
- [ ] Zero critical and high vulnerabilities in production
- [ ] 100% of containers scanned and secured
- [ ] Secret management implemented
- [ ] Security policies as code deployed
- [ ] DAST testing automated
- [ ] Security dashboard operational

### Portfolio Impact
- [ ] Demonstrable security metrics improvement
- [ ] Comprehensive security documentation
- [ ] Security incident response procedures
- [ ] Compliance reporting automated
- [ ] Security testing integrated into development workflow

---

**Congratulations!** 🔒 You've successfully implemented comprehensive DevSecOps practices. Your pipeline now has enterprise-grade security integrated at every layer.

**Next Step**: Proceed to [Phase 3: Kubernetes & GitOps](03-PHASE3-KUBERNETES.md) to deploy your secured applications to Kubernetes with GitOps workflows.