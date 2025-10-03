#!/bin/bash

# Setup script for Vertex AI Custom Training with Cloud Composer
# This script configures Cloud Composer to run notebooks using Vertex AI Custom Training

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if project ID is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: GCP Project ID is required${NC}"
    echo "Usage: ./setup_vertex.sh YOUR_PROJECT_ID"
    exit 1
fi

PROJECT_ID=$1
REGION="us-central1"
COMPOSER_ENV="composer-demo"
COMPOSER_LOCATION="us-central1"
BUCKET_NAME="${PROJECT_ID}-notebooks"
ARTIFACT_REGISTRY_REPO="notebooks"
IMAGE_NAME="notebook-executor"
IMAGE_TAG="latest"
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Vertex AI Custom Training Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Composer Environment: $COMPOSER_ENV"
echo "Image URI: $IMAGE_URI"
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
    aiplatform.googleapis.com \
    artifactregistry.googleapis.com \
    --project=$PROJECT_ID

echo -e "${GREEN}APIs enabled${NC}"
echo ""

# Step 3: Create Artifact Registry repository
echo -e "${YELLOW}Step 3: Creating Artifact Registry repository...${NC}"
if gcloud artifacts repositories describe $ARTIFACT_REGISTRY_REPO \
    --location $REGION \
    --project $PROJECT_ID > /dev/null 2>&1; then
    echo -e "${GREEN}Repository $ARTIFACT_REGISTRY_REPO exists${NC}"
else
    gcloud artifacts repositories create $ARTIFACT_REGISTRY_REPO \
        --repository-format=docker \
        --location=$REGION \
        --description="Docker repository for notebook execution containers" \
        --project=$PROJECT_ID
    echo -e "${GREEN}Repository created${NC}"
fi
echo ""

# Step 4: Configure Docker authentication
echo -e "${YELLOW}Step 4: Configuring Docker authentication...${NC}"
gcloud auth configure-docker ${REGION}-docker.pkg.dev
echo -e "${GREEN}Docker authentication configured${NC}"
echo ""

# Step 5: Build and push Docker image
echo -e "${YELLOW}Step 5: Building and pushing Docker image...${NC}"
cd "$(dirname "$0")/.."  # Go to airflow-demo directory

docker build -t $IMAGE_URI -f docker/Dockerfile docker/
docker push $IMAGE_URI

echo -e "${GREEN}Docker image built and pushed${NC}"
echo ""

# Step 6: Create GCS bucket
echo -e "${YELLOW}Step 6: Creating GCS bucket...${NC}"
if gsutil ls -b gs://$BUCKET_NAME > /dev/null 2>&1; then
    echo -e "${GREEN}Bucket gs://$BUCKET_NAME exists${NC}"
else
    gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME
    echo -e "${GREEN}Bucket created${NC}"
fi

# Create bucket directories
gsutil -m mkdir -p gs://$BUCKET_NAME/notebooks/ 2>/dev/null || true
gsutil -m mkdir -p gs://$BUCKET_NAME/notebook-outputs-vertex/ 2>/dev/null || true
gsutil -m mkdir -p gs://$BUCKET_NAME/credentials/ 2>/dev/null || true
echo ""

# Step 7: Upload notebook to GCS
echo -e "${YELLOW}Step 7: Uploading notebook to GCS...${NC}"
if [ -f "notebooks/sheets_bigquery_scheduled.ipynb" ]; then
    gsutil cp notebooks/sheets_bigquery_scheduled.ipynb \
        gs://$BUCKET_NAME/notebooks/sheets_bigquery_scheduled.ipynb
    echo -e "${GREEN}Notebook uploaded to gs://$BUCKET_NAME/notebooks/${NC}"
else
    echo -e "${RED}Error: Notebook file not found at notebooks/sheets_bigquery_scheduled.ipynb${NC}"
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

# Step 8: Deploy DAG to Cloud Composer
echo -e "${YELLOW}Step 8: Deploying DAG to Cloud Composer...${NC}"
if [ -f "dags/sheets_bigquery_vertex_dag.py" ]; then
    COMPOSER_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV \
        --location $COMPOSER_LOCATION \
        --project $PROJECT_ID \
        --format="get(config.dagGcsPrefix)" | sed 's|/dags||')

    if [ -z "$COMPOSER_BUCKET" ]; then
        echo -e "${RED}Error: Cloud Composer environment '$COMPOSER_ENV' not found${NC}"
        exit 1
    fi

    gsutil cp dags/sheets_bigquery_vertex_dag.py ${COMPOSER_BUCKET}/dags/
    echo -e "${GREEN}DAG deployed to Cloud Composer${NC}"
else
    echo -e "${RED}Error: DAG file not found at dags/sheets_bigquery_vertex_dag.py${NC}"
    exit 1
fi
echo ""

# Step 9: Set Airflow Variables
echo -e "${YELLOW}Step 9: Configuring Airflow Variables...${NC}"

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

# Step 10: Check and install apache-airflow-providers-google if needed
echo -e "${YELLOW}Step 10: Checking apache-airflow-providers-google...${NC}"

if gcloud composer environments describe $COMPOSER_ENV \
    --location $COMPOSER_LOCATION \
    --format="value(config.softwareConfig.pypiPackages)" 2>/dev/null | grep -q "apache-airflow-providers-google"; then
    echo -e "${GREEN}Provider already installed${NC}"
else
    echo "Installing apache-airflow-providers-google>=18.0.0..."
    echo "Note: This may take 10-15 minutes..."

    gcloud composer environments update $COMPOSER_ENV \
        --location $COMPOSER_LOCATION \
        --update-pypi-package apache-airflow-providers-google>=18.0.0

    echo -e "${GREEN}Provider installed${NC}"
fi
echo ""

# Step 11: Verification
echo -e "${YELLOW}Step 11: Verifying deployment...${NC}"
echo ""
echo "Checking GCS resources:"
echo "  Notebook: $(gsutil ls gs://$BUCKET_NAME/notebooks/sheets_bigquery_scheduled.ipynb && echo 'OK' || echo 'MISSING')"
echo "  Outputs dir: $(gsutil ls gs://$BUCKET_NAME/notebook-outputs-vertex/ && echo 'OK' || echo 'MISSING')"
echo "  Credentials: $(gsutil ls gs://$BUCKET_NAME/credentials/drive-api.json && echo 'OK' || echo 'MISSING')"
echo "  Docker image: $(gcloud artifacts docker images describe $IMAGE_URI && echo 'OK' || echo 'MISSING')"
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
echo "  Container Image: $IMAGE_URI"
echo ""
echo "Resources Created:"
echo "  - Artifact Registry repository"
echo "  - Docker image built and pushed"
echo "  - GCS bucket with directories"
echo "  - Notebook uploaded to GCS"
echo "  - DAG deployed to Cloud Composer"
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
