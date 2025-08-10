const express = require('express');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'frontend',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Ready endpoint
app.get('/ready', (req, res) => {
  res.json({
    status: 'ready',
    service: 'frontend',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Microservices Platform</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        .service { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .healthy { background-color: #d4edda; }
        .unhealthy { background-color: #f8d7da; }
      </style>
    </head>
    <body>
      <h1>Microservices Deployment Pipeline</h1>
      <p>Welcome to the microservices platform!</p>
      
      <div class="service">
        <h2>Services Status</h2>
        <ul>
          <li>Frontend: ✅ Running on port ${PORT}</li>
          <li>API Gateway: Configure at ${process.env.API_GATEWAY_URL || 'http://localhost:8080'}</li>
          <li>User Service: Configure at ${process.env.USER_SERVICE_URL || 'http://localhost:8000'}</li>
          <li>Product Service: Configure at ${process.env.PRODUCT_SERVICE_URL || 'http://localhost:8081'}</li>
          <li>Order Service: Configure at ${process.env.ORDER_SERVICE_URL || 'http://localhost:3001'}</li>
        </ul>
      </div>
      
      <div class="service">
        <h2>Quick Links</h2>
        <ul>
          <li><a href="/health">Health Check</a></li>
          <li><a href="${process.env.API_GATEWAY_URL || 'http://localhost:8080'}">API Gateway</a></li>
        </ul>
      </div>
    </body>
    </html>
  `);
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`Frontend service running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

module.exports = app;