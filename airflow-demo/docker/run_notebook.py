"""
Entry point script for Vertex AI Custom Training notebook execution.

This script executes a Jupyter notebook using Papermill with parameters
injected from environment variables set by Vertex AI.

Author: Demo
Project: Vertex AI Custom Training Notebook Executor
"""

from datetime import datetime
import os
import sys

import papermill as pm


def main():
    """Executes notebook with Papermill using environment variables."""

    # Get required parameters from environment variables
    input_notebook = os.environ.get("INPUT_NOTEBOOK")
    output_notebook = os.environ.get("OUTPUT_NOTEBOOK")
    gcp_project = os.environ.get("GCP_PROJECT")
    gcp_region = os.environ.get("GCP_REGION")

    # Validate required parameters
    if not input_notebook:
        print("ERROR: INPUT_NOTEBOOK environment variable not set")
        sys.exit(1)

    if not output_notebook:
        print("ERROR: OUTPUT_NOTEBOOK environment variable not set")
        sys.exit(1)

    if not gcp_project:
        print("ERROR: GCP_PROJECT environment variable not set")
        sys.exit(1)

    if not gcp_region:
        print("ERROR: GCP_REGION environment variable not set")
        sys.exit(1)

    # Log execution details
    print("=" * 80)
    print("Vertex AI Custom Training - Notebook Execution")
    print("=" * 80)
    print(f"Timestamp: {datetime.utcnow().isoformat()}Z")
    print(f"Input Notebook: {input_notebook}")
    print(f"Output Notebook: {output_notebook}")
    print(f"GCP Project: {gcp_project}")
    print(f"GCP Region: {gcp_region}")
    print("=" * 80)

    # Prepare parameters for notebook
    parameters = {
        "GCP_PROJECT": gcp_project,
        "GCP_REGION": gcp_region,
    }

    try:
        # Execute notebook with Papermill
        print("\nExecuting notebook...")
        pm.execute_notebook(
            input_path=input_notebook,
            output_path=output_notebook,
            parameters=parameters,
            progress_bar=False,
        )

        print("\n" + "=" * 80)
        print("Notebook executed successfully!")
        print(f"Output saved to: {output_notebook}")
        print("=" * 80)

    except Exception as e:
        print("\n" + "=" * 80)
        print("ERROR: Notebook execution failed")
        print("=" * 80)
        print(f"Error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
