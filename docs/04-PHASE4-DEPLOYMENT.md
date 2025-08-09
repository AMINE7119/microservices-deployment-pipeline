# Phase 4: Advanced Deployment Strategies

## 🎯 Phase Objective
Implement sophisticated deployment patterns including blue-green deployments, canary releases, feature flags, and A/B testing. This phase transforms basic deployments into production-grade progressive delivery with automated rollback capabilities.

## ⏱️ Timeline
**Estimated Duration**: 2-3 weeks
**Prerequisites**: Phase 3 (Kubernetes & GitOps) completed successfully

## 🏗️ Advanced Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PROGRESSIVE DELIVERY ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐         │
│  │  BLUE-GREEN     │    │   CANARY        │    │   A/B TESTING   │         │
│  │  DEPLOYMENT     │    │   RELEASES      │    │   & FEATURES    │         │
│  │                 │    │                 │    │                 │         │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │         │
│  │  │   Blue    │  │    │  │ Canary 5% │  │    │  │Feature A  │  │         │
│  │  │Environment│  │    │  │    ↓      │  │    │  │    50%    │  │         │
│  │  │   100%    │  │    │  │ Stable95% │  │    │  │Feature B  │  │         │
│  │  └───────────┘  │    │  └───────────┘  │    │  │    50%    │  │         │
│  │         ↕       │    │       ↕         │    │  └───────────┘  │         │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │       ↕         │         │
│  │  │   Green   │  │    │  │ Metrics   │  │    │  ┌───────────┐  │         │
│  │  │Environment│  │    │  │Monitoring │  │    │  │   Rules   │  │         │
│  │  │    0%     │  │    │  │& Analysis │  │    │  │  Engine   │  │         │
│  │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │         │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘         │
│           │                       │                       │                │
│           └───────────────────────┼───────────────────────┘                │
│                                   │                                        │
│                                   ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        TRAFFIC MANAGEMENT                               │ │
│  │                                                                         │ │
│  │  Istio Service Mesh │ Nginx Ingress │ AWS ALB │ Traffic Splitting      │ │
│  │  Circuit Breakers │ Retry Logic │ Timeouts │ Load Balancing            │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                   │                                        │
│                                   ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                      AUTOMATED DECISION MAKING                         │ │
│  │                                                                         │ │
│  │  Prometheus Metrics → Flagger → Deployment Decision → Rollback/Promote  │ │
│  │  Success Rate      → Analysis→ Traffic Shifting    → Auto Recovery     │ │
│  │  Error Rate        →        → Health Checks       → Notifications     │ │
│  │  Response Time     →        → SLO Validation      → Audit Trail       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📋 Detailed Implementation Checklist

### 1. Blue-Green Deployment Setup

#### 1.1 Blue-Green Infrastructure
- [ ] **Configure dual environments**
```yaml
# infrastructure/kubernetes/blue-green/blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: microservices-blue
  namespace: microservices
  labels:
    app: microservices
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: microservices
      version: blue
  template:
    metadata:
      labels:
        app: microservices
        version: blue
    spec:
      containers:
      - name: frontend
        image: microservices/frontend:stable
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "blue"
        - name: ENVIRONMENT
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
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: microservices-green
  namespace: microservices
  labels:
    app: microservices
    version: green
spec:
  replicas: 0  # Initially scaled to 0
  selector:
    matchLabels:
      app: microservices
      version: green
  template:
    metadata:
      labels:
        app: microservices
        version: green
    spec:
      containers:
      - name: frontend
        image: microservices/frontend:latest
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "green"
        - name: ENVIRONMENT
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
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### 1.2 Traffic Switching Service
```yaml
# infrastructure/kubernetes/blue-green/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: microservices
  namespace: microservices
  labels:
    app: microservices
spec:
  selector:
    app: microservices
    version: blue  # Initially points to blue
  ports:
  - port: 80
    targetPort: 80
    name: http
  type: ClusterIP
