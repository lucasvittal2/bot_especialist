provider "google" {
  project = var.project_id
  region= var.region
}

# Infra para upload de documentos e notificações

data "google_storage_project_service_account" "gcs_account" {
  provider = google-beta
  project = var.project_name
}

# Criação de um tópico Pub/Sub
resource "google_pubsub_topic" "topic" {
  name     = var.trigger_topic_name
  provider = google-beta
  project = var.project_name
}

resource "google_pubsub_topic_iam_binding" "binding" {
  provider = google-beta
  topic    = google_pubsub_topic.topic.id
  role     = "roles/pubsub.publisher"
  members  = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}



# Criação do bucket no Google Cloud Storage
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

resource "google_storage_bucket_iam_member" "bucket_role_assignment" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Configuração da notificação no bucket

resource "google_storage_notification" "bucket_notification" {
  bucket         = google_storage_bucket.bucket.name
  topic          = google_pubsub_topic.topic.id
  payload_format = "JSON_API_V1"
  event_types    = ["OBJECT_FINALIZE"]

  depends_on = [
    google_pubsub_topic_iam_binding.binding,
    google_storage_bucket_iam_member.bucket_role_assignment
  ]
}

# Provisionando Pipeline de Ingestão no Composer

## Grant required roles to the custom service account


resource "google_service_account" "custom_service_account" {
  provider = google-beta
  account_id   = "custom-service-account"
  display_name = "Example Custom Service Account"
  project= var.project_name
}

resource "google_project_iam_member" "custom_service_account" {
  provider = google-beta
  project  = var.project_name
  member   = format("serviceAccount:%s", google_service_account.custom_service_account.email)
  role     = "roles/composer.worker"
}


resource "google_service_account_iam_member" "custom_service_account" {
  provider = google-beta
  service_account_id = google_service_account.custom_service_account.name
  role = "roles/composer.ServiceAgentV2Ext"
  member = "serviceAccount:service-${var.project_id}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

resource "google_project_service" "composer_api" {
  provider = google-beta
  project =  var.project_name
  service = "composer.googleapis.com"
  disable_on_destroy = false
  check_if_service_has_usage_on_destroy = true
}

## Create Composer Environment
resource "google_composer_environment" "ingestion_pipeline_environment" {
  provider = google-beta
  name = var.composer_env_name
  project = var.project_name
  region = var.region
  config {

    software_config {
      image_version = var.composer_image_version
    }

    node_config {
      service_account = google_service_account.custom_service_account.email
    }

  }
}
