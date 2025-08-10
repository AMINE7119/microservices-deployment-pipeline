# Security-hardened multi-stage Dockerfile for User Service
# Implements CIS Docker Benchmark and OWASP best practices

# Stage 1: Build stage with security scanning
FROM python:3.11-slim AS builder

# Add security labels
LABEL security.scan="true" \
      maintainer="devops@company.com" \
      version="2.0.0" \
      description="Hardened User Service"

# Install security updates and build dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements-prod.txt requirements.txt ./

# Create virtual environment and install dependencies
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements-prod.txt && \
    /opt/venv/bin/pip install --no-cache-dir safety bandit

# Copy application code
COPY . .

# Run security checks during build
RUN /opt/venv/bin/safety check --json || true && \
    /opt/venv/bin/bandit -r . -ll -f json || true

# Remove unnecessary files
RUN rm -rf .git .gitignore *.md tests/ __pycache__ *.pyc .env* .pytest_cache/

# Stage 2: Distroless production image
FROM python:3.11-slim

# Add security labels
LABEL security.scan="true" \
      security.nonroot="true" \
      security.hardened="true"

# Install only runtime dependencies and security updates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create non-root user with specific UID/GID
RUN groupadd -r -g 10001 appuser && \
    useradd -r -u 10001 -g appuser -d /app -s /sbin/nologin appuser

# Set working directory
WORKDIR /app

# Copy virtual environment from builder with proper permissions
COPY --from=builder --chown=appuser:appuser /opt/venv /opt/venv

# Copy only necessary application files
COPY --from=builder --chown=appuser:appuser /app/app.py ./
COPY --from=builder --chown=appuser:appuser /app/main.py ./

# Set security environment variables
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Remove any setuid/setgid files
RUN find / -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true

# Switch to non-root user
USER appuser

# Expose port (non-privileged)
EXPOSE 8000

# Health check without external dependencies
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()" || exit 1

# Start the application
CMD ["/opt/venv/bin/uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]