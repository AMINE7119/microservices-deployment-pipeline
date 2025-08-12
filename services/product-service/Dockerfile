# Security-hardened multi-stage Dockerfile for Product Service (Go)
# Implements CIS Docker Benchmark and OWASP best practices

# Stage 1: Build stage with security scanning
FROM golang:1.24-alpine AS builder

# Add security labels
LABEL security.scan="true" \
      maintainer="devops@company.com" \
      version="2.0.0" \
      description="Hardened Product Service"

# Install security updates and build tools
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    git \
    ca-certificates \
    gcc \
    musl-dev \
    && rm -rf /var/cache/apk/*

# Install security scanning tools (compatible with Go 1.21)
RUN go install github.com/securego/gosec/v2/cmd/gosec@v2.18.2 && \
    go install golang.org/x/vuln/cmd/govulncheck@v1.0.1

# Set working directory
WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download and verify dependencies
RUN go mod download && \
    go mod verify

# Copy source code
COPY . .

# Run security scans during build
RUN gosec -fmt json -out gosec-report.json ./... || true && \
    govulncheck ./... || true

# Build the binary with security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -extldflags '-static'" \
    -a -installsuffix cgo \
    -trimpath \
    -o product-service \
    main.go

# Remove source code and build artifacts
RUN rm -rf /app/*.go /app/go.* /app/tests/

# Stage 2: Distroless production image
FROM gcr.io/distroless/static-debian11:nonroot

# Add security labels
LABEL security.scan="true" \
      security.nonroot="true" \
      security.distroless="true" \
      security.minimal="true"

# Copy the binary from builder
COPY --from=builder --chown=nonroot:nonroot /app/product-service /product-service

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Use non-root user (distroless default: 65532)
USER nonroot

# Expose port (non-privileged)
EXPOSE 8081

# Health check (binary should support -health flag)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/product-service", "-health"]

# Security: No shell, minimal attack surface, static binary
# Start the application
ENTRYPOINT ["/product-service"]