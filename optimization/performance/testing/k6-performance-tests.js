// K6 Performance Testing Suite for Microservices
// Comprehensive load testing with cost optimization insights

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.1/index.js';

// Custom metrics for cost analysis
const errorRate = new Rate('error_rate');
const responseTime = new Trend('response_time');
const requestsPerSecond = new Rate('requests_per_second');
const costPerRequest = new Trend('cost_per_request');
const resourceUtilization = new Trend('resource_utilization');

// Test configuration
export let options = {
  scenarios: {
    // Baseline performance test
    baseline: {
      executor: 'constant-vus',
      vus: 10,
      duration: '5m',
      tags: { test_type: 'baseline' },
    },
    
    // Load test
    load_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 50 },   // Ramp up
        { duration: '5m', target: 50 },   // Stay at 50 users
        { duration: '2m', target: 100 },  // Ramp up to 100
        { duration: '5m', target: 100 },  // Stay at 100 users
        { duration: '2m', target: 0 },    // Ramp down
      ],
      tags: { test_type: 'load' },
    },
    
    // Stress test
    stress_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 100 },
        { duration: '5m', target: 200 },
        { duration: '2m', target: 300 },
        { duration: '5m', target: 300 },
        { duration: '10m', target: 0 },
      ],
      tags: { test_type: 'stress' },
    },
    
    // Spike test
    spike_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 100 },
        { duration: '30s', target: 500 }, // Spike
        { duration: '3m', target: 100 },
        { duration: '1m', target: 0 },
      ],
      tags: { test_type: 'spike' },
    },
    
    // Endurance test
    endurance_test: {
      executor: 'constant-vus',
      vus: 50,
      duration: '30m',
      tags: { test_type: 'endurance' },
    },
  },
  
  thresholds: {
    // Performance thresholds
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],
    'http_req_failed': ['rate<0.01'], // Error rate < 1%
    'http_reqs': ['rate>100'],        // At least 100 RPS
    
    // Cost optimization thresholds
    'cost_per_request': ['avg<0.001'], // Less than $0.001 per request
    'resource_utilization': ['avg>0.7'], // At least 70% utilization
  },
  
  // Export results for analysis
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(95)', 'p(99)', 'p(99.99)', 'count'],
};

// Environment configuration
const BASE_URL = __ENV.BASE_URL || 'http://api-gateway.microservices.svc.cluster.local:8080';
const PROMETHEUS_URL = __ENV.PROMETHEUS_URL || 'http://prometheus.monitoring.svc.cluster.local:9090';

// Test data
const testUsers = [
  { username: 'testuser1', email: 'test1@example.com' },
  { username: 'testuser2', email: 'test2@example.com' },
  { username: 'testuser3', email: 'test3@example.com' },
];

const testProducts = [
  { name: 'Test Product 1', price: 29.99, category: 'electronics' },
  { name: 'Test Product 2', price: 49.99, category: 'books' },
  { name: 'Test Product 3', price: 19.99, category: 'clothing' },
];

// Cost calculation helper
function calculateCostMetrics() {
  // Query Prometheus for resource costs
  const costQuery = `sum(increase(total_cost[1m]))`;
  const requestsQuery = `sum(increase(http_requests_total[1m]))`;
  
  try {
    const costResponse = http.get(`${PROMETHEUS_URL}/api/v1/query?query=${encodeURIComponent(costQuery)}`);
    const requestsResponse = http.get(`${PROMETHEUS_URL}/api/v1/query?query=${encodeURIComponent(requestsQuery)}`);
    
    if (costResponse.status === 200 && requestsResponse.status === 200) {
      const costData = JSON.parse(costResponse.body);
      const requestsData = JSON.parse(requestsResponse.body);
      
      if (costData.data.result.length > 0 && requestsData.data.result.length > 0) {
        const totalCost = parseFloat(costData.data.result[0].value[1]);
        const totalRequests = parseFloat(requestsData.data.result[0].value[1]);
        
        if (totalRequests > 0) {
          costPerRequest.add(totalCost / totalRequests);
        }
      }
    }
  } catch (error) {
    console.log(`Cost metrics calculation failed: ${error}`);
  }
}

