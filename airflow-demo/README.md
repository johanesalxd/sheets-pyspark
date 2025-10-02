# Airflow Notebook Scheduling Demo

Demonstrates scheduling BigQuery notebooks using Cloud Composer (Airflow) with Vertex AI Workbench Executor, providing a GCP equivalent to Databricks' `DatabricksSubmitRunOperator`.

## Overview

This demo uses Airflow's `PythonOperator` with the Vertex AI Workbench Executor API to schedule notebook execution, providing a GCP equivalent to Databricks' `DatabricksSubmitRunOperator`.

**Comparison:**

| Aspect | Databricks | GCP (This Demo) |
|--------|-----------|-----------------|
| Operator | `DatabricksSubmitRunOperator` | `PythonOperator` + Notebooks API |
| Execution | Databricks Runtime | Vertex AI Workbench Executor |
| Integration | Databricks-specific | GCP-native services |
| Complexity | Simple | Simple |

Both approaches provide clean notebook scheduling in Airflow.

## Project Structure

```
airflow-demo/
├── README.md                                    # This file
├── dags/
│   └── sheets_bigquery_notebook_dag.py         # Airflow DAG
├── notebooks/
│   └── sheets_bigquery_scheduled.ipynb         # Notebook with env var support
└── setup/
    └── setup_workbench.sh                      # Complete setup script
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
./setup_workbench.sh your-project-id
```

This command:
1. Enables required APIs
2. Creates service account with IAM roles
3. Creates GCS bucket and directories
4. Uploads notebook and credentials to GCS
5. Deploys DAG to Cloud Composer
6. Installs required Python packages in Composer

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
```

## Monitoring

- **Airflow UI:** DAG status and logs
- **Cloud Console:** Vertex AI Workbench executions
- **Cloud Logging:** Detailed execution logs
- **GCS:** Output notebooks in `notebook-outputs/` folder
- **BigQuery:** Verify data in temp tables

## How It Works

### Architecture

```
Airflow DAG (Cloud Composer)
  → PythonOperator
    → execute_notebook() function
      → notebooks_v1.NotebookServiceClient
        → create_execution() API call
          → Vertex AI Workbench Executor
            → Executes notebook on managed compute
              → Saves output to GCS
```

## Comparison to Databricks

### Databricks Approach
```python
from airflow.providers.databricks.operators.databricks import DatabricksSubmitRunOperator

run_notebook = DatabricksSubmitRunOperator(
    task_id='run_notebook',
    notebook_task={
        'notebook_path': '/path/to/notebook',
    }
)
```

### GCP Approach (This Demo)
```python
from airflow.operators.python import PythonOperator
from google.cloud import notebooks_v1

def execute_notebook(**context):
    client = notebooks_v1.NotebookServiceClient()
    operation = client.create_execution(
        parent=f"projects/{project_id}/locations/{region}",
        execution_id=execution_id,
        execution={
            "execution_template": {
                "input_notebook_file": notebook_path,
            }
        }
    )
    return operation.result()

run_notebook = PythonOperator(
    task_id='execute_notebook',
    python_callable=execute_notebook,
)
```

Both approaches provide clean, declarative notebook scheduling in Airflow.

## Resources

- [Vertex AI Workbench Documentation](https://cloud.google.com/vertex-ai/docs/workbench/instances/introduction)
- [Schedule Notebook Runs](https://cloud.google.com/vertex-ai/docs/workbench/instances/schedule-notebook-run-quickstart)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [Airflow Vertex AI Provider](https://airflow.apache.org/docs/apache-airflow-providers-google/stable/operators/cloud/vertex_ai.html)
