FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY src/ /app/src/

# Create config directory for runtime YAML
RUN mkdir -p /app/config

# Set Python path
ENV PYTHONPATH=/app

# Set default environment variables
ENV ABINITIO_API_BASE=https://abinitio-api-bi-dev
ENV ABINITIO_OPERATOR_NAMESPACE=abinitio-operator
ENV RUNTIME_YAML_PATH=/app/config/runtime.yaml

# Make script executable
RUN chmod +x /app/src/abinitio_batch_service.py

# Run the batch service
CMD ["python", "/app/src/abinitio_batch_service.py"]