// Resource utilization helper
function calculateResourceUtilization() {
  const cpuQuery = `avg(rate(container_cpu_usage_seconds_total[1m])) / avg(container_spec_cpu_quota / container_spec_cpu_period)`;
  const memoryQuery = `avg(container_memory_working_set_bytes) / avg(container_spec_memory_limit_bytes)`;
  
  try {
    const cpuResponse = http.get(`${PROMETHEUS_URL}/api/v1/query?query=${encodeURIComponent(cpuQuery)}`);
    const memoryResponse = http.get(`${PROMETHEUS_URL}/api/v1/query?query=${encodeURIComponent(memoryQuery)}`);
    
    if (cpuResponse.status === 200 && memoryResponse.status === 200) {
      const cpuData = JSON.parse(cpuResponse.body);
      const memoryData = JSON.parse(memoryResponse.body);
      
      if (cpuData.data.result.length > 0 && memoryData.data.result.length > 0) {
        const cpuUtil = parseFloat(cpuData.data.result[0].value[1]);
        const memoryUtil = parseFloat(memoryData.data.result[0].value[1]);
        
        resourceUtilization.add((cpuUtil + memoryUtil) / 2);
      }
    }
  } catch (error) {
    console.log(`Resource utilization calculation failed: ${error}`);
  }
}

// Main test function
export default function () {
  const testType = __ITER % 4;
  
  switch (testType) {
    case 0:
      testUserService();
      break;
    case 1:
      testProductService();
      break;
    case 2:
      testOrderService();
      break;
    case 3:
      testApiGateway();
      break;
  }
  
  // Calculate cost metrics every 10 iterations
  if (__ITER % 10 === 0) {
    calculateCostMetrics();
    calculateResourceUtilization();
  }
  
  sleep(1);
}

