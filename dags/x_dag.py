from airflow.sdk import dag,task 
from airflow.operators.python import PythonOperator
from api_etl import run_x_etl

def first_task_func():
    return "Hello World!"

@dag
def python_dag():

    first_task = PythonOperator(
        task_id="first_task",
        python_callable=first_task_func
    )

    second_task = PythonOperator(
        task_id="second_task",
        python_callable=run_x_etl
    )

    first_task >> second_task

python_dag_instance = python_dag()