variable "region" {
  description = "The region for the resources."
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "GCP project name where resources are deployed."
  type = string
}
