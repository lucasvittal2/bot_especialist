module "bot_api" {
  source           = "../modules/bot_api"
  app_name         = var.app_name
  project_name     = var.project_name
  region           = var.region
  registry_repo_name = var.registry_repo_name
  container_image = "us-central1-docker.pkg.dev/the-bot-specialist-dev/bot-specialist-repov1/${var.container_image}"  # if you are getting started, change 'the-bot-specialist' to your project name
  track_db_name = "track"
  postgres_version = "POSTGRES_15"
  db_instance_type = "db-f1-micro"
}
