# Google Sheets with PySpark on Dataproc Serverless

This project demonstrates using Google Sheets as a data source for PySpark sessions on Google Cloud Dataproc Serverless. It includes Jupyter notebooks for data processing and an Airflow demo for scheduling notebook execution.

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
│   ├── requirements.txt        # Python dependencies for Composer
│   ├── dags/                   # Airflow DAG definitions
│   ├── notebooks/              # Production-ready notebooks
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

### 1. Prerequisites

*   Python 3.11
*   [uv](https://github.com/astral-sh/uv) (a fast Python package installer)
*   Access to a Google Cloud project with Dataproc Serverless enabled.

### 2. Credentials

This project requires Google Service Account credentials to access Google Sheets and Google Drive.

1.  Obtain your Service Account key in JSON format from the Google Cloud Console.
2.  Rename the file to `drive-api.json` and place it in the root of this project directory.
3.  **Important**: The `drive-api.json` file is included in `.gitignore` and should never be committed to version control.

### 3. Environment and Dependencies

1.  **Install uv** (if you don't have it already):
    ```bash
    pip install uv
    ```

2.  **Create a virtual environment**:
    ```bash
    uv sync
    ```

3.  **Activate the virtual environment**:
    ```bash
    source .venv/bin/activate
    ```

## Usage

### Main Notebook

The core logic is within the `sheets_pyspark.ipynb` notebook. It demonstrates how to:
1.  Connect to a Dataproc Serverless Spark session.
2.  Authenticate with Google Sheets using service account credentials.
3.  Read data from multiple Google Sheets into Spark DataFrames.
4.  Perform SQL queries and analysis on the data.

### Airflow Notebook Scheduling Demo

The `airflow-demo/` directory contains a production-ready solution for scheduling notebook execution using Cloud Composer (Airflow) with PythonVirtualenvOperator.

**Features:**
- One-command setup script
- Isolated virtual environments per task
- Package isolation using PythonVirtualenvOperator
- Cost-effective execution on Composer workers
- Idempotent deployment

**See [airflow-demo/README.md](airflow-demo/README.md) for complete setup and usage instructions.**

### Utility Scripts

The `utils/` directory contains helper scripts:

*   `test_gspread_access.py`: Verifies `drive-api.json` credentials and Google Sheets API access.
*   `seed_gsheets.py`: Populates Google Sheets with sample data from `sample_data/` directory.
