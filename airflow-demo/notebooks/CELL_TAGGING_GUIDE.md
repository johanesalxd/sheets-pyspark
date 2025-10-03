# Cell Tagging Guide for sheets_spark_dev.ipynb

This guide explains how to tag cells in the notebook to control which code is used for interactive development vs production batch execution.

## Overview

The notebook uses cell tags to separate:
- **Interactive development code** - Uses DataprocSparkSession (tagged `skip-conversion`)
- **Production batch code** - Uses standard SparkSession (no tag, included in script)

## How to Add Cell Tags in Jupyter

### Method 1: Using Jupyter Lab

1. Open `sheets_spark_dev.ipynb` in Jupyter Lab
2. Click on the cell you want to tag
3. Click the "Property Inspector" icon (gear icon) in the right sidebar
4. Under "Cell Tags", click "Add Tag"
5. Enter the tag name and press Enter

### Method 2: Using Jupyter Notebook (Classic)

1. Open `sheets_spark_dev.ipynb` in Jupyter Notebook
2. Enable the Cell Tags toolbar: View → Cell Toolbar → Tags
3. Click on the cell you want to tag
4. Enter the tag name in the "Add tag" field and click "Add tag"

## Required Cell Tags

### Cell to Tag: DataprocSparkSession Creation

**Tag this cell with:** `skip-conversion`

**Cell content:**
```python
# Create Spark session for Dataproc Serverless Interactive Session
# Note: This uses DataprocSparkSession for interactive development
# When converted to script for batch mode, this will be replaced with standard SparkSession
from google.cloud.dataproc_spark_connect import DataprocSparkSession
from google.cloud.dataproc_v1 import Session, SparkConnectConfig

session_config = Session()
session_config.spark_connect_session = SparkConnectConfig()
# TODO: Replace with your actual session template
session_config.session_template = f'projects/{GCP_PROJECT}/locations/{GCP_REGION}/sessionTemplates/runtime-00000b96da90'

spark = DataprocSparkSession.builder \
    .projectId(GCP_PROJECT) \
    .location(GCP_REGION) \
    .dataprocSessionConfig(session_config) \
    .getOrCreate()

logger.info(f"Spark session created: {spark.version}")
logger.info(f"BigQuery project: {GCP_PROJECT}")
logger.info(f"BigQuery location: {GCP_REGION}")
```

**Why:** This cell is only for interactive development. In batch mode, Dataproc Serverless auto-creates a SparkSession.

## Verification

After tagging, verify the setup:

1. **In Jupyter:** The DataprocSparkSession cell should show the tag `skip-conversion`
2. **Run the DAG:** The generated script should NOT contain DataprocSparkSession code
3. **Check generated script:**
   ```bash
   gsutil cat gs://your-project-id-notebooks/scripts/sheets_spark_job.py | grep -i "DataprocSparkSession"
   ```
   Should return nothing (cell was skipped)

## How It Works

### Interactive Development (Jupyter)
- All cells execute normally
- Uses `DataprocSparkSession` for interactive sessions
- Tagged cells are visible and executable

### Production (Batch Script)
- DAG converts notebook to Python script
- Cells tagged `skip-conversion` are excluded
- Dataproc Serverless auto-creates standard `SparkSession`
- Script runs on serverless Spark cluster

## Troubleshooting

### Issue: Script fails with "DataprocSparkSession not found"
**Solution:** The cell tag wasn't applied. Re-tag the cell and re-run the DAG.

### Issue: Script fails with "No SparkSession found"
**Solution:** Dataproc Serverless should auto-create the session. Check the batch configuration in the DAG.

### Issue: Can't see cell tags in Jupyter
**Solution:**
- Jupyter Lab: Enable Property Inspector (View → Show Right Sidebar)
- Jupyter Notebook: Enable Cell Toolbar (View → Cell Toolbar → Tags)

## Alternative: Manual JSON Editing

If you prefer to edit the notebook JSON directly:

1. Open `sheets_spark_dev.ipynb` in a text editor
2. Find the cell with DataprocSparkSession
3. Add metadata:
   ```json
   {
     "cell_type": "code",
     "metadata": {
       "tags": ["skip-conversion"]
     },
     "source": [...]
   }
   ```
4. Save the file

## Summary

**Tag:** `skip-conversion`
**Apply to:** DataprocSparkSession creation cell
**Result:** Cell excluded from production script, Dataproc auto-creates SparkSession