function testUserService() {
  const user = testUsers[Math.floor(Math.random() * testUsers.length)];
  
  // Create user
  let response = http.post(`${BASE_URL}/api/users`, JSON.stringify(user), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  const success = check(response, {
    'user creation status is 200 or 201': (r) => r.status === 200 || r.status === 201,
    'user creation response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  errorRate.add(!success);
  responseTime.add(response.timings.duration);
  
  if (success && response.json('id')) {
    const userId = response.json('id');
    
    // Get user
    response = http.get(`${BASE_URL}/api/users/${userId}`);
    check(response, {
      'user retrieval status is 200': (r) => r.status === 200,
      'user retrieval response time < 300ms': (r) => r.timings.duration < 300,
    });
    
    // Update user
    user.email = `updated_${user.email}`;
    response = http.put(`${BASE_URL}/api/users/${userId}`, JSON.stringify(user), {
      headers: { 'Content-Type': 'application/json' },
    });
    check(response, {
      'user update status is 200': (r) => r.status === 200,
      'user update response time < 400ms': (r) => r.timings.duration < 400,
    });
    
    // Delete user
    response = http.del(`${BASE_URL}/api/users/${userId}`);
    check(response, {
      'user deletion status is 200 or 204': (r) => r.status === 200 || r.status === 204,
    });
  }
}

function testProductService() {
  // List products
  let response = http.get(`${BASE_URL}/api/products`);
  
  const success = check(response, {
    'product list status is 200': (r) => r.status === 200,
    'product list response time < 300ms': (r) => r.timings.duration < 300,
    'product list has data': (r) => r.json().length >= 0,
  });
  
  errorRate.add(!success);
  responseTime.add(response.timings.duration);
  
  // Search products
  response = http.get(`${BASE_URL}/api/products/search?q=test`);
  check(response, {
    'product search status is 200': (r) => r.status === 200,
    'product search response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  // Get product by category
  response = http.get(`${BASE_URL}/api/products/category/electronics`);
  check(response, {
    'product category status is 200': (r) => r.status === 200,
    'product category response time < 400ms': (r) => r.timings.duration < 400,
  });
}

function testOrderService() {
  const order = {
    user_id: Math.floor(Math.random() * 1000) + 1,
    items: [
      {
        product_id: Math.floor(Math.random() * 100) + 1,
        quantity: Math.floor(Math.random() * 5) + 1,
      },
    ],
  };
  
  // Create order
  let response = http.post(`${BASE_URL}/api/orders`, JSON.stringify(order), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  const success = check(response, {
    'order creation status is 200 or 201': (r) => r.status === 200 || r.status === 201,
    'order creation response time < 800ms': (r) => r.timings.duration < 800,
  });
  
  errorRate.add(!success);
  responseTime.add(response.timings.duration);
  
  if (success && response.json('id')) {
    const orderId = response.json('id');
    
    // Get order
    response = http.get(`${BASE_URL}/api/orders/${orderId}`);
    check(response, {
      'order retrieval status is 200': (r) => r.status === 200,
      'order retrieval response time < 400ms': (r) => r.timings.duration < 400,
    });
    
    // Update order status
    response = http.patch(`${BASE_URL}/api/orders/${orderId}/status`, 
      JSON.stringify({ status: 'processing' }), {
      headers: { 'Content-Type': 'application/json' },
    });
    check(response, {
      'order status update is 200': (r) => r.status === 200,
    });
  }
}

function testApiGateway() {
  // Health check
  let response = http.get(`${BASE_URL}/health`);
  
  const success = check(response, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 100ms': (r) => r.timings.duration < 100,
  });
  
  errorRate.add(!success);
  responseTime.add(response.timings.duration);
  
  // Metrics endpoint
  response = http.get(`${BASE_URL}/metrics`);
  check(response, {
    'metrics endpoint status is 200': (r) => r.status === 200,
    'metrics response time < 200ms': (r) => r.timings.duration < 200,
  });
  
  // Rate limiting test
  for (let i = 0; i < 10; i++) {
    response = http.get(`${BASE_URL}/api/products`);
    if (response.status === 429) {
      check(response, {
        'rate limiting works': (r) => r.status === 429,
      });
      break;
    }
  }
}

// Custom summary with cost analysis
export function handleSummary(data) {
  return {
    'performance-results.html': htmlReport(data),
    'performance-summary.json': JSON.stringify(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }) + 
            generateCostAnalysisReport(data),
  };
}

function generateCostAnalysisReport(data) {
  const report = `

🔍 COST OPTIMIZATION ANALYSIS
============================

Performance Metrics:
- Total Requests: ${data.metrics.http_reqs.count}
- Average Response Time: ${data.metrics.http_req_duration.avg.toFixed(2)}ms
- Error Rate: ${(data.metrics.http_req_failed.rate * 100).toFixed(2)}%
- Requests/Second: ${data.metrics.http_reqs.rate.toFixed(2)}

Cost Efficiency Metrics:
- Estimated Cost per Request: $${data.metrics.cost_per_request?.avg?.toFixed(6) || 'N/A'}
- Resource Utilization: ${((data.metrics.resource_utilization?.avg || 0) * 100).toFixed(1)}%

Optimization Recommendations:
`;

  const recommendations = [];
  
  // Performance-based recommendations
  if (data.metrics.http_req_duration.avg > 500) {
    recommendations.push('- Response times are high. Consider scaling up or optimizing application code.');
  }
  
  if (data.metrics.http_req_failed.rate > 0.01) {
    recommendations.push('- Error rate is above threshold. Investigate error causes and scaling requirements.');
  }
  
  // Cost-based recommendations
  if (data.metrics.resource_utilization?.avg < 0.6) {
    recommendations.push('- Resource utilization is low. Consider rightsizing to reduce costs.');
  }
  
  if (data.metrics.cost_per_request?.avg > 0.001) {
    recommendations.push('- Cost per request is high. Consider optimizing resource allocation.');
  }
  
  if (recommendations.length === 0) {
    recommendations.push('- Performance and cost metrics are within acceptable ranges.');
  }
  
  return report + recommendations.join('\n') + '\n';
}