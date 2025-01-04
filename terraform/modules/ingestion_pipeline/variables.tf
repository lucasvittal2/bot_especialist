variable "environment" {
  description = "The environment for the bot API (e.g., dev, staging, production)."
  type        = string
}

variable "region" {
  description = "The region for the resources."
  type        = string
  default     = "us-central1"
}

variable "service_account_id" {
  description = "The service account id"
  type        = string
}

variable "service_account_display_name" {
  description = "The display name of the custom service account."
  type        = string
  default     = "Default Custom Service Account"
}

variable "project_id" {
  description = "The ID of GCP project"
  type        = string
}

variable "location" {
  description = "location"
  type        = string
}

variable "trigger_topic_name"{
  description = "the topic used to send message in order to trigger workflow"
  type = string
}

variable "composer_service_account" {
  description = "Composer service account"
  type  = string
}

variable "project_name" {
  description = "GCP project name where resources are deployed."
  type = string
}

variable "bucket_name" {
  description = "The Bucket where pdf will be uploaded"
  type = string
}
