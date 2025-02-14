# create Transaction Databases

resource "google_sql_database_instance" "track-database" {
  name                = var.track_db_name
  project             = var.project_name
  database_version    = var.postgres_version
  region              = var.region
  deletion_protection = false

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = var.db_instance_type
  }
}
