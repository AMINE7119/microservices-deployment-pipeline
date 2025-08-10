const request = require('supertest');
const app = require('./index');

describe('API Gateway', () => {
  describe('GET /', () => {
    it('should return API information', async () => {
      const res = await request(app)
        .get('/')
        .expect('Content-Type', /json/)
        .expect(200);
      
      expect(res.body).toHaveProperty('service', 'API Gateway');
      expect(res.body).toHaveProperty('version');
      expect(res.body).toHaveProperty('endpoints');
    });
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const res = await request(app)
        .get('/health')
        .expect('Content-Type', /json/)
        .expect(200);
      
      expect(res.body).toHaveProperty('status', 'healthy');
      expect(res.body).toHaveProperty('service', 'api-gateway');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body).toHaveProperty('uptime');
    });
  });

  describe('GET /ready', () => {
    it('should return readiness status', async () => {
      const res = await request(app)
        .get('/ready')
        .expect('Content-Type', /json/)
        .expect(200);
      
      expect(res.body).toHaveProperty('status', 'ready');
      expect(res.body).toHaveProperty('service', 'api-gateway');
      expect(res.body).toHaveProperty('timestamp');
    });
  });

  describe('GET /nonexistent', () => {
    it('should return 404 for unknown routes', async () => {
      const res = await request(app)
        .get('/nonexistent')
        .expect('Content-Type', /json/)
        .expect(404);
      
      expect(res.body).toHaveProperty('error', 'Not Found');
      expect(res.body).toHaveProperty('path', '/nonexistent');
    });
  });
});