# Airflow Notebook Scheduling Demo

This demo demonstrates scheduling BigQuery notebooks using Cloud Composer (Airflow), providing a GCP equivalent to Databricks' `DatabricksSubmitRunOperator`.

## Project Structure

```
airflow-demo/
├── README.md                                    # This file
├── dags/
│   └── sheets_bigquery_notebook_dag.py         # Airflow DAG for scheduling
├── notebooks/
│   └── sheets_bigquery_scheduled.ipynb         # Production-ready notebook
├── config/
│   └── requirements.txt                        # Python dependencies for container
└── setup/
    └── setup_vertex_ai.sh                      # GCP setup script
```

## Components

### Airflow DAG

**File:** `dags/sheets_bigquery_notebook_dag.py`

Uses `CreateCustomTrainingJobOperator` to schedule notebook execution via Vertex AI.

**Features:**
- Daily execution at 2 AM
- Retry logic: 2 attempts with 5-minute delays
- Parameterized execution via environment variables
- Alternative implementations included (Bash, Python operators)

**Required Configuration:**
- `GCS_NOTEBOOK_PATH`: Notebook location in GCS
- `GCS_OUTPUT_PATH`: Output storage location
- `SERVICE_ACCOUNT`: Execution service account

### Scheduled Notebook

**File:** `notebooks/sheets_bigquery_scheduled.ipynb`

Production-ready version with environment variable support, logging, and parameterization. Business logic identical to original notebook.

**Enhancements:**
- Environment variable configuration
- Execution logging
- Parameterized sheet IDs
- Flexible credentials handling
- Backward compatible with local execution

**Data Flow:**
1. Reads from 3 Google Sheets
2. Writes to BigQuery temp tables
3. Performs SQL join analysis

### Setup Script

**File:** `setup/setup_vertex_ai.sh`

Automates GCP resource provisioning.

**Actions:**
- Enables required APIs (Vertex AI, BigQuery, Storage, Compute)
- Creates service account with appropriate IAM roles
- Provisions GCS bucket for notebook storage
- Configures permissions

## Databricks Comparison

| Aspect | Databricks | GCP |
|--------|-----------|-----|
| Operator | `DatabricksSubmitRunOperator` | `CreateCustomTrainingJobOperator` |
| Setup | Native integration | Requires containerization |
| Execution | Databricks Runtime | Vertex AI Custom Training |
| Integration | Databricks-specific | GCP-native services |
| Cost Model | DBU-based | Compute-based |

## Setup

### Prerequisites

- GCP Project: `your-project-id`
- Cloud Composer environment
- Vertex AI API enabled
- Service account with required permissions

### Installation

**Step 1: Provision GCP Resources**
```bash
cd setup
./setup_vertex_ai.sh
```

**Step 2: Upload Notebook to GCS**
```bash
gsutil cp notebooks/sheets_bigquery_scheduled.ipynb \
  gs://your-project-id-notebooks/notebooks/
```

**Step 3: Configure DAG**

Edit `dags/sheets_bigquery_notebook_dag.py`:
```python
GCS_NOTEBOOK_PATH = "gs://your-project-id-notebooks/notebooks/sheets_bigquery_scheduled.ipynb"
GCS_OUTPUT_PATH = "gs://your-project-id-notebooks/notebook-outputs/"
SERVICE_ACCOUNT = "notebook-executor@your-project-id.iam.gserviceaccount.com"
```

**Step 4: Deploy to Cloud Composer**
```bash
gcloud composer environments storage dags import \
  --environment YOUR_COMPOSER_ENV \
  --location us-central1 \
  --source dags/sheets_bigquery_notebook_dag.py
```

**Step 5: Trigger Execution**

Via Airflow UI:
1. Navigate to Cloud Composer environment
2. Open Airflow UI
3. Enable `sheets_bigquery_notebook_dag`
4. Trigger execution

Via CLI:
```bash
gcloud composer environments run YOUR_ENV \
  --location us-central1 \
  dags trigger -- sheets_bigquery_notebook_dag
```

## Monitoring

Monitor execution through:
- Airflow UI: DAG status and logs
- Cloud Console: Vertex AI job details
- Cloud Logging: Detailed execution logs
- BigQuery: Verify data in temp tables

## Key Differences from Databricks

**Infrastructure:**
- Databricks: Native notebook execution
- GCP: Container-based execution via Papermill

**Advantages:**
- Native BigQuery integration
- Flexible containerization
- GCP service integration
- Compute-based pricing

## Environment Variables

The notebook supports the following environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `GCP_PROJECT` | BigQuery project ID | `your-project-id` |
| `GCP_REGION` | BigQuery region | `us-central1` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Service account path | `drive-api.json` |
| `LEGACY_CHARGES_SHEET_ID` | Legacy charges sheet | `1kQENu6sumzEQX60fjQtgmXvwPGlUfaNRgW7v_TWFUXo` |
| `MERCHANT_SEND_MID_LABEL_SHEET_ID` | Merchant send mid label sheet | `1_8sm8QciAU3T8oDlNS1Pfj-GQlmlJBrAi1TYdnnMlkw` |
| `MERCHANT_EXCLUDED_SHEET_ID` | Merchant excluded sheet | `1orVBlPP77HTt9d8x-lC1Oo5xrPp0r1FgVUQ-43DYqYc` |

## Resources

- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [Airflow Google Provider](https://airflow.apache.org/docs/apache-airflow-providers-google/)
- [Papermill Documentation](https://papermill.readthedocs.io/)
