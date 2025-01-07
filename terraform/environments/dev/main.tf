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
