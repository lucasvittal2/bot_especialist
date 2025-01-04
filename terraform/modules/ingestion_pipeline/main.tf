
# Provide infra to upload document and send notification
data "google_storage_project_service_account" "gcs_account" {
  provider = google-beta
}

// Create a Pub/Sub topic.
resource "google_pubsub_topic_iam_binding" "binding" {
  provider = google-beta
  topic    = google_pubsub_topic.topic.id
  role     = "roles/pubsub.publisher"
  members  = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_notification" "notification" {
  provider       = google-beta
  bucket         = google_storage_bucket.bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.topic.id
  depends_on     = [google_pubsub_topic_iam_binding.binding]
}

resource "random_id" "bucket_prefix" {
  byte_length = 8
}


resource "google_pubsub_topic" "topic" {
  name     = var.trigger_topic_name
  provider = google-beta
}




provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# Create the Google Cloud Storage bucket
resource "google_storage_bucket" "bucket" {
  name          = var.bucket_name
  location      = "US"
  force_destroy = true
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
}

# Create the notification on the bucket
resource "google_storage_notification" "bucket_notification" {
  bucket         = google_storage_bucket.bucket.name
  topic          = google_pubsub_topic.topic.id
  payload_format = "JSON_API_V1"

  event_types = [
    "OBJECT_FINALIZE", # Triggered when a new object is finalized in the bucket
  ]

  # Optional: Filter to limit the notifications to specific objects
  object_name_prefix = "uploads/"  # Only triggers for objects with this prefix
}

# Provisioning Ingestion Pipeline on Composer
provider "google-beta" {
  project = var.project_name
  region  = var.region
}

resource "google_project_service" "composer_api" {
  provider = google-beta
  project  = var.project_name
  service  = "composer.googleapis.com"
  disable_on_destroy                      = false
  check_if_service_has_usage_on_destroy  = true
}

resource "google_service_account" "composer_service_account" {
  provider      = google-beta
  account_id    = var.service_account_id
  display_name  = var.service_account_display_name
}

resource "google_project_iam_member" "composer_service_account" {
  provider = google-beta
  project  = var.project_name
  member   = format("serviceAccount:%s", google_service_account.composer_service_account.email)
  role     = "roles/composer.worker"
}

resource "google_service_account_iam_member" "composer_service_account_pubsub" {
  provider            = google-beta
  service_account_id  = google_service_account.composer_service_account.name
  role                = "roles/pubsub.publisher"
  member              = var.composer_service_account
}

resource "google_service_account_iam_member" "composer_service_account_vertex_ai" {
  provider            = google-beta
  service_account_id  = google_service_account.composer_service_account.name
  role                = "roles/aiplatform.user"
  member              = var.composer_service_account
}

resource "google_composer_environment" "ingestion-pipeline" {
  provider = google-beta
  name     = var.trigger_topic_name

  config {
    software_config {
      image_version = "composer-2.10.1-airflow-2.10.2"
    }

    node_config {
      service_account = google_service_account.composer_service_account.email
    }
  }
}
