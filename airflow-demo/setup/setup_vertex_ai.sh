#!/bin/bash
# Setup script for Vertex AI notebook execution environment
# Project: your-project-id
# Region: us-central1

set -e

PROJECT_ID="your-project-id"
REGION="us-central1"

echo "=========================================="
echo "Setting up Vertex AI for Notebook Execution"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "=========================================="

# Set the project
echo "Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable \
    aiplatform.googleapis.com \
    notebooks.googleapis.com \
    storage.googleapis.com \
    bigquery.googleapis.com \
    compute.googleapis.com \
    --project=$PROJECT_ID

echo "APIs enabled successfully!"

# Create a service account for notebook execution (if it doesn't exist)
SERVICE_ACCOUNT_NAME="notebook-executor"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Checking if service account exists..."
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL --project=$PROJECT_ID &>/dev/null; then
    echo "Service account $SERVICE_ACCOUNT_EMAIL already exists"
else
    echo "Creating service account: $SERVICE_ACCOUNT_EMAIL"
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --display-name="Notebook Executor Service Account" \
        --project=$PROJECT_ID
fi

# Grant necessary IAM roles to the service account
echo "Granting IAM roles to service account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/bigquery.dataEditor" \
    --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/bigquery.jobUser" \
    --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/storage.objectAdmin" \
    --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/aiplatform.user" \
    --condition=None

echo "IAM roles granted successfully!"

# Create a GCS bucket for notebook storage (if it doesn't exist)
BUCKET_NAME="${PROJECT_ID}-notebooks"
echo "Checking if GCS bucket exists..."
if gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
    echo "Bucket gs://$BUCKET_NAME already exists"
else
    echo "Creating GCS bucket: gs://$BUCKET_NAME"
    gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME
fi

# Create directories in the bucket
echo "Creating bucket directories..."
gsutil -m mkdir -p gs://$BUCKET_NAME/notebooks/
gsutil -m mkdir -p gs://$BUCKET_NAME/notebook-outputs/

echo ""
echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Upload your notebook to: gs://$BUCKET_NAME/notebooks/"
echo "2. Update the DAG configuration with:"
echo "   - GCS_NOTEBOOK_PATH: gs://$BUCKET_NAME/notebooks/sheets_bigquery_scheduled.ipynb"
echo "   - GCS_OUTPUT_PATH: gs://$BUCKET_NAME/notebook-outputs/"
echo "   - SERVICE_ACCOUNT: $SERVICE_ACCOUNT_EMAIL"
echo ""
echo "3. Upload your service account credentials (drive-api.json) to a secure location"
echo "4. Deploy the DAG to Cloud Composer"
echo ""
echo "=========================================="
