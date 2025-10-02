"""
Airflow DAG for scheduling BigQuery notebook execution using PapermillOperator.

This DAG executes notebooks directly on Cloud Composer workers using Papermill.

Author: Demo
Project: Configurable via Airflow variables
"""

from datetime import timedelta
import os

from airflow import DAG
from airflow.providers.papermill.operators.papermill import PapermillOperator
from airflow.utils.dates import days_ago

# Configuration - Uses Cloud Composer built-in project variable
PROJECT_ID = os.getenv("GCP_PROJECT", "your-project-id")
REGION = "us-central1"

# GCS paths
BUCKET_NAME = f"{PROJECT_ID}-notebooks"
INPUT_NOTEBOOK = f"gs://{BUCKET_NAME}/notebooks/sheets_bigquery_scheduled.ipynb"
OUTPUT_FOLDER = f"gs://{BUCKET_NAME}/notebook-outputs"

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
    description="Execute BigQuery notebook using Papermill on Composer workers",
    schedule_interval=None,  # Manual trigger only
    start_date=days_ago(1),
    catchup=False,
    tags=["bigquery", "notebook", "papermill", "demo"],
) as dag:

    run_notebook = PapermillOperator(
        task_id="execute_sheets_bigquery_notebook",
        input_nb=INPUT_NOTEBOOK,
        output_nb=f"{OUTPUT_FOLDER}/{{{{ ds }}}}/output_{{{{ ts_nodash }}}}.ipynb",
        parameters={
            "GCP_PROJECT": PROJECT_ID,
            "GCP_REGION": REGION,
        },
    )
