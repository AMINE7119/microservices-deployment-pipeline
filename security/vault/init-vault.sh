#!/bin/bash

# HashiCorp Vault Initialization Script
# Secure secrets management setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
VAULT_TOKEN_FILE="/vault/init/root-token"
VAULT_KEYS_FILE="/vault/init/unseal-keys"

echo -e "${GREEN}Starting HashiCorp Vault initialization...${NC}"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status 2>/dev/null; do
  sleep 2
done

# Check if Vault is already initialized
if vault status | grep -q "Initialized.*true"; then
  echo -e "${YELLOW}Vault is already initialized${NC}"
else
  echo "Initializing Vault..."
  vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json > /vault/init/init.json
  
  # Extract root token and unseal keys
  cat /vault/init/init.json | jq -r '.root_token' > "$VAULT_TOKEN_FILE"
  cat /vault/init/init.json | jq -r '.unseal_keys_b64[]' > "$VAULT_KEYS_FILE"
  
  echo -e "${GREEN}Vault initialized successfully${NC}"
  echo -e "${YELLOW}IMPORTANT: Securely backup the files in /vault/init/${NC}"
fi

# Unseal Vault
echo "Unsealing Vault..."
UNSEAL_KEYS=$(cat "$VAULT_KEYS_FILE" | head -3)
for key in $UNSEAL_KEYS; do
  vault operator unseal "$key"
done

# Login with root token
export VAULT_TOKEN=$(cat "$VAULT_TOKEN_FILE")
vault login "$VAULT_TOKEN"

echo -e "${GREEN}Configuring Vault...${NC}"

# Enable audit logging
vault audit enable file \
  file_path=/vault/logs/audit.log \
  log_raw=false \
  hmac_accessor=true \
  mode=0600 \
  format=json || true

# Enable KV v2 secrets engine
vault secrets enable -version=2 -path=secret kv || true

# Enable Transit secrets engine for encryption
vault secrets enable transit || true
vault write -f transit/keys/app || true

# Enable PKI secrets engine for TLS certificates
vault secrets enable pki || true
vault secrets tune -max-lease-ttl=87600h pki || true

# Configure PKI
vault write -field=certificate pki/root/generate/internal \
  common_name="Microservices CA" \
  ttl=87600h > /vault/ca/CA_cert.crt

vault write pki/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

# Enable AppRole auth method
vault auth enable approle || true

# Create policies
echo "Creating security policies..."
vault policy write app-policy /vault/policies/app-policy.hcl

# Create AppRole for services
vault write auth/approle/role/microservices \
  token_policies="app-policy" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0 \
  secret_id_num_uses=0

# Store initial secrets
echo "Storing initial secrets..."

# Database credentials
vault kv put secret/database/postgres \
  username="app_user" \
  password="$(openssl rand -base64 32)" \
  host="postgres" \
  port="5432" \
  database="microservices"

vault kv put secret/database/mongodb \
  username="app_user" \
  password="$(openssl rand -base64 32)" \
  connection_string="mongodb://mongodb:27017/microservices"

# Redis credentials
vault kv put secret/database/redis \
  password="$(openssl rand -base64 32)" \
  host="redis" \
  port="6379"

# RabbitMQ credentials
vault kv put secret/messaging/rabbitmq \
  username="app_user" \
  password="$(openssl rand -base64 32)" \
  host="rabbitmq" \
  port="5672"

# JWT secret
vault kv put secret/jwt/signing-key \
  secret="$(openssl rand -base64 64)"

# API keys
vault kv put secret/apikeys/external \
  stripe_key="sk_test_$(openssl rand -hex 24)" \
  sendgrid_key="SG.$(openssl rand -base64 32)" \
  aws_access_key="AKIA$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')" \
  aws_secret_key="$(openssl rand -base64 40)"

# Service-specific secrets
for service in api-gateway user-service product-service order-service frontend; do
  vault kv put secret/services/$service/config \
    service_key="$(openssl rand -base64 32)" \
    internal_api_key="$(openssl rand -hex 32)"
done

# Get AppRole credentials for services
ROLE_ID=$(vault read -field=role_id auth/approle/role/microservices/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/microservices/secret-id)

echo -e "${GREEN}Vault configuration complete!${NC}"
echo ""
echo "AppRole credentials for services:"
echo "ROLE_ID: $ROLE_ID"
echo "SECRET_ID: $SECRET_ID"
echo ""
echo -e "${YELLOW}Store these credentials securely in your CI/CD system${NC}"

# Create backup
echo "Creating Vault backup..."
vault operator raft snapshot save /vault/backup/vault-backup-$(date +%Y%m%d-%H%M%S).snap || true

echo -e "${GREEN}Vault initialization and configuration complete!${NC}"