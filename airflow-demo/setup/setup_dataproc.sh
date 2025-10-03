#!/bin/bash

# Setup script for Dataproc Serverless with Cloud Composer
# This script configures Cloud Composer to run Spark notebooks using Dataproc Serverless

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if project ID is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: GCP Project ID is required${NC}"
    echo "Usage: ./setup_dataproc.sh YOUR_PROJECT_ID"
    exit 1
fi

PROJECT_ID=$1
REGION="us-central1"
COMPOSER_ENV="composer-demo"
COMPOSER_LOCATION="us-central1"
BUCKET_NAME="${PROJECT_ID}-notebooks"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Dataproc Serverless Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Composer Environment: $COMPOSER_ENV"
echo ""

# Step 1: Set the project
echo -e "${YELLOW}Step 1: Setting GCP project...${NC}"
gcloud config set project $PROJECT_ID
echo -e "${GREEN}Project set${NC}"
echo ""

# Step 2: Enable required APIs
echo -e "${YELLOW}Step 2: Enabling required APIs...${NC}"
gcloud services enable \
    storage.googleapis.com \
    bigquery.googleapis.com \
    composer.googleapis.com \
    dataproc.googleapis.com \
    --project=$PROJECT_ID

echo -e "${GREEN}APIs enabled${NC}"
echo ""

# Step 3: Verify GCS bucket exists
echo -e "${YELLOW}Step 3: Verifying GCS bucket...${NC}"
if gsutil ls -b gs://$BUCKET_NAME > /dev/null 2>&1; then
    echo -e "${GREEN}Bucket gs://$BUCKET_NAME exists${NC}"
else
    echo -e "${RED}Error: Bucket gs://$BUCKET_NAME does not exist${NC}"
    echo "Please run setup.sh first to create the bucket"
    exit 1
fi

# Create scripts directory
gsutil ls gs://$BUCKET_NAME/scripts/ > /dev/null 2>&1 || \
    echo "# Auto-generated scripts directory" | gsutil cp - gs://$BUCKET_NAME/scripts/README.txt
echo ""

# Step 4: Create Python dependencies
echo -e "${YELLOW}Step 4: Creating Python dependencies...${NC}"
cd "$(dirname "$0")"  # Go to setup directory

if [ ! -f "setup_dataproc_requirements.txt" ]; then
    echo -e "${RED}Error: setup_dataproc_requirements.txt not found${NC}"
    exit 1
fi

# Clean up old dependencies
rm -rf dependencies dependencies.zip

# Create dependencies directory
mkdir -p dependencies

# Install packages
echo "Installing packages from setup_dataproc_requirements.txt..."
pip3 install -r setup_dataproc_requirements.txt --target=dependencies/ --quiet

# Create zip file
cd dependencies && zip -r ../dependencies.zip . --quiet
cd ..

echo -e "${GREEN}Dependencies created: dependencies.zip${NC}"
echo ""

# Step 5: Upload files to GCS
echo -e "${YELLOW}Step 5: Uploading files to GCS...${NC}"
cd "$(dirname "$0")/.."  # Go to airflow-demo directory

# Upload dependencies
if [ -f "setup/dependencies.zip" ]; then
    gsutil cp setup/dependencies.zip gs://$BUCKET_NAME/dependencies/dependencies.zip
    echo -e "${GREEN}Dependencies uploaded to gs://$BUCKET_NAME/dependencies/${NC}"
else
    echo -e "${RED}Error: dependencies.zip not found${NC}"
    exit 1
fi

# Upload notebook
if [ -f "notebooks/sheets_spark_dev.ipynb" ]; then
    gsutil cp notebooks/sheets_spark_dev.ipynb \
        gs://$BUCKET_NAME/notebooks/sheets_spark_dev.ipynb
    echo -e "${GREEN}Notebook uploaded to gs://$BUCKET_NAME/notebooks/${NC}"
else
    echo -e "${RED}Error: Notebook file not found at notebooks/sheets_spark_dev.ipynb${NC}"
    exit 1
fi

# Upload credentials to GCS (if exists)
if [ -f "../drive-api.json" ]; then
    gsutil cp ../drive-api.json gs://$BUCKET_NAME/credentials/drive-api.json
    echo -e "${GREEN}Credentials uploaded${NC}"
