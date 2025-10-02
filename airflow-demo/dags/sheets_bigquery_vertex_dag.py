"""Airflow DAG for scheduling BigQuery notebook execution using Vertex AI Custom Training.

This DAG executes notebooks on dedicated Vertex AI compute resources,
providing a Databricks-style submit job experience with full isolation
and flexible compute options.

The DAG submits a Custom Training job to Vertex AI that executes the notebook
in a containerized environment with specified dependencies.

Typical usage example:
    Triggered manually or via API to execute notebooks on isolated compute.
    Outputs are saved to GCS with execution date partitioning.
    Provides Databricks-style submit job experience on GCP.

Author: Demo
Project: Configurable via Airflow variables
"""

from datetime import timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.providers.google.cloud.operators.vertex_ai.custom_job import \
    CreateCustomContainerTrainingJobOperator
from airflow.utils.dates import days_ago

# Configuration - Uses Airflow Variables (best practice for per-DAG isolation)
PROJECT_ID: str = Variable.get("gcp_project_id")
REGION: str = Variable.get("gcp_region", default_var="us-central1")

# GCS paths
BUCKET_NAME: str = f"{PROJECT_ID}-notebooks"
INPUT_NOTEBOOK: str = f"gs://{BUCKET_NAME}/notebooks/sheets_bigquery_scheduled.ipynb"
OUTPUT_FOLDER: str = f"gs://{BUCKET_NAME}/notebook-outputs-vertex"

# Container image (will be built and pushed by setup script)
CONTAINER_IMAGE_URI: str = f"{REGION}-docker.pkg.dev/{PROJECT_ID}/notebooks/notebook-executor:latest"

# Default arguments for the DAG
default_args = {
    "owner": "data-team",
    "depends_on_past": False,
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "execution_timeout": timedelta(hours=2),
}

# Define the DAG
with DAG(
    dag_id="sheets_bigquery_vertex_dag",
    default_args=default_args,
    description="Execute BigQuery notebook on Vertex AI Custom Training",
    schedule_interval=None,  # Manual trigger only
    start_date=days_ago(1),
    catchup=False,
    tags=["bigquery", "notebook", "vertex-ai", "custom-training", "demo"],
) as dag:

    # Task to submit notebook execution to Vertex AI Custom Training
    submit_notebook_job = CreateCustomContainerTrainingJobOperator(
        task_id="submit_notebook_to_vertex_ai",
        staging_bucket=f"gs://{BUCKET_NAME}",
        display_name=f"notebook-execution-{{{{ ds }}}}-{{{{ ts_nodash }}}}",
        container_uri=CONTAINER_IMAGE_URI,
        model_serving_container_image_uri=CONTAINER_IMAGE_URI,
        command=["python", "/app/run_notebook.py"],
        environment_variables={
            "INPUT_NOTEBOOK": INPUT_NOTEBOOK,
            "OUTPUT_NOTEBOOK": f"{OUTPUT_FOLDER}/{{{{ ds }}}}/output_{{{{ ts_nodash }}}}.ipynb",
            "GCP_PROJECT": PROJECT_ID,
            "GCP_REGION": REGION,
        },
        replica_count=1,
        machine_type="n1-standard-4",
        region=REGION,
        project_id=PROJECT_ID,
    )
