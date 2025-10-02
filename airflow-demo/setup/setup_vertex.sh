#!/bin/bash
# Setup script for Vertex AI Custom Training with Cloud Composer
# Usage: ./setup_vertex.sh [PROJECT_ID]
# If PROJECT_ID is not provided, uses default: your-project-id

set -e

# Configuration - Easy to change
PROJECT_ID="${1:-your-project-id}"
REGION="us-central1"
COMPOSER_ENV="composer-demo"
COMPOSER_LOCATION="us-central1"

# Derived variables
BUCKET_NAME="${PROJECT_ID}-notebooks"
ARTIFACT_REGISTRY_REPO="notebooks"
IMAGE_NAME="notebook-executor"
IMAGE_TAG="latest"
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=========================================="
echo "Setup for Vertex AI Custom Training"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Composer Environment: $COMPOSER_ENV"
echo "Image URI: $IMAGE_URI"
echo "=========================================="
echo ""

# Set the project
echo "[1/11] Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "[2/11] Enabling required APIs..."
gcloud services enable \
    storage.googleapis.com \
    bigquery.googleapis.com \
    composer.googleapis.com \
    aiplatform.googleapis.com \
    artifactregistry.googleapis.com \
    --project=$PROJECT_ID

echo "APIs enabled successfully!"

# Create Artifact Registry repository
echo "[3/11] Creating Artifact Registry repository..."
if gcloud artifacts repositories describe $ARTIFACT_REGISTRY_REPO \
    --location=$REGION \
    --project=$PROJECT_ID &>/dev/null; then
    echo "Repository $ARTIFACT_REGISTRY_REPO already exists"
else
    gcloud artifacts repositories create $ARTIFACT_REGISTRY_REPO \
        --repository-format=docker \
        --location=$REGION \
        --description="Docker repository for notebook execution containers" \
        --project=$PROJECT_ID
    echo "Repository created"
fi

# Configure Docker authentication
echo "[4/11] Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build and push Docker image
echo "[5/11] Building and pushing Docker image..."
cd "$(dirname "$0")/.."  # Go to airflow-demo directory

docker build -t $IMAGE_URI -f docker/Dockerfile docker/
docker push $IMAGE_URI

echo "Docker image built and pushed successfully!"

# Create GCS bucket
echo "[6/11] Creating GCS bucket..."
if gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
    echo "Bucket gs://$BUCKET_NAME already exists"
else
    gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME
    echo "Bucket created"
fi

# Create bucket directories
echo "Creating bucket directories..."
gsutil -m mkdir -p gs://$BUCKET_NAME/notebooks/ 2>/dev/null || true
gsutil -m mkdir -p gs://$BUCKET_NAME/notebook-outputs-vertex/ 2>/dev/null || true
gsutil -m mkdir -p gs://$BUCKET_NAME/credentials/ 2>/dev/null || true

# Upload notebook to GCS
echo "[7/11] Uploading notebook to GCS..."
gsutil cp notebooks/sheets_bigquery_scheduled.ipynb \
    gs://$BUCKET_NAME/notebooks/sheets_bigquery_scheduled.ipynb
echo "Notebook uploaded successfully!"

# Upload credentials to GCS (if exists)
echo "Uploading credentials to GCS..."
if [ -f "../drive-api.json" ]; then
    gsutil cp ../drive-api.json gs://$BUCKET_NAME/credentials/drive-api.json
    echo "Credentials uploaded successfully!"
else
    echo "WARNING: drive-api.json not found in parent directory"
    echo "You'll need to upload it manually to: gs://$BUCKET_NAME/credentials/drive-api.json"
fi

# Deploy DAG to Cloud Composer
echo "[8/11] Deploying DAG to Cloud Composer..."
COMPOSER_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    --format="get(config.dagGcsPrefix)" | sed 's|/dags||')

if [ -z "$COMPOSER_BUCKET" ]; then
    echo "ERROR: Could not find Cloud Composer environment: $COMPOSER_ENV"
    echo "Please verify the environment exists and try again"
    exit 1
fi

echo "Uploading DAG to: $COMPOSER_BUCKET/dags/"
gsutil cp dags/sheets_bigquery_vertex_dag.py $COMPOSER_BUCKET/dags/

# Set Airflow Variables for the DAG
echo "[9/11] Setting Airflow Variables in Cloud Composer..."
gcloud composer environments run $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    variables set -- gcp_project_id $PROJECT_ID

gcloud composer environments run $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    variables set -- gcp_region $REGION

echo "Airflow Variables set successfully!"

# Check and install apache-airflow-providers-google if needed
echo "[10/11] Checking apache-airflow-providers-google version..."

CURRENT_VERSION=$(gcloud composer environments run $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    list_packages 2>/dev/null | grep "apache-airflow-providers-google" | awk '{print $2}' || echo "not-installed")

REQUIRED_VERSION="18.0.0"

echo "Current version: $CURRENT_VERSION"
echo "Required version: >=$REQUIRED_VERSION"

if [ "$CURRENT_VERSION" = "not-installed" ]; then
    echo "Provider not installed. Installing apache-airflow-providers-google>=$REQUIRED_VERSION..."
    echo "⏱️  This may take 10-15 minutes..."

    gcloud composer environments update $COMPOSER_ENV \
        --location=$COMPOSER_LOCATION \
        --update-pypi-package apache-airflow-providers-google>=$REQUIRED_VERSION

    echo "Provider installed successfully!"
elif [ "$(printf '%s\n' "$REQUIRED_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Current version $CURRENT_VERSION is older than required $REQUIRED_VERSION"
    echo "Upgrading apache-airflow-providers-google to >=$REQUIRED_VERSION..."
    echo "⏱️  This may take 10-15 minutes..."

    gcloud composer environments update $COMPOSER_ENV \
        --location=$COMPOSER_LOCATION \
        --update-pypi-package apache-airflow-providers-google>=$REQUIRED_VERSION

    echo "Provider upgraded successfully!"
else
    echo "✓ apache-airflow-providers-google $CURRENT_VERSION is already installed (>=$REQUIRED_VERSION)"
    echo "Skipping installation to save time"
fi

echo ""
echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
echo ""
echo "Configuration Summary:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Composer Environment: $COMPOSER_ENV"
echo "  GCS Bucket: gs://$BUCKET_NAME"
echo "  Container Image: $IMAGE_URI"
echo ""
echo "Resources Created:"
echo "  ✓ Artifact Registry repository"
echo "  ✓ Docker image built and pushed"
echo "  ✓ GCS bucket with directories"
echo "  ✓ Notebook uploaded to GCS"
echo "  ✓ DAG deployed to Cloud Composer"
echo ""
echo "How It Works:"
echo "  - Submits notebook as Vertex AI Custom Training job"
echo "  - Runs on dedicated compute (n1-standard-4)"
echo "  - Executes in isolated Docker container"
echo "  - Similar to Databricks submit job"
echo "  - Outputs saved to GCS"
echo ""
echo "Next Steps:"
echo "1. Verify credentials are uploaded:"
echo "   gsutil ls gs://$BUCKET_NAME/credentials/"
echo ""
echo "2. Trigger the DAG in Airflow UI:"
echo "   - Navigate to Cloud Composer Airflow UI"
echo "   - Find 'sheets_bigquery_vertex_dag'"
echo "   - Enable and trigger the DAG"
echo ""
echo "3. Monitor execution:"
echo "   - Check Airflow UI for task status"
echo "   - View Vertex AI Custom Training jobs in console"
echo "   - Check output notebooks: gs://$BUCKET_NAME/notebook-outputs-vertex/"
echo ""
echo "=========================================="
