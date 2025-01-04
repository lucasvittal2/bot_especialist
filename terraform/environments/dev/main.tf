module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  environment                = "dev"
  region                     = "us-central1"
  service_account_id         = "custom-service-account-dev"
  service_account_display_name = "Dev Custom Service Account"
  location = "US"
  project_id = "680560386191"
  trigger_topic_name = "ingestion-pipeline-dev"
  composer_service_account="serviceAccount:ingestion-pipeline-dev-680560386191@cloudcomposer-accounts.iam.gserviceaccount.com"
  project_name = "bot-especialist-dev"
  bucket_name= "pdf-repository-dev-680560386191"
}
