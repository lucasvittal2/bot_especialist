resource "google_cloud_run_v2_service" "default" {
  name     = var.app_name
  location = var.region
  project  = var.project_name
  deletion_protection = false
  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = var.container_image
      ports {
        container_port = 8090
      }
      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds = 5
        period_seconds = 3
        failure_threshold = 1
        tcp_socket {
          port = 8090
        }
      }
      liveness_probe {
        http_get {
          path = "/"
        }
      }
    }
  }
}


# create Transaction Databases

resource "google_sql_database_instance" "dialogue_database" {
  name             = var.dialogue_db_name
  project = var.project_name
  database_version = var.postgres_version
  region           = var.region

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = var.db_instance_type
  }
}


resource "google_sql_database_instance" "feedback_database" {
  name             = var.feedback_db_name
  database_version = var.postgres_version
  project = var.project_name
  region           = var.region

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = var.db_instance_type
  }
}
