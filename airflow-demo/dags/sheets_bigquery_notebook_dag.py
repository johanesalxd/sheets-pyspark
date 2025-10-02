"""
Airflow DAG for scheduling BigQuery notebook execution.

This DAG demonstrates how to schedule a notebook in GCP using Vertex AI,
similar to how Databricks uses DatabricksSubmitRunOperator.

Author: Demo
Project: Configurable (default: your-project-id)
"""

from datetime import datetime
from datetime import timedelta

from airflow import DAG
from airflow.providers.google.cloud.operators.vertex_ai.custom_job import \
    CreateCustomTrainingJobOperator
from airflow.utils.dates import days_ago

# Configuration - Update these values for your environment
PROJECT_ID = "your-project-id"
REGION = "us-central1"
DISPLAY_NAME = "sheets-bigquery-notebook-execution"

# GCS paths - These will be set by the setup script
BUCKET_NAME = f"{PROJECT_ID}-notebooks"
GCS_NOTEBOOK_PATH = f"gs://{BUCKET_NAME}/notebooks/sheets_bigquery_scheduled.ipynb"
GCS_OUTPUT_PATH = f"gs://{BUCKET_NAME}/notebook-outputs/"
GCS_CREDENTIALS_PATH = f"gs://{BUCKET_NAME}/credentials/drive-api.json"

# Service account and container image
SERVICE_ACCOUNT = f"notebook-executor@{PROJECT_ID}.iam.gserviceaccount.com"
IMAGE_URI = f"{REGION}-docker.pkg.dev/{PROJECT_ID}/notebook-executor/notebook-executor:latest"

# Default arguments for the DAG
default_args = {
    "owner": "data-team",
    "depends_on_past": False,
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "execution_timeout": timedelta(hours=1),
}

# Define the DAG
with DAG(
    dag_id="sheets_bigquery_notebook_dag",
    default_args=default_args,
    description="Schedule BigQuery notebook execution using Vertex AI",
    schedule_interval="0 2 * * *",  # Daily at 2 AM
    start_date=days_ago(1),
    catchup=False,
    tags=["bigquery", "notebook", "vertex-ai", "demo"],
) as dag:

    execute_notebook = CreateCustomTrainingJobOperator(
        task_id="execute_sheets_bigquery_notebook",
        project_id=PROJECT_ID,
        region=REGION,
        display_name=DISPLAY_NAME,
        worker_pool_specs=[
            {
                "machine_spec": {
                    "machine_type": "n1-standard-4",
                },
                "replica_count": 1,
                "container_spec": {
                    "image_uri": IMAGE_URI,
                    "command": ["sh", "-c"],
                    "args": [
                        f"gsutil cp {GCS_CREDENTIALS_PATH} /tmp/drive-api.json && "
                        f"python -m papermill {GCS_NOTEBOOK_PATH} "
                        f"{GCS_OUTPUT_PATH}output-{{{{ ds }}}}.ipynb "
                        f"--parameters project_id={PROJECT_ID} region={REGION}"
                    ],
                    "env": [
                        {"name": "GCP_PROJECT", "value": PROJECT_ID},
                        {"name": "GCP_REGION", "value": REGION},
                        {"name": "GOOGLE_APPLICATION_CREDENTIALS",
                            "value": "/tmp/drive-api.json"},
                    ],
                },
                # Mount GCS bucket for credentials access
                "disk_spec": {
                    "boot_disk_type": "pd-ssd",
                    "boot_disk_size_gb": 100,
                },
            }
        ],
        service_account=SERVICE_ACCOUNT,
        # Enable GCS FUSE for mounting credentials
        base_output_dir=GCS_OUTPUT_PATH,
    )

    execute_notebook