```

#### 1.3 Blue-Green Deployment Script
```bash
#!/bin/bash
# scripts/deployment/blue-green-deploy.sh

set -e

NAMESPACE="microservices"
NEW_IMAGE="$1"
CURRENT_VERSION=$(kubectl get service microservices -n $NAMESPACE -o jsonpath='{.spec.selector.version}')
NEW_VERSION="green"

if [ "$CURRENT_VERSION" == "green" ]; then
    NEW_VERSION="blue"
fi

echo "Current version: $CURRENT_VERSION"
echo "Deploying to: $NEW_VERSION"
echo "New image: $NEW_IMAGE"

# Step 1: Update the new environment
echo "Updating $NEW_VERSION environment..."
kubectl set image deployment/microservices-$NEW_VERSION frontend=$NEW_IMAGE -n $NAMESPACE

# Step 2: Scale up new environment
echo "Scaling up $NEW_VERSION environment..."
kubectl scale deployment microservices-$NEW_VERSION --replicas=3 -n $NAMESPACE

# Step 3: Wait for rollout to complete
echo "Waiting for $NEW_VERSION deployment to be ready..."
kubectl rollout status deployment/microservices-$NEW_VERSION -n $NAMESPACE --timeout=300s

# Step 4: Run health checks
echo "Running health checks..."
for i in {1..10}; do
    if kubectl exec -n $NAMESPACE deployment/microservices-$NEW_VERSION -- curl -f http://localhost/health; then
        echo "Health check $i passed"
    else
        echo "Health check $i failed"
        exit 1
    fi
    sleep 5
done

# Step 5: Switch traffic
echo "Switching traffic to $NEW_VERSION..."
kubectl patch service microservices -n $NAMESPACE -p "{\"spec\":{\"selector\":{\"version\":\"$NEW_VERSION\"}}}"

# Step 6: Wait and verify
echo "Waiting 30 seconds for traffic to stabilize..."
sleep 30

# Step 7: Run smoke tests
echo "Running smoke tests..."
./scripts/testing/smoke-tests.sh

# Step 8: Scale down old environment
echo "Scaling down $CURRENT_VERSION environment..."
kubectl scale deployment microservices-$CURRENT_VERSION --replicas=0 -n $NAMESPACE

echo "Blue-Green deployment completed successfully!"
echo "Active version: $NEW_VERSION"
```

### 2. Canary Releases with Flagger

#### 2.1 Install Flagger
```bash
#!/bin/bash
# scripts/deployment/install-flagger.sh

# Install Flagger
kubectl apply -k github.com/fluxcd/flagger//kustomize/istio

# Install Prometheus for metrics
helm upgrade -i prometheus prometheus-community/prometheus \
  --namespace istio-system \
  --set server.persistentVolume.enabled=false

# Install Grafana for visualization
helm upgrade -i grafana grafana/grafana \
  --namespace istio-system \
  --set persistence.enabled=false \
  --set adminPassword=admin
```

#### 2.2 Canary Configuration
```yaml
# infrastructure/kubernetes/canary/canary.yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: microservices-canary
  namespace: microservices
spec:
  # Target deployment
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: microservices
  
  # Service configuration
  service:
    port: 80
    targetPort: 80
    gateways:
    - microservices-gateway
    hosts:
    - microservices.example.com
  
  # Canary analysis
  analysis:
    # Schedule interval
    interval: 30s
    
    # Max number of failed metric checks
    threshold: 5
    
    # Max traffic percentage routed to canary
    maxWeight: 50
    
    # Canary increment step
    stepWeight: 10
    
    # Prometheus metrics
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 30s
    - name: request-duration
      thresholdRange:
        max: 0.5
      interval: 30s
    - name: error-rate
      thresholdRange:
        max: 1
      interval: 30s
    
    # Load testing webhook
    webhooks:
    - name: load-test
      url: http://load-tester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 1m -q 10 -c 2 http://microservices.example.com/"
