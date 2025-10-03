# Google Sheets with PySpark on Dataproc Serverless

Demonstrates using Google Sheets as a data source for PySpark sessions on Google Cloud Dataproc Serverless. Includes Jupyter notebooks for data processing and an Airflow demo for scheduling notebook execution.

## Project Structure

```
.
├── .gitignore
├── drive-api.json              # (Git-ignored) Google Service Account credentials
├── pyproject.toml              # Project dependencies and configuration
├── sheets_pyspark.ipynb        # Main Jupyter Notebook for data analysis
├── sheets_bigquery.ipynb       # BigQuery notebook example
├── uv.lock                     # Lock file for uv package manager
├── airflow-demo/               # Airflow notebook scheduling demo
│   ├── README.md               # Demo documentation
│   ├── dags/                   # Airflow DAG definitions
│   ├── docker/                 # Vertex AI container files
│   ├── notebooks/              # Production-ready notebooks
│   ├── scripts/                # Auto-generated scripts
│   └── setup/                  # Setup scripts
├── sample_data/                # Sample CSV files
│   ├── legacy_charges.csv
│   ├── merchant_excluded.csv
│   └── merchant_send_mid_label.csv
└── utils/                      # Utility scripts
    ├── seed_gsheets.py
    └── test_gspread_access.py
```

## Setup and Installation

### Prerequisites

- Python 3.11
- [uv](https://github.com/astral-sh/uv) (fast Python package installer)
- Access to Google Cloud project with Dataproc Serverless enabled

### Credentials

This project requires Google Service Account credentials to access Google Sheets and Google Drive.

1. Obtain Service Account key in JSON format from Google Cloud Console
2. Rename file to `drive-api.json` and place in project root
3. The `drive-api.json` file is included in `.gitignore` and should never be committed

### Environment and Dependencies

Install uv:
```bash
pip install uv
```

Create virtual environment:
```bash
uv sync
```

Activate virtual environment:
```bash
source .venv/bin/activate
```

## Usage

### Main Notebook

The `sheets_pyspark.ipynb` notebook demonstrates:
1. Connect to Dataproc Serverless Spark session
2. Authenticate with Google Sheets using service account credentials
3. Read data from multiple Google Sheets into Spark DataFrames
4. Perform SQL queries and analysis on data

### Airflow Notebook Scheduling Demo

The `airflow-demo/` directory contains production-ready solutions for scheduling notebook execution using Cloud Composer (Airflow).

**Three execution options:**
1. **PythonVirtualenvOperator** - Cost-effective execution on Composer workers
2. **Vertex AI Custom Training** - Flexible execution with custom containers
3. **Dataproc Serverless** - Spark-native execution with auto-scaling

**Features:**
- One-command setup scripts
- Isolated environments per task
- Package isolation
- Cost-effective execution
- Idempotent deployment

See [airflow-demo/README.md](airflow-demo/README.md) for complete setup and usage instructions.

### Utility Scripts

The `utils/` directory contains helper scripts:

- `test_gspread_access.py`: Verifies `drive-api.json` credentials and Google Sheets API access
- `seed_gsheets.py`: Populates Google Sheets with sample data from `sample_data/` directory
