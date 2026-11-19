# DataOps demo (your first ETL process)

This project template is designed to practice etl process on AWS.

## Install Docker Engine on Ubuntu

Check the status of Docker Engine

```bash
sudo systemctl status docker
```

Enable docker commands run without sudo

```bash
sudo usermod -aG docker Ubuntu
```

## Run the Airflow service on Ubuntu

Services are built or rebuilt

```bash
docker compose build
```

Run command in a directory that contains docker-compose.yaml

```bash
docker compose up -d
```

## Check the status of the files in the dags folder

Check for code errors in the files within the dags folder

```bash
docker compose exec airflow-dag-processor airflow dags list-import-errors
```

Check the update status of the files in the dags folder

```bash
docker compose exec airflow-dag-processor ls -l /opt/airflow/dags/
```
