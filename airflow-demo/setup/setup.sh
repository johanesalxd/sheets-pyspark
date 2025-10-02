#!/bin/bash
# Setup script for Cloud Composer notebook execution with PapermillOperator
# Usage: ./setup.sh [PROJECT_ID]
# If PROJECT_ID is not provided, uses default: your-project-id

set -e

# Configuration - Easy to change
PROJECT_ID="${1:-your-project-id}"
REGION="us-central1"
COMPOSER_ENV="composer-demo"
COMPOSER_LOCATION="us-central1"

# Derived variables
BUCKET_NAME="${PROJECT_ID}-notebooks"

echo "=========================================="
echo "Setup for Papermill Notebook Execution"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Composer Environment: $COMPOSER_ENV"
echo "=========================================="
echo ""

# Set the project
echo "[1/5] Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "[2/5] Enabling required APIs..."
gcloud services enable \
    storage.googleapis.com \
    bigquery.googleapis.com \
    composer.googleapis.com \
    --project=$PROJECT_ID

echo "APIs enabled successfully!"

# Create GCS bucket
echo "[3/5] Creating GCS bucket..."
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
echo "[4/5] Uploading notebook to GCS..."
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
echo "[5/5] Deploying DAG to Cloud Composer..."
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

# Install Python packages from requirements.txt
if [ -f "requirements.txt" ]; then
    echo "Checking if packages from requirements.txt are installed..."
    INSTALLED_PACKAGES=$(gcloud composer environments describe $COMPOSER_ENV \
        --location=$COMPOSER_LOCATION \
        --format="value(config.softwareConfig.pypiPackages)")

    NEEDS_INSTALL=false
    while IFS= read -r package; do
        # Skip empty lines and comments
        [[ -z "$package" || "$package" =~ ^#.* ]] && continue
        package_name=$(echo "$package" | cut -d'=' -f1 | cut -d'>' -f1 | cut -d'<' -f1 | tr -d ' ')
        if ! echo "$INSTALLED_PACKAGES" | grep -q "$package_name"; then
            NEEDS_INSTALL=true
            break
        fi
    done < requirements.txt

    if [ "$NEEDS_INSTALL" = true ]; then
        echo "Installing packages from requirements.txt in Cloud Composer..."
        gcloud composer environments update $COMPOSER_ENV \
            --location=$COMPOSER_LOCATION \
            --update-pypi-packages-from-file requirements.txt \
            --quiet
        echo "Package installation initiated (this may take a few minutes)"
    else
        echo "All packages from requirements.txt already installed, skipping installation"
    fi
else
    echo "WARNING: requirements.txt not found, skipping package installation"
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
echo ""
echo "Resources Created:"
echo "  ✓ GCS bucket with directories"
echo "  ✓ Notebook uploaded to GCS"
echo "  ✓ DAG deployed to Cloud Composer"
echo "  ✓ Python packages installed in Composer"
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
