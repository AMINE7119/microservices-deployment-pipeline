package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

// Import the main package functions and types
// We'll need to move this to the main package or create a separate file

func TestHealthEndpoint(t *testing.T) {
	router := setupRouter()

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/health", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, 200, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "healthy", response["status"])
	assert.Equal(t, "product-service", response["service"])
	assert.Contains(t, response, "timestamp")
}

func TestReadyEndpoint(t *testing.T) {
	router := setupRouter()

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/ready", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, 200, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "ready", response["status"])
	assert.Equal(t, "product-service", response["service"])
}

func TestGetProductsEmpty(t *testing.T) {
	router := setupRouter()

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/products", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, 200, w.Code)

	var response []Product
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.IsType(t, []Product{}, response)
}

func TestCreateProduct(t *testing.T) {
	router := setupRouter()

	product := Product{
		Name:        "Test Product",
		Description: "Test Description",
		Price:       99.99,
	}

	jsonData, _ := json.Marshal(product)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/products", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, 201, w.Code)

	var response Product
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, product.Name, response.Name)
	assert.Equal(t, product.Description, response.Description)
	assert.Equal(t, product.Price, response.Price)
	assert.NotZero(t, response.ID)
	assert.NotZero(t, response.CreatedAt)
}

func TestCreateProductInvalidData(t *testing.T) {
	router := setupRouter()

	// Test with missing required fields
	invalidProduct := map[string]interface{}{
		"name": "Test Product",
		// Missing description and price
	}

	jsonData, _ := json.Marshal(invalidProduct)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/products", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, 400, w.Code)
}

func TestGetProductNotFound(t *testing.T) {
	router := setupRouter()

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/products/99999", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, 404, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "Product not found", response["error"])
}

func TestProductCRUDFlow(t *testing.T) {
	router := setupRouter()

	// Create product
	product := Product{
		Name:        "CRUD Test Product",
		Description: "CRUD Test Description",
		Price:       199.99,
	}

	jsonData, _ := json.Marshal(product)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/products", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, 201, w.Code)

	var createdProduct Product
	err := json.Unmarshal(w.Body.Bytes(), &createdProduct)
	assert.NoError(t, err)
	productID := createdProduct.ID

	// Get product
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("GET", "/products/"+string(rune(productID)), nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, 200, w.Code)

	var fetchedProduct Product
	err = json.Unmarshal(w.Body.Bytes(), &fetchedProduct)
	assert.NoError(t, err)
	assert.Equal(t, product.Name, fetchedProduct.Name)

	// Update product
	updatedProduct := Product{
		Name:        "Updated CRUD Product",
		Description: "Updated Description",
		Price:       299.99,
	}

	jsonData, _ = json.Marshal(updatedProduct)
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("PUT", "/products/"+string(rune(productID)), bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	assert.Equal(t, 200, w.Code)

	var responseProduct Product
	err = json.Unmarshal(w.Body.Bytes(), &responseProduct)
	assert.NoError(t, err)
	assert.Equal(t, updatedProduct.Name, responseProduct.Name)

	// Delete product
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("DELETE", "/products/"+string(rune(productID)), nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, 204, w.Code)

	// Verify product is deleted
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("GET", "/products/"+string(rune(productID)), nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, 404, w.Code)
}