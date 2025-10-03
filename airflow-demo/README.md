# Airflow Notebook Scheduling Demo

Demonstrates three approaches for scheduling notebook execution in GCP using Cloud Composer (Airflow).

## Overview

This demo provides three execution options for running notebooks in production:

1. **PythonVirtualenvOperator** - Cost-effective execution on Composer workers
2. **Vertex AI Custom Training** - Flexible execution with custom containers
3. **Dataproc Serverless** - Spark-native execution with auto-scaling

## Execution Options Comparison

| Feature | PythonVirtualenv | Vertex AI | Dataproc Serverless |
|---------|-----------------|-----------|---------------------|
| Compute | Composer workers | Dedicated VM | Serverless Spark |
| Startup Time | Instant | 2-3 min | 60 sec |
| Scaling | No | No | Auto-scale |
| Cost | Lowest | Medium | Pay-per-use |
| Best For | Simple workloads | Isolation, custom deps | Spark workloads |
| Package Isolation | virtualenv | Docker container | Dependencies ZIP |

## Project Structure

```
airflow-demo/
├── README.md
├── dags/
│   ├── sheets_bigquery_notebook_dag.py         # PythonVirtualenvOperator
│   ├── sheets_bigquery_vertex_dag.py           # Vertex AI Custom Training
│   └── sheets_spark_dataproc_dag.py            # Dataproc Serverless
├── docker/
│   ├── Dockerfile                              # Vertex AI container
│   ├── requirements.txt                        # Python dependencies
│   └── run_notebook.py                         # Notebook executor
├── notebooks/
│   ├── sheets_bigquery_scheduled.ipynb         # BigQuery notebook
│   └── sheets_spark_dev.ipynb                  # Spark notebook
├── scripts/
│   └── README.md                               # Auto-generated scripts
└── setup/
    ├── setup.sh                                # PythonVirtualenv setup
    ├── setup_vertex.sh                         # Vertex AI setup
    ├── setup_dataproc.sh                       # Dataproc setup
    └── setup_dataproc_requirements.txt         # Dataproc dependencies
```

## Quick Start

### Prerequisites

- GCP Project with billing enabled
- Cloud Composer environment (e.g., `composer-demo`)
- `gcloud` CLI configured
- `drive-api.json` credentials in parent directory

### Setup

Choose the execution method that fits your needs:

**Option 1: PythonVirtualenvOperator**
```bash
cd airflow-demo/setup
./setup.sh your-project-id
```

**Option 2: Vertex AI Custom Training**
```bash
cd airflow-demo/setup
./setup_vertex.sh your-project-id
```

**Option 3: Dataproc Serverless**
```bash
cd airflow-demo/setup
./setup_dataproc.sh your-project-id
```

## Execution

### Trigger DAGs

Via Airflow UI:
1. Open Cloud Composer Airflow UI
2. Enable the desired DAG
3. Click "Trigger DAG"

Via CLI:
```bash
gcloud composer environments run composer-demo \
  --location us-central1 \
  dags trigger -- sheets_bigquery_notebook_dag
```

### Verification

Check deployment:
```bash
# GCS bucket
gsutil ls gs://your-project-id-notebooks/

# Notebooks
gsutil ls gs://your-project-id-notebooks/notebooks/

# Output notebooks
gsutil ls gs://your-project-id-notebooks/notebook-outputs/
```

## Configuration

DAGs use Airflow Variables for configuration:

- `gcp_project_id`: GCP project ID
- `gcp_region`: GCP region (default: `us-central1`)

Variables are set automatically by setup scripts. View/modify in Airflow UI under Admin → Variables.

## Implementation Details

### 1. PythonVirtualenvOperator

**Architecture:**
```
Airflow DAG → PythonVirtualenvOperator → virtualenv → Papermill → Notebook
```

**Features:**
- Runs on Composer workers (no extra compute)
- Isolated virtualenv per task
- Fast execution (no startup time)
- Package isolation

**Use Case:** BigQuery data processing with BigFrames

**Implementation:**
```python
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
    system_site_packages=False,
)
```

### 2. Vertex AI Custom Training

**Architecture:**
```
Airflow DAG → Vertex AI Job → Custom Container → Papermill → Notebook
```

