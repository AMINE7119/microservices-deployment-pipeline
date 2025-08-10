#!/bin/bash

# Health check script for all services

echo "========================================="
echo "Microservices Health Check"
echo "========================================="
echo ""

# Function to check service health
check_service() {
    service_name=$1
    url=$2
    
    echo -n "Checking $service_name... "
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo "✅ Healthy"
        return 0
    else
        echo "❌ Unhealthy or not running"
        return 1
    fi
}

# Check each service
check_service "Frontend" "http://localhost:3000/health"
check_service "API Gateway" "http://localhost:8080/health"
check_service "User Service" "http://localhost:8000/health"
check_service "Product Service" "http://localhost:8081/health"
check_service "Order Service" "http://localhost:3001/health"

echo ""
echo "========================================="
echo "Infrastructure Services"
echo "========================================="
echo ""

# Check infrastructure
check_service "PostgreSQL" "http://localhost:5432" 2>/dev/null || echo "PostgreSQL: Check with 'docker ps'"
check_service "MongoDB" "http://localhost:27017" 2>/dev/null || echo "MongoDB: Check with 'docker ps'"
check_service "Redis" "http://localhost:6379" 2>/dev/null || echo "Redis: Check with 'docker ps'"
check_service "RabbitMQ Management" "http://localhost:15672"

echo ""
echo "To view container status: docker ps"
echo "To view logs: docker-compose logs [service-name]"