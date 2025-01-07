module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  environment                = "dev"
  project_name                   = "bot-especialist-dev"
  region                     = "us-central1"
  service_account_id         = "custom-service-account-dev"
  service_account_display_name = "Dev Custom Service Account"
  location = "US"
  project_id = "680560386191"
  trigger_topic_name = "ingestion-pipeline-dev"
  composer_service_account_worker="ingestion-worker-680560386191"
  composer_image_version = "composer-2.10.1-airflow-2.10.2"
  composer_env_name = "ingestion-pipeline"
  bucket_name= "pdf-repository-dev-680560386191"
  alloy_cluster_id = "alloydb-cluster-dev"

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
