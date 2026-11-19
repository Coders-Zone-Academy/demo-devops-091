FROM apache/airflow:3.4.0

USER airflow

RUN pip install --no-cache-dir s3fs