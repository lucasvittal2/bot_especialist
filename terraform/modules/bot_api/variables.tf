# Project Variables

variable "project_name" {
  description = "GCP project name where resources are deployed."
  type = string
}


variable "region" {
  description = "The region for the resources."
  type        = string
  default     = "us-central1"
}



# Cloud SQL Variables
variable "track_db_name" {
  description = "Database name for feedbacks"
  type = string
}

variable "postgres_version" {
  description = "Postgres Version used on cloud SQL"
  type = string
}

variable "db_instance_type" {
  description = "Instance type used to host Cloud SQL Databases"
  type = string
}
