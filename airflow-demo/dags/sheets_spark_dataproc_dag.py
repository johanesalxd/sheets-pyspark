"""Airflow DAG for scheduling Spark notebook execution using Dataproc Serverless.

This DAG executes Spark notebooks on serverless Dataproc compute resources,
providing auto-scaling Spark execution without cluster management.

The DAG converts a development notebook to a Python script, then submits
it as a PySpark batch workload to Dataproc Serverless.

Typical usage example:
    Triggered manually or via API to execute Spark workloads serverlessly.
    Notebook is converted to script automatically for production execution.
    Provides Spark-native processing with auto-scaling compute.

Author: Demo
Project: Configurable via Airflow variables
"""

from datetime import timedelta
import os
import tempfile

from airflow import DAG
from airflow.models import Variable
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.dataproc import \
    DataprocCreateBatchOperator
from airflow.utils.dates import days_ago

# Configuration - Uses Airflow Variables (best practice for per-DAG isolation)
PROJECT_ID: str = Variable.get("gcp_project_id")
REGION: str = Variable.get("gcp_region", default_var="us-central1")

# GCS paths
BUCKET_NAME: str = f"{PROJECT_ID}-notebooks"
INPUT_NOTEBOOK: str = f"gs://{BUCKET_NAME}/notebooks/sheets_spark_dev.ipynb"
OUTPUT_SCRIPT: str = f"gs://{BUCKET_NAME}/scripts/sheets_spark_job.py"
SPARK_BIGQUERY_JAR: str = "gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12:0.32.2"

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


def convert_notebook_to_script(**context):
    """Converts Jupyter notebook to Python script for Dataproc Serverless.

    This function downloads the notebook from GCS, converts it to a Python
    script using nbconvert, and uploads the script back to GCS.

    Args:
        **context: Airflow context containing task instance and other metadata.

    Returns:
        Path to the generated Python script in GCS.
    """
    from google.cloud import storage
    from nbconvert import PythonExporter
    import nbformat

    # Get configuration from context
    input_notebook = INPUT_NOTEBOOK
    output_script = OUTPUT_SCRIPT
    project_id = PROJECT_ID

    print(f"Converting notebook: {input_notebook}")
    print(f"Output script: {output_script}")

    # Initialize GCS client
    storage_client = storage.Client(project=project_id)

    # Parse GCS paths
    input_bucket_name = input_notebook.replace("gs://", "").split("/")[0]
    input_blob_name = "/".join(input_notebook.replace("gs://",
                               "").split("/")[1:])
    output_bucket_name = output_script.replace("gs://", "").split("/")[0]
    output_blob_name = "/".join(output_script.replace("gs://",
                                "").split("/")[1:])

    # Download notebook from GCS
    print(
        f"Downloading notebook from gs://{input_bucket_name}/{input_blob_name}")
    bucket = storage_client.bucket(input_bucket_name)
    blob = bucket.blob(input_blob_name)

    with tempfile.NamedTemporaryFile(mode='w+', suffix='.ipynb', delete=False) as temp_nb:
        blob.download_to_filename(temp_nb.name)
        temp_nb_path = temp_nb.name

    try:
        # Read and convert notebook
        print("Converting notebook to Python script...")
        with open(temp_nb_path, 'r') as f:
            notebook = nbformat.read(f, as_version=4)

        # Convert to Python script
        exporter = PythonExporter()
        script, _ = exporter.from_notebook_node(notebook)

        # Add shebang and encoding
        script = "#!/usr/bin/env python3\n# -*- coding: utf-8 -*-\n\n" + script

        # Write script to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as temp_py:
            temp_py.write(script)
            temp_py_path = temp_py.name

        # Upload script to GCS
        print(
            f"Uploading script to gs://{output_bucket_name}/{output_blob_name}")
        output_bucket = storage_client.bucket(output_bucket_name)
        output_blob = output_bucket.blob(output_blob_name)
        output_blob.upload_from_filename(temp_py_path)

        print(f"Successfully converted notebook to script: {output_script}")
        return output_script

    finally:
        # Clean up temp files
        if os.path.exists(temp_nb_path):
            os.remove(temp_nb_path)
        if 'temp_py_path' in locals() and os.path.exists(temp_py_path):
            os.remove(temp_py_path)


# Define the DAG
with DAG(
    dag_id="sheets_spark_dataproc_dag",
    default_args=default_args,
    description="Execute Spark notebook on Dataproc Serverless",
    schedule_interval=None,  # Manual trigger only
    start_date=days_ago(1),
    catchup=False,
    tags=["spark", "dataproc-serverless", "notebook", "bigquery", "demo"],
) as dag:

    # Task 1: Convert notebook to Python script
    convert_notebook = PythonOperator(
        task_id="convert_notebook_to_script",
        python_callable=convert_notebook_to_script,
        provide_context=True,
    )

    # Task 2: Submit PySpark batch to Dataproc Serverless
    submit_spark_batch = DataprocCreateBatchOperator(
        task_id="submit_to_dataproc_serverless",
        project_id=PROJECT_ID,
        region=REGION,
        batch={
            "pyspark_batch": {
                "main_python_file_uri": OUTPUT_SCRIPT,
                "jar_file_uris": [SPARK_BIGQUERY_JAR],
                "args": [PROJECT_ID, REGION],
            },
            "environment_config": {
                "execution_config": {
                    "service_account": f"{PROJECT_ID}@appspot.gserviceaccount.com",
                },
            },
        },
        batch_id=f"sheets-spark-batch-{{{{ ds_nodash }}}}-{{{{ ts_nodash }}}}",
    )

    # Define task dependencies
    convert_notebook >> submit_spark_batch
