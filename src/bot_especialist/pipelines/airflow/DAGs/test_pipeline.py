from datetime import datetime

from airflow import DAG
from airflow.operators.dummy import DummyOperator
from airflow.providers.google.cloud.sensors.pubsub import PubSubPullSensor

default_args = {
    "start_date": datetime(2025, 1, 1),
    "retries": 0,
}

with DAG(
    "test_pipeline",
    default_args=default_args,
    schedule_interval=None,  # Triggered by Pub/Sub
    catchup=False,
) as dag:

    # Pub/Sub Sensor Task
    wait_for_message = PubSubPullSensor(
        task_id="testing_pipeline",
        project_id="680560386191",
        subscription="projects/680560386191/subscriptions/ingestion-pipeline-dev",
        ack_messages=True,
    )

    # Dummy Task
    process_message = DummyOperator(task_id="process_message")

    wait_for_message >> process_message
