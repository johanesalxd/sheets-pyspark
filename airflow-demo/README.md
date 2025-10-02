# Airflow Notebook Scheduling Demo

Demonstrates scheduling BigQuery notebooks using Cloud Composer (Airflow) with PythonVirtualenvOperator for isolated package environments.

## Overview

This demo shows how to schedule notebook execution in GCP using Airflow with isolated virtual environments per task. The solution runs on Cloud Composer workers while providing complete package isolation, making it cost-effective and flexible for different package requirements per DAG.

## Project Structure

```
airflow-demo/
├── README.md                                    # This file
├── dags/
│   └── sheets_bigquery_notebook_dag.py         # Airflow DAG using PythonVirtualenvOperator
├── notebooks/
│   └── sheets_bigquery_scheduled.ipynb         # Notebook with Papermill parameters
└── setup/
    └── setup.sh                                # Complete setup script
```

## Comparison to Databricks

### Databricks Submit Run Operator
```python
from airflow.providers.databricks.operators.databricks import DatabricksSubmitRunOperator

run_notebook = DatabricksSubmitRunOperator(
    task_id="run_notebook",
    notebook_task={
        "notebook_path": "/path/to/notebook",
        "base_parameters": {"param1": "value1"}
    },
    new_cluster={...}
)
```

### GCP PythonVirtualenvOperator (This Demo)
```python
from airflow.operators.python import PythonVirtualenvOperator

def run_notebook(gcp_project, gcp_region, input_nb, output_nb):
    import papermill as pm
    pm.execute_notebook(input_nb, output_nb,
                       parameters={"GCP_PROJECT": gcp_project})

run_notebook = PythonVirtualenvOperator(
    task_id="execute_notebook",
    python_callable=run_notebook,
    requirements=["papermill", "gspread", "bigframes"],  # ← Isolated!
    op_kwargs={...}
)
```

**Key Features:**
- ✅ Isolated environment per task
- ✅ Different packages per DAG
- ✅ Runs on Composer workers (cost-effective)
- ✅ No cluster management
- ✅ Production-ready

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
1. Enables required APIs (Storage, BigQuery, Composer)
2. Creates GCS bucket and directories
3. Uploads notebook and credentials to GCS
4. Deploys DAG to Cloud Composer

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
  → PythonVirtualenvOperator
    → Creates isolated virtualenv
      → Installs packages (papermill, gspread, bigframes)
        → Runs Python function
          → Executes notebook with Papermill
            → Injects parameters
              → Saves output to GCS
```

### Implementation

The DAG uses PythonVirtualenvOperator to create isolated environments:

```python
from airflow.operators.python import PythonVirtualenvOperator

def run_notebook_in_venv(gcp_project, gcp_region, input_nb, output_nb):
    import papermill as pm

    result = pm.execute_notebook(
        input_path=input_nb,
        output_path=output_nb,
        parameters={
            "GCP_PROJECT": gcp_project,
            "GCP_REGION": gcp_region,
        },
    )
    return output_nb

run_notebook = PythonVirtualenvOperator(
    task_id="execute_sheets_bigquery_notebook",
    python_callable=run_notebook_in_venv,
    requirements=[
        "papermill",
        "gspread",
        "oauth2client",
        "bigframes",
        "db-dtypes",
    ],
    op_kwargs={
        "gcp_project": PROJECT_ID,
        "gcp_region": REGION,
        "input_nb": INPUT_NOTEBOOK,
        "output_nb": OUTPUT_NOTEBOOK,
    },
    system_site_packages=False,  # Complete isolation
)
```

### Key Features

- **Isolated Environments:** Each task runs in a fresh virtualenv with only specified packages
- **No Package Conflicts:** Different DAGs can use different package versions
- **Cost-Effective:** Runs on existing Composer workers, no extra compute
- **Flexible:** Easy to add/change packages per DAG
- **Production Ready:** Built on Airflow's standard operators

### Notebook Parameters

The notebook has a parameters cell that Papermill injects values into:

```python
# Parameters (injected by Papermill)
GCP_PROJECT = "your-project-id"  # Will be overridden by Airflow
GCP_REGION = "us-central1"  # Will be overridden by Airflow
```

## Package Isolation

### How It Works

1. **PythonVirtualenvOperator** creates a fresh virtualenv for each task execution
2. Installs only the packages specified in `requirements` parameter
3. Runs the Python function in that isolated environment
4. Virtualenv is cached for subsequent runs (faster)

### Benefits

- **No Conflicts:** DAG A can use `bigframes==1.0.0` while DAG B uses `bigframes==2.0.0`
- **Clean State:** Each execution starts with a fresh environment
- **Easy Updates:** Change packages without affecting other DAGs
- **Cost-Effective:** No need for separate compute resources

## Alternative Approaches

| Approach | Isolation | Cost | Complexity | Best For |
|----------|-----------|------|------------|----------|
| **PythonVirtualenvOperator** | ✅ Per task | $ | Low | This demo ✅ |
| KubernetesPodOperator | ✅ Complete | $$ | Medium | Heavy workloads |
| Vertex AI Workbench | ✅ Complete | $$$ | High | ML compute |
| PapermillOperator | ❌ Shared | $ | Low | Single DAG |

## Resources

- [PythonVirtualenvOperator Documentation](https://airflow.apache.org/docs/apache-airflow/stable/howto/operator/python.html#pythonvirtualenvoperator)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [Papermill Documentation](https://papermill.readthedocs.io/)
- [BigFrames Documentation](https://cloud.google.com/python/docs/reference/bigframes/latest)
