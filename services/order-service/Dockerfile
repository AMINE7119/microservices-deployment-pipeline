# Security-hardened multi-stage Dockerfile for Order Service
# Implements CIS Docker Benchmark and OWASP best practices

# Stage 1: Build stage with security scanning
FROM node:24-alpine AS builder

# Add security labels
LABEL security.scan="true" \
      maintainer="devops@company.com" \
      version="2.0.0" \
      description="Hardened Order Service"

# Install security updates
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy package files with specific permissions
COPY --chown=node:node package*.json ./

# Install dependencies with audit
RUN npm ci --only=production && \
    npm audit fix && \
    npm cache clean --force && \
    rm -rf /tmp/*

# Copy application code
COPY --chown=node:node . .

# Remove unnecessary files
RUN rm -rf .git .gitignore .dockerignore *.md tests/ coverage/ .env.example

# Stage 2: Distroless production image
FROM gcr.io/distroless/nodejs18-debian11:nonroot

# Add security labels
LABEL security.scan="true" \
      security.nonroot="true" \
      security.distroless="true"

# Set working directory
WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /app/index.js ./
COPY --from=builder --chown=nonroot:nonroot /app/package.json ./

# Set security environment variables
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=2048 --enable-source-maps" \
    NPM_CONFIG_LOGLEVEL=error

# Use non-root user (distroless default)
USER nonroot

# Expose port (non-privileged)
EXPOSE 3001

# Health check with timeout
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/nodejs/bin/node", "-e", "require('http').get('http://localhost:3001/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); });"]

# Security: No shell, minimal attack surface
# Start the application
ENTRYPOINT ["/nodejs/bin/node"]
CMD ["index.js"]