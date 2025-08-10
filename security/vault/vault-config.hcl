# HashiCorp Vault Configuration
# Production-ready secrets management

# Storage backend configuration
storage "file" {
  path = "/vault/data"
}

# For production, use Consul or Raft storage
# storage "consul" {
#   address = "127.0.0.1:8500"
#   path    = "vault/"
# }

# storage "raft" {
#   path    = "/vault/data"
#   node_id = "node1"
# }

# Listener configuration
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 0
  
  # TLS Configuration
  tls_cert_file = "/vault/certs/vault.crt"
  tls_key_file  = "/vault/certs/vault.key"
  
  # Security headers
  custom_response_headers {
    "Strict-Transport-Security" = ["max-age=31536000; includeSubDomains"]
    "X-Content-Type-Options"    = ["nosniff"]
    "X-Frame-Options"           = ["DENY"]
    "X-XSS-Protection"          = ["1; mode=block"]
    "Content-Security-Policy"   = ["default-src 'self'"]
  }
}

# API configuration
api_addr = "https://vault.example.com:8200"
cluster_addr = "https://vault.example.com:8201"

# UI configuration
ui = true

# Telemetry configuration
telemetry {
  prometheus_retention_time = "0s"
  disable_hostname = true
}

# Audit logging
# Enable after initialization
# audit {
#   file {
#     path = "/vault/logs/audit.log"
#     log_raw = false
#     hmac_accessor = true
#     mode = "0600"
#     format = "json"
#   }
# }

# Performance tuning
max_lease_ttl = "10h"
default_lease_ttl = "10h"
cluster_name = "microservices-vault"
disable_mlock = false

# Security settings
disable_sealwrap = false
disable_cache = false
disable_indexing = false

# Plugin directory
plugin_directory = "/vault/plugins"