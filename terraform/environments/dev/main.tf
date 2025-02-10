module "alloydb_central" {
  source  = "GoogleCloudPlatform/alloy-db/google"
  version = "~> 3.0"
  cluster_id       = "cluster-us-central1"
  cluster_location = "us-central1"
  project_id       = "the-bot-specialist-dev"
  network_self_link = "projects/the-bot-specialist-dev/global/networks/simple-adb-bot"


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
  project_name     = "the-bot-specialist-dev"
  project_id       = "150030916493"
  region           = "us-central1"
  registry_repo_name = "bot-especialist-repo"
  container_image = "us-central1-docker.pkg.dev/the-bot-specialist-dev/bot-specialist-repov1/bot-specialist-dev:v1"
  track_db_name = "track"
  postgres_version = "POSTGRES_15"
  db_instance_type = "db-f1-micro"
}
