# Dockerfile for notebook execution in Vertex AI
# This container runs Jupyter notebooks using Papermill

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY config/requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt google-cloud-storage

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Default command (will be overridden by DAG)
CMD ["python", "-m", "papermill"]
