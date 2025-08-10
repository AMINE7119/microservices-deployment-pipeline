#!/bin/bash

# API Testing Script

echo "========================================="
echo "API Gateway Integration Test"
echo "========================================="
echo ""

BASE_URL="http://localhost:8080/api"

# Function to test endpoint
test_endpoint() {
    method=$1
    endpoint=$2
    data=$3
    description=$4
    
    echo "Testing: $description"
    echo "Request: $method $BASE_URL$endpoint"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -X POST "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    else
        response=$(curl -s "$BASE_URL$endpoint")
    fi
    
    echo "Response: $response"
    echo "---"
    echo ""
}

# Test User Service
echo "📋 USER SERVICE TESTS"
echo "===================="
test_endpoint "POST" "/users" '{"username":"test1","email":"test1@example.com","full_name":"Test User 1"}' "Create User"
test_endpoint "GET" "/users" "" "Get All Users"
echo ""

# Test Product Service
echo "📦 PRODUCT SERVICE TESTS"
echo "======================="
test_endpoint "POST" "/products" '{"name":"Keyboard","description":"Mechanical keyboard","price":79.99,"stock":25}' "Create Product"
test_endpoint "GET" "/products" "" "Get All Products"
echo ""

# Test Order Service
echo "🛒 ORDER SERVICE TESTS"
echo "====================="
test_endpoint "POST" "/orders" '{"userId":"1","products":[{"id":"1","quantity":2}],"totalAmount":159.98}' "Create Order"
test_endpoint "GET" "/orders" "" "Get All Orders"
echo ""

echo "========================================="
echo "✅ API Gateway Integration Test Complete"
echo "========================================="