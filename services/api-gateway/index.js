const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { createProxyMiddleware } = require('http-proxy-middleware');
const http = require('http');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware - IMPORTANT: Order matters for proxy middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));

// Body parsing middleware MUST come before proxy middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check endpoint BEFORE proxy middleware
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'api-gateway',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

app.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ready',
    service: 'api-gateway',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint BEFORE proxy middleware
app.get('/', (req, res) => {
  res.json({
    service: 'API Gateway',
    version: '1.0.0',
    description: 'Microservices API Gateway - Fixed Version',
    endpoints: {
      health: '/health',
      ready: '/ready',
      users: '/api/users',
      products: '/api/products',
      orders: '/api/orders'
    },
    status: 'All services configured and running'
  });
});

// User Service Proxy with improved configuration
const userServiceProxy = createProxyMiddleware({
  target: 'http://user-service:8000',
  changeOrigin: true,
  pathRewrite: {
    '^/api/users': '/users'
  },
  timeout: 30000,
  proxyTimeout: 30000,
  onProxyReq: (proxyReq, req, res) => {
    console.log(`[USER-PROXY] ${req.method} ${req.originalUrl} -> http://user-service:8000/users`);
    console.log(`[USER-PROXY] Request body:`, req.body);
    
    // Handle POST/PUT request body forwarding
    if (req.body && (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH')) {
      const bodyData = JSON.stringify(req.body);
      console.log(`[USER-PROXY] Sending body data:`, bodyData);
      proxyReq.setHeader('Content-Type', 'application/json');
      proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
      proxyReq.write(bodyData);
    }
  },
  onProxyRes: (proxyRes, req, res) => {
    console.log(`[USER-PROXY] Response: ${proxyRes.statusCode} for ${req.method} ${req.originalUrl}`);
  },
  onError: (err, req, res) => {
    console.error(`[USER-PROXY] Error:`, err.message);
    res.status(503).json({ 
      error: 'User service unavailable', 
      message: err.message,
      service: 'user-service'
    });
  }
});

// Product Service Proxy
const productServiceProxy = createProxyMiddleware({
  target: 'http://product-service:8081',
  changeOrigin: true,
  pathRewrite: {
    '^/api/products': '/products'
  },
  timeout: 30000,
  proxyTimeout: 30000,
  onProxyReq: (proxyReq, req, res) => {
    console.log(`[PRODUCT-PROXY] ${req.method} ${req.originalUrl} -> http://product-service:8081/products`);
    
    if (req.body && (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH')) {
      const bodyData = JSON.stringify(req.body);
      proxyReq.setHeader('Content-Type', 'application/json');
      proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
      proxyReq.write(bodyData);
    }
  },
  onProxyRes: (proxyRes, req, res) => {
    console.log(`[PRODUCT-PROXY] Response: ${proxyRes.statusCode} for ${req.method} ${req.originalUrl}`);
  },
  onError: (err, req, res) => {
    console.error(`[PRODUCT-PROXY] Error:`, err.message);
    res.status(503).json({ 
      error: 'Product service unavailable', 
      message: err.message,
      service: 'product-service'
    });
  }
});

// Order Service Proxy
const orderServiceProxy = createProxyMiddleware({
  target: 'http://order-service:3001',
  changeOrigin: true,
  pathRewrite: {
    '^/api/orders': '/orders'
  },
  timeout: 30000,
  proxyTimeout: 30000,
  onProxyReq: (proxyReq, req, res) => {
    console.log(`[ORDER-PROXY] ${req.method} ${req.originalUrl} -> http://order-service:3001/orders`);
    
    if (req.body && (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH')) {
      const bodyData = JSON.stringify(req.body);
      proxyReq.setHeader('Content-Type', 'application/json');
      proxyReq.setHeader('Content-Length', Buffer.byteLength(Buffer.from(bodyData)));
      proxyReq.write(bodyData);
    }
  },
  onProxyRes: (proxyRes, req, res) => {
    console.log(`[ORDER-PROXY] Response: ${proxyRes.statusCode} for ${req.method} ${req.originalUrl}`);
  },
  onError: (err, req, res) => {
    console.error(`[ORDER-PROXY] Error:`, err.message);
    res.status(503).json({ 
      error: 'Order service unavailable', 
      message: err.message,
      service: 'order-service'  
    });
  }
});

// Apply proxy middleware
app.use('/api/users', userServiceProxy);
app.use('/api/products', productServiceProxy);
app.use('/api/orders', orderServiceProxy);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested resource was not found',
    path: req.originalUrl,
    timestamp: new Date().toISOString()
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Gateway Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error',
    timestamp: new Date().toISOString()
  });
});

// Start server only if not in test environment
if (process.env.NODE_ENV !== 'test') {
  const server = app.listen(PORT, () => {
    console.log(`🚀 API Gateway FIXED VERSION running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log('✅ Proxy routes configured:');
    console.log('  - /api/users -> user-service:8000/users');
    console.log('  - /api/products -> product-service:8081/products');
    console.log('  - /api/orders -> order-service:3001/orders');
    console.log('🔥 Ready to handle all HTTP methods!');
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    server.close(() => {
      console.log('HTTP server closed');
      process.exit(0);
    });
  });
}

module.exports = app;