#!/bin/bash
# Complete setup script for Vertex AI notebook execution with Cloud Composer
# Usage: ./setup_vertex_ai.sh [PROJECT_ID]
# If PROJECT_ID is not provided, uses default: your-project-id

set -e

# Configuration - Easy to change
PROJECT_ID="${1:-your-project-id}"
REGION="us-central1"
COMPOSER_ENV="composer-demo"
COMPOSER_LOCATION="us-central1"

# Derived variables
SERVICE_ACCOUNT_NAME="notebook-executor"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
BUCKET_NAME="${PROJECT_ID}-notebooks"
REPOSITORY_NAME="notebook-executor"
IMAGE_NAME="notebook-executor"
IMAGE_TAG="latest"
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=========================================="
echo "Complete Setup for Notebook Execution"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Composer Environment: $COMPOSER_ENV"
echo "Image URI: $IMAGE_URI"
echo "=========================================="
echo ""

# Set the project
echo "[1/10] Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "[2/10] Enabling required APIs..."
gcloud services enable \
    aiplatform.googleapis.com \
    artifactregistry.googleapis.com \
    storage.googleapis.com \
    bigquery.googleapis.com \
    compute.googleapis.com \
    composer.googleapis.com \
    --project=$PROJECT_ID

echo "APIs enabled successfully!"

# Create service account
echo "[3/10] Creating service account..."
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL --project=$PROJECT_ID &>/dev/null; then
    echo "Service account $SERVICE_ACCOUNT_EMAIL already exists"
else
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --display-name="Notebook Executor Service Account" \
        --project=$PROJECT_ID
    echo "Service account created"
fi

# Grant IAM roles
echo "[4/10] Granting IAM roles to service account..."
for role in \
    "roles/bigquery.dataEditor" \
    "roles/bigquery.jobUser" \
    "roles/storage.objectAdmin" \
    "roles/aiplatform.user"
do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
        --role="$role" \
        --condition=None \
        --quiet
done
echo "IAM roles granted successfully!"

# Create GCS bucket
echo "[5/10] Creating GCS bucket..."
if gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
    echo "Bucket gs://$BUCKET_NAME already exists"
else
    gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME
    echo "Bucket created"
fi

# Create bucket directories
echo "Creating bucket directories..."
gsutil -m mkdir -p gs://$BUCKET_NAME/notebooks/ 2>/dev/null || true
gsutil -m mkdir -p gs://$BUCKET_NAME/notebook-outputs/ 2>/dev/null || true
gsutil -m mkdir -p gs://$BUCKET_NAME/credentials/ 2>/dev/null || true

# Create Artifact Registry repository
echo "[6/10] Creating Artifact Registry repository..."
if gcloud artifacts repositories describe $REPOSITORY_NAME \
    --location=$REGION \
    --project=$PROJECT_ID &>/dev/null; then
    echo "Repository $REPOSITORY_NAME already exists"
else
    gcloud artifacts repositories create $REPOSITORY_NAME \
        --repository-format=docker \
        --location=$REGION \
        --description="Docker repository for notebook executor" \
        --project=$PROJECT_ID
    echo "Repository created"
fi

# Build and push Docker image
echo "[7/10] Building and pushing Docker image..."
echo "Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

echo "Building image: $IMAGE_URI"
cd "$(dirname "$0")/.."  # Go to airflow-demo directory
docker build -t $IMAGE_URI .

echo "Pushing image to Artifact Registry..."
docker push $IMAGE_URI
echo "Docker image built and pushed successfully!"

# Upload notebook to GCS
echo "[8/10] Uploading notebook to GCS..."
gsutil cp notebooks/sheets_bigquery_scheduled.ipynb \
    gs://$BUCKET_NAME/notebooks/sheets_bigquery_scheduled.ipynb
echo "Notebook uploaded successfully!"

# Upload credentials to GCS (if exists)
echo "[9/10] Uploading credentials to GCS..."
if [ -f "../drive-api.json" ]; then
    gsutil cp ../drive-api.json gs://$BUCKET_NAME/credentials/drive-api.json
    echo "Credentials uploaded successfully!"
else
    echo "WARNING: drive-api.json not found in parent directory"
    echo "You'll need to upload it manually to: gs://$BUCKET_NAME/credentials/drive-api.json"
fi

# Deploy DAG to Cloud Composer
echo "[10/10] Deploying DAG to Cloud Composer..."
COMPOSER_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    --format="get(config.dagGcsPrefix)" | sed 's|/dags||')

if [ -z "$COMPOSER_BUCKET" ]; then
    echo "ERROR: Could not find Cloud Composer environment: $COMPOSER_ENV"
    echo "Please verify the environment exists and try again"
    exit 1
fi

echo "Uploading DAG to: $COMPOSER_BUCKET/dags/"
gsutil cp dags/sheets_bigquery_notebook_dag.py $COMPOSER_BUCKET/dags/

echo ""
echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
echo ""
echo "Configuration Summary:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Composer Environment: $COMPOSER_ENV"
echo "  Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "  GCS Bucket: gs://$BUCKET_NAME"
echo "  Docker Image: $IMAGE_URI"
echo ""
echo "Resources Created:"
echo "  ✓ Service account with IAM roles"
echo "  ✓ GCS bucket with directories"
echo "  ✓ Artifact Registry repository"
echo "  ✓ Docker image built and pushed"
echo "  ✓ Notebook uploaded to GCS"
echo "  ✓ DAG deployed to Cloud Composer"
echo ""
echo "Next Steps:"
echo "1. Verify credentials are uploaded:"
echo "   gsutil ls gs://$BUCKET_NAME/credentials/"
echo ""
echo "2. Update DAG variables in Airflow UI (if needed):"
echo "   - GCS_NOTEBOOK_PATH: gs://$BUCKET_NAME/notebooks/sheets_bigquery_scheduled.ipynb"
echo "   - GCS_OUTPUT_PATH: gs://$BUCKET_NAME/notebook-outputs/"
echo "   - SERVICE_ACCOUNT: $SERVICE_ACCOUNT_EMAIL"
echo "   - IMAGE_URI: $IMAGE_URI"
echo ""
echo "3. Trigger the DAG in Airflow UI:"
echo "   - Navigate to Cloud Composer Airflow UI"
echo "   - Find 'sheets_bigquery_notebook_dag'"
echo "   - Enable and trigger the DAG"
echo ""
echo "=========================================="