**Features:**
- Dedicated compute resources
- Custom Docker containers
- Complete isolation
- Flexible machine types

**Use Case:** Complex dependencies, custom environments

**Implementation:**
- Builds Docker image with dependencies
- Submits Custom Training job to Vertex AI
- Executes notebook in container
- Saves output to GCS

### 3. Dataproc Serverless

**Architecture:**
```
Airflow DAG → Convert Notebook → PySpark Script → Dataproc Serverless → Spark
```

**Features:**
- Serverless Spark execution
- Auto-scaling compute
- No cluster management
- Built-in BigQuery connector

**Use Case:** Spark workloads, large-scale data processing

**Workflow:**
1. Develop in Jupyter notebook (`sheets_spark_dev.ipynb`)
2. DAG converts notebook to Python script
3. Script submitted to Dataproc Serverless with dependencies
4. Executes on auto-scaling Spark cluster

**Python Dependencies:**

Dependencies are packaged as ZIP and uploaded to GCS:
```bash
# setup_dataproc_requirements.txt
gspread>=5.0.0
oauth2client>=4.1.3
google-cloud-storage>=2.0.0
```

Setup script creates `dependencies.zip` and uploads to GCS. DAG references it:
```python
batch={
    "pyspark_batch": {
        "main_python_file_uri": OUTPUT_SCRIPT,
        "python_file_uris": [DEPENDENCIES_ZIP],
        "args": [PROJECT_ID, REGION],
    },
}
```

**Dual-Mode Notebook:**

The notebook supports both interactive development and batch execution:

```python
# Parameters cell - reads sys.argv for batch, uses defaults for interactive
import sys
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if len(sys.argv) > 1:
    # Batch mode: read from command-line arguments
    GCP_PROJECT = sys.argv[1]
    GCP_REGION = sys.argv[2] if len(sys.argv) > 2 else "us-central1"
else:
    # Interactive mode: use defaults
    GCP_PROJECT = "your-project-id"
    GCP_REGION = "us-central1"
```

**Cell Tagging:**

Tag cells to control conversion from notebook to script:

**Interactive-only cell** (tagged `skip-conversion`):
```python
# This cell is skipped during conversion
from google.cloud.dataproc_spark_connect import DataprocSparkSession

spark = DataprocSparkSession.builder \
    .projectId(GCP_PROJECT) \
    .location(GCP_REGION) \
    .getOrCreate()
```

**Batch-compatible cell** (no tag):
```python
# This cell is included in the converted script
try:
    spark  # Check if exists from interactive cell
except NameError:
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.appName("sheets-to-bigquery").getOrCreate()
```

**How to tag cells:**

Jupyter Lab:
1. Click cell to tag
2. Open Property Inspector (gear icon)
3. Add tag: `skip-conversion`

Jupyter Notebook:
1. Enable Cell Toolbar: View → Cell Toolbar → Tags
2. Enter tag name and click "Add tag"

**Verification:**

Check generated script excludes tagged cells:
```bash
gsutil cat gs://your-project-id-notebooks/scripts/sheets_spark_job.py | grep -i "DataprocSparkSession"
# Should return nothing (cell was skipped)
```

**BigQuery Connector:**

Dataproc Serverless includes the Spark BigQuery connector. No external JARs needed:
```python
# Write to BigQuery using built-in connector
df.write \
    .format("bigquery") \
    .option("table", f"{GCP_PROJECT}.temp.table_name") \
    .option("writeMethod", "direct") \
    .mode("overwrite") \
    .save()
```

## Monitoring

- Airflow UI: DAG status and logs
- GCS: Output notebooks in `notebook-outputs/` folder
- BigQuery: Check temp tables created by notebook
- Dataproc Batches: https://console.cloud.google.com/dataproc/batches

## Resources

- [PythonVirtualenvOperator Documentation](https://airflow.apache.org/docs/apache-airflow/stable/howto/operator/python.html#pythonvirtualenvoperator)
- [Vertex AI Custom Training](https://cloud.google.com/vertex-ai/docs/training/create-custom-job)
- [Dataproc Serverless](https://cloud.google.com/dataproc-serverless/docs)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [Papermill Documentation](https://papermill.readthedocs.io/)
- [BigFrames Documentation](https://cloud.google.com/python/docs/reference/bigframes/latest)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
