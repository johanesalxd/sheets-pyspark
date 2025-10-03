# Auto-Generated Scripts

This directory contains Python scripts that are automatically generated from Jupyter notebooks by the Dataproc Serverless DAG.

## Purpose

The `sheets_spark_dataproc_dag` converts development notebooks to production-ready Python scripts for execution on Dataproc Serverless.

## Workflow

1. **Development**: Edit `notebooks/sheets_spark_dev.ipynb`
2. **Conversion**: DAG task converts `.ipynb` → `.py`
3. **Storage**: Generated script saved here
4. **Execution**: Script submitted to Dataproc Serverless

## Files

- `sheets_spark_job.py` - Auto-generated from `sheets_spark_dev.ipynb`

## Important Notes

- ⚠️ **Do not edit files in this directory manually**
- ⚠️ **Files are regenerated on each DAG run**
- ✅ **Edit the source notebook instead**
- ✅ **This directory is for generated artifacts only**

## Git Ignore

Generated scripts should be added to `.gitignore` as they are build artifacts:

```
# Auto-generated scripts
airflow-demo/scripts/*.py
```

## Verification

To verify the generated script:

```bash
# View the generated script
gsutil cat gs://your-project-id-notebooks/scripts/sheets_spark_job.py

# Check generation timestamp
gsutil ls -l gs://your-project-id-notebooks/scripts/
