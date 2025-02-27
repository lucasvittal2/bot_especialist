module "bot_api" {
  source           = "../modules/bot_api"
  project_name     = var.project_name
  region           = var.region
  track_db_name = "track"
  postgres_version = "POSTGRES_15"
  db_instance_type = "db-f1-micro"
}
