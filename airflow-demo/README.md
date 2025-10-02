# Airflow Notebook Scheduling Demo

Demonstrates scheduling BigQuery notebooks using Cloud Composer (Airflow), providing a GCP equivalent to Databricks' `DatabricksSubmitRunOperator`.

## Overview

This demo uses Vertex AI Custom Training Jobs to execute notebooks via Papermill in a containerized environment, similar to how Databricks schedules notebook execution.

**Comparison:**

| Aspect | Databricks | GCP (This Demo) |
|--------|-----------|-----------------|
| Operator | `DatabricksSubmitRunOperator` | `CreateCustomTrainingJobOperator` |
| Execution | Databricks Runtime | Vertex AI + Docker Container |
| Integration | Databricks-specific | GCP-native services |

## Project Structure

```
airflow-demo/
├── README.md                                    # This file
├── Dockerfile                                   # Container for notebook execution
├── dags/
│   └── sheets_bigquery_notebook_dag.py         # Airflow DAG
├── notebooks/
│   └── sheets_bigquery_scheduled.ipynb         # Notebook with env var support
├── config/
│   └── requirements.txt                        # Python dependencies
└── setup/
    └── setup_vertex_ai.sh                      # Complete setup script
```

## Quick Start

### Prerequisites

- GCP Project with billing enabled
- Cloud Composer environment (e.g., `composer-demo`)
- Docker installed locally
- `gcloud` CLI configured
- `drive-api.json` credentials in parent directory

### One-Command Setup

```bash
cd airflow-demo/setup
./setup_vertex_ai.sh your-project-id
```

This command:
1. Enables required APIs
2. Creates service account with IAM roles
3. Creates GCS bucket and directories
4. Creates Artifact Registry repository
5. Builds and pushes Docker container
6. Uploads notebook and credentials to GCS
7. Deploys DAG to Cloud Composer

### Configuration

To customize, edit `dags/sheets_bigquery_notebook_dag.py`:

```python
PROJECT_ID = "your-project-id"  # Change this
REGION = "us-central1"
```

All paths are derived from `PROJECT_ID`.

## Execution

### Trigger DAG

**Via Airflow UI:**
1. Open Cloud Composer Airflow UI
2. Enable `sheets_bigquery_notebook_dag`
3. Click "Trigger DAG"

**Via CLI:**
```bash
gcloud composer environments run composer-demo \
  --location us-central1 \
  dags trigger -- sheets_bigquery_notebook_dag
```

### Verification

**Check deployment:**
```bash
# GCS bucket
gsutil ls gs://your-project-id-notebooks/

# Docker image
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/your-project-id/notebook-executor
```

## Monitoring

- **Airflow UI:** DAG status and logs
- **Cloud Console:** Vertex AI job details
- **Cloud Logging:** Detailed execution logs
- **BigQuery:** Verify data in temp tables

## How It Works

### Environment Variables

The notebook uses environment variables for configuration:

**Set in DAG → Passed to Container → Read by Notebook**

```python
# In DAG (container_spec.env)
{"name": "GCP_PROJECT", "value": "your-project-id"}

# In Notebook
project = os.getenv("GCP_PROJECT", "default-value")
```

**Available Variables:**

| Variable | Purpose |
|----------|---------|
| `GCP_PROJECT` | BigQuery project ID |
| `GCP_REGION` | BigQuery region |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service account JSON |

### Credentials

Credentials are uploaded to GCS and downloaded at runtime to `/tmp/drive-api.json` using `gsutil cp`.

## Resources

- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [Papermill Documentation](https://papermill.readthedocs.io/)
