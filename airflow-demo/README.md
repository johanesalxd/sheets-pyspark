# Airflow Notebook Scheduling Demo

Demonstrates three different approaches for scheduling notebook execution in GCP using Cloud Composer (Airflow).

## Overview

This demo provides three execution options for running notebooks in production, each optimized for different use cases:

1. **PythonVirtualenvOperator** - Cost-effective execution on Composer workers
2. **Vertex AI Custom Training** - Flexible execution with custom containers
3. **Dataproc Serverless** - Spark-native execution with auto-scaling

## Execution Options Comparison

| Feature | PythonVirtualenv | Vertex AI | Dataproc Serverless |
|---------|-----------------|-----------|---------------------|
| **Compute** | Composer workers | Dedicated VM | Serverless Spark |
| **Startup Time** | Instant | ~2-3 min | ~60 sec |
| **Scaling** | No | No | Auto-scale |
| **Cost** | Lowest | Medium | Pay-per-use |
| **Best For** | Simple workloads | Isolation, custom deps | Spark workloads |
| **Package Isolation** | virtualenv | Docker container | Custom container |

## Project Structure

```
airflow-demo/
├── README.md                                    # This file
├── dags/
│   ├── sheets_bigquery_notebook_dag.py         # PythonVirtualenvOperator DAG
│   ├── sheets_bigquery_vertex_dag.py           # Vertex AI Custom Training DAG
│   └── sheets_spark_dataproc_dag.py            # Dataproc Serverless DAG
├── docker/
│   ├── Dockerfile                              # Container for Vertex AI
│   ├── requirements.txt                        # Python dependencies
│   └── run_notebook.py                         # Notebook executor
├── notebooks/
│   ├── sheets_bigquery_scheduled.ipynb         # BigQuery notebook (Papermill)
│   └── sheets_spark_dev.ipynb                  # Spark notebook (development)
├── scripts/
│   └── README.md                               # Auto-generated scripts info
└── setup/
    ├── setup.sh                                # PythonVirtualenv setup
    ├── setup_vertex.sh                         # Vertex AI setup
    └── setup_dataproc.sh                       # Dataproc Serverless setup
```

## Quick Start

### Prerequisites

- GCP Project with billing enabled
- Cloud Composer environment (e.g., `composer-demo`)
- `gcloud` CLI configured
- `drive-api.json` credentials in parent directory

### Setup Options

Choose the execution method that best fits your needs:

#### Option 1: PythonVirtualenvOperator (Recommended for Simple Workloads)

```bash
cd airflow-demo/setup
./setup.sh your-project-id
```

**Best for:** Cost-effective execution, simple dependencies, quick setup

#### Option 2: Vertex AI Custom Training (Recommended for Isolation)

```bash
cd airflow-demo/setup
./setup_vertex.sh your-project-id
```

**Best for:** Custom dependencies, complete isolation, flexible compute

#### Option 3: Dataproc Serverless (Recommended for Spark Workloads)

```bash
cd airflow-demo/setup
./setup_dataproc.sh your-project-id
```

**Best for:** Spark processing, auto-scaling, data-intensive workloads

## Execution

### Trigger DAGs

**Via Airflow UI:**
1. Open Cloud Composer Airflow UI
2. Enable the desired DAG:
   - `sheets_bigquery_notebook_dag` (PythonVirtualenv)
   - `sheets_bigquery_vertex_dag` (Vertex AI)
   - `sheets_spark_dataproc_dag` (Dataproc Serverless)
3. Click "Trigger DAG"

**Via CLI:**
```bash
# PythonVirtualenv
gcloud composer environments run composer-demo \
  --location us-central1 \
  dags trigger -- sheets_bigquery_notebook_dag

# Vertex AI
gcloud composer environments run composer-demo \
  --location us-central1 \
  dags trigger -- sheets_bigquery_vertex_dag

# Dataproc Serverless
gcloud composer environments run composer-demo \
  --location us-central1 \
  dags trigger -- sheets_spark_dataproc_dag
```

### Verification

**Check deployment:**
```bash
# GCS bucket
gsutil ls gs://your-project-id-notebooks/

# Notebooks
gsutil ls gs://your-project-id-notebooks/notebooks/

# Output notebooks
gsutil ls gs://your-project-id-notebooks/notebook-outputs/        # PythonVirtualenv
gsutil ls gs://your-project-id-notebooks/notebook-outputs-vertex/ # Vertex AI

# Generated scripts (Dataproc only)
gsutil ls gs://your-project-id-notebooks/scripts/
```

## Configuration

The DAG uses **Airflow Variables** for configuration (following Airflow best practices):

- **`gcp_project_id`**: GCP project ID for BigQuery operations
- **`gcp_region`**: GCP region (default: `us-central1`)

These variables are automatically set by the setup script. You can view/modify them in:
- **Airflow UI:** Admin → Variables
- **CLI:** `gcloud composer environments run composer-demo --location us-central1 variables list`

### Why Airflow Variables?

Following [Airflow best practices](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html#airflow-variables):
- **Per-DAG isolation**: Different DAGs can use different projects/regions
- **Easy to change**: Modify in UI without redeploying
- **Visible**: See all configurations in one place
- **Standard practice**: Recommended by Airflow documentation

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

## Detailed Implementation Guides

### 1. PythonVirtualenvOperator

**Architecture:**
```
Airflow DAG → PythonVirtualenvOperator → virtualenv → Papermill → Notebook
```

**Key Features:**
- Runs on Composer workers (no extra compute cost)
- Isolated virtualenv per task
- Fast execution (no startup time)
- Perfect for simple workloads

**Use Case:** BigQuery data processing with BigFrames

### 2. Vertex AI Custom Training

**Architecture:**
```
Airflow DAG → Vertex AI Job → Custom Container → Papermill → Notebook
```

**Key Features:**
- Dedicated compute resources
- Custom Docker containers
- Complete isolation
- Flexible machine types

**Use Case:** Complex dependencies, custom environments

### 3. Dataproc Serverless

**Architecture:**
```
Airflow DAG → Convert Notebook → PySpark Script → Dataproc Serverless → Spark
```

**Key Features:**
- Serverless Spark execution
- Auto-scaling compute
- No cluster management
- Industry-standard PySpark deployment

**Use Case:** Spark workloads, large-scale data processing

**Unique Workflow:**
1. Develop in Jupyter notebook (`sheets_spark_dev.ipynb`)
2. DAG converts notebook to Python script
3. Script submitted to Dataproc Serverless
4. Executes on auto-scaling Spark cluster

## Resources

- [PythonVirtualenvOperator Documentation](https://airflow.apache.org/docs/apache-airflow/stable/howto/operator/python.html#pythonvirtualenvoperator)
- [Vertex AI Custom Training](https://cloud.google.com/vertex-ai/docs/training/create-custom-job)
- [Dataproc Serverless](https://cloud.google.com/dataproc-serverless/docs)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [Papermill Documentation](https://papermill.readthedocs.io/)
- [BigFrames Documentation](https://cloud.google.com/python/docs/reference/bigframes/latest)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
