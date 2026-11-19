from airflow.sdk import task, dag

@dag
def first_dag():

    @task
    def task_1():
        print("Esta es la tarea 1")

    @task
    def task_2():
        print("Esta es la tarea 2")

    t1 = task_1()
    t2 = task_2()

    t1 >> t2

first_dag_instance = first_dag()