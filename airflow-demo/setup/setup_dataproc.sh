#!/bin/bash

# Setup script for Dataproc Serverless notebook execution
# This script configures GCP resources and deploys the Airflow DAG for Dataproc Serverless

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
BUCKET_NAME="${PROJECT_ID}-notebooks"
COMPOSER_ENV="composer-demo"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Dataproc Serverless Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Bucket: $BUCKET_NAME"
echo ""

# Step 1: Enable required APIs
echo -e "${YELLOW}Step 1: Enabling required APIs...${NC}"
gcloud services enable dataproc.googleapis.com \
    --project=$PROJECT_ID

echo -e "${GREEN}✓ APIs enabled${NC}"
echo ""

# Step 2: Verify GCS bucket exists (created by setup.sh)
echo -e "${YELLOW}Step 2: Verifying GCS bucket...${NC}"
if gsutil ls -b gs://$BUCKET_NAME > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Bucket gs://$BUCKET_NAME exists${NC}"
else
    echo -e "${RED}Error: Bucket gs://$BUCKET_NAME does not exist${NC}"
    echo "Please run setup.sh first to create the bucket"
    exit 1
fi
echo ""

# Step 3: Create scripts directory in GCS
echo -e "${YELLOW}Step 3: Creating scripts directory in GCS...${NC}"
echo "This directory will store auto-generated Python scripts"
gsutil ls gs://$BUCKET_NAME/scripts/ > /dev/null 2>&1 || \
    echo "# Auto-generated scripts directory" | gsutil cp - gs://$BUCKET_NAME/scripts/README.txt
echo -e "${GREEN}✓ Scripts directory created${NC}"
echo ""

# Step 4: Upload Spark development notebook to GCS
echo -e "${YELLOW}Step 4: Uploading Spark notebook to GCS...${NC}"
if [ -f "../notebooks/sheets_spark_dev.ipynb" ]; then
    gsutil cp ../notebooks/sheets_spark_dev.ipynb gs://$BUCKET_NAME/notebooks/
    echo -e "${GREEN}✓ Notebook uploaded to gs://$BUCKET_NAME/notebooks/${NC}"
else
    echo -e "${RED}Error: Notebook file not found at ../notebooks/sheets_spark_dev.ipynb${NC}"
    exit 1
fi
echo ""

# Step 5: Deploy DAG to Cloud Composer
echo -e "${YELLOW}Step 5: Deploying DAG to Cloud Composer...${NC}"
if [ -f "../dags/sheets_spark_dataproc_dag.py" ]; then
    # Get Composer bucket
    COMPOSER_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV \
        --location $REGION \
        --project $PROJECT_ID \
        --format="get(config.dagGcsPrefix)" | sed 's|/dags||')

    # Upload DAG
    gsutil cp ../dags/sheets_spark_dataproc_dag.py ${COMPOSER_BUCKET}/dags/
    echo -e "${GREEN}✓ DAG deployed to Cloud Composer${NC}"
else
    echo -e "${RED}Error: DAG file not found at ../dags/sheets_spark_dataproc_dag.py${NC}"
    exit 1
fi
echo ""

# Step 6: Set Airflow Variables (if not already set)
echo -e "${YELLOW}Step 6: Configuring Airflow Variables...${NC}"

# Check if variables already exist
EXISTING_PROJECT=$(gcloud composer environments run $COMPOSER_ENV \
    --location $REGION \
    --project $PROJECT_ID \
    variables get -- gcp_project_id 2>/dev/null || echo "")

if [ -z "$EXISTING_PROJECT" ]; then
    echo "Setting gcp_project_id variable..."
    gcloud composer environments run $COMPOSER_ENV \
        --location $REGION \
        --project $PROJECT_ID \
        variables set -- gcp_project_id $PROJECT_ID

    echo "Setting gcp_region variable..."
    gcloud composer environments run $COMPOSER_ENV \
        --location $REGION \
        --project $PROJECT_ID \
        variables set -- gcp_region $REGION

    echo -e "${GREEN}✓ Airflow variables configured${NC}"
else
    echo -e "${GREEN}✓ Airflow variables already configured${NC}"
fi
echo ""

# Step 7: Verification
echo -e "${YELLOW}Step 7: Verifying deployment...${NC}"
echo ""
echo "Checking GCS resources:"
echo "  Notebook: $(gsutil ls gs://$BUCKET_NAME/notebooks/sheets_spark_dev.ipynb && echo '✓' || echo '✗')"
echo "  Scripts dir: $(gsutil ls gs://$BUCKET_NAME/scripts/ && echo '✓' || echo '✗')"
echo "  Credentials: $(gsutil ls gs://$BUCKET_NAME/credentials/drive-api.json && echo '✓' || echo '✗')"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Open Airflow UI:"
echo "   gcloud composer environments run $COMPOSER_ENV \\"
echo "     --location $REGION \\"
echo "     --project $PROJECT_ID \\"
echo "     webserver info"
echo ""
echo "2. Enable and trigger the DAG:"
echo "   - DAG Name: sheets_spark_dataproc_dag"
echo "   - Tags: spark, dataproc-serverless, notebook"
echo ""
echo "3. Monitor execution:"
echo "   - Airflow UI: Task logs and status"
echo "   - Dataproc Batches: https://console.cloud.google.com/dataproc/batches"
echo "   - Generated scripts: gs://$BUCKET_NAME/scripts/"
echo ""
echo "Architecture:"
echo "  Airflow DAG"
echo "    → Task 1: Convert notebook to Python script"
echo "    → Task 2: Submit to Dataproc Serverless"
echo "      → Auto-scaling Spark execution"
echo "        → Write to BigQuery"
echo ""
echo -e "${GREEN}Setup complete. Ready to execute Spark workloads.${NC}"
