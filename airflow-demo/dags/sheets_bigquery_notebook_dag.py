"""
Airflow DAG for scheduling BigQuery notebook execution.

This DAG demonstrates how to schedule a notebook in GCP using Vertex AI,
similar to how Databricks uses DatabricksSubmitRunOperator.

Author: Demo
Project: your-project-id
"""

from datetime import datetime
from datetime import timedelta

from airflow import DAG
from airflow.providers.google.cloud.operators.gcs import \
    GCSCreateBucketOperator
from airflow.providers.google.cloud.operators.vertex_ai.custom_job import \
    CreateCustomTrainingJobOperator
from airflow.utils.dates import days_ago

# Configuration
PROJECT_ID = "your-project-id"
REGION = "us-central1"
DISPLAY_NAME = "sheets-bigquery-notebook-execution"

# GCS paths - Update these to match your setup
GCS_NOTEBOOK_PATH = "gs://YOUR_BUCKET_ID/notebooks/sheets_bigquery_scheduled.ipynb"
GCS_OUTPUT_PATH = "gs://YOUR_BUCKET_ID/notebook-outputs/"

# Service account for execution
SERVICE_ACCOUNT = "YOUR_SERVICE_ACCOUNT@your-project-id.iam.gserviceaccount.com"

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

    # Note: For actual notebook execution, you would use one of these approaches:
    #
    # Option 1: Use Vertex AI Workbench Executor (Recommended)
    # This requires the notebook to be in a Vertex AI Workbench instance
    #
    # Option 2: Use Custom Training Job with notebook execution container
    # This is what we demonstrate below
    #
    # Option 3: Convert to Python script and use DataprocSubmitJobOperator

    # For this demo, we'll show the structure using a custom container approach
    # In production, you'd use Vertex AI Workbench Executor or Notebooks API

    execute_notebook = CreateCustomTrainingJobOperator(
        task_id="execute_sheets_bigquery_notebook",
        project_id=PROJECT_ID,
        region=REGION,
        display_name=DISPLAY_NAME,
        # Container spec for notebook execution
        # You would build a custom container that executes the notebook
        worker_pool_specs=[
            {
                "machine_spec": {
                    "machine_type": "n1-standard-4",
                },
                "replica_count": 1,
                "container_spec": {
                    # This would be your custom container that runs papermill or nbconvert
                    "image_uri": f"gcr.io/{PROJECT_ID}/notebook-executor:latest",
                    "command": ["python", "-m", "papermill"],
                    "args": [
                        GCS_NOTEBOOK_PATH,
                        f"{GCS_OUTPUT_PATH}output-{{{{ ds }}}}.ipynb",
                        "--parameters",
                        f"project_id={PROJECT_ID}",
                        f"region={REGION}",
                    ],
                },
            }
        ],
        # Service account with necessary permissions
        service_account=SERVICE_ACCOUNT,
    )

    # Task dependencies (if you have multiple tasks)
    execute_notebook


# Alternative approach using bash operator to run papermill directly
# This is simpler but requires Cloud Composer to have the right packages
"""
from airflow.operators.bash import BashOperator

execute_notebook_simple = BashOperator(
    task_id='execute_notebook_with_papermill',
    bash_command=f'''
        papermill \
            {GCS_NOTEBOOK_PATH} \
            {GCS_OUTPUT_PATH}output-{{{{ ds }}}}.ipynb \
            -p project_id {PROJECT_ID} \
            -p region {REGION} \
            -p execution_date {{{{ ds }}}}
    ''',
    dag=dag,
)
"""

# For the simplest demo, you could also use a Python operator
"""
from airflow.operators.python import PythonOperator
import papermill as pm

def execute_notebook_function(**context):
    pm.execute_notebook(
        input_path=GCS_NOTEBOOK_PATH,
        output_path=f"{GCS_OUTPUT_PATH}output-{context['ds']}.ipynb",
        parameters={
            'project_id': PROJECT_ID,
            'region': REGION,
            'execution_date': context['ds'],
        }
    )

execute_notebook_python = PythonOperator(
    task_id='execute_notebook_python',
    python_callable=execute_notebook_function,
    provide_context=True,
    dag=dag,
)
"""
