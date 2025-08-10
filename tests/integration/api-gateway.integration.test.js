const request = require('supertest');

describe('API Gateway Integration Tests', () => {
  const API_GATEWAY_URL = process.env.API_GATEWAY_URL || 'http://localhost:8080';
  const timeout = 30000; // 30 seconds for integration tests

  beforeAll(() => {
    // Wait for services to be ready
    return new Promise(resolve => setTimeout(resolve, 5000));
  }, timeout);

  describe('Service Health Checks via Gateway', () => {
    it('should return API Gateway health status', async () => {
      const response = await request(API_GATEWAY_URL)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('service', 'api-gateway');
    }, timeout);

    it('should return gateway service information', async () => {
      const response = await request(API_GATEWAY_URL)
        .get('/')
        .expect(200);

      expect(response.body).toHaveProperty('service', 'API Gateway');
      expect(response.body).toHaveProperty('endpoints');
    }, timeout);
  });

  describe('User Service Integration', () => {
    let createdUserId;

    it('should create a user through API Gateway', async () => {
      const userData = {
        username: `integration-user-${Date.now()}`,
        email: `integration@test-${Date.now()}.com`,
        full_name: 'Integration Test User'
      };

      const response = await request(API_GATEWAY_URL)
        .post('/api/users')
        .send(userData)
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('username', userData.username);
      expect(response.body).toHaveProperty('email', userData.email);
      expect(response.body).toHaveProperty('full_name', userData.full_name);
      expect(response.body).toHaveProperty('created_at');

      createdUserId = response.body.id;
    }, timeout);

    it('should get all users through API Gateway', async () => {
      const response = await request(API_GATEWAY_URL)
        .get('/api/users')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
      
      // Find our created user
      const createdUser = response.body.find(user => user.id === createdUserId);
      expect(createdUser).toBeDefined();
    }, timeout);

    it('should get specific user through API Gateway', async () => {
      const response = await request(API_GATEWAY_URL)
        .get(`/api/users/${createdUserId}`)
        .expect(200);

      expect(response.body).toHaveProperty('id', createdUserId);
      expect(response.body).toHaveProperty('username');
      expect(response.body).toHaveProperty('email');
    }, timeout);
  });

  describe('Product Service Integration', () => {
    let createdProductId;

    it('should create a product through API Gateway', async () => {
      const productData = {
        name: `Integration Product ${Date.now()}`,
        description: 'Integration test product',
        price: 99.99
      };

      const response = await request(API_GATEWAY_URL)
        .post('/api/products')
        .send(productData)
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('name', productData.name);
      expect(response.body).toHaveProperty('description', productData.description);
      expect(response.body).toHaveProperty('price', productData.price);

      createdProductId = response.body.id;
    }, timeout);

    it('should get all products through API Gateway', async () => {
      const response = await request(API_GATEWAY_URL)
        .get('/api/products')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    }, timeout);

    it('should get specific product through API Gateway', async () => {
      const response = await request(API_GATEWAY_URL)
        .get(`/api/products/${createdProductId}`)
        .expect(200);

      expect(response.body).toHaveProperty('id', createdProductId);
      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('price');
    }, timeout);
  });

  describe('Order Service Integration', () => {
    let createdOrderId;

    it('should create an order through API Gateway', async () => {
      const orderData = {
        userId: 'integration-test-user',
        products: [
          { id: '1', quantity: 2 }
        ],
        totalAmount: 199.98
      };

      const response = await request(API_GATEWAY_URL)
        .post('/api/orders')
        .send(orderData)
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('userId', orderData.userId);
      expect(response.body).toHaveProperty('totalAmount', orderData.totalAmount);
      expect(response.body).toHaveProperty('status', 'pending');

      createdOrderId = response.body.id;
    }, timeout);

    it('should get all orders through API Gateway', async () => {
      const response = await request(API_GATEWAY_URL)
        .get('/api/orders')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    }, timeout);

    it('should get specific order through API Gateway', async () => {
      const response = await request(API_GATEWAY_URL)
        .get(`/api/orders/${createdOrderId}`)
        .expect(200);

      expect(response.body).toHaveProperty('id', createdOrderId);
      expect(response.body).toHaveProperty('userId');
      expect(response.body).toHaveProperty('status');
    }, timeout);
  });

  describe('Cross-Service Integration', () => {
    it('should handle concurrent requests to different services', async () => {
      const requests = [
        request(API_GATEWAY_URL).get('/api/users'),
        request(API_GATEWAY_URL).get('/api/products'), 
        request(API_GATEWAY_URL).get('/api/orders')
      ];

      const responses = await Promise.all(requests);
      
      responses.forEach(response => {
        expect(response.status).toBe(200);
        expect(Array.isArray(response.body)).toBe(true);
      });
    }, timeout);

    it('should maintain data consistency across services', async () => {
      // Create entities in sequence
      const user = await request(API_GATEWAY_URL)
        .post('/api/users')
        .send({
          username: `consistency-user-${Date.now()}`,
          email: `consistency@test-${Date.now()}.com`,
          full_name: 'Consistency Test User'
        })
        .expect(201);

      const product = await request(API_GATEWAY_URL)
        .post('/api/products')
        .send({
          name: `Consistency Product ${Date.now()}`,
          description: 'Consistency test product',
          price: 49.99
        })
        .expect(201);

      const order = await request(API_GATEWAY_URL)
        .post('/api/orders')
        .send({
          userId: user.body.id.toString(),
          products: [{ id: product.body.id.toString(), quantity: 1 }],
          totalAmount: 49.99
        })
        .expect(201);

      // Verify all entities exist
      expect(user.body).toHaveProperty('id');
      expect(product.body).toHaveProperty('id');
      expect(order.body).toHaveProperty('id');
    }, timeout);
  });

  describe('Error Handling Integration', () => {
    it('should handle invalid endpoints gracefully', async () => {
      const response = await request(API_GATEWAY_URL)
        .get('/api/nonexistent')
        .expect(404);

      expect(response.body).toHaveProperty('error');
    }, timeout);

    it('should handle invalid data gracefully', async () => {
      const response = await request(API_GATEWAY_URL)
        .post('/api/users')
        .send({ invalid: 'data' })
        .expect(422);

      expect(response.body).toHaveProperty('detail');
    }, timeout);

    it('should handle service unavailability (if applicable)', async () => {
      // This test would be more meaningful if we could simulate service downtime
      // For now, just test that the gateway responds appropriately to valid requests
      const response = await request(API_GATEWAY_URL)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
    }, timeout);
  });
});