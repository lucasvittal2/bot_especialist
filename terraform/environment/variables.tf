variable "app_name" {
  description = "The App name which runs on cloud run"
  type        = string
}
variable "registry_repo_name" {
  description = "Instance type used to host Cloud SQL Databases"
  type = string
}
variable "container_image" {
  description = "The App name which runs on cloud run"
  type        = string
}
variable "region" {
  description = "The region for the resources."
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "GCP project name where resources are deployed."
  type = string
}
