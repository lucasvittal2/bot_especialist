module "bot_api" {
  source           = "../../modules/bot_api"
  app_name         = "testing-dev"
  project_name     = "the-bot-specialist-dev" # if you are getting started, change to your project name
  project_id       = "150030916493" # if you are getting started, change to your project number
  region           = "us-central1"
  registry_repo_name = "bot-especialist-repo"
  container_image = "us-central1-docker.pkg.dev/the-bot-specialist-dev/bot-specialist-repov1/bot-specialist-dev:v1"  # if you are getting started, change 'the-bot-specialist' to your project name
  track_db_name = "track"
  postgres_version = "POSTGRES_15"
  db_instance_type = "db-f1-micro"
}
