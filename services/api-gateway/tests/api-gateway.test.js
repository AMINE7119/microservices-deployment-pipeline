const request = require('supertest');
const app = require('../index');

describe('API Gateway', () => {
  describe('Health Check Endpoints', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('service', 'api-gateway');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
    });

    it('should return ready status', async () => {
      const response = await request(app)
        .get('/ready')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ready');
      expect(response.body).toHaveProperty('service', 'api-gateway');
    });
  });

  describe('Root Endpoint', () => {
    it('should return service information', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.body).toHaveProperty('service', 'API Gateway');
      expect(response.body).toHaveProperty('version', '1.0.0');
      expect(response.body).toHaveProperty('endpoints');
      expect(response.body.endpoints).toHaveProperty('users', '/api/users');
      expect(response.body.endpoints).toHaveProperty('products', '/api/products');
      expect(response.body.endpoints).toHaveProperty('orders', '/api/orders');
    });
  });

  describe('Error Handling', () => {
    it('should return 404 for unknown routes', async () => {
      const response = await request(app)
        .get('/unknown-route')
        .expect(404);

      expect(response.body).toHaveProperty('error', 'Not Found');
      expect(response.body).toHaveProperty('message', 'The requested resource was not found');
      expect(response.body).toHaveProperty('path', '/unknown-route');
    });
  });

  describe('Proxy Route Configuration', () => {
    // These tests verify that proxy routes are configured but don't test actual proxying
    // as that would require running backend services
    
    it('should have user service routes configured', async () => {
      // Test that the route exists (will fail proxy but route is there)
      const response = await request(app)
        .get('/api/users')
        .expect(503); // Service unavailable when backend not running

      expect(response.body).toHaveProperty('error');
    });

    it('should have product service routes configured', async () => {
      const response = await request(app)
        .get('/api/products')
        .expect(503);

      expect(response.body).toHaveProperty('error');
    });

    it('should have order service routes configured', async () => {
      const response = await request(app)
        .get('/api/orders')
        .expect(503);

      expect(response.body).toHaveProperty('error');
    });
  });
});