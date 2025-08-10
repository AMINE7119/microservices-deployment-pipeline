# Application secrets policy
# Defines access permissions for microservices

# Database credentials - read only
path "secret/data/database/*" {
  capabilities = ["read", "list"]
}

# API keys - read only
path "secret/data/apikeys/*" {
  capabilities = ["read", "list"]
}

# Service-specific secrets
path "secret/data/services/api-gateway/*" {
  capabilities = ["read", "list"]
}

path "secret/data/services/user-service/*" {
  capabilities = ["read", "list"]
}

path "secret/data/services/product-service/*" {
  capabilities = ["read", "list"]
}

path "secret/data/services/order-service/*" {
  capabilities = ["read", "list"]
}

path "secret/data/services/frontend/*" {
  capabilities = ["read", "list"]
}

# JWT secrets - read only
path "secret/data/jwt/*" {
  capabilities = ["read"]
}

# TLS certificates - read only
path "pki/issue/*" {
  capabilities = ["create", "update"]
}

path "pki/certs" {
  capabilities = ["list"]
}

# Transit encryption
path "transit/encrypt/app" {
  capabilities = ["update"]
}

path "transit/decrypt/app" {
  capabilities = ["update"]
}

# Token management
path "auth/token/create" {
  capabilities = ["create", "update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Cubbyhole (temporary secrets)
path "cubbyhole/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# System capabilities
path "sys/capabilities-self" {
  capabilities = ["read"]
}

path "sys/leases/renew" {
  capabilities = ["update"]
}

path "sys/leases/lookup" {
  capabilities = ["read"]
}

# Deny access to admin paths
path "sys/*" {
  capabilities = ["deny"]
}

path "auth/*" {
  capabilities = ["deny"]
}