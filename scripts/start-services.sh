#!/bin/bash

# Script to start services locally (without Go requirement)

echo "Starting infrastructure services..."
docker-compose -f docker-compose.dev.yml up -d

echo "Waiting for infrastructure to be ready..."
sleep 10

echo "Starting Node.js services..."

# API Gateway
cd services/api-gateway
npm start &
API_PID=$!
cd ../..

# Frontend
cd services/frontend
npm start &
FRONTEND_PID=$!
cd ../..

# Order Service
cd services/order-service
npm start &
ORDER_PID=$!
cd ../..

# User Service (Python with uv)
cd services/user-service
source .venv/bin/activate
python app.py &
USER_PID=$!
cd ../..

echo ""
echo "Services are starting..."
echo ""
echo "Service URLs:"
echo "  Frontend: http://localhost:3000"
echo "  API Gateway: http://localhost:8080"
echo "  User Service: http://localhost:8000 (FastAPI docs: http://localhost:8000/docs)"
echo "  Order Service: http://localhost:3001"
echo "  RabbitMQ Management: http://localhost:15672 (admin/admin)"
echo ""
echo "Note: Product Service requires Go to be installed."
echo "To install Go on Ubuntu/WSL: sudo apt install golang-go"
echo ""
echo "Press Ctrl+C to stop all services"

# Function to cleanup on exit
cleanup() {
    echo "Stopping services..."
    kill $API_PID $FRONTEND_PID $ORDER_PID $USER_PID 2>/dev/null
    docker-compose -f docker-compose.dev.yml down
    exit 0
}

# Set trap to cleanup on Ctrl+C
trap cleanup INT

# Wait forever
while true; do
    sleep 1
done