```

#### 2.3 Canary Metrics Configuration
```yaml
# monitoring/prometheus/canary-metrics.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: canary-metrics
  namespace: istio-system
data:
  metrics.yaml: |
    # Request success rate
    - name: request-success-rate
      query: |
        sum(
          rate(
            istio_request_total{
              destination_service_name="microservices",
              response_code!~"5.*"
            }[1m]
          )
        ) /
        sum(
          rate(
            istio_request_total{
              destination_service_name="microservices"
            }[1m]
          )
        ) * 100
    
    # Request duration
    - name: request-duration
      query: |
        histogram_quantile(0.99,
          sum(
            rate(
              istio_request_duration_milliseconds_bucket{
                destination_service_name="microservices"
              }[1m]
            )
          ) by (le)
        ) / 1000
    
    # Error rate
    - name: error-rate
      query: |
        sum(
          rate(
            istio_request_total{
              destination_service_name="microservices",
              response_code=~"5.*"
            }[1m]
          )
        ) /
        sum(
          rate(
            istio_request_total{
              destination_service_name="microservices"
            }[1m]
          )
        ) * 100
```

### 3. Feature Flags Implementation

#### 3.1 Feature Flag Service
```javascript
// services/feature-flags/src/app.js
const express = require('express');
const redis = require('redis');
const app = express();

const client = redis.createClient(process.env.REDIS_URL || 'redis://localhost:6379');

app.use(express.json());

