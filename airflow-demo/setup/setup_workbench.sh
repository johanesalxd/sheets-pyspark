#!/bin/bash
# Setup script for Vertex AI Workbench notebook execution with Cloud Composer
# Usage: ./setup_workbench.sh [PROJECT_ID]
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

echo "=========================================="
echo "Setup for Workbench Notebook Execution"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Composer Environment: $COMPOSER_ENV"
echo "=========================================="
echo ""

# Set the project
echo "[1/7] Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "[2/7] Enabling required APIs..."
gcloud services enable \
    notebooks.googleapis.com \
    aiplatform.googleapis.com \
    storage.googleapis.com \
    bigquery.googleapis.com \
    composer.googleapis.com \
    --project=$PROJECT_ID

echo "APIs enabled successfully!"

# Create service account
echo "[3/7] Creating service account..."
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL --project=$PROJECT_ID &>/dev/null; then
    echo "Service account $SERVICE_ACCOUNT_EMAIL already exists"
else
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --display-name="Notebook Executor Service Account" \
        --project=$PROJECT_ID
    echo "Service account created"
fi

# Grant IAM roles
echo "[4/7] Granting IAM roles to service account..."
for role in \
    "roles/bigquery.dataEditor" \
    "roles/bigquery.jobUser" \
    "roles/storage.objectAdmin" \
    "roles/notebooks.runner"
do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
        --role="$role" \
        --condition=None \
        --quiet
done
echo "IAM roles granted successfully!"

# Create GCS bucket
echo "[5/7] Creating GCS bucket..."
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

# Upload notebook to GCS
echo "[6/7] Uploading notebook to GCS..."
cd "$(dirname "$0")/.."  # Go to airflow-demo directory
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
echo "[7/7] Deploying DAG to Cloud Composer..."
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

# Install required Python package in Cloud Composer
echo "Installing google-cloud-notebooks package in Cloud Composer..."
gcloud composer environments update $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    --update-pypi-package google-cloud-notebooks==1.0.0 \
    --quiet

echo "Package installation initiated (this may take a few minutes)"

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
echo ""
echo "Resources Created:"
echo "  ✓ Service account with IAM roles"
echo "  ✓ GCS bucket with directories"
echo "  ✓ Notebook uploaded to GCS"
echo "  ✓ DAG deployed to Cloud Composer"
echo ""
echo "Next Steps:"
echo "1. Verify credentials are uploaded:"
echo "   gsutil ls gs://$BUCKET_NAME/credentials/"
echo ""
echo "2. Trigger the DAG in Airflow UI:"
echo "   - Navigate to Cloud Composer Airflow UI"
echo "   - Find 'sheets_bigquery_notebook_dag'"
echo "   - Enable and trigger the DAG"
echo ""
echo "3. Monitor execution:"
echo "   - Check Airflow UI for task status"
echo "   - View results in: gs://$BUCKET_NAME/notebook-outputs/"
echo "   - Check BigQuery temp tables"
echo ""
echo "=========================================="
