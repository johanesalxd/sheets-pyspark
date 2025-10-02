"""
Airflow DAG for scheduling BigQuery notebook execution using PythonVirtualenvOperator.

This DAG executes notebooks in isolated virtual environments on Cloud Composer workers,
providing package isolation per task while remaining cost-effective.

The DAG creates a fresh virtualenv for each execution with specified packages,
ensuring no conflicts between different notebook jobs.

Author: Demo
Project: Configurable via Airflow variables
"""

from datetime import timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.operators.python import PythonVirtualenvOperator
from airflow.utils.dates import days_ago

# Configuration - Uses Airflow Variables (best practice for per-DAG isolation)
PROJECT_ID = Variable.get("gcp_project_id")
REGION = Variable.get("gcp_region", default_var="us-central1")

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


def run_notebook_in_venv(gcp_project: str, gcp_region: str, input_nb: str, output_nb: str):
    """
    Executes a notebook using Papermill in an isolated virtual environment.

    This function runs in a fresh virtualenv with only the specified packages,
    providing complete isolation from other tasks and DAGs.

    Args:
        gcp_project: GCP project ID for BigQuery operations
        gcp_region: GCP region for BigQuery operations
        input_nb: GCS path to input notebook
        output_nb: GCS path for output notebook

    Returns:
        str: Path to the executed output notebook
    """
    import papermill as pm

    # Execute notebook with parameters
    result = pm.execute_notebook(
        input_path=input_nb,
        output_path=output_nb,
        parameters={
            "GCP_PROJECT": gcp_project,
            "GCP_REGION": gcp_region,
        },
        progress_bar=False,
    )

    print(f"Notebook executed successfully: {output_nb}")
    return output_nb


# Define the DAG
with DAG(
    dag_id="sheets_bigquery_notebook_dag",
    default_args=default_args,
    description="Execute BigQuery notebook in isolated virtualenv on Composer workers",
    schedule_interval=None,  # Manual trigger only
    start_date=days_ago(1),
    catchup=False,
    tags=["bigquery", "notebook", "virtualenv", "isolated", "demo"],
) as dag:

    run_notebook = PythonVirtualenvOperator(
        task_id="execute_sheets_bigquery_notebook",
        python_callable=run_notebook_in_venv,
        requirements=[
            "papermill",
            "ipykernel",
            "gspread",
            "oauth2client",
            "bigframes",
            "db-dtypes",
        ],
        op_kwargs={
            "gcp_project": PROJECT_ID,
            "gcp_region": REGION,
            "input_nb": INPUT_NOTEBOOK,
            "output_nb": f"{OUTPUT_FOLDER}/{{{{ ds }}}}/output_{{{{ ts_nodash }}}}.ipynb",
        },
        system_site_packages=False,  # Complete isolation
    )