// Feature flag evaluation
app.get('/api/features/:flagName', async (req, res) => {
  const { flagName } = req.params;
  const { userId, environment } = req.query;
  
  try {
    // Get feature flag configuration
    const flagConfig = await client.get(`feature:${flagName}`);
    
    if (!flagConfig) {
      return res.status(404).json({ enabled: false, reason: 'Flag not found' });
    }
    
    const config = JSON.parse(flagConfig);
    
    // Evaluate flag based on rules
    const enabled = evaluateFlag(config, { userId, environment });
    
    res.json({
      enabled,
      flagName,
      userId,
      environment,
      config: config.public || {}
    });
    
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create or update feature flag
app.post('/api/features/:flagName', async (req, res) => {
  const { flagName } = req.params;
  const config = req.body;
  
  try {
    await client.set(`feature:${flagName}`, JSON.stringify(config));
    res.json({ success: true, flagName });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

function evaluateFlag(config, context) {
  // Environment-based rules
  if (config.environments && !config.environments.includes(context.environment)) {
    return false;
  }
  
  // User-based rules
  if (config.userWhitelist && config.userWhitelist.includes(context.userId)) {
    return true;
  }
  
  // Percentage rollout
  if (config.percentage) {
    const hash = simpleHash(context.userId || 'anonymous');
    return (hash % 100) < config.percentage;
  }
  
  return config.enabled || false;
}

function simpleHash(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash);
}

app.listen(3000, () => {
  console.log('Feature flag service running on port 3000');
});
```

#### 3.2 Feature Flag Client (Frontend)
```javascript
// services/frontend/src/utils/featureFlags.js
class FeatureFlagClient {
  constructor(apiUrl, userId, environment) {
    this.apiUrl = apiUrl || 'http://localhost:3000';
    this.userId = userId;
    this.environment = environment;
    this.cache = new Map();
    this.cacheTTL = 5 * 60 * 1000; // 5 minutes
  }
  
  async isEnabled(flagName) {
    const cacheKey = `${flagName}:${this.userId}:${this.environment}`;
    const cached = this.cache.get(cacheKey);
    
    if (cached && (Date.now() - cached.timestamp) < this.cacheTTL) {
      return cached.enabled;
    }
    
    try {
      const response = await fetch(
        `${this.apiUrl}/api/features/${flagName}?userId=${this.userId}&environment=${this.environment}`
      );
      
      if (response.ok) {
        const data = await response.json();
        this.cache.set(cacheKey, {
          enabled: data.enabled,
          timestamp: Date.now()
        });
        return data.enabled;
      }
    } catch (error) {
      console.warn('Feature flag service unavailable:', error);
    }
    
    return false; // Fail closed
  }
  
  async getConfig(flagName) {
    const response = await fetch(
      `${this.apiUrl}/api/features/${flagName}?userId=${this.userId}&environment=${this.environment}`
    );
    
    if (response.ok) {
      return response.json();
    }
    
    throw new Error('Feature flag not found');
  }
}

export default FeatureFlagClient;
```

#### 3.3 Feature Flag Usage Example
```jsx
// services/frontend/src/components/ProductList.jsx
import React, { useState, useEffect } from 'react';
import FeatureFlagClient from '../utils/featureFlags';

const ProductList = ({ userId }) => {
  const [showNewDesign, setShowNewDesign] = useState(false);
  const [showRecommendations, setShowRecommendations] = useState(false);
  
  const featureFlags = new FeatureFlagClient(
    process.env.REACT_APP_FEATURE_FLAG_URL,
    userId,
    process.env.NODE_ENV
  );
  
  useEffect(() => {
    const checkFlags = async () => {
      const newDesign = await featureFlags.isEnabled('new-product-design');
      const recommendations = await featureFlags.isEnabled('ai-recommendations');
      
      setShowNewDesign(newDesign);
      setShowRecommendations(recommendations);
    };
    
    checkFlags();
  }, [userId]);
  
  return (
    <div className={showNewDesign ? 'product-list-v2' : 'product-list'}>
      <h2>Products</h2>
      
      {showRecommendations && (
        <div className="recommendations">
          <h3>Recommended for you</h3>
          {/* AI-powered recommendations */}
        </div>
      )}
      
      <div className="product-grid">
        {/* Product items */}
      </div>
    </div>
  );
};

export default ProductList;
```

### 4. A/B Testing Framework

#### 4.1 A/B Test Configuration
```yaml
# infrastructure/kubernetes/ab-testing/experiment.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ab-test-config
  namespace: microservices
data:
  experiments.json: |
    {
      "checkout-flow-redesign": {
        "name": "Checkout Flow Redesign",
        "description": "Testing new streamlined checkout process",
        "status": "active",
        "traffic_split": {
          "control": 50,
          "variant_a": 50
        },
        "targeting": {
          "user_segments": ["new_users", "mobile_users"],
          "geo_locations": ["US", "CA", "UK"]
        },
        "metrics": {
          "primary": "conversion_rate",
          "secondary": ["cart_abandonment", "time_to_checkout"]
        },
        "duration_days": 14,
        "min_sample_size": 1000
      },
      "product-page-layout": {
        "name": "Product Page Layout Test",
        "description": "Testing grid vs list layout for products",
        "status": "active",
        "traffic_split": {
          "control": 33,
          "variant_a": 33,
          "variant_b": 34
        },
        "metrics": {
          "primary": "click_through_rate",
          "secondary": ["time_on_page", "bounce_rate"]
        },
        "duration_days": 7,
        "min_sample_size": 500
      }
    }
```

#### 4.2 A/B Test Analytics Service
```python
# services/analytics/ab_testing.py
import json
import redis
import hashlib
from datetime import datetime, timedelta
from typing import Dict, Optional

class ABTestManager:
    def __init__(self, redis_url: str):
        self.redis_client = redis.from_url(redis_url)
        
    def get_experiment_variant(self, experiment_id: str, user_id: str) -> Optional[str]:
        """Assign user to experiment variant"""
        # Check if user already assigned
        assignment_key = f"assignment:{experiment_id}:{user_id}"
        existing_assignment = self.redis_client.get(assignment_key)
        
        if existing_assignment:
            return existing_assignment.decode()
        
        # Get experiment config
        experiment = self._get_experiment_config(experiment_id)
        if not experiment or experiment.get('status') != 'active':
            return None
            
        # Check targeting criteria
        if not self._matches_targeting(experiment, user_id):
            return None
            
        # Assign variant based on hash
        variant = self._assign_variant(experiment, user_id)
        
        # Store assignment
        self.redis_client.setex(
            assignment_key, 
            timedelta(days=30), 
            variant
        )
        
        # Track assignment event
        self._track_event(experiment_id, user_id, 'assigned', {'variant': variant})
        
        return variant
    
    def track_conversion(self, experiment_id: str, user_id: str, metric: str, value: float = 1.0):
        """Track conversion event for A/B test"""
        variant = self.get_experiment_variant(experiment_id, user_id)
        if not variant:
            return
            
        self._track_event(experiment_id, user_id, 'conversion', {
            'variant': variant,
            'metric': metric,
            'value': value
        })
    
    def get_experiment_results(self, experiment_id: str) -> Dict:
        """Get current results for experiment"""
        results = {
            'experiment_id': experiment_id,
            'variants': {},
            'summary': {}
        }
        
        # Get all events for this experiment
        events_key = f"events:{experiment_id}:*"
        event_keys = self.redis_client.keys(events_key)
        
        variant_stats = {}
        
        for key in event_keys:
            events = self.redis_client.lrange(key, 0, -1)
            for event_data in events:
                event = json.loads(event_data)
                variant = event.get('data', {}).get('variant')
                
                if variant not in variant_stats:
                    variant_stats[variant] = {
                        'assignments': 0,
                        'conversions': 0,
                        'conversion_rate': 0
                    }
                
                if event['event_type'] == 'assigned':
                    variant_stats[variant]['assignments'] += 1
                elif event['event_type'] == 'conversion':
                    variant_stats[variant]['conversions'] += 1
        
        # Calculate conversion rates
        for variant, stats in variant_stats.items():
            if stats['assignments'] > 0:
                stats['conversion_rate'] = stats['conversions'] / stats['assignments']
        
        results['variants'] = variant_stats
        return results
    
    def _get_experiment_config(self, experiment_id: str) -> Optional[Dict]:
        config_data = self.redis_client.get(f"experiment:{experiment_id}")
        if config_data:
            return json.loads(config_data)
        return None
    
    def _matches_targeting(self, experiment: Dict, user_id: str) -> bool:
        # Implement targeting logic based on user segments, geo, etc.
        # For now, simple implementation
        return True
    
    def _assign_variant(self, experiment: Dict, user_id: str) -> str:
        # Use consistent hashing to assign variant
        hash_input = f"{experiment['name']}:{user_id}"
        hash_value = int(hashlib.md5(hash_input.encode()).hexdigest(), 16)
        
        traffic_split = experiment['traffic_split']
        cumulative = 0
        random_value = hash_value % 100
        
        for variant, percentage in traffic_split.items():
            cumulative += percentage
            if random_value < cumulative:
                return variant
                
        return 'control'  # Fallback
    
    def _track_event(self, experiment_id: str, user_id: str, event_type: str, data: Dict):
        event = {
            'timestamp': datetime.utcnow().isoformat(),
            'experiment_id': experiment_id,
            'user_id': user_id,
            'event_type': event_type,
            'data': data
        }
        
        events_key = f"events:{experiment_id}:{user_id}"
        self.redis_client.lpush(events_key, json.dumps(event))
        self.redis_client.expire(events_key, timedelta(days=90))
```

### 5. Progressive Delivery Pipeline

#### 5.1 GitOps Deployment Pipeline
```yaml
# .github/workflows/progressive-delivery.yml
name: Progressive Delivery Pipeline

on:
  push:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-security-scan:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix=main-{{date 'YYYYMMDD'}}-
      
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
      
      - name: Security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.meta.outputs.tags }}
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  deploy-staging:
    needs: build-and-security-scan
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
      - name: Checkout config repo
        uses: actions/checkout@v3
        with:
          repository: your-org/microservices-config
          token: ${{ secrets.CONFIG_REPO_TOKEN }}
      
      - name: Update staging config
        run: |
          yq eval '.image.tag = "${{ needs.build-and-security-scan.outputs.image-tag }}"' \
            -i environments/staging/values.yaml
          
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add environments/staging/values.yaml
          git commit -m "Update staging to ${{ github.sha }}"
          git push
      
      - name: Wait for staging deployment
        run: |
          # Wait for ArgoCD to sync
          sleep 60
          # Add health checks here

  integration-tests:
    needs: deploy-staging
    runs-on: ubuntu-latest
    
    steps:
      - name: Run integration tests
        run: |
          # Run comprehensive integration tests against staging
          npm run test:integration -- --env=staging
      
      - name: Run performance tests
        run: |
          k6 run tests/performance/staging-load-test.js

  deploy-production-canary:
    needs: [build-and-security-scan, integration-tests]
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - name: Checkout config repo
        uses: actions/checkout@v3
        with:
          repository: your-org/microservices-config
          token: ${{ secrets.CONFIG_REPO_TOKEN }}
      
      - name: Deploy canary
        run: |
          # Update canary deployment
          yq eval '.canary.image.tag = "${{ needs.build-and-security-scan.outputs.image-tag }}"' \
            -i environments/production/canary.yaml
          
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add environments/production/canary.yaml
          git commit -m "Deploy canary ${{ github.sha }}"
          git push
      
      - name: Monitor canary deployment
        run: |
          # Wait for Flagger to complete analysis
          timeout 1800 bash -c 'until kubectl get canary microservices-canary -n microservices -o jsonpath="{.status.phase}" | grep -q "Succeeded\|Failed"; do sleep 30; done'
          
          # Check final status
          STATUS=$(kubectl get canary microservices-canary -n microservices -o jsonpath="{.status.phase}")
          if [ "$STATUS" != "Succeeded" ]; then
            echo "Canary deployment failed: $STATUS"
            exit 1
          fi

  notify:
    needs: [deploy-production-canary]
    runs-on: ubuntu-latest
    if: always()
    
    steps:
      - name: Notify team
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#deployments'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
          fields: repo,message,commit,author,action,eventName,ref,workflow,job,took
```

### 6. Rollback Automation

#### 6.1 Automated Rollback Script
```bash
#!/bin/bash
# scripts/deployment/auto-rollback.sh

set -e

NAMESPACE="microservices"
SERVICE_NAME="microservices"
THRESHOLD_ERROR_RATE=5  # 5% error rate threshold
THRESHOLD_RESPONSE_TIME=1000  # 1000ms response time threshold
CHECK_DURATION=300  # 5 minutes

echo "Starting automated rollback monitoring..."
echo "Error rate threshold: $THRESHOLD_ERROR_RATE%"
echo "Response time threshold: ${THRESHOLD_RESPONSE_TIME}ms"
echo "Check duration: ${CHECK_DURATION}s"

# Function to get error rate from Prometheus
get_error_rate() {
    kubectl exec -n monitoring deployment/prometheus -- \
        promtool query instant \
        'sum(rate(http_request_total{job="microservices",status=~"5.."}[1m])) / sum(rate(http_request_total{job="microservices"}[1m])) * 100' \
        | grep -oP '\d+\.\d+' || echo "0"
}

# Function to get average response time from Prometheus  
get_response_time() {
    kubectl exec -n monitoring deployment/prometheus -- \
        promtool query instant \
        'avg(rate(http_request_duration_seconds_sum{job="microservices"}[1m]) / rate(http_request_duration_seconds_count{job="microservices"}[1m])) * 1000' \
        | grep -oP '\d+\.\d+' || echo "0"
}

# Function to rollback deployment
rollback_deployment() {
    echo "ROLLBACK TRIGGERED: Performance degradation detected"
    
    # Get previous revision
    PREVIOUS_REVISION=$(kubectl rollout history deployment/$SERVICE_NAME -n $NAMESPACE | tail -n 2 | head -n 1 | awk '{print $1}')
    
    echo "Rolling back to revision: $PREVIOUS_REVISION"
    
    # Perform rollback
    kubectl rollout undo deployment/$SERVICE_NAME -n $NAMESPACE --to-revision=$PREVIOUS_REVISION
    
    # Wait for rollback to complete
    kubectl rollout status deployment/$SERVICE_NAME -n $NAMESPACE --timeout=300s
    
    # Send alert
    curl -X POST "$SLACK_WEBHOOK_URL" \
        -H 'Content-type: application/json' \
        --data '{"text":"🚨 AUTOMATED ROLLBACK EXECUTED\nService: '$SERVICE_NAME'\nNamespace: '$NAMESPACE'\nReason: Performance degradation detected\nRolled back to revision: '$PREVIOUS_REVISION'"}'
    
    echo "Rollback completed successfully"
    exit 0
}

# Monitor for specified duration
START_TIME=$(date +%s)
END_TIME=$((START_TIME + CHECK_DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
    ERROR_RATE=$(get_error_rate)
    RESPONSE_TIME=$(get_response_time)
    
    echo "$(date): Error Rate: ${ERROR_RATE}%, Response Time: ${RESPONSE_TIME}ms"
    
    # Check if thresholds are exceeded
    if (( $(echo "$ERROR_RATE > $THRESHOLD_ERROR_RATE" | bc -l) )); then
        echo "ERROR RATE THRESHOLD EXCEEDED: ${ERROR_RATE}% > ${THRESHOLD_ERROR_RATE}%"
        rollback_deployment
    fi
    
    if (( $(echo "$RESPONSE_TIME > $THRESHOLD_RESPONSE_TIME" | bc -l) )); then
        echo "RESPONSE TIME THRESHOLD EXCEEDED: ${RESPONSE_TIME}ms > ${THRESHOLD_RESPONSE_TIME}ms"
        rollback_deployment
    fi
    
    sleep 30
done

echo "Monitoring completed. No issues detected."
```

## 📊 Success Metrics for Phase 4

### Technical Metrics
- [ ] **Deployment Success Rate**: 100% successful deployments
- [ ] **Rollback Time**: < 2 minutes for automated rollbacks
- [ ] **Canary Analysis**: Automated promotion/rollback based on metrics
- [ ] **Feature Flag Response**: < 50ms flag evaluation time
- [ ] **A/B Test Coverage**: Statistical significance within 7 days

### Business Impact Metrics  
- [ ] **Zero Downtime Deployments**: 100% of deployments
- [ ] **Deployment Frequency**: 10+ deployments per day capability
- [ ] **Lead Time Reduction**: 90% reduction in deployment lead time
- [ ] **Risk Reduction**: 95% reduction in deployment-related incidents

## 🎯 Phase 4 Success Criteria

### Technical Achievement
- [ ] Blue-green deployments operational
- [ ] Canary releases automated with Flagger
- [ ] Feature flags service deployed and functional
- [ ] A/B testing framework implemented
- [ ] Automated rollback system active
- [ ] Progressive delivery pipeline complete

### Portfolio Impact
- [ ] Demonstrated advanced deployment strategies
- [ ] Zero-downtime deployment capability
- [ ] Risk mitigation through automated rollbacks
- [ ] Data-driven deployment decisions
- [ ] Production-grade progressive delivery

---

**Congratulations!** 🚀 You've implemented advanced deployment strategies that demonstrate world-class DevOps capabilities. Your platform now supports sophisticated progressive delivery patterns used by leading technology companies.

**Next Step**: Proceed to [Phase 5: Observability & Monitoring](05-PHASE5-OBSERVABILITY.md) to implement comprehensive monitoring and observability.