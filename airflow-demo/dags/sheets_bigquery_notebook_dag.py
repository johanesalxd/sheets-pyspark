"""
Airflow DAG for scheduling BigQuery notebook execution using Vertex AI Workbench.

This DAG schedules notebook execution in GCP using the Vertex AI Workbench Executor API
with Airflow's PythonOperator.

Author: Demo
Project: Configurable via GCP_PROJECT environment variable
"""

from datetime import timedelta
import os

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from google.cloud import notebooks_v1

# Configuration - Uses Cloud Composer built-in project variable
PROJECT_ID = os.getenv("GCP_PROJECT")
REGION = "us-central1"

# GCS paths
BUCKET_NAME = f"{PROJECT_ID}-notebooks"
GCS_NOTEBOOK_PATH = f"gs://{BUCKET_NAME}/notebooks/sheets_bigquery_scheduled.ipynb"
GCS_OUTPUT_PATH = f"gs://{BUCKET_NAME}/notebook-outputs/"

# Service account
SERVICE_ACCOUNT = f"notebook-executor@{PROJECT_ID}.iam.gserviceaccount.com"


def execute_notebook(**context):
    """Execute notebook using Vertex AI Workbench Executor API.

    Args:
        **context: Airflow context containing execution parameters.

    Returns:
        Execution ID of the completed notebook run.

    Raises:
        RuntimeError: If notebook execution fails.
    """
    project_id = context['params']['project_id']
    region = context['params']['region']
    notebook_path = context['params']['notebook_path']
    output_path = context['params']['output_path']
    service_account = context['params']['service_account']

    client = notebooks_v1.NotebookServiceClient()
    parent = f"projects/{project_id}/locations/{region}"

    execution_id = f"execution-{context['ds_nodash']}"

    operation = client.create_execution(
        parent=parent,
        execution_id=execution_id,
        execution={
            "execution_template": {
                "input_notebook_file": notebook_path,
                "output_notebook_folder": output_path,
                "machine_type": "n1-standard-4",
                "service_account": service_account,
            }
        }
    )

    response = operation.result()

    if response.state != notebooks_v1.Execution.State.SUCCEEDED:
        raise RuntimeError(
            f"Notebook execution failed with state: {response.state}")

    return execution_id


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
    description="Schedule BigQuery notebook execution using Vertex AI Workbench",
    schedule_interval="0 2 * * *",  # Daily at 2 AM
    start_date=days_ago(1),
    catchup=False,
    tags=["bigquery", "notebook", "vertex-ai", "workbench", "demo"],
) as dag:

    run_notebook = PythonOperator(
        task_id="execute_sheets_bigquery_notebook",
        python_callable=execute_notebook,
        params={
            "project_id": PROJECT_ID,
            "region": REGION,
            "notebook_path": GCS_NOTEBOOK_PATH,
            "output_path": GCS_OUTPUT_PATH,
            "service_account": SERVICE_ACCOUNT,
        },
    )

    run_notebook
