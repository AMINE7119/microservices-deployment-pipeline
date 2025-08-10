package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
)

// Product represents a product in the catalog
type Product struct {
	ID          int       `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Price       float64   `json:"price"`
	Stock       int       `json:"stock"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// HealthResponse represents the health check response
type HealthResponse struct {
	Status      string    `json:"status"`
	Service     string    `json:"service"`
	Timestamp   time.Time `json:"timestamp"`
	Uptime      float64   `json:"uptime"`
	Environment string    `json:"environment"`
}

var (
	products   []Product
	productsMu sync.RWMutex
	idCounter  int = 1
	startTime  time.Time
)

func init() {
	startTime = time.Now()
	// Load environment variables
	godotenv.Load()
}

func main() {
	// Parse command line flags
	healthCheck := flag.Bool("health", false, "Run health check")
	flag.Parse()

	// If health check flag is set, perform health check and exit
	if *healthCheck {
		resp, err := http.Get("http://localhost:8081/health")
		if err != nil {
			fmt.Println("Health check failed:", err)
			os.Exit(1)
		}
		defer resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			fmt.Println("Health check passed")
			os.Exit(0)
		} else {
			fmt.Println("Health check failed with status:", resp.StatusCode)
			os.Exit(1)
		}
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	router := mux.NewRouter()

	// Root endpoint
	router.HandleFunc("/", rootHandler).Methods("GET")
	
	// Health and readiness endpoints
	router.HandleFunc("/health", healthHandler).Methods("GET")
	router.HandleFunc("/ready", readinessHandler).Methods("GET")
	
	// Product endpoints
	router.HandleFunc("/products", getProductsHandler).Methods("GET")
	router.HandleFunc("/products", createProductHandler).Methods("POST")
	router.HandleFunc("/products/{id}", getProductHandler).Methods("GET")
	router.HandleFunc("/products/{id}", updateProductHandler).Methods("PUT")
	router.HandleFunc("/products/{id}", deleteProductHandler).Methods("DELETE")

	// Add CORS middleware
	router.Use(corsMiddleware)
	router.Use(loggingMiddleware)

	log.Printf("Product Service starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, router))
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		
		next.ServeHTTP(w, r)
	})
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start))
	})
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"service":     "Product Service",
		"version":     "1.0.0",
		"description": "Product catalog microservice",
		"endpoints": map[string]string{
			"health":   "/health",
			"ready":    "/ready",
			"products": "/products",
		},
	})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "development"
	}
	
	health := HealthResponse{
		Status:      "healthy",
		Service:     "product-service",
		Timestamp:   time.Now(),
		Uptime:      time.Since(startTime).Seconds(),
		Environment: environment,
	}
	
	json.NewEncoder(w).Encode(health)
}

func readinessHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	// Check if service is ready (simplified)
	isReady := true
	
	if isReady {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":    "ready",
			"service":   "product-service",
			"timestamp": time.Now(),
		})
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":    "not ready",
			"service":   "product-service",
			"timestamp": time.Now(),
		})
	}
}

func getProductsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	productsMu.RLock()
	defer productsMu.RUnlock()
	
	json.NewEncoder(w).Encode(products)
}

func createProductHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	var product Product
	if err := json.NewDecoder(r.Body).Decode(&product); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request body"})
		return
	}
	
	productsMu.Lock()
	defer productsMu.Unlock()
	
	product.ID = idCounter
	product.CreatedAt = time.Now()
	product.UpdatedAt = time.Now()
	idCounter++
	
	products = append(products, product)
	
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(product)
}

func getProductHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid product ID"})
		return
	}
	
	productsMu.RLock()
	defer productsMu.RUnlock()
	
	for _, product := range products {
		if product.ID == id {
			json.NewEncoder(w).Encode(product)
			return
		}
	}
	
	w.WriteHeader(http.StatusNotFound)
	json.NewEncoder(w).Encode(map[string]string{"error": "Product not found"})
}

func updateProductHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid product ID"})
		return
	}
	
	var updatedProduct Product
	if err := json.NewDecoder(r.Body).Decode(&updatedProduct); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request body"})
		return
	}
	
	productsMu.Lock()
	defer productsMu.Unlock()
	
	for i, product := range products {
		if product.ID == id {
			updatedProduct.ID = id
			updatedProduct.CreatedAt = product.CreatedAt
			updatedProduct.UpdatedAt = time.Now()
			products[i] = updatedProduct
			json.NewEncoder(w).Encode(updatedProduct)
			return
		}
	}
	
	w.WriteHeader(http.StatusNotFound)
	json.NewEncoder(w).Encode(map[string]string{"error": "Product not found"})
}

func deleteProductHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid product ID"})
		return
	}
	
	productsMu.Lock()
	defer productsMu.Unlock()
	
	for i, product := range products {
		if product.ID == id {
			products = append(products[:i], products[i+1:]...)
			json.NewEncoder(w).Encode(map[string]string{"message": "Product deleted successfully"})
			return
		}
	}
	
	w.WriteHeader(http.StatusNotFound)
	json.NewEncoder(w).Encode(map[string]string{"error": "Product not found"})
}

// setupRoutes creates and configures the HTTP router for testing
func setupRoutes() *mux.Router {
	router := mux.NewRouter()

	// Root endpoint
	router.HandleFunc("/", rootHandler).Methods("GET")
	
	// Health and readiness endpoints
	router.HandleFunc("/health", healthHandler).Methods("GET")
	router.HandleFunc("/ready", readinessHandler).Methods("GET")
	
	// Product endpoints
	router.HandleFunc("/products", getProductsHandler).Methods("GET")
	router.HandleFunc("/products", createProductHandler).Methods("POST")
	router.HandleFunc("/products/{id}", getProductHandler).Methods("GET")
	router.HandleFunc("/products/{id}", updateProductHandler).Methods("PUT")
	router.HandleFunc("/products/{id}", deleteProductHandler).Methods("DELETE")

	// Add CORS middleware
	router.Use(corsMiddleware)
	router.Use(loggingMiddleware)

	return router
}