else
    echo -e "${YELLOW}Warning: drive-api.json not found in parent directory${NC}"
    echo "You'll need to upload it manually to: gs://$BUCKET_NAME/credentials/drive-api.json"
fi
echo ""

# Step 6: Deploy DAG to Cloud Composer
echo -e "${YELLOW}Step 6: Deploying DAG to Cloud Composer...${NC}"
if [ -f "dags/sheets_spark_dataproc_dag.py" ]; then
    COMPOSER_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV \
        --location $COMPOSER_LOCATION \
        --project $PROJECT_ID \
        --format="get(config.dagGcsPrefix)" | sed 's|/dags||')

    if [ -z "$COMPOSER_BUCKET" ]; then
        echo -e "${RED}Error: Cloud Composer environment '$COMPOSER_ENV' not found${NC}"
        exit 1
    fi

    gsutil cp dags/sheets_spark_dataproc_dag.py ${COMPOSER_BUCKET}/dags/
    echo -e "${GREEN}DAG deployed to Cloud Composer${NC}"
else
    echo -e "${RED}Error: DAG file not found at dags/sheets_spark_dataproc_dag.py${NC}"
    exit 1
fi
echo ""

# Step 7: Set Airflow Variables
echo -e "${YELLOW}Step 7: Configuring Airflow Variables...${NC}"

# Check if variables already exist
EXISTING_PROJECT=$(gcloud composer environments run $COMPOSER_ENV \
    --location $COMPOSER_LOCATION \
    --project $PROJECT_ID \
    variables get -- gcp_project_id 2>/dev/null || echo "")

if [ -z "$EXISTING_PROJECT" ]; then
    gcloud composer environments run $COMPOSER_ENV \
        --location $COMPOSER_LOCATION \
        --project $PROJECT_ID \
        variables set -- gcp_project_id $PROJECT_ID

    gcloud composer environments run $COMPOSER_ENV \
        --location $COMPOSER_LOCATION \
        --project $PROJECT_ID \
        variables set -- gcp_region $REGION

    echo -e "${GREEN}Airflow variables configured${NC}"
else
    echo -e "${GREEN}Airflow variables already configured${NC}"
fi
echo ""

# Step 8: Verification
echo -e "${YELLOW}Step 8: Verifying deployment...${NC}"
echo ""
echo "Checking GCS resources:"
echo "  Dependencies: $(gsutil ls gs://$BUCKET_NAME/dependencies/dependencies.zip && echo 'OK' || echo 'MISSING')"
echo "  Notebook: $(gsutil ls gs://$BUCKET_NAME/notebooks/sheets_spark_dev.ipynb && echo 'OK' || echo 'MISSING')"
echo "  Scripts dir: $(gsutil ls gs://$BUCKET_NAME/scripts/ && echo 'OK' || echo 'MISSING')"
echo "  Credentials: $(gsutil ls gs://$BUCKET_NAME/credentials/drive-api.json && echo 'OK' || echo 'MISSING')"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Configuration Summary:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Composer Environment: $COMPOSER_ENV"
echo "  GCS Bucket: gs://$BUCKET_NAME"
echo ""
echo "Resources Created:"
echo "  - Python dependencies (gspread, oauth2client, google-cloud-storage)"
echo "  - Dependencies uploaded to GCS"
echo "  - Notebook uploaded to GCS"
echo "  - DAG deployed to Cloud Composer"
echo ""
echo "How It Works:"
echo "  - Converts notebook to Python script"
echo "  - Submits to Dataproc Serverless with dependencies"
echo "  - Runs on auto-scaling Spark compute"
echo "  - Writes to BigQuery using built-in connector"
echo ""
echo "Next Steps:"
echo "1. Verify credentials are uploaded:"
echo "   gsutil ls gs://$BUCKET_NAME/credentials/"
echo ""
echo "2. Trigger the DAG in Airflow UI:"
echo "   - Navigate to Cloud Composer Airflow UI"
echo "   - Find 'sheets_spark_dataproc_dag'"
echo "   - Enable and trigger the DAG"
echo ""
echo "3. Monitor execution:"
echo "   - Check Airflow UI for task status"
echo "   - View Dataproc Batches: https://console.cloud.google.com/dataproc/batches"
echo "   - Check generated scripts: gs://$BUCKET_NAME/scripts/"
echo "   - View BigQuery tables"
echo ""
echo "=========================================="
