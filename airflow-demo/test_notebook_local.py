"""Local notebook testing script using Papermill.

This script allows you to test notebooks locally before deploying to production.
It executes notebooks with Papermill and saves the output locally.

Usage:
    python test_notebook_local.py

Prerequisites:
    - drive-api.json credentials in parent directory
    - Update GCP_PROJECT in this script

Requirements:
    - papermill installed (included in pyproject.toml)
    - GCP project configured

Author: Demo
"""

from datetime import datetime
import os
import shutil

import papermill as pm


def test_bigquery_notebook():
    """Tests the BigQuery notebook locally.

    Executes sheets_bigquery_scheduled.ipynb with test parameters
    and saves output to local file.
    """
    # Configuration
    GCP_PROJECT = "johanesa-playground-326616"  # UPDATE THIS
    GCP_REGION = "us-central1"

    # Paths
    INPUT_NOTEBOOK = "notebooks/sheets_bigquery_scheduled.ipynb"
    OUTPUT_NOTEBOOK = f"output_bigquery_{datetime.now().strftime('%Y%m%d_%H%M%S')}.ipynb"
    CREDENTIALS_SOURCE = "../drive-api.json"
    CREDENTIALS_LOCAL = "drive-api.json"

    print(f"Testing BigQuery notebook: {INPUT_NOTEBOOK}")
    print(f"Output will be saved to: {OUTPUT_NOTEBOOK}")
    print(f"Project: {GCP_PROJECT}")
    print(f"Region: {GCP_REGION}")
    print("")

    # Copy credentials file from parent directory to prevent GCS download
    credentials_copied = False
    if not os.path.exists(CREDENTIALS_LOCAL):
        if os.path.exists(CREDENTIALS_SOURCE):
            print(f"Copying credentials from {CREDENTIALS_SOURCE}")
            shutil.copy2(CREDENTIALS_SOURCE, CREDENTIALS_LOCAL)
            credentials_copied = True
        else:
            print(f"ERROR: Credentials file not found at {CREDENTIALS_SOURCE}")
            return

    try:
        # Execute notebook
        pm.execute_notebook(
            input_path=INPUT_NOTEBOOK,
            output_path=OUTPUT_NOTEBOOK,
            parameters={
                "GCP_PROJECT": GCP_PROJECT,
                "GCP_REGION": GCP_REGION,
            },
        )

        print(f"Notebook executed successfully: {OUTPUT_NOTEBOOK}")

    finally:
        # Clean up copied credentials file
        if credentials_copied and os.path.exists(CREDENTIALS_LOCAL):
            print(f"Cleaning up credentials file: {CREDENTIALS_LOCAL}")
            os.remove(CREDENTIALS_LOCAL)


if __name__ == "__main__":
    test_bigquery_notebook()
