module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  environment                = "dev"
  project_name                   = "bot-especialist-dev"
  region                     = "us-central1"
  service_account_id         = "custom-service-account-dev"
  location = "US"
  project_id = "680560386191"
  trigger_topic_name = "ingestion-pipeline-dev"
  composer_image_version = "composer-2.10.1-airflow-2.10.2"
  composer_env_name = "ingestion-pipeline"
  bucket_name= "pdf-repository-dev-680560386191"

}


module "alloydb_central" {
  source  = "GoogleCloudPlatform/alloy-db/google"
  version = "~> 3.0"

  cluster_id       = "cluster-us-central1"
  cluster_location = "us-central1"
  project_id       = 680560386191

  network_self_link           = "projects/680560386191/global/networks/simple-adb"


  automated_backup_policy = {
    location      = "us-central1"
    backup_window = "1800s"
    enabled       = true
    weekly_schedule = {
      days_of_week = ["FRIDAY"],
      start_times  = ["2:00:00:00", ]
    }
    quantity_based_retention_count = 1
    time_based_retention_count     = null
    labels = {
      test = "alloydb-cluster-with-prim"
    }

  }

  continuous_backup_recovery_window_days = 10


  primary_instance = {
    instance_id        = "cluster-us-central1-instance1",
    require_connectors = false
    ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
  }


  depends_on = [
    google_service_networking_connection.vpc_connection
  ]
}

module "bot_api" {
  source           = "../../modules/bot_api"
  app_name         = "testing-dev"
  project_name     = "bot-especialist-dev"
  project_id       = "680560386191"
  region           = "us-central1"
  container_image = "us-central1-docker.pkg.dev/bot-especialist-dev/bot-especialist/document-ingestion-pipelines@sha256:56269a4848a47c82d689a6672aff0d6bc7b097e8c1d8f1ad0b137e7f8b83897d"
  #change later, the current one is just for test
  feedback_db_name = "feedback-database"
  dialogue_db_name = "dialogue-database"
  postgres_version = "POSTGRES_15"
  db_instance_type = "db-f1-micro"
}
