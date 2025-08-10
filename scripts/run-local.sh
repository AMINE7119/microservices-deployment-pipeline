#!/bin/bash

# Script to run all services locally for development

echo "Starting all microservices locally..."

# Function to run service in background
run_service() {
    service_name=$1
    service_dir=$2
    command=$3
    
    echo "Starting $service_name..."
    cd "services/$service_dir"
    $command &
    cd ../..
    sleep 2
}

# Start infrastructure first (using docker-compose)
echo "Starting infrastructure services (databases, redis, rabbitmq)..."
docker-compose -f docker-compose.dev.yml up -d

echo "Waiting for infrastructure to be ready..."
sleep 10

# Start services
run_service "API Gateway" "api-gateway" "npm start"
run_service "Frontend" "frontend" "npm start"
run_service "Order Service" "order-service" "npm start"

# For Python service, use virtual environment with uv
echo "Starting User Service..."
cd services/user-service
if [ -d ".venv" ]; then
    source .venv/bin/activate
elif [ -d "venv" ]; then
    source venv/bin/activate
fi
python app.py &
cd ../..

# For Go service
echo "Starting Product Service..."
cd services/product-service
go run main.go &
cd ../..

echo "All services started!"
echo ""
echo "Service URLs:"
echo "  Frontend: http://localhost:3000"
echo "  API Gateway: http://localhost:8080"
echo "  User Service: http://localhost:8000"
echo "  Product Service: http://localhost:8081"
echo "  Order Service: http://localhost:3001"
echo "  RabbitMQ Management: http://localhost:15672 (admin/admin)"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for user interrupt
wait