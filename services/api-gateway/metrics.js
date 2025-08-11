const promClient = require('prom-client');

// Create a Registry
const register = new promClient.Registry();

// Add default metrics (CPU, memory, etc.)
promClient.collectDefaultMetrics({ 
  register,
  prefix: 'api_gateway_'
});

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status', 'service'],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status', 'service']
});

const activeConnections = new promClient.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  labelNames: ['service']
});

const businessMetrics = {
  ordersCreated: new promClient.Counter({
    name: 'orders_created_total',
    help: 'Total number of orders created',
    labelNames: ['status', 'payment_method']
  }),
  
  userRegistrations: new promClient.Counter({
    name: 'user_registrations_total',
    help: 'Total number of user registrations',
    labelNames: ['source', 'type']
  }),
  
  apiKeyUsage: new promClient.Counter({
    name: 'api_key_usage_total',
    help: 'API key usage by client',
    labelNames: ['client_id', 'endpoint']
  }),
  
  cacheHitRate: new promClient.Counter({
    name: 'cache_operations_total',
    help: 'Cache operations',
    labelNames: ['operation', 'result']
  })
};

// Register all metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(activeConnections);
Object.values(businessMetrics).forEach(metric => register.registerMetric(metric));

// Middleware to track HTTP metrics
const metricsMiddleware = (req, res, next) => {
  const start = Date.now();
  
  // Increment active connections
  activeConnections.inc({ service: 'api-gateway' });
  
  // Track response
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode.toString(), 'api-gateway')
      .observe(duration);
    
    httpRequestsTotal
      .labels(req.method, route, res.statusCode.toString(), 'api-gateway')
      .inc();
    
    // Decrement active connections
    activeConnections.dec({ service: 'api-gateway' });
  });
  
  next();
};

// Endpoint to expose metrics
const metricsEndpoint = async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    const metrics = await register.metrics();
    res.end(metrics);
  } catch (err) {
    res.status(500).end(err);
  }
};

module.exports = {
  register,
  metricsMiddleware,
  metricsEndpoint,
  businessMetrics,
  httpRequestDuration,
  httpRequestsTotal,
  activeConnections
};