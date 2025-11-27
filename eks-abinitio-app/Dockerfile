FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY src/ /app/src/

# Create directories for configuration and data
RUN mkdir -p /app/config /app/logs /app/data

# Set Python path
ENV PYTHONPATH=/app/src:/app

# Set default environment variables (can be overridden by ConfigMap/values.yaml)
ENV ABINITIO_API_BASE=https://abinitio-api-bi-abi-apps-dev.cluster \
    OPERATION=submit \
    JOB_SPEC_PATH=/app/config/job_spec.yaml \
    JOB_NAME="" \
    POLL_INTERVAL=10 \
    MAX_POLL_ATTEMPTS=60 \
    POLL=false

# Make scripts executable
RUN chmod +x /app/src/*.py

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import sys; sys.exit(0)"

# Run the batch service
CMD ["python3", "/app/src/abinitio_batch_service.py"]
