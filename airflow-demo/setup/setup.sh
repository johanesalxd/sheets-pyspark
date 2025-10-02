#!/bin/bash
# Setup script for PythonVirtualenvOperator with Cloud Composer.
#
# This script configures Cloud Composer to run notebooks using PythonVirtualenvOperator,
# which creates isolated Python environments for each task execution.
#
# Operations performed:
# - Enables required GCP APIs (Storage, BigQuery, Composer)
# - Creates GCS bucket for notebooks and outputs
# - Uploads notebook and credentials to GCS
# - Deploys DAG to Cloud Composer
# - Sets Airflow variables for DAG configuration
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Cloud Composer environment already created
# - Service account credentials file (drive-api.json) in parent directory
#
# Usage:
#     ./setup.sh [PROJECT_ID]
#
# Args:
#     PROJECT_ID: GCP project ID (optional, defaults to 'your-project-id')
#
# Exit codes:
#     0: Success
#     1: Error occurred (API enablement, bucket creation, or Composer operations)

set -e

# Configuration - Easy to change
PROJECT_ID="${1:-your-project-id}"
REGION="us-central1"
COMPOSER_ENV="composer-demo"
COMPOSER_LOCATION="us-central1"

# Derived variables
BUCKET_NAME="${PROJECT_ID}-notebooks"

echo "=========================================="
echo "Setup for PythonVirtualenvOperator"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Composer Environment: $COMPOSER_ENV"
echo "=========================================="
echo ""

# Set the project
echo "[1/6] Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "[2/6] Enabling required APIs..."
gcloud services enable \
    storage.googleapis.com \
    bigquery.googleapis.com \
    composer.googleapis.com \
    --project=$PROJECT_ID

echo "APIs enabled successfully!"

# Create GCS bucket
echo "[3/6] Creating GCS bucket..."
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
echo "[4/6] Uploading notebook to GCS..."
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
echo "[5/6] Deploying DAG to Cloud Composer..."
COMPOSER_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    --format="get(config.dagGcsPrefix)" | sed 's|/dags||')

if [ -z "$COMPOSER_BUCKET" ]; then
    echo "ERROR: Cloud Composer environment '$COMPOSER_ENV' not found in location '$COMPOSER_LOCATION'"
    echo "Verify the environment exists with: gcloud composer environments list --locations=$COMPOSER_LOCATION"
    echo "Or create it with: gcloud composer environments create $COMPOSER_ENV --location=$COMPOSER_LOCATION"
    exit 1
fi

echo "Uploading DAG to: $COMPOSER_BUCKET/dags/"
gsutil cp dags/sheets_bigquery_notebook_dag.py $COMPOSER_BUCKET/dags/

# Set Airflow Variables for the DAG
echo "[6/6] Setting Airflow Variables in Cloud Composer..."
gcloud composer environments run $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    variables set -- gcp_project_id $PROJECT_ID

gcloud composer environments run $COMPOSER_ENV \
    --location=$COMPOSER_LOCATION \
    variables set -- gcp_region $REGION

echo "Airflow Variables set successfully!"

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
echo ""
echo "Resources Created:"
echo "  - GCS bucket with directories"
echo "  - Notebook uploaded to GCS"
echo "  - DAG deployed to Cloud Composer"
echo ""
echo "How It Works:"
echo "  - PythonVirtualenvOperator creates isolated venv per task"
echo "  - Packages (papermill, gspread, bigframes) installed in venv"
echo "  - No package conflicts between DAGs"
echo "  - Runs on Composer workers (cost-effective)"
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
echo "   - View output notebooks: gs://$BUCKET_NAME/notebook-outputs/"
echo "   - Check BigQuery temp tables"
echo ""
echo "=========================================="
