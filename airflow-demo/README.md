# Airflow Notebook Scheduling Demo

Demonstrates scheduling BigQuery notebooks using Cloud Composer (Airflow) with PapermillOperator.

## Overview

This demo shows how to schedule notebook execution in GCP using Airflow's `PapermillOperator`. The solution executes notebooks directly on Cloud Composer workers using Papermill, providing a simple and production-ready approach to notebook scheduling.

## Project Structure

```
airflow-demo/
├── README.md                                    # This file
├── requirements.txt                             # Python dependencies for Composer
├── dags/
│   └── sheets_bigquery_notebook_dag.py         # Airflow DAG using PapermillOperator
├── notebooks/
│   └── sheets_bigquery_scheduled.ipynb         # Notebook with Papermill parameters
└── setup/
    └── setup.sh                                # Complete setup script
```

## Quick Start

### Prerequisites

- GCP Project with billing enabled
- Cloud Composer environment (e.g., `composer-demo`)
- `gcloud` CLI configured
- `drive-api.json` credentials in parent directory

### One-Command Setup

```bash
cd airflow-demo/setup
./setup.sh your-project-id
```

This command:
1. Enables required APIs (BigQuery, Storage, Composer)
2. Creates GCS bucket and directories
3. Uploads notebook and credentials to GCS
4. Deploys DAG to Cloud Composer
5. Installs required Python packages in Composer

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

# Notebook file
gsutil ls gs://your-project-id-notebooks/notebooks/

# Output notebooks
gsutil ls gs://your-project-id-notebooks/notebook-outputs/
```

## Monitoring

- **Airflow UI:** DAG status and logs
- **GCS:** Output notebooks in `notebook-outputs/` folder
- **BigQuery:** Check temp tables created by notebook

## How It Works

### Architecture

```
Airflow DAG (Cloud Composer)
  → PapermillOperator
    → Executes notebook on Composer worker
      → Papermill injects parameters
        → Notebook runs with injected values
          → Saves output to GCS
```

### Implementation

The DAG uses PapermillOperator to execute notebooks directly on Composer workers:

```python
from airflow.providers.papermill.operators.papermill import PapermillOperator

run_notebook = PapermillOperator(
    task_id="execute_sheets_bigquery_notebook",
    input_nb="gs://PROJECT-notebooks/notebooks/sheets_bigquery_scheduled.ipynb",
    output_nb="gs://PROJECT-notebooks/notebook-outputs/{{ ds }}/output_{{ ts_nodash }}.ipynb",
    parameters={
        "GCP_PROJECT": PROJECT_ID,
        "GCP_REGION": REGION,
    },
)
```

### Key Features

- **Simple:** No separate compute infrastructure needed
- **Integrated:** Runs directly on Composer workers
- **Parameterized:** Papermill injects parameters at runtime
- **Traceable:** Output notebooks saved to GCS with timestamps

### Notebook Parameters

The notebook has a parameters cell that Papermill injects values into:

```python
# Parameters (injected by Papermill)
GCP_PROJECT = "your-project-id"  # Will be overridden by Airflow
GCP_REGION = "us-central1"  # Will be overridden by Airflow
```

## Resources

- [Papermill Documentation](https://papermill.readthedocs.io/)
- [Airflow Papermill Provider](https://airflow.apache.org/docs/apache-airflow-providers-papermill/stable/index.html)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [BigQuery Python Client](https://cloud.google.com/python/docs/reference/bigquery/latest)
