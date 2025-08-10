// Quick test script to verify proxy configuration
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

// Simple proxy test
app.use('/test-users', createProxyMiddleware({
  target: 'http://localhost:8000',
  changeOrigin: true,
  pathRewrite: {
    '^/test-users': '/users'
  },
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying: ${req.method} ${req.originalUrl} -> http://localhost:8000${req.url.replace('/test-users', '/users')}`);
  },
  onError: (err, req, res) => {
    console.error('Proxy error:', err.message);
    res.status(503).json({ error: err.message });
  }
}));

app.listen(9999, () => {
  console.log('Test proxy running on port 9999');
  console.log('Test with: curl http://localhost:9999/test-users');
});