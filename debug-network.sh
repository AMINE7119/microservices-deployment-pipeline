#!/bin/bash

echo "=== API Gateway Network Debug ==="
echo ""

echo "1. Checking container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "2. Testing API Gateway health:"
curl -s http://localhost:8080/health || echo "Health check failed"
echo ""

echo "3. Testing from API Gateway to User Service:"
docker exec api-gateway curl -s http://user-service:8000/health || echo "Internal network test failed"
echo ""

echo "4. Recent API Gateway logs:"
docker-compose logs --tail=10 api-gateway
echo ""

echo "5. Testing direct user service access:"
curl -s http://localhost:8000/health || echo "Direct user service test failed"
echo ""